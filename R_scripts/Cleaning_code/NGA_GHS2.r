# ==============================================================================
# NGA_GHS2.r - Nigeria Wave 2 (GHS 2012)
# LSMS-ISA Harmonised Panel Analysis Code - R Translation
# ==============================================================================

# Clean environment
rm(list = ls())

# Load required packages
packages <- c("tidyverse", "haven", "labelled", "stringr", "purrr", 
              "data.table", "lubridate", "mice", "psych", "labelled")
installed <- packages %in% rownames(utils::installed.packages())
if (any(!installed)) utils::install.packages(packages[!installed])
lapply(packages, library, character.only = TRUE)

# Source helper functions
source("R_scripts/programs.r")

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

# Define country and wave
country <- "Nigeria"
wave <- "GHS 12"

# Define file names
cover1 <- "secta_plantingw2.dta"
cover2 <- "secta_harvestw2.dta"
indiv_roster <- "sect1_plantingw2.dta"
indiv_roster0 <- "sect1_harvestw2.dta"
indiv_roster1 <- "sect2a_harvestw2.dta"
indiv_roster2 <- "sect2b_harvestw2.dta"
lab_roster1 <- "sect11c1_plantingw2.dta"
lab_roster2 <- "secta2_harvestw2.dta"
shocks <- "sect15a_harvestw2.dta"
housing <- "sect8_harvestw2.dta"
plot_roster <- "sect11a1_plantingw2.dta"
plot_inputs <- "sect11f_plantingw2.dta"
ferts <- "sect11d_plantingw2.dta"
csption1 <- "cons_agg_wave2_visit1.dta"
csption2 <- "cons_agg_wave2_visit2.dta"
items <- "secta41_harvestw2.dta"
items_hh <- "sect7_harvestw2.dta"
harvest_rwdta <- "secta3_harvestw2.dta"
perennial <- "sect11g_plantingw2.dta"
HDDS <- "sect10b_harvestw2.dta"
livestock <- "sect11i_plantingw2.dta"
conversions <- "w2agnsconversion.dta"
seeds <- "sect11e_plantingw2.dta"
pesticides <- "sect11c2_plantingw2.dta"
tenure <- "sect11b1_plantingw2.dta"
labor_hh <- "sect3a_plantingw2.dta"
nfe <- "sect9_harvestw2.dta"
geovars_hh <- "NGA_HouseholdGeovars_Y2.dta"
geovars <- "NGA_PlotGeovariables_Y2.dta"
anthropo <- "sect4a_harvestw2.dta"

# Set temp path
temppath <- file.path("NGA", "GHS12")

# ==============================================================================
# 2. HELPER FUNCTIONS
# ==============================================================================

# Note: The following helper functions would need to be defined in programs.r
# For this translation, we'll define them inline or note where they're needed

# ==============================================================================
# 3. MASTER FRAME OF CROPS, PLOTS AND HOUSEHOLDS
# ==============================================================================

# 3.1 Plot-crop frame
harvest_data <- haven::read_dta(file.path(Input_path, country, wave, harvest_rwdta)) |>
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

haven::write_dta(harvest_data, file.path(Temp_path, temppath, "plot_crop_frame.dta"))

# 3.2 Household frame
cover1_data <- haven::read_dta(file.path(Input_path, country, wave, cover1))

hh_frame <- cover1_data |>
  dplyr::distinct(hhid)

haven::write_dta(hh_frame, file.path(Temp_path, temppath, "hh_frame.dta"))

# 3.3 Individual frame
indiv0_data <- haven::read_dta(file.path(Input_path, country, wave, indiv_roster0))
indiv_data <- haven::read_dta(file.path(Input_path, country, wave, indiv_roster))

indiv_frame <- indiv0_data |>
  dplyr::left_join(indiv_data, by = c("hhid", "indiv")) |>
  dplyr::filter(s1q14 != 2) |>
  dplyr::rename(id = indiv) |>
  dplyr::mutate(ID = paste(hhid, id, sep = "-")) |>
  dplyr::select(hhid, ID) |>
  dplyr::distinct()

