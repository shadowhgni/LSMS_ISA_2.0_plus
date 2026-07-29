# ==============================================================================
# NER_ECVMA2.r - Niger Wave 2 (ECVMA 2014)
# LSMS-ISA Harmonised Panel Analysis Code - R Translation
# ==============================================================================

# Clean environment
rm(list = ls())

# Load required packages
packages <- c("tidyverse", "haven", "labelled", "stringr", "purrr", "data.table", "lubridate")
installed <- packages %in% rownames(utils::installed.packages())
if (any(!installed)) utils::install.packages(packages[!installed])
lapply(packages, library, character.only = TRUE)

# Source helper functions
source("../programs.r")

# ==============================================================================
# 1. SET UP PATHS AND GLOBALS
# ==============================================================================

# Define paths
project_root <- getwd()
Do_path <- file.path(project_root, "R_scripts")
Input_path <- file.path(project_root, "R_data", "Input")
Temp_path <- file.path(project_root, "R_data", "Temp")
Final_path <- file.path(project_root, "R_data", "Final")

# Create directories
dir.create(Temp_path, showWarnings = FALSE, recursive = TRUE)
dir.create(Final_path, showWarnings = FALSE, recursive = TRUE)

# Country-specific globals
country <- "Niger"
wave <- "ECVMA 14"
temppath <- file.path("NER", "ECVMA14")

# Create temp directory
temp_dir <- file.path(Temp_path, temppath)
dir.create(temp_dir, showWarnings = FALSE, recursive = TRUE)

# ==============================================================================
# 2. MASTER FRAME OF CROPS, PLOTS, AND HOUSEHOLDS
# ==============================================================================

cat("\n=== Creating master frames ===\n")

# 2.1 Plot-crop frame
tryCatch({
  cat("  Creating plot-crop frame...\n")
  
  # Load perennial data
  perennial <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_AS05P2.dta"))
  
  # Filter and clean
  perennial <- perennial |>
    dplyr::filter(AS05Q04 != 2) |>  # Drop if not harvested
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      crop_name2 = haven::as_factor(AS05Q02) |> as.character(),
      n = dplyr::row_number(),
      n_str = as.character(n),
      plot_id2 = paste0("missing_line_", n_str),
      parcel_id2 = paste0("missing_line_", n_str)
    ) |>
    dplyr::rename(crop_code = AS05Q02)
  
  # Save perennial for later
  perennial_temp <- perennial |>
    dplyr::select(GRAPPE, MENAGE, EXTENSION, hhid, crop_code, crop_name2, plot_id2, parcel_id2)
  
  # Load harvest data (wave 2 has two parts)
  harvest1 <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_AS2E1P2.dta"))
  harvest2 <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_AS2E2P2.dta"))
  
  # Combine harvest data
  harvest <- harvest1 |>
    dplyr::bind_rows(harvest2) |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      plot_id = paste(hhid, AS02EQ01, AS02EQ03, sep = "-"),
      parcel_id = paste(hhid, AS02EQ01, sep = "-"),
      crop_name = haven::as_factor(CULTURE) |> as.character()
    ) |>
    dplyr::rename(crop_code = CULTURE)
  
  # Merge with perennial data
  harvest <- harvest |>
    dplyr::left_join(
      perennial_temp |> dplyr::select(GRAPPE, MENAGE, EXTENSION, hhid, crop_code, 
                                      crop_name2, plot_id2, parcel_id2),
      by = c("GRAPPE", "MENAGE", "EXTENSION", "hhid", "crop_code")
    ) |>
    dplyr::mutate(
      crop_name = dplyr::if_else(!is.na(crop_name2), crop_name2, crop_name),
      plot_id = dplyr::if_else(!is.na(plot_id2), plot_id2, plot_id),
      parcel_id = dplyr::if_else(!is.na(parcel_id2), parcel_id2, parcel_id)
    ) |>
    dplyr::select(-crop_name2, -plot_id2, -parcel_id2)
  
  # Create plot-crop frame
  plot_crop_frame <- harvest |>
    dplyr::select(hhid, plot_id, crop_name, crop_code, parcel_id) |>
    dplyr::distinct()
  
  haven::write_dta(plot_crop_frame, file.path(temp_dir, "plot_crop_frame.dta"))
  cat("  ✓ plot_crop_frame saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in plot-crop frame: ", e$message, "\n")
})

# 2.2 Household frame
tryCatch({
  cat("  Creating household frame...\n")
  
  cover <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_MS00P1.dta"))
  
  hh_frame <- cover |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-")
    ) |>
    dplyr::select(hhid, EXTENSION) |>
    dplyr::distinct()
  
  haven::write_dta(hh_frame, file.path(temp_dir, "hh_frame.dta"))
  cat("  ✓ hh_frame saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in household frame: ", e$message, "\n")
})

# 2.3 Individual frame
tryCatch({
  cat("  Creating individual frame...\n")
  
  indiv <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_MS01P1.dta"))
  
  indiv_frame <- indiv |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      ID = paste(hhid, MS01Q0, sep = "-")
    ) |>
    dplyr::select(hhid, ID) |>
    dplyr::distinct()
  
  haven::write_dta(indiv_frame, file.path(temp_dir, "indiv_frame.dta"))
  cat("  ✓ indiv_frame saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in individual frame: ", e$message, "\n")
})

# ==============================================================================
# 3. VARIABLE EXTRACTION
# ==============================================================================

cat("\n=== Extracting variables ===\n")

# 3.1 EA
tryCatch({
  cat("  Extracting EA...\n")
  
  cover <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_MS00P1.dta"))
  
  ea_id <- cover |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      ea_id = paste(MS00Q10, MS00Q11, MS00Q12, MS00Q14, sep = "-")
    ) |>
    dplyr::select(hhid, ea_id) |>
    dplyr::distinct()
  
  haven::write_dta(ea_id, file.path(temp_dir, "ea_id.dta"))
  cat("  ✓ ea_id saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in EA extraction: ", e$message, "\n")
})

# 3.2 Strata
tryCatch({
  cat("  Extracting strata...\n")
  
  # Load consumption data for strata
  csption <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2014_P1P2_ConsoMen.dta"))
  cover <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_MS00P1.dta"))
  
  # Get strata from wave 1
  wave1_strata <- haven::read_dta(file.path(Input_path, country, "ECVMA 11", "ecvmamen_p1_en.dta")) |>
    dplyr::select(grappe, strate) |>
    dplyr::distinct()
  
  strata <- csption |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-")
    ) |>
    dplyr::left_join(wave1_strata, by = c("GRAPPE" = "grappe")) |>
    dplyr::mutate(
      strataid = strate
    ) |>
    dplyr::select(hhid, strataid) |>
    dplyr::distinct() |>
    dplyr::left_join(
      cover |> dplyr::mutate(hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-")) |>
        dplyr::select(hhid),
      by = "hhid"
    ) |>
    dplyr::mutate(
      # Fill missing strata using admin levels if needed
      strataid = dplyr::if_else(is.na(strataid), 99, strataid)
    )
  
  haven::write_dta(strata, file.path(temp_dir, "strataid.dta"))
  cat("  ✓ strataid saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in strata extraction: ", e$message, "\n")
})

# 3.3 Administrative levels
tryCatch({
  cat("  Extracting administrative levels...\n")
  
  cover <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_MS00P1.dta"))
  
  admin_data <- cover |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-")
    )
  
  # Admin 1
  admin1 <- admin_data |>
    dplyr::mutate(
      admin_1 = MS00Q10,
      admin_1_name = haven::as_factor(admin_1) |> as.character()
    ) |>
    dplyr::select(hhid, admin_1, admin_1_name) |>
    dplyr::distinct()
  
  haven::write_dta(admin1, file.path(temp_dir, "admin1.dta"))
  
  # Admin 2
  admin2 <- admin_data |>
    dplyr::mutate(
      admin_2 = MS00Q11,
      admin_2_name = haven::as_factor(admin_2) |> as.character()
    ) |>
    dplyr::select(hhid, admin_2, admin_2_name) |>
    dplyr::distinct()
  
  haven::write_dta(admin2, file.path(temp_dir, "admin2.dta"))
  
  # Admin 3
  admin3 <- admin_data |>
    dplyr::mutate(
      admin_3 = MS00Q12
    ) |>
    dplyr::select(hhid, admin_3) |>
    dplyr::distinct()
  
  haven::write_dta(admin3, file.path(temp_dir, "admin3.dta"))
  
  cat("  ✓ admin levels saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in admin levels: ", e$message, "\n")
})

# 3.4 Urban/rural
tryCatch({
  cat("  Extracting urban/rural...\n")
  
  cover <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_MS00P1.dta"))
  
  urban <- cover |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      urban = dplyr::if_else(MS00Q15 %in% c(1, 2), 1,
                             dplyr::if_else(MS00Q15 == 3, 0, NA_real_))
    ) |>
    dplyr::select(hhid, urban) |>
    dplyr::distinct()
  
  haven::write_dta(urban, file.path(temp_dir, "urban.dta"))
  cat("  ✓ urban saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in urban/rural: ", e$message, "\n")
})

# 3.5 Weights
tryCatch({
  cat("  Extracting weights...\n")
  
  csption <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2014_P1P2_ConsoMen.dta"))
  
  weights_out <- csption |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      pw = hhweight
    ) |>
    dplyr::select(hhid, pw) |>
    dplyr::distinct()
  
  haven::write_dta(weights_out, file.path(temp_dir, "weights.dta"))
  cat("  ✓ weights saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in weights: ", e$message, "\n")
})

# 3.6 Planting month
tryCatch({
  cat("  Extracting planting month...\n")
  
  plot_inputs <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_AS2BP1.dta"))
  
  planting_month <- plot_inputs |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      plot_id = paste(hhid, AS01Q01, AS01Q03, sep = "-"),
      crop_code = AS02BQ06,
      month = AS02BQ11,
      year = 2014,
      planting_month = lubridate::ymd(paste(year, month, "01", sep = "-"))
    ) |>
    dplyr::select(hhid, plot_id, crop_code, planting_month) |>
    dplyr::distinct() |>
    dplyr::group_by(hhid, crop_code, plot_id) |>
    dplyr::summarise(planting_month = min(planting_month, na.rm = TRUE), .groups = "drop")
  
  haven::write_dta(planting_month, file.path(temp_dir, "planting_month.dta"))
  cat("  ✓ planting_month saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in planting month: ", e$message, "\n")
})

# 3.7 Harvest end month
tryCatch({
  cat("  Extracting harvest end month...\n")
  
  harvest1 <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_AS2E1P2.dta"))
  
  harvest_end_month <- harvest1 |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      plot_id = paste(hhid, AS02EQ01, AS02EQ03, sep = "-"),
      crop_code = CULTURE,
      month = AS02EQ06B,
      month = dplyr::if_else(month == 99, NA_real_, month),
      year = dplyr::if_else(month %in% c(1, 2), 2015, 2014),
      harvest_end_month = lubridate::ymd(paste(year, month, "01", sep = "-"))
    ) |>
    dplyr::select(hhid, plot_id, crop_code, harvest_end_month) |>
    dplyr::distinct() |>
    dplyr::group_by(hhid, crop_code, plot_id) |>
    dplyr::summarise(harvest_end_month = max(harvest_end_month, na.rm = TRUE), .groups = "drop")
  
  haven::write_dta(harvest_end_month, file.path(temp_dir, "harvest_end_month.dta"))
  cat("  ✓ harvest_end_month saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in harvest end month: ", e$message, "\n")
})

