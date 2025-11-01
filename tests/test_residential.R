#!/usr/bin/env Rscript

# Test residential sector data loading
library(arrow)
library(here)
library(dplyr)

# Source mapping file
source(here("scripts", "0_support", "mapping_countries.R"))
source(here("scripts", "0_support", "data_load.R"))

# Test loading residential data for Belgium
cat("\n=== Testing Residential Sector Data for Belgium ===\n")

test_country <- "Belgium"
country_code <- get_country_code(test_country)

cat(sprintf("\nCountry: %s (%s)\n", test_country, country_code))

# Test each dataset needed for residential sector
datasets <- c("nrg_bal_c", "nrg_d_hhq", "nrg_chdd_a", "demo_gind", "ilc_lvph01")

for (dataset in datasets) {
  file_path <- here("data", paste0(dataset, "_", country_code, ".feather"))
  
  if (file.exists(file_path)) {
    data <- arrow::read_feather(file_path)
    cat(sprintf("✓ %s: %d rows, %d columns\n", dataset, nrow(data), ncol(data)))
    cat(sprintf("  Columns: %s\n", paste(names(data), collapse=", ")))
    
    # Show date range if 'time' column exists
    if ("time" %in% names(data)) {
      cat(sprintf("  Years: %d to %d\n", min(data$time), max(data$time)))
    }
  } else {
    cat(sprintf("✗ %s: FILE NOT FOUND\n", dataset))
  }
}

# Check if old .Rda files exist
cat("\n=== Checking for old .Rda files ===\n")
for (dataset in datasets) {
  rda_path <- here("data", paste0(dataset, ".Rda"))
  if (file.exists(rda_path)) {
    cat(sprintf("⚠ %s.Rda exists (old format)\n", dataset))
  }
}

cat("\n=== Test Complete ===\n")
