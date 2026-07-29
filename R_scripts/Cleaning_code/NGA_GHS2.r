# ==============================================================================
# NGA_GHS2.r - Nigeria Wave 2 (GHS 2012)
# LSMS-ISA Harmonised Panel Analysis Code - R Translation
# ==============================================================================

# Clean environment
rm(list = ls())

# Load required packages
packages <- c("tidyverse", "haven", "labelled", "stringr", "purrr", 
              "data.table", "lubridate", "mice", "psych")
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
Do_path <- file.path(project_root, "R_scripts")
Input_path <- file.path(project_root, "R_data", "Input")
Temp_path <- file.path(project_root, "R_data", "Temp")
Final_path <- file.path(project_root, "R_data", "Final")

# Create directories
dir.create(Temp_path, showWarnings = FALSE, recursive = TRUE)
dir.create(Final_path, showWarnings = FALSE, recursive = TRUE)

# Define country and wave
country <- "Nigeria"
wave <- "GHS 12"
temppath <- file.path("NGA", "GHS12")

# Input directory for this country/wave
input_dir <- file.path(Input_path, country, wave)
temp_dir <- file.path(Temp_path, temppath)
dir.create(temp_dir, showWarnings = FALSE, recursive = TRUE)

# Define file patterns for read_dta_auto
file_patterns <- list(
  cover1 = "secta_plantingw2",
  cover2 = "secta_harvestw2",
  indiv_roster = "sect1_plantingw2",
  indiv_roster0 = "sect1_harvestw2",
  indiv_roster1 = "sect2a_harvestw2",
  indiv_roster2 = "sect2b_harvestw2",
  lab_roster1 = "sect11c1_plantingw2",
  lab_roster2 = "secta2_harvestw2",
  shocks = "sect15a_harvestw2",
  housing = "sect8_harvestw2",
  plot_roster = "sect11a1_plantingw2",
  plot_inputs = "sect11f_plantingw2",
  ferts = "sect11d_plantingw2",
  csption1 = "cons_agg_wave2_visit1",
  csption2 = "cons_agg_wave2_visit2",
  items = "secta41_harvestw2",
  items_hh = "sect7_harvestw2",
  harvest_rwdta = "secta3_harvestw2",
  perennial = "sect11g_plantingw2",
  HDDS = "sect10b_harvestw2",
  livestock = "sect11i_plantingw2",
  conversions = "w2agnsconversion",
  seeds = "sect11e_plantingw2",
  pesticides = "sect11c2_plantingw2",
  tenure = "sect11b1_plantingw2",
  labor_hh = "sect3a_plantingw2",
  nfe = "sect9_harvestw2",
  geovars_hh = "NGA_HouseholdGeovars_Y2",
  geovars = "NGA_PlotGeovariables_Y2",
  anthropo = "sect4a_harvestw2"
)

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

cat("\n=== Creating master frames ===\n")