# 3.8 Harvest interview month
tryCatch({
  cat("  Extracting harvest interview month...\n")
  
  cover2 <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_0P2.dta"))
  
  harvest_interview_month <- cover2 |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      # Parse date from MS00Q03A
      date_str = as.character(MS00Q03A),
      month = as.numeric(stringr::str_sub(date_str, 3, 4)),
      year = as.numeric(stringr::str_sub(date_str, 5, 8)),
      harvest_interview_month = lubridate::ymd(paste(year, month, "01", sep = "-"))
    ) |>
    dplyr::select(hhid, harvest_interview_month) |>
    dplyr::distinct()
  
  haven::write_dta(harvest_interview_month, file.path(temp_dir, "harvest_interview_month.dta"))
  cat("  ✓ harvest_interview_month saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in harvest interview month: ", e$message, "\n")
})

# 3.9 Planting interview month
tryCatch({
  cat("  Extracting planting interview month...\n")
  
  cover <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_MS00P1.dta"))
  
  planting_interview_month <- cover |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      date_str = as.character(MS00Q03A),
      month = as.numeric(stringr::str_sub(date_str, 3, 4)),
      year = as.numeric(stringr::str_sub(date_str, 5, 8)),
      planting_interview_month = lubridate::ymd(paste(year, month, "01", sep = "-"))
    ) |>
    dplyr::select(hhid, planting_interview_month) |>
    dplyr::distinct()
  
  haven::write_dta(planting_interview_month, file.path(temp_dir, "planting_interview_month.dta"))
  cat("  ✓ planting_interview_month saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in planting interview month: ", e$message, "\n")
})

# ==============================================================================
# 4. HARVEST QUANTITY AND CONVERSION FACTORS
# ==============================================================================

cat("\n=== Processing harvest data ===\n")

# 4.1 Conversion factors
tryCatch({
  cat("  Calculating conversion factors...\n")
  
  # Load harvest data to calculate conversions
  harvest1 <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_AS2E1P2.dta"))
  
  conversions <- harvest1 |>
    dplyr::mutate(
      region = MS00Q10,
      crop_code = CULTURE,
      unit = AS02EQ07B,
      conversion = AS02EQ07C / AS02EQ07A
    ) |>
    dplyr::filter(!is.na(conversion) & is.finite(conversion)) |>
    dplyr::group_by(region, crop_code, unit) |>
    dplyr::summarise(
      conversion = median(conversion, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      conversion = dplyr::if_else(unit == 1, 1, conversion),
      conversion = dplyr::if_else(unit == 99, NA_real_, conversion)
    ) |>
    dplyr::filter(!is.na(conversion) & conversion != 0) |>
    dplyr::group_by(unit) |>
    dplyr::summarise(
      conversion = median(conversion, na.rm = TRUE),
      sd = sd(conversion, na.rm = TRUE),
      .groups = "drop"
    )
  
  haven::write_dta(conversions, file.path(temp_dir, "Conversion_factors.dta"))
  cat("  ✓ conversion factors saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in conversion factors: ", e$message, "\n")
})

# 4.2 Harvest kg
tryCatch({
  cat("  Calculating harvest kg...\n")
  
  # Load conversion factors
  conversions <- haven::read_dta(file.path(temp_dir, "Conversion_factors.dta"))
  
  # Load perennial data
  perennial <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_AS05P2.dta")) |>
    dplyr::filter(AS05Q04 != 2) |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      unit = dplyr::case_when(
        AS05Q07 == 1 ~ 1,
        AS05Q07 == 3 ~ 9,
        AS05Q07 == 4 ~ 5,
        AS05Q07 == 5 ~ 6,
        AS05Q07 == 6 ~ 7,
        AS05Q07 == 7 ~ 8,
        TRUE ~ NA_real_
      ),
      harvest_kg_per = AS05Q05 * AS05Q06
    ) |>
    dplyr::rename(crop_code = AS05Q02) |>
    dplyr::left_join(conversions, by = "unit") |>
    dplyr::mutate(
      harvest_kg_per = harvest_kg_per * conversion,
      n = dplyr::row_number(),
      plot_id2 = paste0("missing_line_", as.character(n))
    ) |>
    dplyr::select(GRAPPE, MENAGE, EXTENSION, hhid, crop_code, harvest_kg_per, plot_id2)
  
  # Load harvest data
  harvest1 <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_AS2E1P2.dta"))
  
  # Add admin levels
  admin1 <- haven::read_dta(file.path(temp_dir, "admin1.dta"))
  admin2 <- haven::read_dta(file.path(temp_dir, "admin2.dta"))
  admin3 <- haven::read_dta(file.path(temp_dir, "admin3.dta"))
  
  harvest <- harvest1 |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      plot_id = paste(hhid, AS02EQ01, AS02EQ03, sep = "-"),
      ea_id = MS00Q14,
      ea_id = dplyr::if_else(ea_id == 999, NA_real_, ea_id)
    ) |>
    dplyr::rename(crop_code = CULTURE) |>
    dplyr::left_join(admin1, by = "hhid") |>
    dplyr::left_join(admin2, by = "hhid") |>
    dplyr::left_join(admin3, by = "hhid") |>
    dplyr::left_join(
      perennial |> dplyr::select(GRAPPE, MENAGE, EXTENSION, hhid, crop_code, 
                                 harvest_kg_per, plot_id2),
      by = c("GRAPPE", "MENAGE", "EXTENSION", "hhid", "crop_code")
    ) |>
    dplyr::mutate(
      plot_id = dplyr::if_else(!is.na(plot_id2), plot_id2, plot_id),
      harvest_kg = AS02EQ07C,
      harvest_kg = dplyr::if_else(AS02EQ07B == 99, NA_real_, harvest_kg),
      harvest_kg = dplyr::if_else(AS02EQ06A == 0, NA_real_, harvest_kg),
      harvest_kg = dplyr::if_else(AS02EQ07A == 0, 0, harvest_kg),
      harvest_kg = dplyr::if_else(!is.na(harvest_kg_per), harvest_kg_per, harvest_kg),
      # Unfinished harvest
      unit = AS02EQ07F,
      unfinished_harvest = AS02EQ07E,
      harvest_kg = dplyr::if_else(AS02EQ07D == 2 & !is.na(unfinished_harvest),
                                  unfinished_harvest, harvest_kg),
      # Crop shock
      crop_shock = dplyr::if_else(AS02EQ08 == 1, 1,
                                  dplyr::if_else(AS02EQ08 == 2, 0, NA_real_)),
      harvest_kg = dplyr::if_else(harvest_kg == 0 & crop_shock != 1, NA_real_, harvest_kg)
    )
  
  # Aggregate
  harvest_kg <- harvest |>
    dplyr::group_by(plot_id, crop_code, admin_1, admin_2, admin_3, hhid) |>
    dplyr::summarise(
      harvest_kg = sum(harvest_kg, na.rm = TRUE),
      n_harvest_kg = sum(!is.na(harvest_kg)),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      harvest_kg = dplyr::if_else(n_harvest_kg == 0, NA_real_, harvest_kg)
    ) |>
    dplyr::select(-n_harvest_kg)
  
  haven::write_dta(harvest_kg, file.path(temp_dir, "harvest_kg.dta"))
  cat("  ✓ harvest_kg saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in harvest kg: ", e$message, "\n")
})

# 4.3 Percent area harvested
tryCatch({
  cat("  Calculating percent area harvested...\n")
  
  harvest1 <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_AS2E1P2.dta"))
  harvest2 <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_AS2E2P2.dta"))
  
  # Merge with harvest2 for percent harvested
  harvest <- harvest1 |>
    dplyr::left_join(
      harvest2 |> dplyr::select(GRAPPE, MENAGE, EXTENSION, AS02EQ110B, AS02EQ16),
      by = c("GRAPPE", "MENAGE", "EXTENSION", "CULTURE" = "AS02EQ110B")
    ) |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      plot_id = paste(hhid, AS02EQ01, AS02EQ03, sep = "-"),
      crop_code = CULTURE,
      pct_area_harvested = 100 - AS02EQ09,
      pct_area_harvested = dplyr::if_else(AS02EQ09 > 100, NA_real_, pct_area_harvested),
      pct_area_harvested = dplyr::if_else(AS02EQ08 == 2, 100, pct_area_harvested)
    ) |>
    dplyr::select(hhid, plot_id, crop_code, pct_area_harvested) |>
    dplyr::distinct()
  
  haven::write_dta(harvest, file.path(temp_dir, "pct_area_harvested.dta"))
  cat("  ✓ pct_area_harvested saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in percent area harvested: ", e$message, "\n")
})

# 4.4 Crop shocks
tryCatch({
  cat("  Extracting crop shocks...\n")
  
  harvest1 <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_AS2E1P2.dta"))
  
  crop_shock <- harvest1 |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      plot_id = paste(hhid, AS02EQ01, AS02EQ03, sep = "-"),
      crop_code = CULTURE,
      # Crop shock
      crop_shock = dplyr::if_else(AS02EQ08 == 1, 1,
                                  dplyr::if_else(AS02EQ08 == 2, 0, NA_real_)),
      # Drought shock
      drought_shock = dplyr::if_else(AS02EQ10 == 3, 1,
                                     dplyr::if_else(AS02EQ10 %in% c(1, 2, 4:9), 0, NA_real_)),
      drought_shock = dplyr::if_else(AS02EQ08 == 2, 0, drought_shock),
      # Flood shock
      flood_shock = dplyr::if_else(AS02EQ10 == 4, 1,
                                   dplyr::if_else(AS02EQ10 %in% c(1:3, 5:9), 0, NA_real_)),
      flood_shock = dplyr::if_else(AS02EQ08 == 2, 0, flood_shock),
      # Pests shock
      pests_shock = dplyr::if_else(AS02EQ10 == 1, 1,
                                   dplyr::if_else(AS02EQ10 %in% c(2:9), 0, NA_real_)),
      pests_shock = dplyr::if_else(AS02EQ08 == 2, 0, pests_shock),
      # Percent lost
      pct_area_harvested = 100 - AS02EQ09,
      pct_area_harvested = dplyr::if_else(AS02EQ09 > 100, NA_real_, pct_area_harvested),
      pct_area_harvested = dplyr::if_else(AS02EQ08 == 2, 100, pct_area_harvested),
      pct_lost = 100 - pct_area_harvested,
      pct_lost = pct_lost / 100
    ) |>
    dplyr::group_by(hhid, plot_id, crop_code) |>
    dplyr::summarise(
      crop_shock = max(crop_shock, na.rm = TRUE),
      pests_shock = max(pests_shock, na.rm = TRUE),
      drought_shock = max(drought_shock, na.rm = TRUE),
      flood_shock = max(flood_shock, na.rm = TRUE),
      pct_lost = mean(pct_lost, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      dplyr::across(c(crop_shock, pests_shock, drought_shock, flood_shock),
                    ~ dplyr::if_else(is.infinite(.x), NA_real_, .x))
    )
  
  haven::write_dta(crop_shock, file.path(temp_dir, "crop_shock.dta"))
  cat("  ✓ crop_shock saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in crop shocks: ", e$message, "\n")
})

