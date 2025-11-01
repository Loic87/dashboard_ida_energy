#!/usr/bin/env Rscript

# Test data download for sample countries (Phase 2)
# Downloads data for France, Germany, and Belgium as a test

library(futile.logger)
library(eurostat)
library(tidyr)
library(dplyr)
library(feather)
library(here)

cat("Testing data download for sample countries...\n\n")

# Get base directory
base_dir <- here()
cat("Base directory:", base_dir, "\n")
cat("Data directory:", file.path(base_dir, "data"), "\n\n")

# Test countries
test_countries <- c("FR", "DE", "BE")
cat("Test countries:", paste(test_countries, collapse = ", "), "\n\n")

# Simplified download function
download_test_data <- function(country_code, dataset_id, filters, base_dir) {
  tryCatch({
    cat(sprintf("  %s for %s...", dataset_id, country_code))
    
    data <- get_eurostat(id = dataset_id,
                        time_format = "num",
                        filters = filters,
                        cache = FALSE)
    
    # Remove freq column if exists
    if ("freq" %in% names(data)) {
      data <- data[,!(names(data) %in% "freq")]
    }
    
    # Save to feather
    file_path <- file.path(base_dir, "data", paste0(dataset_id, "_", country_code, ".feather"))
    dir.create(dirname(file_path), showWarnings = FALSE, recursive = TRUE)
    write_feather(data, file_path)
    
    cat(sprintf(" ✓ (%d rows, years: %d-%d)\n", 
                nrow(data),
                min(data$time, na.rm = TRUE),
                max(data$time, na.rm = TRUE)))
    
    return(list(status = "OK", rows = nrow(data), 
                year_min = min(data$time, na.rm = TRUE),
                year_max = max(data$time, na.rm = TRUE)))
    
  }, error = function(e) {
    cat(" ✗ ERROR:", as.character(e), "\n")
    return(list(status = "ERROR", error = as.character(e)))
  })
}

# Test datasets (subset of main ones)
test_datasets <- list(
  list(id = "nrg_bal_c", desc = "Energy balance",
       filters_fn = function(cc) list(geo = cc, unit = "TJ")),
  list(id = "nama_10_a64", desc = "GVA by sector",
       filters_fn = function(cc) list(geo = cc, na_item = "B1G", unit = "CLV10_MEUR")),
  list(id = "demo_gind", desc = "Population",
       filters_fn = function(cc) list(geo = cc, indic_de = "AVG"))
)

# Download test data
results <- list()
start_time <- Sys.time()

for (country in test_countries) {
  cat(sprintf("\n%s (%s):\n", country, switch(country,
                                              "FR" = "France",
                                              "DE" = "Germany", 
                                              "BE" = "Belgium",
                                              country)))
  cat(strrep("-", 50), "\n")
  
  for (dataset in test_datasets) {
    filters <- dataset$filters_fn(country)
    result <- download_test_data(country, dataset$id, filters, base_dir)
    results[[paste0(country, "_", dataset$id)]] <- result
    Sys.sleep(0.3)  # Be nice to Eurostat servers
  }
}

end_time <- Sys.time()
duration <- as.numeric(difftime(end_time, start_time, units = "secs"))

# Summary
cat("\n", strrep("=", 50), "\n")
cat("TEST SUMMARY\n")
cat(strrep("=", 50), "\n\n")

success <- sum(sapply(results, function(x) x$status == "OK"))
errors <- sum(sapply(results, function(x) x$status == "ERROR"))

cat("Downloads attempted:", length(results), "\n")
cat("Successful:", success, "\n")
cat("Errors:", errors, "\n")
cat("Duration:", sprintf("%.1f seconds", duration), "\n\n")

if (success > 0) {
  cat("Sample data details:\n")
  for (key in names(results)) {
    res <- results[[key]]
    if (res$status == "OK") {
      cat(sprintf("  %s: %d rows, %d-%d\n", 
                  key, res$rows, res$year_min, res$year_max))
    }
  }
  cat("\n")
}

if (errors > 0) {
  cat("Datasets with errors:\n")
  for (key in names(results)) {
    if (results[[key]]$status == "ERROR") {
      cat("  -", key, ":", results[[key]]$error, "\n")
    }
  }
}

if (success == length(results)) {
  cat("\n✓ All test downloads successful!\n")
  cat("\nRecommendation: Data structure is compatible. Ready to download full dataset.\n")
} else {
  cat("\n⚠ Some downloads failed. Review errors above.\n")
}

cat("\nNext step: Run full data download with improved script\n")
