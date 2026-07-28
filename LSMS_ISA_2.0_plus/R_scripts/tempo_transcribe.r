# ==============================================================================
# Script to concatenate all .do files from Cleaning_code folder into one text file
# ==============================================================================

# Clean environment
rm(list = ls())

# Load required packages
packages <- c("tidyverse", "here", "fs")
installed <- packages %in% rownames(utils::installed.packages())
if (any(!installed)) utils::install.packages(packages[!installed])
lapply(packages, library, character.only = TRUE)

# ==============================================================================
# Configuration
# ==============================================================================

# Set the path to your project root (modify if needed)
project_root <- here::here()  # Uses the current R project directory
# Alternative: Set manually
# project_root <- "C:/path/to/your/project"
project_root <- "C:/Users/DHOUGNI/OneDrive - CIMMYT/Documents/Harare 2023/Sustainable_Farming_Science_Prgm/LSMS_ISA_West_Af/LSMS-ISA-2.0+/R_scripts"

# Define folder paths
cleaning_code_folder <- file.path(project_root, "../Reproduction_v2/Code/Cleaning_code")
output_file <- file.path(project_root, "all_do_files_combined.txt")

# ==============================================================================
# Function to combine all .do files
# ==============================================================================

combine_do_files <- function(input_folder, output_file) {
  
  # Check if input folder exists
  if (!fs::dir_exists(input_folder)) {
    stop("Error: Cleaning_code folder not found at: ", input_folder)
  }
  
  # Get all .do files in the folder (recursive search)
  do_files <- fs::dir_ls(
    path = input_folder,
    recurse = TRUE,
    regexp = "\\.do$"
  )
  
  # Check if any .do files were found
  if (length(do_files) == 0) {
    stop("No .do files found in: ", input_folder)
  }
  
  # Convert to character vector and sort alphabetically
  do_files <- sort(as.character(do_files))
  
  cat("Found", length(do_files), ".do files\n")
  cat("First few files:\n")
  print(head(do_files, 5))
  
  # Open connection for writing
  con <- file(output_file, open = "w", encoding = "UTF-8")
  
  # Write header
  cat("================================================================================\n", file = con)
  cat("COMBINED .DO FILES FROM CLEANING_CODE FOLDER\n", file = con)
  cat("Generated on:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n", file = con)
  cat("Total files:", length(do_files), "\n", file = con)
  cat("================================================================================\n\n\n", file = con)
  
  # Counter for progress
  file_count <- 0
  total_files <- length(do_files)
  
  # Loop through each .do file
  for (file_path in do_files) {
    file_count <- file_count + 1
    
    # Get just the filename (without path)
    file_name <- basename(file_path)
    
    # Progress indicator
    cat(sprintf("Processing [%d/%d]: %s\n", file_count, total_files, file_name))
    
    # Write file header
    cat("\n\n", file = con)
    cat("============================================================================\n", file = con)
    cat("FILE:", file_name, "\n", file = con)
    cat("Path:", file_path, "\n", file = con)
    cat("============================================================================\n\n", file = con)
    
    # Read and write the file content
    tryCatch({
      # Read the .do file
      file_content <- readLines(file_path, warn = FALSE, encoding = "UTF-8")
      
      # Write content with line numbers (optional)
      # For now, just write the raw content
      cat(file_content, sep = "\n", file = con)
      
      # If the file doesn't end with a newline, add one
      if (length(file_content) > 0) {
        cat("\n", file = con)
      }
      
    }, error = function(e) {
      # If there's an error reading the file
      cat("ERROR READING FILE:", e$message, "\n", file = con)
      cat("========================================\n", file = con)
    })
    
    # Write file footer
    cat("\n", file = con)
    cat("=====================END OF SCRIPT======================\n", file = con)
    cat("END OF FILE:", file_name, "\n", file = con)
    cat("============================================================================\n", file = con)
  }
  
  # Close connection
  close(con)
  
  cat("\n✅ Completed! Combined", file_count, "files into:", output_file, "\n")
  
  # Return file info
  file_info <- fs::file_info(output_file)
  cat("File size:", format(file_info$size, units = "auto"), "\n")
  
  return(invisible(output_file))
}


# ==============================================================================
# Execute the combination
# ==============================================================================

# Main execution
cat("\n--- Starting standard combination ---\n")
combine_do_files(cleaning_code_folder, output_file)


# ==============================================================================
# Optional: Create a summary file listing all .do files
# ==============================================================================

create_file_summary <- function(input_folder, output_summary) {
  
  do_files <- sort(as.character(fs::dir_ls(
    path = input_folder,
    recurse = TRUE,
    regexp = "\\.do$"
  )))
  
  # Create a data frame with file info
  file_info_df <- purrr::map_dfr(do_files, function(file_path) {
    info <- fs::file_info(file_path)
    tibble::tibble(
      filename = basename(file_path),
      path = file_path,
      size_bytes = info$size,
      size_kb = round(info$size / 1024, 2),
      modification_time = info$modification_time,
      line_count = length(readLines(file_path, warn = FALSE))
    )
  })
  
  # Write summary
  readr::write_csv(file_info_df, output_summary)
  
  cat("📊 File summary written to:", output_summary, "\n")
  print(file_info_df)
  
  return(invisible(file_info_df))
}

# Create summary file
summary_file <- file.path(project_root, "do_files_summary.csv")
create_file_summary(cleaning_code_folder, summary_file)

# ==============================================================================
# Final message
# ==============================================================================

cat("\n" , rep("=", 80), "\n", sep = "")
cat("✅ ALL TASKS COMPLETED\n")
cat("  📄 Combined file:", output_file, "\n")
cat("  📊 Summary file:", summary_file, "\n")
cat("  📁 Source folder:", cleaning_code_folder, "\n")
cat(rep("=", 80), "\n", sep = "")