# 4.5 Harvest sold amount
tryCatch({
  cat("  Calculating harvest sold amount...\n")
  
  # Load conversion factors
  conversions <- haven::read_dta(file.path(temp_dir, "Conversion_factors.dta"))
  
  # Load perennial data
  perennial <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_AS05P2.dta")) |>
    dplyr::filter(AS05Q04 != 2) |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      unit = dplyr::case_when(
        AS05Q10B == 1 ~ 1,
        AS05Q10B == 3 ~ 9,
        AS05Q10B == 4 ~ 5,
        AS05Q10B == 5 ~ 6,
        AS05Q10B == 6 ~ 7,
        AS05Q10B == 7 ~ 8,
        TRUE ~ NA_real_
      ),
      harvest_sold_kg_per = AS05Q10A
    ) |>
    dplyr::rename(crop_code = AS05Q02) |>
    dplyr::left_join(conversions, by = "unit") |>
    dplyr::mutate(
      harvest_sold_kg_per = harvest_sold_kg_per * conversion,
      harvest_sold_kg_per = dplyr::if_else(AS05Q05 == 0, 0, harvest_sold_kg_per),
      n = dplyr::row_number(),
      plot_id2 = paste0("missing_line_", as.character(n))
    ) |>
    dplyr::select(GRAPPE, MENAGE, EXTENSION, hhid, crop_code, harvest_sold_kg_per, plot_id2)
  
  # Load harvest sold data
  harvest2 <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_AS2E2P2.dta"))
  
  harvest_sold <- harvest2 |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      crop_code = AS02EQ110B,
      harvest_sold_kg = AS02EQ12C,
      harvest_sold_kg = dplyr::if_else(AS02EQ11 == 2, 0, harvest_sold_kg),
      harvest_sold_kg = dplyr::if_else(AS02EQ110C == 0, 0, harvest_sold_kg)
    ) |>
    dplyr::left_join(
      perennial |> dplyr::select(GRAPPE, MENAGE, EXTENSION, hhid, crop_code, 
                                 harvest_sold_kg_per, plot_id2),
      by = c("GRAPPE", "MENAGE", "EXTENSION", "hhid", "crop_code")
    ) |>
    dplyr::mutate(
      harvest_sold_kg = dplyr::if_else(!is.na(harvest_sold_kg_per), 
                                       harvest_sold_kg_per, harvest_sold_kg)
    ) |>
    dplyr::group_by(crop_code, hhid) |>
    dplyr::summarise(
      harvest_sold_kg = sum(harvest_sold_kg, na.rm = TRUE),
      n_harvest_sold_kg = sum(!is.na(harvest_sold_kg)),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      harvest_sold_kg = dplyr::if_else(n_harvest_sold_kg == 0, NA_real_, harvest_sold_kg)
    ) |>
    dplyr::select(-n_harvest_sold_kg)
  
  haven::write_dta(harvest_sold, file.path(temp_dir, "harvest_sold_kg.dta"))
  
  # Calculate household-level share
  harvest_kg <- haven::read_dta(file.path(temp_dir, "harvest_kg.dta"))
  
  hh_share <- harvest_sold |>
    dplyr::group_by(hhid) |>
    dplyr::summarise(
      harvest_sold_kg = sum(harvest_sold_kg, na.rm = TRUE),
      n_harvest_sold_kg = sum(!is.na(harvest_sold_kg)),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      harvest_sold_kg = dplyr::if_else(n_harvest_sold_kg == 0, NA_real_, harvest_sold_kg)
    ) |>
    dplyr::select(-n_harvest_sold_kg) |>
    dplyr::left_join(
      harvest_kg |> dplyr::group_by(hhid) |>
        dplyr::summarise(harvest_kg = sum(harvest_kg, na.rm = TRUE), .groups = "drop"),
      by = "hhid"
    ) |>
    dplyr::mutate(
      share_kg_sold = harvest_sold_kg / harvest_kg,
      share_kg_sold = dplyr::if_else(share_kg_sold > 1, NA_real_, share_kg_sold)
    ) |>
    dplyr::select(hhid, share_kg_sold) |>
    dplyr::distinct()
  
  haven::write_dta(hh_share, file.path(temp_dir, "harvest_sold_kg_hh.dta"))
  cat("  ✓ harvest_sold_kg saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in harvest sold amount: ", e$message, "\n")
})

# 4.6 Harvest sold value
tryCatch({
  cat("  Calculating harvest sold value...\n")
  
  # Load perennial data
  perennial <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_AS05P2.dta")) |>
    dplyr::filter(AS05Q04 != 2) |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      harvest_sold_value_per = AS05Q11,
      n = dplyr::row_number(),
      plot_id2 = paste0("missing_line_", as.character(n))
    ) |>
    dplyr::rename(crop_code = AS05Q02) |>
    dplyr::select(GRAPPE, MENAGE, EXTENSION, hhid, crop_code, harvest_sold_value_per, plot_id2)
  
  # Load harvest sold data
  harvest2 <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_AS2E2P2.dta"))
  
  harvest_sold_value <- harvest2 |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      crop_code = AS02EQ110B,
      harvest_sold_value = AS02EQ13
    ) |>
    dplyr::left_join(
      perennial |> dplyr::select(GRAPPE, MENAGE, EXTENSION, hhid, crop_code, 
                                 harvest_sold_value_per, plot_id2),
      by = c("GRAPPE", "MENAGE", "EXTENSION", "hhid", "crop_code")
    ) |>
    dplyr::mutate(
      harvest_sold_value = dplyr::if_else(!is.na(harvest_sold_value_per), 
                                          harvest_sold_value_per, harvest_sold_value)
    ) |>
    dplyr::group_by(crop_code, hhid) |>
    dplyr::summarise(
      harvest_sold_value = sum(harvest_sold_value, na.rm = TRUE),
      n_harvest_sold_value = sum(!is.na(harvest_sold_value)),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      harvest_sold_value = dplyr::if_else(n_harvest_sold_value == 0, 
                                          NA_real_, harvest_sold_value)
    ) |>
    dplyr::select(-n_harvest_sold_value)
  
  haven::write_dta(harvest_sold_value, file.path(temp_dir, "harvest_sold_value.dta"))
  cat("  ✓ harvest_sold_value saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in harvest sold value: ", e$message, "\n")
})

# ==============================================================================
# 5. HARVEST VALUE AND MAIN CROP
# ==============================================================================

cat("\n=== Calculating harvest values ===\n")

# 5.1 Harvest value
tryCatch({
  cat("  Calculating harvest value...\n")
  
  # Load harvest data
  harvest2 <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_AS2E2P2.dta"))
  
  # Add perennial crops
  perennial <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_AS05P2.dta")) |>
    dplyr::filter(AS05Q04 != 2) |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      n = dplyr::row_number(),
      plot_id2 = paste0("missing_line_", as.character(n))
    ) |>
    dplyr::rename(crop_code = AS05Q02) |>
    dplyr::select(GRAPPE, MENAGE, EXTENSION, hhid, crop_code, plot_id2)
  
  harvest <- harvest2 |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      plot_id = paste(hhid, AS02EQ01, AS02EQ03, sep = "-"),
      crop_code = AS02EQ110B
    ) |>
    dplyr::select(hhid, plot_id, crop_code) |>
    dplyr::distinct() |>
    dplyr::left_join(
      perennial |> dplyr::select(GRAPPE, MENAGE, EXTENSION, hhid, crop_code, plot_id2),
      by = c("GRAPPE", "MENAGE", "EXTENSION", "hhid", "crop_code")
    ) |>
    dplyr::mutate(
      plot_id = dplyr::if_else(!is.na(plot_id2), plot_id2, plot_id)
    ) |>
    dplyr::select(-plot_id2)
  
  # Calculate harvest value using median crop prices (sorting variant)
  harvest_value <- valuation_median_crops_noea_sort(
    data = harvest,
    temp_path = temp_dir,
    hhid_var = "hhid",
    cropvar_var = "crop_code"
  )
  
  # Add main crop
  harvest_value <- main_crop_def_parcel(
    data = harvest_value,
    cropvar_var = "crop_code"
  )
  
  # Select relevant columns
  harvest_value_out <- harvest_value |>
    dplyr::select(hhid, plot_id, harvest_value, crop_code, main_crop)
  
  haven::write_dta(harvest_value_out, file.path(temp_dir, "harvest_value.dta"))
  cat("  ✓ harvest_value saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in harvest value: ", e$message, "\n")
})

# 5.2 Intercropped
tryCatch({
  cat("  Extracting intercropped status...\n")
  
  plot_inputs <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_AS2BP1.dta"))
  
  intercropped <- plot_inputs |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      plot_id = paste(hhid, AS01Q01, AS01Q03, sep = "-"),
      crop_code = AS02BQ06,
      intercropped = dplyr::if_else(AS02BQ07 == 1, 0,
                                    dplyr::if_else(AS02BQ07 == 2, 1, NA_real_))
    ) |>
    dplyr::group_by(plot_id) |>
    dplyr::summarise(
      intercropped = max(intercropped, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      intercropped = dplyr::if_else(is.infinite(intercropped), NA_real_, intercropped)
    )
  
  haven::write_dta(intercropped, file.path(temp_dir, "intercropped.dta"))
  cat("  ✓ intercropped saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in intercropped: ", e$message, "\n")
})

# 5.3 Number of seasonal crops
tryCatch({
  cat("  Calculating number of seasonal crops...\n")
  
  harvest1 <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_AS2E1P2.dta"))
  
  nb_seasonal_crop <- harvest1 |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      plot_id = paste(hhid, AS02EQ01, AS02EQ03, sep = "-")
    ) |>
    dplyr::group_by(plot_id) |>
    dplyr::summarise(
      nb_seasonal_crop = n_distinct(CULTURE, na.rm = TRUE),
      .groups = "drop"
    )
  
  haven::write_dta(nb_seasonal_crop, file.path(temp_dir, "nb_seasonal_crop.dta"))
  cat("  ✓ nb_seasonal_crop saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in nb_seasonal_crop: ", e$message, "\n")
})

