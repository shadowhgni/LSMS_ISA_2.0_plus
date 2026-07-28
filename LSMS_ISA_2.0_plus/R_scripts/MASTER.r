# ==============================================================================
# LSMS-ISA Harmonised Panel Analysis Code - R Translation
# Description: This code harmonises LSMS-ISA data
# Date: December 2023 (R translation: 2026)
# ==============================================================================

# Clear environment and close any open connections
rm(list = ls())
gc()
options(max.print = 10000)
options(stringsAsFactors = FALSE)

# Set seed for reproducibility
set.seed(12345)

# ==============================================================================
# 1. SETUP PATHS
# ==============================================================================

# Define directory paths - YOU MUST MODIFY THESE
Do_path <- "..."  # Path to the directory containing your .do files
Input_path <- "..."  # Path to raw data
Temp_path <- "..."  # Path for temporary files
Final_path <- "..."  # Path for final output

# Create directories if they don't exist
dir.create(Do_path, showWarnings = FALSE, recursive = TRUE)
dir.create(Input_path, showWarnings = FALSE, recursive = TRUE)
dir.create(Temp_path, showWarnings = FALSE, recursive = TRUE)
dir.create(Final_path, showWarnings = FALSE, recursive = TRUE)

# ==============================================================================
# 2. INSTALL AND LOAD REQUIRED PACKAGES
# ==============================================================================

# List of required packages (matching Stata packages)
required_packages <- c(
  "haven",        # For reading/writing Stata files
  "dplyr",        # For data manipulation
  "tidyr",        # For data reshaping
  "stringr",      # For string operations
  "labelled",     # For working with labelled data
  "purrr",        # For functional programming
  "data.table",   # For efficient data operations
  "foreign",      # For reading other formats
  "readr",        # For reading CSV files
  "magrittr",     # For pipe operations
  "tibble"        # For modern data frames
)

# Function to install missing packages
install_if_missing <- function(pkg) {
  if (!require(pkg, character.only = TRUE)) {
    install.packages(pkg, dependencies = TRUE)
    library(pkg, character.only = TRUE)
  }
}

# Install and load all required packages
invisible(lapply(required_packages, install_if_missing))

# ==============================================================================
# 3. SOURCE HELPER FUNCTIONS
# ==============================================================================

# Source the R equivalent of programs.do
# This file should contain helper functions that match the Stata ado files
source(file.path(Do_path, "programs.R"))

# ==============================================================================
# 4. RUN ALL COUNTRY-SPECIFIC CLEANING SCRIPTS
# ==============================================================================

# Create a function to safely source R scripts
source_script <- function(file_name) {
  full_path <- file.path(Do_path, "Cleaning_code", file_name)
  if (file.exists(full_path)) {
    cat(paste("Running:", file_name, "\n"))
    tryCatch({
      source(full_path, local = TRUE)
      cat(paste("Completed:", file_name, "\n"))
    }, error = function(e) {
      cat(paste("Error in", file_name, ":", e$message, "\n"))
    })
  } else {
    cat(paste("Warning: File not found:", full_path, "\n"))
  }
}

# Source the programs file first
if (file.exists(file.path(Do_path, "programs.R"))) {
  source(file.path(Do_path, "programs.R"))
} else {
  cat("Warning: programs.R not found. Some functions may be missing.\n")
}

# Ethiopia
source_script("ETH_ESS1.R")
source_script("ETH_ESS2.R")
source_script("ETH_ESS3.R")
source_script("ETH_ESS4.R")
source_script("ETH_ESS5.R")
source_script("Append_ETH.R")

# Malawi
source_script("MWI_IHPS1.R")
source_script("MWI_IHPS2.R")
source_script("MWI_IHPS3.R")
source_script("MWI_IHPS4.R")
source_script("Append_MWI.R")

# Mali
source_script("MLI_EACI1.R")
source_script("MLI_EACI2.R")
source_script("Append_MLI.R")

# Niger
source_script("NER_ECVMA1.R")
source_script("NER_ECVMA2.R")
source_script("Append_NER.R")

# Nigeria
source_script("NGA_GHS1.R")
source_script("NGA_GHS2.R")
source_script("NGA_GHS3.R")
source_script("NGA_GHS4.R")
source_script("NGA_GHS5.R")
source_script("Append_NGA.R")

# Tanzania
source_script("TZA_NPS1.R")
source_script("TZA_NPS2.R")
source_script("TZA_NPS3.R")
source_script("TZA_NPS4.R")
source_script("TZA_NPS4_refresh.R")
source_script("TZA_NPS5.R")
source_script("TZA_NPS5_refresh.R")
source_script("Append_TZA.R")

# Uganda - Regular waves
source_script("UGA_UNPS1.R")
source_script("UGA_UNPS2.R")
source_script("UGA_UNPS3.R")
source_script("UGA_UNPS4.R")
source_script("UGA_UNPS5.R")
source_script("UGA_UNPS7.R")
source_script("UGA_UNPS8.R")

# Uganda - Season 2 waves
source_script("UGA_UNPS1_S2.R")
source_script("UGA_UNPS2_S2.R")
source_script("UGA_UNPS3_S2.R")
source_script("UGA_UNPS4_S2.R")
source_script("UGA_UNPS5_S2.R")
source_script("UGA_UNPS7_S2.R")
source_script("UGA_UNPS8_S2.R")
source_script("Append_UGA.R")

# Final append - all countries combined
source_script("Append_ALL.R")

# ==============================================================================
# 5. FINAL MESSAGE
# ==============================================================================

cat("\n========================================\n")
cat("LSMS-ISA Harmonisation Process Complete\n")
cat("========================================\n")
cat("Final datasets should be in:", Final_path, "\n")
cat("Temporary files in:", Temp_path, "\n")
cat("========================================\n")