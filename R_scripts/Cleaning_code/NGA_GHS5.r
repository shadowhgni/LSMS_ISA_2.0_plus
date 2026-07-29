# ==============================================================================
# NGA_GHS5.r - Nigeria Wave 5 (GHS 2023)
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
wave <- "GHS 23"
temppath <- file.path("NGA", "GHS23")

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
  
  harvest_data <- read_dta_auto("secta3i_harvestw5", input_dir, temp_dir)
  perennial_data <- read_dta_auto("secta3iii_harvestw5", input_dir, temp_dir)
  
  harvest_data <- harvest_data |>
    dplyr::left_join(perennial_data, by = c("hhid", "plotid", "cropcode")) |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::mutate(crop_name = as.character(haven::as_factor(cropcode))) |>
    dplyr::mutate(crop_name = stringr::str_sub(crop_name, 
                                               stringr::str_locate(crop_name, "\\.")[,1] + 2, 
                                               -1)) |>
    dplyr::select(hhid, plot_id, crop_name, cropcode) |>
    dplyr::distinct()
  
  harvest_data <- harvest_data |>
    dplyr::group_by(plot_id, crop_name) |>
    dplyr::mutate(tag = dplyr::n()) |>
    dplyr::ungroup() |>
    dplyr::mutate(cropname2 = as.character(haven::as_factor(cropcode))) |>
    dplyr::mutate(crop_name = ifelse(tag > 0, cropname2, crop_name)) |>
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
  
  cover_data <- read_dta_auto("secta_plantingw5", input_dir, temp_dir)
  cover2_data <- read_dta_auto("sectaa_harvestw5", input_dir, temp_dir)
  
  hh_frame <- cover_data |>
    dplyr::distinct(hhid)
  
  haven::write_dta(hh_frame, file.path(temp_dir, "hh_frame.dta"))
  cat("  ✓ hh_frame saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in household frame: ", e$message, "\n")
})