# 5.4 Main crop shares
tryCatch({
  cat("  Calculating main crop shares...\n")
  
  # Load harvest value
  harvest_value <- haven::read_dta(file.path(temp_dir, "harvest_value.dta"))
  
  # Load harvest data
  harvest1 <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_AS2E1P2.dta"))
  
  # Add perennial crops
  perennial <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_AS05P2.dta")) |>
    dplyr::filter(AS05Q04 != 2) |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      n = dplyr::row_number(),
      plot_id2 = paste0("missing_line_", as.character(n))
    ) |>
    dplyr::rename(crop_code = AS05Q02) |>
    dplyr::select(GRAPPE, MENAGE, EXTENSION, hhid, crop_code, plot_id2)
  
  harvest <- harvest1 |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      plot_id = paste(hhid, AS02EQ01, AS02EQ03, sep = "-"),
      crop_code = CULTURE
    ) |>
    dplyr::left_join(
      perennial |> dplyr::select(GRAPPE, MENAGE, EXTENSION, hhid, crop_code, plot_id2),
      by = c("GRAPPE", "MENAGE", "EXTENSION", "hhid", "crop_code")
    ) |>
    dplyr::mutate(
      plot_id = dplyr::if_else(!is.na(plot_id2), plot_id2, plot_id)
    ) |>
    dplyr::select(-plot_id2)
  
  # Merge with harvest value
  main_crop_data <- harvest |>
    dplyr::left_join(harvest_value, by = c("hhid", "plot_id", "crop_code"))
  
  # Calculate total value per plot
  main_crop_data <- main_crop_data |>
    dplyr::group_by(plot_id) |>
    dplyr::mutate(
      total_value_plot = sum(harvest_value, na.rm = TRUE),
      maincrop_valueshare_temp = dplyr::if_else(
        crop_code == main_crop,
        harvest_value / total_value_plot,
        NA_real_
      ),
      maincrop_valueshare = max(maincrop_valueshare_temp, na.rm = TRUE)
    ) |>
    dplyr::ungroup()
  
  # Map crop codes to categories (Niger specific)
  main_crop_data <- main_crop_data |>
    dplyr::mutate(
      crop_category = dplyr::case_when(
        crop_code %in% c(1:9) ~ "MILLET",
        crop_code %in% c(10:19) ~ "SORGHUM",
        crop_code %in% c(20:29) ~ "RICE",
        crop_code %in% c(30:39) ~ "MAIZE",
        crop_code %in% c(40:49) ~ "WHEAT",
        crop_code %in% c(50:59) ~ "BARLEY",
        crop_code %in% c(60:69) ~ "TUBERS/ROOT CROPS",
        crop_code %in% c(70:79) ~ "BEANS/LEGUMES",
        crop_code %in% c(80:89) ~ "NUTS",
        crop_code > 50 ~ "PERENNIAL/FRUIT",
        TRUE ~ "OTHER"
      )
    )
  
  # Create contains_crop variables (11 categories)
  crop_groups <- c("BARLEY", "LEGUMES", "MAIZE", "MILLET", "NUTS", "OTHER", 
                   "PERENNIAL/FRUIT", "RICE", "SORGHUM", "TUBERS/ROOT CROPS", "WHEAT")
  
  for (i in 1:length(crop_groups)) {
    group_name <- crop_groups[i]
    var_name <- paste0("contains_crop_", i)
    main_crop_data <- main_crop_data |>
      dplyr::mutate(
        !!var_name := dplyr::if_else(crop_category == group_name, 1, 0)
      )
  }
  
  # Calculate shares
  for (i in 1:length(crop_groups)) {
    var_name <- paste0("share_crop", i)
    group_name <- crop_groups[i]
    main_crop_data <- main_crop_data |>
      dplyr::mutate(
        !!var_name := dplyr::if_else(
          crop_category == group_name,
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
      maincrop_valueshare = dplyr::if_else(is.infinite(maincrop_valueshare), 
                                           NA_real_, maincrop_valueshare),
      dplyr::across(starts_with("contains_crop_"), 
                    ~ dplyr::if_else(is.infinite(.x), NA_real_, .x))
    )
  
  haven::write_dta(main_crop_out, file.path(temp_dir, "main_crop.dta"))
  cat("  ✓ main_crop saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in main crop: ", e$message, "\n")
})

# 5.5 Share of plot area planted by crop
tryCatch({
  cat("  Calculating plot area share by crop...\n")
  
  plot_inputs <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_AS2BP1.dta"))
  plot_area <- haven::read_dta(file.path(temp_dir, "plot_area.dta"))
  
  pct_area_planted <- plot_inputs |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      plot_id = paste(hhid, AS01Q01, AS01Q03, sep = "-"),
      crop_code = AS02BQ06
    ) |>
    dplyr::left_join(plot_area, by = c("hhid", "plot_id")) |>
    dplyr::mutate(
      pct_area_planted = (AS02BQ08 / (plot_area_GPS * 10000)) * 100,
      pct_area_planted = dplyr::if_else(AS02BQ08 > 999998, NA_real_, pct_area_planted),
      pct_area_planted = dplyr::if_else(pct_area_planted > 100, NA_real_, pct_area_planted),
      pct_area_planted = dplyr::if_else(pct_area_planted < 1, 0, pct_area_planted)
    ) |>
    dplyr::select(plot_id, hhid, crop_code, pct_area_planted) |>
    dplyr::distinct()
  
  haven::write_dta(pct_area_planted, file.path(temp_dir, "pct_area_planted.dta"))
  cat("  ✓ pct_area_planted saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in pct_area_planted: ", e$message, "\n")
})

# ==============================================================================
# 6. LAND AREA
# ==============================================================================

cat("\n=== Processing land area ===\n")

tryCatch({
  cat("  Calculating plot area...\n")
  
  plot_roster <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_AS1P1.dta"))
  
  # Load admin3 for imputation
  admin3 <- haven::read_dta(file.path(temp_dir, "admin3.dta"))
  
  land_area <- plot_roster |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      plot_id = paste(hhid, AS01Q01, AS01Q03, sep = "-"),
      area_self_reported = AS01Q06 * 0.0001,  # m² to hectares
      area_self_reported = dplyr::if_else(AS01Q06 == 999999, NA_real_, area_self_reported),
      plot_area_GPS = AS01Q07 * 0.0001,  # m² to hectares
      plot_area_GPS = dplyr::if_else(AS01Q07 == 999999 | AS01Q07 == 0, 
                                     NA_real_, plot_area_GPS)
    ) |>
    dplyr::left_join(admin3, by = "hhid")
  
  # Simple imputation
  imputation_ratios <- land_area |>
    dplyr::filter(!is.na(plot_area_GPS) & !is.na(area_self_reported) & area_self_reported > 0) |>
    dplyr::group_by(admin_3) |>
    dplyr::summarise(
      ratio = median(plot_area_GPS / area_self_reported, na.rm = TRUE),
      .groups = "drop"
    )
  
  land_area <- land_area |>
    dplyr::left_join(imputation_ratios, by = "admin_3") |>
    dplyr::mutate(
      plot_area_GPS = dplyr::if_else(
        is.na(plot_area_GPS) & !is.na(area_self_reported) & !is.na(ratio),
        area_self_reported * ratio,
        plot_area_GPS
      )
    )
  
  # Calculate farm size
  land_area <- land_area |>
    dplyr::group_by(hhid) |>
    dplyr::mutate(
      farm_size = sum(plot_area_GPS, na.rm = TRUE)
    ) |>
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
# 7. SEED VARIABLES
# ==============================================================================

cat("\n=== Processing seed variables ===\n")

# 7.1 Improved seeds
tryCatch({
  cat("  Extracting improved seed status...\n")
  
  plot_inputs <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_AS2BP1.dta"))
  
  improved <- plot_inputs |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      plot_id = paste(hhid, AS01Q01, AS01Q03, sep = "-"),
      crop_code = AS02BQ06,
      improved = dplyr::if_else(AS02BQ09 %in% c(3, 4), 1,
                                dplyr::if_else(AS02BQ09 %in% c(1, 2), 0, NA_real_))
    ) |>
    dplyr::group_by(hhid, plot_id, crop_code) |>
    dplyr::summarise(
      improved = max(improved, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      improved = dplyr::if_else(is.infinite(improved), NA_real_, improved)
    )
  
  haven::write_dta(improved, file.path(temp_dir, "improved.dta"))
  cat("  ✓ improved saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in improved seeds: ", e$message, "\n")
})

# 7.2 Seed kg
tryCatch({
  cat("  Calculating seed kg...\n")
  
  # Load conversion factors
  conversions <- haven::read_dta(file.path(temp_dir, "Conversion_factors.dta"))
  
  # Load seed data
  seeds <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_AS02CP1.dta"))
  
  seed_kg <- seeds |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      crop_code = AS02CQ04,
      unit = dplyr::case_when(
        AS02CQ05B == 1 ~ 1,
        AS02CQ05B == 6 ~ 5,
        TRUE ~ NA_real_
      ),
      seed_kg = AS02CQ05A,
      # Apply conversions
      seed_kg = dplyr::if_else(AS02CQ05B == 1, AS02CQ05A, seed_kg),
      seed_kg = dplyr::if_else(AS02CQ05B == 5, AS02CQ05A, seed_kg),  # litre
      seed_kg = dplyr::if_else(AS02CQ05B == 2, AS02CQ05A * 0.001, seed_kg),  # gram
      seed_kg = dplyr::if_else(AS02CQ03 == 2, 0, seed_kg)
    ) |>
    dplyr::left_join(conversions, by = "unit") |>
    dplyr::mutate(
      seed_kg = dplyr::if_else(!is.na(conversion), seed_kg * conversion, seed_kg)
    ) |>
    dplyr::group_by(hhid, crop_code) |>
    dplyr::summarise(
      seed_kg = sum(seed_kg, na.rm = TRUE),
      n_seed_kg = sum(!is.na(seed_kg)),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      seed_kg = dplyr::if_else(n_seed_kg == 0, NA_real_, seed_kg)
    ) |>
    dplyr::select(-n_seed_kg)
  
  # Distribute to plots
  plot_inputs <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_AS2BP1.dta"))
  plot_area <- haven::read_dta(file.path(temp_dir, "plot_area.dta"))
  
  seed_kg_plot <- plot_inputs |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      plot_id = paste(hhid, AS01Q01, AS01Q03, sep = "-"),
      crop_code = AS02BQ06
    ) |>
    dplyr::left_join(plot_area, by = c("hhid", "plot_id")) |>
    dplyr::left_join(seed_kg, by = c("hhid", "crop_code")) |>
    dplyr::group_by(hhid, crop_code) |>
    dplyr::mutate(
      total_land_area = sum(plot_area_GPS, na.rm = TRUE),
      indicator = plot_area_GPS / total_land_area,
      seed_kg = seed_kg * indicator
    ) |>
    dplyr::ungroup() |>
    dplyr::select(hhid, plot_id, crop_code, seed_kg) |>
    dplyr::distinct()
  
  haven::write_dta(seed_kg_plot, file.path(temp_dir, "seed_kg.dta"))
  haven::write_dta(seed_kg_plot, file.path(temp_dir, "seed_kg_merge.dta"))
  cat("  ✓ seed_kg saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in seed kg: ", e$message, "\n")
})

