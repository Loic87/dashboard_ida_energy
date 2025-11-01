#!/usr/bin/env Rscript

# Improved data download script - Phase 2 update
# Removes RStudio dependency and adds better progress reporting

library(futile.logger)
library(eurostat)
library(tidyr)
library(dplyr)
library(feather)

# Get script directory portably (works outside RStudio)
if (exists("here::here")) {
  library(here)
  base_dir <- here()
} else {
  base_dir <- getwd()
  # If running from scripts folder, go up one level
  if (basename(base_dir) == "scripts" || basename(base_dir) == "0_support") {
    base_dir <- dirname(base_dir)
    if (basename(base_dir) == "scripts") {
      base_dir <- dirname(base_dir)
    }
  }
}

cat("Base directory:", base_dir, "\n")
cat("Data will be saved to:", file.path(base_dir, "data"), "\n\n")

# Source mapping files
scripts_dir <- file.path(base_dir, "scripts")
source(file.path(scripts_dir, "0_support", "mapping_countries.R"))

# Function to fetch Eurostat data, write to a file, and log the process.
fetch_write_log <- function(country_code,
                            dataset_id,
                            filters,
                            base_dir) {
  country_long <- get_country_long(country_code)
  
  # Attempt to fetch data and handle errors within the function
  tryCatch({
    cat(sprintf("  Downloading %s for %s...", dataset_id, country_long))
    
    data <- get_eurostat(id = dataset_id,
                         time_format = "num",
                         filters = filters,
                         cache = FALSE)
    
    # Check if 'freq' column exists and drop it
    if ("freq" %in% names(data)) {
      data <- data[,!(names(data) %in% "freq")]
    }
    
    # Constructing file path dynamically based on parameters
    file_path <- file.path(base_dir, "data", paste0(dataset_id, "_", country_code, ".feather"))
    
    # Create data directory if it doesn't exist
    dir.create(dirname(file_path), showWarnings = FALSE, recursive = TRUE)
    
    write_feather(data, file_path)
    
    cat(sprintf(" ✓ (%d rows)\n", nrow(data)))
    flog.info(paste0("Loaded data from ", dataset_id, " for: ", country_long, " (", nrow(data), " rows)"))
    
    return(list(status = "success", rows = nrow(data)))
    
  }, error = function(e) {
    cat(" ✗ ERROR\n")
    flog.error(
      paste0(
        "Error in updating data from ",
        dataset_id,
        ", country: ",
        country_long,
        ", error: ",
        as.character(e)
      )
    )
    return(list(status = "error", error = as.character(e)))
  })
}

# Define datasets to download
datasets <- list(
  list(id = "nrg_bal_c", 
       desc = "Energy balance sheets",
       filters_fn = function(cc) list(geo = cc, unit = c("TJ", "GWH"))),
  
  list(id = "nama_10_a64",
       desc = "National accounts - GVA by sector",
       filters_fn = function(cc) list(geo = cc, na_item = "B1G", unit = "CLV10_MEUR")),
  
  list(id = "nama_10_a10_e",
       desc = "Employment by sector",
       filters_fn = function(cc) list(geo = cc, na_item = "EMP_DC", unit = "THS_PER")),
  
  list(id = "road_tf_vehmov",
       desc = "Road transport - vehicle movements",
       filters_fn = function(cc) list(geo = cc, vehicle = "TOTAL")),
  
  list(id = "rail_tf_trainmv",
       desc = "Rail transport - train movements",
       filters_fn = function(cc) list(geo = cc, train = "TOTAL", unit = "THS_TRKM")),
  
  list(id = "iww_tf_vetf",
       desc = "Inland waterways transport",
       filters_fn = function(cc) list(geo = cc, tra_cov = "TOTAL", loadstat = "TOTAL", unit = "THS_VESKM")),
  
  list(id = "nrg_d_hhq",
       desc = "Household energy consumption",
       filters_fn = function(cc) list(geo = cc, siec = "TOTAL", unit = "TJ")),
  
  list(id = "nrg_chdd_a",
       desc = "Heating degree days",
       filters_fn = function(cc) list(geo = cc)),
  
  list(id = "demo_gind",
       desc = "Population indicators",
       filters_fn = function(cc) list(geo = cc, indic_de = "AVG")),
  
  list(id = "ilc_lvph01",
       desc = "Household size",
       filters_fn = function(cc) list(geo = cc, unit = "AVG"))
)

# Main download loop
cat("="*70, "\n")
cat("Starting Eurostat data download\n")
cat("="*70, "\n\n")
cat("Countries to process:", length(country_code_list), "\n")
cat("Datasets per country:", length(datasets), "\n")
cat("Total downloads:", length(country_code_list) * length(datasets), "\n\n")

start_time <- Sys.time()
results <- list()
success_count <- 0
error_count <- 0

for (i in seq_along(country_code_list)) {
  country_code <- country_code_list[i]
  country_long <- get_country_long(country_code)
  
  cat(sprintf("[%d/%d] Processing %s (%s)\n", 
              i, length(country_code_list), country_long, country_code))
  cat(strrep("-", 70), "\n")
  
  for (dataset in datasets) {
    filters <- dataset$filters_fn(country_code)
    result <- fetch_write_log(country_code, dataset$id, filters, base_dir)
    
    if (result$status == "success") {
      success_count <- success_count + 1
    } else {
      error_count <- error_count + 1
    }
    
    results[[paste0(country_code, "_", dataset$id)]] <- result
    
    # Small delay to be nice to Eurostat servers
    Sys.sleep(0.5)
  }
  
  cat("\n")
}

end_time <- Sys.time()
duration <- as.numeric(difftime(end_time, start_time, units = "mins"))

# Summary
cat(strrep("=", 70), "\n")
cat("DOWNLOAD SUMMARY\n")
cat(strrep("=", 70), "\n\n")
cat("Total downloads attempted:", length(results), "\n")
cat("Successful:", success_count, "\n")
cat("Errors:", error_count, "\n")
cat("Duration:", sprintf("%.1f minutes", duration), "\n\n")

if (error_count > 0) {
  cat("Datasets with errors:\n")
  for (key in names(results)) {
    if (results[[key]]$status == "error") {
      cat("  -", key, "\n")
    }
  }
}

cat("\n✓ Data download complete!\n")
cat("\nData saved to:", file.path(base_dir, "data"), "\n")