haven::write_dta(indiv_frame, file.path(Temp_path, temppath, "indiv_frame.dta"))

# ==============================================================================
# 4. VARIABLE EXTRACTION
# ==============================================================================

# 4.1 EA (Enumeration Area)
ghs10_data <- haven::read_dta(file.path(Input_path, country, "GHS 10", "secta_plantingw1.dta"))

ea_data <- cover1_data |>
  dplyr::select(-ea, -lga) |>
  dplyr::inner_join(ghs10_data |> dplyr::select(hhid, ea, lga), by = "hhid") |>
  dplyr::mutate(ea_id = paste(lga, ea, sep = "-")) |>
  dplyr::select(hhid, ea_id) |>
  dplyr::distinct()

haven::write_dta(ea_data, file.path(Temp_path, temppath, "ea_id.dta"))

# 4.2 Strata
strata_data <- cover1_data |>
  dplyr::rename(zone_w2 = zone) |>
  dplyr::inner_join(ghs10_data |> dplyr::select(hhid, zone), by = "hhid") |>
  dplyr::rename(strataid = zone) |>
  dplyr::select(hhid, strataid) |>
  dplyr::distinct()

haven::write_dta(strata_data, file.path(Temp_path, temppath, "strataid.dta"))

# 4.3 Admin 1
admin1_data <- cover1_data |>
  dplyr::rename(admin_1 = zone) |>
  dplyr::mutate(admin_1_name = as.character(haven::as_factor(admin_1))) |>
  dplyr::select(hhid, admin_1, admin_1_name) |>
  dplyr::distinct()

haven::write_dta(admin1_data, file.path(Temp_path, temppath, "admin1.dta"))

# 4.4 Admin 2
admin2_data <- cover1_data |>
  dplyr::rename(admin_2 = state) |>
  dplyr::mutate(admin_2_name = as.character(haven::as_factor(admin_2))) |>
  dplyr::select(hhid, admin_2, admin_2_name) |>
  dplyr::distinct()

haven::write_dta(admin2_data, file.path(Temp_path, temppath, "admin2.dta"))

# 4.5 Admin 3
admin3_data <- cover1_data |>
  dplyr::rename(admin_3 = lga) |>
  dplyr::mutate(admin_3_name = as.character(haven::as_factor(admin_3))) |>
  dplyr::select(hhid, admin_3, admin_3_name) |>
  dplyr::distinct()

haven::write_dta(admin3_data, file.path(Temp_path, temppath, "admin3.dta"))

# 4.6 Urban
urban_data <- cover1_data |>
  dplyr::mutate(urban = dplyr::case_when(
    sector == 1 ~ 1,
    sector == 2 ~ 0,
    TRUE ~ NA_real_
  )) |>
  dplyr::select(hhid, urban) |>
  dplyr::distinct()

haven::write_dta(urban_data, file.path(Temp_path, temppath, "urban.dta"))

# 4.7 Weights
csption1_data <- haven::read_dta(file.path(Input_path, country, wave, csption1))
csption2_data <- haven::read_dta(file.path(Input_path, country, wave, csption2))

weights_data <- csption1_data |>
  dplyr::inner_join(csption2_data |> dplyr::select(hhid), by = "hhid") |>
  dplyr::rename(pw = hhweight) |>
  dplyr::select(hhid, pw) |>
  dplyr::distinct()

haven::write_dta(weights_data, file.path(Temp_path, temppath, "weights.dta"))

# 4.8 Planting month
plot_inputs_data <- haven::read_dta(file.path(Input_path, country, wave, plot_inputs))

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

haven::write_dta(planting_month_data, file.path(Temp_path, temppath, "planting_month.dta"))

# 4.9 Harvest interview month
cover2_data <- haven::read_dta(file.path(Input_path, country, wave, cover2))