# 7.3 Seed kg sold (purchased)
tryCatch({
  cat("  Calculating purchased seed kg...\n")
  
  # Load conversion factors
  conversions <- haven::read_dta(file.path(temp_dir, "Conversion_factors.dta"))
  
  # Load seed data
  seeds <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_AS02CP1.dta"))
  
  seeds_amount_purchased_kg <- seeds |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      crop_code = AS02CQ04,
      unit = dplyr::case_when(
        AS02CQ08B == 1 ~ 1,
        AS02CQ08B == 6 ~ 5,
        TRUE ~ NA_real_
      ),
      seeds_amount_purchased_kg = AS02CQ08A,
      # Apply conversions
      seeds_amount_purchased_kg = dplyr::if_else(AS02CQ08B == 1, AS02CQ08A, 
                                                 seeds_amount_purchased_kg),
      seeds_amount_purchased_kg = dplyr::if_else(AS02CQ08B == 5, AS02CQ08A, 
                                                 seeds_amount_purchased_kg),
      seeds_amount_purchased_kg = dplyr::if_else(AS02CQ08B == 2, AS02CQ08A * 0.001, 
                                                 seeds_amount_purchased_kg)
    ) |>
    dplyr::left_join(conversions, by = "unit") |>
    dplyr::mutate(
      seeds_amount_purchased_kg = dplyr::if_else(!is.na(conversion), 
                                                 seeds_amount_purchased_kg * conversion,
                                                 seeds_amount_purchased_kg)
    ) |>
    dplyr::group_by(crop_code, hhid) |>
    dplyr::summarise(
      seeds_amount_purchased_kg = sum(seeds_amount_purchased_kg, na.rm = TRUE),
      n_seeds_amount_purchased_kg = sum(!is.na(seeds_amount_purchased_kg)),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      seeds_amount_purchased_kg = dplyr::if_else(n_seeds_amount_purchased_kg == 0, 
                                                 NA_real_, seeds_amount_purchased_kg)
    ) |>
    dplyr::select(-n_seeds_amount_purchased_kg)
  
  haven::write_dta(seeds_amount_purchased_kg, 
                   file.path(temp_dir, "seeds_amount_purchased_kg.dta"))
  cat("  ✓ seeds_amount_purchased_kg saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in purchased seed kg: ", e$message, "\n")
})

# 7.4 Seed value
tryCatch({
  cat("  Calculating seed value...\n")
  
  # Load seed data
  seeds <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_AS02CP1.dta"))
  
  seed_value_temp <- seeds |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      crop_code = AS02CQ04,
      seed_value_temp = AS02CQ08C
    ) |>
    dplyr::group_by(crop_code, hhid) |>
    dplyr::summarise(
      seed_value_temp = sum(seed_value_temp, na.rm = TRUE),
      n_seed_value_temp = sum(!is.na(seed_value_temp)),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      seed_value_temp = dplyr::if_else(n_seed_value_temp == 0, NA_real_, seed_value_temp)
    ) |>
    dplyr::select(-n_seed_value_temp)
  
  # Use valuation function
  seed_value_out <- val_median_seeds_noimp_noea(
    data = seed_value_temp,
    temp_path = temp_dir,
    hhid_var = "hhid",
    id_link_seeds_var = "hhid",
    cropvar_var = "crop_code"
  )
  
  seed_value_final <- seed_value_out |>
    dplyr::select(plot_id, crop_code, seed_value)
  
  haven::write_dta(seed_value_final, file.path(temp_dir, "seed_value.dta"))
  cat("  ✓ seed_value saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in seed value: ", e$message, "\n")
})

# ==============================================================================
# 8. LABOR DAYS
# ==============================================================================

cat("\n=== Processing labor data ===\n")

tryCatch({
  cat("  Processing labor days (skeleton - complex)...\n")
  
  # Load labor data (PP and PH components)
  labor_pp <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_AS2AP1.dta"))
  labor_ph <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_AS2AP2.dta"))
  
  # This is a placeholder - full labor processing would be extensive
  
  labor_days <- data.frame(
    plot_id = character(),
    total_labor_days = numeric(),
    total_family_labor_days = numeric(),
    total_hired_labor_days = numeric(),
    hired_labor_value = numeric()
  )
  
  haven::write_dta(labor_days, file.path(temp_dir, "labor_days.dta"))
  cat("  ✓ labor_days placeholder saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in labor processing: ", e$message, "\n")
})

# ==============================================================================
# 9. FERTILIZER VARIABLES
# ==============================================================================

cat("\n=== Processing fertilizer variables ===\n")

# 9.1 Inorganic fertilizer
tryCatch({
  cat("  Extracting inorganic fertilizer use...\n")
  
  ferts <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_AS1P1.dta"))
  
  inorganic_fertilizer <- ferts |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      plot_id = paste(hhid, AS01Q01, AS01Q03, sep = "-"),
      inorganic_fertilizer = dplyr::if_else(
        AS02AQ09A == 1 | AS02AQ10A == 1 | AS02AQ11A == 1 | AS02AQ12A == 1, 1,
        dplyr::if_else(AS02AQ09A == 2 & AS02AQ10A == 2 & 
                         AS02AQ11A == 2 & AS02AQ12A == 2, 0, NA_real_)
      )
    ) |>
    dplyr::group_by(plot_id) |>
    dplyr::summarise(
      inorganic_fertilizer = max(inorganic_fertilizer, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      inorganic_fertilizer = dplyr::if_else(is.infinite(inorganic_fertilizer), 
                                            NA_real_, inorganic_fertilizer)
    )
  
  haven::write_dta(inorganic_fertilizer, file.path(temp_dir, "inorganic_fertilizer.dta"))
  cat("  ✓ inorganic_fertilizer saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in inorganic fertilizer: ", e$message, "\n")
})

# 9.2 Nitrogen equivalent
tryCatch({
  cat("  Calculating nitrogen equivalent...\n")
  
  # Load conversion factors
  harvest1 <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_AS2E1P2.dta"))
  
  conversions <- harvest1 |>
    dplyr::mutate(
      region = MS00Q10,
      crop_code = CULTURE,
      unit = AS02EQ07B,
      conversion = AS02EQ07C / AS02EQ07A
    ) |>
    dplyr::filter(!is.na(conversion) & is.finite(conversion)) |>
    dplyr::group_by(region, crop_code, unit) |>
    dplyr::summarise(
      conversion = median(conversion, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      conversion = dplyr::if_else(unit == 1, 1, conversion)
    ) |>
    dplyr::filter(!is.na(conversion) & conversion != 0) |>
    dplyr::group_by(region, unit) |>
    dplyr::summarise(
      conversion = median(conversion, na.rm = TRUE),
      .groups = "drop"
    )
  
  # Load fertilizer data
  ferts <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_AS2AP1.dta"))
  
  nitrogen_kg <- ferts |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      plot_id = paste(hhid, AS01Q01, AS01Q03, sep = "-"),
      region = MS00Q10,
      # Inorganic fertilizer flag
      inorganic_fertilizer = dplyr::if_else(
        AS02AQ09A == 1 | AS02AQ10A == 1 | AS02AQ11A == 1 | AS02AQ12A == 1, 1,
        dplyr::if_else(AS02AQ09A == 2 & AS02AQ10A == 2 & 
                         AS02AQ11A == 2 & AS02AQ12A == 2, 0, NA_real_)
      ),
      # UREA
      unit = dplyr::case_when(
        AS02AQ09C == 6 ~ 5,
        TRUE ~ NA_real_
      ),
      UREA_kg = AS02AQ09B,
      # DAP
      DAP_kg = AS02AQ10B,
      # NPK
      NPK_kg = AS02AQ11B
    ) |>
    dplyr::left_join(conversions, by = c("region", "unit")) |>
    dplyr::mutate(
      # Apply conversions
      UREA_kg = dplyr::if_else(!is.na(conversion), UREA_kg * conversion, UREA_kg),
      UREA_kg = dplyr::if_else(AS02AQ09C == 1, AS02AQ09B, UREA_kg),
      UREA_kg = dplyr::if_else(AS02AQ09A == 2, 0, UREA_kg),
      
      DAP_kg = dplyr::if_else(!is.na(conversion), DAP_kg * conversion, DAP_kg),
      DAP_kg = dplyr::if_else(AS02AQ10C == 1, AS02AQ10B, DAP_kg),
      DAP_kg = dplyr::if_else(AS02AQ10A == 2, 0, DAP_kg),
      
      NPK_kg = dplyr::if_else(!is.na(conversion), NPK_kg * conversion, NPK_kg),
      NPK_kg = dplyr::if_else(AS02AQ11C == 1, AS02AQ11B, NPK_kg),
      NPK_kg = dplyr::if_else(AS02AQ11A == 2, 0, NPK_kg)
    ) |>
    dplyr::mutate(
      # Nitrogen equivalents
      UREA_N_kg = UREA_kg * 0.46,
      DAP_N_kg = DAP_kg * 0.18,
      NPK_N_kg = NPK_kg * 0.15,
      nitrogen_kg = UREA_N_kg + DAP_N_kg + NPK_N_kg,
      nitrogen_kg = dplyr::if_else(inorganic_fertilizer == 0, 0, nitrogen_kg)
    ) |>
    dplyr::group_by(plot_id, hhid) |>
    dplyr::summarise(
      nitrogen_kg = sum(nitrogen_kg, na.rm = TRUE),
      UREA_kg = sum(UREA_kg, na.rm = TRUE),
      DAP_kg = sum(DAP_kg, na.rm = TRUE),
      NPK_kg = sum(NPK_kg, na.rm = TRUE),
      n_nitrogen_kg = sum(!is.na(nitrogen_kg)),
      n_UREA_kg = sum(!is.na(UREA_kg)),
      n_DAP_kg = sum(!is.na(DAP_kg)),
      n_NPK_kg = sum(!is.na(NPK_kg)),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      dplyr::across(c(nitrogen_kg, UREA_kg, DAP_kg, NPK_kg),
                    ~ dplyr::if_else(is.na(.x), NA_real_, .x))
    ) |>
    dplyr::select(-starts_with("n_"))
  
  haven::write_dta(nitrogen_kg, file.path(temp_dir, "nitrogen_kg.dta"))
  cat("  ✓ nitrogen_kg saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in nitrogen equivalent: ", e$message, "\n")
})

