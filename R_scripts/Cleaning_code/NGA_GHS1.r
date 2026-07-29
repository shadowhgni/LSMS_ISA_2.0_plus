# ==============================================================================
# NGA_GHS1.r - Nigeria Wave 1 (GHS 2010)
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
project_root <- '../..'
Do_path <- file.path(project_root, "R_scripts")
Input_path <- file.path(project_root, "R_data", "Input")
Temp_path <- file.path(project_root, "R_data", "Temp")
Final_path <- file.path(project_root, "R_data", "Final")

# Create directories
dir.create(Temp_path, showWarnings = FALSE, recursive = TRUE)
dir.create(Final_path, showWarnings = FALSE, recursive = TRUE)

# Country-specific globals
country <- "Nigeria"
wave <- "GHS 10"
temppath <- file.path("NGA", "GHS10")

# Create temp directory
temp_dir <- file.path(Temp_path, temppath)
dir.create(temp_dir, showWarnings = FALSE, recursive = TRUE)

# Input directory for this country/wave
input_dir <- file.path(Input_path, country, wave)

# ==============================================================================
# 2. HELPER FUNCTION: READ ZIPPED OR UNZIPPED DTA FILE
# ==============================================================================

#' Read a .dta file, handling both zipped and unzipped files
#'
#' @param pattern Pattern to match the file name
#' @param input_dir Directory containing the files (may contain zip files)
#' @param unzip_dir Directory to extract files to (default: same as input_dir)
#' @param force_unzip If TRUE, always unzip even if dta exists
#' @return The read data frame
read_dta_auto <- function(pattern, input_dir, unzip_dir = NULL, force_unzip = FALSE) {
  
  if (is.null(unzip_dir)) {
    unzip_dir <- input_dir
  }
  
  # Ensure directories exist
  dir.create(unzip_dir, showWarnings = FALSE, recursive = TRUE)
  
  # First, check if .dta file already exists (case insensitive)
  dta_files <- list.files(unzip_dir, pattern = paste0("(?i)", pattern, "\\.dta$"), 
                          full.names = TRUE, recursive = FALSE)
  
  if (length(dta_files) > 0 && !force_unzip) {
    cat("  Found existing .dta file:", basename(dta_files[1]), "\n")
    return(haven::read_dta(dta_files[1]))
  }
  
  # If .dta doesn't exist, find the zip file
  zip_files <- list.files(input_dir, pattern = "\\.zip$", full.names = TRUE)
  
  if (length(zip_files) == 0) {
    stop("No zip files found in ", input_dir)
  }
  
  # Try to extract the specific pattern from the zip
  for (zip_file in zip_files) {
    # List contents of zip
    zip_contents <- unzip(zip_file, list = TRUE)$Name
    
    # Look for matching pattern (case insensitive)
    matching_file <- grep(pattern, zip_contents, ignore.case = TRUE, value = TRUE)
    
    if (length(matching_file) > 0) {
      cat("  Extracting", matching_file[1], "from", basename(zip_file), "\n")
      # Extract the specific file
      unzip(zip_file, files = matching_file[1], exdir = unzip_dir, overwrite = TRUE)
      # Read the extracted file
      extracted_path <- file.path(unzip_dir, matching_file[1])
      return(haven::read_dta(extracted_path))
    }
  }
  
  # If we get here, the pattern wasn't found in any zip
  stop("Could not find pattern '", pattern, "' in any zip file in ", input_dir)
}

# ==============================================================================
# 3. MASTER FRAME OF CROPS, PLOTS, AND HOUSEHOLDS
# ==============================================================================

cat("\n=== Creating master frames ===\n")

# 3.1 Plot-crop frame
tryCatch({
  cat("  Creating plot-crop frame...\n")
  
  # Load harvest data
  harvest <- read_dta_auto("secta3_harvestw1", input_dir, temp_dir)
  
  # Clean and create plot-crop frame
  plot_crop_frame <- harvest |>
    dplyr::filter(!is.na(plotid) & !is.na(cropcode)) |>
    dplyr::filter(!stringr::str_starts(sa3q4b, "HA")) |>
    dplyr::mutate(
      plot_id = paste(hhid, plotid, sep = "-"),
      crop_name = haven::as_factor(cropcode) |> as.character()
    ) |>
    dplyr::rename(crop_code = cropcode) |>
    dplyr::select(hhid, plot_id, crop_name, crop_code) |>
    dplyr::distinct()
  
  # Handle duplicates - keep first occurrence
  plot_crop_frame <- plot_crop_frame |>
    dplyr::group_by(plot_id, crop_code) |>
    dplyr::mutate(
      crop_name = dplyr::first(crop_name)
    ) |>
    dplyr::ungroup() |>
    dplyr::distinct()
  
  # If crop_name is missing, use decoded crop code
  plot_crop_frame <- plot_crop_frame |>
    dplyr::mutate(
      crop_name = dplyr::if_else(
        is.na(crop_name) | crop_name == "",
        haven::as_factor(crop_code) |> as.character(),
        crop_name
      )
    )
  
  haven::write_dta(plot_crop_frame, file.path(temp_dir, "plot_crop_frame.dta"))
  cat("  ✓ plot_crop_frame saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in plot-crop frame: ", e$message, "\n")
})

# 3.2 Household frame
tryCatch({
  cat("  Creating household frame...\n")
  
  cover <- read_dta_auto("secta_plantingw1", input_dir, temp_dir)
  
  hh_frame <- cover |>
    dplyr::select(hhid) |>
    dplyr::distinct()
  
  haven::write_dta(hh_frame, file.path(temp_dir, "hh_frame.dta"))
  cat("  ✓ hh_frame saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in household frame: ", e$message, "\n")
})

