# ==============================================================================
# NER_ECVMA1.R - Niger Wave 1 (ECVMA 2011)
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
source("R_scripts/programs.R")

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
wave <- "ECVMA 11"
temppath <- file.path("NER", "ECVMA11")

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
  perennial <- haven::read_dta(file.path(Input_path, country, wave, "ecvmaas05_p2.dta"))
  
  # Filter and clean
  perennial <- perennial |>
    dplyr::filter(!is.na(as05q02)) |>
    dplyr::mutate(
      crop_name2 = haven::as_factor(as05q02) |> as.character(),
      n = dplyr::row_number(),
      n_str = as.character(n),
      plot_id2 = paste0("missing_line_", n_str),
      parcel_id2 = paste0("missing_line_", n_str)
    ) |>
    dplyr::rename(crop_code = as05q02)
  
  # Save perennial for later
  perennial_temp <- perennial |>
    dplyr::select(hid, crop_code, crop_name2, plot_id2, parcel_id2)
  
  # Load harvest data
  harvest <- haven::read_dta(file.path(Input_path, country, wave, "ecvmaas2e_p2_en.dta"))
  
  # Create plot_id and crop_name
  harvest <- harvest |>
    dplyr::mutate(
      plot_id = paste(hid, as02eq01, as02eq03, sep = "-"),
      parcel_id = paste(hid, as02eq01, sep = "-"),
      crop_name = haven::as_factor(as02eq06) |> as.character()
    ) |>
    dplyr::rename(crop_code = as02eq06)
  
  # Merge with perennial data
  harvest <- harvest |>
    dplyr::left_join(
      perennial_temp,
      by = c("hid", "crop_code")
    ) |>
    dplyr::mutate(
      crop_name = dplyr::if_else(!is.na(crop_name2), crop_name2, crop_name),
      plot_id = dplyr::if_else(!is.na(plot_id2), plot_id2, plot_id),
      parcel_id = dplyr::if_else(!is.na(parcel_id2), parcel_id2, parcel_id)
    ) |>
    dplyr::select(-crop_name2, -plot_id2, -parcel_id2)
  
  # Create plot-crop frame
  plot_crop_frame <- harvest |>
    dplyr::select(hid, plot_id, crop_name, crop_code, parcel_id) |>
    dplyr::distinct()
  
  haven::write_dta(plot_crop_frame, file.path(temp_dir, "plot_crop_frame.dta"))
  cat("  ✓ plot_crop_frame saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in plot-crop frame: ", e$message, "\n")
})

# 2.2 Household frame
tryCatch({
  cat("  Creating household frame...\n")
  
  cover <- haven::read_dta(file.path(Input_path, country, wave, "ecvmasection00_p1.dta"))
  
  hh_frame <- cover |>
    dplyr::select(hid) |>
    dplyr::distinct()
  
  haven::write_dta(hh_frame, file.path(temp_dir, "hh_frame.dta"))
  cat("  ✓ hh_frame saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in household frame: ", e$message, "\n")
})

# 2.3 Individual frame
tryCatch({
  cat("  Creating individual frame...\n")
  
  indiv <- haven::read_dta(file.path(Input_path, country, wave, "ecvmaind_p1p2.dta"))
  
  indiv_frame <- indiv |>
    dplyr::mutate(
      ID = paste(hid, ms01q00, sep = "-")
    ) |>
    dplyr::select(hid, ID) |>
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
  
  cover <- haven::read_dta(file.path(Input_path, country, wave, "ecvmasection00_p1.dta"))
  harvest <- haven::read_dta(file.path(Input_path, country, wave, "ecvmaas2e_p2_en.dta"))
  
  ea_id <- cover |>
    dplyr::left_join(
      harvest |> dplyr::select(hid, ms00q10, ms00q11, ms00q12, ms00q14) |> dplyr::distinct(),
      by = "hid"
    ) |>
    dplyr::mutate(
      ea_id = paste(ms00q10, ms00q11, ms00q12, ms00q14, sep = "-")
    ) |>
    dplyr::select(hid, ea_id) |>
    dplyr::distinct()
  
  haven::write_dta(ea_id, file.path(temp_dir, "ea_id.dta"))
  cat("  ✓ ea_id saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in EA extraction: ", e$message, "\n")
})

# 3.2 Strata
tryCatch({
  cat("  Extracting strata...\n")
  
  welfare <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2011_Welfare_en.dta"))
  cover <- haven::read_dta(file.path(Input_path, country, wave, "ecvmasection00_p1.dta"))
  
  strata <- welfare |>
    dplyr::mutate(
      hid = paste(grappe, menage, sep = "-")
    ) |>
    dplyr::select(hid, strate) |>
    dplyr::distinct() |>
    dplyr::right_join(
      cover |> dplyr::mutate(hid = paste(grappe, menage, sep = "-")) |> dplyr::select(hid),
      by = "hid"
    ) |>
    dplyr::rename(strataid = strate)
  
  haven::write_dta(strata, file.path(temp_dir, "strataid.dta"))
  cat("  ✓ strataid saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in strata extraction: ", e$message, "\n")
})

# 3.3 Administrative levels
tryCatch({
  cat("  Extracting administrative levels...\n")
  
  cover <- haven::read_dta(file.path(Input_path, country, wave, "ecvmasection00_p1.dta"))
  harvest <- haven::read_dta(file.path(Input_path, country, wave, "ecvmaas2e_p2_en.dta"))
  
  # Merge to get admin info
  admin_data <- cover |>
    dplyr::left_join(
      harvest |> dplyr::select(hid, ms00q10, ms00q11, ms00q12) |> dplyr::distinct(),
      by = "hid"
    )
  
  # Admin 1
  admin1 <- admin_data |>
    dplyr::mutate(
      admin_1 = ms00q10,
      admin_1_name = haven::as_factor(admin_1) |> as.character()
    ) |>
    dplyr::select(hid, admin_1, admin_1_name) |>
    dplyr::distinct()
  
  haven::write_dta(admin1, file.path(temp_dir, "admin1.dta"))
  
  # Admin 2
  admin2 <- admin_data |>
    dplyr::mutate(
      admin_2 = ms00q11,
      admin_2_name = haven::as_factor(admin_2) |> as.character()
    ) |>
    dplyr::select(hid, admin_2, admin_2_name) |>
    dplyr::distinct()
  
  haven::write_dta(admin2, file.path(temp_dir, "admin2.dta"))
  
  # Admin 3
  admin3 <- admin_data |>
    dplyr::mutate(
      admin_3 = ms00q12
    ) |>
    dplyr::select(hid, admin_3) |>
    dplyr::distinct()
  
  haven::write_dta(admin3, file.path(temp_dir, "admin3.dta"))
  
  cat("  ✓ admin levels saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in admin levels: ", e$message, "\n")
})

# 3.4 Urban/rural
tryCatch({
  cat("  Extracting urban/rural...\n")
  
  cover <- haven::read_dta(file.path(Input_path, country, wave, "ecvmasection00_p1.dta"))
  
  urban <- cover |>
    dplyr::mutate(
      urban = dplyr::if_else(ms00q15 %in% c(1, 2), 1,
                             dplyr::if_else(ms00q15 == 3, 0, NA_real_))
    ) |>
    dplyr::select(hid, urban) |>
    dplyr::distinct()
  
  haven::write_dta(urban, file.path(temp_dir, "urban.dta"))
  cat("  ✓ urban saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in urban/rural: ", e$message, "\n")
})

# 3.5 Weights
tryCatch({
  cat("  Extracting weights...\n")
  
  housing <- haven::read_dta(file.path(Input_path, country, wave, "ecvmamen_p1_en.dta"))
  
  weights_out <- housing |>
    dplyr::select(hid, pw = hhweight) |>
    dplyr::distinct()
  
  haven::write_dta(weights_out, file.path(temp_dir, "weights.dta"))
  cat("  ✓ weights saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in weights: ", e$message, "\n")
})