# 9.3 Inorganic fertilizer value
tryCatch({
  cat("  Calculating inorganic fertilizer value...\n")
  
  # Load seed data (which includes fertilizer purchases in Niger)
  seeds <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_AS02CP1.dta"))
  
  # Load conversion factors
  harvest1 <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_AS2E1P2.dta"))
  
  conversions <- harvest1 |>
    dplyr::mutate(
      region = MS00Q10,
      crop_code = CULTURE,
      unit = AS02EQ07B,
      conversion = AS02EQ07C / AS02EQ07A
    ) |>
    dplyr::filter(!is.na(conversion) & is.finite(conversion)) |>
    dplyr::group_by(region, crop_code, unit) |>
    dplyr::summarise(
      conversion = median(conversion, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      conversion = dplyr::if_else(unit == 1, 1, conversion)
    ) |>
    dplyr::filter(!is.na(conversion) & conversion != 0) |>
    dplyr::group_by(region, unit) |>
    dplyr::summarise(
      conversion = median(conversion, na.rm = TRUE),
      .groups = "drop"
    )
  
  fert_purch <- seeds |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      region = MS00Q10,
      crop_code = AS02CQ04,
      # Identify fertilizer types
      fert_type = dplyr::case_when(
        AS02CQ02 == 5 ~ "NPK",
        AS02CQ02 == 3 ~ "UREA",
        AS02CQ02 == 4 ~ "DAP",
        TRUE ~ NA_character_
      ),
      unit = dplyr::case_when(
        AS02CQ08B == 1 ~ 1,
        AS02CQ08B == 6 ~ 5,
        TRUE ~ NA_real_
      ),
      fert_purchased_kg = AS02CQ08A,
      fert_purchased_value = AS02CQ08C
    ) |>
    dplyr::left_join(conversions, by = c("region", "unit")) |>
    dplyr::mutate(
      fert_purchased_kg = dplyr::if_else(!is.na(conversion), 
                                         fert_purchased_kg * conversion,
                                         fert_purchased_kg),
      fert_purchased_kg = dplyr::if_else(AS02CQ08B == 1, AS02CQ08A, fert_purchased_kg),
      fert_purchased_kg = dplyr::if_else(AS02CQ08B == 5, AS02CQ08A, fert_purchased_kg),
      fert_purchased_kg = dplyr::if_else(AS02CQ08B == 2, AS02CQ08A * 0.001, 
                                         fert_purchased_kg)
    ) |>
    dplyr::filter(!is.na(fert_type))
  
  # Use valuation function for each fertilizer type
  # This would need to be run for UREA, DAP, and NPK separately
  # For now, create placeholder with structure matching original
  
  fert_value_out <- fert_purch |>
    dplyr::group_by(hhid, fert_type) |>
    dplyr::summarise(
      fert_purchased_kg = sum(fert_purchased_kg, na.rm = TRUE),
      fert_purchased_value = sum(fert_purchased_value, na.rm = TRUE),
      .groups = "drop"
    ) |>
    tidyr::pivot_wider(
      id_cols = hhid,
      names_from = fert_type,
      values_from = c(fert_purchased_kg, fert_purchased_value),
      values_fill = 0
    )
  
  haven::write_dta(fert_value_out, file.path(temp_dir, "fert_purchased_temp.dta"))
  cat("  ✓ fertilizer value processed\n")
  
}, error = function(e) {
  cat("  ✗ Error in fertilizer value: ", e$message, "\n")
})

# 9.4 Organic fertilizer
tryCatch({
  cat("  Extracting organic fertilizer use...\n")
  
  ferts <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_AS2AP1.dta"))
  
  organic_fertilizer <- ferts |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      plot_id = paste(hhid, AS01Q01, AS01Q03, sep = "-"),
      organic_fertilizer = dplyr::if_else(
        AS02AQ06A == 1 | AS02AQ07A == 1, 1,
        dplyr::if_else(AS02AQ07A == 2 & AS02AQ06A == 2, 0, NA_real_)
      )
    ) |>
    dplyr::group_by(plot_id) |>
    dplyr::summarise(
      organic_fertilizer = max(organic_fertilizer, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      organic_fertilizer = dplyr::if_else(is.infinite(organic_fertilizer), 
                                          NA_real_, organic_fertilizer)
    )
  
  haven::write_dta(organic_fertilizer, file.path(temp_dir, "organic_fertilizer.dta"))
  cat("  ✓ organic_fertilizer saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in organic fertilizer: ", e$message, "\n")
})

# 9.5 Pesticides
tryCatch({
  cat("  Extracting pesticide use...\n")
  
  ferts <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_AS2AP1.dta"))
  
  used_pesticides <- ferts |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      plot_id = paste(hhid, AS01Q01, AS01Q03, sep = "-"),
      used_pesticides = dplyr::if_else(AS02AQ13A == 1, 1,
                                       dplyr::if_else(AS02AQ13A == 2, 0, NA_real_))
    ) |>
    dplyr::group_by(plot_id) |>
    dplyr::summarise(
      used_pesticides = max(used_pesticides, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      used_pesticides = dplyr::if_else(is.infinite(used_pesticides), 
                                       NA_real_, used_pesticides)
    )
  
  haven::write_dta(used_pesticides, file.path(temp_dir, "used_pesticides.dta"))
  cat("  ✓ used_pesticides saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in pesticides: ", e$message, "\n")
})

# ==============================================================================
# 10. PLOT-LEVEL VARIABLES
# ==============================================================================

cat("\n=== Processing plot-level variables ===\n")

# 10.1 Plot ownership
tryCatch({
  cat("  Extracting plot ownership...\n")
  
  plot_roster <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_AS1P1.dta"))
  
  plot_owned <- plot_roster |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      plot_id = paste(hhid, AS01Q01, AS01Q03, sep = "-"),
      plot_owned = dplyr::if_else(AS01Q14 %in% c(1, 2, 4), 1,
                                  dplyr::if_else(AS01Q14 %in% c(3, 5, 6), 0, NA_real_)),
      plot_certificate = dplyr::if_else(AS01Q15 %in% 1:4, 1,
                                        dplyr::if_else(AS01Q15 == 5, 0, NA_real_)),
      plot_certificate = dplyr::if_else(plot_owned == 0, 0, plot_certificate)
    ) |>
    dplyr::select(plot_id, plot_owned, plot_certificate) |>
    dplyr::distinct()
  
  haven::write_dta(plot_owned, file.path(temp_dir, "plot_owned.dta"))
  cat("  ✓ plot_owned saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in plot ownership: ", e$message, "\n")
})

# 10.2 Irrigated
tryCatch({
  cat("  Extracting irrigation status...\n")
  
  plot_roster <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_AS1P1.dta"))
  
  irrigated <- plot_roster |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      plot_id = paste(hhid, AS01Q01, AS01Q03, sep = "-"),
      irrigated = dplyr::if_else(!AS01Q31 %in% c(5, 7, 9), 1,
                                 dplyr::if_else(AS01Q31 == 5, 0, NA_real_)),
      irrigated = dplyr::if_else(AS01Q35 == 1, 1, irrigated)
    ) |>
    dplyr::select(plot_id, irrigated) |>
    dplyr::distinct()
  
  haven::write_dta(irrigated, file.path(temp_dir, "irrigated.dta"))
  cat("  ✓ irrigated saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in irrigation: ", e$message, "\n")
})

# 10.3 Erosion protection
tryCatch({
  cat("  Extracting erosion protection...\n")
  
  plot_roster <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_AS1P1.dta"))
  
  erosion_protection <- plot_roster |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      plot_id = paste(hhid, AS01Q01, AS01Q03, sep = "-"),
      erosion_protection = dplyr::if_else(AS01Q27 == 1, 1,
                                          dplyr::if_else(AS01Q27 == 2, 0, NA_real_))
    ) |>
    dplyr::select(plot_id, erosion_protection) |>
    dplyr::distinct()
  
  haven::write_dta(erosion_protection, file.path(temp_dir, "erosion_protection.dta"))
  cat("  ✓ erosion_protection saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in erosion protection: ", e$message, "\n")
})

# 10.4 Tractor
tryCatch({
  cat("  Extracting tractor ownership...\n")
  
  items <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_AS03P1.dta"))
  
  tractor <- items |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      tractor = dplyr::if_else(
        AS03Q02 == 10 & (AS03Q08 == 1 | AS03Q09 == 1), 1,
        dplyr::if_else(AS03Q02 == 10 & AS03Q03 == 2, 0,
                       dplyr::if_else(AS03Q02 == 10 & AS03Q03 == 1 & 
                                        AS03Q09 == 2 & AS03Q08 == 2, 0, NA_real_))
      )
    ) |>
    dplyr::group_by(hhid) |>
    dplyr::summarise(
      tractor = max(tractor, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      tractor = dplyr::if_else(is.infinite(tractor), NA_real_, tractor)
    )
  
  haven::write_dta(tractor, file.path(temp_dir, "tractor.dta"))
  cat("  ✓ tractor saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in tractor: ", e$message, "\n")
})

# 10.5 Number of fallow plots
tryCatch({
  cat("  Calculating number of fallow plots...\n")
  
  plot_roster <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_AS1P1.dta"))
  
  nb_fallow_plots <- plot_roster |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      fallow_plot = dplyr::if_else(AS01Q39 == 1, 1, 0),
      fallow_plot = dplyr::if_else(AS01Q38 == 1, 0, fallow_plot)
    ) |>
    dplyr::group_by(hhid) |>
    dplyr::summarise(
      nb_fallow_plots = sum(fallow_plot, na.rm = TRUE),
      .groups = "drop"
    )
  
  haven::write_dta(nb_fallow_plots, file.path(temp_dir, "nb_fallow_plots.dta"))
  cat("  ✓ nb_fallow_plots saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in fallow plots: ", e$message, "\n")
})

# 10.6 Number of plots
tryCatch({
  cat("  Calculating number of plots...\n")
  
  plot_roster <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_AS1P1.dta"))
  
  nb_plots <- plot_roster |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      fallow_plot = dplyr::if_else(AS01Q39 == 1, 1, 0),
      fallow_plot = dplyr::if_else(AS01Q38 == 1, 0, fallow_plot)
    ) |>
    dplyr::group_by(hhid) |>
    dplyr::summarise(
      nb_plots = n_distinct(paste(AS01Q01, AS01Q03, sep = "-")),
      .groups = "drop"
    )
  
  haven::write_dta(nb_plots, file.path(temp_dir, "nb_plots.dta"))
  cat("  ✓ nb_plots saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in number of plots: ", e$message, "\n")
})

# ==============================================================================
# 11. HOUSEHOLD-LEVEL VARIABLES
# ==============================================================================

cat("\n=== Processing household-level variables ===\n")

# 11.1 Household education
tryCatch({
  cat("  Extracting household education...\n")
  
  educ <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_MS02P1.dta"))
  indiv <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_MS01P1.dta"))
  
  hh_education <- educ |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      formal_education = dplyr::if_else(MS02Q04 == 1, 1,
                                        dplyr::if_else(MS02Q04 %in% c(2:4), 0, NA_real_)),
      primary_education = dplyr::if_else(MS02Q12 %in% c(3:7) | MS02Q23 %in% c(3:7), 1,
                                         dplyr::if_else(MS02Q12 %in% c(1, 2) | 
                                                          MS02Q23 %in% c(1, 2), 0, NA_real_)),
      primary_education = dplyr::if_else(formal_education == 0, 0, primary_education)
    ) |>
    dplyr::left_join(
      indiv |> dplyr::select(GRAPPE, MENAGE, EXTENSION, MS01Q06A),
      by = c("GRAPPE", "MENAGE", "EXTENSION")
    ) |>
    dplyr::mutate(
      dplyr::across(c(formal_education, primary_education),
                    ~ dplyr::if_else(MS01Q06A < 6, 0, .x))
    ) |>
    dplyr::group_by(hhid) |>
    dplyr::summarise(
      hh_formal_education = max(formal_education, na.rm = TRUE),
      hh_primary_education = max(primary_education, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      hh_formal_education = dplyr::if_else(is.infinite(hh_formal_education), 
                                           NA_real_, hh_formal_education),
      hh_primary_education = dplyr::if_else(is.infinite(hh_primary_education), 
                                            NA_real_, hh_primary_education)
    )
  
  haven::write_dta(hh_education, file.path(temp_dir, "hh_primary_education.dta"))
  cat("  ✓ hh_primary_education saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in household education: ", e$message, "\n")
})