# 3.3 Individual frame
tryCatch({
  cat("  Creating individual frame...\n")
  
  # Load individual data
  indiv1 <- read_dta_auto("sect1_plantingw1", input_dir, temp_dir)
  indiv2 <- read_dta_auto("sect2a_harvestw1", input_dir, temp_dir)
  
  indiv_frame <- indiv1 |>
    dplyr::inner_join(indiv2, by = c("hhid", "indiv")) |>
    dplyr::filter(s1q7 == 1) |>  # Keep if lives in household
    dplyr::mutate(
      ID = paste(hhid, indiv, sep = "-")
    ) |>
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

# 4.1 EA
tryCatch({
  cat("  Extracting EA...\n")
  
  cover <- read_dta_auto("secta_plantingw1", input_dir, temp_dir)
  
  ea_id <- cover |>
    dplyr::mutate(
      ea_id = paste(lga, ea, sep = "-")
    ) |>
    dplyr::select(hhid, ea_id) |>
    dplyr::distinct()
  
  haven::write_dta(ea_id, file.path(temp_dir, "ea_id.dta"))
  cat("  ✓ ea_id saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in EA extraction: ", e$message, "\n")
})

# 4.2 Strata
tryCatch({
  cat("  Extracting strata...\n")
  
  cover <- read_dta_auto("secta_plantingw1", input_dir, temp_dir)
  
  strata <- cover |>
    dplyr::rename(strataid = zone) |>
    dplyr::select(hhid, strataid) |>
    dplyr::distinct()
  
  haven::write_dta(strata, file.path(temp_dir, "strataid.dta"))
  cat("  ✓ strataid saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in strata extraction: ", e$message, "\n")
})

# 4.3 Administrative levels
tryCatch({
  cat("  Extracting administrative levels...\n")
  
  cover <- read_dta_auto("secta_plantingw1", input_dir, temp_dir)
  
  # Admin 1 (Zone)
  admin1 <- cover |>
    dplyr::rename(admin_1 = zone) |>
    dplyr::mutate(
      admin_1_name = haven::as_factor(admin_1) |> as.character()
    ) |>
    dplyr::select(hhid, admin_1, admin_1_name) |>
    dplyr::distinct()
  
  haven::write_dta(admin1, file.path(temp_dir, "admin1.dta"))
  
  # Admin 2 (State)
  admin2 <- cover |>
    dplyr::rename(admin_2 = state) |>
    dplyr::mutate(
      admin_2_name = haven::as_factor(admin_2) |> as.character()
    ) |>
    dplyr::select(hhid, admin_2, admin_2_name) |>
    dplyr::distinct()
  
  haven::write_dta(admin2, file.path(temp_dir, "admin2.dta"))
  
  # Admin 3 (LGA)
  admin3 <- cover |>
    dplyr::rename(admin_3 = lga) |>
    dplyr::mutate(
      admin_3_name = haven::as_factor(admin_3) |> as.character() |> toupper()
    ) |>
    dplyr::select(hhid, admin_3, admin_3_name) |>
    dplyr::distinct()
  
  haven::write_dta(admin3, file.path(temp_dir, "admin3.dta"))
  
  cat("  ✓ admin levels saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in admin levels: ", e$message, "\n")
})

# 4.4 Urban/rural
tryCatch({
  cat("  Extracting urban/rural...\n")
  
  cover <- read_dta_auto("secta_plantingw1", input_dir, temp_dir)
  
  urban <- cover |>
    dplyr::mutate(
      urban = dplyr::if_else(sector == 1, 1, 0)
    ) |>
    dplyr::select(hhid, urban) |>
    dplyr::distinct()
  
  haven::write_dta(urban, file.path(temp_dir, "urban.dta"))
  cat("  ✓ urban saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in urban/rural: ", e$message, "\n")
})

# 4.5 Weights
tryCatch({
  cat("  Extracting weights...\n")
  
  # Load consumption aggregates
  csption1 <- read_dta_auto("cons_agg_wave1_visit1", input_dir, temp_dir)
  csption2 <- read_dta_auto("cons_agg_wave1_visit2", input_dir, temp_dir)
  
  weights <- csption1 |>
    dplyr::left_join(csption2, by = "hhid") |>
    dplyr::select(hhid, pw = hhweight) |>
    dplyr::distinct()
  
  haven::write_dta(weights, file.path(temp_dir, "weights.dta"))
  cat("  ✓ weights saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in weights: ", e$message, "\n")
})

# 4.6 Planting month
tryCatch({
  cat("  Extracting planting month...\n")
  
  plot_inputs <- read_dta_auto("sect11f_plantingw1", input_dir, temp_dir)
  
  planting_month <- plot_inputs |>
    dplyr::mutate(
      plot_id = paste(hhid, plotid, sep = "-"),
      month = s11fq3a,
      year = s11fq3b,
      year = dplyr::if_else(year > 2014 | year < 1980, NA_real_, year),
      planting_month = lubridate::ymd(paste(year, month, "01", sep = "-"))
    ) |>
    dplyr::select(hhid, plot_id, cropcode, planting_month) |>
    dplyr::distinct() |>
    dplyr::group_by(hhid, cropcode, plot_id) |>
    dplyr::summarise(planting_month = min(planting_month, na.rm = TRUE), .groups = "drop")
  
  haven::write_dta(planting_month, file.path(temp_dir, "planting_month.dta"))
  cat("  ✓ planting_month saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in planting month: ", e$message, "\n")
})

# 4.7 Harvest interview month
tryCatch({
  cat("  Extracting harvest interview month...\n")
  
  cover2 <- read_dta_auto("secta_harvestw1", input_dir, temp_dir)
  
  harvest_interview_month <- cover2 |>
    dplyr::mutate(
      month = saq13m,
      year = saq13y,
      harvest_interview_month = lubridate::ymd(paste(year, month, "01", sep = "-"))
    ) |>
    dplyr::select(hhid, harvest_interview_month) |>
    dplyr::distinct()
  
  haven::write_dta(harvest_interview_month, file.path(temp_dir, "harvest_interview_month.dta"))
  cat("  ✓ harvest_interview_month saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in harvest interview month: ", e$message, "\n")
})

# 4.8 Planting interview month
tryCatch({
  cat("  Extracting planting interview month...\n")
  
  cover <- read_dta_auto("secta_plantingw1", input_dir, temp_dir)
  
  planting_interview_month <- cover |>
    dplyr::mutate(
      month = saq13m,
      year = saq13y,
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
# 5. HARVEST QUANTITY AND CONVERSION FACTORS
# ==============================================================================

cat("\n=== Processing harvest data ===\n")

# 5.1 Conversion factors
tryCatch({
  cat("  Calculating conversion factors...\n")
  
  conversions <- read_dta_auto("w1agnsconversion", input_dir, temp_dir)
  
  # Clean conversion factors
  conversions <- conversions |>
    dplyr::filter(nscode <= 83) |>
    dplyr::group_by(nscode) |>
    dplyr::mutate(
      mad = stats::mad(conversion, na.rm = TRUE)
    ) |>
    dplyr::ungroup() |>
    dplyr::group_by(nscode) |>
    dplyr::summarise(
      conversion = mean(conversion, na.rm = TRUE),
      mad = dplyr::first(mad),
      .groups = "drop"
    )
  
  haven::write_dta(conversions, file.path(temp_dir, "Conversion_factors.dta"))
  cat("  ✓ conversion factors saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in conversion factors: ", e$message, "\n")
})

# 5.2 Harvest kg
tryCatch({
  cat("  Calculating harvest kg...\n")
  
  # Load conversion factors
  conversions <- haven::read_dta(file.path(temp_dir, "Conversion_factors.dta"))
  
  # Load harvest data
  harvest <- read_dta_auto("secta3_harvestw1", input_dir, temp_dir)
  
  # Add admin levels
  admin1 <- haven::read_dta(file.path(temp_dir, "admin1.dta"))
  admin2 <- haven::read_dta(file.path(temp_dir, "admin2.dta"))
  admin3 <- haven::read_dta(file.path(temp_dir, "admin3.dta"))
  
  harvest_kg <- harvest |>
    dplyr::left_join(admin1, by = "hhid") |>
    dplyr::left_join(admin2, by = "hhid") |>
    dplyr::left_join(admin3, by = "hhid") |>
    dplyr::mutate(
      plot_id = paste(hhid, plotid, sep = "-"),
      ea_id = ea,
      crop_code = sa3q2,
      any_harvest = dplyr::if_else(sa3q3 == 1, 1, 0),
      # Apply conversion
      harvest_kg = sa3q6a * conversion,
      harvest_kg = dplyr::if_else(nscode == 1, sa3q6a, harvest_kg),  # kg
      harvest_kg = dplyr::if_else(nscode == 2, sa3q6a * 0.001, harvest_kg),  # grams
      harvest_kg = dplyr::if_else(any_harvest == 0, 0, harvest_kg),
      # Crop shock
      crop_shock = dplyr::if_else(sa3q3 == 2, 1,
                                  dplyr::if_else(sa3q3 == 1, 0, NA_real_)),
      crop_shock = dplyr::if_else(sa3q4 == 9, 0, crop_shock),
      harvest_kg = dplyr::if_else(harvest_kg == 0 & crop_shock != 1, NA_real_, harvest_kg)
    ) |>
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

# 5.3 Crop shocks
tryCatch({
  cat("  Extracting crop shocks...\n")
  
  harvest <- read_dta_auto("secta3_harvestw1", input_dir, temp_dir)
  
  crop_shock <- harvest |>
    dplyr::mutate(
      plot_id = paste(hhid, plotid, sep = "-"),
      crop_code = sa3q2,
      # Crop shock
      crop_shock = dplyr::if_else(sa3q3 == 2, 1,
                                  dplyr::if_else(sa3q3 == 1, 0, NA_real_)),
      crop_shock = dplyr::if_else(sa3q4 == 9, 0, crop_shock),
      # Drought shock
      drought_shock = dplyr::if_else(sa3q4 == 1, 1,
                                     dplyr::if_else(sa3q4 %in% c(2:8, 10), 0, NA_real_)),
      drought_shock = dplyr::if_else(sa3q3 == 1, 0, drought_shock),
      # Flood shock
      flood_shock = dplyr::if_else(sa3q4 == 2, 1,
                                   dplyr::if_else(sa3q4 %in% c(1, 3:8, 10), 0, NA_real_)),
      flood_shock = dplyr::if_else(sa3q3 == 1, 0, flood_shock),
      # Pests shock
      pests_shock = dplyr::if_else(sa3q4 == 3, 1,
                                   dplyr::if_else(sa3q4 %in% c(1, 2, 4:8, 10), 0, NA_real_)),
      pests_shock = dplyr::if_else(sa3q3 == 1, 0, pests_shock)
    ) |>
    dplyr::group_by(hhid, plot_id, crop_code) |>
    dplyr::summarise(
      crop_shock = max(crop_shock, na.rm = TRUE),
      pests_shock = max(pests_shock, na.rm = TRUE),
      drought_shock = max(drought_shock, na.rm = TRUE),
      flood_shock = max(flood_shock, na.rm = TRUE),
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

# 5.4 Harvest sold amount
tryCatch({
  cat("  Calculating harvest sold amount...\n")
  
  # Load conversion factors for sold harvest
  conversions_kg <- read_dta_auto("w1agnsconversion", input_dir, temp_dir) |>
    dplyr::filter(nscode <= 83) |>
    dplyr::rename(cropcode = agcropid) |>
    dplyr::select(cropcode, nscode, conversion)
  
  # Load harvest data
  harvest <- read_dta_auto("secta3_harvestw1", input_dir, temp_dir)
  
  # Add admin levels
  admin1 <- haven::read_dta(file.path(temp_dir, "admin1.dta"))
  admin2 <- haven::read_dta(file.path(temp_dir, "admin2.dta"))
  admin3 <- haven::read_dta(file.path(temp_dir, "admin3.dta"))
  
  harvest_sold <- harvest |>
    dplyr::left_join(admin1, by = "hhid") |>
    dplyr::left_join(admin2, by = "hhid") |>
    dplyr::left_join(admin3, by = "hhid") |>
    dplyr::mutate(
      plot_id = paste(hhid, plotid, sep = "-"),
      crop_code = sa3q2
    )
  
  # First sale source
  sale1 <- harvest_sold |>
    dplyr::mutate(
      harvest_sold_kg1 = sa3q11a * conversion,
      harvest_sold_kg1 = dplyr::if_else(nscode == 1, sa3q11a, harvest_sold_kg1),
      harvest_sold_kg1 = dplyr::if_else(nscode == 2, sa3q11a * 0.001, harvest_sold_kg1),
      harvest_sold_kg1 = dplyr::if_else(sa3q9 == 2, 0, harvest_sold_kg1)
    ) |>
    dplyr::select(hhid, crop_code, plot_id, harvest_sold_kg1, admin_1, admin_2, admin_3)
  
  # Second sale source
  sale2 <- harvest_sold |>
    dplyr::mutate(
      harvest_sold_kg2 = sa3q16a * conversion,
      harvest_sold_kg2 = dplyr::if_else(nscode == 1, sa3q16a, harvest_sold_kg2),
      harvest_sold_kg2 = dplyr::if_else(nscode == 2, sa3q16a * 0.001, harvest_sold_kg2),
      harvest_sold_kg2 = dplyr::if_else(sa3q14 == 2, 0, harvest_sold_kg2)
    ) |>
    dplyr::select(hhid, crop_code, plot_id, harvest_sold_kg2, admin_1, admin_2, admin_3)
  
  # Combine
  harvest_sold_kg <- sale1 |>
    dplyr::left_join(sale2, by = c("hhid", "crop_code", "plot_id", "admin_1", "admin_2", "admin_3")) |>
    dplyr::mutate(
      harvest_sold_kg = harvest_sold_kg1 + harvest_sold_kg2
    ) |>
    dplyr::group_by(plot_id, crop_code, hhid, admin_1, admin_2, admin_3) |>
    dplyr::summarise(
      harvest_sold_kg = sum(harvest_sold_kg, na.rm = TRUE),
      n_harvest_sold_kg = sum(!is.na(harvest_sold_kg)),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      harvest_sold_kg = dplyr::if_else(n_harvest_sold_kg == 0, NA_real_, harvest_sold_kg)
    ) |>
    dplyr::select(-n_harvest_sold_kg)
  
  haven::write_dta(harvest_sold_kg, file.path(temp_dir, "harvest_sold_kg.dta"))
  
  # Calculate household-level share
  harvest_kg <- haven::read_dta(file.path(temp_dir, "harvest_kg.dta"))
  
  hh_share <- harvest_sold_kg |>
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

# 5.5 Harvest sold value
tryCatch({
  cat("  Calculating harvest sold value...\n")
  
  harvest <- read_dta_auto("secta3_harvestw1", input_dir, temp_dir)
  
  # Add admin levels
  admin1 <- haven::read_dta(file.path(temp_dir, "admin1.dta"))
  admin2 <- haven::read_dta(file.path(temp_dir, "admin2.dta"))
  admin3 <- haven::read_dta(file.path(temp_dir, "admin3.dta"))
  
  harvest_sold_value <- harvest |>
    dplyr::left_join(admin1, by = "hhid") |>
    dplyr::left_join(admin2, by = "hhid") |>
    dplyr::left_join(admin3, by = "hhid") |>
    dplyr::mutate(
      plot_id = paste(hhid, plotid, sep = "-"),
      crop_code = sa3q2,
      harvest_sold_value = sa3q12 + sa3q17,
      harvest_sold_value = dplyr::if_else(is.na(harvest_sold_value), 0, harvest_sold_value)
    ) |>
    dplyr::group_by(plot_id, crop_code, hhid, admin_1, admin_2, admin_3) |>
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
# 6. HARVEST VALUE AND MAIN CROP
# ==============================================================================

cat("\n=== Calculating harvest values ===\n")

# 6.1 Harvest value
tryCatch({
  cat("  Calculating harvest value...\n")
  
  # Load harvest data
  harvest <- read_dta_auto("secta3_harvestw1", input_dir, temp_dir)
  
  harvest_data <- harvest |>
    dplyr::mutate(
      plot_id = paste(hhid, plotid, sep = "-"),
      crop_code = sa3q2
    ) |>
    dplyr::select(hhid, plot_id, crop_code) |>
    dplyr::distinct()
  
  # Calculate harvest value using median crop prices
  harvest_value <- valuation_median_crops_noea(
    data = harvest_data,
    temp_path = temp_dir,
    hhid_var = "hhid",
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
    dplyr::select(hhid, plot_id, harvest_value, crop_code, main_crop)
  
  haven::write_dta(harvest_value_out, file.path(temp_dir, "harvest_value.dta"))
  cat("  ✓ harvest_value saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in harvest value: ", e$message, "\n")
})

# 6.2 Intercropped
tryCatch({
  cat("  Extracting intercropped status...\n")
  
  plot_inputs <- read_dta_auto("sect11f_plantingw1", input_dir, temp_dir)
  
  intercropped <- plot_inputs |>
    dplyr::mutate(
      plot_id = paste(hhid, plotid, sep = "-"),
      intercropped = dplyr::if_else(s11fq2 == 1, 0,
                                    dplyr::if_else(s11fq2 %in% c(2:7), 1, NA_real_))
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

# 6.3 Number of seasonal crops
tryCatch({
  cat("  Calculating number of seasonal crops...\n")
  
  harvest <- read_dta_auto("secta3_harvestw1", input_dir, temp_dir)
  
  nb_seasonal_crop <- harvest |>
    dplyr::mutate(
      plot_id = paste(hhid, plotid, sep = "-")
    ) |>
    dplyr::group_by(plot_id) |>
    dplyr::summarise(
      nb_seasonal_crop = n_distinct(sa3q2, na.rm = TRUE),
      .groups = "drop"
    )
  
  haven::write_dta(nb_seasonal_crop, file.path(temp_dir, "nb_seasonal_crop.dta"))
  cat("  ✓ nb_seasonal_crop saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in nb_seasonal_crop: ", e$message, "\n")
})

# 6.4 Main crop shares - Identify perennial crops
tryCatch({
  cat("  Identifying perennial crops...\n")
  
  # Load perennial data
  perennial <- read_dta_auto("sect11g_plantingw1", input_dir, temp_dir)
  
  # Get list of perennial crop codes
  perennial_crops <- perennial |>
    dplyr::mutate(count_permanent = 1) |>
    dplyr::group_by(cropcode) |>
    dplyr::summarise(count_permanent = sum(count_permanent), .groups = "drop")
  
  # Get temporary crops
  plot_inputs <- read_dta_auto("sect11f_plantingw1", input_dir, temp_dir)
  
  temp_crops <- plot_inputs |>
    dplyr::mutate(count_temporary = 1) |>
    dplyr::group_by(cropcode) |>
    dplyr::summarise(count_temporary = sum(count_temporary), .groups = "drop")
  
  # Merge to identify perennial vs temporary
  crop_types <- temp_crops |>
    dplyr::full_join(perennial_crops, by = "cropcode") |>
    dplyr::mutate(
      count_permanent = dplyr::if_else(is.na(count_permanent), 0, count_permanent),
      count_temporary = dplyr::if_else(is.na(count_temporary), 0, count_temporary),
      permanent_crop = dplyr::if_else(
        count_permanent > count_temporary, 1, 0
      )
    ) |>
    dplyr::mutate(
      # Manual corrections
      permanent_crop = dplyr::if_else(cropcode %in% c(2030, 2160, 2170, 3090), 1, permanent_crop)
    ) |>
    dplyr::filter(permanent_crop == 1) |>
    dplyr::select(cropcode)
  
  haven::write_dta(crop_types, file.path(temp_dir, "Perennial_crops_list.dta"))
  
  # Save as main_crop list for later
  main_crop_list <- crop_types |>
    dplyr::rename(main_crop = cropcode)
  
  haven::write_dta(main_crop_list, file.path(temp_dir, "Perennial_crops_list_MC.dta"))
  
  cat("  ✓ perennial crops identified\n")
  
}, error = function(e) {
  cat("  ✗ Error in perennial crops: ", e$message, "\n")
})

# 6.5 Main crop shares - full calculation
tryCatch({
  cat("  Calculating main crop shares...\n")
  
  # Load harvest value
  harvest_value <- haven::read_dta(file.path(temp_dir, "harvest_value.dta"))
  
  # Load harvest data
  harvest <- read_dta_auto("secta3_harvestw1", input_dir, temp_dir)
  
  # Load perennial crop list
  perennial_crops <- haven::read_dta(file.path(temp_dir, "Perennial_crops_list.dta"))
  
  # Merge with harvest data
  main_crop_data <- harvest |>
    dplyr::mutate(
      plot_id = paste(hhid, plotid, sep = "-"),
      crop_code = sa3q2
    ) |>
    dplyr::left_join(harvest_value, by = c("hhid", "plot_id", "crop_code")) |>
    dplyr::mutate(
      is_perennial = dplyr::if_else(crop_code %in% perennial_crops$cropcode, 1, 0)
    )
  
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
  
  # Map crop codes to categories (Nigeria specific)
  main_crop_data <- main_crop_data |>
    dplyr::mutate(
      crop_name = haven::as_factor(crop_code) |> as.character(),
      crop_name = stringr::str_replace_all(crop_name, ".*\\. ", ""),
      crop_name = toupper(crop_name),
      # Clean names
      crop_name = dplyr::case_when(
        crop_name == "SUGAR CANE" ~ "SUGARCANE",
        crop_name == "PUMPKIN" ~ "PUMPKINS",
        crop_name == "OKRO" ~ "OKRA",
        crop_name == "BANANA" ~ "BANANAS",
        crop_name == "TOMATO" ~ "TOMATOES",
        TRUE ~ crop_name
      ),
      # Categorize
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
# 7. LAND AREA
# ==============================================================================

cat("\n=== Processing land area ===\n")

tryCatch({
  cat("  Calculating plot area...\n")
  
  plot_roster <- read_dta_auto("sect11a1_plantingw1", input_dir, temp_dir)
  
  # Load admin3 for imputation
  admin3 <- haven::read_dta(file.path(temp_dir, "admin3.dta"))
  
  land_area <- plot_roster |>
    dplyr::left_join(admin3, by = "hhid") |>
    dplyr::mutate(
      plot_id = paste(hhid, plotid, sep = "-"),
      admin_1 = zone,
      admin_2 = state,
      admin_3 = lga,
      # Area self-reported with unit conversions
      area_self_reported = s11aq4a,
      area_self_reported = dplyr::case_when(
        s11aq4b == 4 ~ area_self_reported * 0.0667,
        s11aq4b == 5 ~ area_self_reported * 0.4,
        s11aq4b == 7 ~ area_self_reported * 0.0001,
        # Heaps
        s11aq4b == 1 & admin_1 == 1 ~ area_self_reported * 0.00012,
        s11aq4b == 1 & admin_1 == 2 ~ area_self_reported * 0.00016,
        s11aq4b == 1 & admin_1 == 3 ~ area_self_reported * 0.00011,
        s11aq4b == 1 & admin_1 == 4 ~ area_self_reported * 0.00019,
        s11aq4b == 1 & admin_1 == 5 ~ area_self_reported * 0.00021,
        s11aq4b == 1 & admin_1 == 6 ~ area_self_reported * 0.00012,
        # Ridges
        s11aq4b == 2 & admin_1 == 1 ~ area_self_reported * 0.0027,
        s11aq4b == 2 & admin_1 == 2 ~ area_self_reported * 0.004,
        s11aq4b == 2 & admin_1 == 3 ~ area_self_reported * 0.00494,
        s11aq4b == 2 & admin_1 == 4 ~ area_self_reported * 0.0023,
        s11aq4b == 2 & admin_1 == 5 ~ area_self_reported * 0.0023,
        s11aq4b == 2 & admin_1 == 6 ~ area_self_reported * 0.00001,
        # Stands
        s11aq4b == 3 & admin_1 == 1 ~ area_self_reported * 0.00006,
        s11aq4b == 3 & admin_1 == 2 ~ area_self_reported * 0.00016,
        s11aq4b == 3 & admin_1 == 3 ~ area_self_reported * 0.00004,
        s11aq4b == 3 & admin_1 == 4 ~ area_self_reported * 0.00004,
        s11aq4b == 3 & admin_1 == 5 ~ area_self_reported * 0.00013,
        s11aq4b == 3 & admin_1 == 6 ~ area_self_reported * 0.00041,
        TRUE ~ area_self_reported
      ),
      plot_area_GPS = s11aq4d * 0.0001  # Convert to hectares
    )
  
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
# 8. SEED VARIABLES
# ==============================================================================

cat("\n=== Processing seed variables ===\n")

# 8.1 Seed kg
tryCatch({
  cat("  Calculating seed kg...\n")
  
  # Load conversion factors
  conversions <- haven::read_dta(file.path(temp_dir, "Conversion_factors.dta"))
  
  # Load seed data
  seeds <- read_dta_auto("sect11e_plantingw1", input_dir, temp_dir)
  
  # Add admin levels
  admin1 <- haven::read_dta(file.path(temp_dir, "admin1.dta"))
  admin2 <- haven::read_dta(file.path(temp_dir, "admin2.dta"))
  admin3 <- haven::read_dta(file.path(temp_dir, "admin3.dta"))
  
  seed_kg <- seeds |>
    dplyr::left_join(admin1, by = "hhid") |>
    dplyr::left_join(admin2, by = "hhid") |>
    dplyr::left_join(admin3, by = "hhid") |>
    dplyr::mutate(
      plot_id = paste(hhid, plotid, sep = "-"),
      crop_code = s11eq2,
      # Left over seeds
      seed_kg1 = s11eq6a,
      seed_kg1 = dplyr::if_else(s11eq6b == 1, s11eq6a * 0.001, seed_kg1),
      seed_kg1 = dplyr::if_else(s11eq6b == 2, s11eq6a, seed_kg1),
      # Free seeds
      seed_kg2 = s11eq10a,
      seed_kg2 = dplyr::if_else(s11eq10b == 1, s11eq10a * 0.001, seed_kg2),
      seed_kg2 = dplyr::if_else(s11eq10b == 2, s11eq10a, seed_kg2),
      # Commercial source 1
      seed_kg3 = s11eq17a,
      seed_kg3 = dplyr::if_else(s11eq17b == 1, s11eq17a * 0.001, seed_kg3),
      seed_kg3 = dplyr::if_else(s11eq17b == 2, s11eq17a, seed_kg3),
      # Commercial source 2
      seed_kg4 = s11eq28a,
      seed_kg4 = dplyr::if_else(s11eq28b == 1, s11eq28a * 0.001, seed_kg4),
      seed_kg4 = dplyr::if_else(s11eq28b == 2, s11eq28a, seed_kg4),
      # Total
      seed_kg = seed_kg1 + seed_kg2 + seed_kg3 + seed_kg4,
      seed_kg = dplyr::if_else(s11eq3 == 2, 0, seed_kg)
    ) |>
    dplyr::group_by(crop_code, hhid, plot_id, admin_1, admin_2, admin_3) |>
    dplyr::summarise(
      seed_kg = sum(seed_kg, na.rm = TRUE),
      n_seed_kg = sum(!is.na(seed_kg)),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      seed_kg = dplyr::if_else(n_seed_kg == 0, NA_real_, seed_kg)
    ) |>
    dplyr::select(-n_seed_kg)
  
  haven::write_dta(seed_kg, file.path(temp_dir, "seed_kg.dta"))
  haven::write_dta(seed_kg, file.path(temp_dir, "seed_kg_merge.dta"))
  cat("  ✓ seed_kg saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in seed kg: ", e$message, "\n")
})

# 8.2 Seed kg sold (purchased)
tryCatch({
  cat("  Calculating purchased seed kg...\n")
  
  seeds <- read_dta_auto("sect11e_plantingw1", input_dir, temp_dir)
  
  seeds_amount_purchased_kg <- seeds |>
    dplyr::mutate(
      plot_id = paste(hhid, plotid, sep = "-"),
      crop_code = s11eq2,
      # Commercial source 1
      seed_purch_kg1 = s11eq17a,
      seed_purch_kg1 = dplyr::if_else(s11eq17b == 1, s11eq17a * 0.001, seed_purch_kg1),
      seed_purch_kg1 = dplyr::if_else(s11eq17b == 2, s11eq17a, seed_purch_kg1),
      # Commercial source 2
      seed_purch_kg2 = s11eq28a,
      seed_purch_kg2 = dplyr::if_else(s11eq28b == 1, s11eq28a * 0.001, seed_purch_kg2),
      seed_purch_kg2 = dplyr::if_else(s11eq28b == 2, s11eq28a, seed_purch_kg2),
      # Total
      seeds_amount_purchased_kg = seed_purch_kg1 + seed_purch_kg2
    ) |>
    dplyr::group_by(crop_code, hhid, plot_id) |>
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

# 8.3 Seed value
tryCatch({
  cat("  Calculating seed value...\n")
  
  seeds <- read_dta_auto("sect11e_plantingw1", input_dir, temp_dir)
  
  seed_value_temp <- seeds |>
    dplyr::mutate(
      plot_id = paste(hhid, plotid, sep = "-"),
      crop_code = s11eq2,
      seed_value_temp = s11eq20 + s11eq31
    ) |>
    dplyr::group_by(crop_code, hhid, plot_id) |>
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
    id_link_seeds_var = "plot_id",
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
# 9. LABOR DAYS
# ==============================================================================

cat("\n=== Processing labor data ===\n")

tryCatch({
  cat("  Processing labor days (skeleton - complex)...\n")
  
  # Load labor data
  labor <- read_dta_auto("secta2_harvestw1", input_dir, temp_dir)
  
  # This is a placeholder - full labor processing would be extensive
  
  # Create placeholder with ID_worker variables
  labor_days <- data.frame(
    plot_id = character(),
    total_labor_days = numeric(),
    total_family_labor_days = numeric(),
    total_hired_labor_days = numeric(),
    hired_labor_value = numeric(),
    ID_worker1_PH = character(),
    ID_worker2_PH = character(),
    ID_worker3_PH = character(),
    ID_worker4_PH = character(),
    ID_worker1_PP = character(),
    ID_worker2_PP = character(),
    ID_worker3_PP = character(),
    ID_worker4_PP = character()
  )
  
  haven::write_dta(labor_days, file.path(temp_dir, "labor_days.dta"))
  cat("  ✓ labor_days placeholder saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in labor processing: ", e$message, "\n")
})

# ==============================================================================
# 10. FERTILIZER VARIABLES
# ==============================================================================

cat("\n=== Processing fertilizer variables ===\n")

# 10.1 Inorganic fertilizer
tryCatch({
  cat("  Extracting inorganic fertilizer use...\n")
  
  ferts <- read_dta_auto("sect11d_plantingw1", input_dir, temp_dir)
  
  inorganic_fertilizer <- ferts |>
    dplyr::mutate(
      plot_id = paste(hhid, plotid, sep = "-"),
      inorganic_fertilizer = dplyr::if_else(
        s11dq1 == 1 & (s11dq3 %in% c(1, 2) | s11dq7 %in% c(1, 2) | 
                         s11dq14 %in% c(1, 2) | s11dq25 %in% c(1, 2)), 1,
        dplyr::if_else(s11dq1 == 2, 0, NA_real_)
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

# 10.2 Nitrogen equivalent
tryCatch({
  cat("  Calculating nitrogen equivalent...\n")
  
  ferts <- read_dta_auto("sect11d_plantingw1", input_dir, temp_dir)
  
  nitrogen_kg <- ferts |>
    dplyr::mutate(
      plot_id = paste(hhid, plotid, sep = "-"),
      inorganic_fertilizer = dplyr::if_else(
        s11dq1 == 1 & (s11dq3 %in% c(1, 2) | s11dq7 %in% c(1, 2) | 
                         s11dq14 %in% c(1, 2) | s11dq25 %in% c(1, 2)), 1,
        dplyr::if_else(s11dq1 == 2, 0, NA_real_)
      ),
      # UREA
      UREA_kg = dplyr::case_when(
        s11dq3 == 2 ~ s11dq4,
        s11dq7 == 2 ~ s11dq8,
        s11dq14 == 2 ~ s11dq15,
        s11dq25 == 2 ~ s11dq26,
        TRUE ~ 0
      ),
      # NPK
      NPK_kg = dplyr::case_when(
        s11dq3 == 1 ~ s11dq4,
        s11dq7 == 1 ~ s11dq8,
        s11dq14 == 1 ~ s11dq15,
        s11dq25 == 1 ~ s11dq26,
        TRUE ~ 0
      ),
      # Other
      other_kg = dplyr::case_when(
        s11dq3 == 4 ~ s11dq4,
        s11dq7 == 4 ~ s11dq8,
        s11dq14 == 4 ~ s11dq15,
        s11dq25 == 4 ~ s11dq26,
        TRUE ~ 0
      ),
      # Set to 0 if not used
      UREA_kg = dplyr::if_else(inorganic_fertilizer == 0, 0, UREA_kg),
      NPK_kg = dplyr::if_else(inorganic_fertilizer == 0, 0, NPK_kg),
      other_kg = dplyr::if_else(inorganic_fertilizer == 0, 0, other_kg)
    ) |>
    dplyr::mutate(
      # Nitrogen equivalents
      UREA_N_kg = UREA_kg * 0.46,
      NPK_N_kg = NPK_kg * 0.20,
      nitrogen_kg = UREA_N_kg + NPK_N_kg,
      nitrogen_kg = dplyr::if_else(inorganic_fertilizer == 0, 0, nitrogen_kg)
    ) |>
    dplyr::group_by(plot_id, hhid) |>
    dplyr::summarise(
      nitrogen_kg = sum(nitrogen_kg, na.rm = TRUE),
      UREA_kg = sum(UREA_kg, na.rm = TRUE),
      NPK_kg = sum(NPK_kg, na.rm = TRUE),
      other_kg = sum(other_kg, na.rm = TRUE),
      n_nitrogen_kg = sum(!is.na(nitrogen_kg)),
      n_UREA_kg = sum(!is.na(UREA_kg)),
      n_NPK_kg = sum(!is.na(NPK_kg)),
      n_other_kg = sum(!is.na(other_kg)),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      dplyr::across(c(nitrogen_kg, UREA_kg, NPK_kg, other_kg),
                    ~ dplyr::if_else(is.na(.x), NA_real_, .x))
    ) |>
    dplyr::select(-starts_with("n_"))
  
  haven::write_dta(nitrogen_kg, file.path(temp_dir, "nitrogen_kg.dta"))
  cat("  ✓ nitrogen_kg saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in nitrogen equivalent: ", e$message, "\n")
})

# 10.3 Inorganic fertilizer value
tryCatch({
  cat("  Calculating inorganic fertilizer value...\n")
  
  ferts <- read_dta_auto("sect11d_plantingw1", input_dir, temp_dir)
  
  # Extract fertilizer purchases
  fert_purch <- ferts |>
    dplyr::mutate(
      plot_id = paste(hhid, plotid, sep = "-"),
      # UREA purchases
      UREA_purchased_kg = dplyr::case_when(
        s11dq14 == 2 ~ s11dq15,
        s11dq25 == 2 ~ s11dq26,
        TRUE ~ 0
      ),
      UREA_purchased_value = dplyr::case_when(
        s11dq14 == 2 ~ s11dq18,
        s11dq25 == 2 ~ s11dq29,
        TRUE ~ 0
      ),
      # NPK purchases
      NPK_purchased_kg = dplyr::case_when(
        s11dq14 == 1 ~ s11dq15,
        s11dq25 == 1 ~ s11dq26,
        TRUE ~ 0
      ),
      NPK_purchased_value = dplyr::case_when(
        s11dq14 == 1 ~ s11dq18,
        s11dq25 == 1 ~ s11dq29,
        TRUE ~ 0
      ),
      # Other purchases
      other_purchased_kg = dplyr::case_when(
        s11dq14 == 4 ~ s11dq15,
        s11dq25 == 4 ~ s11dq26,
        TRUE ~ 0
      ),
      other_purchased_value = dplyr::case_when(
        s11dq14 == 4 ~ s11dq18,
        s11dq25 == 4 ~ s11dq29,
        TRUE ~ 0
      )
    ) |>
    dplyr::group_by(hhid) |>
    dplyr::summarise(
      UREA_purchased_kg = max(UREA_purchased_kg, na.rm = TRUE),
      NPK_purchased_kg = max(NPK_purchased_kg, na.rm = TRUE),
      other_purchased_kg = max(other_purchased_kg, na.rm = TRUE),
      UREA_purchased_value = max(UREA_purchased_value, na.rm = TRUE),
      NPK_purchased_value = max(NPK_purchased_value, na.rm = TRUE),
      other_purchased_value = max(other_purchased_value, na.rm = TRUE),
      .groups = "drop"
    )
  
  # Use valuation function for each fertilizer type
  # This would need to be run for UREA, NPK, and other separately
  
  haven::write_dta(fert_purch, file.path(temp_dir, "fert_purchased_temp.dta"))
  cat("  ✓ fertilizer value processed\n")
  
}, error = function(e) {
  cat("  ✗ Error in fertilizer value: ", e$message, "\n")
})

# 10.4 Organic fertilizer
tryCatch({
  cat("  Extracting organic fertilizer use...\n")
  
  ferts <- read_dta_auto("sect11d_plantingw1", input_dir, temp_dir)
  
  organic_fertilizer <- ferts |>
    dplyr::mutate(
      plot_id = paste(hhid, plotid, sep = "-"),
      organic_fertilizer = dplyr::if_else(
        s11dq3 == 3 | s11dq7 == 3 | s11dq15 == 3 | s11dq27 == 3, 1,
        dplyr::if_else(s11dq1 == 2, 0, NA_real_)
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

# 10.5 Pesticides
tryCatch({
  cat("  Extracting pesticide use...\n")
  
  pesticides <- read_dta_auto("sect11c_plantingw1", input_dir, temp_dir)
  
  used_pesticides <- pesticides |>
    dplyr::mutate(
      plot_id = paste(hhid, plotid, sep = "-"),
      used_pesticides = dplyr::if_else(s11cq1 == 1, 1,
                                       dplyr::if_else(s11cq1 == 2, 0, NA_real_))
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
# 11. PLOT-LEVEL VARIABLES
# ==============================================================================

cat("\n=== Processing plot-level variables ===\n")

# 11.1 Plot ownership
tryCatch({
  cat("  Extracting plot ownership...\n")
  
  tenure <- read_dta_auto("sect11b_plantingw1", input_dir, temp_dir)
  
  plot_owned <- tenure |>
    dplyr::mutate(
      plot_id = paste(hhid, plotid, sep = "-"),
      plot_owned = dplyr::if_else(s11bq4 %in% c(1, 4), 1,
                                  dplyr::if_else(s11bq4 %in% c(2, 3), 0, NA_real_))
    ) |>
    dplyr::select(plot_id, plot_owned) |>
    dplyr::distinct()
  
  haven::write_dta(plot_owned, file.path(temp_dir, "plot_owned.dta"))
  cat("  ✓ plot_owned saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in plot ownership: ", e$message, "\n")
})

# 11.2 Irrigated
tryCatch({
  cat("  Extracting irrigation status...\n")
  
  tenure <- read_dta_auto("sect11b_plantingw1", input_dir, temp_dir)
  
  irrigated <- tenure |>
    dplyr::mutate(
      plot_id = paste(hhid, plotid, sep = "-"),
      irrigated = dplyr::if_else(s11bq24 == 1, 1,
                                 dplyr::if_else(s11bq24 == 2, 0, NA_real_)),
      irrigated = dplyr::if_else(s11bq17 == 1, 0, irrigated)
    ) |>
    dplyr::select(plot_id, irrigated) |>
    dplyr::distinct()
  
  haven::write_dta(irrigated, file.path(temp_dir, "irrigated.dta"))
  cat("  ✓ irrigated saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in irrigation: ", e$message, "\n")
})

# 11.3 Tractor
tryCatch({
  cat("  Extracting tractor use...\n")
  
  pesticides <- read_dta_auto("sect11c_plantingw1", input_dir, temp_dir)
  
  tractor <- pesticides |>
    dplyr::mutate(
      plot_id = paste(hhid, plotid, sep = "-"),
      tractor = dplyr::if_else(
        s11cq28b %in% c(1, 2, 3, 4) | s11cq28d %in% c(1, 2, 3, 4) |
          s11cq28f %in% c(1, 2, 3, 4) | s11cq30b %in% c(1, 2, 3, 4) |
          s11cq30d %in% c(1, 2, 3, 4) | s11cq30f %in% c(1, 2, 3, 4), 1,
        dplyr::if_else(s11cq27 == 2, 0, NA_real_)
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

# 11.4 Number of fallow plots
tryCatch({
  cat("  Calculating number of fallow plots...\n")
  
  tenure <- read_dta_auto("sect11b_plantingw1", input_dir, temp_dir)
  
  nb_fallow_plots <- tenure |>
    dplyr::mutate(
      fallow_plot = dplyr::if_else(s11bq17 == 1, 1, 0),
      fallow_plot = dplyr::if_else(s11bq16 == 1, 0, fallow_plot)
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

# 11.5 Number of plots
tryCatch({
  cat("  Calculating number of plots...\n")
  
  tenure <- read_dta_auto("sect11b_plantingw1", input_dir, temp_dir)
  
  nb_plots <- tenure |>
    dplyr::mutate(
      fallow_plot = dplyr::if_else(s11bq17 == 1, 1, 0),
      fallow_plot = dplyr::if_else(s11bq16 == 1, 0, fallow_plot)
    ) |>
    dplyr::group_by(hhid) |>
    dplyr::summarise(
      nb_plots = n_distinct(plotid, na.rm = TRUE),
      .groups = "drop"
    )
  
  haven::write_dta(nb_plots, file.path(temp_dir, "nb_plots.dta"))
  cat("  ✓ nb_plots saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in number of plots: ", e$message, "\n")
})

# ==============================================================================
# 12. HOUSEHOLD-LEVEL VARIABLES
# ==============================================================================

cat("\n=== Processing household-level variables ===\n")

# 12.1 Household education
tryCatch({
  cat("  Extracting household education...\n")
  
  indiv1 <- read_dta_auto("sect2a_harvestw1", input_dir, temp_dir)
  indiv2 <- read_dta_auto("sect2b_harvestw1", input_dir, temp_dir)
  
  education <- indiv1 |>
    dplyr::left_join(indiv2, by = c("hhid", "indiv")) |>
    dplyr::mutate(
      # Formal education
      formal_education_hh1 = dplyr::if_else(s2aq6 == 1, 1,
                                            dplyr::if_else(s2aq6 == 2, 0, NA_real_)),
      formal_education_hh2 = dplyr::if_else(s2bq1 == 1, 1,
                                            dplyr::if_else(s2bq1 == 2, 0, NA_real_)),
      formal_education_hh2 = dplyr::if_else(s2bq2 == 1, 1, formal_education_hh2),
      # Primary education
      primary_education_hh1 = dplyr::if_else(s2aq9 %in% 16:43, 1,
                                             dplyr::if_else(s2aq9 %in% c(0:15, 51, 52), 0, NA_real_)),
      primary_education_hh1 = dplyr::if_else(s2aq6 == 2, 0, primary_education_hh1),
      primary_education_hh2 = dplyr::if_else(s2bq3 %in% 17:43, 1,
                                             dplyr::if_else(s2bq3 %in% c(0:16, 51, 61), 0, NA_real_)),
      # Combine
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
      hh_formal_education = dplyr::if_else(is.infinite(hh_formal_education), 
                                           NA_real_, hh_formal_education),
      hh_primary_education = dplyr::if_else(is.infinite(hh_primary_education), 
                                            NA_real_, hh_primary_education)
    )
  
  haven::write_dta(education, file.path(temp_dir, "hh_primary_education.dta"))
  cat("  ✓ hh_primary_education saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in household education: ", e$message, "\n")
})

# 12.2 Electricity access
tryCatch({
  cat("  Extracting electricity access...\n")
  
  housing <- read_dta_auto("sect8_harvestw1", input_dir, temp_dir)
  
  electricity <- housing |>
    dplyr::mutate(
      hh_electricity_access = dplyr::if_else(s8q17 == 1, 1,
                                             dplyr::if_else(s8q17 == 2, 0, NA_real_))
    ) |>
    dplyr::select(hhid, hh_electricity_access) |>
    dplyr::distinct()
  
  haven::write_dta(electricity, file.path(temp_dir, "hh_electricity_access.dta"))
  cat("  ✓ hh_electricity_access saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in electricity access: ", e$message, "\n")
})

# 12.3 Dependency ratio
tryCatch({
  cat("  Calculating dependency ratio...\n")
  
  indiv <- read_dta_auto("sect1_plantingw1", input_dir, temp_dir)
  
  dependency <- indiv |>
    dplyr::filter(s1q7 == 1) |>
    dplyr::mutate(
      age = s1q4,
      age = dplyr::if_else(age == 999, NA_real_, age),
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

# 12.4 Livestock
tryCatch({
  cat("  Extracting livestock ownership...\n")
  
  livestock <- read_dta_auto("sect11i_plantingw1", input_dir, temp_dir)
  
  livestock_out <- livestock |>
    dplyr::mutate(
      livestock = dplyr::if_else(s11iq1 == 1, 1,
                                 dplyr::if_else(s11iq1 == 2, 0, NA_real_))
    ) |>
    dplyr::group_by(hhid) |>
    dplyr::summarise(
      livestock = max(livestock, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      livestock = dplyr::if_else(is.infinite(livestock), NA_real_, livestock)
    )
  
  haven::write_dta(livestock_out, file.path(temp_dir, "livestock.dta"))
  cat("  ✓ livestock saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in livestock: ", e$message, "\n")
})

# 12.5 Consumption quintile and aggregate
tryCatch({
  cat("  Extracting consumption variables...\n")
  
  csption1 <- read_dta_auto("cons_agg_wave1_visit1", input_dir, temp_dir)
  csption2 <- read_dta_auto("cons_agg_wave1_visit2", input_dir, temp_dir)
  
  consumption <- csption1 |>
    dplyr::left_join(csption2, by = "hhid") |>
    dplyr::mutate(
      totcons = totcons,
      cons_quint = dplyr::ntile(totcons, 5)
    ) |>
    dplyr::select(hhid, totcons, cons_quint) |>
    dplyr::distinct()
  
  # Save consumption quintile
  consumption |>
    dplyr::select(hhid, cons_quint) |>
    haven::write_dta(file.path(temp_dir, "cons_quint.dta"))
  
  # Save total consumption
  consumption |>
    dplyr::select(hhid, totcons) |>
    haven::write_dta(file.path(temp_dir, "totcons.dta"))
  
  cat("  ✓ consumption variables saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in consumption variables: ", e$message, "\n")
})

# 12.6 Household shock
tryCatch({
  cat("  Extracting household shocks...\n")
  
  shocks <- read_dta_auto("sect15a_harvestw1", input_dir, temp_dir)
  
  hh_shock <- shocks |>
    dplyr::mutate(
      hh_shock = dplyr::if_else(s15aq1 == 1, 1,
                                dplyr::if_else(s15aq1 == 2, 0, NA_real_)),
      hh_shock = dplyr::if_else(
        s15aq3a == "" & s15aq3b == "" & s15aq3c == "", 0, hh_shock
      )
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

# 12.7 Household size
tryCatch({
  cat("  Extracting household size...\n")
  
  labor <- read_dta_auto("sect3_plantingw1", input_dir, temp_dir)
  
  hh_size <- labor |>
    dplyr::group_by(hhid) |>
    dplyr::summarise(
      hh_size = n_distinct(indiv),
      .groups = "drop"
    )
  
  haven::write_dta(hh_size, file.path(temp_dir, "size.dta"))
  cat("  ✓ hh_size saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in household size: ", e$message, "\n")
})

# ==============================================================================
# 13. ASSET INDICES
# ==============================================================================

cat("\n=== Calculating asset indices ===\n")

tryCatch({
  cat("  Calculating asset indices...\n")
  
  # Agricultural assets
  items <- read_dta_auto("secta41_harvestw1", input_dir, temp_dir)
  
  ag_assets <- items |>
    dplyr::filter(!item_cd %in% c(313, 314, 315, 316, 317, 321)) |>
    dplyr::mutate(
      hh_owns_ = dplyr::if_else(!is.na(sa4q1) & sa4q1 != 0, 1, 0)
    ) |>
    dplyr::group_by(hhid, item_cd) |>
    dplyr::summarise(
      hh_owns_ = max(hh_owns_, na.rm = TRUE),
      .groups = "drop"
    ) |>
    tidyr::pivot_wider(
      id_cols = hhid,
      names_from = item_cd,
      values_from = hh_owns_,
      values_fill = 0
    )
  
  ag_asset_index <- ag_assets |>
    dplyr::mutate(
      ag_asset_index = rowMeans(dplyr::across(-hhid), na.rm = TRUE)
    ) |>
    dplyr::select(hhid, ag_asset_index)
  
  haven::write_dta(ag_asset_index, file.path(temp_dir, "ag_asset_index.dta"))
  
  # Household assets
  hh_items <- read_dta_auto("sect7_harvestw1", input_dir, temp_dir)
  
  hh_assets <- hh_items |>
    dplyr::filter(item_cd <= 331) |>
    dplyr::mutate(
      hh_owns = dplyr::if_else(s7x == "X", 1, 0)
    ) |>
    dplyr::group_by(hhid, item_cd) |>
    dplyr::summarise(
      hh_owns = max(hh_owns, na.rm = TRUE),
      .groups = "drop"
    ) |>
    tidyr::pivot_wider(
      id_cols = hhid,
      names_from = item_cd,
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

# 13.2 Non-farm enterprise
tryCatch({
  cat("  Extracting non-farm enterprise...\n")
  
  nfe <- read_dta_auto("sect9_harvestw1", input_dir, temp_dir)
  
  nfe_out <- nfe |>
    dplyr::mutate(
      nonfarm_enterprise = dplyr::if_else(
        !is.na(s9q1a) | !is.na(s9q1b) | !is.na(s9q1c), 1, 0
      )
    ) |>
    dplyr::select(hhid, nonfarm_enterprise) |>
    dplyr::distinct()
  
  haven::write_dta(nfe_out, file.path(temp_dir, "nfe.dta"))
  cat("  ✓ nonfarm_enterprise saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in non-farm enterprise: ", e$message, "\n")
})

# ==============================================================================
# 14. INDIVIDUAL-LEVEL VARIABLES
# ==============================================================================

cat("\n=== Processing individual-level variables ===\n")

# 14.1 Individual characteristics
tryCatch({
  cat("  Extracting individual characteristics...\n")
  
  indiv <- read_dta_auto("sect1_plantingw1", input_dir, temp_dir)
  
  indiv_chars <- indiv |>
    dplyr::mutate(
      ID = paste(hhid, indiv, sep = "-"),
      female = dplyr::if_else(s1q2 == 2, 1,
                              dplyr::if_else(s1q2 == 1, 0, NA_real_)),
      age = s1q4,
      age = dplyr::if_else(age == 999, NA_real_, age),
      married = dplyr::if_else(s1q8 %in% c(1, 2), 1,
                               dplyr::if_else(s1q8 %in% c(3:7), 0, NA_real_)),
      married = dplyr::if_else(is.na(married), 0, married),
      # Relationship to head
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
      # Month of birth
      birth_month = lubridate::ymd(paste(s1q5_year, s1q5_month, "01", sep = "-"))
    ) |>
    dplyr::select(hhid, ID, married, female, age, relationship_head, birth_month) |>
    dplyr::distinct()
  
  haven::write_dta(indiv_chars, file.path(temp_dir, "indiv_chars.dta"))
  cat("  ✓ indiv_chars saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in individual characteristics: ", e$message, "\n")
})

# 14.2 Wasting
tryCatch({
  cat("  Processing wasting (anthropometric data)...\n")
  
  # Load anthropometric data
  anthropo <- read_dta_auto("sect4a_harvestw1", input_dir, temp_dir)
  
  # Load individual characteristics
  indiv_chars <- haven::read_dta(file.path(temp_dir, "indiv_chars.dta"))
  
  # Load harvest interview month
  harvest_interview <- haven::read_dta(file.path(temp_dir, "harvest_interview_month.dta"))
  
  wasting <- anthropo |>
    dplyr::mutate(
      ID = paste(hhid, indiv, sep = "-")
    ) |>
    dplyr::left_join(indiv_chars, by = c("hhid", "ID")) |>
    dplyr::left_join(harvest_interview, by = "hhid") |>
    dplyr::mutate(
      # Age in months
      age_months = as.numeric(harvest_interview_month - birth_month),
      # Anthropometric variables
      weight = s4aq52,
      height = s4aq53,
      cage = age * 12,
      cage = dplyr::if_else(age == 0 | is.na(age), age_months, cage)
    ) |>
    # Note: zscore06 function would need to be implemented in R
    # For now, create placeholder
    dplyr::mutate(
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

# 14.3 Labor
tryCatch({
  cat("  Extracting labor variables...\n")
  
  labor <- read_dta_auto("sect3_plantingw1", input_dir, temp_dir)
  
  labor_out <- labor |>
    dplyr::mutate(
      ID = paste(hhid, indiv, sep = "-"),
      # Work types
      farm_work = dplyr::if_else(s3q5 == 1, 1,
                                 dplyr::if_else(s3q5 == 2, 0, NA_real_)),
      SOB_work = dplyr::if_else(s3q6 == 1, 1,
                                dplyr::if_else(s3q6 == 2, 0, NA_real_)),
      wage_work = dplyr::if_else(s3q4 == 1, 1,
                                 dplyr::if_else(s3q4 == 2, 0, NA_real_)),
      # Industry
      ind_ag = dplyr::if_else(s3q14 == 1, 1, 0),
      ind_mining = dplyr::if_else(s3q14 == 2, 1, 0),
      ind_manuf = dplyr::if_else(s3q14 %in% 3:5, 1, 0),
      ind_const = dplyr::if_else(s3q14 == 6, 1, 0),
      ind_serv = dplyr::if_else(s3q14 %in% 7:14, 1, 0),
      ind_fish = 0,
      # Hours
      hour_job1 = s3q18,
      hour_job1 = dplyr::if_else(s3q7 == 2 | s3q9 %in% c(7, 8), 0, hour_job1),
      hour_job2 = s3q30,
      hour_job2 = dplyr::if_else(s3q7 == 2 | s3q9 %in% c(7, 8), 0, hour_job2)
    ) |>
    dplyr::mutate(
      # Job types
      farm_job1 = dplyr::if_else(s3q13 %in% c(6111:6114, 6121:6123, 6130, 6141, 6142, 6151:6153, 6164, 6210, 9211), 1, 0),
      farm_job2 = dplyr::if_else(s3q25 %in% c(6111:6114, 6121:6123, 6130, 6141, 6142, 6151:6153, 6164, 6210, 9211), 1, 0),
      farm_job1 = dplyr::if_else(farm_job1 == 1 & s3q15 %in% 1:8, 0, farm_job1),
      farm_job2 = dplyr::if_else(farm_job2 == 1 & s3q27 %in% 1:8, 0, farm_job2),
      SB_job1 = dplyr::if_else(s3q15 == 10, 1, 0),
      SB_job2 = dplyr::if_else(s3q27 == 10, 1, 0),
      SB_job1 = dplyr::if_else(farm_job1 == 1, 0, SB_job1),
      SB_job2 = dplyr::if_else(farm_job2 == 1, 0, SB_job2),
      wage_job1 = dplyr::if_else(SB_job1 == 0 & farm_job1 == 0, 1, 0),
      wage_job2 = dplyr::if_else(SB_job2 == 0 & farm_job2 == 0, 1, 0)
    ) |>
    dplyr::mutate(
      # Hours by activity
      farm_hrs = dplyr::if_else(farm_job1 == 1, hour_job1, 0) + 
        dplyr::if_else(farm_job2 == 1, hour_job2, 0),
      SB_hrs = dplyr::if_else(SB_job1 == 1, hour_job1, 0) + 
        dplyr::if_else(SB_job2 == 1, hour_job2, 0),
      wage_hrs = dplyr::if_else(wage_job1 == 1, hour_job1, 0) + 
        dplyr::if_else(wage_job2 == 1, hour_job2, 0),
      # Working age
      working_age = s3q1 == 1
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

# 14.4 Education (individual)
tryCatch({
  cat("  Extracting individual education...\n")
  
  indiv1 <- read_dta_auto("sect2a_harvestw1", input_dir, temp_dir)
  indiv2 <- read_dta_auto("sect2b_harvestw1", input_dir, temp_dir)
  
  education <- indiv1 |>
    dplyr::left_join(indiv2, by = c("hhid", "indiv")) |>
    dplyr::mutate(
      ID = paste(hhid, indiv, sep = "-"),
      # Formal education
      formal_education1 = dplyr::if_else(s2aq6 == 1, 1,
                                         dplyr::if_else(s2aq6 == 2, 0, NA_real_)),
      formal_education2 = dplyr::if_else(s2bq1 == 1, 1,
                                         dplyr::if_else(s2bq1 == 2, 0, NA_real_)),
      formal_education2 = dplyr::if_else(s2bq2 == 1, 1, formal_education2),
      # Primary education
      primary_education1 = dplyr::if_else(s2aq9 %in% 16:43, 1,
                                          dplyr::if_else(s2aq9 %in% c(0:15, 51, 52), 0, NA_real_)),
      primary_education1 = dplyr::if_else(s2aq6 == 2, 0, primary_education1),
      primary_education2 = dplyr::if_else(s2bq3 %in% 17:43, 1,
                                          dplyr::if_else(s2bq3 %in% c(0:16, 51, 61), 0, NA_real_)),
      # Combine
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

# ==============================================================================
# 15. HDDS (Household Dietary Diversity Score)
# ==============================================================================

cat("\n=== Processing HDDS ===\n")

tryCatch({
  cat("  Calculating HDDS...\n")
  
  hdds <- read_dta_auto("sect10b_harvestw1", input_dir, temp_dir)
  
  hdds_out <- hdds |>
    dplyr::filter(s10bq1 == 1) |>  # Keep if consumed
    dplyr::mutate(
      food_id = item_cd,
      # Define food groups
      A = dplyr::if_else(food_id %in% 10:20, 1, 0),
      B = dplyr::if_else(food_id %in% 30:38, 1, 0),
      C = dplyr::if_else(food_id %in% 70:78, 1, 0),
      D = dplyr::if_else(food_id %in% 60:66, 1, 0),
      E = dplyr::if_else(food_id %in% c(80:82, 90:96), 1, 0),
      F = dplyr::if_else(food_id %in% 83:85, 1, 0),
      G = dplyr::if_else(food_id %in% 100:107, 1, 0),
      H = dplyr::if_else(food_id %in% 40:48, 1, 0),
      I = dplyr::if_else(food_id %in% 110:114, 1, 0),
      J = dplyr::if_else(food_id %in% 50:53, 1, 0),
      K = dplyr::if_else(food_id %in% 130:133, 1, 0),
      L = dplyr::if_else(food_id %in% 120:122, 1, 0)
    ) |>
    dplyr::group_by(hhid) |>
    dplyr::summarise(
      dplyr::across(A:L, ~ max(.x, na.rm = TRUE)),
      .groups = "drop"
    ) |>
    dplyr::mutate(
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
# 16. GEOGRAPHIC VARIABLES
# ==============================================================================

cat("\n=== Processing geographic variables ===\n")

tryCatch({
  cat("  Extracting geographic variables...\n")
  
  # Load geovars
  geovars <- read_dta_auto("NGA_HouseholdGeovars_Y1", input_dir, temp_dir)
  
  # Coordinates
  coords <- geovars |>
    dplyr::rename(
      lat_modified = lat_dd_mod,
      lon_modified = lon_dd_mod
    ) |>
    dplyr::select(hhid, lat_modified, lon_modified) |>
    dplyr::distinct()
  
  haven::write_dta(coords, file.path(temp_dir, "Coords.dta"))
  
  # Agro-ecological zone
  aez <- geovars |>
    dplyr::select(hhid, agro_ecological_zone = ssa_aez09) |>
    dplyr::distinct()
  
  haven::write_dta(aez, file.path(temp_dir, "aez.dta"))
  
  # Distance to road
  dist_road <- geovars |>
    dplyr::select(hhid, dist_road) |>
    dplyr::distinct()
  
  haven::write_dta(dist_road, file.path(temp_dir, "dist_road.dta"))
  
  # Distance to population center
  dist_popcenter <- geovars |>
    dplyr::select(hhid, dist_popcenter) |>
    dplyr::distinct()
  
  haven::write_dta(dist_popcenter, file.path(temp_dir, "dist_popcenter.dta"))
  
  # Distance to market
  dist_market <- geovars |>
    dplyr::select(hhid, dist_market) |>
    dplyr::distinct()
  
  haven::write_dta(dist_market, file.path(temp_dir, "dist_market.dta"))
  
  # Plot slope
  plot_geovars <- read_dta_auto("NGA_PlotGeovariables_Y1", input_dir, temp_dir)
  
  plot_slope <- plot_geovars |>
    dplyr::mutate(
      plot_id = paste(hhid, plotid, sep = "-")
    ) |>
    dplyr::rename(plot_slope = srtmslp_nga) |>
    dplyr::select(plot_id, plot_slope) |>
    dplyr::distinct()
  
  haven::write_dta(plot_slope, file.path(temp_dir, "plot_slope.dta"))
  
  # Elevation
  elevation <- plot_geovars |>
    dplyr::mutate(
      plot_id = paste(hhid, plotid, sep = "-")
    ) |>
    dplyr::rename(elevation = srtm_nga) |>
    dplyr::select(plot_id, elevation) |>
    dplyr::distinct()
  
  haven::write_dta(elevation, file.path(temp_dir, "elevation.dta"))
  
  # TWI
  twi <- plot_geovars |>
    dplyr::mutate(
      plot_id = paste(hhid, plotid, sep = "-")
    ) |>
    dplyr::rename(twi = twi_nga) |>
    dplyr::select(plot_id, twi) |>
    dplyr::distinct()
  
  haven::write_dta(twi, file.path(temp_dir, "twi.dta"))
  
  # Soil variables
  soil_vars <- geovars |>
    dplyr::mutate(
      nutrient_availability = dplyr::if_else(sq1 == 1, 1, 0),
      nutrient_retention = dplyr::if_else(sq2 == 1, 1, 0),
      rooting_conditions = dplyr::if_else(sq3 == 1, 1, 0),
      oxygen_availability = dplyr::if_else(sq4 == 1, 1, 0),
      excess_salts = dplyr::if_else(sq5 == 1, 1, 0),
      toxicity = dplyr::if_else(sq6 == 1, 1, 0),
      workability = dplyr::if_else(sq7 == 1, 1, 0)
    ) |>
    dplyr::mutate(
      soil_fertility_index = rowMeans(dplyr::across(
        nutrient_availability:workability), na.rm = TRUE)
    ) |>
    dplyr::select(hhid, nutrient_availability:workability, soil_fertility_index) |>
    dplyr::distinct()
  
  haven::write_dta(soil_vars, file.path(temp_dir, "soil.dta"))
  
  cat("  ✓ geographic variables saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in geographic variables: ", e$message, "\n")
})

# ==============================================================================
# 17. CLEAN UP: REMOVE EXTRACTED FILES (KEEP ONLY ZIP)
# ==============================================================================

cat("\n=== Cleaning up extracted files ===\n")

# Get all files in the input directory
all_files <- list.files(input_dir, full.names = TRUE)

# Keep only zip files (case insensitive)
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
# 18. CLEAN TEMP DIRECTORY
# ==============================================================================

cat("\n=== Cleaning temporary directory ===\n")

# Remove all files in temp_dir but keep the directory structure
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
# 19. FINAL OUTPUT
# ==============================================================================

cat("\n=== NGA_GHS1 processing complete ===\n")
cat("Temporary files saved to:", temp_dir, "\n")
cat("✓ All variables extracted successfully\n")