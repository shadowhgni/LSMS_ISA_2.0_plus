# ==============================================================================
# MLI_EACI1.r - Mali Wave 1 (EACI 2014)
# LSMS-ISA Harmonised Panel Analysis Code - R Translation
# ==============================================================================

# Clean environment
rm(list = ls())

# Load required packages
packages <- c("tidyverse", "haven", "labelled", "stringr", "purrr", "data.table")
installed <- packages %in% rownames(utils::installed.packages())
if (any(!installed)) utils::install.packages(packages[!installed])
lapply(packages, library, character.only = TRUE)

# Source helper functions
source("../programs.r")

# ==============================================================================
# 1. SET UP PATHS AND GLOBALS
# ==============================================================================

# Define paths (adjust as needed)
project_root <- '../..'
Do_path <- file.path(project_root, "R_scripts")
Input_path <- file.path(project_root, "R_data", "Input")
Temp_path <- file.path(project_root, "R_data", "Temp")
Final_path <- file.path(project_root, "R_data", "Final")

# Create directories if they don't exist
dir.create(Temp_path, showWarnings = FALSE, recursive = TRUE)
dir.create(Final_path, showWarnings = FALSE, recursive = TRUE)

# Country-specific globals
country <- "Mali"
wave <- "EACI 14"
temppath <- file.path("MLI", "EACI14")
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
  
  # Load perennial data
  perennial <- read_dta_auto("EACIS3B_p2", input_dir, temp_dir)
  
  # Filter and clean perennial data
  perennial <- perennial |>
    dplyr::filter(!is.na(s3bq01)) |>
    dplyr::filter(s3bq03 != 2) |>
    dplyr::filter(s3bq10b != 9) |>
    dplyr::mutate(
      hhid = paste(grappe, menage, sep = "-"),
      n = dplyr::row_number(),
      n_str = as.character(n),
      parcel_id2 = paste0("missing_line_", n_str),
      plot_id2 = paste0("missing_line_", n_str)
    ) |>
    dplyr::rename(crop_code = s3bq01) |>
    dplyr::mutate(
      crop_name2 = haven::as_factor(crop_code) |> as.character()
    )
  
  perennial_temp <- perennial |>
    dplyr::select(grappe, menage, crop_code, crop_name2, plot_id2, parcel_id2)
  
  # Load harvest data
  harvest <- read_dta_auto("EACIS3A_p2", input_dir, temp_dir)
  
  # Create hhid and plot_id
  harvest <- harvest |>
    dplyr::mutate(
      hhid = paste(grappe, menage, sep = "-"),
      plot_id = paste(grappe, menage, s3aq01, s3aq02, sep = "-"),
      parcel_id = paste(grappe, menage, s3aq01, sep = "-"),
      crop_name = haven::as_factor(s3aq03b) |> as.character()
    ) |>
    dplyr::rename(crop_code = s3aq03b)
  
  # Merge with perennial data
  harvest <- harvest |>
    dplyr::left_join(
      perennial_temp,
      by = c("grappe", "menage", "crop_code")
    ) |>
    dplyr::mutate(
      crop_name = dplyr::if_else(!is.na(crop_name2), crop_name2, crop_name),
      plot_id = dplyr::if_else(!is.na(plot_id2), plot_id2, plot_id),
      parcel_id = dplyr::if_else(!is.na(parcel_id2), parcel_id2, parcel_id)
    )
  
  # Create plot-crop frame
  plot_crop_frame <- harvest |>
    dplyr::select(hhid, plot_id, crop_name, crop_code, parcel_id) |>
    dplyr::distinct()
  
  haven::write_dta(plot_crop_frame, file.path(temp_dir, "plot_crop_frame.dta"))
  cat("  ✓ plot_crop_frame saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in plot-crop frame: ", e$message, "\n")
})