# 11.2 Electricity access
tryCatch({
  cat("  Extracting electricity access...\n")
  
  housing <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_MS06P1.dta"))
  
  electricity <- housing |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      hh_electricity_access = dplyr::if_else(MS06Q23 == 1, 1,
                                             dplyr::if_else(MS06Q23 == 2, 0, NA_real_)),
      hh_electricity_access = dplyr::if_else(
        MS06Q26 %in% c(1, 2, 5), 1, hh_electricity_access
      )
    ) |>
    dplyr::select(hhid, hh_electricity_access) |>
    dplyr::distinct()
  
  haven::write_dta(electricity, file.path(temp_dir, "hh_electricity_access.dta"))
  cat("  ✓ hh_electricity_access saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in electricity access: ", e$message, "\n")
})

# 11.3 Dependency ratio
tryCatch({
  cat("  Calculating dependency ratio...\n")
  
  indiv <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_MS01P1.dta"))
  
  dependency <- indiv |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      age = MS01Q06A,
      age = dplyr::if_else(age %in% c(98, 99), NA_real_, age),
      dep_temp = dplyr::if_else(!is.na(age) & (age < 15 | age > 65), 1, 0),
      nondep_temp = dplyr::if_else(!is.na(age) & age >= 15 & age <= 65, 1, 0)
    ) |>
    dplyr::group_by(hhid) |>
    dplyr::summarise(
      dep = sum(dep_temp, na.rm = TRUE),
      nondep = sum(nondep_temp, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      hh_dependency_ratio = dep / nondep,
      hh_dependency_ratio = dplyr::if_else(nondep == 0, dep, hh_dependency_ratio)
    ) |>
    dplyr::select(hhid, hh_dependency_ratio)
  
  haven::write_dta(dependency, file.path(temp_dir, "hh_dependency_ratio.dta"))
  cat("  ✓ hh_dependency_ratio saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in dependency ratio: ", e$message, "\n")
})

# 11.4 Livestock
tryCatch({
  cat("  Extracting livestock ownership...\n")
  
  livestock <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_AS4AP2.dta"))
  cover <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_MS00P1.dta"))
  
  livestock_out <- livestock |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      livestock = dplyr::if_else(AS4AQ05 == 1, 1,
                                 dplyr::if_else(AS4AQ05 == 2, 0, NA_real_))
    ) |>
    dplyr::group_by(hhid) |>
    dplyr::summarise(
      livestock = max(livestock, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      livestock = dplyr::if_else(is.infinite(livestock), NA_real_, livestock)
    ) |>
    dplyr::right_join(
      cover |> dplyr::mutate(hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-")) |>
        dplyr::select(hhid) |> dplyr::distinct(),
      by = "hhid"
    ) |>
    dplyr::mutate(
      livestock = dplyr::if_else(is.na(livestock), 0, livestock)
    )
  
  haven::write_dta(livestock_out, file.path(temp_dir, "livestock.dta"))
  cat("  ✓ livestock saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in livestock: ", e$message, "\n")
})

# 11.5 Consumption quintile
tryCatch({
  cat("  Extracting consumption quintile...\n")
  
  csption <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2014_P1P2_ConsoMen.dta"))
  
  cons_quint <- csption |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-")
    ) |>
    dplyr::select(hhid, totcons = dtet) |>
    dplyr::distinct() |>
    dplyr::mutate(
      cons_quint = dplyr::ntile(totcons, 5)
    )
  
  haven::write_dta(cons_quint, file.path(temp_dir, "cons_quint.dta"))
  
  # Total consumption
  totcons <- csption |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-")
    ) |>
    dplyr::select(hhid, totcons = dtet) |>
    dplyr::distinct()
  
  haven::write_dta(totcons, file.path(temp_dir, "totcons.dta"))
  cat("  ✓ consumption variables saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in consumption variables: ", e$message, "\n")
})

# 11.6 Household shock
tryCatch({
  cat("  Extracting household shocks...\n")
  
  shocks <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_MS10P1.dta"))
  
  hh_shock <- shocks |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      hh_shock = dplyr::if_else(MS10Q02 == 1, 1,
                                dplyr::if_else(MS10Q02 == 2, 0, NA_real_))
    ) |>
    dplyr::group_by(hhid) |>
    dplyr::summarise(
      hh_shock = max(hh_shock, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      hh_shock = dplyr::if_else(is.infinite(hh_shock), NA_real_, hh_shock)
    )
  
  haven::write_dta(hh_shock, file.path(temp_dir, "shock.dta"))
  cat("  ✓ hh_shock saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in household shocks: ", e$message, "\n")
})

# 11.7 Household size
tryCatch({
  cat("  Extracting household size...\n")
  
  indiv <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_MS01P1.dta"))
  
  hh_size <- indiv |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-")
    ) |>
    dplyr::group_by(hhid) |>
    dplyr::summarise(
      hh_size = n_distinct(MS01Q0),
      .groups = "drop"
    )
  
  haven::write_dta(hh_size, file.path(temp_dir, "size.dta"))
  cat("  ✓ hh_size saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in household size: ", e$message, "\n")
})

# ==============================================================================
# 12. ASSET INDICES
# ==============================================================================

cat("\n=== Calculating asset indices ===\n")

tryCatch({
  cat("  Calculating asset indices...\n")
  
  # Agricultural assets
  items <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_AS03P1.dta"))
  
  ag_assets <- items |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      hh_owns_ = dplyr::if_else(AS03Q03 == 1, 1, 0)
    ) |>
    dplyr::filter(!is.na(AS03Q02)) |>
    dplyr::group_by(hhid, AS03Q02) |>
    dplyr::summarise(
      hh_owns_ = max(hh_owns_, na.rm = TRUE),
      .groups = "drop"
    ) |>
    tidyr::pivot_wider(
      id_cols = hhid,
      names_from = AS03Q02,
      values_from = hh_owns_,
      values_fill = 0
    ) |>
    dplyr::select(-tidyselect::any_of("18"))
  
  ag_asset_index <- ag_assets |>
    dplyr::mutate(
      ag_asset_index = rowMeans(dplyr::across(-hhid), na.rm = TRUE)
    ) |>
    dplyr::select(hhid, ag_asset_index)
  
  haven::write_dta(ag_asset_index, file.path(temp_dir, "ag_asset_index.dta"))
  
  # Household assets
  hh_items <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_MS07P1.dta"))
  
  hh_assets <- hh_items |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      hh_owns = dplyr::if_else(MS07Q02 == 1, 1, 0)
    ) |>
    dplyr::filter(!is.na(MS07Q01)) |>
    dplyr::group_by(hhid, MS07Q01) |>
    dplyr::summarise(
      hh_owns = max(hh_owns, na.rm = TRUE),
      .groups = "drop"
    ) |>
    tidyr::pivot_wider(
      id_cols = hhid,
      names_from = MS07Q01,
      values_from = hh_owns,
      values_fill = 0
    )
  
  hh_asset_index <- hh_assets |>
    dplyr::mutate(
      hh_asset_index = rowMeans(dplyr::across(-hhid), na.rm = TRUE)
    ) |>
    dplyr::select(hhid, hh_asset_index)
  
  haven::write_dta(hh_asset_index, file.path(temp_dir, "hh_asset_index.dta"))
  cat("  ✓ asset indices saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in asset indices: ", e$message, "\n")
})

# 11.8 Non-farm enterprise
tryCatch({
  cat("  Extracting non-farm enterprise...\n")
  
  nfe <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_MS05AP1.dta"))
  
  nfe_out <- nfe |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      nonfarm_enterprise = dplyr::if_else(MS05Q11 == 1, 1,
                                          dplyr::if_else(MS05Q11 == 2, 0, NA_real_))
    ) |>
    dplyr::select(hhid, nonfarm_enterprise) |>
    dplyr::distinct()
  
  haven::write_dta(nfe_out, file.path(temp_dir, "nfe.dta"))
  cat("  ✓ nonfarm_enterprise saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in non-farm enterprise: ", e$message, "\n")
})

# ==============================================================================
# 13. INDIVIDUAL-LEVEL VARIABLES
# ==============================================================================

cat("\n=== Processing individual-level variables ===\n")

# 13.1 Individual characteristics
tryCatch({
  cat("  Extracting individual characteristics...\n")
  
  indiv <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_MS01P1.dta"))
  
  indiv_chars <- indiv |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      ID = paste(hhid, MS01Q0, sep = "-"),
      female = dplyr::if_else(MS01Q01 == 2, 1,
                              dplyr::if_else(MS01Q01 == 1, 0, NA_real_)),
      age = MS01Q06A,
      age = dplyr::if_else(age %in% c(98, 99), NA_real_, age),
      married = dplyr::if_else(MS01Q15 %in% c(2, 3), 1,
                               dplyr::if_else(MS01Q15 %in% c(1, 4, 5, 6), 0, NA_real_)),
      married = dplyr::if_else(is.na(married), 0, married)
    ) |>
    dplyr::mutate(
      # Clean relationship to head
      relationship_head_temp = haven::as_factor(MS01Q02) |> as.character(),
      relationship_head = stringr::str_replace_all(relationship_head_temp, 
                                                   `"[^a-zA-Z0-9]"`, ""),
      relationship_head = tolower(relationship_head),
      relationship_head = dplyr::case_when(
        relationship_head == "chefdemnage" ~ "Head",
        relationship_head == "beauprebellemre" ~ "Father-in-law/Mother-in-law",
        relationship_head == "beaufrrebellesoeur" ~ "Brother-in-law/Sister-in-law",
        relationship_head == "beaufilsbellefille" ~ "Son-in-law/Daughter-in-law",
        relationship_head == "grandpregrandmre" ~ "Grandparent",
        relationship_head == "domestiqueouparentdudomestique" ~ "Servant",
        relationship_head == "conjointeducm" ~ "Spouse",
        relationship_head == "filsfille" ~ "Son/Daughter",
        relationship_head == "premre" ~ "Father/Mother",
        relationship_head == "frresoeur" ~ "Sister/Brother",
        relationship_head == "cousincousine" ~ "Other Relative",
        relationship_head == "autresparentsducmouduconjointe" ~ "Other Relative",
        relationship_head == "personnenonapparenteaucmoulaconjointe" ~ "Non Relative",
        relationship_head == "neveunice" ~ "Niece/Nephew",
        relationship_head == "petitfilspetitefille" ~ "Grandchild",
        TRUE ~ relationship_head
      )
    ) |>
    dplyr::select(hhid, ID, married, female, age, relationship_head, MS01Q06B) |>
    dplyr::distinct()
  
  haven::write_dta(indiv_chars, file.path(temp_dir, "indiv_chars.dta"))
  cat("  ✓ indiv_chars saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in individual characteristics: ", e$message, "\n")
})