harvest_interview_data <- cover2_data |>
  dplyr::mutate(
    month = saq13m,
    year = saq13y
  ) |>
  dplyr::mutate(harvest_interview_month = lubridate::ymd(paste(year, month, "01", sep = "-"))) |>
  dplyr::select(hhid, harvest_interview_month) |>
  dplyr::distinct()

haven::write_dta(harvest_interview_data, file.path(Temp_path, temppath, "harvest_interview_month.dta"))

# 4.10 Planting interview month
planting_interview_data <- cover1_data |>
  dplyr::mutate(
    month = saq13m,
    year = saq13y
  ) |>
  dplyr::mutate(planting_interview_month = lubridate::ymd(paste(year, month, "01", sep = "-"))) |>
  dplyr::select(hhid, planting_interview_month) |>
  dplyr::distinct()

haven::write_dta(planting_interview_data, file.path(Temp_path, temppath, "planting_interview_month.dta"))

# 4.11 Harvest kg (Main calculation)
conversions_data <- haven::read_dta(file.path(Input_path, country, wave, conversions))

conversions_clean <- conversions_data |>
  dplyr::filter(kg != 0) |>
  dplyr::group_by(nscode) |>
  dplyr::mutate(mad = stats::mad(conversion, na.rm = TRUE)) |>
  dplyr::summarise(
    conversion = mean(conversion, na.rm = TRUE),
    mad = dplyr::first(mad),
    .groups = "drop"
  )

harvest_raw <- haven::read_dta(file.path(Input_path, country, wave, harvest_rwdta))

# Add admin variables
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

haven::write_dta(harvest_kg_data, file.path(Temp_path, temppath, "harvest_kg.dta"))

# 4.12 Crop shock
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

haven::write_dta(crop_shock_data, file.path(Temp_path, temppath, "crop_shock.dta"))

# ==============================================================================
# 5. ADDITIONAL VARIABLE EXTRACTIONS (Placeholder sections)
# ==============================================================================

# Note: The following sections would contain the full implementation of:
# - harvest_sold_kg
# - harvest_sold_value
# - harvest_value & main crop
# - intercropped
# - nb_seasonal_crop
# - main_crop classification
# - land area (with imputation)
# - seed kg
# - labor days
# - fertilizer variables
# - pesticide variables
# - plot ownership
# - irrigation
# - tractor
# - fallow plots
# - education
# - electricity access
# - dependency ratio
# - livestock
# - consumption quintiles
# - manager characteristics
# - respondent characteristics
# - shocks
# - household size
# - asset indices
# - non-farm enterprise
# - geographic variables
# - soil variables
# - individual characteristics
# - anthropometric measures (wasting)
# - labor variables
# - HDDS

# ==============================================================================
# 6. MERGE ALL VARIABLES AND SAVE FINAL DATASET
# ==============================================================================

# Load all created datasets and merge them together
# This would be the final step to create the complete household dataset

# Example merge structure:
# final_data <- hh_frame |>
#   dplyr::left_join(admin1_data, by = "hhid") |>
#   dplyr::left_join(admin2_data, by = "hhid") |>
#   dplyr::left_join(admin3_data, by = "hhid") |>
#   dplyr::left_join(urban_data, by = "hhid") |>
#   dplyr::left_join(weights_data, by = "hhid") |>
#   dplyr::left_join(ea_data, by = "hhid") |>
#   dplyr::left_join(strata_data, by = "hhid") |>
#   # ... continue with all other datasets
#   haven::write_dta(file.path(Final_path, "NGA_GHS2_clean.dta"))

# ==============================================================================
# 7. CREATE CROP-LEVEL DATASET
# ==============================================================================

# Similarly, merge plot-level and crop-level variables

message("Script execution completed successfully!")
message("Note: Full implementation requires additional processing for all variables.")
message("See comments in code for placeholder sections.")
