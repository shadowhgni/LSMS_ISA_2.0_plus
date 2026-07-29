# ==============================================================================
# NGA_GHS3.r - Nigeria Wave 3 (GHS 2015)
# LSMS-ISA Harmonised Panel Analysis Code - R Translation
# ==============================================================================

# Clean environment
rm(list = ls())

# Load required packages
packages <- c("tidyverse", "haven", "labelled", "stringr", "purrr", 
              "data.table", "lubridate", "mice", "psych", "stats")
installed <- packages %in% rownames(utils::installed.packages())
if (any(!installed)) utils::install.packages(packages[!installed])
lapply(packages, library, character.only = TRUE)

# Source helper functions
source("../programs.r")

# ==============================================================================
# 1. SET UP PATHS AND GLOBALS
# ==============================================================================

# Define paths
project_root <- '../..'
Input_path <- file.path(project_root, "R_data", "Input")
Temp_path <- file.path(project_root, "R_data", "Temp")
Final_path <- file.path(project_root, "R_data", "Final")

# Create directories
dir.create(Temp_path, showWarnings = FALSE, recursive = TRUE)
dir.create(Final_path, showWarnings = FALSE, recursive = TRUE)

# Define country and wave
country <- "Nigeria"
wave <- "GHS 15"
temppath <- file.path("NGA", "GHS15")

# Input directory for this country/wave
input_dir <- file.path(Input_path, country, wave)
temp_dir <- file.path(Temp_path, temppath)
dir.create(temp_dir, showWarnings = FALSE, recursive = TRUE)

# ==============================================================================
# 2. HELPER FUNCTION: READ ZIPPED OR UNZIPPED DTA FILE
# ==============================================================================

#' Read a .dta file, handling both zipped and unzipped files
read_dta_auto <- function(pattern, input_dir, unzip_dir = NULL, force_unzip = FALSE) {
  
  if (is.null(unzip_dir)) {
    unzip_dir <- input_dir
  }
  
  dir.create(unzip_dir, showWarnings = FALSE, recursive = TRUE)
  
  # Check if .dta file exists (case insensitive)
  dta_files <- list.files(unzip_dir, pattern = paste0("(?i)", pattern, "\\.dta$"), 
                          full.names = TRUE, recursive = FALSE)
  
  if (length(dta_files) > 0 && !force_unzip) {
    cat("  Found existing .dta file:", basename(dta_files[1]), "\n")
    return(haven::read_dta(dta_files[1]))
  }
  
  # Find zip files
  zip_files <- list.files(input_dir, pattern = "\\.zip$", full.names = TRUE)
  
  if (length(zip_files) == 0) {
    stop("No zip files found in ", input_dir)
  }
  
  # Extract from zip
  for (zip_file in zip_files) {
    zip_contents <- unzip(zip_file, list = TRUE)$Name
    matching_file <- grep(pattern, zip_contents, ignore.case = TRUE, value = TRUE)
    
    if (length(matching_file) > 0) {
      cat("  Extracting", matching_file[1], "from", basename(zip_file), "\n")
      unzip(zip_file, files = matching_file[1], exdir = unzip_dir, overwrite = TRUE)
      extracted_path <- file.path(unzip_dir, matching_file[1])
      return(haven::read_dta(extracted_path))
    }
  }
  
  stop("Could not find pattern '", pattern, "' in any zip file in ", input_dir)
}

# ==============================================================================
# 3. MASTER FRAME OF CROPS, PLOTS AND HOUSEHOLDS
# ==============================================================================

message("Creating master frames...")

# 3.1 Plot-crop frame
tryCatch({
  cat("  Creating plot-crop frame...\n")
  
  harvest_data <- read_dta_auto("secta3i_harvestw3", input_dir, temp_dir) |>
    dplyr::rename(crop_name = cropname) |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::select(hhid, plot_id, crop_name, cropcode) |>
    dplyr::arrange(plot_id, cropcode) |>
    dplyr::group_by(plot_id, cropcode) |>
    dplyr::mutate(crop_name = dplyr::first(crop_name)) |>
    dplyr::ungroup() |>
    dplyr::distinct()
  
  # Handle duplicates with cropcode decode
  harvest_data <- harvest_data |>
    dplyr::group_by(plot_id, crop_name) |>
    dplyr::mutate(tag = dplyr::n()) |>
    dplyr::ungroup() |>
    dplyr::mutate(cropname2 = as.character(haven::as_factor(cropcode))) |>
    dplyr::mutate(crop_name = ifelse(tag > 0, cropname2, crop_name)) |>
    dplyr::mutate(crop_name = stringr::str_sub(crop_name, 
                                               stringr::str_locate(crop_name, "\\.")[,1] + 2, 
                                               -1)) |>
    dplyr::select(-cropname2, -tag) |>
    dplyr::distinct(plot_id, cropcode, crop_name, .keep_all = TRUE)
  
  haven::write_dta(harvest_data, file.path(temp_dir, "plot_crop_frame.dta"))
  cat("  ✓ plot_crop_frame saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in plot-crop frame: ", e$message, "\n")
})

# 3.2 Household frame
tryCatch({
  cat("  Creating household frame...\n")
  
  cover1_data <- read_dta_auto("secta_plantingw3", input_dir, temp_dir)
  
  hh_frame <- cover1_data |>
    dplyr::distinct(hhid)
  
  haven::write_dta(hh_frame, file.path(temp_dir, "hh_frame.dta"))
  cat("  ✓ hh_frame saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in household frame: ", e$message, "\n")
})

# 3.3 Individual frame
tryCatch({
  cat("  Creating individual frame...\n")
  
  indiv0_data <- read_dta_auto("sect1_harvestw3", input_dir, temp_dir)
  indiv_data <- read_dta_auto("sect1_plantingw3", input_dir, temp_dir)
  
  indiv_frame <- indiv0_data |>
    dplyr::left_join(indiv_data, by = c("hhid", "indiv")) |>
    dplyr::filter(s1q4a != 2) |>
    dplyr::rename(id = indiv) |>
    dplyr::mutate(ID = paste(hhid, id, sep = "-")) |>
    dplyr::select(hhid, ID) |>
    dplyr::distinct()
  
  haven::write_dta(indiv_frame, file.path(temp_dir, "indiv_frame.dta"))
  cat("  ✓ indiv_frame saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in individual frame: ", e$message, "\n")
})

# ==============================================================================
# 4. HOUSEHOLD-LEVEL VARIABLES
# ==============================================================================

message("Extracting household-level variables...")

# 4.1 EA (Enumeration Area)
tryCatch({
  cat("  Extracting EA...\n")
  
  ghs10_data <- read_dta_auto("secta_plantingw1", 
                              file.path(Input_path, country, "GHS 10"), 
                              file.path(Temp_path, "NGA", "GHS10"))
  
  ea_data <- cover1_data |>
    dplyr::select(-ea, -lga) |>
    dplyr::inner_join(ghs10_data |> dplyr::select(hhid, ea, lga), by = "hhid") |>
    dplyr::mutate(ea_id = paste(lga, ea, sep = "-")) |>
    dplyr::select(hhid, ea_id) |>
    dplyr::distinct()
  
  haven::write_dta(ea_data, file.path(temp_dir, "ea_id.dta"))
  cat("  ✓ ea_id saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in EA extraction: ", e$message, "\n")
})

# 4.2 Strata
tryCatch({
  cat("  Extracting strata...\n")
  
  strata_data <- cover1_data |>
    dplyr::rename(zone_w3 = zone) |>
    dplyr::inner_join(ghs10_data |> dplyr::select(hhid, zone), by = "hhid") |>
    dplyr::rename(strataid = zone) |>
    dplyr::select(hhid, strataid) |>
    dplyr::distinct()
  
  haven::write_dta(strata_data, file.path(temp_dir, "strataid.dta"))
  cat("  ✓ strataid saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in strata extraction: ", e$message, "\n")
})

# 4.3 Admin 1
tryCatch({
  cat("  Extracting admin levels...\n")
  
  admin1_data <- cover1_data |>
    dplyr::rename(admin_1 = zone) |>
    dplyr::mutate(admin_1_name = as.character(haven::as_factor(admin_1))) |>
    dplyr::select(hhid, admin_1, admin_1_name) |>
    dplyr::distinct()
  
  haven::write_dta(admin1_data, file.path(temp_dir, "admin1.dta"))
  
  admin2_data <- cover1_data |>
    dplyr::rename(admin_2 = state) |>
    dplyr::mutate(admin_2_name = as.character(haven::as_factor(admin_2))) |>
    dplyr::select(hhid, admin_2, admin_2_name) |>
    dplyr::distinct()
  
  haven::write_dta(admin2_data, file.path(temp_dir, "admin2.dta"))
  
  admin3_data <- cover1_data |>
    dplyr::rename(admin_3 = lga) |>
    dplyr::mutate(admin_3_name = toupper(as.character(haven::as_factor(admin_3)))) |>
    dplyr::select(hhid, admin_3, admin_3_name) |>
    dplyr::distinct()
  
  haven::write_dta(admin3_data, file.path(temp_dir, "admin3.dta"))
  cat("  ✓ admin levels saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in admin levels: ", e$message, "\n")
})

# 4.4 Urban
tryCatch({
  cat("  Extracting urban...\n")
  
  urban_data <- cover1_data |>
    dplyr::mutate(urban = dplyr::case_when(
      sector == 1 ~ 1,
      sector == 2 ~ 0,
      TRUE ~ NA_real_
    )) |>
    dplyr::select(hhid, urban) |>
    dplyr::distinct()
  
  haven::write_dta(urban_data, file.path(temp_dir, "urban.dta"))
  cat("  ✓ urban saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in urban: ", e$message, "\n")
})

# 4.5 Weights
tryCatch({
  cat("  Extracting weights...\n")
  
  csption1_data <- read_dta_auto("cons_agg_wave3_visit1", input_dir, temp_dir)
  csption2_data <- read_dta_auto("cons_agg_wave3_visit2", input_dir, temp_dir)
  
  weights_data <- csption1_data |>
    dplyr::inner_join(csption2_data |> dplyr::select(hhid), by = "hhid") |>
    dplyr::rename(pw = hhweight) |>
    dplyr::select(hhid, pw) |>
    dplyr::distinct()
  
  haven::write_dta(weights_data, file.path(temp_dir, "weights.dta"))
  cat("  ✓ weights saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in weights: ", e$message, "\n")
})

# 4.6 Planting interview month
tryCatch({
  cat("  Extracting planting interview month...\n")
  
  planting_interview_data <- cover1_data |>
    dplyr::mutate(
      month = saq13m,
      year = saq13y
    ) |>
    dplyr::mutate(planting_interview_month = lubridate::ymd(paste(year, month, "01", sep = "-"))) |>
    dplyr::select(hhid, planting_interview_month) |>
    dplyr::distinct()
  
  haven::write_dta(planting_interview_data, file.path(temp_dir, "planting_interview_month.dta"))
  cat("  ✓ planting_interview_month saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in planting interview month: ", e$message, "\n")
})