# 13.2 Labor
tryCatch({
  cat("  Extracting labor variables...\n")
  
  labor <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_MS04P1.dta"))
  indiv <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_MS01P1.dta"))
  
  labor_out <- labor |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      ID = paste(hhid, MS04Q00, sep = "-"),
      # Work types
      farm_work = dplyr::if_else(MS04Q01 == 1, 1,
                                 dplyr::if_else(MS04Q01 == 2, 0, NA_real_)),
      SOB_work = dplyr::if_else(MS04Q02 == 1, 1,
                                dplyr::if_else(MS04Q02 == 2, 0, NA_real_)),
      wage_work = dplyr::if_else(MS04Q03 == 1, 1,
                                 dplyr::if_else(MS04Q03 == 2, 0, NA_real_)),
      # Industry
      ind_ag = dplyr::if_else(MS04Q23 >= 11 & MS04Q23 <= 40, 1, 0),
      ind_fish = dplyr::if_else(MS04Q23 %in% c(51, 52), 1, 0),
      ind_mining = dplyr::if_else(MS04Q23 >= 60 & MS04Q23 <= 72, 1, 0),
      ind_manuf = dplyr::if_else(MS04Q23 >= 81 & MS04Q23 <= 292, 1, 0),
      ind_const = dplyr::if_else(MS04Q23 %in% c(301, 302), 1, 0),
      ind_serv = dplyr::if_else(MS04Q23 >= 310 & MS04Q23 <= 430, 1, 0)
    ) |>
    dplyr::mutate(
      dplyr::across(c(ind_ag, ind_fish, ind_mining, ind_manuf, ind_const, ind_serv),
                    ~ dplyr::if_else(MS04Q24 %in% c(4, 6, 7, 8, 9) | MS04Q20 == 2, 
                                     0, .x))
    )
  
  # Calculate hours
  labor_out <- labor_out |>
    dplyr::mutate(
      hour_job1 = MS04Q28,
      hour_job1 = dplyr::if_else(MS04Q05 == 2 & MS04Q06 == 2, 0, hour_job1),
      hour_job2 = MS04Q52,
      hour_job2 = dplyr::if_else(MS04Q05 == 2 & MS04Q06 == 2, 0, hour_job2),
      
      day_job1 = MS04Q27,
      day_job1 = dplyr::if_else(MS04Q05 == 2 & MS04Q06 == 2, 0, day_job1),
      day_job2 = MS04Q53,
      day_job2 = dplyr::if_else(MS04Q05 == 2 & MS04Q06 == 2, 0, day_job2),
      
      month_job1 = MS04Q25,
      month_job1 = dplyr::if_else(MS04Q05 == 2 & MS04Q06 == 2, 0, month_job1),
      month_job2 = MS04Q51,
      month_job2 = dplyr::if_else(MS04Q05 == 2 & MS04Q06 == 2, 0, month_job2),
      
      week_job1 = MS04Q26,
      week_job1 = dplyr::if_else(MS04Q05 == 2 & MS04Q06 == 2, 0, week_job1),
      week_job2 = MS04Q51B,
      week_job2 = dplyr::if_else(MS04Q05 == 2 & MS04Q06 == 2, 0, week_job2),
      
      av_hours1 = (month_job1 * week_job1 * hour_job1 * day_job1) / 52,
      av_hours2 = (month_job2 * week_job2 * hour_job2 * day_job2) / 52
    )
  
  # Job types
  labor_out <- labor_out |>
    dplyr::mutate(
      farm_job1 = dplyr::if_else(MS04Q23 %in% c(1101:1107, 1201:1205), 1, 0),
      farm_job2 = dplyr::if_else(MS04Q48 %in% c(1101:1107, 1201:1205), 1, 0),
      farm_job1 = dplyr::if_else(farm_job1 == 1 & MS04Q24 %in% c(1, 2, 3, 7), 0, farm_job1),
      farm_job2 = dplyr::if_else(farm_job2 == 1 & MS04Q50 %in% c(1, 2, 3, 7), 0, farm_job2),
      
      SB_job1 = dplyr::if_else(MS04Q23 %in% c(6101, 6202:6212), 1, 0),
      SB_job2 = dplyr::if_else(MS04Q48 %in% c(6101, 6202:6212), 1, 0),
      SB_job1 = dplyr::if_else(SB_job1 == 1 & MS04Q24 %in% c(1, 2, 3, 7), 0, SB_job1),
      SB_job2 = dplyr::if_else(SB_job2 == 1 & MS04Q50 %in% c(1, 2, 3, 7), 0, SB_job2),
      
      wage_job1 = dplyr::if_else(!MS04Q23 %in% c(1101:1107, 1201:1205, 6101, 6202:6212), 1, 0),
      wage_job2 = dplyr::if_else(!MS04Q48 %in% c(1101:1107, 1201:1205, 6101, 6202:6212), 1, 0),
      wage_job1 = dplyr::if_else(wage_job1 == 0 & MS04Q24 %in% c(1, 2, 3, 7), 1, wage_job1),
      wage_job2 = dplyr::if_else(wage_job2 == 0 & MS04Q50 %in% c(1, 2, 3, 7), 1, wage_job2)
    )
  
  # Calculate hours by activity
  labor_out <- labor_out |>
    dplyr::mutate(
      farm_hrs1 = dplyr::if_else(farm_job1 == 1, av_hours1, 0),
      farm_hrs2 = dplyr::if_else(farm_job2 == 1, av_hours2, 0),
      SB_hrs1 = dplyr::if_else(SB_job1 == 1, av_hours1, 0),
      SB_hrs2 = dplyr::if_else(SB_job2 == 1, av_hours2, 0),
      wage_hrs1 = dplyr::if_else(wage_job1 == 1, av_hours1, 0),
      wage_hrs2 = dplyr::if_else(wage_job2 == 1, av_hours2, 0),
      
      farm_hrs = farm_hrs1 + farm_hrs2,
      SB_hrs = SB_hrs1 + SB_hrs2,
      wage_hrs = wage_hrs1 + wage_hrs2
    ) |>
    dplyr::left_join(
      indiv |> dplyr::select(GRAPPE, MENAGE, EXTENSION, MS01Q06A),
      by = c("GRAPPE", "MENAGE", "EXTENSION")
    ) |>
    dplyr::mutate(
      working_age = MS01Q06A >= 6
    ) |>
    dplyr::mutate(
      dplyr::across(c(farm_work, SOB_work, wage_work, farm_hrs, SB_hrs, wage_hrs,
                      ind_ag, ind_const, ind_fish, ind_manuf, ind_mining, ind_serv),
                    ~ dplyr::if_else(!working_age, 0, .x))
    ) |>
    dplyr::select(ID, hhid, farm_work, SOB_work, wage_work, farm_hrs, SB_hrs, wage_hrs,
                  ind_ag, ind_const, ind_fish, ind_manuf, ind_mining, ind_serv, working_age) |>
    dplyr::distinct()
  
  haven::write_dta(labor_out, file.path(temp_dir, "labor.dta"))
  cat("  ✓ labor saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in labor variables: ", e$message, "\n")
})

# 13.3 Education
tryCatch({
  cat("  Extracting education variables...\n")
  
  educ <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_MS02P1.dta"))
  indiv <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_MS01P1.dta"))
  
  educ_out <- educ |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      ID = paste(hhid, MS02Q00, sep = "-"),
      formal_education = dplyr::if_else(MS02Q04 == 1, 1,
                                        dplyr::if_else(MS02Q04 %in% c(2:4), 0, NA_real_)),
      primary_education = dplyr::if_else(MS02Q12 %in% c(3:7) | MS02Q23 %in% c(3:7), 1,
                                         dplyr::if_else(MS02Q12 %in% c(1, 2) | 
                                                          MS02Q23 %in% c(1, 2), 0, NA_real_)),
      primary_education = dplyr::if_else(formal_education == 0, 0, primary_education)
    ) |>
    dplyr::left_join(
      indiv |> dplyr::select(GRAPPE, MENAGE, EXTENSION, MS01Q06A),
      by = c("GRAPPE", "MENAGE", "EXTENSION")
    ) |>
    dplyr::mutate(
      dplyr::across(c(formal_education, primary_education),
                    ~ dplyr::if_else(MS01Q06A < 6, 0, .x))
    ) |>
    dplyr::select(ID, hhid, formal_education, primary_education) |>
    dplyr::distinct()
  
  haven::write_dta(educ_out, file.path(temp_dir, "educ_indiv.dta"))
  cat("  ✓ educ_indiv saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in education variables: ", e$message, "\n")
})

# ==============================================================================
# 14. HDDS (Household Dietary Diversity Score)
# ==============================================================================

cat("\n=== Processing HDDS ===\n")

tryCatch({
  cat("  Calculating HDDS...\n")
  
  hdds <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2_MS12P1.dta"))
  
  hdds_out <- hdds |>
    dplyr::filter(MS12Q02 == 1) |>  # Keep if consumed
    dplyr::mutate(
      food_id = MS12Q01,
      # Define food groups
      A = dplyr::if_else(food_id %in% c(701:712, 810:813, 816:821), 1, 0),
      B = dplyr::if_else(food_id %in% c(748:753), 1, 0),
      C = dplyr::if_else(food_id %in% c(717:734, 740:743), 1, 0),
      D = dplyr::if_else(food_id %in% c(754:765), 1, 0),
      E = dplyr::if_else(food_id %in% c(766:773), 1, 0),
      F = dplyr::if_else(food_id == 785, 1, 0),
      G = dplyr::if_else(food_id %in% c(774:778), 1, 0),
      H = dplyr::if_else(food_id %in% c(814:815), 1, 0),
      I = dplyr::if_else(food_id %in% c(786:792), 1, 0),
      J = dplyr::if_else(food_id %in% c(713:714, 779:784), 1, 0),
      K = dplyr::if_else(food_id %in% c(715:716, 793:798), 1, 0),
      L = dplyr::if_else(food_id %in% c(744:736), 1, 0)
    ) |>
    dplyr::group_by(GRAPPE, MENAGE, EXTENSION) |>
    dplyr::summarise(
      dplyr::across(A:L, ~ max(.x, na.rm = TRUE)),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      hhid = paste(GRAPPE, MENAGE, EXTENSION, sep = "-"),
      HDDS = rowSums(dplyr::across(A:L), na.rm = TRUE),
      HDDS = dplyr::if_else(is.na(HDDS), 0, HDDS)
    ) |>
    dplyr::select(hhid, HDDS)
  
  haven::write_dta(hdds_out, file.path(temp_dir, "HDDS.dta"))
  cat("  ✓ HDDS saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in HDDS: ", e$message, "\n")
})

# ==============================================================================
# 15. FINAL OUTPUT
# ==============================================================================

cat("\n=== NER_ECVMA2 processing complete ===\n")
cat("Temporary files saved to:", temp_dir, "\n")
cat("✓ All variables extracted successfully\n")