# 3.3 Individual frame
tryCatch({
  cat("  Creating individual frame...\n")
  
  indiv0_data <- read_dta_auto("sect1_harvestw5", input_dir, temp_dir)
  indiv_data <- read_dta_auto("sect1_plantingw5", input_dir, temp_dir)
  
  indiv_frame <- indiv0_data |>
    dplyr::left_join(indiv_data, by = c("hhid", "indiv")) |>
    dplyr::filter(s1q4 != 2) |>
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
  
  ghs18_ea <- read_dta_auto("ea_id", 
                            file.path(Temp_path, "NGA", "GHS18"), 
                            file.path(Temp_path, "NGA", "GHS18"))
  
  ea_data <- cover_data |>
    dplyr::mutate(ea_id_temp = paste(lga, ea, sep = "-")) |>
    dplyr::select(-lga, -ea) |>
    dplyr::left_join(ghs18_ea, by = "hhid") |>
    dplyr::mutate(ea_id = ifelse(!is.na(ea_id_temp), ea_id_temp, ea_id)) |>
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
  
  ghs18_strata <- read_dta_auto("strataid", 
                                file.path(Temp_path, "NGA", "GHS18"), 
                                file.path(Temp_path, "NGA", "GHS18"))
  
  strata_data <- cover_data |>
    dplyr::rename(zone_w5 = zone) |>
    dplyr::left_join(ghs18_strata, by = "hhid") |>
    dplyr::mutate(strataid = ifelse(is.na(strataid), zone_w5, strataid)) |>
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
  
  admin1_data <- cover_data |>
    dplyr::rename(admin_1 = zone) |>
    dplyr::mutate(admin_1_name = as.character(haven::as_factor(admin_1))) |>
    dplyr::select(hhid, admin_1, admin_1_name) |>
    dplyr::distinct()
  
  haven::write_dta(admin1_data, file.path(temp_dir, "admin1.dta"))
  
  admin2_data <- cover_data |>
    dplyr::rename(admin_2 = state) |>
    dplyr::mutate(admin_2_name = as.character(haven::as_factor(admin_2))) |>
    dplyr::select(hhid, admin_2, admin_2_name) |>
    dplyr::distinct()
  
  haven::write_dta(admin2_data, file.path(temp_dir, "admin2.dta"))
  
  admin3_data <- cover_data |>
    dplyr::rename(admin_3 = lga) |>
    dplyr::mutate(admin_3_name = as.character(haven::as_factor(admin_3))) |>
    dplyr::mutate(admin_3_name = stringr::str_sub(admin_3_name, 
                                                  stringr::str_locate(admin_3_name, "\\.")[,1] + 2, 
                                                  -1)) |>
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
  
  urban_data <- cover_data |>
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
  
  weights_data <- cover_data |>
    dplyr::rename(pw = wt_cross_wave5) |>
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
  
  planting_interview_data <- cover_data |>
    dplyr::mutate(
      InterviewStart = as.numeric(InterviewStart),
      str_date = substr(as.character(InterviewStart), 1, 10),
      day = lubridate::ymd(str_date),
      planting_interview_month = lubridate::floor_date(day, "month")
    ) |>
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
  
  harvest_interview_data <- cover2_data |>
    dplyr::mutate(
      InterviewStart = as.numeric(InterviewStart),
      str_date = substr(as.character(InterviewStart), 1, 10),
      day = lubridate::ymd(str_date),
      harvest_interview_month = lubridate::floor_date(day, "month")
    ) |>
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
  
  labor_hh_data <- read_dta_auto("sect4a_harvestw5", input_dir, temp_dir)
  
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
  
  indiv_roster_data <- read_dta_auto("sect1_plantingw5", input_dir, temp_dir)
  
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
  
  indiv_roster1_data <- read_dta_auto("sect2_harvestw5", input_dir, temp_dir)
  
  educ_hh_data <- indiv_roster1_data |>
    dplyr::mutate(
      formal_education_hh1 = dplyr::case_when(
        s2q6 == 1 ~ 1,
        s2q6 == 2 ~ 0,
        TRUE ~ NA_real_
      ),
      primary_education_hh1 = dplyr::case_when(
        s2q9 >= 16 & s2q9 <= 43 ~ 1,
        s2q9 %in% c(0:15, 51:64, 98, 99) ~ 0,
        TRUE ~ NA_real_
      ),
      primary_education_hh1 = ifelse(formal_education_hh1 == 0, 0, primary_education_hh1)
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
  
  housing_data <- read_dta_auto("sect9_harvestw5", input_dir, temp_dir)
  
  electricity_data <- housing_data |>
    dplyr::mutate(
      hh_electricity_access = dplyr::case_when(
        s9q20 == 1 ~ 1,
        s9q20 == 2 ~ 0,
        TRUE ~ NA_real_
      ),
      hh_electricity_access = ifelse(s9q19_1 == 1 | s9q19_2 == 1, 1, hh_electricity_access)
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
  
  livestock_data <- read_dta_auto("sect11i_plantingw5", input_dir, temp_dir)
  
  livestock_data <- livestock_data |>
    dplyr::left_join(cover_data |> dplyr::select(hhid), by = "hhid") |>
    dplyr::mutate(
      livestock = dplyr::case_when(
        s11iq1 == 1 ~ 1,
        s11iq1 %in% c(2, NA) ~ 0,
        TRUE ~ NA_real_
      )
    ) |>
    dplyr::group_by(hhid = hhid.x) |>
    dplyr::summarise(livestock = max(livestock, na.rm = TRUE), .groups = "drop") |>
    dplyr::mutate(livestock = ifelse(is.infinite(livestock), NA, livestock))
  
  haven::write_dta(livestock_data, file.path(temp_dir, "livestock.dta"))
  cat("  ✓ livestock saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in livestock: ", e$message, "\n")
})

# 4.13 Household shocks
tryCatch({
  cat("  Extracting household shocks...\n")
  
  shocks_data <- read_dta_auto("sect12_harvestw5", input_dir, temp_dir)
  
  shock_data <- shocks_data |>
    dplyr::mutate(
      hh_shock = dplyr::case_when(
        s12q1 == 1 ~ 1,
        s12q1 %in% c(2, 0) ~ 0,
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

# 4.14 Non-farm enterprise
tryCatch({
  cat("  Extracting non-farm enterprise...\n")
  
  nfe_data <- read_dta_auto("sect8a_harvestw5", input_dir, temp_dir)
  
  nfe_data <- nfe_data |>
    dplyr::left_join(cover_data |> dplyr::select(hhid), by = "hhid") |>
    dplyr::mutate(
      nonfarm_enterprise = dplyr::case_when(
        s8q1__1 == 1 ~ 1,
        s8q1__1 == 0 ~ 0,
        TRUE ~ NA_real_
      )
    ) |>
    dplyr::select(hhid, nonfarm_enterprise) |>
    dplyr::distinct()
  
  haven::write_dta(nfe_data, file.path(temp_dir, "nfe.dta"))
  cat("  ✓ nonfarm_enterprise saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in non-farm enterprise: ", e$message, "\n")
})

# 4.15 Agricultural asset index
tryCatch({
  cat("  Calculating agricultural asset index...\n")
  
  items_data <- read_dta_auto("secta4_harvestw5", input_dir, temp_dir)
  
  items_data <- items_data |>
    dplyr::filter(!item_cd %in% c(313, 314, 315, 316))
  
  items_data <- items_data |>
    dplyr::mutate(
      hh_owns_ = 0,
      hh_owns_ = ifelse(!is.na(sa4q4_1) & sa4q4_1 != 0, 1, hh_owns_),
      hh_owns_ = ifelse(!is.na(sa4q4_2) & sa4q4_2 != 0, 1, hh_owns_),
      hh_owns_ = ifelse(!is.na(sa4q4_3) & sa4q4_3 != 0, 1, hh_owns_),
      hh_owns_ = ifelse(!is.na(sa4q4_4) & sa4q4_4 != 0, 1, hh_owns_),
      hh_owns_ = ifelse(!is.na(sa4q4_5) & sa4q4_5 != 0, 1, hh_owns_),
      hh_owns_ = ifelse(sa4q3 == 1 | sa4q3 == 2, 1, hh_owns_)
    ) |>
    dplyr::select(hhid, item_cd, hh_owns_)
  
  items_wide <- items_data |>
    dplyr::distinct(hhid, item_cd, .keep_all = TRUE) |>
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

# 4.16 Household asset index
tryCatch({
  cat("  Calculating household asset index...\n")
  
  items_hh_data <- read_dta_auto("sect10_plantingw5", input_dir, temp_dir)
  
  items_hh_data <- items_hh_data |>
    dplyr::mutate(
      hh_owns = dplyr::case_when(
        s10q1a == 1 ~ 1,
        s10q1a == 2 ~ 0,
        TRUE ~ NA_real_
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

# 4.17 Tractor ownership
tryCatch({
  cat("  Extracting tractor ownership...\n")
  
  tenure_data <- read_dta_auto("sect11b1_plantingw5", input_dir, temp_dir)
  
  tractor_data <- tenure_data |>
    dplyr::mutate(tractor = dplyr::case_when(
      s11b1q69 == 1 ~ 1,
      s11b1q69 == 2 ~ 0,
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

# 4.18 Respondent characteristics
tryCatch({
  cat("  Extracting respondent characteristics...\n")
  
  plot_roster_data <- read_dta_auto("sect11a1_plantingw5", input_dir, temp_dir)
  
  respondent_ids <- tenure_data |>
    dplyr::left_join(plot_roster_data, by = c("hhid", "plotid")) |>
    dplyr::mutate(respondent_id = s11b1q2) |>
    dplyr::group_by(hhid) |>
    dplyr::summarise(respondent_id = dplyr::first(respondent_id), .groups = "drop")
  
  indiv0_data <- read_dta_auto("sect1_harvestw5", input_dir, temp_dir)
  
  resp_chars1 <- indiv0_data |>
    dplyr::rename(id = indiv) |>
    dplyr::inner_join(respondent_ids, by = c("hhid", "id" = "respondent_id")) |>
    dplyr::mutate(
      female_respondent = dplyr::case_when(
        s1q2 == 2 ~ 1,
        s1q2 == 1 ~ 0,
        TRUE ~ NA_real_
      ),
      age_respondent = ifelse(s1q6 == 999, NA, s1q6),
      married_respondent = dplyr::case_when(
        s1q16 %in% c(1, 2) ~ 1,
        s1q16 %in% c(3:7) ~ 0,
        TRUE ~ NA_real_
      )
    ) |>
    dplyr::mutate(respondent_id = paste(hhid, id, sep = "-")) |>
    dplyr::select(hhid, female_respondent, age_respondent, married_respondent, respondent_id) |>
    dplyr::distinct()
  
  indiv_roster1_data <- read_dta_auto("sect2_harvestw5", input_dir, temp_dir)
  
  resp_chars2 <- indiv_roster1_data |>
    dplyr::rename(id = indiv) |>
    dplyr::inner_join(respondent_ids, by = c("hhid", "id" = "respondent_id")) |>
    dplyr::mutate(
      formal_education_respondent1 = dplyr::case_when(
        s2q6 == 1 ~ 1,
        s2q6 == 2 ~ 0,
        TRUE ~ NA_real_
      ),
      primary_education_respondent1 = dplyr::case_when(
        s2q9 >= 16 & s2q9 <= 43 ~ 1,
        s2q9 %in% c(0:15, 51:64, 98, 99) ~ 0,
        TRUE ~ NA_real_
      ),
      primary_education_respondent1 = ifelse(formal_education_respondent1 == 0, 0, primary_education_respondent1)
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

# 4.19 Fallow plots and number of plots
tryCatch({
  cat("  Calculating fallow plots and number of plots...\n")
  
  fallow_data <- tenure_data |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::mutate(
      fallow_plot = dplyr::case_when(
        s11b1q44 == 1 ~ 1,
        !is.na(s11b1q44) & s11b1q44 != 1 ~ 0,
        TRUE ~ NA_real_
      )
    ) |>
    dplyr::group_by(hhid) |>
    dplyr::summarise(
      nb_fallow_plots = sum(fallow_plot == 1, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::left_join(cover_data |> dplyr::select(hhid), by = "hhid") |>
    dplyr::mutate(nb_fallow_plots = ifelse(is.na(hhid.y), 0, nb_fallow_plots)) |>
    dplyr::select(hhid = hhid.x, nb_fallow_plots)
  
  haven::write_dta(fallow_data, file.path(temp_dir, "nb_fallow_plots.dta"))
  
  nb_plots_data <- plot_roster_data |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::group_by(hhid) |>
    dplyr::summarise(nb_plots = dplyr::n_distinct(plot_id), .groups = "drop") |>
    dplyr::left_join(cover_data |> dplyr::select(hhid), by = "hhid") |>
    dplyr::mutate(nb_plots = ifelse(is.na(hhid.y), 0, nb_plots)) |>
    dplyr::select(hhid = hhid.x, nb_plots)
  
  haven::write_dta(nb_plots_data, file.path(temp_dir, "nb_plots.dta"))
  cat("  ✓ fallow plots saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in fallow plots: ", e$message, "\n")
})

# ==============================================================================
# 5. PLOT-LEVEL VARIABLES
# ==============================================================================

message("Extracting plot-level variables...")

# 5.1 Plot area (with imputation)
tryCatch({
  cat("  Calculating plot area...\n")
  
  plot_roster_data <- read_dta_auto("sect11a1_plantingw5", input_dir, temp_dir)
  
  plot_area_data <- plot_roster_data |>
    dplyr::rename(admin_1 = zone, admin_2 = state, admin_3 = lga) |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::mutate(
      area_self_reported = s11aq3_number,
      area_self_reported = ifelse(s11aq3_unit == 5, area_self_reported * 0.4, area_self_reported),
      area_self_reported = ifelse(s11aq3_unit == 7, area_self_reported * 0.0001, area_self_reported),
      area_self_reported = ifelse(s11aq3_unit == 8, area_self_reported * 0.0929, area_self_reported),
      area_self_reported = ifelse(s11aq3_unit == 9, area_self_reported * 0.04645, area_self_reported),
      area_self_reported = ifelse(s11aq3_unit == 10, area_self_reported * 0.405, area_self_reported),
      
      area_self_reported = ifelse(s11aq3_unit == 1 & admin_1 == 1, area_self_reported * 0.00012, area_self_reported),
      area_self_reported = ifelse(s11aq3_unit == 1 & admin_1 == 2, area_self_reported * 0.00016, area_self_reported),
      area_self_reported = ifelse(s11aq3_unit == 1 & admin_1 == 3, area_self_reported * 0.00011, area_self_reported),
      area_self_reported = ifelse(s11aq3_unit == 1 & admin_1 == 4, area_self_reported * 0.00019, area_self_reported),
      area_self_reported = ifelse(s11aq3_unit == 1 & admin_1 == 5, area_self_reported * 0.00021, area_self_reported),
      area_self_reported = ifelse(s11aq3_unit == 1 & admin_1 == 6, area_self_reported * 0.00012, area_self_reported),
      
      area_self_reported = ifelse(s11aq3_unit == 2 & admin_1 == 1, area_self_reported * 0.0027, area_self_reported),
      area_self_reported = ifelse(s11aq3_unit == 2 & admin_1 == 2, area_self_reported * 0.004, area_self_reported),
      area_self_reported = ifelse(s11aq3_unit == 2 & admin_1 == 3, area_self_reported * 0.00494, area_self_reported),
      area_self_reported = ifelse(s11aq3_unit == 2 & admin_1 == 4, area_self_reported * 0.0023, area_self_reported),
      area_self_reported = ifelse(s11aq3_unit == 2 & admin_1 == 5, area_self_reported * 0.0023, area_self_reported),
      area_self_reported = ifelse(s11aq3_unit == 2 & admin_1 == 6, area_self_reported * 0.00001, area_self_reported),
      
      area_self_reported = ifelse(s11aq3_unit == 3 & admin_1 == 1, area_self_reported * 0.00006, area_self_reported),
      area_self_reported = ifelse(s11aq3_unit == 3 & admin_1 == 2, area_self_reported * 0.00016, area_self_reported),
      area_self_reported = ifelse(s11aq3_unit == 3 & admin_1 == 3, area_self_reported * 0.00004, area_self_reported),
      area_self_reported = ifelse(s11aq3_unit == 3 & admin_1 == 4, area_self_reported * 0.00004, area_self_reported),
      area_self_reported = ifelse(s11aq3_unit == 3 & admin_1 == 5, area_self_reported * 0.00013, area_self_reported),
      area_self_reported = ifelse(s11aq3_unit == 3 & admin_1 == 6, area_self_reported * 0.00041, area_self_reported),
      
      plot_area_GPS = s11mq3 * 0.0001
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
  
  seeds_data <- read_dta_auto("sect11f_plantingw5", input_dir, temp_dir)
  
  planting_month_plot <- seeds_data |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::mutate(
      month = s11fq11_month,
      year = s11fq11_year
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
  
  harvest_raw <- read_dta_auto("secta3i_harvestw5", input_dir, temp_dir)
  
  harvest_end_month_plot <- harvest_raw |>
    dplyr::left_join(perennial_data, by = c("hhid", "plotid", "cropcode")) |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::mutate(
      month = sa3iq14a,
      year = sa3iq14b,
      month = ifelse(!is.na(sa3iiiq22a), sa3iiiq22a, month),
      year = ifelse(!is.na(sa3iiiq22b), sa3iiiq22b, year)
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
  
  intercropped_data <- seeds_data |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::mutate(intercropped = dplyr::case_when(
      s11fq4 == 1 ~ 0,
      s11fq4 == 2 ~ 1,
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
  
  improved_data <- seeds_data |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::mutate(improved = dplyr::case_when(
      s11fq7 == 2 ~ 0,
      s11fq7 == 1 ~ 1,
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
  
  tenure_data <- read_dta_auto("sect11b1_plantingw5", input_dir, temp_dir)
  
  plot_owned_data <- tenure_data |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::mutate(
      plot_owned = dplyr::case_when(
        s11b1q4 %in% c(1, 4, 5) ~ 1,
        s11b1q4 %in% c(2, 3, 6, 7, 8, 9) ~ 0,
        TRUE ~ NA_real_
      ),
      plot_certificate = dplyr::case_when(
        s11b1q8 == 1 ~ 1,
        s11b1q8 == 2 ~ 0,
        s11b1q8 == 3 ~ NA_real_,
        TRUE ~ NA_real_
      ),
      plot_certificate = ifelse(plot_owned == 0, 0, plot_certificate)
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
  
  irrigated_data <- tenure_data |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::mutate(irrigated = dplyr::case_when(
      s11b1q56 == 1 ~ 1,
      s11b1q56 == 2 ~ 0,
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
  
  erosion_data <- tenure_data |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::mutate(erosion_protection = dplyr::case_when(
      s11b1q66 == 1 ~ 1,
      s11b1q66 == 2 ~ 0,
      TRUE ~ NA_real_
    )) |>
    dplyr::select(plot_id, erosion_protection) |>
    dplyr::distinct()
  
  haven::write_dta(erosion_data, file.path(temp_dir, "erosion_protection.dta"))
  cat("  ✓ erosion_protection saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in erosion protection: ", e$message, "\n")
})

# 5.10 Manager characteristics
tryCatch({
  cat("  Extracting manager characteristics...\n")
  
  plot_roster_data <- read_dta_auto("sect11a1_plantingw5", input_dir, temp_dir)
  indiv0_data <- read_dta_auto("sect1_harvestw5", input_dir, temp_dir)
  indiv_roster1_data <- read_dta_auto("sect2_harvestw5", input_dir, temp_dir)
  
  manager_ids <- plot_roster_data |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::rename(manager_id = s11aq5a) |>
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
      age_manager = ifelse(s1q6 == 999, NA, s1q6),
      married_manager = dplyr::case_when(
        s1q16 %in% c(1, 2) ~ 1,
        s1q16 %in% c(3:7) ~ 0,
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
        s2q6 == 1 ~ 1,
        s2q6 == 2 ~ 0,
        TRUE ~ NA_real_
      ),
      primary_education_manager1 = dplyr::case_when(
        s2q9 >= 16 & s2q9 <= 43 ~ 1,
        s2q9 %in% c(0:15, 51:64, 98, 99) ~ 0,
        TRUE ~ NA_real_
      ),
      primary_education_manager1 = ifelse(formal_education_manager1 == 0, 0, primary_education_manager1)
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

# ==============================================================================
# 6. CROP-LEVEL VARIABLES
# ==============================================================================

message("Extracting crop-level variables...")

# 6.1 Harvest kg
tryCatch({
  cat("  Calculating harvest kg...\n")
  
  harvest_raw <- read_dta_auto("secta3i_harvestw5", input_dir, temp_dir)
  
  harvest_kg_data <- harvest_raw |>
    dplyr::left_join(perennial_data, by = c("hhid", "plotid", "cropcode")) |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::mutate(
      any_harvest = dplyr::case_when(
        sa3iq3 == 1 ~ 1,
        sa3iq3 == 2 ~ 0,
        TRUE ~ NA_real_
      ),
      harvest_kg_temp = sa3iq9a * sa3iq9_conv,
      harvest_kg_temp = ifelse(any_harvest == 0, 0, harvest_kg_temp),
      harvest_kg_expected = sa3iq15a * sa3iq15_conv,
      harvest_kg_per = sa3iiiq23a * sa3iiiq23_conv
    ) |>
    dplyr::mutate(
      harvest_kg = dplyr::coalesce(harvest_kg_temp, harvest_kg_expected, harvest_kg_per),
      crop_shock = dplyr::case_when(
        sa3iq3 == 2 ~ 1,
        sa3iq3 == 1 ~ 0,
        TRUE ~ NA_real_
      ),
      crop_shock = ifelse(sa3iq4_1 > 21 & sa3iq4_2 > 21, 0, crop_shock),
      crop_shock = ifelse(sa3iq6 == 1, 1, crop_shock),
      crop_shock = ifelse(sa3iq7_1 > 21 & sa3iq7_1 > 21, 0, crop_shock),
      harvest_kg = ifelse(harvest_kg == 0 & crop_shock != 1, NA, harvest_kg)
    ) |>
    dplyr::left_join(admin1_data, by = "hhid") |>
    dplyr::left_join(admin2_data, by = "hhid") |>
    dplyr::left_join(admin3_data, by = "hhid") |>
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
  
  crop_shock_data <- harvest_raw |>
    dplyr::left_join(perennial_data, by = c("hhid", "plotid", "cropcode")) |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::mutate(
      crop_shock = dplyr::case_when(
        sa3iq3 == 2 ~ 1,
        sa3iq3 == 1 ~ 0,
        TRUE ~ NA_real_
      ),
      crop_shock = ifelse(sa3iq4_1 > 21 & sa3iq4_2 > 21, 0, crop_shock),
      crop_shock = ifelse(sa3iq6 == 1, 1, crop_shock),
      crop_shock = ifelse(sa3iq7_1 > 21 & sa3iq7_1 > 21, 0, crop_shock)
    ) |>
    dplyr::group_by(hhid, plot_id, cropcode) |>
    dplyr::summarise(
      crop_shock = max(crop_shock, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(crop_shock = ifelse(is.infinite(crop_shock), NA, crop_shock))
  
  haven::write_dta(crop_shock_data, file.path(temp_dir, "crop_shock.dta"))
  cat("  ✓ crop_shock saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in crop shocks: ", e$message, "\n")
})

# 6.3 Harvest sold amount
tryCatch({
  cat("  Calculating harvest sold kg...\n")
  
  harvest_sold_data <- read_dta_auto("secta3ii_harvestw5", input_dir, temp_dir)
  
  harvest_sold_kg_data <- harvest_sold_data |>
    dplyr::mutate(
      total_kg = sa3iiq3a * sa3iiq1_conv,
      share_sold = sa3iiq6 / sa3iiq3a,
      harvest_sold_kg_temp = share_sold * total_kg,
      harvest_sold_kg_temp = ifelse(sa3iiq4 == 2, 0, harvest_sold_kg_temp)
    ) |>
    dplyr::left_join(perennial_data, by = c("hhid", "cropcode")) |>
    dplyr::mutate(
      harvest_sold_per = sa3iiiq23a * sa3iiiq23_conv,
      harvest_sold_per = ifelse(is.na(harvest_sold_per) & !is.na(sa3iiiq23a), 0, harvest_sold_per)
    ) |>
    dplyr::group_by(cropcode, hhid) |>
    dplyr::summarise(
      harvest_sold_kg_temp = max(harvest_sold_kg_temp, na.rm = TRUE),
      harvest_sold_per = sum(harvest_sold_per, na.rm = TRUE),
      n = sum(!is.na(harvest_sold_per)),
      .groups = "drop"
    ) |>
    dplyr::mutate(harvest_sold_per = ifelse(n == 0, NA, harvest_sold_per)) |>
    dplyr::left_join(admin1_data, by = "hhid") |>
    dplyr::left_join(admin2_data, by = "hhid") |>
    dplyr::left_join(admin3_data, by = "hhid") |>
    dplyr::mutate(
      harvest_sold_kg = dplyr::coalesce(harvest_sold_kg_temp, harvest_sold_per)
    ) |>
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
  
  harvest_sold_value_data <- harvest_sold_data |>
    dplyr::mutate(harvest_sold_value_temp = sa3iiq7) |>
    dplyr::left_join(perennial_data, by = c("hhid", "cropcode")) |>
    dplyr::mutate(
      harvest_sold_value_per = sa3iiiq24
    ) |>
    dplyr::group_by(cropcode, hhid) |>
    dplyr::summarise(
      harvest_sold_value_temp = max(harvest_sold_value_temp, na.rm = TRUE),
      harvest_sold_value_per = sum(harvest_sold_value_per, na.rm = TRUE),
      n = sum(!is.na(harvest_sold_value_per)),
      .groups = "drop"
    ) |>
    dplyr::mutate(harvest_sold_value_per = ifelse(n == 0, NA, harvest_sold_value_per)) |>
    dplyr::left_join(admin1_data, by = "hhid") |>
    dplyr::left_join(admin2_data, by = "hhid") |>
    dplyr::left_join(admin3_data, by = "hhid") |>
    dplyr::mutate(
      harvest_sold_value = dplyr::coalesce(harvest_sold_value_temp, harvest_sold_value_per)
    ) |>
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

# 6.5 Fertilizer variables
tryCatch({
  cat("  Extracting fertilizer variables...\n")
  
  ferts_data <- read_dta_auto("secta11c2_harvestw5", input_dir, temp_dir)
  
  # Inorganic fertilizer
  inorganic_fert <- ferts_data |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::mutate(
      inorganic_fertilizer = dplyr::case_when(
        s11c2q5 == 1 ~ 1,
        s11c2q5 == 2 ~ 0,
        TRUE ~ NA_real_
      )
    ) |>
    dplyr::select(plot_id, inorganic_fertilizer) |>
    dplyr::distinct()
  
  haven::write_dta(inorganic_fert, file.path(temp_dir, "inorganic_fertilizer.dta"))
  
  # Nitrogen kg
  nitrogen_kg <- ferts_data |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::mutate(
      inorganic_fertilizer = dplyr::case_when(
        s11c2q5 == 1 ~ 1,
        s11c2q5 == 2 ~ 0,
        TRUE ~ NA_real_
      ),
      UREA_kg = s11c2q11a * s11c2q11a_conv,
      UREA_kg = ifelse(s11c2q6__2 == 0, 0, UREA_kg),
      UREA_kg = ifelse(inorganic_fertilizer == 0, 0, UREA_kg),
      NPK_kg = s11c2q7a * s11c2q7a_conv,
      NPK_kg = ifelse(s11c2q6__1 == 0, 0, NPK_kg),
      NPK_kg = ifelse(inorganic_fertilizer == 0, 0, NPK_kg),
      other_kg = s11c2q9a * s11c2q9a_conv,
      other_kg = ifelse(s11c2q6__96 == 0, 0, other_kg),
      other_kg = ifelse(inorganic_fertilizer == 0, 0, other_kg),
      UREA_N_kg = UREA_kg * 0.46,
      NPK_N_kg = NPK_kg * 0.2,
      nitrogen_kg = UREA_N_kg + NPK_N_kg
    ) |>
    dplyr::left_join(ea_data, by = "hhid") |>
    dplyr::left_join(admin1_data, by = "hhid") |>
    dplyr::left_join(admin2_data, by = "hhid") |>
    dplyr::left_join(admin3_data, by = "hhid") |>
    dplyr::group_by(plot_id, hhid, ea_id, admin_1, admin_2, admin_3) |>
    dplyr::summarise(
      nitrogen_kg = sum(nitrogen_kg, na.rm = TRUE),
      UREA_kg = sum(UREA_kg, na.rm = TRUE),
      NPK_kg = sum(NPK_kg, na.rm = TRUE),
      other_kg = sum(other_kg, na.rm = TRUE),
      n_nitrogen_kg = sum(!is.na(nitrogen_kg)),
      n_NPK_kg = sum(!is.na(NPK_kg)),
      n_UREA_kg = sum(!is.na(UREA_kg)),
      n_other_kg = sum(!is.na(other_kg)),
      .groups = "drop"
    ) |>
    dplyr::mutate(dplyr::across(c(nitrogen_kg, UREA_kg, NPK_kg, other_kg),
                                ~ ifelse(. == 0, NA, .)))
  
  haven::write_dta(nitrogen_kg, file.path(temp_dir, "nitrogen_kg.dta"))
  
  # Organic fertilizer
  organic_fert <- ferts_data |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::mutate(
      organic_fertilizer = dplyr::case_when(
        s11c2q11 == 1 ~ 1,
        s11c2q11 == 2 ~ 0,
        TRUE ~ NA_real_
      )
    ) |>
    dplyr::group_by(plot_id) |>
    dplyr::summarise(organic_fertilizer = max(organic_fertilizer, na.rm = TRUE), .groups = "drop") |>
    dplyr::mutate(organic_fertilizer = ifelse(is.infinite(organic_fertilizer), NA, organic_fertilizer))
  
  haven::write_dta(organic_fert, file.path(temp_dir, "organic_fertilizer.dta"))
  
  # Pesticides
  pesticides_use <- ferts_data |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::mutate(used_pesticides = dplyr::case_when(
      s11c2q3 == 1 ~ 1,
      s11c2q3 == 2 ~ 0,
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

# 6.6 Labor days
tryCatch({
  cat("  Processing labor days...\n")
  
  lab_roster11 <- read_dta_auto("sect11c1a_plantingw5", input_dir, temp_dir)
  lab_roster12 <- read_dta_auto("sect11c1b_plantingw5", input_dir, temp_dir)
  
  # Planting labor
  pp_labor <- lab_roster11 |>
    dplyr::left_join(lab_roster12, by = c("hhid", "plotid")) |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::filter(!is.na(indiv)) |>
    dplyr::mutate(
      s11c1q1b = ifelse(s11c1q1a == 2, 0, s11c1q1b),
      PPtotal_family_labor_days = sum(s11c1q1b, na.rm = TRUE),
      PPtotal_family_labor_days = ifelse(is.na(s11c1q1b.y), 0, PPtotal_family_labor_days),
      
      PPhired_man_days = ifelse(s11c1q2_1 == 2, 0, s11c1q3_1 * s11c1q4_1),
      PPhired_woman_days = ifelse(s11c1q2_2 == 2, 0, s11c1q3_2 * s11c1q4_2),
      PPhired_child_days = ifelse(s11c1q2_3 == 2, 0, s11c1q3_3 * s11c1q4_3),
      PPtotal_hired_labor_days = dplyr::coalesce(PPhired_man_days, 0) + 
        dplyr::coalesce(PPhired_woman_days, 0) +
        dplyr::coalesce(PPhired_child_days, 0),
      PPtotal_hired_labor_days = ifelse(is.na(s11c1q2_1.y), 0, PPtotal_hired_labor_days),
      
      PPother_man_days = ifelse(s11c1q8_1 == 2, 0, s11c1q9_1 * s11c1q10_1),
      PPother_woman_days = ifelse(s11c1q8_2 == 2, 0, s11c1q9_2 * s11c1q10_2),
      PPother_child_days = ifelse(s11c1q8_3 == 2, 0, s11c1q9_3 * s11c1q10_3),
      PPtotal_other_labor_days = dplyr::coalesce(PPother_man_days, 0) + 
        dplyr::coalesce(PPother_woman_days, 0) +
        dplyr::coalesce(PPother_child_days, 0),
      PPtotal_other_labor_days = ifelse(is.na(s11c1q8_1.y), 0, PPtotal_other_labor_days)
    ) |>
    dplyr::group_by(hhid, plot_id) |>
    dplyr::summarise(
      PPtotal_family_labor_days = sum(PPtotal_family_labor_days, na.rm = TRUE),
      PPtotal_hired_labor_days = sum(PPtotal_hired_labor_days, na.rm = TRUE),
      PPtotal_other_labor_days = sum(PPtotal_other_labor_days, na.rm = TRUE),
      .groups = "drop"
    )
  
  # Harvest labor
  lab_roster21 <- read_dta_auto("secta2a_harvestw5", input_dir, temp_dir)
  lab_roster22 <- read_dta_auto("secta2b_harvestw5", input_dir, temp_dir)
  
  ph_labor <- lab_roster21 |>
    dplyr::left_join(lab_roster22, by = c("hhid", "plotid")) |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::filter(!is.na(indiv)) |>
    dplyr::left_join(harvest_interview_data, by = "hhid") |>
    dplyr::left_join(planting_interview_data, by = "hhid") |>
    dplyr::mutate(
      nb_months_since_pp = as.numeric(difftime(harvest_interview_month, planting_interview_month, units = "days")) / 30.44,
      nb_weeks_since_pp = round(nb_months_since_pp * 4.33),
      ld = nb_weeks_since_pp * sa2aq2,
      ld = ifelse(sa2aq1 == 2, 0, ld)
    ) |>
    dplyr::group_by(plot_id) |>
    dplyr::summarise(
      PHtotal_family_labor_days = sum(ld, na.rm = TRUE),
      PHtotal_family_labor_days = ifelse(is.na(sa2aq1.y), 0, PHtotal_family_labor_days),
      
      PHhired_man_days = ifelse(sa2bq1_1 == 0, 0, sa2bq2_1 * sa2bq3_1),
      PHhired_woman_days = ifelse(sa2bq1_2 == 0, 0, sa2bq2_2 * sa2bq3_2),
      PHhired_child_days = ifelse(sa2bq1_3 == 0, 0, sa2bq2_3 * sa2bq3_3),
      PHtotal_hired_labor_days = dplyr::coalesce(PHhired_man_days, 0) + 
        dplyr::coalesce(PHhired_woman_days, 0) +
        dplyr::coalesce(PHhired_child_days, 0),
      PHtotal_hired_labor_days = ifelse(is.na(sa2bq1_1.y), 0, PHtotal_hired_labor_days),
      
      PHother_man_days = ifelse(sa2bq7_1 == 0, 0, sa2bq8_1 * sa2bq9_1),
      PHother_woman_days = ifelse(sa2bq7_2 == 0, 0, sa2bq8_2 * sa2bq9_2),
      PHother_child_days = ifelse(sa2bq7_3 == 0, 0, sa2bq8_3 * sa2bq9_3),
      PHtotal_other_labor_days = dplyr::coalesce(PHother_man_days, 0) + 
        dplyr::coalesce(PHother_woman_days, 0) +
        dplyr::coalesce(PHother_child_days, 0),
      PHtotal_other_labor_days = ifelse(is.na(sa2bq7_1.y), 0, PHtotal_other_labor_days),
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
        dplyr::coalesce(PPtotal_hired_labor_days, 0) +
        dplyr::coalesce(PPtotal_other_labor_days, 0),
      total_family_labor_days = dplyr::coalesce(PHtotal_family_labor_days, 0) + 
        dplyr::coalesce(PPtotal_family_labor_days, 0),
      total_hired_labor_days = dplyr::coalesce(PHtotal_hired_labor_days, 0) + 
        dplyr::coalesce(PPtotal_hired_labor_days, 0)
    ) |>
    dplyr::select(plot_id, total_labor_days, total_family_labor_days, total_hired_labor_days)
  
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
  
  indiv0_data <- read_dta_auto("sect1_harvestw5", input_dir, temp_dir)
  
  indiv_chars <- indiv0_data |>
    dplyr::filter(s1q4 != 2) |>
    dplyr::mutate(
      ID = paste(hhid, indiv, sep = "-"),
      female = dplyr::case_when(
        s1q2 == 2 ~ 1,
        s1q2 == 1 ~ 0,
        TRUE ~ NA_real_
      ),
      age = ifelse(s1q6 == 999, NA, s1q6),
      married = dplyr::case_when(
        s1q16 %in% c(1, 2) ~ 1,
        s1q16 %in% c(3:7) ~ 0,
        TRUE ~ NA_real_
      ),
      relationship_head = as.character(haven::as_factor(s1q3)),
      relationship_head = stringr::str_to_title(relationship_head),
      relationship_head = stringr::str_sub(relationship_head, 
                                           stringr::str_locate(relationship_head, " ")[,1] + 1, 
                                           -1),
      relationship_head = dplyr::case_when(
        relationship_head == "Parent-In-Law" ~ "Father-in-law/Mother-in-law",
        relationship_head == "Son-In-Law/Daughter-In-Law" ~ "Son-in-law/Daughter-in-law",
        relationship_head == "Brother/Sister-In-Law" ~ "Brother-in-law/Sister-in-law",
        relationship_head == "Brother/Sister" ~ "Sister/Brother",
        relationship_head == "Other Non-Relation (Specify)" ~ "Non Relative",
        relationship_head == "Other (Specify)" ~ "Non Relative",
        relationship_head == "Other Relation (Specify)" ~ "Other Relative",
        relationship_head == "Domestic Help (Resident)" ~ "Servant",
        relationship_head == "Grandfather/Mother" ~ "Grandparent",
        relationship_head == "Adopted Child" ~ "Son/Daughter",
        relationship_head == "Own Child" ~ "Son/Daughter",
        relationship_head == "Step Child" ~ "Son/Daughter",
        TRUE ~ relationship_head
      ),
      birth_month = lubridate::ymd(paste(s1q11, s1q10, "01", sep = "-"))
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
  
  indiv_roster1_data <- read_dta_auto("sect2_harvestw5", input_dir, temp_dir)
  
  educ_indiv <- indiv_roster1_data |>
    dplyr::mutate(
      ID = paste(hhid, indiv, sep = "-"),
      formal_education1 = dplyr::case_when(
        s2q6 == 1 ~ 1,
        s2q6 == 2 ~ 0,
        TRUE ~ NA_real_
      ),
      primary_education1 = dplyr::case_when(
        s2q9 >= 16 & s2q9 <= 43 ~ 1,
        s2q9 %in% c(0:15, 51:64, 98, 99) ~ 0,
        TRUE ~ NA_real_
      ),
      primary_education1 = ifelse(formal_education1 == 0, 0, primary_education1)
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
  
  labor_hh_data <- read_dta_auto("sect4a_harvestw5", input_dir, temp_dir)
  
  labor_indiv <- labor_hh_data |>
    dplyr::mutate(
      ID = paste(hhid, indiv, sep = "-"),
      working_age = s4aq1 == 1,
      farm_work1 = dplyr::case_when(
        s4aq10 == 1 ~ 1,
        s4aq10 == 2 ~ 0,
        TRUE ~ NA_real_
      ),
      farm_work2 = dplyr::case_when(
        s4aq11 == 1 ~ 1,
        s4aq11 == 2 ~ 0,
        TRUE ~ NA_real_
      ),
      farm_work = ifelse(farm_work1 == 1 | farm_work2 == 1, 1, 0),
      farm_work = ifelse(farm_work1 == 0, 0, farm_work),
      SOB_work = dplyr::case_when(
        s4aq6 == 1 ~ 1,
        s4aq6 == 2 ~ 0,
        TRUE ~ NA_real_
      ),
      wage_work = dplyr::case_when(
        s4aq40_code == 0 ~ 0,
        !is.na(s4aq40_code) ~ 1,
        TRUE ~ NA_real_
      ),
      wage_work = ifelse(s4aq32 == 2, 0, wage_work),
      farm_hrs = ifelse(s4aq11 == 2, 0, s4aq12),
      SB_hrs = ifelse(s4aq6 == 2, 0, s4aq7),
      wage_hrs = ifelse(s4aq4 == 2, 0, s4aq5),
      ind_ag = ifelse(s4aq41_code > 100 & s4aq41_code < 300 & working_age == 1, 1, 0),
      ind_fish = ifelse(s4aq41_code > 300 & s4aq41_code < 400 & working_age == 1, 1, 0),
      ind_mining = ifelse(s4aq41_code > 500 & s4aq41_code < 1000 & working_age == 1, 1, 0),
      ind_manuf = ifelse(s4aq41_code >= 1010 & s4aq41_code <= 4000 & working_age == 1, 1, 0),
      ind_const = ifelse(s4aq41_code >= 4100 & s4aq41_code <= 4500 & working_age == 1, 1, 0),
      ind_serv = ifelse(s4aq41_code >= 4501 & s4aq41_code <= 10000 & working_age == 1, 1, 0)
    ) |>
    dplyr::mutate(
      dplyr::across(c(ind_ag, ind_fish, ind_mining, ind_manuf, ind_const, ind_serv),
                    ~ ifelse(s4aq42 == 1 | s4aq42 == 2, 0, .))
    ) |>
    dplyr::mutate(
      dplyr::across(c(ind_ag, ind_const, ind_fish, ind_manuf, ind_mining, ind_serv),
                    ~ ifelse(s4aq21 == 1, 0, .))
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

# 7.4 Anthropometric measures
tryCatch({
  cat("  Processing anthropometric measures...\n")
  
  anthropo_data <- read_dta_auto("sect4b_harvestw5", input_dir, temp_dir)
  harvest_interview_data <- haven::read_dta(file.path(temp_dir, "harvest_interview_month.dta"))
  
  wasting_data <- anthropo_data |>
    dplyr::mutate(
      ID = paste(hhid, indiv, sep = "-"),
      weight = rowMeans(dplyr::select(., starts_with("s4bq8")), na.rm = TRUE),
      height = rowMeans(dplyr::select(., starts_with("s4bq12")), na.rm = TRUE)
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
  
  hdds_data <- read_dta_auto("sect5b_harvestw5", input_dir, temp_dir)
  
  hdds_data <- hdds_data |>
    dplyr::filter(s5bq1 == 1) |>
    dplyr::rename(food_id = item_cd) |>
    dplyr::mutate(
      A = ifelse(food_id >= 10 & food_id <= 29, 1, 0),
      B = ifelse(food_id >= 30 & food_id <= 38, 1, 0),
      C = ifelse(food_id >= 70 & food_id <= 79, 1, 0),
      D = ifelse(food_id >= 60 & food_id <= 69, 1, 0),
      E = ifelse((food_id >= 80 & food_id <= 82) | (food_id >= 90 & food_id <= 96), 1, 0),
      F = ifelse(food_id >= 83 & food_id <= 85, 1, 0),
      G = ifelse(food_id >= 100 & food_id <= 107, 1, 0),
      H = ifelse(food_id >= 40 & food_id <= 48, 1, 0),
      I = ifelse(food_id >= 110 & food_id <= 115, 1, 0),
      J = ifelse(food_id >= 50 & food_id <= 56, 1, 0),
      K = ifelse(food_id >= 130 & food_id <= 133, 1, 0),
      L = ifelse((food_id >= 120 & food_id <= 122) | (food_id >= 141 & food_id <= 148), 1, 0)
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

cat("\n=== NGA_GHS5 processing complete ===\n")
cat("Temporary files saved to:", temp_dir, "\n")
cat("✓ All variables extracted successfully\n")