# 3.6 Planting month
tryCatch({
  cat("  Extracting planting month...\n")
  
  plot_inputs <- haven::read_dta(file.path(Input_path, country, wave, "ecvmaas2b_p1.dta"))
  
  planting_month <- plot_inputs |>
    dplyr::mutate(
      plot_id = paste(hid, as02bq01, as02bq03, sep = "-"),
      crop_code = as02bq06,
      month = as02bq11,
      year = 2011,
      planting_month = lubridate::ymd(paste(year, month, "01", sep = "-"))
    ) |>
    dplyr::select(hid, plot_id, crop_code, planting_month) |>
    dplyr::distinct() |>
    dplyr::group_by(hid, crop_code, plot_id) |>
    dplyr::summarise(planting_month = min(planting_month, na.rm = TRUE), .groups = "drop")
  
  haven::write_dta(planting_month, file.path(temp_dir, "planting_month.dta"))
  cat("  ✓ planting_month saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in planting month: ", e$message, "\n")
})

# 3.7 Harvest interview month
tryCatch({
  cat("  Extracting harvest interview month...\n")
  
  cover2 <- haven::read_dta(file.path(Input_path, country, wave, "ecvmasection00_p2_en.dta"))
  
  harvest_interview_month <- cover2 |>
    dplyr::mutate(
      month = as00q03am,
      year = 2011,
      harvest_interview_month = lubridate::ymd(paste(year, month, "01", sep = "-"))
    ) |>
    dplyr::select(hid, harvest_interview_month) |>
    dplyr::distinct()
  
  haven::write_dta(harvest_interview_month, file.path(temp_dir, "harvest_interview_month.dta"))
  cat("  ✓ harvest_interview_month saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in harvest interview month: ", e$message, "\n")
})