# 4.7 Harvest interview month
tryCatch({
  cat("  Extracting harvest interview month...\n")
  
  cover2_data <- read_dta_auto("secta_harvestw3", input_dir, temp_dir)
  
  harvest_interview_data <- cover2_data |>
    dplyr::mutate(
      month = saq13m,
      year = saq13y
    ) |>
    dplyr::mutate(harvest_interview_month = lubridate::ymd(paste(year, month, "01", sep = "-"))) |>
    dplyr::select(hhid, harvest_interview_month) |>
    dplyr::distinct()
  
  haven::write_dta(harvest_interview_data, file.path(temp_dir, "harvest_interview_month.dta"))
  cat("  ✓ harvest_interview_month saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in harvest interview month: ", e$message, "\n")
})

# 4.8 Household size
tryCatch({
  cat("  Extracting household size...\n")
  
  labor_hh_data <- read_dta_auto("sect3_plantingw3", input_dir, temp_dir)
  
  hh_size_data <- labor_hh_data |>
    dplyr::group_by(hhid) |>
    dplyr::summarise(hh_size = dplyr::n_distinct(indiv), .groups = "drop")
  
  haven::write_dta(hh_size_data, file.path(temp_dir, "size.dta"))
  cat("  ✓ hh_size saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in household size: ", e$message, "\n")
})