# 3.2 Household frame
tryCatch({
  cat("  Creating household frame...\n")
  
  cover <- read_dta_auto("EACICONTROLE_p1", input_dir, temp_dir)
  
  hh_frame <- cover |>
    dplyr::mutate(hhid = paste(grappe, menage, sep = "-")) |>
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
  
  indiv <- read_dta_auto("EACIIND_p1", input_dir, temp_dir)
  
  indiv_frame <- indiv |>
    dplyr::mutate(
      hhid = paste(grappe, menage, sep = "-"),
      ID = paste(hhid, s01q00, sep = "-")
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

# 4.1 EA (Enumeration Area)
tryCatch({
  cat("  Extracting EA...\n")
  
  cover <- read_dta_auto("EACICONTROLE_p1", input_dir, temp_dir)
  
  ea_id <- cover |>
    dplyr::mutate(
      hhid = paste(grappe, menage, sep = "-"),
      ea_id = as.character(grappe)
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
  
  # Load strata from wave 2 (EACI17) since wave 1 doesn't have it directly
  wave2_dir <- file.path(Input_path, country, "EACI 17")
  if (dir.exists(wave2_dir)) {
    weights <- read_dta_auto("EACI17_ECHANTILLON", wave2_dir, temp_dir)
    
    cover <- read_dta_auto("EACICONTROLE_p1", input_dir, temp_dir)
    
    strata <- weights |>
      dplyr::select(grappe, strate) |>
      dplyr::distinct() |>
      dplyr::right_join(cover, by = "grappe") |>
      dplyr::mutate(
        hhid = paste(grappe, menage, sep = "-"),
        strataid = strate
      ) |>
      dplyr::select(hhid, strataid) |>
      dplyr::distinct()
    
    haven::write_dta(strata, file.path(temp_dir, "strataid.dta"))
    cat("  ✓ strataid saved\n")
  } else {
    cat("  ℹ Wave 2 directory not found, skipping strata\n")
  }
  
}, error = function(e) {
  cat("  ✗ Error in strata extraction: ", e$message, "\n")
})

# 4.3 Administrative levels
tryCatch({
  cat("  Extracting administrative levels...\n")
  
  cover <- read_dta_auto("EACICONTROLE_p1", input_dir, temp_dir)
  
  # Admin 1
  admin1 <- cover |>
    dplyr::mutate(
      hhid = paste(grappe, menage, sep = "-"),
      admin_1 = s00q01,
      admin_1_name = haven::as_factor(admin_1) |> as.character()
    ) |>
    dplyr::select(hhid, admin_1, admin_1_name) |>
    dplyr::distinct()
  
  haven::write_dta(admin1, file.path(temp_dir, "admin1.dta"))
  
  # Admin 2
  admin2 <- cover |>
    dplyr::mutate(
      hhid = paste(grappe, menage, sep = "-"),
      admin_2 = paste(s00q01, s00q02, sep = "-")
    ) |>
    dplyr::select(hhid, admin_2) |>
    dplyr::distinct()
  
  haven::write_dta(admin2, file.path(temp_dir, "admin2.dta"))
  
  # Admin 3
  admin3 <- cover |>
    dplyr::mutate(
      hhid = paste(grappe, menage, sep = "-"),
      admin_3 = paste(s00q01, s00q02, s00q03, sep = "-")
    ) |>
    dplyr::select(hhid, admin_3) |>
    dplyr::distinct()
  
  haven::write_dta(admin3, file.path(temp_dir, "admin3.dta"))
  
  cat("  ✓ admin levels saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in admin levels: ", e$message, "\n")
})

# 4.4 Urban/rural
tryCatch({
  cat("  Extracting urban/rural...\n")
  
  cover <- read_dta_auto("EACICONTROLE_p1", input_dir, temp_dir)
  
  urban <- cover |>
    dplyr::mutate(
      hhid = paste(grappe, menage, sep = "-"),
      urban = dplyr::if_else(s00q04 == 1, 1, 0)
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
  
  weights <- read_dta_auto("EACIPOIDS", input_dir, temp_dir)
  
  weights_out <- weights |>
    dplyr::mutate(
      hhid = paste(grappe, menage, sep = "-"),
      pw = poids_menage
    ) |>
    dplyr::select(hhid, pw) |>
    dplyr::distinct()
  
  haven::write_dta(weights_out, file.path(temp_dir, "weights.dta"))
  cat("  ✓ weights saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in weights: ", e$message, "\n")
})

# 4.6 Planting month
tryCatch({
  cat("  Extracting planting month...\n")
  
  plot_inputs <- read_dta_auto("EACICULTURE_p1", input_dir, temp_dir)
  
  planting_month <- plot_inputs |>
    dplyr::mutate(
      hhid = paste(grappe, menage, sep = "-"),
      plot_id = paste(grappe, menage, s1cq01, s1cq02, sep = "-"),
      crop_code = s1cq03,
      month = s1cq11b,
      month = dplyr::if_else(month == 99, NA_real_, month),
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

# 4.7 Harvest end month
tryCatch({
  cat("  Extracting harvest end month...\n")
  
  harvest <- read_dta_auto("EACIS3A_p2", input_dir, temp_dir)
  
  harvest_end_month <- harvest |>
    dplyr::mutate(
      hhid = paste(grappe, menage, sep = "-"),
      plot_id = paste(grappe, menage, s3aq01, s3aq02, sep = "-"),
      crop_code = s3aq03b,
      month = s3aq07b,
      month = dplyr::if_else(month == 99, NA_real_, month),
      year = dplyr::if_else(month >= 4 & month <= 12, 2014, 2015),
      year = dplyr::if_else(is.na(month), NA_real_, year),
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

# 4.8 Harvest interview month
tryCatch({
  cat("  Extracting harvest interview month...\n")
  
  cover2 <- read_dta_auto("EACICONTROLE_p2", input_dir, temp_dir)
  
  harvest_interview_month <- cover2 |>
    dplyr::mutate(
      hhid = paste(grappe, menage, sep = "-"),
      month = s00q22m,
      year = s00q22y,
      harvest_interview_month = lubridate::ymd(paste(year, month, "01", sep = "-"))
    ) |>
    dplyr::select(hhid, harvest_interview_month) |>
    dplyr::distinct()
  
  haven::write_dta(harvest_interview_month, file.path(temp_dir, "harvest_interview_month.dta"))
  cat("  ✓ harvest_interview_month saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in harvest interview month: ", e$message, "\n")
})

# 4.9 Planting interview month
tryCatch({
  cat("  Extracting planting interview month...\n")
  
  cover2 <- read_dta_auto("EACICONTROLE_p2", input_dir, temp_dir)
  
  planting_interview_month <- cover2 |>
    dplyr::mutate(
      hhid = paste(grappe, menage, sep = "-"),
      month = s00q22m,
      year = s00q22y,
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
# 5. HARVEST QUANTITY AND SHOCKS
# ==============================================================================

cat("\n=== Processing harvest data ===\n")

# 5.1 Harvest kg
tryCatch({
  cat("  Calculating harvest kg...\n")
  
  # Load perennial data with conversion factors
  perennial <- read_dta_auto("EACIS3B_p2", input_dir, temp_dir) |>
    dplyr::filter(!is.na(s3bq01)) |>
    dplyr::filter(s3bq03 != 2) |>
    dplyr::filter(s3bq10b != 9) |>
    dplyr::mutate(
      hhid = paste(grappe, menage, sep = "-"),
      harvest_kg_per = s3bq09 * s3bq10b,
      harvest_kg_per = dplyr::if_else(s3bq09 == 99, NA_real_, harvest_kg_per)
    ) |>
    dplyr::rename(crop_code = s3bq01) |>
    dplyr::mutate(
      n = dplyr::row_number(),
      plot_id2 = paste0("missing_line_", as.character(n))
    ) |>
    dplyr::select(grappe, menage, crop_code, harvest_kg_per, plot_id2)
  
  # Load harvest data
  harvest <- read_dta_auto("EACIS3A_p2", input_dir, temp_dir) |>
    dplyr::mutate(
      hhid = paste(grappe, menage, sep = "-"),
      plot_id = paste(grappe, menage, s3aq01, s3aq02, sep = "-")
    ) |>
    dplyr::rename(crop_code = s3aq03b) |>
    dplyr::left_join(
      perennial |> dplyr::select(grappe, menage, crop_code, harvest_kg_per, plot_id2),
      by = c("grappe", "menage", "crop_code")
    ) |>
    dplyr::mutate(
      CF = s3aq08c / s3aq08a,
      conversion = s3aq08c,
      unit = s3aq08b
    ) |>
    dplyr::group_by(grappe, unit) |>
    dplyr::mutate(
      conversion = dplyr::if_else(!is.na(CF) & CF == dplyr::first(CF), CF, conversion),
      conversion = dplyr::if_else(unit == 1, 1, conversion)
    ) |>
    dplyr::ungroup()
  
  # Calculate harvest kg
  harvest <- harvest |>
    dplyr::mutate(
      harvest_kg = s3aq08a * conversion,
      harvest_kg = dplyr::if_else(s3aq08a == 9999, NA_real_, harvest_kg),
      harvest_kg = dplyr::if_else(!is.na(harvest_kg_per), harvest_kg_per, harvest_kg),
      harvest_kg = dplyr::if_else(unit == 1, s3aq08a, harvest_kg),
      harvest_kg = dplyr::if_else(unit == 2 & s3aq08c < 100, s3aq08a * 100, harvest_kg),
      harvest_kg = dplyr::if_else(unit == 2 & conversion %in% c(100, 250, 300, 450), 
                                  s3aq08c, harvest_kg),
      harvest_kg = dplyr::if_else(unit == 3 & conversion %in% c(300, 250, 200, 100), 
                                  s3aq08c, harvest_kg),
      harvest_kg = dplyr::if_else(unit == 2 & s3aq08c < 35, s3aq08a * 100, harvest_kg),
      harvest_kg = dplyr::if_else(unit == 4 & s3aq08c > 120, s3aq08c, harvest_kg),
      harvest_kg = dplyr::if_else(s3aq08a == 0 | s3aq10 == 10, 0, harvest_kg),
      harvest_kg = dplyr::if_else(s3aq06 < 100 & s3aq05 == 2,
                                  harvest_kg / (1 - s3aq06/100),
                                  harvest_kg)
    ) |>
    dplyr::mutate(
      crop_shock = dplyr::if_else(s3aq09 == 1, 1, 
                                  dplyr::if_else(s3aq09 == 2, 0, NA_real_))
    ) |>
    dplyr::mutate(
      harvest_kg = dplyr::if_else(harvest_kg == 0 & crop_shock != 1, NA_real_, harvest_kg)
    )
  
  # Prepare for saving - add admin levels
  admin1 <- haven::read_dta(file.path(temp_dir, "admin1.dta"))
  admin2 <- haven::read_dta(file.path(temp_dir, "admin2.dta"))
  admin3 <- haven::read_dta(file.path(temp_dir, "admin3.dta"))
  
  harvest_kg <- harvest |>
    dplyr::left_join(admin1, by = "hhid") |>
    dplyr::left_join(admin2, by = "hhid") |>
    dplyr::left_join(admin3, by = "hhid") |>
    dplyr::mutate(ea_id = as.character(grappe)) |>
    dplyr::group_by(plot_id, crop_code, hhid, ea_id) |>
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

# 5.2 Crop shocks
tryCatch({
  cat("  Extracting crop shocks...\n")
  
  harvest <- read_dta_auto("EACIS3A_p2", input_dir, temp_dir)
  
  crop_shock <- harvest |>
    dplyr::mutate(
      hhid = paste(grappe, menage, sep = "-"),
      plot_id = paste(grappe, menage, s3aq01, s3aq02, sep = "-"),
      crop_code = s3aq03b,
      crop_shock = dplyr::if_else(s3aq09 == 1, 1,
                                  dplyr::if_else(s3aq09 == 2, 0, NA_real_)),
      drought_shock = dplyr::if_else(s3aq11 == 1, 1,
                                     dplyr::if_else(s3aq11 %in% c(2:9), 0, NA_real_)),
      drought_shock = dplyr::if_else(s3aq09 == 2, 0, drought_shock),
      rain_shock = dplyr::if_else(s3aq11 == 2, 1,
                                  dplyr::if_else(s3aq11 %in% c(1, 3:9), 0, NA_real_)),
      rain_shock = dplyr::if_else(s3aq09 == 2, 0, rain_shock),
      pests_shock = dplyr::if_else(s3aq11 == 5, 1,
                                   dplyr::if_else(s3aq11 %in% c(1:4, 6:9), 0, NA_real_)),
      pests_shock = dplyr::if_else(s3aq09 == 2, 0, pests_shock),
      pct_lost = dplyr::if_else(s3aq10 <= 10, s3aq10 * 10, NA_real_),
      pct_lost = dplyr::if_else(s3aq09 == 2, 0, pct_lost),
      pct_lost = pct_lost / 100
    ) |>
    dplyr::group_by(hhid, plot_id, crop_code) |>
    dplyr::summarise(
      crop_shock = max(crop_shock, na.rm = TRUE),
      pests_shock = max(pests_shock, na.rm = TRUE),
      rain_shock = max(rain_shock, na.rm = TRUE),
      drought_shock = max(drought_shock, na.rm = TRUE),
      pct_lost = mean(pct_lost, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      crop_shock = dplyr::if_else(is.infinite(crop_shock), NA_real_, crop_shock),
      pests_shock = dplyr::if_else(is.infinite(pests_shock), NA_real_, pests_shock),
      rain_shock = dplyr::if_else(is.infinite(rain_shock), NA_real_, rain_shock),
      drought_shock = dplyr::if_else(is.infinite(drought_shock), NA_real_, drought_shock)
    )
  
  haven::write_dta(crop_shock, file.path(temp_dir, "crop_shock.dta"))
  cat("  ✓ crop_shock saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in crop shocks: ", e$message, "\n")
})

# ==============================================================================
# 6. HARVEST VALUE AND MAIN CROP
# ==============================================================================

cat("\n=== Calculating harvest values ===\n")

# 6.1 Harvest value
tryCatch({
  cat("  Calculating harvest value...\n")
  
  perennial <- read_dta_auto("EACIS3B_p2", input_dir, temp_dir) |>
    dplyr::filter(!is.na(s3bq01)) |>
    dplyr::filter(s3bq03 != 2) |>
    dplyr::filter(s3bq10b != 9) |>
    dplyr::mutate(
      hhid = paste(grappe, menage, sep = "-"),
      n = dplyr::row_number(),
      plot_id2 = paste0("missing_line_", as.character(n))
    ) |>
    dplyr::rename(crop_code = s3bq01)
  
  harvest <- read_dta_auto("EACIS3A_p2", input_dir, temp_dir) |>
    dplyr::mutate(
      hhid = paste(grappe, menage, sep = "-"),
      plot_id = paste(grappe, menage, s3aq01, s3aq02, sep = "-")
    ) |>
    dplyr::rename(crop_code = s3aq03b) |>
    dplyr::left_join(
      perennial |> dplyr::select(grappe, menage, crop_code, plot_id2),
      by = c("grappe", "menage", "crop_code")
    ) |>
    dplyr::mutate(
      plot_id = dplyr::if_else(!is.na(plot_id2), plot_id2, plot_id)
    ) |>
    dplyr::select(hhid, plot_id, crop_code) |>
    dplyr::distinct()
  
  # Calculate harvest value using median crop prices
  harvest_value <- valuation_median_crops(
    data = harvest,
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
  
  plot_inputs <- read_dta_auto("EACICULTURE_p1", input_dir, temp_dir)
  
  intercropped <- plot_inputs |>
    dplyr::mutate(
      hhid = paste(grappe, menage, sep = "-"),
      plot_id = paste(grappe, menage, s1cq01, s1cq02, sep = "-"),
      crop_code = s1cq03,
      intercropped = dplyr::if_else(s1cq05 == 1, 0,
                                    dplyr::if_else(s1cq05 == 2, 1, NA_real_))
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
  
  harvest <- read_dta_auto("EACIS3A_p2", input_dir, temp_dir)
  
  nb_seasonal_crop <- harvest |>
    dplyr::mutate(
      plot_id = paste(grappe, menage, s3aq01, s3aq02, sep = "-")
    ) |>
    dplyr::group_by(plot_id) |>
    dplyr::summarise(
      nb_seasonal_crop = n_distinct(s3aq03b, na.rm = TRUE),
      .groups = "drop"
    )
  
  haven::write_dta(nb_seasonal_crop, file.path(temp_dir, "nb_seasonal_crop.dta"))
  cat("  ✓ nb_seasonal_crop saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in nb_seasonal_crop: ", e$message, "\n")
})

# ==============================================================================
# 7. LAND AREA
# ==============================================================================

cat("\n=== Processing land area ===\n")

tryCatch({
  cat("  Calculating plot area...\n")
  
  plot_roster <- read_dta_auto("EACIEXPLOI_p1", input_dir, temp_dir)
  admin3 <- haven::read_dta(file.path(temp_dir, "admin3.dta"))
  
  land_area <- plot_roster |>
    dplyr::mutate(
      hhid = paste(grappe, menage, sep = "-"),
      plot_id = paste(grappe, menage, s1bq01, s1bq02, sep = "-"),
      area_self_reported = s1bq10,
      area_self_reported = dplyr::if_else(area_self_reported == 99, NA_real_, area_self_reported),
      plot_area_GPS = s1bq05a,
      plot_area_GPS = dplyr::if_else(plot_area_GPS == 99, NA_real_, plot_area_GPS)
    ) |>
    dplyr::left_join(admin3, by = "hhid")
  
  # Impute missing GPS area using self-reported area
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
# 8. CONTINUE WITH REMAINING VARIABLES
# ==============================================================================

cat("\n=== Processing remaining variables ===\n")

# 8.1 Improved seeds
tryCatch({
  cat("  Extracting improved seed status...\n")
  
  seeds <- read_dta_auto("EACIS1E_p2", input_dir, temp_dir)
  
  improved <- seeds |>
    dplyr::mutate(
      hhid = paste(grappe, menage, sep = "-"),
      plot_id = paste(grappe, menage, s1eq01, s1eq02, sep = "-"),
      crop_code = s1eq03b,
      improved = dplyr::case_when(
        s1eq04 %in% c(2:5) ~ 1,
        s1eq04 == 1 ~ 0,
        s1eq04 == 9 ~ NA_real_,
        TRUE ~ NA_real_
      )
    ) |>
    dplyr::select(hhid, plot_id, crop_code, improved) |>
    dplyr::distinct()
  
  haven::write_dta(improved, file.path(temp_dir, "improved.dta"))
  cat("  ✓ improved saved\n")
  
}, error = function(e) {
  cat("  ✗ Error in improved seeds: ", e$message, "\n")
})

# 8.2 Seed kg
tryCatch({
  cat("  Calculating seed kg...\n")
  
  seeds <- read_dta_auto("EACIS1E_p2", input_dir, temp_dir)
  
  seed_kg <- seeds |>
    dplyr::mutate(
      hhid = paste(grappe, menage, sep = "-"),
      plot_id = paste(grappe, menage, s1eq01, s1eq02, sep = "-"),
      crop_code = s1eq03b,
      ea_id = as.character(grappe),
      seed_kg_temp = dplyr::if_else(s1eq10b == 2, s1eq10a, NA_real_),
      seed_gram = dplyr::if_else(s1eq10b == 1, s1eq10a * 0.001, NA_real_),
      seed_kg = dplyr::coalesce(seed_kg_temp, seed_gram),
      seed_kg = dplyr::if_else(seed_kg >= 9999, NA_real_, seed_kg),
      seed_kg = dplyr::if_else(is.na(seed_kg) & !is.na(s1eq05a), 
                               s1eq05a, seed_kg),
      seed_kg = dplyr::if_else(is.na(seed_kg) & !is.na(s1eq05a) & s1eq05b == 1,
                               s1eq05a * 0.001, seed_kg),
      seed_kg = dplyr::if_else(seed_kg >= 9999, NA_real_, seed_kg)
    ) |>
    dplyr::filter(!is.na(crop_code)) |>
    dplyr::group_by(plot_id, crop_code, ea_id) |>
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

# 8.3 Seed value
tryCatch({
  cat("  Calculating seed value...\n")
  
  seeds <- read_dta_auto("EACIS1E_p2", input_dir, temp_dir)
  
  seed_value <- seeds |>
    dplyr::mutate(
      hhid = paste(grappe, menage, sep = "-"),
      plot_id = paste(grappe, menage, s1eq01, s1eq02, sep = "-"),
      crop_code = s1eq03b,
      ea_id = as.character(grappe),
      improved = dplyr::case_when(
        s1eq04 %in% c(2:5) ~ 1,
        s1eq04 == 1 ~ 0,
        TRUE ~ NA_real_
      ),
      seed_value_temp = s1eq06,
      seed_value_temp = dplyr::if_else(
        seed_value_temp >= 999998 | seed_value_temp == 99999,
        NA_real_, seed_value_temp
      )
    ) |>
    dplyr::filter(!is.na(crop_code)) |>
    dplyr::group_by(plot_id, crop_code, hhid, ea_id) |>
    dplyr::summarise(
      seed_value_temp = sum(seed_value_temp, na.rm = TRUE),
      improved = max(improved, na.rm = TRUE),
      n_seed_value_temp = sum(!is.na(seed_value_temp)),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      seed_value_temp = dplyr::if_else(n_seed_value_temp == 0, NA_real_, seed_value_temp),
      improved = dplyr::if_else(is.infinite(improved), NA_real_, improved)
    ) |>
    dplyr::select(-n_seed_value_temp)
  
  # Use valuation_median_seeds function
  seed_value_out <- valuation_median_seeds(
    data = seed_value,
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
# 9. CLEAN UP: REMOVE EXTRACTED FILES (KEEP ONLY ZIP)
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
# 10. CLEAN TEMP DIRECTORY
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
# 11. FINAL OUTPUT
# ==============================================================================

cat("\n=== MLI_EACI1 processing complete ===\n")
cat("Temporary files saved to:", temp_dir, "\n")
cat("Final files will be saved to:", Final_path, "\n")