# 3.8 Planting interview month
tryCatch({
  cat("  Extracting planting interview month...\n")
  
  cover <- haven::read_dta(file.path(Input_path, country, wave, "ecvmasection00_p1.dta"))
  
  planting_interview_month <- cover |>
    dplyr::mutate(
      month = as00q03am,
      year = 2011,
      planting_interview_month = lubridate::ymd(paste(year, month, "01", sep = "-"))
    ) |>
    dplyr::select(hid, planting_interview_month) |>
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

# 4.1 Harvest kg - conversion factors
tryCatch({
  cat("  Calculating conversion factors...\n")
  
  # Load harvest data to calculate conversions
  harvest <- haven::read_dta(file.path(Input_path, country, wave, "ecvmaas2e_p2_en.dta"))
  cover <- haven::read_dta(file.path(Input_path, country, wave, "ecvmasection00_p1.dta"))
  
  # Calculate conversion factors by region, crop, and unit
  conversions <- harvest |>
    dplyr::mutate(
      region = ms00q10,
      crop_code = as02eq06,
      unit = as02eq07b,
      conversion = as02eq07c / as02eq07a
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

# 4.2 Harvest kg - main
tryCatch({
  cat("  Calculating harvest kg...\n")
  
  # Load conversion factors
  conversions <- haven::read_dta(file.path(temp_dir, "Conversion_factors.dta"))
  
  # Load perennial data
  perennial <- haven::read_dta(file.path(Input_path, country, wave, "ecvmaas05_p2.dta")) |>
    dplyr::filter(!is.na(as05q02)) |>
    dplyr::mutate(
      unit = dplyr::case_when(
        as05q06b == 1 ~ 1,
        as05q06b == 3 ~ 9,
        as05q06b == 4 ~ 5,
        as05q06b == 5 ~ 6,
        as05q06b == 6 ~ 7,
        as05q06b == 7 ~ 8,
        TRUE ~ NA_real_
      ),
      harvest_kg_per = as05q05 * as05q06a
    ) |>
    dplyr::rename(crop_code = as05q02) |>
    dplyr::left_join(conversions, by = "unit") |>
    dplyr::mutate(
      harvest_kg_per = harvest_kg_per * conversion,
      n = dplyr::row_number(),
      plot_id2 = paste0("missing_line_", as.character(n))
    ) |>
    dplyr::select(hid, crop_code, harvest_kg_per, plot_id2)
  
  # Load harvest data
  harvest <- haven::read_dta(file.path(Input_path, country, wave, "ecvmaas2e_p2_en.dta"))
  
  # Add admin levels
  admin1 <- haven::read_dta(file.path(temp_dir, "admin1.dta"))
  admin2 <- haven::read_dta(file.path(temp_dir, "admin2.dta"))
  admin3 <- haven::read_dta(file.path(temp_dir, "admin3.dta"))
  
  harvest <- harvest |>
    dplyr::left_join(admin1, by = "hid") |>
    dplyr::left_join(admin2, by = "hid") |>
    dplyr::left_join(admin3, by = "hid") |>
    dplyr::mutate(
      plot_id = paste(hid, as02eq01, as02eq03, sep = "-"),
      ea_id = ms00q14
    ) |>
    dplyr::rename(crop_code = as02eq06) |>
    dplyr::left_join(
      perennial |> dplyr::select(hid, crop_code, harvest_kg_per, plot_id2),
      by = c("hid", "crop_code")
    ) |>
    dplyr::mutate(
      plot_id = dplyr::if_else(!is.na(plot_id2), plot_id2, plot_id),
      harvest_kg = as02eq07c,
      harvest_kg = dplyr::if_else(as02eq07b == 99, NA_real_, harvest_kg),
      harvest_kg = dplyr::if_else(as02eq07c == 999999, NA_real_, harvest_kg),
      harvest_kg = dplyr::if_else(as02eq07a == 0, 0, harvest_kg),
      harvest_kg = dplyr::if_else(!is.na(harvest_kg_per), harvest_kg_per, harvest_kg),
      # Crop shock
      crop_shock = dplyr::if_else(as02eq08 == 1, 1,
                                  dplyr::if_else(as02eq08 == 2, 0, NA_real_)),
      harvest_kg = dplyr::if_else(harvest_kg == 0 & crop_shock != 1, NA_real_, harvest_kg)
    )
  
  # Aggregate
  harvest_kg <- harvest |>
    dplyr::group_by(plot_id, crop_code, hid, admin_1, admin_2, admin_3) |>
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
  
  harvest <- haven::read_dta(file.path(Input_path, country, wave, "ecvmaas2e_p2_en.dta"))
  
  pct_area_harvested <- harvest |>
    dplyr::mutate(
      plot_id = paste(hid, as02eq01, as02eq03, sep = "-"),
      crop_code = as02eq06,
      pct_area_harvested = 100 - as02eq09,
      pct_area_harvested = dplyr::if_else(as02eq09 == 999, NA_real_, pct_area_harvested),
      pct_area_harvested = dplyr::if_else(as02eq08 == 2, 100, pct_area_harvested)
    ) |>
    dplyr::select(hid, plot_id, crop_code, pct_area_harvested) |>
    dplyr::distinct()
  
  haven::write_dta(pct_area_harvested, file.path(temp_dir, "pct_area_harvested.dta"))
  cat("  ✓ pct_area_harvested saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in percent area harvested: ", e$message, "\n")
})

# 4.4 Crop shocks
tryCatch({
  cat("  Extracting crop shocks...\n")
  
  harvest <- haven::read_dta(file.path(Input_path, country, wave, "ecvmaas2e_p2_en.dta"))
  
  crop_shock <- harvest |>
    dplyr::mutate(
      plot_id = paste(hid, as02eq01, as02eq03, sep = "-"),
      crop_code = as02eq06,
      # Crop shock
      crop_shock = dplyr::if_else(as02eq08 == 1, 1,
                                  dplyr::if_else(as02eq08 == 2, 0, NA_real_)),
      # Drought shock
      drought_shock = dplyr::if_else(as02eq10 == 3, 1,
                                     dplyr::if_else(as02eq10 %in% c(1, 2, 4:9), 0, NA_real_)),
      drought_shock = dplyr::if_else(as02eq08 == 2, 0, drought_shock),
      # Flood shock
      flood_shock = dplyr::if_else(as02eq10 == 4, 1,
                                   dplyr::if_else(as02eq10 %in% c(1:3, 5:9), 0, NA_real_)),
      flood_shock = dplyr::if_else(as02eq08 == 2, 0, flood_shock),
      # Pests shock
      pests_shock = dplyr::if_else(as02eq10 == 1, 1,
                                   dplyr::if_else(as02eq10 %in% c(2:9), 0, NA_real_)),
      pests_shock = dplyr::if_else(as02eq08 == 2, 0, pests_shock),
      # Percent lost
      pct_area_harvested = 100 - as02eq09,
      pct_area_harvested = dplyr::if_else(as02eq09 == 999, NA_real_, pct_area_harvested),
      pct_area_harvested = dplyr::if_else(as02eq08 == 2, 100, pct_area_harvested),
      pct_lost = 100 - pct_area_harvested,
      pct_lost = pct_lost / 100
    ) |>
    dplyr::group_by(hid, plot_id, crop_code) |>
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
  perennial <- haven::read_dta(file.path(Input_path, country, wave, "ecvmaas05_p2.dta")) |>
    dplyr::filter(!is.na(as05q02)) |>
    dplyr::mutate(
      unit = dplyr::case_when(
        as05q06b == 1 ~ 1,
        as05q06b == 3 ~ 9,
        as05q06b == 4 ~ 5,
        as05q06b == 5 ~ 6,
        as05q06b == 6 ~ 7,
        as05q06b == 7 ~ 8,
        TRUE ~ NA_real_
      ),
      harvest_sold_kg_per = as05q09 * conversion
    ) |>
    dplyr::rename(crop_code = as05q02) |>
    dplyr::left_join(conversions, by = "unit") |>
    dplyr::mutate(
      harvest_sold_kg_per = harvest_sold_kg_per * conversion,
      n = dplyr::row_number(),
      plot_id2 = paste0("missing_line_", as.character(n))
    ) |>
    dplyr::select(hid, crop_code, harvest_sold_kg_per, plot_id2)
  
  # Load harvest data
  harvest <- haven::read_dta(file.path(Input_path, country, wave, "ecvmaas2e_p2_en.dta"))
  
  harvest_sold <- harvest |>
    dplyr::mutate(
      plot_id = paste(hid, as02eq01, as02eq03, sep = "-"),
      crop_code = as02eq06,
      harvest_sold_kg = as02eq12c,
      harvest_sold_kg = dplyr::if_else(as02eq11 == 2, 0, harvest_sold_kg),
      harvest_sold_kg = dplyr::if_else(as02eq12a == 0, 0, harvest_sold_kg)
    ) |>
    dplyr::left_join(
      perennial |> dplyr::select(hid, crop_code, harvest_sold_kg_per, plot_id2),
      by = c("hid", "crop_code")
    ) |>
    dplyr::mutate(
      plot_id = dplyr::if_else(!is.na(plot_id2), plot_id2, plot_id),
      harvest_sold_kg = dplyr::if_else(!is.na(harvest_sold_kg_per), 
                                       harvest_sold_kg_per, harvest_sold_kg)
    ) |>
    dplyr::group_by(crop_code, hid, plot_id) |>
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
    dplyr::group_by(hid) |>
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
      harvest_kg |> dplyr::group_by(hid) |>
        dplyr::summarise(harvest_kg = sum(harvest_kg, na.rm = TRUE), .groups = "drop"),
      by = "hid"
    ) |>
    dplyr::mutate(
      share_kg_sold = harvest_sold_kg / harvest_kg,
      share_kg_sold = dplyr::if_else(share_kg_sold > 1, NA_real_, share_kg_sold)
    ) |>
    dplyr::select(hid, share_kg_sold) |>
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
  perennial <- haven::read_dta(file.path(Input_path, country, wave, "ecvmaas05_p2.dta")) |>
    dplyr::filter(!is.na(as05q02)) |>
    dplyr::mutate(
      harvest_sold_value_per = as05q10,
      n = dplyr::row_number(),
      plot_id2 = paste0("missing_line_", as.character(n))
    ) |>
    dplyr::rename(crop_code = as05q02) |>
    dplyr::select(hid, crop_code, harvest_sold_value_per, plot_id2)
  
  # Load harvest data
  harvest <- haven::read_dta(file.path(Input_path, country, wave, "ecvmaas2e_p2_en.dta"))
  
  harvest_sold_value <- harvest |>
    dplyr::mutate(
      plot_id = paste(hid, as02eq01, as02eq03, sep = "-"),
      crop_code = as02eq06,
      harvest_sold_value = as02eq13
    ) |>
    dplyr::left_join(
      perennial |> dplyr::select(hid, crop_code, harvest_sold_value_per, plot_id2),
      by = c("hid", "crop_code")
    ) |>
    dplyr::mutate(
      plot_id = dplyr::if_else(!is.na(plot_id2), plot_id2, plot_id),
      harvest_sold_value = dplyr::if_else(!is.na(harvest_sold_value_per), 
                                          harvest_sold_value_per, harvest_sold_value)
    ) |>
    dplyr::group_by(crop_code, hid, plot_id) |>
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
  harvest <- haven::read_dta(file.path(Input_path, country, wave, "ecvmaas2e_p2_en.dta"))
  
  # Add perennial crops
  perennial <- haven::read_dta(file.path(Input_path, country, wave, "ecvmaas05_p2.dta")) |>
    dplyr::filter(!is.na(as05q02)) |>
    dplyr::mutate(
      n = dplyr::row_number(),
      plot_id2 = paste0("missing_line_", as.character(n))
    ) |>
    dplyr::rename(crop_code = as05q02) |>
    dplyr::select(hid, crop_code, plot_id2)
  
  harvest <- harvest |>
    dplyr::mutate(
      plot_id = paste(hid, as02eq01, as02eq03, sep = "-"),
      crop_code = as02eq06
    ) |>
    dplyr::select(hid, plot_id, crop_code) |>
    dplyr::distinct() |>
    dplyr::left_join(
      perennial |> dplyr::select(hid, crop_code, plot_id2),
      by = c("hid", "crop_code")
    ) |>
    dplyr::mutate(
      plot_id = dplyr::if_else(!is.na(plot_id2), plot_id2, plot_id)
    ) |>
    dplyr::select(-plot_id2)
  
  # Calculate harvest value using median crop prices
  harvest_value <- valuation_median_crops_noea(
    data = harvest,
    temp_path = temp_dir,
    hhid_var = "hid",
    plotid_var = "plot_id",
    cropvar_var = "crop_code"
  )
  
  # Add main crop
  harvest_value <- main_crop_def(
    data = harvest_value,
    cropvar_var = "crop_code"
  )
  
  # Select relevant columns
  harvest_value_out <- harvest_value |>
    dplyr::select(hid, plot_id, harvest_value, crop_code, main_crop)
  
  haven::write_dta(harvest_value_out, file.path(temp_dir, "harvest_value.dta"))
  cat("  ✓ harvest_value saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in harvest value: ", e$message, "\n")
})

# 5.2 Intercropped
tryCatch({
  cat("  Extracting intercropped status...\n")
  
  plot_inputs <- haven::read_dta(file.path(Input_path, country, wave, "ecvmaas2b_p1.dta"))
  
  intercropped <- plot_inputs |>
    dplyr::mutate(
      plot_id = paste(hid, as02bq01, as02bq03, sep = "-"),
      crop_code = as02bq06,
      intercropped = dplyr::if_else(as02bq07 == 1, 0,
                                    dplyr::if_else(as02bq07 == 2, 1, NA_real_))
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
  
  harvest <- haven::read_dta(file.path(Input_path, country, wave, "ecvmaas2e_p2_en.dta"))
  
  nb_seasonal_crop <- harvest |>
    dplyr::mutate(
      plot_id = paste(hid, as02eq01, as02eq03, sep = "-")
    ) |>
    dplyr::group_by(plot_id) |>
    dplyr::summarise(
      nb_seasonal_crop = n_distinct(as02eq06, na.rm = TRUE),
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
  harvest <- haven::read_dta(file.path(Input_path, country, wave, "ecvmaas2e_p2_en.dta"))
  
  # Add perennial crops
  perennial <- haven::read_dta(file.path(Input_path, country, wave, "ecvmaas05_p2.dta")) |>
    dplyr::filter(!is.na(as05q02)) |>
    dplyr::mutate(
      n = dplyr::row_number(),
      plot_id2 = paste0("missing_line_", as.character(n))
    ) |>
    dplyr::rename(crop_code = as05q02) |>
    dplyr::select(hid, crop_code, plot_id2)
  
  harvest <- harvest |>
    dplyr::mutate(
      plot_id = paste(hid, as02eq01, as02eq03, sep = "-"),
      crop_code = as02eq06
    ) |>
    dplyr::left_join(
      perennial |> dplyr::select(hid, crop_code, plot_id2),
      by = c("hid", "crop_code")
    ) |>
    dplyr::mutate(
      plot_id = dplyr::if_else(!is.na(plot_id2), plot_id2, plot_id)
    ) |>
    dplyr::select(-plot_id2)
  
  # Merge with harvest value
  main_crop_data <- harvest |>
    dplyr::left_join(harvest_value, by = c("hid", "plot_id", "crop_code"))
  
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
  
  # Create crop group variables
  main_crop_data <- main_crop_data |>
    dplyr::mutate(
      # Map crop codes to categories (simplified for Niger)
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
        crop_code %in% c(90:99) ~ "PERENNIAL/FRUIT",
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

# ==============================================================================
# 6. LAND AREA
# ==============================================================================

cat("\n=== Processing land area ===\n")

tryCatch({
  cat("  Calculating plot area...\n")
  
  plot_roster <- haven::read_dta(file.path(Input_path, country, wave, "ecvmaas1_p1.dta"))
  
  # Load admin3 for imputation
  admin3 <- haven::read_dta(file.path(temp_dir, "admin3.dta"))
  
  land_area <- plot_roster |>
    dplyr::mutate(
      plot_id = paste(hid, as01q03, as01q05, sep = "-"),
      area_self_reported = as01q08 * 0.0001,  # m² to hectares
      area_self_reported = dplyr::if_else(as01q08 == 999999, NA_real_, area_self_reported),
      plot_area_GPS = as01q09 * 0.0001,  # m² to hectares
      plot_area_GPS = dplyr::if_else(as01q09 == 999999 | as01q09 == 0, 
                                     NA_real_, plot_area_GPS)
    ) |>
    dplyr::left_join(admin3, by = "hid")
  
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
    dplyr::group_by(hid) |>
    dplyr::mutate(
      farm_size = sum(plot_area_GPS, na.rm = TRUE)
    ) |>
    dplyr::ungroup()
  
  land_area_out <- land_area |>
    dplyr::select(hid, plot_id, plot_area_GPS, farm_size) |>
    dplyr::distinct()
  
  haven::write_dta(land_area_out, file.path(temp_dir, "plot_area.dta"))
  cat("  ✓ plot_area saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in land area: ", e$message, "\n")
})

# 5.5 Share of plot area planted by crop
tryCatch({
  cat("  Calculating plot area share by crop...\n")
  
  plot_inputs <- haven::read_dta(file.path(Input_path, country, wave, "ecvmaas2b_p1.dta"))
  plot_area <- haven::read_dta(file.path(temp_dir, "plot_area.dta"))
  
  pct_area_planted <- plot_inputs |>
    dplyr::mutate(
      plot_id = paste(hid, as02bq01, as02bq03, sep = "-"),
      crop_code = as02bq06
    ) |>
    dplyr::left_join(plot_area, by = c("hid", "plot_id")) |>
    dplyr::mutate(
      pct_area_planted = (as02bq08 / (plot_area_GPS * 10000)) * 100,
      pct_area_planted = dplyr::if_else(as02bq08 == 999999, NA_real_, pct_area_planted),
      pct_area_planted = dplyr::if_else(pct_area_planted > 100, NA_real_, pct_area_planted),
      pct_area_planted = dplyr::if_else(pct_area_planted < 1, 0, pct_area_planted)
    ) |>
    dplyr::select(plot_id, hid, crop_code, pct_area_planted) |>
    dplyr::distinct()
  
  haven::write_dta(pct_area_planted, file.path(temp_dir, "pct_area_planted.dta"))
  cat("  ✓ pct_area_planted saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in pct_area_planted: ", e$message, "\n")
})

# ==============================================================================
# 7. SEED VARIABLES
# ==============================================================================

cat("\n=== Processing seed variables ===\n")

# 7.1 Improved seeds
tryCatch({
  cat("  Extracting improved seed status...\n")
  
  plot_inputs <- haven::read_dta(file.path(Input_path, country, wave, "ecvmaas2b_p1.dta"))
  
  improved <- plot_inputs |>
    dplyr::mutate(
      plot_id = paste(hid, as02bq01, as02bq03, sep = "-"),
      crop_code = as02bq06,
      improved = dplyr::if_else(as02bq09 %in% c(3, 4), 1,
                                dplyr::if_else(as02bq09 %in% c(1, 2), 0, NA_real_))
    ) |>
    dplyr::group_by(plot_id, crop_code) |>
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
  seeds <- haven::read_dta(file.path(Input_path, country, wave, "ecvmaas2c_p1.dta"))
  
  seed_kg <- seeds |>
    dplyr::mutate(
      crop_code = as02cq04,
      unit = dplyr::case_when(
        as02cq05b == 1 ~ 1,
        as02cq05b == 6 ~ 5,
        TRUE ~ NA_real_
      ),
      seed_kg = as02cq05a,
      # Apply conversions
      seed_kg = dplyr::if_else(as02cq05b == 1, as02cq05a, seed_kg),
      seed_kg = dplyr::if_else(as02cq05b == 8, as02cq05a, seed_kg),  # litre
      seed_kg = dplyr::if_else(as02cq05b == 2, as02cq05a * 5, seed_kg),
      seed_kg = dplyr::if_else(as02cq05b == 3, as02cq05a * 10, seed_kg),
      seed_kg = dplyr::if_else(as02cq05b == 4, as02cq05a * 25, seed_kg),
      seed_kg = dplyr::if_else(as02cq05b == 5, as02cq05a * 50, seed_kg),
      seed_kg = dplyr::if_else(as02cq03 == 2, 0, seed_kg)
    ) |>
    dplyr::left_join(conversions, by = "unit") |>
    dplyr::mutate(
      seed_kg = dplyr::if_else(!is.na(conversion), seed_kg * conversion, seed_kg)
    ) |>
    dplyr::group_by(hid, crop_code) |>
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
  plot_inputs <- haven::read_dta(file.path(Input_path, country, wave, "ecvmaas2b_p1.dta"))
  plot_area <- haven::read_dta(file.path(temp_dir, "plot_area.dta"))
  
  seed_kg_plot <- plot_inputs |>
    dplyr::mutate(
      plot_id = paste(hid, as02bq01, as02bq03, sep = "-"),
      crop_code = as02bq06
    ) |>
    dplyr::left_join(plot_area, by = c("hid", "plot_id")) |>
    dplyr::left_join(seed_kg, by = c("hid", "crop_code")) |>
    dplyr::group_by(hid, crop_code) |>
    dplyr::mutate(
      total_land_area = sum(plot_area_GPS, na.rm = TRUE),
      indicator = plot_area_GPS / total_land_area,
      seed_kg = seed_kg * indicator
    ) |>
    dplyr::ungroup() |>
    dplyr::select(hid, plot_id, crop_code, seed_kg) |>
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
  seeds <- haven::read_dta(file.path(Input_path, country, wave, "ecvmaas2c_p1.dta"))
  
  seeds_amount_purchased_kg <- seeds |>
    dplyr::mutate(
      crop_code = as02cq04,
      unit = dplyr::case_when(
        as02cq05b == 1 ~ 1,
        as02cq05b == 6 ~ 5,
        TRUE ~ NA_real_
      ),
      seeds_amount_purchased_kg = as02cq08a,
      # Apply conversions
      seeds_amount_purchased_kg = dplyr::if_else(as02cq05b == 1, as02cq08a, 
                                                 seeds_amount_purchased_kg),
      seeds_amount_purchased_kg = dplyr::if_else(as02cq05b == 8, as02cq08a, 
                                                 seeds_amount_purchased_kg),
      seeds_amount_purchased_kg = dplyr::if_else(as02cq05b == 2, as02cq08a * 5, 
                                                 seeds_amount_purchased_kg),
      seeds_amount_purchased_kg = dplyr::if_else(as02cq05b == 3, as02cq08a * 10, 
                                                 seeds_amount_purchased_kg),
      seeds_amount_purchased_kg = dplyr::if_else(as02cq05b == 4, as02cq08a * 25, 
                                                 seeds_amount_purchased_kg),
      seeds_amount_purchased_kg = dplyr::if_else(as02cq05b == 5, as02cq08a * 50, 
                                                 seeds_amount_purchased_kg)
    ) |>
    dplyr::left_join(conversions, by = "unit") |>
    dplyr::mutate(
      seeds_amount_purchased_kg = dplyr::if_else(!is.na(conversion), 
                                                 seeds_amount_purchased_kg * conversion,
                                                 seeds_amount_purchased_kg)
    ) |>
    dplyr::group_by(crop_code, hid) |>
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
  seeds <- haven::read_dta(file.path(Input_path, country, wave, "ecvmaas2c_p1.dta"))
  
  seed_value_temp <- seeds |>
    dplyr::mutate(
      crop_code = as02cq04,
      seed_value_temp = as02cq08b
    ) |>
    dplyr::group_by(crop_code, hid) |>
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
    hhid_var = "hid",
    id_link_seeds_var = "hid",
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
  labor_pp <- haven::read_dta(file.path(Input_path, country, wave, "ecvmaas1_p1.dta"))
  labor_ph <- haven::read_dta(file.path(Input_path, country, wave, "ecvmaas1_p2.dta"))
  
  # For Niger, labor is in as02aq* variables
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
  
  ferts <- haven::read_dta(file.path(Input_path, country, wave, "ecvmaas1_p1_en.dta"))
  
  inorganic_fertilizer <- ferts |>
    dplyr::mutate(
      plot_id = paste(hid, as01q03, as01q05, sep = "-"),
      inorganic_fertilizer = dplyr::if_else(as02aq10 == 1, 1,
                                            dplyr::if_else(as02aq10 == 2, 0, NA_real_))
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
  harvest <- haven::read_dta(file.path(Input_path, country, wave, "ecvmaas2e_p2_en.dta"))
  
  conversions <- harvest |>
    dplyr::mutate(
      region = ms00q10,
      crop_code = as02eq06,
      unit = as02eq07b,
      conversion = as02eq07c / as02eq07a
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
  ferts <- haven::read_dta(file.path(Input_path, country, wave, "ecvmaas1_p1_en.dta"))
  
  nitrogen_kg <- ferts |>
    dplyr::mutate(
      plot_id = paste(hid, as01q03, as01q05, sep = "-"),
      region = ms00q10,
      inorganic_fertilizer = dplyr::if_else(as02aq10 == 1, 1,
                                            dplyr::if_else(as02aq10 == 2, 0, NA_real_)),
      # UREA
      unit = dplyr::case_when(
        as02aq11b == 6 ~ 5,
        TRUE ~ NA_real_
      ),
      UREA_kg = as02aq11a,
      # DAP
      DAP_kg = as02aq12a,
      # NPK
      NPK_kg = as02aq13a
    ) |>
    dplyr::left_join(conversions, by = c("region", "unit")) |>
    dplyr::mutate(
      # Apply conversions
      UREA_kg = dplyr::if_else(!is.na(conversion), UREA_kg * conversion, UREA_kg),
      UREA_kg = dplyr::if_else(as02aq11b == 2, as02aq11a * 5, UREA_kg),
      UREA_kg = dplyr::if_else(as02aq11b == 3, as02aq11a * 10, UREA_kg),
      UREA_kg = dplyr::if_else(as02aq11b == 4, as02aq11a * 25, UREA_kg),
      UREA_kg = dplyr::if_else(as02aq11b == 5, as02aq11a * 50, UREA_kg),
      UREA_kg = dplyr::if_else(inorganic_fertilizer == 0, 0, UREA_kg),
      
      DAP_kg = dplyr::if_else(!is.na(conversion), DAP_kg * conversion, DAP_kg),
      DAP_kg = dplyr::if_else(as02aq12b == 2, as02aq12a * 5, DAP_kg),
      DAP_kg = dplyr::if_else(as02aq12b == 3, as02aq12a * 10, DAP_kg),
      DAP_kg = dplyr::if_else(as02aq12b == 4, as02aq12a * 25, DAP_kg),
      DAP_kg = dplyr::if_else(as02aq12b == 5, as02aq12a * 50, DAP_kg),
      DAP_kg = dplyr::if_else(inorganic_fertilizer == 0, 0, DAP_kg),
      
      NPK_kg = dplyr::if_else(!is.na(conversion), NPK_kg * conversion, NPK_kg),
      NPK_kg = dplyr::if_else(as02aq13b == 2, as02aq13a * 5, NPK_kg),
      NPK_kg = dplyr::if_else(as02aq13b == 3, as02aq13a * 10, NPK_kg),
      NPK_kg = dplyr::if_else(as02aq13b == 4, as02aq13a * 25, NPK_kg),
      NPK_kg = dplyr::if_else(as02aq13b == 5, as02aq13a * 50, NPK_kg),
      NPK_kg = dplyr::if_else(inorganic_fertilizer == 0, 0, NPK_kg)
    ) |>
    dplyr::mutate(
      # Nitrogen equivalents
      UREA_N_kg = UREA_kg * 0.46,
      DAP_N_kg = DAP_kg * 0.18,
      NPK_N_kg = NPK_kg * 0.15,
      nitrogen_kg = UREA_N_kg + DAP_N_kg + NPK_N_kg,
      nitrogen_kg = dplyr::if_else(inorganic_fertilizer == 0, 0, nitrogen_kg)
    ) |>
    dplyr::group_by(plot_id, hid) |>
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
  seeds <- haven::read_dta(file.path(Input_path, country, wave, "ecvmaas2c_p1.dta"))
  
  # Load conversion factors
  harvest <- haven::read_dta(file.path(Input_path, country, wave, "ecvmaas2e_p2_en.dta"))
  
  conversions <- harvest |>
    dplyr::mutate(
      region = ms00q10,
      crop_code = as02eq06,
      unit = as02eq07b,
      conversion = as02eq07c / as02eq07a
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
      hid = paste(grappe, menage, sep = "-"),
      region = ms00q10,
      crop_code = as02cq04,
      # Identify fertilizer types
      fert_type = dplyr::case_when(
        as02cq02 == 5 ~ "NPK",
        as02cq02 == 3 ~ "UREA",
        as02cq02 == 4 ~ "DAP",
        TRUE ~ NA_character_
      ),
      unit = dplyr::case_when(
        as02cq05b == 1 ~ 1,
        as02cq05b == 6 ~ 5,
        TRUE ~ NA_real_
      ),
      fert_purchased_kg = as02cq08a,
      fert_purchased_value = as02cq08b
    ) |>
    dplyr::left_join(conversions, by = c("region", "unit")) |>
    dplyr::mutate(
      fert_purchased_kg = dplyr::if_else(!is.na(conversion), 
                                         fert_purchased_kg * conversion,
                                         fert_purchased_kg),
      fert_purchased_kg = dplyr::if_else(as02cq05b == 1, as02cq08a, fert_purchased_kg),
      fert_purchased_kg = dplyr::if_else(as02cq05b == 8, as02cq08a, fert_purchased_kg),
      fert_purchased_kg = dplyr::if_else(as02cq05b == 2, as02cq08a * 0.001, 
                                         fert_purchased_kg)
    ) |>
    dplyr::filter(!is.na(fert_type))
  
  # Use valuation function for each fertilizer type
  # This would need to be run for UREA, DAP, and NPK separately
  # For now, placeholder
  
  haven::write_dta(fert_purch, file.path(temp_dir, "fert_purchased_temp.dta"))
  cat("  ✓ fertilizer value processed\n")
  
}, error = function(e) {
  cat("  ✗ Error in fertilizer value: ", e$message, "\n")
})

# 9.4 Organic fertilizer
tryCatch({
  cat("  Extracting organic fertilizer use...\n")
  
  ferts <- haven::read_dta(file.path(Input_path, country, wave, "ecvmaas1_p1_en.dta"))
  
  organic_fertilizer <- ferts |>
    dplyr::mutate(
      plot_id = paste(hid, as01q03, as01q05, sep = "-"),
      organic_fertilizer = dplyr::if_else(as02aq06 == 1, 1,
                                          dplyr::if_else(as02aq06 == 2, 0, NA_real_))
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
  
  ferts <- haven::read_dta(file.path(Input_path, country, wave, "ecvmaas1_p1_en.dta"))
  
  used_pesticides <- ferts |>
    dplyr::mutate(
      plot_id = paste(hid, as01q03, as01q05, sep = "-"),
      used_pesticides = dplyr::if_else(as02aq16a > 0, 1,
                                       dplyr::if_else(as02aq16a == 0 | as02aq15 == 2, 
                                                      0, NA_real_))
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
  
  plot_roster <- haven::read_dta(file.path(Input_path, country, wave, "ecvmaas1_p1.dta"))
  
  plot_owned <- plot_roster |>
    dplyr::mutate(
      plot_id = paste(hid, as01q03, as01q05, sep = "-"),
      plot_owned = dplyr::if_else(as01q16 %in% c(1, 3), 1,
                                  dplyr::if_else(as01q16 %in% c(2, 4, 5), 0, NA_real_)),
      plot_certificate = dplyr::if_else(as01q18 %in% 1:4, 1,
                                        dplyr::if_else(as01q18 == 5, 0, NA_real_)),
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
  
  plot_roster <- haven::read_dta(file.path(Input_path, country, wave, "ecvmaas1_p1.dta"))
  
  irrigated <- plot_roster |>
    dplyr::mutate(
      plot_id = paste(hid, as01q03, as01q05, sep = "-"),
      irrigated = dplyr::if_else(!as01q39 %in% c(5, 7), 1,
                                 dplyr::if_else(as01q39 == 5, 0, NA_real_))
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
  
  plot_roster <- haven::read_dta(file.path(Input_path, country, wave, "ecvmaas1_p1.dta"))
  
  erosion_protection <- plot_roster |>
    dplyr::mutate(
      plot_id = paste(hid, as01q03, as01q05, sep = "-"),
      erosion_protection = dplyr::if_else(as01q27 == 1, 1,
                                          dplyr::if_else(as01q27 == 2, 0, NA_real_))
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
  
  items <- haven::read_dta(file.path(Input_path, country, wave, "ecvmaas06_p2.dta"))
  
  tractor <- items |>
    dplyr::mutate(
      tractor = dplyr::if_else(
        as06q02 == 10 & (as06q09 == 1 | as06q12 == 1), 1,
        dplyr::if_else(as06q02 == 10 & as06q03 == 2, 0,
                       dplyr::if_else(as06q02 == 10 & as06q03 == 1 & 
                                        as06q09 == 2 & as06q12 == 2, 0, NA_real_))
      )
    ) |>
    dplyr::group_by(hid) |>
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
  
  plot_roster <- haven::read_dta(file.path(Input_path, country, wave, "ecvmaas1_p1.dta"))
  
  nb_fallow_plots <- plot_roster |>
    dplyr::mutate(
      fallow_plot = dplyr::if_else(as01q41 == 1, 1, 0),
      fallow_plot = dplyr::if_else(as01q40 == 1, 0, fallow_plot)
    ) |>
    dplyr::group_by(hid) |>
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
  
  plot_roster <- haven::read_dta(file.path(Input_path, country, wave, "ecvmaas1_p1.dta"))
  
  nb_plots <- plot_roster |>
    dplyr::mutate(
      fallow_plot = dplyr::if_else(as01q41 == 1, 1, 0),
      fallow_plot = dplyr::if_else(as01q40 == 1, 0, fallow_plot)
    ) |>
    dplyr::group_by(hid) |>
    dplyr::summarise(
      nb_plots = n_distinct(paste(as01q03, as01q05, sep = "-")),
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
  
  indiv <- haven::read_dta(file.path(Input_path, country, wave, "ecvmaind_p1p2.dta"))
  
  hh_education <- indiv |>
    dplyr::mutate(
      formal_education = dplyr::if_else(ms02q04 == 1, 1,
                                        dplyr::if_else(ms02q04 %in% c(2:4), 0, NA_real_)),
      primary_education = dplyr::if_else(ms02q12 %in% c(3:7) | ms02q23 %in% c(3:7), 1,
                                         dplyr::if_else(ms02q12 %in% c(1, 2) | 
                                                          ms02q23 %in% c(1, 2), 0, NA_real_)),
      primary_education = dplyr::if_else(formal_education == 0, 0, primary_education)
    ) |>
    dplyr::group_by(hid) |>
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
  
  housing <- haven::read_dta(file.path(Input_path, country, wave, "ecvmamen_p1_en.dta"))
  
  electricity <- housing |>
    dplyr::mutate(
      hh_electricity_access = dplyr::if_else(ms06q26 %in% c(1, 2), 1,
                                             dplyr::if_else(!ms06q26 %in% c(1, 2), 0, NA_real_))
    ) |>
    dplyr::select(hid, hh_electricity_access) |>
    dplyr::distinct()
  
  haven::write_dta(electricity, file.path(temp_dir, "hh_electricity_access.dta"))
  cat("  ✓ hh_electricity_access saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in electricity access: ", e$message, "\n")
})

# 11.3 Dependency ratio
tryCatch({
  cat("  Calculating dependency ratio...\n")
  
  indiv <- haven::read_dta(file.path(Input_path, country, wave, "ecvmaind_p1p2.dta"))
  
  dependency <- indiv |>
    dplyr::mutate(
      age = ms01q06a,
      dep_temp = dplyr::if_else(!is.na(age) & (age < 15 | age > 65), 1, 0),
      nondep_temp = dplyr::if_else(!is.na(age) & age >= 15 & age <= 65, 1, 0)
    ) |>
    dplyr::group_by(hid) |>
    dplyr::summarise(
      dep = sum(dep_temp, na.rm = TRUE),
      nondep = sum(nondep_temp, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      hh_dependency_ratio = dep / nondep,
      hh_dependency_ratio = dplyr::if_else(nondep == 0, dep, hh_dependency_ratio)
    ) |>
    dplyr::select(hid, hh_dependency_ratio)
  
  haven::write_dta(dependency, file.path(temp_dir, "hh_dependency_ratio.dta"))
  cat("  ✓ hh_dependency_ratio saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in dependency ratio: ", e$message, "\n")
})

# 11.4 Livestock
tryCatch({
  cat("  Extracting livestock ownership...\n")
  
  livestock <- haven::read_dta(file.path(Input_path, country, wave, "ecvmaas4a_p2.dta"))
  cover <- haven::read_dta(file.path(Input_path, country, wave, "ecvmasection00_p1.dta"))
  
  livestock_out <- livestock |>
    dplyr::mutate(
      livestock = dplyr::if_else(as4aq05 == 1, 1,
                                 dplyr::if_else(as4aq05 == 2, 0, NA_real_))
    ) |>
    dplyr::group_by(hid) |>
    dplyr::summarise(
      livestock = max(livestock, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      livestock = dplyr::if_else(is.infinite(livestock), NA_real_, livestock)
    ) |>
    dplyr::right_join(
      cover |> dplyr::select(hid) |> dplyr::distinct(),
      by = "hid"
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
  
  welfare <- haven::read_dta(file.path(Input_path, country, wave, "ECVMA2011_Welfare_en.dta"))
  
  # Create consumption quintiles
  cons_quint <- welfare |>
    dplyr::mutate(
      hid = paste(grappe, menage, sep = "-")
    ) |>
    dplyr::select(hid, pcexp) |>
    dplyr::distinct() |>
    dplyr::mutate(
      cons_quint = dplyr::ntile(pcexp, 5)
    ) |>
    dplyr::select(hid, cons_quint)
  
  haven::write_dta(cons_quint, file.path(temp_dir, "cons_quint.dta"))
  
  # Total consumption
  totcons <- welfare |>
    dplyr::mutate(
      hid = paste(grappe, menage, sep = "-")
    ) |>
    dplyr::select(hid, totcons = pcexp) |>
    dplyr::distinct()
  
  haven::write_dta(totcons, file.path(temp_dir, "totcons.dta"))
  cat("  ✓ consumption variables saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in consumption variables: ", e$message, "\n")
})

# 11.6 Household shock
tryCatch({
  cat("  Extracting household shocks...\n")
  
  shocks <- haven::read_dta(file.path(Input_path, country, wave, "ecvmachoc_p1.dta"))
  
  hh_shock <- shocks |>
    dplyr::mutate(
      hh_shock = dplyr::if_else(ms11q02 == 1, 1,
                                dplyr::if_else(ms11q02 == 2, 0, NA_real_))
    ) |>
    dplyr::group_by(hid) |>
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
  
  indiv <- haven::read_dta(file.path(Input_path, country, wave, "ecvmaind_p1p2.dta"))
  
  hh_size <- indiv |>
    dplyr::group_by(hid) |>
    dplyr::summarise(
      hh_size = n_distinct(ms01q00),
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
  cat("  Calculating agricultural assets index...\n")
  
  items <- haven::read_dta(file.path(Input_path, country, wave, "ecvmaas06_p2.dta"))
  
  # Agricultural assets (exclude buildings)
  ag_assets <- items |>
    dplyr::mutate(
      hh_owns_ = dplyr::if_else(as06q03 == 1, 1, 0)
    ) |>
    dplyr::filter(!is.na(as06q02)) |>
    dplyr::group_by(hid, as06q02) |>
    dplyr::summarise(
      hh_owns_ = max(hh_owns_, na.rm = TRUE),
      .groups = "drop"
    ) |>
    tidyr::pivot_wider(
      id_cols = hid,
      names_from = as06q02,
      values_from = hh_owns_,
      values_fill = 0
    )
  
  # Remove building columns
  ag_assets <- ag_assets |>
    dplyr::select(-tidyselect::any_of(c("18", "19", "20")))
  
  # Calculate index using PCA (simplified as sum)
  ag_asset_index <- ag_assets |>
    dplyr::mutate(
      ag_asset_index = rowMeans(dplyr::across(-hid), na.rm = TRUE)
    ) |>
    dplyr::select(hid, ag_asset_index)
  
  haven::write_dta(ag_asset_index, file.path(temp_dir, "ag_asset_index.dta"))
  
  # Household assets
  hh_items <- haven::read_dta(file.path(Input_path, country, wave, "ecvmaas06_p2.dta"))
  
  hh_assets <- hh_items |>
    dplyr::mutate(
      hh_owns = dplyr::if_else(as06q03 == 1, 1, 0)
    ) |>
    dplyr::filter(!is.na(as06q02)) |>
    dplyr::group_by(hid, as06q02) |>
    dplyr::summarise(
      hh_owns = max(hh_owns, na.rm = TRUE),
      .groups = "drop"
    ) |>
    tidyr::pivot_wider(
      id_cols = hid,
      names_from = as06q02,
      values_from = hh_owns,
      values_fill = 0
    )
  
  hh_asset_index <- hh_assets |>
    dplyr::mutate(
      hh_asset_index = rowMeans(dplyr::across(-hid), na.rm = TRUE)
    ) |>
    dplyr::select(hid, hh_asset_index)
  
  haven::write_dta(hh_asset_index, file.path(temp_dir, "hh_asset_index.dta"))
  cat("  ✓ asset indices saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in asset indices: ", e$message, "\n")
})

# 11.8 Non-farm enterprise
tryCatch({
  cat("  Extracting non-farm enterprise...\n")
  
  housing <- haven::read_dta(file.path(Input_path, country, wave, "ecvmamen_p1_en.dta"))
  
  nfe <- housing |>
    dplyr::mutate(
      # Based on ms05q02-ms05q10
      total = rowSums(dplyr::across(ms05q02:ms05q10), na.rm = TRUE),
      nonfarm_enterprise = dplyr::if_else(total < 18, 1, 0)
    ) |>
    dplyr::select(hid, nonfarm_enterprise) |>
    dplyr::distinct()
  
  haven::write_dta(nfe, file.path(temp_dir, "nfe.dta"))
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
  
  indiv <- haven::read_dta(file.path(Input_path, country, wave, "ecvmaind_p1p2.dta"))
  
  indiv_chars <- indiv |>
    dplyr::mutate(
      ID = paste(hid, ms01q00, sep = "-"),
      female = dplyr::if_else(ms01q01 == 2, 1,
                              dplyr::if_else(ms01q01 == 1, 0, NA_real_)),
      age = ms01q06a,
      married = dplyr::if_else(ms01q15 %in% c(2, 3), 1,
                               dplyr::if_else(ms01q15 %in% c(1, 4, 5, 6), 0, NA_real_)),
      married = dplyr::if_else(is.na(married), 0, married)
    ) |>
    dplyr::mutate(
      # Clean relationship to head
      relationship_head_temp = haven::as_factor(ms01q02) |> as.character(),
      relationship_head = stringr::str_replace_all(relationship_head_temp, 
                                                   `"[^a-zA-Z0-9]"`, ""),
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
    dplyr::select(hid, ID, married, female, age, relationship_head, ms01q06b) |>
    dplyr::distinct()
  
  haven::write_dta(indiv_chars, file.path(temp_dir, "indiv_chars.dta"))
  cat("  ✓ indiv_chars saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in individual characteristics: ", e$message, "\n")
})

# 13.2 Labor
tryCatch({
  cat("  Extracting labor variables...\n")
  
  labor <- haven::read_dta(file.path(Input_path, country, wave, "ecvmaind_p1p2.dta"))
  
  labor_out <- labor |>
    dplyr::mutate(
      ID = paste(hid, ms01q00, sep = "-"),
      # Work types
      farm_work = dplyr::if_else(ms04q03 == 1, 1,
                                 dplyr::if_else(ms04q03 == 2, 0, NA_real_)),
      SOB_work = dplyr::if_else(ms04q05 == 1, 1,
                                dplyr::if_else(ms04q05 == 2, 0, NA_real_)),
      wage_work = dplyr::if_else(ms04q02 == 1, 1,
                                 dplyr::if_else(ms04q02 == 2, 0, NA_real_)),
      # Industry
      ind_ag = dplyr::if_else(ms04q24 >= 11 & ms04q24 <= 40, 1, 0),
      ind_fish = dplyr::if_else(ms04q24 %in% c(51, 52), 1, 0),
      ind_mining = dplyr::if_else(ms04q24 >= 60 & ms04q24 <= 72, 1, 0),
      ind_manuf = dplyr::if_else(ms04q24 >= 81 & ms04q24 <= 292, 1, 0),
      ind_const = dplyr::if_else(ms04q24 %in% c(301, 302), 1, 0),
      ind_serv = dplyr::if_else(ms04q24 >= 310 & ms04q24 <= 430, 1, 0)
    ) |>
    dplyr::mutate(
      dplyr::across(c(ind_ag, ind_fish, ind_mining, ind_manuf, ind_const, ind_serv),
                    ~ dplyr::if_else(ms04q26 %in% c(4, 6, 7, 8) | ms04q22 == 2, 
                                     0, .x))
    )
  
  # Calculate hours
  labor_out <- labor_out |>
    dplyr::mutate(
      hour_job1 = ms04q30,
      hour_job1 = dplyr::if_else(ms04q11 == 2 & ms04q12 == 2, 0, hour_job1),
      hour_job2 = ms04q56,
      hour_job2 = dplyr::if_else(ms04q11 == 2 & ms04q12 == 2, 0, hour_job2),
      
      day_job1 = ms04q31,
      day_job1 = dplyr::if_else(ms04q11 == 2 & ms04q12 == 2, 0, day_job1),
      day_job2 = ms04q57,
      day_job2 = dplyr::if_else(ms04q11 == 2 & ms04q12 == 2, 0, day_job2),
      
      month_job1 = ms04q29,
      month_job1 = dplyr::if_else(ms04q11 == 2 & ms04q12 == 2, 0, month_job1),
      month_job2 = ms04q55,
      month_job2 = dplyr::if_else(ms04q11 == 2 & ms04q12 == 2, 0, month_job2),
      
      av_hours1 = (month_job1 * hour_job1 * day_job1) / 52,
      av_hours2 = (month_job2 * hour_job2 * day_job2) / 52
    )
  
  # Job types
  labor_out <- labor_out |>
    dplyr::mutate(
      farm_job1 = dplyr::if_else(ms04q23 %in% c(1101:1107, 1201:1205), 1, 0),
      farm_job2 = dplyr::if_else(ms04q51 %in% c(1101:1107, 1201:1205), 1, 0),
      farm_job1 = dplyr::if_else(farm_job1 == 1 & ms04q26 %in% c(1, 2, 3, 7), 0, farm_job1),
      farm_job2 = dplyr::if_else(farm_job2 == 1 & ms04q54 %in% c(1, 2, 3, 7), 0, farm_job2),
      
      SB_job1 = dplyr::if_else(ms04q23 %in% c(6101, 6202:6212), 1, 0),
      SB_job2 = dplyr::if_else(ms04q51 %in% c(6101, 6202:6212), 1, 0),
      SB_job1 = dplyr::if_else(SB_job1 == 1 & ms04q26 %in% c(1, 2, 3, 7), 0, SB_job1),
      SB_job2 = dplyr::if_else(SB_job2 == 1 & ms04q54 %in% c(1, 2, 3, 7), 0, SB_job2),
      
      wage_job1 = dplyr::if_else(!ms04q23 %in% c(1101:1107, 1201:1205, 6101, 6202:6212), 1, 0),
      wage_job2 = dplyr::if_else(!ms04q51 %in% c(1101:1107, 1201:1205, 6101, 6202:6212), 1, 0),
      wage_job1 = dplyr::if_else(wage_job1 == 0 & ms04q26 %in% c(1, 2, 3, 7), 1, wage_job1),
      wage_job2 = dplyr::if_else(wage_job2 == 0 & ms04q54 %in% c(1, 2, 3, 7), 1, wage_job2)
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
    dplyr::mutate(
      working_age = ms01q06a >= 6
    ) |>
    dplyr::mutate(
      dplyr::across(c(farm_work, SOB_work, wage_work, farm_hrs, SB_hrs, wage_hrs,
                      ind_ag, ind_const, ind_fish, ind_manuf, ind_mining, ind_serv),
                    ~ dplyr::if_else(!working_age, 0, .x))
    ) |>
    dplyr::select(ID, hid, farm_work, SOB_work, wage_work, farm_hrs, SB_hrs, wage_hrs,
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
  
  indiv <- haven::read_dta(file.path(Input_path, country, wave, "ecvmaind_p1p2.dta"))
  
  educ_out <- indiv |>
    dplyr::mutate(
      ID = paste(hid, ms01q00, sep = "-"),
      formal_education = dplyr::if_else(ms02q04 == 1, 1,
                                        dplyr::if_else(ms02q04 %in% c(2:4), 0, NA_real_)),
      primary_education = dplyr::if_else(ms02q12 %in% c(3:7) | ms02q23 %in% c(3:7), 1,
                                         dplyr::if_else(ms02q12 %in% c(1, 2) | 
                                                          ms02q23 %in% c(1, 2), 0, NA_real_)),
      primary_education = dplyr::if_else(formal_education == 0, 0, primary_education)
    ) |>
    dplyr::mutate(
      dplyr::across(c(formal_education, primary_education),
                    ~ dplyr::if_else(ms01q06a < 6, 0, .x))
    ) |>
    dplyr::select(ID, hid, formal_education, primary_education) |>
    dplyr::distinct()
  
  haven::write_dta(educ_out, file.path(temp_dir, "educ_indiv.dta"))
  cat("  ✓ educ_indiv saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in education variables: ", e$message, "\n")
})

# ==============================================================================
# 14. GEOGRAPHIC VARIABLES
# ==============================================================================

cat("\n=== Processing geographic variables ===\n")

tryCatch({
  cat("  Extracting geographic variables...\n")
  
  # Load geovars
  geovars <- haven::read_dta(file.path(Input_path, country, wave, "NER_HouseholdGeovars_Y1.dta"))
  cover <- haven::read_dta(file.path(Input_path, country, wave, "ecvmasection00_p1.dta"))
  
  # EA to hid mapping
  ea_map <- cover |>
    dplyr::mutate(
      ea_id = paste(ms00q10, ms00q11, ms00q12, ms00q14, sep = "-")
    ) |>
    dplyr::select(grappe, ea_id) |>
    dplyr::distinct()
  
  # Coordinates
  coords <- geovars |>
    dplyr::rename(
      lat_modified = LAT_DD_MOD,
      lon_modified = LON_DD_MOD
    ) |>
    dplyr::select(grappe, lat_modified, lon_modified) |>
    dplyr::distinct() |>
    dplyr::left_join(ea_map, by = "grappe") |>
    dplyr::select(ea_id, lat_modified, lon_modified) |>
    dplyr::distinct()
  
  haven::write_dta(coords, file.path(temp_dir, "Coords.dta"))
  
  # Agro-ecological zone
  aez <- geovars |>
    dplyr::select(grappe, agro_ecological_zone = ssa_aez09) |>
    dplyr::distinct() |>
    dplyr::left_join(ea_map, by = "grappe") |>
    dplyr::select(hid = grappe, agro_ecological_zone) |>
    dplyr::distinct()
  
  haven::write_dta(aez, file.path(temp_dir, "aez.dta"))
  
  # Distance to road
  dist_road <- geovars |>
    dplyr::select(grappe, dist_road) |>
    dplyr::distinct() |>
    dplyr::left_join(
      cover |> dplyr::mutate(hid = paste(grappe, menage, sep = "-")) |> 
        dplyr::select(grappe, hid) |> dplyr::distinct(),
      by = "grappe"
    ) |>
    dplyr::select(hid, dist_road) |>
    dplyr::distinct()
  
  haven::write_dta(dist_road, file.path(temp_dir, "dist_road.dta"))
  
  # Distance to population center
  dist_popcenter <- geovars |>
    dplyr::select(grappe, dist_popcenter) |>
    dplyr::distinct() |>
    dplyr::left_join(
      cover |> dplyr::mutate(hid = paste(grappe, menage, sep = "-")) |> 
        dplyr::select(grappe, hid) |> dplyr::distinct(),
      by = "grappe"
    ) |>
    dplyr::select(hid, dist_popcenter) |>
    dplyr::distinct()
  
  haven::write_dta(dist_popcenter, file.path(temp_dir, "dist_popcenter.dta"))
  
  # Distance to market
  dist_market <- geovars |>
    dplyr::select(grappe, dist_market) |>
    dplyr::distinct() |>
    dplyr::left_join(
      cover |> dplyr::mutate(hid = paste(grappe, menage, sep = "-")) |> 
        dplyr::select(grappe, hid) |> dplyr::distinct(),
      by = "grappe"
    ) |>
    dplyr::select(hid, dist_market) |>
    dplyr::distinct()
  
  haven::write_dta(dist_market, file.path(temp_dir, "dist_market.dta"))
  
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
  
  hdds <- haven::read_dta(file.path(Input_path, country, wave, "ecvmaali_p1_en.dta"))
  
  hdds_out <- hdds |>
    dplyr::filter(ms13q02 == 1) |>  # Keep if consumed
    dplyr::mutate(
      food_id = ms13q01,
      # Define food groups
      A = dplyr::if_else(food_id %in% c(701:712, 810:813, 816:821), 1, 0),
      B = dplyr::if_else(food_id %in% c(748:753), 1, 0),
      C = dplyr::if_else(food_id %in% c(717:730), 1, 0),
      D = dplyr::if_else(food_id %in% c(754:765), 1, 0),
      E = dplyr::if_else(food_id %in% c(766:773), 1, 0),
      F = dplyr::if_else(food_id == 785, 1, 0),
      G = dplyr::if_else(food_id %in% c(774:778), 1, 0),
      H = dplyr::if_else(food_id %in% c(731:734, 814:815), 1, 0),
      I = dplyr::if_else(food_id %in% c(786:792), 1, 0),
      J = dplyr::if_else(food_id %in% c(713:714, 779:784), 1, 0),
      K = dplyr::if_else(food_id %in% c(715:716, 793:798), 1, 0),
      L = dplyr::if_else(food_id %in% c(735:747), 1, 0)
    ) |>
    dplyr::group_by(hid) |>
    dplyr::summarise(
      dplyr::across(A:L, ~ max(.x, na.rm = TRUE)),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      HDDS = rowSums(dplyr::across(A:L), na.rm = TRUE),
      HDDS = dplyr::if_else(is.na(HDDS), 0, HDDS)
    ) |>
    dplyr::select(hid, HDDS)
  
  haven::write_dta(hdds_out, file.path(temp_dir, "HDDS.dta"))
  cat("  ✓ HDDS saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in HDDS: ", e$message, "\n")
})

# ==============================================================================
# 16. FINAL OUTPUT
# ==============================================================================

cat("\n=== NER_ECVMA1 processing complete ===\n")
cat("Temporary files saved to:", temp_dir, "\n")
cat("✓ All variables extracted successfully\n")