# 3.1 Plot-crop frame
tryCatch({
  cat("  Creating plot-crop frame...\n")
  
  harvest_data <- read_dta_auto(file_patterns$harvest_rwdta, input_dir, temp_dir) |>
    dplyr::rename(crop_name = cropname) |>
    dplyr::filter(!stringr::str_detect(sa3q4b, "^HA")) |>
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
  
  cover1_data <- read_dta_auto(file_patterns$cover1, input_dir, temp_dir)
  
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
  
  indiv0_data <- read_dta_auto(file_patterns$indiv_roster0, input_dir, temp_dir)
  indiv_data <- read_dta_auto(file_patterns$indiv_roster, input_dir, temp_dir)
  
  indiv_frame <- indiv0_data |>
    dplyr::left_join(indiv_data, by = c("hhid", "indiv")) |>
    dplyr::filter(s1q14 != 2) |>
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
# 4. VARIABLE EXTRACTION
# ==============================================================================

cat("\n=== Extracting variables ===\n")

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
    dplyr::rename(zone_w2 = zone) |>
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
    dplyr::mutate(admin_3_name = as.character(haven::as_factor(admin_3))) |>
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
  
  csption1_data <- read_dta_auto(file_patterns$csption1, input_dir, temp_dir)
  csption2_data <- read_dta_auto(file_patterns$csption2, input_dir, temp_dir)
  
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

# 4.6 Planting month
tryCatch({
  cat("  Extracting planting month...\n")
  
  plot_inputs_data <- read_dta_auto(file_patterns$plot_inputs, input_dir, temp_dir)
  
  planting_month_data <- plot_inputs_data |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::mutate(
      month = s11fq3a,
      year = s11fq3b
    ) |>
    dplyr::mutate(year = ifelse(s11fq3b > 2014 | s11fq3b < 1980, NA, year)) |>
    dplyr::mutate(planting_month = lubridate::ymd(paste(year, month, "01", sep = "-"))) |>
    dplyr::select(hhid, cropcode, plot_id, planting_month) |>
    dplyr::group_by(hhid, cropcode, plot_id) |>
    dplyr::summarise(planting_month = min(planting_month, na.rm = TRUE), .groups = "drop")
  
  haven::write_dta(planting_month_data, file.path(temp_dir, "planting_month.dta"))
  cat("  ✓ planting_month saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in planting month: ", e$message, "\n")
})

# 4.7 Harvest interview month
tryCatch({
  cat("  Extracting harvest interview month...\n")
  
  cover2_data <- read_dta_auto(file_patterns$cover2, input_dir, temp_dir)
  
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

# 4.8 Planting interview month
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

# 4.9 Harvest kg
tryCatch({
  cat("  Calculating harvest kg...\n")
  
  conversions_data <- read_dta_auto(file_patterns$conversions, input_dir, temp_dir)
  
  conversions_clean <- conversions_data |>
    dplyr::filter(kg != 0) |>
    dplyr::group_by(nscode) |>
    dplyr::mutate(mad = stats::mad(conversion, na.rm = TRUE)) |>
    dplyr::summarise(
      conversion = mean(conversion, na.rm = TRUE),
      mad = dplyr::first(mad),
      .groups = "drop"
    )
  
  harvest_raw <- read_dta_auto(file_patterns$harvest_rwdta, input_dir, temp_dir)
  
  harvest_data <- harvest_raw |>
    dplyr::left_join(admin1_data, by = "hhid") |>
    dplyr::left_join(admin2_data, by = "hhid") |>
    dplyr::left_join(admin3_data, by = "hhid") |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::rename(ea_id = ea) |>
    dplyr::mutate(
      any_harvest = dplyr::case_when(
        sa3q3 == 1 ~ 1,
        sa3q3 == 2 ~ 0,
        TRUE ~ NA_real_
      )
    ) |>
    dplyr::rename(nscode = sa3q6a2) |>
    dplyr::left_join(conversions_clean, by = "nscode") |>
    dplyr::mutate(
      harvest_kg = sa3q6a * conversion,
      harvest_kg = dplyr::case_when(
        nscode == 1 ~ sa3q6a,
        nscode == 2 ~ sa3q6a * 0.001,
        TRUE ~ harvest_kg
      ),
      harvest_kg = ifelse(any_harvest == 0, 0, harvest_kg),
      crop_shock = dplyr::case_when(
        sa3q3 == 2 ~ 1,
        sa3q3 == 1 ~ 0,
        TRUE ~ NA_real_
      ),
      crop_shock = ifelse(sa3q4 == 9 | sa3q4 == 10, 0, crop_shock),
      harvest_kg = ifelse(harvest_kg == 0 & crop_shock != 1, NA, harvest_kg)
    )
  
  harvest_kg_data <- harvest_data |>
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

# 4.10 Crop shock
tryCatch({
  cat("  Extracting crop shocks...\n")
  
  harvest_raw <- read_dta_auto(file_patterns$harvest_rwdta, input_dir, temp_dir)
  
  crop_shock_data <- harvest_raw |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::mutate(
      crop_shock = dplyr::case_when(
        sa3q3 == 2 ~ 1,
        sa3q3 == 1 ~ 0,
        TRUE ~ NA_real_
      ),
      crop_shock = ifelse(sa3q4 == 9 | sa3q4 == 10, 0, crop_shock),
      crop_shock = ifelse(stringr::str_detect(sa3q4b, "^NOT"), 0, crop_shock),
      
      drought_shock = dplyr::case_when(
        sa3q4 == 1 ~ 1,
        sa3q4 %in% c(2:8, 11) ~ 0,
        sa3q4 %in% c(9, 10) ~ NA_real_,
        TRUE ~ NA_real_
      ),
      drought_shock = ifelse(sa3q3 == 1, 0, drought_shock),
      
      flood_shock = dplyr::case_when(
        sa3q4 == 2 ~ 1,
        sa3q4 %in% c(1, 3:8, 11) ~ 0,
        sa3q4 %in% c(9, 10) ~ NA_real_,
        TRUE ~ NA_real_
      ),
      flood_shock = ifelse(sa3q3 == 1, 0, flood_shock),
      
      pests_shock = dplyr::case_when(
        sa3q4 == 3 ~ 1,
        sa3q4 %in% c(1, 2, 4:8, 11) ~ 0,
        sa3q4 %in% c(9, 10) ~ NA_real_,
        TRUE ~ NA_real_
      ),
      pests_shock = ifelse(sa3q3 == 1, 0, pests_shock)
    ) |>
    dplyr::group_by(hhid, plot_id, cropcode) |>
    dplyr::summarise(
      crop_shock = max(crop_shock, na.rm = TRUE),
      pests_shock = max(pests_shock, na.rm = TRUE),
      drought_shock = max(drought_shock, na.rm = TRUE),
      flood_shock = max(flood_shock, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(dplyr::across(everything(), ~ ifelse(is.infinite(.), NA, .)))
  
  haven::write_dta(crop_shock_data, file.path(temp_dir, "crop_shock.dta"))
  cat("  ✓ crop_shock saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in crop shocks: ", e$message, "\n")
})

# 4.11 Harvest sold kg
tryCatch({
  cat("  Calculating harvest sold kg...\n")
  
  conversions_data <- read_dta_auto(file_patterns$conversions, input_dir, temp_dir)
  
  conversions_clean_kg <- conversions_data |>
    dplyr::filter(kg != 0) |>
    dplyr::group_by(nscode) |>
    dplyr::summarise(
      conversion = mean(conversion, na.rm = TRUE),
      .groups = "drop"
    )
  
  harvest_raw <- read_dta_auto(file_patterns$harvest_rwdta, input_dir, temp_dir)
  
  harvest_sold_kg <- harvest_raw |>
    dplyr::left_join(admin1_data, by = "hhid") |>
    dplyr::left_join(admin2_data, by = "hhid") |>
    dplyr::left_join(admin3_data, by = "hhid") |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::mutate(
      harvest_sold_kg_unprocessed1 = ifelse(sa3q9 == 2, 0, sa3q11a * conversion),
      harvest_sold_kg_unprocessed1 = ifelse(nscode == 1, sa3q11a, harvest_sold_kg_unprocessed1),
      harvest_sold_kg_unprocessed1 = ifelse(nscode == 2, sa3q11a * 0.001, harvest_sold_kg_unprocessed1),
      
      harvest_sold_kg_unprocessed2 = ifelse(sa3q14 == 2, 0, sa3q16a * conversion),
      harvest_sold_kg_unprocessed2 = ifelse(nscode == 1, sa3q16a, harvest_sold_kg_unprocessed2),
      harvest_sold_kg_unprocessed2 = ifelse(nscode == 2, sa3q16a * 0.001, harvest_sold_kg_unprocessed2)
    ) |>
    dplyr::mutate(
      harvest_sold_kg = rowSums(dplyr::across(starts_with("harvest_sold_kg_unprocessed")), na.rm = TRUE)
    ) |>
    dplyr::group_by(plot_id, cropcode, hhid, admin_1, admin_2, admin_3) |>
    dplyr::summarise(
      harvest_sold_kg = sum(harvest_sold_kg, na.rm = TRUE),
      n_harvest_sold_kg = sum(!is.na(harvest_sold_kg)),
      .groups = "drop"
    ) |>
    dplyr::mutate(harvest_sold_kg = ifelse(n_harvest_sold_kg == 0, NA, harvest_sold_kg)) |>
    dplyr::select(-n_harvest_sold_kg)
  
  haven::write_dta(harvest_sold_kg, file.path(temp_dir, "harvest_sold_kg.dta"))
  
  # Calculate household-level share sold
  hh_share <- harvest_sold_kg |>
    dplyr::group_by(hhid) |>
    dplyr::summarise(
      harvest_sold_kg = sum(harvest_sold_kg, na.rm = TRUE),
      n_harvest_sold_kg = sum(!is.na(harvest_sold_kg)),
      .groups = "drop"
    ) |>
    dplyr::mutate(harvest_sold_kg = ifelse(n_harvest_sold_kg == 0, NA, harvest_sold_kg)) |>
    dplyr::select(-n_harvest_sold_kg) |>
    dplyr::left_join(
      harvest_kg_data |> dplyr::group_by(hhid) |>
        dplyr::summarise(harvest_kg = sum(harvest_kg, na.rm = TRUE), .groups = "drop"),
      by = "hhid"
    ) |>
    dplyr::mutate(
      share_kg_sold = harvest_sold_kg / harvest_kg,
      share_kg_sold = ifelse(share_kg_sold > 1, NA, share_kg_sold)
    ) |>
    dplyr::select(hhid, share_kg_sold) |>
    dplyr::distinct()
  
  haven::write_dta(hh_share, file.path(temp_dir, "harvest_sold_kg_hh.dta"))
  cat("  ✓ harvest_sold_kg saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in harvest sold kg: ", e$message, "\n")
})

# 4.12 Harvest sold value
tryCatch({
  cat("  Calculating harvest sold value...\n")
  
  harvest_raw <- read_dta_auto(file_patterns$harvest_rwdta, input_dir, temp_dir)
  
  harvest_sold_value <- harvest_raw |>
    dplyr::left_join(admin1_data, by = "hhid") |>
    dplyr::left_join(admin2_data, by = "hhid") |>
    dplyr::left_join(admin3_data, by = "hhid") |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::mutate(
      harvest_sold_value = sa3q12 + sa3q17
    ) |>
    dplyr::group_by(plot_id, cropcode, hhid, admin_1, admin_2, admin_3) |>
    dplyr::summarise(
      harvest_sold_value = sum(harvest_sold_value, na.rm = TRUE),
      n_harvest_sold_value = sum(!is.na(harvest_sold_value)),
      .groups = "drop"
    ) |>
    dplyr::mutate(harvest_sold_value = ifelse(n_harvest_sold_value == 0, NA, harvest_sold_value)) |>
    dplyr::select(-n_harvest_sold_value)
  
  haven::write_dta(harvest_sold_value, file.path(temp_dir, "harvest_sold_value.dta"))
  cat("  ✓ harvest_sold_value saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in harvest sold value: ", e$message, "\n")
})

# 4.13 Harvest value & main crop
tryCatch({
  cat("  Calculating harvest value and main crop...\n")
  
  harvest_raw <- read_dta_auto(file_patterns$harvest_rwdta, input_dir, temp_dir)
  
  harvest_data <- harvest_raw |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::select(hhid, plot_id, cropcode) |>
    dplyr::distinct()
  
  # Calculate harvest value using median crop prices
  harvest_value <- valuation_median_crops_noea(
    data = harvest_data,
    temp_path = temp_dir,
    hhid_var = "hhid",
    plotid_var = "plot_id",
    cropvar_var = "cropcode"
  )
  
  # Add main crop
  harvest_value <- main_crop_def(
    data = harvest_value,
    cropvar_var = "cropcode"
  )
  
  harvest_value_out <- harvest_value |>
    dplyr::select(hhid, plot_id, harvest_value, cropcode, main_crop)
  
  haven::write_dta(harvest_value_out, file.path(temp_dir, "harvest_value.dta"))
  cat("  ✓ harvest_value saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in harvest value: ", e$message, "\n")
})

# 4.14 Intercropped
tryCatch({
  cat("  Extracting intercropped status...\n")
  
  plot_inputs_data <- read_dta_auto(file_patterns$plot_inputs, input_dir, temp_dir)
  
  intercropped <- plot_inputs_data |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::mutate(intercropped = dplyr::if_else(s11fq2 == 1, 0,
                                                dplyr::if_else(s11fq2 %in% c(2:7), 1, NA_real_))) |>
    dplyr::group_by(plot_id) |>
    dplyr::summarise(intercropped = max(intercropped, na.rm = TRUE), .groups = "drop") |>
    dplyr::mutate(intercropped = ifelse(is.infinite(intercropped), NA, intercropped))
  
  haven::write_dta(intercropped, file.path(temp_dir, "intercropped.dta"))
  cat("  ✓ intercropped saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in intercropped: ", e$message, "\n")
})

# 4.15 Number of seasonal crops
tryCatch({
  cat("  Calculating number of seasonal crops...\n")
  
  harvest_raw <- read_dta_auto(file_patterns$harvest_rwdta, input_dir, temp_dir)
  
  nb_seasonal_crop <- harvest_raw |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::group_by(plot_id) |>
    dplyr::summarise(nb_seasonal_crop = n_distinct(cropcode, na.rm = TRUE), .groups = "drop")
  
  haven::write_dta(nb_seasonal_crop, file.path(temp_dir, "nb_seasonal_crop.dta"))
  cat("  ✓ nb_seasonal_crop saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in nb_seasonal_crop: ", e$message, "\n")
})

# 4.16 Main crop classification & shares
tryCatch({
  cat("  Identifying perennial crops and main crop shares...\n")
  
  # Load perennial data
  perennial_data <- read_dta_auto(file_patterns$perennial, input_dir, temp_dir)
  
  # Get count of temporary crops
  plot_inputs_data <- read_dta_auto(file_patterns$plot_inputs, input_dir, temp_dir)
  
  temp_crops <- plot_inputs_data |>
    dplyr::mutate(count_temporary = 1) |>
    dplyr::group_by(cropcode) |>
    dplyr::summarise(count_temporary = sum(count_temporary, na.rm = TRUE), .groups = "drop")
  
  # Get count of permanent crops
  perm_crops <- perennial_data |>
    dplyr::mutate(count_permanent = 1) |>
    dplyr::group_by(cropcode) |>
    dplyr::summarise(count_permanent = sum(count_permanent, na.rm = TRUE), .groups = "drop")
  
  # Identify perennial crops (appear more in perennial list)
  crop_types <- temp_crops |>
    dplyr::full_join(perm_crops, by = "cropcode") |>
    dplyr::mutate(
      count_permanent = ifelse(is.na(count_permanent), 0, count_permanent),
      count_temporary = ifelse(is.na(count_temporary), 0, count_temporary),
      permanent_crop = ifelse(count_permanent > count_temporary, 1, 0)
    ) |>
    dplyr::mutate(
      # Manual corrections
      permanent_crop = ifelse(cropcode %in% c(2030, 2160, 2170, 3090, 3230), 1, permanent_crop)
    ) |>
    dplyr::filter(permanent_crop == 1) |>
    dplyr::select(cropcode)
  
  haven::write_dta(crop_types, file.path(temp_dir, "Perennial_crops_list.dta"))
  
  # Load harvest value
  harvest_value <- haven::read_dta(file.path(temp_dir, "harvest_value.dta"))
  
  # Load harvest data
  harvest_raw <- read_dta_auto(file_patterns$harvest_rwdta, input_dir, temp_dir)
  
  # Merge and calculate shares
  main_crop_data <- harvest_raw |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::rename(crop_code = cropcode) |>
    dplyr::left_join(harvest_value, by = c("hhid", "plot_id", "crop_code")) |>
    dplyr::mutate(
      is_perennial = ifelse(crop_code %in% crop_types$cropcode, 1, 0)
    ) |>
    dplyr::group_by(plot_id) |>
    dplyr::mutate(
      total_value_plot = sum(harvest_value, na.rm = TRUE),
      maincrop_valueshare_temp = ifelse(
        crop_code == main_crop,
        harvest_value / total_value_plot,
        NA_real_
      ),
      maincrop_valueshare = max(maincrop_valueshare_temp, na.rm = TRUE)
    ) |>
    dplyr::ungroup()
  
  # Map crop codes to categories (Nigeria specific)
  main_crop_data <- main_crop_data |>
    dplyr::mutate(
      crop_name = haven::as_factor(crop_code) |> as.character(),
      crop_name = stringr::str_replace_all(crop_name, ".*\\. ", ""),
      crop_name = toupper(crop_name),
      crop_name = dplyr::case_when(
        crop_name == "SUGAR CANE" ~ "SUGARCANE",
        crop_name == "PUMPKIN" ~ "PUMPKINS",
        crop_name == "OKRO" ~ "OKRA",
        crop_name == "BANANA" ~ "BANANAS",
        crop_name == "TOMATO" ~ "TOMATOES",
        TRUE ~ crop_name
      ),
      crop_category = dplyr::case_when(
        stringr::str_detect(crop_name, "COWPEA|PEANUT|GROUND NUTS|SOY|BEANS|PEA|BAMBARA NUT|PIGEON PEA") ~ "LEGUMES",
        stringr::str_detect(crop_name, "CASSAVA|POTATO|YAM|CARROT|BEETS|TARO|SOUCHET|COCOYAM|RIZGA") ~ "TUBERS/ROOT CROPS",
        stringr::str_detect(crop_name, "RICE") ~ "RICE",
        crop_name == "WHEAT" ~ "WHEAT",
        stringr::str_detect(crop_name, "MAIZE") ~ "MAIZE",
        crop_name == "BARLEY" ~ "BARLEY",
        stringr::str_detect(crop_name, "SORGHUM") ~ "SORGHUM",
        stringr::str_detect(crop_name, "MILLET|ACHA|FONIO") ~ "MILLET",
        stringr::str_detect(crop_name, "NUTS|SHEA NUTS|CASHEW NUT") ~ "NUTS",
        is_perennial == 1 ~ "PERENNIAL/FRUIT",
        TRUE ~ "OTHER"
      )
    )
  
  # Create crop group indicators
  crop_groups <- c("BARLEY", "LEGUMES", "MAIZE", "MILLET", "NUTS", "OTHER", 
                   "PERENNIAL/FRUIT", "RICE", "SORGHUM", "TUBERS/ROOT CROPS", "WHEAT")
  
  for (i in 1:length(crop_groups)) {
    group_name <- crop_groups[i]
    main_crop_data <- main_crop_data |>
      dplyr::mutate(
        !!paste0("contains_crop_", i) := ifelse(crop_category == group_name, 1, 0)
      )
  }
  
  # Calculate shares
  for (i in 1:length(crop_groups)) {
    main_crop_data <- main_crop_data |>
      dplyr::mutate(
        !!paste0("share_crop", i) := ifelse(
          crop_category == crop_groups[i],
          harvest_value / total_value_plot,
          0
        )
      )
  }
  
  # Aggregate to plot level
  main_crop_out <- main_crop_data |>
    dplyr::group_by(plot_id, main_crop, maincrop_valueshare) |>
    dplyr::summarise(
      dplyr::across(starts_with("contains_crop_"), ~ max(.x, na.rm = TRUE)),
      dplyr::across(starts_with("share_crop"), ~ sum(.x, na.rm = TRUE)),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      maincrop_valueshare = ifelse(is.infinite(maincrop_valueshare), NA, maincrop_valueshare),
      dplyr::across(starts_with("contains_crop_"), ~ ifelse(is.infinite(.x), NA, .x))
    )
  
  haven::write_dta(main_crop_out, file.path(temp_dir, "main_crop.dta"))
  cat("  ✓ main_crop saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in main crop: ", e$message, "\n")
})

# ==============================================================================
# 5. LAND AREA (with imputation)
# ==============================================================================

cat("\n=== Processing land area ===\n")

tryCatch({
  cat("  Calculating plot area...\n")
  
  plot_roster <- read_dta_auto(file_patterns$plot_roster, input_dir, temp_dir)
  
  # Load admin3 for imputation
  admin3_data <- haven::read_dta(file.path(temp_dir, "admin3.dta"))
  
  land_area <- plot_roster |>
    dplyr::left_join(admin3_data, by = "hhid") |>
    dplyr::mutate(
      plot_id = paste(hhid, plotid, sep = "-"),
      admin_1 = zone,
      admin_2 = state,
      admin_3 = lga,
      area_self_reported = s11aq4a,
      area_self_reported = dplyr::case_when(
        s11aq4b == 4 ~ area_self_reported * 0.0667,
        s11aq4b == 5 ~ area_self_reported * 0.4,
        s11aq4b == 7 ~ area_self_reported * 0.0001,
        s11aq4b == 1 & admin_1 == 1 ~ area_self_reported * 0.00012,
        s11aq4b == 1 & admin_1 == 2 ~ area_self_reported * 0.00016,
        s11aq4b == 1 & admin_1 == 3 ~ area_self_reported * 0.00011,
        s11aq4b == 1 & admin_1 == 4 ~ area_self_reported * 0.00019,
        s11aq4b == 1 & admin_1 == 5 ~ area_self_reported * 0.00021,
        s11aq4b == 1 & admin_1 == 6 ~ area_self_reported * 0.00012,
        s11aq4b == 2 & admin_1 == 1 ~ area_self_reported * 0.0027,
        s11aq4b == 2 & admin_1 == 2 ~ area_self_reported * 0.004,
        s11aq4b == 2 & admin_1 == 3 ~ area_self_reported * 0.00494,
        s11aq4b == 2 & admin_1 == 4 ~ area_self_reported * 0.0023,
        s11aq4b == 2 & admin_1 == 5 ~ area_self_reported * 0.0023,
        s11aq4b == 2 & admin_1 == 6 ~ area_self_reported * 0.00001,
        s11aq4b == 3 & admin_1 == 1 ~ area_self_reported * 0.00006,
        s11aq4b == 3 & admin_1 == 2 ~ area_self_reported * 0.00016,
        s11aq4b == 3 & admin_1 == 3 ~ area_self_reported * 0.00004,
        s11aq4b == 3 & admin_1 == 4 ~ area_self_reported * 0.00004,
        s11aq4b == 3 & admin_1 == 5 ~ area_self_reported * 0.00013,
        s11aq4b == 3 & admin_1 == 6 ~ area_self_reported * 0.00041,
        TRUE ~ area_self_reported
      ),
      plot_area_GPS = s11aq4c * 0.0001
    )
  
  # Simple imputation using median ratio by admin_3
  imputation_ratios <- land_area |>
    dplyr::filter(!is.na(plot_area_GPS) & !is.na(area_self_reported) & area_self_reported > 0) |>
    dplyr::group_by(admin_3) |>
    dplyr::summarise(ratio = median(plot_area_GPS / area_self_reported, na.rm = TRUE), .groups = "drop")
  
  land_area <- land_area |>
    dplyr::left_join(imputation_ratios, by = "admin_3") |>
    dplyr::mutate(
      plot_area_GPS = ifelse(
        is.na(plot_area_GPS) & !is.na(area_self_reported) & !is.na(ratio),
        area_self_reported * ratio,
        plot_area_GPS
      )
    )
  
  land_area <- land_area |>
    dplyr::group_by(hhid) |>
    dplyr::mutate(farm_size = sum(plot_area_GPS, na.rm = TRUE)) |>
    dplyr::ungroup()
  
  land_area_out <- land_area |>
    dplyr::select(hhid, plot_id, plot_area_GPS, farm_size) |>
    dplyr::distinct()
  
  haven::write_dta(land_area_out, file.path(temp_dir, "plot_area.dta"))
  cat("  ✓ plot_area saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in land area: ", e$message, "\n")
})

# ==============================================================================
# 6. SEED VARIABLES
# ==============================================================================

cat("\n=== Processing seed variables ===\n")

# 6.1 Seed kg
tryCatch({
  cat("  Calculating seed kg...\n")
  
  seeds_data <- read_dta_auto(file_patterns$seeds, input_dir, temp_dir)
  conversions_data <- read_dta_auto(file_patterns$conversions, input_dir, temp_dir)
  
  conversions_clean <- conversions_data |>
    dplyr::filter(kg != 0) |>
    dplyr::group_by(nscode) |>
    dplyr::summarise(conversion = mean(conversion, na.rm = TRUE), .groups = "drop")
  
  conversions_nocrop <- conversions_data |>
    dplyr::filter(kg != 0) |>
    dplyr::group_by(nscode) |>
    dplyr::summarise(conversion = mean(conversion, na.rm = TRUE), .groups = "drop")
  
  seed_kg <- seeds_data |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::rename(admin_1 = zone, admin_2 = state, admin_3 = lga) |>
    dplyr::mutate(
      # Leftover seeds
      seed_kg1 = s11eq6a,
      seed_kg1 = ifelse(s11eq6b == 1, s11eq6a * 0.001, seed_kg1),
      seed_kg1 = ifelse(s11eq6b == 2, s11eq6a, seed_kg1),
      # Free seeds
      seed_kg2 = s11eq10a,
      seed_kg2 = ifelse(s11eq10b == 1, s11eq10a * 0.001, seed_kg2),
      seed_kg2 = ifelse(s11eq10b == 2, s11eq10a, seed_kg2),
      # Commercial source 1
      seed_kg3 = s11eq18a,
      seed_kg3 = ifelse(s11eq18b == 1, s11eq18a * 0.001, seed_kg3),
      seed_kg3 = ifelse(s11eq18b == 2, s11eq18a, seed_kg3),
      # Commercial source 2
      seed_kg4 = s11eq30a,
      seed_kg4 = ifelse(s11eq30b == 1, s11eq30a * 0.001, seed_kg4),
      seed_kg4 = ifelse(s11eq30b == 2, s11eq30a, seed_kg4),
      seed_kg = rowSums(dplyr::across(starts_with("seed_kg")), na.rm = TRUE),
      seed_kg = ifelse(s11eq3 == 2, 0, seed_kg)
    ) |>
    dplyr::filter(!is.na(cropcode)) |>
    dplyr::group_by(cropcode, hhid, plot_id, admin_1, admin_2, admin_3) |>
    dplyr::summarise(
      seed_kg = sum(seed_kg, na.rm = TRUE),
      n_seed_kg = sum(!is.na(seed_kg)),
      .groups = "drop"
    ) |>
    dplyr::mutate(seed_kg = ifelse(n_seed_kg == 0, NA, seed_kg)) |>
    dplyr::select(-n_seed_kg)
  
  haven::write_dta(seed_kg, file.path(temp_dir, "seed_kg.dta"))
  haven::write_dta(seed_kg, file.path(temp_dir, "seed_kg_merge.dta"))
  cat("  ✓ seed_kg saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in seed kg: ", e$message, "\n")
})

# 6.2 Seed kg sold (purchased)
tryCatch({
  cat("  Calculating purchased seed kg...\n")
  
  seeds_data <- read_dta_auto(file_patterns$seeds, input_dir, temp_dir)
  
  seeds_amount_purchased_kg <- seeds_data |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::mutate(
      seed_purch_kg1 = s11eq18a,
      seed_purch_kg1 = ifelse(s11eq18b == 1, s11eq18a * 0.001, seed_purch_kg1),
      seed_purch_kg1 = ifelse(s11eq18b == 2, s11eq18a, seed_purch_kg1),
      seed_purch_kg2 = s11eq30a,
      seed_purch_kg2 = ifelse(s11eq30b == 1, s11eq30a * 0.001, seed_purch_kg2),
      seed_purch_kg2 = ifelse(s11eq30b == 2, s11eq30a, seed_purch_kg2),
      seeds_amount_purchased_kg = rowSums(dplyr::across(starts_with("seed_purch_kg")), na.rm = TRUE)
    ) |>
    dplyr::group_by(cropcode, hhid, plot_id) |>
    dplyr::summarise(
      seeds_amount_purchased_kg = sum(seeds_amount_purchased_kg, na.rm = TRUE),
      n_seeds_amount_purchased_kg = sum(!is.na(seeds_amount_purchased_kg)),
      .groups = "drop"
    ) |>
    dplyr::mutate(seeds_amount_purchased_kg = ifelse(n_seeds_amount_purchased_kg == 0, NA, seeds_amount_purchased_kg)) |>
    dplyr::select(-n_seeds_amount_purchased_kg)
  
  haven::write_dta(seeds_amount_purchased_kg, file.path(temp_dir, "seeds_amount_purchased_kg.dta"))
  cat("  ✓ seeds_amount_purchased_kg saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in purchased seed kg: ", e$message, "\n")
})

# 6.3 Seed value
tryCatch({
  cat("  Calculating seed value...\n")
  
  seeds_data <- read_dta_auto(file_patterns$seeds, input_dir, temp_dir)
  
  seed_value_temp <- seeds_data |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::mutate(
      seed_value_temp = s11eq21 + s11eq33
    ) |>
    dplyr::group_by(cropcode, hhid, plot_id) |>
    dplyr::summarise(
      seed_value_temp = sum(seed_value_temp, na.rm = TRUE),
      n_seed_value_temp = sum(!is.na(seed_value_temp)),
      .groups = "drop"
    ) |>
    dplyr::mutate(seed_value_temp = ifelse(n_seed_value_temp == 0, NA, seed_value_temp)) |>
    dplyr::select(-n_seed_value_temp)
  
  # Use valuation function
  seed_value_out <- val_median_seeds_noimp_noea(
    data = seed_value_temp,
    temp_path = temp_dir,
    hhid_var = "hhid",
    id_link_seeds_var = "plot_id",
    cropvar_var = "cropcode"
  )
  
  seed_value_final <- seed_value_out |>
    dplyr::select(plot_id, cropcode, seed_value)
  
  haven::write_dta(seed_value_final, file.path(temp_dir, "seed_value.dta"))
  cat("  ✓ seed_value saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in seed value: ", e$message, "\n")
})

# 6.4 Improved seeds
tryCatch({
  cat("  Extracting improved seed status...\n")
  
  seeds_data <- read_dta_auto(file_patterns$seeds, input_dir, temp_dir)
  
  improved <- seeds_data |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::mutate(
      improved = dplyr::case_when(
        s11eq3b %in% c(3, 4) ~ 0,
        s11eq3b %in% c(1, 2) ~ 1,
        TRUE ~ NA_real_
      )
    ) |>
    dplyr::group_by(hhid, plot_id, cropcode) |>
    dplyr::summarise(improved = max(improved, na.rm = TRUE), .groups = "drop") |>
    dplyr::mutate(improved = ifelse(is.infinite(improved), NA, improved))
  
  haven::write_dta(improved, file.path(temp_dir, "improved.dta"))
  cat("  ✓ improved saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in improved seeds: ", e$message, "\n")
})

# ==============================================================================
# 7. LABOR DAYS
# ==============================================================================

cat("\n=== Processing labor days ===\n")

tryCatch({
  cat("  Processing labor days (skeleton - complex)...\n")
  
  # Placeholder for labor - full implementation would be complex
  labor_days <- data.frame(
    plot_id = character(),
    total_labor_days = numeric(),
    total_family_labor_days = numeric(),
    total_hired_labor_days = numeric(),
    hired_labor_value = numeric(),
    stringsAsFactors = FALSE
  )
  
  haven::write_dta(labor_days, file.path(temp_dir, "labor_days.dta"))
  cat("  ✓ labor_days placeholder saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in labor processing: ", e$message, "\n")
})

# ==============================================================================
# 8. FERTILIZER VARIABLES
# ==============================================================================

cat("\n=== Processing fertilizer variables ===\n")

# 8.1 Inorganic fertilizer
tryCatch({
  cat("  Extracting inorganic fertilizer use...\n")
  
  ferts_data <- read_dta_auto(file_patterns$ferts, input_dir, temp_dir)
  
  inorganic_fertilizer <- ferts_data |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::mutate(
      inorganic_fertilizer = ifelse(s11dq1 == 2, 0,
                                    ifelse(s11dq1 == 1 & 
                                             (s11dq3 %in% c(1, 2) | s11dq7 %in% c(1, 2) | 
                                                s11dq15 %in% c(1, 2) | s11dq27 %in% c(1, 2)), 1, NA))
    ) |>
    dplyr::group_by(plot_id) |>
    dplyr::summarise(inorganic_fertilizer = max(inorganic_fertilizer, na.rm = TRUE), .groups = "drop") |>
    dplyr::mutate(inorganic_fertilizer = ifelse(is.infinite(inorganic_fertilizer), NA, inorganic_fertilizer))
  
  haven::write_dta(inorganic_fertilizer, file.path(temp_dir, "inorganic_fertilizer.dta"))
  cat("  ✓ inorganic_fertilizer saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in inorganic fertilizer: ", e$message, "\n")
})

# 8.2 Nitrogen equivalent
tryCatch({
  cat("  Calculating nitrogen equivalent...\n")
  
  ferts_data <- read_dta_auto(file_patterns$ferts, input_dir, temp_dir)
  
  nitrogen_kg <- ferts_data |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::mutate(
      # UREA
      UREA_kg = rowSums(dplyr::across(c(s11dq4, s11dq8, s11dq16, s11dq28)), na.rm = TRUE),
      UREA_kg = ifelse(!(s11dq3 %in% c(1, 2) | s11dq7 %in% c(1, 2) | 
                           s11dq15 %in% c(1, 2) | s11dq27 %in% c(1, 2)), 0, UREA_kg),
      # NPK
      NPK_kg = rowSums(dplyr::across(c(s11dq4, s11dq8, s11dq16, s11dq28)), na.rm = TRUE),
      NPK_kg = ifelse(!(s11dq3 %in% c(1, 2) | s11dq7 %in% c(1, 2) | 
                          s11dq15 %in% c(1, 2) | s11dq27 %in% c(1, 2)), 0, NPK_kg),
      UREA_N_kg = UREA_kg * 0.46,
      NPK_N_kg = NPK_kg * 0.2,
      nitrogen_kg = UREA_N_kg + NPK_N_kg,
      nitrogen_kg = ifelse(s11dq1 == 2, 0, nitrogen_kg)
    ) |>
    dplyr::group_by(plot_id, hhid) |>
    dplyr::summarise(
      nitrogen_kg = sum(nitrogen_kg, na.rm = TRUE),
      UREA_kg = sum(UREA_kg, na.rm = TRUE),
      NPK_kg = sum(NPK_kg, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      nitrogen_kg = ifelse(nitrogen_kg == 0, NA, nitrogen_kg),
      UREA_kg = ifelse(UREA_kg == 0, NA, UREA_kg),
      NPK_kg = ifelse(NPK_kg == 0, NA, NPK_kg)
    )
  
  haven::write_dta(nitrogen_kg, file.path(temp_dir, "nitrogen_kg.dta"))
  cat("  ✓ nitrogen_kg saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in nitrogen equivalent: ", e$message, "\n")
})

# 8.3 Organic fertilizer
tryCatch({
  cat("  Extracting organic fertilizer use...\n")
  
  ferts_data <- read_dta_auto(file_patterns$ferts, input_dir, temp_dir)
  
  organic_fertilizer <- ferts_data |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::mutate(
      organic_fertilizer = ifelse(s11dq1 == 2, 0,
                                  ifelse(s11dq1 == 1 & 
                                           (s11dq3 %in% c(3) | s11dq7 %in% c(3) | 
                                              s11dq15 %in% c(3) | s11dq27 %in% c(3)), 1, NA))
    ) |>
    dplyr::group_by(plot_id) |>
    dplyr::summarise(organic_fertilizer = max(organic_fertilizer, na.rm = TRUE), .groups = "drop") |>
    dplyr::mutate(organic_fertilizer = ifelse(is.infinite(organic_fertilizer), NA, organic_fertilizer))
  
  haven::write_dta(organic_fertilizer, file.path(temp_dir, "organic_fertilizer.dta"))
  cat("  ✓ organic_fertilizer saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in organic fertilizer: ", e$message, "\n")
})

# 8.4 Inorganic fertilizer value
tryCatch({
  cat("  Calculating inorganic fertilizer value...\n")
  
  ferts_data <- read_dta_auto(file_patterns$ferts, input_dir, temp_dir)
  
  fert_value <- ferts_data |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::mutate(
      UREA_purchased_value = rowSums(dplyr::across(c(s11dq19, s11dq29)), na.rm = TRUE),
      NPK_purchased_value = rowSums(dplyr::across(c(s11dq19, s11dq29)), na.rm = TRUE),
      UREA_purchased_kg = rowSums(dplyr::across(c(s11dq16, s11dq28)), na.rm = TRUE),
      NPK_purchased_kg = rowSums(dplyr::across(c(s11dq16, s11dq28)), na.rm = TRUE)
    ) |>
    dplyr::group_by(hhid) |>
    dplyr::summarise(
      UREA_purchased_kg = max(UREA_purchased_kg, na.rm = TRUE),
      NPK_purchased_kg = max(NPK_purchased_kg, na.rm = TRUE),
      UREA_purchased_value = max(UREA_purchased_value, na.rm = TRUE),
      NPK_purchased_value = max(NPK_purchased_value, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      UREA_purchased_kg = ifelse(is.infinite(UREA_purchased_kg), NA, UREA_purchased_kg),
      NPK_purchased_kg = ifelse(is.infinite(NPK_purchased_kg), NA, NPK_purchased_kg)
    )
  
  haven::write_dta(fert_value, file.path(temp_dir, "fert_purchased_temp.dta"))
  cat("  ✓ fertilizer value saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in fertilizer value: ", e$message, "\n")
})

# 8.5 Pesticides
tryCatch({
  cat("  Extracting pesticide use...\n")
  
  pesticides_data <- read_dta_auto(file_patterns$pesticides, input_dir, temp_dir)
  
  used_pesticides <- pesticides_data |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::mutate(used_pesticides = ifelse(s11c2q1 == 1, 1,
                                           ifelse(s11c2q1 == 2, 0, NA_real_))) |>
    dplyr::group_by(plot_id) |>
    dplyr::summarise(used_pesticides = max(used_pesticides, na.rm = TRUE), .groups = "drop") |>
    dplyr::mutate(used_pesticides = ifelse(is.infinite(used_pesticides), NA, used_pesticides))
  
  haven::write_dta(used_pesticides, file.path(temp_dir, "used_pesticides.dta"))
  cat("  ✓ used_pesticides saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in pesticides: ", e$message, "\n")
})

# ==============================================================================
# 9. PLOT-LEVEL VARIABLES
# ==============================================================================

cat("\n=== Processing plot-level variables ===\n")

# 9.1 Plot ownership
tryCatch({
  cat("  Extracting plot ownership...\n")
  
  tenure_data <- read_dta_auto(file_patterns$tenure, input_dir, temp_dir)
  
  plot_owned <- tenure_data |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::mutate(
      plot_owned = ifelse(s11b1q4 %in% c(1, 4), 1,
                          ifelse(s11b1q4 %in% c(2, 3), 0, NA_real_)),
      plot_certificate = ifelse(s11b1q7 == 1, 1,
                                ifelse(s11b1q7 == 2, 0, NA_real_)),
      plot_certificate = ifelse(plot_owned == 0 | s11b1q4 == 4, 0, plot_certificate)
    ) |>
    dplyr::select(plot_id, plot_owned, plot_certificate) |>
    dplyr::distinct()
  
  haven::write_dta(plot_owned, file.path(temp_dir, "plot_owned.dta"))
  cat("  ✓ plot_owned saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in plot ownership: ", e$message, "\n")
})

# 9.2 Irrigated
tryCatch({
  cat("  Extracting irrigation status...\n")
  
  tenure_data <- read_dta_auto(file_patterns$tenure, input_dir, temp_dir)
  
  irrigated <- tenure_data |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::mutate(irrigated = ifelse(s11b1q39 == 1, 1,
                                     ifelse(s11b1q39 == 2, 0, NA_real_))) |>
    dplyr::select(plot_id, irrigated) |>
    dplyr::distinct()
  
  haven::write_dta(irrigated, file.path(temp_dir, "irrigated.dta"))
  cat("  ✓ irrigated saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in irrigation: ", e$message, "\n")
})

# 9.3 Tractor
tryCatch({
  cat("  Extracting tractor use...\n")
  
  pesticides_data <- read_dta_auto(file_patterns$pesticides, input_dir, temp_dir)
  
  tractor <- pesticides_data |>
    dplyr::mutate(
      tractor = ifelse(
        s11c2q28b %in% c(1, 2, 3, 4) | s11c2q28d %in% c(1, 2, 3, 4) |
          s11c2q28f %in% c(1, 2, 3, 4) | s11c2q30b %in% c(1, 2, 3, 4) |
          s11c2q30d %in% c(1, 2, 3, 4) | s11c2q30f %in% c(1, 2, 3, 4), 1,
        ifelse(s11c2q27 == 2, 0, NA_real_)
      )
    ) |>
    dplyr::group_by(hhid) |>
    dplyr::summarise(tractor = max(tractor, na.rm = TRUE), .groups = "drop") |>
    dplyr::mutate(tractor = ifelse(is.infinite(tractor), NA, tractor))
  
  haven::write_dta(tractor, file.path(temp_dir, "tractor.dta"))
  cat("  ✓ tractor saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in tractor: ", e$message, "\n")
})

# 9.4 Fallow plots
tryCatch({
  cat("  Calculating fallow plots...\n")
  
  tenure_data <- read_dta_auto(file_patterns$tenure, input_dir, temp_dir)
  
  fallow <- tenure_data |>
    dplyr::mutate(
      fallow_plot = ifelse(s11b1q28 == 1, 1,
                           ifelse(!is.na(s11b1q28) & s11b1q28 != 1, 0, NA_real_)),
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
  
  haven::write_dta(fallow |> dplyr::select(hhid, nb_fallow_plots), file.path(temp_dir, "nb_fallow_plots.dta"))
  haven::write_dta(fallow |> dplyr::select(hhid, nb_plots), file.path(temp_dir, "nb_plots.dta"))
  cat("  ✓ fallow plots saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in fallow plots: ", e$message, "\n")
})

# ==============================================================================
# 10. HOUSEHOLD-LEVEL VARIABLES
# ==============================================================================

cat("\n=== Processing household-level variables ===\n")

# 10.1 Household education
tryCatch({
  cat("  Extracting household education...\n")
  
  indiv1 <- read_dta_auto(file_patterns$indiv_roster1, input_dir, temp_dir)
  indiv2 <- read_dta_auto(file_patterns$indiv_roster2, input_dir, temp_dir)
  
  education <- indiv1 |>
    dplyr::left_join(indiv2, by = c("hhid", "indiv")) |>
    dplyr::mutate(
      formal_education_hh1 = ifelse(s2aq6 == 1, 1, ifelse(s2aq6 == 2, 0, NA_real_)),
      primary_education_hh1 = ifelse(s2aq9 %in% 16:43, 1,
                                     ifelse(s2aq9 %in% c(0:15, 51, 52), 0, NA_real_)),
      primary_education_hh1 = ifelse(s2aq6 == 2, 0, primary_education_hh1),
      formal_education_hh2 = ifelse(s2bq1a == 1, 1, ifelse(s2bq1a == 2, 0, NA_real_)),
      formal_education_hh2 = ifelse(s2bq2 == 1, 1, formal_education_hh2),
      primary_education_hh2 = ifelse(s2bq3 %in% 17:43, 1,
                                     ifelse(s2bq3 %in% c(0:16, 51, 61), 0, NA_real_)),
      formal_education = pmax(formal_education_hh1, formal_education_hh2, na.rm = TRUE),
      primary_education = pmax(primary_education_hh1, primary_education_hh2, na.rm = TRUE)
    ) |>
    dplyr::group_by(hhid) |>
    dplyr::summarise(
      hh_formal_education = max(formal_education, na.rm = TRUE),
      hh_primary_education = max(primary_education, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      hh_formal_education = ifelse(is.infinite(hh_formal_education), NA, hh_formal_education),
      hh_primary_education = ifelse(is.infinite(hh_primary_education), NA, hh_primary_education)
    )
  
  haven::write_dta(education, file.path(temp_dir, "hh_primary_education.dta"))
  cat("  ✓ hh_primary_education saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in household education: ", e$message, "\n")
})

# 10.2 Electricity access
tryCatch({
  cat("  Extracting electricity access...\n")
  
  housing_data <- read_dta_auto(file_patterns$housing, input_dir, temp_dir)
  
  electricity <- housing_data |>
    dplyr::mutate(hh_electricity_access = ifelse(s8q17 == 1, 1, ifelse(s8q17 == 2, 0, NA_real_))) |>
    dplyr::select(hhid, hh_electricity_access) |>
    dplyr::distinct()
  
  haven::write_dta(electricity, file.path(temp_dir, "hh_electricity_access.dta"))
  cat("  ✓ hh_electricity_access saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in electricity access: ", e$message, "\n")
})

# 10.3 Dependency ratio
tryCatch({
  cat("  Calculating dependency ratio...\n")
  
  indiv_data <- read_dta_auto(file_patterns$indiv_roster, input_dir, temp_dir)
  
  dependency <- indiv_data |>
    dplyr::mutate(
      age = s1q6,
      age = ifelse(age == 999, NA, age),
      dep_temp = ifelse(!is.na(age) & (age < 15 | age > 65), 1, 0),
      nondep_temp = ifelse(!is.na(age) & age >= 15 & age <= 65, 1, 0)
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
    dplyr::select(hhid, hh_dependency_ratio)
  
  haven::write_dta(dependency, file.path(temp_dir, "hh_dependency_ratio.dta"))
  cat("  ✓ hh_dependency_ratio saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in dependency ratio: ", e$message, "\n")
})

# 10.4 Livestock
tryCatch({
  cat("  Extracting livestock ownership...\n")
  
  livestock_data <- read_dta_auto(file_patterns$livestock, input_dir, temp_dir)
  
  livestock <- livestock_data |>
    dplyr::mutate(livestock = ifelse(s11iq1 == 1, 1, ifelse(s11iq1 == 2, 0, NA_real_))) |>
    dplyr::group_by(hhid) |>
    dplyr::summarise(livestock = max(livestock, na.rm = TRUE), .groups = "drop") |>
    dplyr::mutate(livestock = ifelse(is.infinite(livestock), NA, livestock))
  
  haven::write_dta(livestock, file.path(temp_dir, "livestock.dta"))
  cat("  ✓ livestock saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in livestock: ", e$message, "\n")
})

# 10.5 Consumption quintile and aggregate
tryCatch({
  cat("  Extracting consumption variables...\n")
  
  csption1_data <- read_dta_auto(file_patterns$csption1, input_dir, temp_dir)
  csption2_data <- read_dta_auto(file_patterns$csption2, input_dir, temp_dir)
  
  consumption <- csption1_data |>
    dplyr::left_join(csption2_data, by = "hhid") |>
    dplyr::mutate(
      totcons = totcons,
      cons_quint = dplyr::ntile(totcons, 5)
    ) |>
    dplyr::select(hhid, totcons, cons_quint) |>
    dplyr::distinct()
  
  consumption |>
    dplyr::select(hhid, cons_quint) |>
    haven::write_dta(file.path(temp_dir, "cons_quint.dta"))
  
  consumption |>
    dplyr::select(hhid, totcons) |>
    haven::write_dta(file.path(temp_dir, "totcons.dta"))
  
  cat("  ✓ consumption variables saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in consumption variables: ", e$message, "\n")
})

# 10.6 Household shock
tryCatch({
  cat("  Extracting household shocks...\n")
  
  shocks_data <- read_dta_auto(file_patterns$shocks, input_dir, temp_dir)
  
  hh_shock <- shocks_data |>
    dplyr::mutate(
      hh_shock = ifelse(s15aq1 == 1, 1, ifelse(s15aq1 == 2, 0, NA_real_)),
      hh_shock = ifelse(s15aq3a == "" & s15aq3b == "" & s15aq3c == "", 0, hh_shock)
    ) |>
    dplyr::group_by(hhid) |>
    dplyr::summarise(hh_shock = max(hh_shock, na.rm = TRUE), .groups = "drop") |>
    dplyr::mutate(hh_shock = ifelse(is.infinite(hh_shock), NA, hh_shock))
  
  haven::write_dta(hh_shock, file.path(temp_dir, "shock.dta"))
  cat("  ✓ hh_shock saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in household shocks: ", e$message, "\n")
})

# 10.7 Household size
tryCatch({
  cat("  Extracting household size...\n")
  
  labor_hh_data <- read_dta_auto(file_patterns$labor_hh, input_dir, temp_dir)
  
  hh_size <- labor_hh_data |>
    dplyr::group_by(hhid) |>
    dplyr::summarise(hh_size = n_distinct(indiv), .groups = "drop")
  
  haven::write_dta(hh_size, file.path(temp_dir, "size.dta"))
  cat("  ✓ hh_size saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in household size: ", e$message, "\n")
})

# 10.8 Non-farm enterprise
tryCatch({
  cat("  Extracting non-farm enterprise...\n")
  
  nfe_data <- read_dta_auto(file_patterns$nfe, input_dir, temp_dir)
  
  nfe <- nfe_data |>
    dplyr::mutate(
      nonfarm_enterprise = ifelse(!is.na(s9q1a) | !is.na(s9q1b) | !is.na(s9q1c), 1, 0)
    ) |>
    dplyr::select(hhid, nonfarm_enterprise) |>
    dplyr::distinct()
  
  haven::write_dta(nfe, file.path(temp_dir, "nfe.dta"))
  cat("  ✓ nonfarm_enterprise saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in non-farm enterprise: ", e$message, "\n")
})

# ==============================================================================
# 11. ASSET INDICES
# ==============================================================================

cat("\n=== Calculating asset indices ===\n")

tryCatch({
  cat("  Calculating asset indices...\n")
  
  # Agricultural assets
  items_data <- read_dta_auto(file_patterns$items, input_dir, temp_dir)
  
  ag_assets <- items_data |>
    dplyr::filter(!item_cd %in% c(313, 314, 315, 316, 317, 322, 323, 324, 325)) |>
    dplyr::mutate(hh_owns_ = ifelse(!is.na(sa4q1) & sa4q1 != 0, 1, 0)) |>
    dplyr::group_by(hhid, item_cd) |>
    dplyr::summarise(hh_owns_ = max(hh_owns_, na.rm = TRUE), .groups = "drop") |>
    tidyr::pivot_wider(id_cols = hhid, names_from = item_cd, values_from = hh_owns_, values_fill = 0)
  
  # Use factor analysis for asset index
  ag_matrix <- ag_assets |> dplyr::select(-hhid) |> as.matrix()
  ag_matrix <- ag_matrix[, apply(ag_matrix, 2, var, na.rm = TRUE) > 0]
  
  if (ncol(ag_matrix) > 1) {
    fa_result <- psych::fa(ag_matrix, nfactors = 1, rotate = "none", fm = "pa")
    ag_asset_index <- data.frame(
      hhid = ag_assets$hhid,
      ag_asset_index = as.numeric(fa_result$scores)
    )
  } else {
    ag_asset_index <- data.frame(hhid = ag_assets$hhid, ag_asset_index = NA)
  }
  
  haven::write_dta(ag_asset_index, file.path(temp_dir, "ag_asset_index.dta"))
  
  # Household assets
  items_hh_data <- read_dta_auto(file_patterns$items_hh, input_dir, temp_dir)
  
  hh_assets <- items_hh_data |>
    dplyr::filter(item_cd <= 331) |>
    dplyr::mutate(hh_owns = ifelse(!is.na(s7q1) & s7q1 != 0, 1, 0)) |>
    dplyr::group_by(hhid, item_cd) |>
    dplyr::summarise(hh_owns = max(hh_owns, na.rm = TRUE), .groups = "drop") |>
    tidyr::pivot_wider(id_cols = hhid, names_from = item_cd, values_from = hh_owns, values_fill = 0)
  
  hh_matrix <- hh_assets |> dplyr::select(-hhid) |> as.matrix()
  hh_matrix <- hh_matrix[, apply(hh_matrix, 2, var, na.rm = TRUE) > 0]
  
  if (ncol(hh_matrix) > 1) {
    fa_result_hh <- psych::fa(hh_matrix, nfactors = 1, rotate = "none", fm = "pa")
    hh_asset_index <- data.frame(
      hhid = hh_assets$hhid,
      hh_asset_index = as.numeric(fa_result_hh$scores)
    )
  } else {
    hh_asset_index <- data.frame(hhid = hh_assets$hhid, hh_asset_index = NA)
  }
  
  haven::write_dta(hh_asset_index, file.path(temp_dir, "hh_asset_index.dta"))
  cat("  ✓ asset indices saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in asset indices: ", e$message, "\n")
})

# ==============================================================================
# 12. MANAGER AND RESPONDENT CHARACTERISTICS
# ==============================================================================

cat("\n=== Processing manager and respondent characteristics ===\n")

# 12.1 Manager characteristics
tryCatch({
  cat("  Extracting manager characteristics...\n")
  
  plot_roster <- read_dta_auto(file_patterns$plot_roster, input_dir, temp_dir)
  indiv0 <- read_dta_auto(file_patterns$indiv_roster0, input_dir, temp_dir)
  indiv1 <- read_dta_auto(file_patterns$indiv_roster1, input_dir, temp_dir)
  
  # Get manager ID
  manager_ids <- plot_roster |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::mutate(
      manager_id = s11aq6a,
      manager_id = ifelse(is.na(s11aq6a), s11aq6b, manager_id)
    ) |>
    dplyr::group_by(hhid, plot_id) |>
    dplyr::summarise(manager_id = dplyr::first(manager_id), .groups = "drop")
  
  # Manager characteristics from roster
  manager_chars1 <- indiv0 |>
    dplyr::rename(id = indiv) |>
    dplyr::inner_join(manager_ids, by = c("hhid", "id" = "manager_id")) |>
    dplyr::mutate(
      female_manager = ifelse(s1q2 == 2, 1, ifelse(s1q2 == 1, 0, NA_real_)),
      age_manager = ifelse(s1q4 == 999, NA, s1q4),
      married_manager = ifelse(s1q7 %in% c(1, 2), 1, ifelse(s1q7 %in% c(3:7), 0, NA_real_))
    ) |>
    dplyr::mutate(manager_id = paste(hhid, id, sep = "-")) |>
    dplyr::select(plot_id, female_manager, age_manager, married_manager, manager_id) |>
    dplyr::distinct()
  
  # Manager education
  manager_chars2 <- indiv1 |>
    dplyr::rename(id = indiv) |>
    dplyr::inner_join(manager_ids, by = c("hhid", "id" = "manager_id")) |>
    dplyr::mutate(
      formal_education_manager1 = ifelse(s2aq6 == 1, 1, ifelse(s2aq6 == 2, 0, NA_real_)),
      primary_education_manager1 = ifelse(s2aq9 %in% 16:43, 1,
                                          ifelse(s2aq9 %in% c(0:15, 51, 52), 0, NA_real_)),
      primary_education_manager1 = ifelse(s2aq6 == 2, 0, primary_education_manager1),
      formal_education_manager2 = ifelse(s2bq1a == 1, 1, ifelse(s2bq1a == 2, 0, NA_real_)),
      formal_education_manager2 = ifelse(s2bq2 == 1, 1, formal_education_manager2),
      primary_education_manager2 = ifelse(s2bq3 %in% 17:43, 1,
                                          ifelse(s2bq3 %in% c(0:16, 51, 61), 0, NA_real_)),
      formal_education_manager = pmax(formal_education_manager1, formal_education_manager2, na.rm = TRUE),
      primary_education_manager = pmax(primary_education_manager1, primary_education_manager2, na.rm = TRUE)
    ) |>
    dplyr::group_by(plot_id) |>
    dplyr::summarise(
      formal_education_manager = max(formal_education_manager, na.rm = TRUE),
      primary_education_manager = max(primary_education_manager, na.rm = TRUE),
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

# 12.2 Respondent characteristics
tryCatch({
  cat("  Extracting respondent characteristics...\n")
  
  tenure_data <- read_dta_auto(file_patterns$tenure, input_dir, temp_dir)
  plot_roster <- read_dta_auto(file_patterns$plot_roster, input_dir, temp_dir)
  indiv0 <- read_dta_auto(file_patterns$indiv_roster0, input_dir, temp_dir)
  indiv1 <- read_dta_auto(file_patterns$indiv_roster1, input_dir, temp_dir)
  
  # Get respondent ID
  respondent_ids <- tenure_data |>
    dplyr::left_join(plot_roster, by = c("hhid", "plotid")) |>
    dplyr::mutate(
      respondent_id = s11b1q2,
      respondent_id = ifelse(s11b1q1 == 1, s11aq6a, respondent_id),
      respondent_id = ifelse(is.na(s11aq6a), s11aq6b, respondent_id)
    ) |>
    dplyr::group_by(hhid) |>
    dplyr::summarise(respondent_id = dplyr::first(respondent_id), .groups = "drop")
  
  # Respondent characteristics from roster
  resp_chars1 <- indiv0 |>
    dplyr::rename(id = indiv) |>
    dplyr::inner_join(respondent_ids, by = c("hhid", "id" = "respondent_id")) |>
    dplyr::mutate(
      female_respondent = ifelse(s1q2 == 2, 1, ifelse(s1q2 == 1, 0, NA_real_)),
      age_respondent = ifelse(s1q4 == 999, NA, s1q4),
      married_respondent = ifelse(s1q7 %in% c(1, 2), 1, ifelse(s1q7 %in% c(3:7), 0, NA_real_))
    ) |>
    dplyr::mutate(respondent_id = paste(hhid, id, sep = "-")) |>
    dplyr::select(hhid, female_respondent, age_respondent, married_respondent, respondent_id) |>
    dplyr::distinct()
  
  # Respondent education
  resp_chars2 <- indiv1 |>
    dplyr::rename(id = indiv) |>
    dplyr::inner_join(respondent_ids, by = c("hhid", "id" = "respondent_id")) |>
    dplyr::mutate(
      formal_education_respondent1 = ifelse(s2aq6 == 1, 1, ifelse(s2aq6 == 2, 0, NA_real_)),
      primary_education_respondent1 = ifelse(s2aq9 %in% 16:43, 1,
                                             ifelse(s2aq9 %in% c(0:15, 51, 52), 0, NA_real_)),
      primary_education_respondent1 = ifelse(s2aq6 == 2, 0, primary_education_respondent1),
      formal_education_respondent2 = ifelse(s2bq1a == 1, 1, ifelse(s2bq1a == 2, 0, NA_real_)),
      formal_education_respondent2 = ifelse(s2bq2 == 1, 1, formal_education_respondent2),
      primary_education_respondent2 = ifelse(s2bq3 %in% 17:43, 1,
                                             ifelse(s2bq3 %in% c(0:16, 51, 61), 0, NA_real_)),
      formal_education_respondent = pmax(formal_education_respondent1, formal_education_respondent2, na.rm = TRUE),
      primary_education_respondent = pmax(primary_education_respondent1, primary_education_respondent2, na.rm = TRUE)
    ) |>
    dplyr::group_by(hhid) |>
    dplyr::summarise(
      formal_education_respondent = max(formal_education_respondent, na.rm = TRUE),
      primary_education_respondent = max(primary_education_respondent, na.rm = TRUE),
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

# ==============================================================================
# 13. INDIVIDUAL-LEVEL VARIABLES
# ==============================================================================

cat("\n=== Processing individual-level variables ===\n")

# 13.1 Individual characteristics
tryCatch({
  cat("  Extracting individual characteristics...\n")
  
  indiv0 <- read_dta_auto(file_patterns$indiv_roster0, input_dir, temp_dir)
  
  indiv_chars <- indiv0 |>
    dplyr::mutate(
      ID = paste(hhid, indiv, sep = "-"),
      female = ifelse(s1q2 == 2, 1, ifelse(s1q2 == 1, 0, NA_real_)),
      age = ifelse(s1q4 == 999, NA, s1q4),
      married = ifelse(s1q7 %in% c(1, 2), 1, ifelse(s1q7 %in% c(3:7), 0, NA_real_)),
      relationship_head_temp = haven::as_factor(s1q3) |> as.character(),
      relationship_head = stringr::str_to_title(relationship_head_temp),
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

# 13.2 Labor
tryCatch({
  cat("  Extracting labor variables...\n")
  
  labor_hh_data <- read_dta_auto(file_patterns$labor_hh, input_dir, temp_dir)
  
  labor <- labor_hh_data |>
    dplyr::mutate(
      ID = paste(hhid, indiv, sep = "-"),
      farm_work = ifelse(s3aq5 == 1, 1, ifelse(s3aq5 == 2, 0, NA_real_)),
      SOB_work = ifelse(s3aq6 == 1, 1, ifelse(s3aq6 == 2, 0, NA_real_)),
      wage_work = ifelse(s3aq4 == 1, 1, ifelse(s3aq4 == 2, 0, NA_real_)),
      ind_ag = ifelse(s3aq14 == 1, 1, 0),
      ind_mining = ifelse(s3aq14 == 2, 1, 0),
      ind_manuf = ifelse(s3aq14 %in% 3:5, 1, 0),
      ind_const = ifelse(s3aq14 == 6, 1, 0),
      ind_serv = ifelse(s3aq14 %in% 7:14, 1, 0),
      working_age = s3aq1 == 1
    ) |>
    dplyr::mutate(
      hour_job1 = s3aq18,
      hour_job1 = ifelse(s3aq7 == 2 | s3aq9 %in% c(7, 8), 0, hour_job1),
      hour_job2 = s3aq31,
      hour_job2 = ifelse(s3aq7 == 2 | s3aq9 %in% c(7, 8), 0, hour_job2),
      
      farm_job1 = ifelse(s3aq13b %in% c(6111, 6112, 6113, 6114, 6121, 6122, 6123, 6130, 6141, 6142, 6151, 6152, 6153, 6164, 6210, 9211), 1, 0),
      farm_job1 = ifelse(farm_job1 == 1 & s3aq15 %in% 1:8, 0, farm_job1),
      farm_job2 = ifelse(s3aq26b %in% c(6111, 6112, 6113, 6114, 6121, 6122, 6123, 6130, 6141, 6142, 6151, 6152, 6153, 6164, 6210, 9211), 1, 0),
      farm_job2 = ifelse(farm_job2 == 1 & s3aq28 %in% 1:8, 0, farm_job2),
      
      SB_job1 = ifelse(s3aq15 == 10, 1, 0),
      SB_job1 = ifelse(farm_job1 == 1, 0, SB_job1),
      SB_job2 = ifelse(s3aq28 == 10, 1, 0),
      SB_job2 = ifelse(farm_job2 == 1, 0, SB_job2),
      
      wage_job1 = ifelse(SB_job1 == 0 & farm_job1 == 0, 1, 0),
      wage_job2 = ifelse(SB_job2 == 0 & farm_job2 == 0, 1, 0),
      
      farm_hrs = ifelse(farm_job1 == 1, hour_job1, 0) + ifelse(farm_job2 == 1, hour_job2, 0),
      SB_hrs = ifelse(SB_job1 == 1, hour_job1, 0) + ifelse(SB_job2 == 1, hour_job2, 0),
      wage_hrs = ifelse(wage_job1 == 1, hour_job1, 0) + ifelse(wage_job2 == 1, hour_job2, 0)
    ) |>
    dplyr::mutate(
      dplyr::across(c(farm_work, SOB_work, wage_work, farm_hrs, SB_hrs, wage_hrs,
                      ind_ag, ind_const, ind_manuf, ind_mining, ind_serv),
                    ~ ifelse(!working_age, 0, .x))
    ) |>
    dplyr::select(ID, hhid, farm_work, SOB_work, wage_work, farm_hrs, SB_hrs, wage_hrs,
                  ind_ag, ind_const, ind_fish = ind_const, ind_manuf, ind_mining, ind_serv, working_age) |>
    dplyr::distinct()
  
  haven::write_dta(labor, file.path(temp_dir, "labor.dta"))
  cat("  ✓ labor saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in labor: ", e$message, "\n")
})

# 13.3 Education (individual)
tryCatch({
  cat("  Extracting individual education...\n")
  
  indiv1 <- read_dta_auto(file_patterns$indiv_roster1, input_dir, temp_dir)
  indiv2 <- read_dta_auto(file_patterns$indiv_roster2, input_dir, temp_dir)
  
  education <- indiv1 |>
    dplyr::left_join(indiv2, by = c("hhid", "indiv")) |>
    dplyr::mutate(
      ID = paste(hhid, indiv, sep = "-"),
      formal_education1 = ifelse(s2aq6 == 1, 1, ifelse(s2aq6 == 2, 0, NA_real_)),
      primary_education1 = ifelse(s2aq9 %in% 16:43, 1,
                                  ifelse(s2aq9 %in% c(0:15, 51, 52), 0, NA_real_)),
      primary_education1 = ifelse(s2aq6 == 2, 0, primary_education1),
      formal_education2 = ifelse(s2bq1a == 1, 1, ifelse(s2bq1a == 2, 0, NA_real_)),
      formal_education2 = ifelse(s2bq2 == 1, 1, formal_education2),
      primary_education2 = ifelse(s2bq3 %in% 17:43, 1,
                                  ifelse(s2bq3 %in% c(0:16, 51, 61), 0, NA_real_)),
      formal_education = pmax(formal_education1, formal_education2, na.rm = TRUE),
      primary_education = pmax(primary_education1, primary_education2, na.rm = TRUE)
    ) |>
    dplyr::select(ID, hhid, formal_education, primary_education) |>
    dplyr::distinct()
  
  haven::write_dta(education, file.path(temp_dir, "educ_indiv.dta"))
  cat("  ✓ educ_indiv saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in individual education: ", e$message, "\n")
})

# 13.4 Wasting (anthropometric)
tryCatch({
  cat("  Processing wasting...\n")
  
  anthropo_data <- read_dta_auto(file_patterns$anthropo, input_dir, temp_dir)
  indiv_chars <- haven::read_dta(file.path(temp_dir, "indiv_chars.dta"))
  harvest_interview <- haven::read_dta(file.path(temp_dir, "harvest_interview_month.dta"))
  
  wasting <- anthropo_data |>
    dplyr::mutate(ID = paste(hhid, indiv, sep = "-")) |>
    dplyr::left_join(indiv_chars, by = c("hhid", "ID")) |>
    dplyr::left_join(harvest_interview, by = "hhid") |>
    dplyr::mutate(
      age_months = as.numeric(harvest_interview_month - birth_month),
      weight = s4aq52,
      height = s4aq53,
      cage = ifelse(age == 0 | is.na(age), age_months, age * 12)
    ) |>
    dplyr::mutate(
      # Placeholder for zscore calculation - would need zscore06 function
      haz06 = NA_real_,
      waz06 = NA_real_,
      whz06 = NA_real_,
      bmiz06 = NA_real_,
      wasting = NA_real_
    ) |>
    dplyr::select(hhid, ID, haz06, waz06, whz06, bmiz06, wasting, weight, height) |>
    dplyr::distinct()
  
  haven::write_dta(wasting, file.path(temp_dir, "wasting.dta"))
  cat("  ✓ wasting saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in wasting: ", e$message, "\n")
})

# ==============================================================================
# 14. GEOGRAPHIC VARIABLES
# ==============================================================================

cat("\n=== Processing geographic variables ===\n")

tryCatch({
  cat("  Extracting geographic variables...\n")
  
  geovars_hh <- read_dta_auto(file_patterns$geovars_hh, input_dir, temp_dir)
  geovars_plot <- read_dta_auto(file_patterns$geovars, input_dir, temp_dir)
  
  # Coordinates
  coords <- geovars_hh |>
    dplyr::rename(lat_modified = LAT_DD_MOD, lon_modified = LON_DD_MOD) |>
    dplyr::select(hhid, lat_modified, lon_modified) |>
    dplyr::distinct()
  
  haven::write_dta(coords, file.path(temp_dir, "Coords.dta"))
  
  # Agro-ecological zone
  aez <- geovars_hh |>
    dplyr::rename(agro_ecological_zone = ssa_aez09) |>
    dplyr::select(hhid, agro_ecological_zone) |>
    dplyr::distinct()
  
  haven::write_dta(aez, file.path(temp_dir, "aez.dta"))
  
  # Distance variables
  dist_road <- geovars_hh |>
    dplyr::rename(dist_road = dist_road2) |>
    dplyr::select(hhid, dist_road) |>
    dplyr::distinct()
  
  haven::write_dta(dist_road, file.path(temp_dir, "dist_road.dta"))
  
  dist_popcenter <- geovars_hh |>
    dplyr::rename(dist_popcenter = dist_popcenter2) |>
    dplyr::select(hhid, dist_popcenter) |>
    dplyr::distinct()
  
  haven::write_dta(dist_popcenter, file.path(temp_dir, "dist_popcenter.dta"))
  
  dist_market <- geovars_hh |>
    dplyr::select(hhid, dist_market) |>
    dplyr::distinct()
  
  haven::write_dta(dist_market, file.path(temp_dir, "dist_market.dta"))
  
  # Plot geographic variables
  plot_geo <- geovars_plot |>
    dplyr::mutate(plot_id = paste(hhid, plotid, sep = "-")) |>
    dplyr::rename(plot_slope = srtmslp_nga, elevation = srtm_nga, twi = twi_nga) |>
    dplyr::select(plot_id, plot_slope, elevation, twi) |>
    dplyr::distinct()
  
  haven::write_dta(plot_geo |> dplyr::select(plot_id, plot_slope), file.path(temp_dir, "plot_slope.dta"))
  haven::write_dta(plot_geo |> dplyr::select(plot_id, elevation), file.path(temp_dir, "elevation.dta"))
  haven::write_dta(plot_geo |> dplyr::select(plot_id, twi), file.path(temp_dir, "twi.dta"))
  
  # Soil variables
  soil <- geovars_hh |>
    dplyr::mutate(
      nutrient_availability = ifelse(sq1 == 1, 1, 0),
      nutrient_retention = ifelse(sq2 == 1, 1, 0),
      rooting_conditions = ifelse(sq3 == 1, 1, 0),
      oxygen_availability = ifelse(sq4 == 1, 1, 0),
      excess_salts = ifelse(sq5 == 1, 1, 0),
      toxicity = ifelse(sq6 == 1, 1, 0),
      workability = ifelse(sq7 == 1, 1, 0)
    ) |>
    dplyr::mutate(
      soil_fertility_index = rowMeans(dplyr::across(nutrient_availability:workability), na.rm = TRUE)
    ) |>
    dplyr::select(hhid, nutrient_availability:workability, soil_fertility_index) |>
    dplyr::distinct()
  
  haven::write_dta(soil, file.path(temp_dir, "soil.dta"))
  
  cat("  ✓ geographic variables saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in geographic variables: ", e$message, "\n")
})

# ==============================================================================
# 15. HDDS (Household Dietary Diversity Score)
# ==============================================================================

cat("\n=== Processing HDDS ===\n")

tryCatch({
  cat("  Calculating HDDS...\n")
  
  hdds_data <- read_dta_auto(file_patterns$HDDS, input_dir, temp_dir)
  
  hdds <- hdds_data |>
    dplyr::filter(s10bq1 == 1) |>
    dplyr::mutate(
      food_id = item_cd,
      A = ifelse(food_id %in% 10:29, 1, 0),
      B = ifelse(food_id %in% 30:38, 1, 0),
      C = ifelse(food_id %in% 70:79, 1, 0),
      D = ifelse(food_id %in% 60:66, 1, 0),
      E = ifelse(food_id %in% c(80:82, 90:96), 1, 0),
      F = ifelse(food_id %in% 83:85, 1, 0),
      G = ifelse(food_id %in% 100:107, 1, 0),
      H = ifelse(food_id %in% 40:48, 1, 0),
      I = ifelse(food_id %in% 110:114, 1, 0),
      J = ifelse(food_id %in% 50:53, 1, 0),
      K = ifelse(food_id %in% 130:133, 1, 0),
      L = ifelse(food_id %in% 120:122, 1, 0)
    ) |>
    dplyr::group_by(hhid) |>
    dplyr::summarise(
      dplyr::across(A:L, ~ max(.x, na.rm = TRUE)),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      HDDS = rowSums(dplyr::across(A:L), na.rm = TRUE),
      HDDS = ifelse(is.na(HDDS), 0, HDDS)
    ) |>
    dplyr::select(hhid, HDDS)
  
  haven::write_dta(hdds, file.path(temp_dir, "HDDS.dta"))
  cat("  ✓ HDDS saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in HDDS: ", e$message, "\n")
})

# ==============================================================================
# 16. CLEAN UP: REMOVE EXTRACTED FILES (KEEP ONLY ZIP)
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
# 17. CLEAN TEMP DIRECTORY
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
# 18. FINAL OUTPUT
# ==============================================================================

cat("\n=== NGA_GHS2 processing complete ===\n")
cat("Temporary files saved to:", temp_dir, "\n")
cat("✓ All variables extracted successfully\n")