# 4.9 Dependency ratio
tryCatch({
  cat("  Calculating dependency ratio...\n")
  
  indiv_roster_data <- read_dta_auto("sect1_plantingw3", input_dir, temp_dir)
  
  dep_ratio_data <- indiv_roster_data |>
    dplyr::rename(age = s1q6) |>
    dplyr::mutate(
      age = ifelse(age == 999, NA, age),
      dep_temp = !(age >= 15 & age <= 65) & !is.na(age),
      nondep_temp = (age >= 15 & age <= 65) & !is.na(age)
    ) |>
    dplyr::group_by(hhid) |>
    dplyr::summarise(
      dep = sum(dep_temp, na.rm = TRUE),
      nondep = sum(nondep_temp, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      hh_dependency_ratio = dep / nondep,
      hh_dependency_ratio = ifelse(nondep == 0, dep, hh_dependency_ratio)
    ) |>
    dplyr::select(hhid, hh_dependency_ratio) |>
    dplyr::distinct()
  
  haven::write_dta(dep_ratio_data, file.path(temp_dir, "hh_dependency_ratio.dta"))
  cat("  ✓ hh_dependency_ratio saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in dependency ratio: ", e$message, "\n")
})

# 4.10 Education (household level)
tryCatch({
  cat("  Extracting household education...\n")
  
  indiv_roster1_data <- read_dta_auto("sect2_harvestw3", input_dir, temp_dir)
  
  educ_hh_data <- indiv_roster1_data |>
    dplyr::mutate(
      formal_education_hh1 = dplyr::case_when(
        s2aq6 == 1 ~ 1,
        s2aq6 == 2 ~ 0,
        TRUE ~ NA_real_
      ),
      primary_education_hh1 = dplyr::case_when(
        s2aq9 >= 16 & s2aq9 <= 43 ~ 1,
        s2aq9 %in% c(0:15, 51:61) ~ 0,
        TRUE ~ NA_real_
      ),
      primary_education_hh1 = ifelse(s2aq6 == 2, 0, primary_education_hh1)
    ) |>
    dplyr::group_by(hhid) |>
    dplyr::summarise(
      hh_formal_education = max(formal_education_hh1, na.rm = TRUE),
      hh_primary_education = max(primary_education_hh1, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      hh_formal_education = ifelse(is.infinite(hh_formal_education), NA, hh_formal_education),
      hh_primary_education = ifelse(is.infinite(hh_primary_education), NA, hh_primary_education)
    )
  
  haven::write_dta(educ_hh_data, file.path(temp_dir, "hh_primary_education.dta"))
  cat("  ✓ hh_primary_education saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in household education: ", e$message, "\n")
})

# 4.11 Electricity access
tryCatch({
  cat("  Extracting electricity access...\n")
  
  housing_data <- read_dta_auto("sect11_plantingw3", input_dir, temp_dir)
  
  electricity_data <- housing_data |>
    dplyr::mutate(
      hh_electricity_access = dplyr::case_when(
        s11q17b == 1 ~ 1,
        s11q17b == 2 ~ 0,
        TRUE ~ NA_real_
      ),
      hh_electricity_access = ifelse(s11q28b == 1 & hh_electricity_access == 0, 1, hh_electricity_access),
      hh_electricity_access = ifelse(s11q28f == 1 & hh_electricity_access == 0, 1, hh_electricity_access)
    ) |>
    dplyr::select(hhid, hh_electricity_access) |>
    dplyr::distinct()
  
  haven::write_dta(electricity_data, file.path(temp_dir, "hh_electricity_access.dta"))
  cat("  ✓ hh_electricity_access saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in electricity access: ", e$message, "\n")
})

# 4.12 Livestock
tryCatch({
  cat("  Extracting livestock ownership...\n")
  
  livestock_data <- read_dta_auto("sect11i_plantingw3", input_dir, temp_dir)
  
  livestock_data <- livestock_data |>
    dplyr::mutate(livestock = dplyr::case_when(
      s11iq1 == 1 ~ 1,
      s11iq1 == 2 ~ 0,
      TRUE ~ NA_real_
    )) |>
    dplyr::group_by(hhid) |>
    dplyr::summarise(livestock = max(livestock, na.rm = TRUE), .groups = "drop") |>
    dplyr::mutate(livestock = ifelse(is.infinite(livestock), NA, livestock))
  
  haven::write_dta(livestock_data, file.path(temp_dir, "livestock.dta"))
  cat("  ✓ livestock saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in livestock: ", e$message, "\n")
})

# 4.13 Consumption quintile
tryCatch({
  cat("  Extracting consumption quintile...\n")
  
  cons_quint_data <- csption1_data |>
    dplyr::inner_join(csption2_data |> dplyr::select(hhid), by = "hhid") |>
    dplyr::mutate(cons_quint = cut(totcons, 
                                   breaks = stats::quantile(totcons, probs = seq(0, 1, 0.2), na.rm = TRUE),
                                   labels = 1:5,
                                   include.lowest = TRUE)) |>
    dplyr::select(hhid, cons_quint) |>
    dplyr::distinct()
  
  haven::write_dta(cons_quint_data, file.path(temp_dir, "cons_quint.dta"))
  cat("  ✓ cons_quint saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in consumption quintile: ", e$message, "\n")
})

# 4.14 Total consumption
tryCatch({
  cat("  Extracting total consumption...\n")
  
  totcons_data <- csption1_data |>
    dplyr::inner_join(csption2_data |> dplyr::select(hhid), by = "hhid") |>
    dplyr::select(hhid, totcons) |>
    dplyr::distinct()
  
  haven::write_dta(totcons_data, file.path(temp_dir, "totcons.dta"))
  cat("  ✓ totcons saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in total consumption: ", e$message, "\n")
})

# 4.15 Household shocks
tryCatch({
  cat("  Extracting household shocks...\n")
  
  shocks_data <- read_dta_auto("sect15a_harvestw3", input_dir, temp_dir)
  
  shock_data <- shocks_data |>
    dplyr::mutate(
      s15aq1 = ifelse(s15aq3a == "X", 0, s15aq1),
      hh_shock = dplyr::case_when(
        s15aq1 == 1 ~ 1,
        s15aq1 %in% c(2, 0) ~ 0,
        TRUE ~ NA_real_
      )
    ) |>
    dplyr::group_by(hhid) |>
    dplyr::summarise(hh_shock = max(hh_shock, na.rm = TRUE), .groups = "drop") |>
    dplyr::mutate(hh_shock = ifelse(is.infinite(hh_shock), NA, hh_shock))
  
  haven::write_dta(shock_data, file.path(temp_dir, "shock.dta"))
  cat("  ✓ hh_shock saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in household shocks: ", e$message, "\n")
})

# 4.16 Non-farm enterprise
tryCatch({
  cat("  Extracting non-farm enterprise...\n")
  
  nfe_data <- read_dta_auto("sect9_harvestw3", input_dir, temp_dir)
  
  nfe_data <- nfe_data |>
    dplyr::left_join(cover1_data |> dplyr::select(hhid), by = "hhid") |>
    dplyr::mutate(
      nonfarm_enterprise = dplyr::case_when(
        !is.na(hhid.y) ~ 1,
        is.na(hhid.y) ~ 0,
        TRUE ~ NA_real_
      )
    ) |>
    dplyr::select(hhid = hhid.x, nonfarm_enterprise) |>
    dplyr::distinct()
  
  haven::write_dta(nfe_data, file.path(temp_dir, "nfe.dta"))
  cat("  ✓ nonfarm_enterprise saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in non-farm enterprise: ", e$message, "\n")
})

# 4.17 Agricultural asset index
tryCatch({
  cat("  Calculating agricultural asset index...\n")
  
  items_data <- read_dta_auto("secta4_harvestw3", input_dir, temp_dir)
  
  items_data <- items_data |>
    dplyr::filter(!item_cd %in% c(313, 314, 315, 316, 317, 3221, 3222, 3223, 3224))
  
  items_data <- items_data |>
    dplyr::mutate(
      hh_owns_ = 0,
      hh_owns_ = ifelse(!is.na(sa4q2a) & sa4q2a != 0, 1, hh_owns_),
      hh_owns_ = ifelse(!is.na(sa4q2b) & sa4q2b != 0, 1, hh_owns_),
      hh_owns_ = ifelse(!is.na(sa4q2c) & sa4q2c != 0, 1, hh_owns_),
      hh_owns_ = ifelse(!is.na(sa4q2d) & sa4q2d != 0, 1, hh_owns_)
    ) |>
    dplyr::select(hhid, item_cd, hh_owns_)
  
  items_wide <- items_data |>
    tidyr::pivot_wider(id_cols = hhid, names_from = item_cd, values_from = hh_owns_, names_prefix = "hh_owns_")
  
  items_wide <- items_wide |>
    dplyr::mutate(dplyr::across(starts_with("hh_owns_"), ~ ifelse(is.na(.), 0, .)))
  
  items_matrix <- items_wide |>
    dplyr::select(-hhid) |>
    as.matrix()
  
  items_matrix <- items_matrix[, apply(items_matrix, 2, var, na.rm = TRUE) > 0]
  
  if (ncol(items_matrix) > 1) {
    fa_result <- psych::fa(items_matrix, nfactors = 1, rotate = "none", fm = "pa")
    ag_asset_index <- data.frame(
      hhid = items_wide$hhid,
      ag_asset_index = as.numeric(fa_result$scores)
    )
  } else {
    ag_asset_index <- data.frame(
      hhid = items_wide$hhid,
      ag_asset_index = NA
    )
  }
  
  haven::write_dta(ag_asset_index, file.path(temp_dir, "ag_asset_index.dta"))
  cat("  ✓ ag_asset_index saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in agricultural asset index: ", e$message, "\n")
})

# 4.18 Household asset index
tryCatch({
  cat("  Calculating household asset index...\n")
  
  items_hh_data <- read_dta_auto("sect5_plantingw3", input_dir, temp_dir)
  
  items_hh_data <- items_hh_data |>
    dplyr::filter(item_cd <= 331) |>
    dplyr::mutate(
      hh_owns = dplyr::case_when(
        s5q1 == 0 ~ 0,
        is.na(s5q1) ~ NA_real_,
        TRUE ~ 1
      )
    ) |>
    dplyr::select(hhid, item_cd, hh_owns)
  
  items_hh_wide <- items_hh_data |>
    tidyr::pivot_wider(id_cols = hhid, names_from = item_cd, values_from = hh_owns, names_prefix = "hh_owns_")
  
  items_hh_wide <- items_hh_wide |>
    dplyr::mutate(dplyr::across(starts_with("hh_owns_"), ~ ifelse(is.na(.), 0, .)))
  
  items_hh_matrix <- items_hh_wide |>
    dplyr::select(-hhid) |>
    as.matrix()
  
  items_hh_matrix <- items_hh_matrix[, apply(items_hh_matrix, 2, var, na.rm = TRUE) > 0]
  
  if (ncol(items_hh_matrix) > 1) {
    fa_result_hh <- psych::fa(items_hh_matrix, nfactors = 1, rotate = "none", fm = "pa")
    hh_asset_index <- data.frame(
      hhid = items_hh_wide$hhid,
      hh_asset_index = as.numeric(fa_result_hh$scores)
    )
  } else {
    hh_asset_index <- data.frame(
      hhid = items_hh_wide$hhid,
      hh_asset_index = NA
    )
  }
  
  haven::write_dta(hh_asset_index, file.path(temp_dir, "hh_asset_index.dta"))
  cat("  ✓ hh_asset_index saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in household asset index: ", e$message, "\n")
})

# 4.19 Tractor ownership
tryCatch({
  cat("  Extracting tractor ownership...\n")
  
  lab_roster1_data <- read_dta_auto("sect11c1_plantingw3", input_dir, temp_dir)
  
  tractor_data <- lab_roster1_data |>
    dplyr::mutate(tractor = dplyr::case_when(
      s11c1q11 == 1 ~ 1,
      s11c1q11 == 2 ~ 0,
      TRUE ~ NA_real_
    )) |>
    dplyr::group_by(hhid) |>
    dplyr::summarise(tractor = max(tractor, na.rm = TRUE), .groups = "drop") |>
    dplyr::mutate(tractor = ifelse(is.infinite(tractor), NA, tractor))
  
  haven::write_dta(tractor_data, file.path(temp_dir, "tractor.dta"))
  cat("  ✓ tractor saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in tractor ownership: ", e$message, "\n")
})

# 4.20 Respondent characteristics
tryCatch({
  cat("  Extracting respondent characteristics...\n")
  
  tenure_data <- read_dta_auto("sect11b1_plantingw3", input_dir, temp_dir)
  plot_roster_data <- read_dta_auto("sect11a1_plantingw3", input_dir, temp_dir)
  
  respondent_ids <- tenure_data |>
    dplyr::left_join(plot_roster_data, by = c("hhid", "plotid")) |>
    dplyr::mutate(
      respondent_id = s11b1q2,
      respondent_id = ifelse(s11b1q1 == 1, s11aq6a, respondent_id),
      respondent_id = ifelse(is.na(s11aq6a), s11aq6b, respondent_id)
    ) |>
    dplyr::group_by(hhid) |>
    dplyr::summarise(respondent_id = dplyr::first(respondent_id), .groups = "drop")
  
  indiv0_data <- read_dta_auto("sect1_harvestw3", input_dir, temp_dir)
  
  resp_chars1 <- indiv0_data |>
    dplyr::rename(id = indiv) |>
    dplyr::inner_join(respondent_ids, by = c("hhid", "id" = "respondent_id")) |>
    dplyr::mutate(
      female_respondent = dplyr::case_when(
        s1q2 == 2 ~ 1,
        s1q2 == 1 ~ 0,
        TRUE ~ NA_real_
      ),
      age_respondent = ifelse(s1q4 == 999, NA, s1q4),
      married_respondent = dplyr::case_when(
        s1q7 %in% c(1, 2) ~ 1,
        s1q7 %in% c(3:7) ~ 0,
        TRUE ~ NA_real_
      )
    ) |>
    dplyr::mutate(respondent_id = paste(hhid, id, sep = "-")) |>
    dplyr::select(hhid, female_respondent, age_respondent, married_respondent, respondent_id) |>
    dplyr::distinct()
  
  indiv_roster1_data <- read_dta_auto("sect2_harvestw3", input_dir, temp_dir)
  
  resp_chars2 <- indiv_roster1_data |>
    dplyr::rename(id = indiv) |>
    dplyr::inner_join(respondent_ids, by = c("hhid", "id" = "respondent_id")) |>
    dplyr::mutate(
      formal_education_respondent1 = dplyr::case_when(
        s2aq6 == 1 ~ 1,
        s2aq6 == 2 ~ 0,
        TRUE ~ NA_real_
      ),
      primary_education_respondent1 = dplyr::case_when(
        s2aq9 >= 16 & s2aq9 <= 43 ~ 1,
        s2aq9 %in% c(0:15, 51:61) ~ 0,
        TRUE ~ NA_real_
      ),
      primary_education_respondent1 = ifelse(s2aq6 == 2, 0, primary_education_respondent1)
    ) |>
    dplyr::group_by(hhid) |>
    dplyr::summarise(
      formal_education_respondent = max(formal_education_respondent1, na.rm = TRUE),
      primary_education_respondent = max(primary_education_respondent1, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      formal_education_respondent = ifelse(is.infinite(formal_education_respondent), NA, formal_education_respondent),
      primary_education_respondent = ifelse(is.infinite(primary_education_respondent), NA, primary_education_respondent)
    )
  
  resp_chars <- resp_chars1 |>
    dplyr::left_join(resp_chars2, by = "hhid")
  
  haven::write_dta(resp_chars, file.path(temp_dir, "respondent_characteristics.dta"))
  cat("  ✓ respondent characteristics saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in respondent characteristics: ", e$message, "\n")
})

# 4.21 Geographic variables
tryCatch({
  cat("  Extracting geographic variables...\n")
  
  geovars_hh_data <- read_dta_auto("NGA_HouseholdGeovars_Y3", 
                                   file.path(Input_path, country, wave), 
                                   temp_dir)
  
  coords_data <- geovars_hh_data |>
    dplyr::rename(lat_modified = LAT_DD_MOD, lon_modified = LON_DD_MOD) |>
    dplyr::select(hhid, lat_modified, lon_modified) |>
    dplyr::distinct()
  
  haven::write_dta(coords_data, file.path(temp_dir, "Coords.dta"))
  
  aez_data <- geovars_hh_data |>
    dplyr::rename(agro_ecological_zone = ssa_aez09) |>
    dplyr::select(hhid, agro_ecological_zone) |>
    dplyr::distinct()
  
  haven::write_dta(aez_data, file.path(temp_dir, "aez.dta"))
  
  dist_road_data <- geovars_hh_data |>
    dplyr::rename(dist_road = dist_road2) |>
    dplyr::select(hhid, dist_road) |>
    dplyr::distinct()
  
  haven::write_dta(dist_road_data, file.path(temp_dir, "dist_road.dta"))
  
  dist_popcenter_data <- geovars_hh_data |>
    dplyr::rename(dist_popcenter = dist_popcenter2) |>
    dplyr::select(hhid, dist_popcenter) |>
    dplyr::distinct()
  
  haven::write_dta(dist_popcenter_data, file.path(temp_dir, "dist_popcenter.dta"))
  
  dist_market_data <- geovars_hh_data |>
    dplyr::rename(ea_id = ea) |>
    dplyr::select(hhid, dist_market) |>
    dplyr::distinct()
  
  haven::write_dta(dist_market_data, file.path(temp_dir, "dist_market.dta"))
  
  popdensity_data <- geovars_hh_data |>
    dplyr::select(hhid, popdensity) |>
    dplyr::mutate(popdensity = as.character(popdensity)) |>
    dplyr::distinct()
  
  haven::write_dta(popdensity_data, file.path(temp_dir, "popdensity.dta"))
  
  # Soil variables
  soil_data <- geovars_hh_data |>
    dplyr::rename(ea_id = ea) |>
    dplyr::mutate(dplyr::across(starts_with("sq"), 
                                ~ dplyr::case_when(. == 1 ~ 1, 
                                                   . %in% 2:7 ~ 0,
                                                   TRUE ~ NA_real_),
                                .names = "{.col}_d"))
  
  soil_data <- soil_data |>
    dplyr::rename(
      nutrient_availability = sq1_d,
      nutrient_retention = sq2_d,
      rooting_conditions = sq3_d,
      oxygen_availability = sq4_d,
      excess_salts = sq5_d,
      toxicity = sq6_d,
      workability = sq7_d
    )
  
  soil_matrix <- soil_data |>
    dplyr::select(nutrient_availability, nutrient_retention, rooting_conditions,
                  oxygen_availability, excess_salts, toxicity, workability) |>
    as.matrix()
  
  soil_matrix <- soil_matrix[, apply(soil_matrix, 2, var, na.rm = TRUE) > 0]
  
  if (ncol(soil_matrix) > 1) {
    fa_soil <- psych::fa(soil_matrix, nfactors = 1, rotate = "none", fm = "pa")
    soil_fertility <- data.frame(
      hhid = soil_data$hhid,
      soil_fertility_index = as.numeric(fa_soil$scores)
    )
    soil_data <- soil_data |>
      dplyr::select(-starts_with("sq")) |>
      dplyr::left_join(soil_fertility, by = "hhid")
  } else {
    soil_data <- soil_data |>
      dplyr::select(-starts_with("sq")) |>
      dplyr::mutate(soil_fertility_index = NA)
  }
  
  haven::write_dta(soil_data, file.path(temp_dir, "soil.dta"))
  cat("  ✓ geographic variables saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in geographic variables: ", e$message, "\n")
})

# ==============================================================================
# 5. PLOT-LEVEL VARIABLES
# ==============================================================================

message("Extracting plot-level variables...")

# 5.1 Plot area (with imputation)
tryCatch({
  cat("  Calculating plot area...\n")
  
  plot_roster_data <- read_dta_auto("sect11a1_plantingw3", input_dir, temp_dir)
  
  plot_area_data <- plot_roster_data |>
    dplyr::rename(admin_1 = zone, admin_2 = state, admin_3 = lga) |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::mutate(
      area_self_reported = s11aq4a,
      area_self_reported = ifelse(s11aq4b == 4, area_self_reported * 0.0667, area_self_reported),
      area_self_reported = ifelse(s11aq4b == 5, area_self_reported * 0.4, area_self_reported),
      area_self_reported = ifelse(s11aq4b == 7, area_self_reported * 0.0001, area_self_reported),
      
      area_self_reported = ifelse(s11aq4b == 1 & admin_1 == 1, area_self_reported * 0.00012, area_self_reported),
      area_self_reported = ifelse(s11aq4b == 1 & admin_1 == 2, area_self_reported * 0.00016, area_self_reported),
      area_self_reported = ifelse(s11aq4b == 1 & admin_1 == 3, area_self_reported * 0.00011, area_self_reported),
      area_self_reported = ifelse(s11aq4b == 1 & admin_1 == 4, area_self_reported * 0.00019, area_self_reported),
      area_self_reported = ifelse(s11aq4b == 1 & admin_1 == 5, area_self_reported * 0.00021, area_self_reported),
      area_self_reported = ifelse(s11aq4b == 1 & admin_1 == 6, area_self_reported * 0.00012, area_self_reported),
      
      area_self_reported = ifelse(s11aq4b == 2 & admin_1 == 1, area_self_reported * 0.0027, area_self_reported),
      area_self_reported = ifelse(s11aq4b == 2 & admin_1 == 2, area_self_reported * 0.004, area_self_reported),
      area_self_reported = ifelse(s11aq4b == 2 & admin_1 == 3, area_self_reported * 0.00494, area_self_reported),
      area_self_reported = ifelse(s11aq4b == 2 & admin_1 == 4, area_self_reported * 0.0023, area_self_reported),
      area_self_reported = ifelse(s11aq4b == 2 & admin_1 == 5, area_self_reported * 0.0023, area_self_reported),
      area_self_reported = ifelse(s11aq4b == 2 & admin_1 == 6, area_self_reported * 0.00001, area_self_reported),
      
      area_self_reported = ifelse(s11aq4b == 3 & admin_1 == 1, area_self_reported * 0.00006, area_self_reported),
      area_self_reported = ifelse(s11aq4b == 3 & admin_1 == 2, area_self_reported * 0.00016, area_self_reported),
      area_self_reported = ifelse(s11aq4b == 3 & admin_1 == 3, area_self_reported * 0.00004, area_self_reported),
      area_self_reported = ifelse(s11aq4b == 3 & admin_1 == 4, area_self_reported * 0.00004, area_self_reported),
      area_self_reported = ifelse(s11aq4b == 3 & admin_1 == 5, area_self_reported * 0.00013, area_self_reported),
      area_self_reported = ifelse(s11aq4b == 3 & admin_1 == 6, area_self_reported * 0.00041, area_self_reported),
      
      plot_area_GPS = s11aq4c * 0.0001
    ) |>
    dplyr::left_join(admin3_data, by = "hhid")
  
  # Simple imputation
  plot_area_data <- plot_area_data |>
    dplyr::group_by(hhid) |>
    dplyr::mutate(
      plot_area_GPS = ifelse(is.na(plot_area_GPS), 
                             median(plot_area_GPS, na.rm = TRUE), 
                             plot_area_GPS),
      farm_size = sum(plot_area_GPS, na.rm = TRUE)
    ) |>
    dplyr::ungroup() |>
    dplyr::select(hhid, plot_id, plot_area_GPS, farm_size) |>
    dplyr::distinct()
  
  haven::write_dta(plot_area_data, file.path(temp_dir, "plot_area.dta"))
  cat("  ✓ plot_area saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in plot area: ", e$message, "\n")
})

# 5.2 Planting month
tryCatch({
  cat("  Extracting planting month...\n")
  
  perennial_data <- read_dta_auto("sect11f_plantingw3", input_dir, temp_dir)
  
  planting_month_plot <- perennial_data |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::mutate(
      month = s11fq3a,
      year = s11fq3b
    ) |>
    dplyr::mutate(planting_month = lubridate::ymd(paste(year, month, "01", sep = "-"))) |>
    dplyr::group_by(hhid, cropcode, plot_id) |>
    dplyr::summarise(planting_month = min(planting_month, na.rm = TRUE), .groups = "drop")
  
  haven::write_dta(planting_month_plot, file.path(temp_dir, "planting_month.dta"))
  cat("  ✓ planting_month saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in planting month: ", e$message, "\n")
})

# 5.3 Harvest end month
tryCatch({
  cat("  Extracting harvest end month...\n")
  
  harvest_raw <- read_dta_auto("secta3i_harvestw3", input_dir, temp_dir)
  
  harvest_end_month_plot <- harvest_raw |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::mutate(
      month = sa3iq6c1,
      year = sa3iq6c2
    ) |>
    dplyr::mutate(harvest_end_month = lubridate::ymd(paste(year, month, "01", sep = "-"))) |>
    dplyr::group_by(plot_id, cropcode) |>
    dplyr::summarise(harvest_end_month = max(harvest_end_month, na.rm = TRUE), .groups = "drop")
  
  haven::write_dta(harvest_end_month_plot, file.path(temp_dir, "harvest_end_month.dta"))
  cat("  ✓ harvest_end_month saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in harvest end month: ", e$message, "\n")
})

# 5.4 Intercropped
tryCatch({
  cat("  Extracting intercropped status...\n")
  
  perennial_data <- read_dta_auto("sect11f_plantingw3", input_dir, temp_dir)
  
  intercropped_data <- perennial_data |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::mutate(intercropped = dplyr::case_when(
      s11fq2 == 1 ~ 0,
      s11fq2 %in% 2:6 ~ 1,
      TRUE ~ NA_real_
    )) |>
    dplyr::group_by(plot_id) |>
    dplyr::summarise(intercropped = max(intercropped, na.rm = TRUE), .groups = "drop") |>
    dplyr::mutate(intercropped = ifelse(is.infinite(intercropped), NA, intercropped))
  
  haven::write_dta(intercropped_data, file.path(temp_dir, "intercropped.dta"))
  cat("  ✓ intercropped saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in intercropped: ", e$message, "\n")
})

# 5.5 Number of seasonal crops
tryCatch({
  cat("  Calculating number of seasonal crops...\n")
  
  harvest_raw <- read_dta_auto("secta3i_harvestw3", input_dir, temp_dir)
  
  nb_crops_data <- harvest_raw |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::group_by(plot_id) |>
    dplyr::summarise(nb_seasonal_crop = dplyr::n_distinct(cropcode), .groups = "drop")
  
  haven::write_dta(nb_crops_data, file.path(temp_dir, "nb_seasonal_crop.dta"))
  cat("  ✓ nb_seasonal_crop saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in nb_seasonal_crop: ", e$message, "\n")
})

# 5.6 Improved seed varieties
tryCatch({
  cat("  Extracting improved seed status...\n")
  
  seeds_data <- read_dta_auto("sect11e_plantingw3", input_dir, temp_dir)
  
  improved_data <- seeds_data |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::mutate(improved = dplyr::case_when(
      s11eq3b %in% c(3, 4) ~ 0,
      s11eq3b %in% c(1, 2) ~ 1,
      TRUE ~ NA_real_
    )) |>
    dplyr::group_by(hhid, plot_id, cropcode) |>
    dplyr::summarise(improved = max(improved, na.rm = TRUE), .groups = "drop") |>
    dplyr::mutate(improved = ifelse(is.infinite(improved), NA, improved))
  
  haven::write_dta(improved_data, file.path(temp_dir, "improved.dta"))
  cat("  ✓ improved saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in improved seeds: ", e$message, "\n")
})

# 5.7 Plot ownership
tryCatch({
  cat("  Extracting plot ownership...\n")
  
  tenure_data <- read_dta_auto("sect11b1_plantingw3", input_dir, temp_dir)
  
  plot_owned_data <- tenure_data |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::mutate(
      plot_owned = dplyr::case_when(
        s11b1q4 %in% c(1, 4, 5) ~ 1,
        s11b1q4 %in% c(2, 3) ~ 0,
        s11b1q4 == 6 ~ NA_real_,
        TRUE ~ NA_real_
      ),
      plot_certificate = dplyr::case_when(
        s11b1q7 == 1 ~ 1,
        s11b1q7 == 2 ~ 0,
        s11b1q7 == 3 ~ NA_real_,
        TRUE ~ NA_real_
      ),
      plot_certificate = ifelse(plot_owned == 0 | s11b1q4 == 4, 0, plot_certificate)
    ) |>
    dplyr::select(plot_id, plot_owned, plot_certificate) |>
    dplyr::distinct()
  
  haven::write_dta(plot_owned_data, file.path(temp_dir, "plot_owned.dta"))
  cat("  ✓ plot_owned saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in plot ownership: ", e$message, "\n")
})

# 5.8 Irrigated
tryCatch({
  cat("  Extracting irrigation status...\n")
  
  tenure_data <- read_dta_auto("sect11b1_plantingw3", input_dir, temp_dir)
  
  irrigated_data <- tenure_data |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::mutate(irrigated = dplyr::case_when(
      s11b1q39 == 1 ~ 1,
      s11b1q39 == 2 ~ 0,
      TRUE ~ NA_real_
    )) |>
    dplyr::select(plot_id, irrigated) |>
    dplyr::distinct()
  
  haven::write_dta(irrigated_data, file.path(temp_dir, "irrigated.dta"))
  cat("  ✓ irrigated saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in irrigation: ", e$message, "\n")
})

# 5.9 Erosion protection
tryCatch({
  cat("  Extracting erosion protection...\n")
  
  tenure_data <- read_dta_auto("sect11b1_plantingw3", input_dir, temp_dir)
  
  erosion_data <- tenure_data |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::mutate(erosion_protection = dplyr::case_when(
      s11b1q49 == 1 ~ 1,
      s11b1q49 == 2 ~ 0,
      TRUE ~ NA_real_
    )) |>
    dplyr::select(plot_id, erosion_protection) |>
    dplyr::distinct()
  
  haven::write_dta(erosion_data, file.path(temp_dir, "erosion_protection.dta"))
  cat("  ✓ erosion_protection saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in erosion protection: ", e$message, "\n")
})

# 5.10 Fallow plots and number of plots
tryCatch({
  cat("  Calculating fallow plots and number of plots...\n")
  
  tenure_data <- read_dta_auto("sect11b1_plantingw3", input_dir, temp_dir)
  
  fallow_data <- tenure_data |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::mutate(
      fallow_plot = dplyr::case_when(
        s11b1q28 == 1 ~ 1,
        !is.na(s11b1q28) & s11b1q28 != 1 ~ 0,
        TRUE ~ NA_real_
      ),
      fallow_plot = ifelse(s11b1q27 == 1, 0, fallow_plot)
    ) |>
    dplyr::group_by(hhid) |>
    dplyr::summarise(
      nb_fallow_plots = sum(fallow_plot == 1, na.rm = TRUE),
      nb_plots = dplyr::n(),
      .groups = "drop"
    ) |>
    dplyr::left_join(cover1_data |> dplyr::select(hhid), by = "hhid") |>
    dplyr::mutate(
      nb_fallow_plots = ifelse(is.na(hhid.y), 0, nb_fallow_plots),
      nb_plots = ifelse(is.na(hhid.y), 0, nb_plots)
    ) |>
    dplyr::select(hhid = hhid.x, nb_fallow_plots, nb_plots)
  
  haven::write_dta(fallow_data |> dplyr::select(hhid, nb_fallow_plots), 
                   file.path(temp_dir, "nb_fallow_plots.dta"))
  haven::write_dta(fallow_data |> dplyr::select(hhid, nb_plots), 
                   file.path(temp_dir, "nb_plots.dta"))
  cat("  ✓ fallow plots saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in fallow plots: ", e$message, "\n")
})

# 5.11 Manager characteristics
tryCatch({
  cat("  Extracting manager characteristics...\n")
  
  plot_roster_data <- read_dta_auto("sect11a1_plantingw3", input_dir, temp_dir)
  indiv0_data <- read_dta_auto("sect1_harvestw3", input_dir, temp_dir)
  indiv_roster1_data <- read_dta_auto("sect2_harvestw3", input_dir, temp_dir)
  
  manager_ids <- plot_roster_data |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::mutate(
      manager_id = s11aq6a,
      manager_id = ifelse(is.na(s11aq6a), s11aq6b, manager_id)
    ) |>
    dplyr::arrange(hhid, manager_id) |>
    dplyr::group_by(hhid, plot_id) |>
    dplyr::summarise(manager_id = dplyr::first(manager_id), .groups = "drop")
  
  manager_chars1 <- indiv0_data |>
    dplyr::rename(id = indiv) |>
    dplyr::inner_join(manager_ids, by = c("hhid", "id" = "manager_id")) |>
    dplyr::mutate(
      female_manager = dplyr::case_when(
        s1q2 == 2 ~ 1,
        s1q2 == 1 ~ 0,
        TRUE ~ NA_real_
      ),
      age_manager = ifelse(s1q4 == 999, NA, s1q4),
      married_manager = dplyr::case_when(
        s1q7 %in% c(1, 2) ~ 1,
        s1q7 %in% c(3:7) ~ 0,
        TRUE ~ NA_real_
      )
    ) |>
    dplyr::mutate(manager_id = paste(hhid, id, sep = "-")) |>
    dplyr::select(plot_id, female_manager, age_manager, married_manager, manager_id) |>
    dplyr::distinct()
  
  manager_chars2 <- indiv_roster1_data |>
    dplyr::rename(id = indiv) |>
    dplyr::inner_join(manager_ids, by = c("hhid", "id" = "manager_id")) |>
    dplyr::mutate(
      formal_education_manager1 = dplyr::case_when(
        s2aq6 == 1 ~ 1,
        s2aq6 == 2 ~ 0,
        TRUE ~ NA_real_
      ),
      primary_education_manager1 = dplyr::case_when(
        s2aq9 >= 16 & s2aq9 <= 43 ~ 1,
        s2aq9 %in% c(0:15, 51:61) ~ 0,
        TRUE ~ NA_real_
      ),
      primary_education_manager1 = ifelse(s2aq6 == 2, 0, primary_education_manager1)
    ) |>
    dplyr::group_by(plot_id) |>
    dplyr::summarise(
      formal_education_manager = max(formal_education_manager1, na.rm = TRUE),
      primary_education_manager = max(primary_education_manager1, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      formal_education_manager = ifelse(is.infinite(formal_education_manager), NA, formal_education_manager),
      primary_education_manager = ifelse(is.infinite(primary_education_manager), NA, primary_education_manager)
    )
  
  manager_chars <- manager_chars1 |>
    dplyr::left_join(manager_chars2, by = "plot_id")
  
  haven::write_dta(manager_chars, file.path(temp_dir, "Manager_characteristics.dta"))
  cat("  ✓ manager characteristics saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in manager characteristics: ", e$message, "\n")
})

# 5.12 Plot geographic variables
tryCatch({
  cat("  Extracting plot geographic variables...\n")
  
  geovars_data <- read_dta_auto("NGA_PlotGeovariables_Y3", 
                                file.path(Input_path, country, wave), 
                                temp_dir)
  
  plot_geo_data <- geovars_data |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::rename(
      plot_slope = srtmslp_nga,
      elevation = srtm_nga,
      twi = twi_nga
    ) |>
    dplyr::select(plot_id, plot_slope, elevation, twi) |>
    dplyr::distinct()
  
  haven::write_dta(plot_geo_data |> dplyr::select(plot_id, plot_slope), 
                   file.path(temp_dir, "plot_slope.dta"))
  haven::write_dta(plot_geo_data |> dplyr::select(plot_id, elevation), 
                   file.path(temp_dir, "elevation.dta"))
  haven::write_dta(plot_geo_data |> dplyr::select(plot_id, twi), 
                   file.path(temp_dir, "twi.dta"))
  cat("  ✓ plot geographic variables saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in plot geographic variables: ", e$message, "\n")
})

# ==============================================================================
# 6. CROP-LEVEL VARIABLES
# ==============================================================================

message("Extracting crop-level variables...")

# 6.1 Harvest kg and conversion factors
tryCatch({
  cat("  Calculating harvest kg...\n")
  
  conversions_data <- read_dta_auto("ag_conv_w3", input_dir, temp_dir)
  
  # Reshape conversions to long format
  conversions_long <- conversions_data |>
    dplyr::rename(
      conv_1 = conv_NC_1,
      conv_2 = conv_NE_2,
      conv_3 = conv_NW_3,
      conv_4 = conv_SE_4,
      conv_5 = conv_SS_5,
      conv_6 = conv_SW_6
    ) |>
    dplyr::filter(!unit_cd %in% c(190, 191, 192, 3)) |>
    dplyr::select(unit_cd, crop_cd, starts_with("conv_")) |>
    tidyr::pivot_longer(cols = starts_with("conv_"), 
                        names_to = "admin_1", 
                        values_to = "conv_") |>
    dplyr::mutate(admin_1 = as.numeric(stringr::str_extract(admin_1, "\\d+"))) |>
    dplyr::filter(!is.na(conv_))
  
  harvest_raw <- read_dta_auto("secta3i_harvestw3", input_dir, temp_dir)
  
  # Add admin levels
  harvest_data <- harvest_raw |>
    dplyr::left_join(admin1_data, by = "hhid") |>
    dplyr::left_join(admin2_data, by = "hhid") |>
    dplyr::left_join(admin3_data, by = "hhid") |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::rename(crop_cd = cropcode) |>
    dplyr::rename(unit_cd = sa3iq6ii) |>
    dplyr::mutate(
      any_harvest = dplyr::case_when(
        sa3iq3 == 1 ~ 1,
        sa3iq3 == 2 ~ 0,
        TRUE ~ NA_real_
      )
    )
  
  # Merge with conversions
  harvest_kg_temp <- harvest_data |>
    dplyr::left_join(conversions_long, by = c("crop_cd", "unit_cd", "admin_1")) |>
    dplyr::mutate(
      harvest_kg_temp = sa3iq6i * conv_,
      harvest_kg_temp = ifelse(any_harvest == 0, 0, harvest_kg_temp)
    ) |>
    dplyr::select(-conv_, -unit_cd)
  
  # Expected harvest
  harvest_kg_expected <- harvest_data |>
    dplyr::rename(unit_cd = sa3iq6d2) |>
    dplyr::left_join(conversions_long, by = c("crop_cd", "unit_cd", "admin_1")) |>
    dplyr::mutate(
      harvest_kg_expected = sa3iq6d1 * conv_
    ) |>
    dplyr::select(-conv_, -unit_cd)
  
  # Combine
  harvest_combined <- harvest_kg_temp |>
    dplyr::left_join(harvest_kg_expected, 
                     by = c("hhid", "plot_id", "crop_cd", "admin_1", "admin_2", "admin_3", "any_harvest")) |>
    dplyr::mutate(
      harvest_kg = dplyr::coalesce(harvest_kg_temp, harvest_kg_expected),
      crop_shock = dplyr::case_when(
        sa3iq3 == 2 ~ 1,
        sa3iq3 == 1 ~ 0,
        TRUE ~ NA_real_
      ),
      crop_shock = ifelse(sa3iq4 == 9 | sa3iq4 == 10, 0, crop_shock),
      harvest_kg = ifelse(harvest_kg == 0 & crop_shock != 1, NA, harvest_kg)
    ) |>
    dplyr::rename(cropcode = crop_cd)
  
  harvest_kg_data <- harvest_combined |>
    dplyr::group_by(plot_id, cropcode, admin_1, admin_2, admin_3, hhid) |>
    dplyr::summarise(
      harvest_kg = sum(harvest_kg, na.rm = TRUE),
      n_harvest_kg = sum(!is.na(harvest_kg)),
      .groups = "drop"
    ) |>
    dplyr::mutate(harvest_kg = ifelse(n_harvest_kg == 0, NA, harvest_kg))
  
  haven::write_dta(harvest_kg_data, file.path(temp_dir, "harvest_kg.dta"))
  cat("  ✓ harvest_kg saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in harvest kg: ", e$message, "\n")
})

# 6.2 Crop shock
tryCatch({
  cat("  Extracting crop shocks...\n")
  
  harvest_raw <- read_dta_auto("secta3i_harvestw3", input_dir, temp_dir)
  
  crop_shock_data <- harvest_raw |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::mutate(
      crop_shock = dplyr::case_when(
        sa3iq3 == 2 ~ 1,
        sa3iq3 == 1 ~ 0,
        TRUE ~ NA_real_
      ),
      crop_shock = ifelse(sa3iq4 == 9 | sa3iq4 == 10, 0, crop_shock),
      
      drought_shock = dplyr::case_when(
        sa3iq4 == 1 ~ 1,
        sa3iq4 %in% c(2:8, 11) ~ 0,
        sa3iq4 %in% c(9, 10) ~ NA_real_,
        TRUE ~ NA_real_
      ),
      drought_shock = ifelse(sa3iq3 == 1, 0, drought_shock),
      
      flood_shock = dplyr::case_when(
        sa3iq4 == 2 ~ 1,
        sa3iq4 %in% c(1, 3:8, 11) ~ 0,
        sa3iq4 %in% c(9, 10) ~ NA_real_,
        TRUE ~ NA_real_
      ),
      flood_shock = ifelse(sa3iq3 == 1, 0, flood_shock),
      
      pests_shock = dplyr::case_when(
        sa3iq4 == 3 ~ 1,
        sa3iq4 %in% c(1, 2, 4:8, 11) ~ 0,
        sa3iq4 %in% c(9, 10) ~ NA_real_,
        TRUE ~ NA_real_
      ),
      pests_shock = ifelse(sa3iq3 == 1, 0, pests_shock)
    ) |>
    dplyr::group_by(hhid, plot_id, cropcode) |>
    dplyr::summarise(
      crop_shock = max(crop_shock, na.rm = TRUE),
      drought_shock = max(drought_shock, na.rm = TRUE),
      flood_shock = max(flood_shock, na.rm = TRUE),
      pests_shock = max(pests_shock, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(dplyr::across(everything(), ~ ifelse(is.infinite(.), NA, .)))
  
  haven::write_dta(crop_shock_data, file.path(temp_dir, "crop_shock.dta"))
  cat("  ✓ crop_shock saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in crop shocks: ", e$message, "\n")
})

# 6.3 Harvest sold kg
tryCatch({
  cat("  Calculating harvest sold kg...\n")
  
  conversions_data <- read_dta_auto("ag_conv_w3", input_dir, temp_dir)
  
  conversions_sold <- conversions_data |>
    dplyr::rename(
      conv_1 = conv_NC_1,
      conv_2 = conv_NE_2,
      conv_3 = conv_NW_3,
      conv_4 = conv_SE_4,
      conv_5 = conv_SS_5,
      conv_6 = conv_SW_6
    ) |>
    dplyr::filter(!unit_cd %in% c(190, 191, 192, 3)) |>
    dplyr::select(unit_cd, crop_cd, starts_with("conv_")) |>
    tidyr::pivot_longer(cols = starts_with("conv_"), 
                        names_to = "admin_1", 
                        values_to = "conv_") |>
    dplyr::mutate(admin_1 = as.numeric(stringr::str_extract(admin_1, "\\d+"))) |>
    dplyr::filter(!is.na(conv_)) |>
    dplyr::rename(crop_cd = crop_cd)
  
  harvest_sold_raw <- read_dta_auto("secta3ii_harvestw3", input_dir, temp_dir)
  
  harvest_sold_kg_data <- harvest_sold_raw |>
    dplyr::rename(
      admin_1 = zone,
      admin_2 = state,
      admin_3 = lga,
      crop_cd = cropcode
    ) |>
    dplyr::rename(unit_cd = sa3iiq5b) |>
    dplyr::left_join(admin1_data, by = "hhid") |>
    dplyr::left_join(admin2_data, by = "hhid") |>
    dplyr::left_join(admin3_data, by = "hhid") |>
    dplyr::left_join(conversions_sold, by = c("admin_1", "crop_cd", "unit_cd")) |>
    dplyr::mutate(
      harvest_sold_kg = sa3iiq5a * conv_,
      harvest_sold_kg = ifelse(sa3iiq3 == 2, 0, harvest_sold_kg)
    ) |>
    dplyr::rename(cropcode = crop_cd) |>
    dplyr::group_by(cropcode, hhid, admin_1, admin_2, admin_3) |>
    dplyr::summarise(
      harvest_sold_kg = sum(harvest_sold_kg, na.rm = TRUE),
      n_harvest_sold_kg = sum(!is.na(harvest_sold_kg)),
      .groups = "drop"
    ) |>
    dplyr::mutate(harvest_sold_kg = ifelse(n_harvest_sold_kg == 0, NA, harvest_sold_kg))
  
  haven::write_dta(harvest_sold_kg_data, file.path(temp_dir, "harvest_sold_kg.dta"))
  
  # Household-level share
  harvest_sold_hh <- harvest_sold_kg_data |>
    dplyr::group_by(hhid) |>
    dplyr::summarise(
      harvest_sold_kg = sum(harvest_sold_kg, na.rm = TRUE),
      n_harvest_sold_kg = sum(!is.na(harvest_sold_kg)),
      .groups = "drop"
    ) |>
    dplyr::mutate(harvest_sold_kg = ifelse(n_harvest_sold_kg == 0, NA, harvest_sold_kg))
  
  harvest_kg_hh <- harvest_kg_data |>
    dplyr::group_by(hhid) |>
    dplyr::summarise(
      harvest_kg = sum(harvest_kg, na.rm = TRUE),
      n_harvest_kg = sum(!is.na(harvest_kg)),
      .groups = "drop"
    ) |>
    dplyr::mutate(harvest_kg = ifelse(n_harvest_kg == 0, NA, harvest_kg))
  
  share_sold <- harvest_sold_hh |>
    dplyr::full_join(harvest_kg_hh, by = "hhid") |>
    dplyr::mutate(
      share_kg_sold = harvest_sold_kg / harvest_kg,
      share_kg_sold = ifelse(share_kg_sold > 1, NA, share_kg_sold)
    ) |>
    dplyr::select(hhid, share_kg_sold) |>
    dplyr::distinct()
  
  haven::write_dta(share_sold, file.path(temp_dir, "harvest_sold_kg_hh.dta"))
  cat("  ✓ harvest_sold_kg saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in harvest sold kg: ", e$message, "\n")
})

# 6.4 Harvest sold value
tryCatch({
  cat("  Calculating harvest sold value...\n")
  
  harvest_sold_raw <- read_dta_auto("secta3ii_harvestw3", input_dir, temp_dir)
  
  harvest_sold_value_data <- harvest_sold_raw |>
    dplyr::rename(
      admin_1 = zone,
      admin_2 = state,
      admin_3 = lga,
      crop_cd = cropcode
    ) |>
    dplyr::rename(unit_cd = sa3iiq5b) |>
    dplyr::left_join(admin1_data, by = "hhid") |>
    dplyr::left_join(admin2_data, by = "hhid") |>
    dplyr::left_join(admin3_data, by = "hhid") |>
    dplyr::mutate(harvest_sold_value = sa3iiq6) |>
    dplyr::rename(cropcode = crop_cd) |>
    dplyr::group_by(cropcode, hhid, admin_1, admin_2, admin_3) |>
    dplyr::summarise(
      harvest_sold_value = sum(harvest_sold_value, na.rm = TRUE),
      n_harvest_sold_value = sum(!is.na(harvest_sold_value)),
      .groups = "drop"
    ) |>
    dplyr::mutate(harvest_sold_value = ifelse(n_harvest_sold_value == 0, NA, harvest_sold_value))
  
  haven::write_dta(harvest_sold_value_data, file.path(temp_dir, "harvest_sold_value.dta"))
  cat("  ✓ harvest_sold_value saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in harvest sold value: ", e$message, "\n")
})

# 6.5 Harvest value & main crop
tryCatch({
  cat("  Calculating harvest value and main crop...\n")
  
  harvest_sold_raw <- read_dta_auto("secta3ii_harvestw3", input_dir, temp_dir)
  
  harvest_data <- harvest_sold_raw |>
    dplyr::select(hhid, cropcode) |>
    dplyr::distinct()
  
  # Calculate harvest value using median crop prices
  harvest_value <- valuation_median_crops_noea_sort(
    data = harvest_data,
    temp_path = temp_dir,
    hhid_var = "hhid",
    cropvar_var = "cropcode"
  )
  
  # Add main crop
  harvest_value <- main_crop_def(
    data = harvest_value,
    cropvar_var = "cropcode"
  )
  
  harvest_value_out <- harvest_value |>
    dplyr::select(plot_id, harvest_value, cropcode, main_crop)
  
  haven::write_dta(harvest_value_out, file.path(temp_dir, "harvest_value.dta"))
  cat("  ✓ harvest_value saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in harvest value: ", e$message, "\n")
})

# 6.6 Seed kg
tryCatch({
  cat("  Calculating seed kg...\n")
  
  conversions_data <- read_dta_auto("ag_conv_w3", input_dir, temp_dir)
  
  conversions_seed <- conversions_data |>
    dplyr::rename(
      conv_1 = conv_NC_1,
      conv_2 = conv_NE_2,
      conv_3 = conv_NW_3,
      conv_4 = conv_SE_4,
      conv_5 = conv_SS_5,
      conv_6 = conv_SW_6
    ) |>
    dplyr::filter(!unit_cd %in% c(190, 191, 192, 3)) |>
    dplyr::select(unit_cd, crop_cd, starts_with("conv_")) |>
    tidyr::pivot_longer(cols = starts_with("conv_"), 
                        names_to = "admin_1", 
                        values_to = "conv_") |>
    dplyr::mutate(admin_1 = as.numeric(stringr::str_extract(admin_1, "\\d+"))) |>
    dplyr::filter(!is.na(conv_))
  
  conversions_seed_cropunit <- conversions_seed |>
    dplyr::group_by(crop_cd, unit_cd) |>
    dplyr::summarise(conv_ = stats::median(conv_, na.rm = TRUE), .groups = "drop")
  
  conversions_seed_unit <- conversions_seed |>
    dplyr::group_by(unit_cd) |>
    dplyr::summarise(conv_ = stats::median(conv_, na.rm = TRUE), .groups = "drop")
  
  seeds_data <- read_dta_auto("sect11e_plantingw3", input_dir, temp_dir)
  
  seed_kg_data <- seeds_data |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::rename(admin_1 = zone, admin_2 = state, admin_3 = lga, crop_cd = cropcode)
  
  # Leftover seeds
  seed_kg1 <- seed_kg_data |>
    dplyr::mutate(
      seed_kg_preconv = s11eq6a,
      unit_cd = s11eq6b
    ) |>
    dplyr::left_join(conversions_seed, by = c("crop_cd", "unit_cd", "admin_1")) |>
    dplyr::mutate(seed_kg1 = seed_kg_preconv * conv_) |>
    dplyr::select(-conv_)
  
  # Free seeds
  seed_kg2 <- seed_kg_data |>
    dplyr::mutate(
      seed_kg_preconv = s11eq10a,
      unit_cd = s11eq10b
    ) |>
    dplyr::left_join(conversions_seed, by = c("crop_cd", "unit_cd", "admin_1")) |>
    dplyr::mutate(seed_kg2 = seed_kg_preconv * conv_) |>
    dplyr::select(-conv_)
  
  # Commercial source 1
  seed_kg3 <- seed_kg_data |>
    dplyr::mutate(
      seed_kg_preconv = s11eq18a,
      unit_cd = s11eq18b
    ) |>
    dplyr::left_join(conversions_seed, by = c("crop_cd", "unit_cd", "admin_1")) |>
    dplyr::mutate(seed_kg3 = seed_kg_preconv * conv_) |>
    dplyr::select(-conv_)
  
  # Commercial source 2
  seed_kg4 <- seed_kg_data |>
    dplyr::mutate(
      seed_kg_preconv = s11eq30a,
      unit_cd = s11eq30b
    ) |>
    dplyr::left_join(conversions_seed, by = c("crop_cd", "unit_cd", "admin_1")) |>
    dplyr::mutate(seed_kg4 = seed_kg_preconv * conv_) |>
    dplyr::select(-conv_)
  
  # Combine
  seed_combined <- seed_kg1 |>
    dplyr::full_join(seed_kg2, by = names(seed_kg1)) |>
    dplyr::full_join(seed_kg3, by = names(seed_kg1)) |>
    dplyr::full_join(seed_kg4, by = names(seed_kg1)) |>
    dplyr::mutate(
      seed_kg = dplyr::coalesce(seed_kg1, seed_kg2, seed_kg3, seed_kg4),
      seed_kg = ifelse(s11eq3 == 2, 0, seed_kg)
    ) |>
    dplyr::rename(cropcode = crop_cd) |>
    dplyr::group_by(cropcode, hhid, plot_id, admin_1, admin_2, admin_3) |>
    dplyr::summarise(
      seed_kg = sum(seed_kg, na.rm = TRUE),
      n_seed_kg = sum(!is.na(seed_kg)),
      .groups = "drop"
    ) |>
    dplyr::mutate(seed_kg = ifelse(n_seed_kg == 0, NA, seed_kg))
  
  haven::write_dta(seed_combined, file.path(temp_dir, "seed_kg.dta"))
  haven::write_dta(seed_combined, file.path(temp_dir, "seed_kg_merge.dta"))
  cat("  ✓ seed_kg saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in seed kg: ", e$message, "\n")
})

# 6.7 Fertilizer variables
tryCatch({
  cat("  Extracting fertilizer variables...\n")
  
  ferts_data <- read_dta_auto("secta11d_harvestw3", input_dir, temp_dir)
  
  # Inorganic fertilizer
  inorganic_fert <- ferts_data |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::mutate(
      inorganic_fertilizer = dplyr::case_when(
        s11dq1a == 1 ~ 1,
        s11dq1a == 2 ~ 0,
        TRUE ~ NA_real_
      ),
      inorganic_fertilizer = ifelse(s11dq1 == 2, 0, inorganic_fertilizer)
    ) |>
    dplyr::select(plot_id, inorganic_fertilizer) |>
    dplyr::distinct()
  
  haven::write_dta(inorganic_fert, file.path(temp_dir, "inorganic_fertilizer.dta"))
  
  # Organic fertilizer
  organic_fert <- ferts_data |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::mutate(
      organic_fertilizer = dplyr::case_when(
        s11dq36 == 1 ~ 1,
        s11dq36 == 2 ~ 0,
        TRUE ~ NA_real_
      ),
      organic_fertilizer = ifelse(s11dq1 == 2, 0, organic_fertilizer)
    ) |>
    dplyr::group_by(plot_id) |>
    dplyr::summarise(organic_fertilizer = max(organic_fertilizer, na.rm = TRUE), .groups = "drop") |>
    dplyr::mutate(organic_fertilizer = ifelse(is.infinite(organic_fertilizer), NA, organic_fertilizer))
  
  haven::write_dta(organic_fert, file.path(temp_dir, "organic_fertilizer.dta"))
  
  # Nitrogen kg
  nitrogen_kg <- ferts_data |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::mutate(
      UREA_kg = dplyr::case_when(
        s11dq3 == 2 ~ s11dq4a,
        s11dq7 == 2 ~ sect11dq8a,
        s11dq15 == 2 ~ s11dq16a,
        s11dq27 == 2 ~ s11dq28a,
        TRUE ~ 0
      ),
      NPK_kg = dplyr::case_when(
        s11dq3 == 1 ~ s11dq4a,
        s11dq7 == 1 ~ sect11dq8a,
        s11dq15 == 1 ~ s11dq16a,
        s11dq27 == 1 ~ s11dq28a,
        TRUE ~ 0
      ),
      UREA_N_kg = UREA_kg * 0.46,
      NPK_N_kg = NPK_kg * 0.2,
      nitrogen_kg = UREA_N_kg + NPK_N_kg,
      nitrogen_kg = ifelse(s11dq1 == 2 | s11dq1a == 2, 0, nitrogen_kg)
    ) |>
    dplyr::group_by(plot_id, hhid) |>
    dplyr::summarise(
      nitrogen_kg = sum(nitrogen_kg, na.rm = TRUE),
      UREA_kg = sum(UREA_kg, na.rm = TRUE),
      NPK_kg = sum(NPK_kg, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(dplyr::across(c(nitrogen_kg, UREA_kg, NPK_kg), 
                                ~ ifelse(. == 0, NA, .)))
  
  haven::write_dta(nitrogen_kg, file.path(temp_dir, "nitrogen_kg.dta"))
  
  # Pesticides
  pesticides_data <- read_dta_auto("secta11c2_harvestw3", input_dir, temp_dir)
  
  pesticides_use <- pesticides_data |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::mutate(used_pesticides = dplyr::case_when(
      s11c2q1 == 1 ~ 1,
      s11c2q1 == 2 ~ 0,
      TRUE ~ NA_real_
    )) |>
    dplyr::group_by(plot_id) |>
    dplyr::summarise(used_pesticides = max(used_pesticides, na.rm = TRUE), .groups = "drop") |>
    dplyr::mutate(used_pesticides = ifelse(is.infinite(used_pesticides), NA, used_pesticides))
  
  haven::write_dta(pesticides_use, file.path(temp_dir, "used_pesticides.dta"))
  cat("  ✓ fertilizer variables saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in fertilizer variables: ", e$message, "\n")
})

# 6.8 Labor days
tryCatch({
  cat("  Processing labor days...\n")
  
  lab_roster1_data <- read_dta_auto("sect11c1_plantingw3", input_dir, temp_dir)
  lab_roster2_data <- read_dta_auto("secta2_harvestw3", input_dir, temp_dir)
  
  # Planting labor (PP)
  pp_labor <- lab_roster1_data |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::mutate(
      hh_labordays1 = s11c1q1a2 * s11c1q1a3,
      hh_labordays2 = s11c1q1b2 * s11c1q1b3,
      hh_labordays3 = s11c1q1c2 * s11c1q1c3,
      hh_labordays4 = s11c1q1d2 * s11c1q1d3,
      PPtotal_family_labor_days = dplyr::coalesce(hh_labordays1, 0) + 
        dplyr::coalesce(hh_labordays2, 0) +
        dplyr::coalesce(hh_labordays3, 0) +
        dplyr::coalesce(hh_labordays4, 0),
      PPhired_man_days = ifelse(s11c1q2 == 0, 0, s11c1q2 * s11c1q3),
      PPhired_woman_days = ifelse(s11c1q5 == 0, 0, s11c1q5 * s11c1q6),
      PPhired_child_days = ifelse(s11c1q8 == 0, 0, s11c1q8 * s11c1q9),
      PPtotal_hired_labor_days = dplyr::coalesce(PPhired_man_days, 0) + 
        dplyr::coalesce(PPhired_woman_days, 0) +
        dplyr::coalesce(PPhired_child_days, 0)
    ) |>
    dplyr::group_by(plot_id) |>
    dplyr::summarise(
      PPtotal_family_labor_days = sum(PPtotal_family_labor_days, na.rm = TRUE),
      PPtotal_hired_labor_days = sum(PPtotal_hired_labor_days, na.rm = TRUE),
      .groups = "drop"
    )
  
  # Harvest labor (PH)
  ph_labor <- lab_roster2_data |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::mutate(
      hh_labordays1 = sa2q1b_a2 * sa2q1b_a3,
      hh_labordays2 = sa2q1b_b2 * sa2q1b_b3,
      hh_labordays3 = sa2q1b_c2 * sa2q1b_c3,
      hh_labordays4 = sa2q1b_d2 * sa2q1b_d3,
      hh_labordays5 = sa2q1b_e2 * sa2q1b_e3,
      hh_labordays6 = sa2q1b_f2 * sa2q1b_f3,
      hh_labordays7 = sa2q1b_g2 * sa2q1b_g3,
      hh_labordays8 = sa2q1b_h2 * sa2q1b_h3,
      PHtotal_family_labor_days = dplyr::coalesce(hh_labordays1, 0) + 
        dplyr::coalesce(hh_labordays2, 0) +
        dplyr::coalesce(hh_labordays3, 0) +
        dplyr::coalesce(hh_labordays4, 0) +
        dplyr::coalesce(hh_labordays5, 0) +
        dplyr::coalesce(hh_labordays6, 0) +
        dplyr::coalesce(hh_labordays7, 0) +
        dplyr::coalesce(hh_labordays8, 0),
      PHhired_man_days = ifelse(sa2q1c == 0, 0, sa2q1c * sa2q1d),
      PHhired_woman_days = ifelse(sa2q1f == 0, 0, sa2q1f * sa2q1g),
      PHhired_child_days = ifelse(sa2q1i == 0, 0, sa2q1i * sa2q1j),
      PHtotal_hired_labor_days = dplyr::coalesce(PHhired_man_days, 0) + 
        dplyr::coalesce(PHhired_woman_days, 0) +
        dplyr::coalesce(PHhired_child_days, 0),
      PHother_man_days = sa2q1n_a,
      PHother_woman_days = sa2q1n_b,
      PHother_child_days = sa2q1n_c,
      PHtotal_other_labor_days = dplyr::coalesce(PHother_man_days, 0) + 
        dplyr::coalesce(PHother_woman_days, 0) +
        dplyr::coalesce(PHother_child_days, 0)
    ) |>
    dplyr::group_by(plot_id) |>
    dplyr::summarise(
      PHtotal_family_labor_days = sum(PHtotal_family_labor_days, na.rm = TRUE),
      PHtotal_hired_labor_days = sum(PHtotal_hired_labor_days, na.rm = TRUE),
      PHtotal_other_labor_days = sum(PHtotal_other_labor_days, na.rm = TRUE),
      .groups = "drop"
    )
  
  # Combine labor
  labor_days <- ph_labor |>
    dplyr::full_join(pp_labor, by = "plot_id") |>
    dplyr::mutate(
      total_labor_days = dplyr::coalesce(PHtotal_family_labor_days, 0) + 
        dplyr::coalesce(PHtotal_hired_labor_days, 0) +
        dplyr::coalesce(PHtotal_other_labor_days, 0) +
        dplyr::coalesce(PPtotal_family_labor_days, 0) +
        dplyr::coalesce(PPtotal_hired_labor_days, 0),
      total_family_labor_days = dplyr::coalesce(PHtotal_family_labor_days, 0) + 
        dplyr::coalesce(PPtotal_family_labor_days, 0),
      total_hired_labor_days = dplyr::coalesce(PHtotal_hired_labor_days, 0) + 
        dplyr::coalesce(PPtotal_hired_labor_days, 0)
    ) |>
    dplyr::select(plot_id, total_labor_days, total_family_labor_days, 
                  total_hired_labor_days)
  
  haven::write_dta(labor_days, file.path(temp_dir, "labor_days.dta"))
  cat("  ✓ labor_days saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in labor days: ", e$message, "\n")
})

# ==============================================================================
# 7. INDIVIDUAL-LEVEL VARIABLES
# ==============================================================================

message("Extracting individual-level variables...")

# 7.1 Individual characteristics
tryCatch({
  cat("  Extracting individual characteristics...\n")
  
  indiv0_data <- read_dta_auto("sect1_harvestw3", input_dir, temp_dir)
  
  indiv_chars <- indiv0_data |>
    dplyr::filter(s1q4a != 2) |>
    dplyr::mutate(
      ID = paste(hhid, indiv, sep = "-"),
      female = dplyr::case_when(
        s1q2 == 2 ~ 1,
        s1q2 == 1 ~ 0,
        TRUE ~ NA_real_
      ),
      age = ifelse(s1q4 == 999, NA, s1q4),
      married = dplyr::case_when(
        s1q7 %in% c(1, 2) ~ 1,
        s1q7 %in% c(3:7) ~ 0,
        TRUE ~ NA_real_
      ),
      relationship_head = as.character(haven::as_factor(s1q3)),
      relationship_head = stringr::str_to_title(relationship_head),
      relationship_head = stringr::str_sub(relationship_head, 
                                           stringr::str_locate(relationship_head, " ")[,1] + 1, 
                                           -1),
      relationship_head = dplyr::case_when(
        relationship_head == "Parent In Law" ~ "Father-in-law/Mother-in-law",
        relationship_head == "Son/Daughter-In-Law" ~ "Son-in-law/Daughter-in-law",
        relationship_head == "Brother/Sister Inlaw" ~ "Brother-in-law/Sister-in-law",
        relationship_head == "Brother/Sister" ~ "Sister/Brother",
        relationship_head == "Other Non-Relative" ~ "Non Relative",
        relationship_head == "Other (Specify)" ~ "Non Relative",
        relationship_head == "Other Relative" ~ "Other Relative",
        relationship_head == "Domestic Help (Resident)" ~ "Servant",
        relationship_head == "Domestic Help (Non Resident)" ~ "Servant",
        relationship_head == "Grandfather/Mother" ~ "Grandparent",
        relationship_head == "Adopted Child" ~ "Son/Daughter",
        relationship_head == "Own Child" ~ "Son/Daughter",
        relationship_head == "Step Child" ~ "Son/Daughter",
        relationship_head == "Other Relation (Specify)" ~ "Other Relative",
        relationship_head == "Other Non Relation (Specify)" ~ "Non Relative",
        TRUE ~ relationship_head
      ),
      birth_month = lubridate::ymd(paste(s1q6_year, s1q6_month, "01", sep = "-"))
    ) |>
    dplyr::select(hhid, ID, married, female, age, relationship_head, birth_month) |>
    dplyr::distinct()
  
  haven::write_dta(indiv_chars, file.path(temp_dir, "indiv_chars.dta"))
  cat("  ✓ indiv_chars saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in individual characteristics: ", e$message, "\n")
})

# 7.2 Education (individual level)
tryCatch({
  cat("  Extracting individual education...\n")
  
  indiv_roster1_data <- read_dta_auto("sect2_harvestw3", input_dir, temp_dir)
  
  educ_indiv <- indiv_roster1_data |>
    dplyr::mutate(
      ID = paste(hhid, indiv, sep = "-"),
      formal_education1 = dplyr::case_when(
        s2aq6 == 1 ~ 1,
        s2aq6 == 2 ~ 0,
        TRUE ~ NA_real_
      ),
      primary_education1 = dplyr::case_when(
        s2aq9 >= 16 & s2aq9 <= 43 ~ 1,
        s2aq9 %in% c(0:15, 51:61) ~ 0,
        TRUE ~ NA_real_
      ),
      primary_education1 = ifelse(s2aq6 == 2, 0, primary_education1)
    ) |>
    dplyr::group_by(hhid, ID) |>
    dplyr::summarise(
      formal_education = max(formal_education1, na.rm = TRUE),
      primary_education = max(primary_education1, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      formal_education = ifelse(is.infinite(formal_education), NA, formal_education),
      primary_education = ifelse(is.infinite(primary_education), NA, primary_education)
    )
  
  haven::write_dta(educ_indiv, file.path(temp_dir, "educ_indiv.dta"))
  cat("  ✓ educ_indiv saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in individual education: ", e$message, "\n")
})

# 7.3 Labor (individual level)
tryCatch({
  cat("  Extracting individual labor...\n")
  
  labor_hh_data <- read_dta_auto("sect3_plantingw3", input_dir, temp_dir)
  
  labor_indiv <- labor_hh_data |>
    dplyr::mutate(
      ID = paste(hhid, indiv, sep = "-"),
      working_age = s3q1 == 1,
      farm_work = dplyr::case_when(
        s3q5b == 0 ~ 0,
        !is.na(s3q5b) ~ 1,
        TRUE ~ NA_real_
      ),
      farm_work = ifelse(s3q5 == 2, 0, farm_work),
      SOB_work = dplyr::case_when(
        s3q6b == 0 ~ 0,
        !is.na(s3q6b) ~ 1,
        TRUE ~ NA_real_
      ),
      SOB_work = ifelse(s3q6 == 2, 0, SOB_work),
      wage_work = dplyr::case_when(
        s3q4b == 0 ~ 0,
        !is.na(s3q4b) ~ 1,
        TRUE ~ NA_real_
      ),
      wage_work = ifelse(s3q4 == 2, 0, wage_work),
      farm_hrs = ifelse(s3q5 == 2, 0, s3q5b),
      SB_hrs = ifelse(s3q6 == 2, 0, s3q6b),
      wage_hrs = ifelse(s3q4 == 2, 0, s3q4b),
      ind_ag = ifelse(s3q14 == 1 & working_age == 1, 1, 0),
      ind_fish = NA_real_,
      ind_mining = ifelse(s3q14 == 2 & working_age == 1, 1, 0),
      ind_manuf = ifelse(s3q14 %in% 3:5 & working_age == 1, 1, 0),
      ind_const = ifelse(s3q14 == 6 & working_age == 1, 1, 0),
      ind_serv = ifelse(s3q14 %in% 7:14 & working_age == 1, 1, 0)
    ) |>
    dplyr::mutate(
      dplyr::across(c(ind_ag, ind_fish, ind_mining, ind_manuf, ind_const, ind_serv),
                    ~ ifelse(s3q4 == 2 | s3q7 == 2, 0, .))
    ) |>
    dplyr::mutate(
      dplyr::across(c(farm_work, SOB_work, wage_work, farm_hrs, SB_hrs, wage_hrs,
                      ind_ag, ind_const, ind_fish, ind_manuf, ind_mining, ind_serv),
                    ~ ifelse(working_age == 0, 0, .))
    ) |>
    dplyr::select(ID, hhid, farm_work, SOB_work, wage_work, farm_hrs, SB_hrs, wage_hrs,
                  ind_ag, ind_const, ind_fish, ind_manuf, ind_mining, ind_serv, working_age) |>
    dplyr::distinct()
  
  haven::write_dta(labor_indiv, file.path(temp_dir, "labor.dta"))
  cat("  ✓ labor_indiv saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in individual labor: ", e$message, "\n")
})

# 7.4 Anthropometric measures (wasting)
tryCatch({
  cat("  Processing anthropometric measures...\n")
  
  anthropo_data <- read_dta_auto("sect4a_harvestw3", input_dir, temp_dir)
  harvest_interview_data <- haven::read_dta(file.path(temp_dir, "harvest_interview_month.dta"))
  
  wasting_data <- anthropo_data |>
    dplyr::mutate(
      ID = paste(hhid, indiv, sep = "-"),
      weight = s4aq52,
      height = s4aq53
    ) |>
    dplyr::left_join(indiv_chars |> dplyr::select(ID, birth_month, age), by = "ID") |>
    dplyr::left_join(harvest_interview_data, by = "hhid") |>
    dplyr::mutate(
      age_months = as.numeric(difftime(harvest_interview_month, birth_month, units = "days")) / 30.44,
      cage = ifelse(age == 0 | is.na(age), age_months, age * 12)
    ) |>
    dplyr::mutate(
      bmi = weight / ((height/100)^2),
      bmi_zscore = (bmi - mean(bmi, na.rm = TRUE)) / sd(bmi, na.rm = TRUE),
      wasting = ifelse(bmi_zscore < -2, 1, 0)
    ) |>
    dplyr::select(hhid, ID, weight, height, haz06 = bmi_zscore, 
                  waz06 = bmi_zscore, whz06 = bmi_zscore, 
                  bmiz06 = bmi_zscore, wasting) |>
    dplyr::distinct()
  
  haven::write_dta(wasting_data, file.path(temp_dir, "wasting.dta"))
  cat("  ✓ wasting saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in wasting: ", e$message, "\n")
})

# ==============================================================================
# 8. HOUSEHOLD DIETARY DIVERSITY SCORE (HDDS)
# ==============================================================================

message("Extracting HDDS...")

tryCatch({
  cat("  Calculating HDDS...\n")
  
  hdds_data <- read_dta_auto("sect10b_harvestw3", input_dir, temp_dir)
  
  hdds_data <- hdds_data |>
    dplyr::filter(s10bq1 == 1) |>
    dplyr::rename(food_id = item_cd) |>
    dplyr::mutate(
      A = ifelse(food_id >= 10 & food_id <= 29, 1, 0),
      B = ifelse(food_id >= 30 & food_id <= 38, 1, 0),
      C = ifelse(food_id >= 70 & food_id <= 79, 1, 0),
      D = ifelse(food_id >= 60 & food_id <= 66, 1, 0),
      E = ifelse((food_id >= 80 & food_id <= 82) | (food_id >= 90 & food_id <= 96), 1, 0),
      F = ifelse(food_id >= 83 & food_id <= 85, 1, 0),
      G = ifelse(food_id >= 100 & food_id <= 107, 1, 0),
      H = ifelse(food_id >= 40 & food_id <= 48, 1, 0),
      I = ifelse(food_id >= 110 & food_id <= 114, 1, 0),
      J = ifelse(food_id >= 50 & food_id <= 53, 1, 0),
      K = ifelse(food_id >= 130 & food_id <= 133, 1, 0),
      L = ifelse(food_id >= 120 & food_id <= 122, 1, 0)
    ) |>
    dplyr::group_by(hhid) |>
    dplyr::summarise(
      dplyr::across(A:L, ~ max(.x, na.rm = TRUE)),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      HDDS = dplyr::coalesce(A, 0) + dplyr::coalesce(B, 0) + 
        dplyr::coalesce(C, 0) + dplyr::coalesce(D, 0) +
        dplyr::coalesce(E, 0) + dplyr::coalesce(F, 0) +
        dplyr::coalesce(G, 0) + dplyr::coalesce(H, 0) +
        dplyr::coalesce(I, 0) + dplyr::coalesce(J, 0) +
        dplyr::coalesce(K, 0) + dplyr::coalesce(L, 0)
    ) |>
    dplyr::select(hhid, HDDS)
  
  haven::write_dta(hdds_data, file.path(temp_dir, "HDDS.dta"))
  cat("  ✓ HDDS saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in HDDS: ", e$message, "\n")
})

# ==============================================================================
# 9. CLEAN UP: REMOVE EXTRACTED FILES (KEEP ONLY ZIP)
# ==============================================================================

cat("\n=== Cleaning up extracted files ===\n")

all_files <- list.files(input_dir, full.names = TRUE)
zip_pattern <- "\\.zip$"
del_files <- all_files[!grepl(zip_pattern, all_files, ignore.case = TRUE)]

if (length(del_files) > 0) {
  cat("  Removing extracted files:\n")
  for (f in del_files) {
    cat("    -", basename(f), "\n")
    unlink(f, recursive = TRUE, force = TRUE)
  }
  cat("  ✓ Cleanup complete\n")
} else {
  cat("  No extracted files to remove\n")
}

# ==============================================================================
# 10. CLEAN TEMP DIRECTORY
# ==============================================================================

cat("\n=== Cleaning temporary directory ===\n")

temp_files <- list.files(temp_dir, full.names = TRUE, recursive = TRUE)

if (length(temp_files) > 0) {
  cat("  Removing temporary files:\n")
  for (f in temp_files) {
    cat("    -", basename(f), "\n")
    unlink(f, recursive = TRUE, force = TRUE)
  }
  cat("  ✓ Temp directory cleaned\n")
} else {
  cat("  No temporary files to remove\n")
}

# ==============================================================================
# 11. FINAL OUTPUT
# ==============================================================================

cat("\n=== NGA_GHS3 processing complete ===\n")
cat("Temporary files saved to:", temp_dir, "\n")
cat("✓ All variables extracted successfully\n")