#!/usr/bin/env Rscript

# Phase 2 - Test Eurostat API Compatibility
cat("Testing Eurostat API compatibility...\n\n")

# Load required packages
if (!requireNamespace("eurostat", quietly = TRUE)) {
  cat("Installing eurostat package...\n")
  install.packages("eurostat", repos = "https://cloud.r-project.org")
}

library(eurostat)

cat("Eurostat package version:", as.character(packageVersion("eurostat")), "\n\n")

# Test 1: Check if we can access Eurostat
cat("Test 1: Checking Eurostat API access...\n")
tryCatch({
  # Try to get table of contents
  toc <- get_eurostat_toc()
  cat("✓ Successfully connected to Eurostat API\n")
  cat("  Available datasets:", nrow(toc), "\n\n")
}, error = function(e) {
  cat("✗ Error connecting to Eurostat API:\n")
  cat("  ", as.character(e), "\n\n")
})

# Test 2: Test key datasets used in the project
cat("Test 2: Checking dataset availability and structure...\n\n")

datasets <- list(
  list(id = "nrg_bal_c", desc = "Energy balance sheets", 
       filters = list(geo = "FR", unit = "TJ", time = "2022")),
  list(id = "nama_10_a64", desc = "National accounts - GVA by sector",
       filters = list(geo = "FR", na_item = "B1G", unit = "CLV10_MEUR", time = "2022")),
  list(id = "demo_gind", desc = "Population indicators",
       filters = list(geo = "FR", indic_de = "AVG", time = "2022")),
  list(id = "ilc_lvph01", desc = "Household size",
       filters = list(geo = "FR", unit = "AVG", time = "2022"))
)

results <- list()
for (dataset in datasets) {
  cat("Testing:", dataset$id, "-", dataset$desc, "\n")
  
  tryCatch({
    # Try to fetch a small sample
    data <- get_eurostat(id = dataset$id, 
                        time_format = "num",
                        filters = dataset$filters,
                        cache = FALSE)
    
    if (nrow(data) > 0) {
      cat("  ✓ Dataset accessible, retrieved", nrow(data), "rows\n")
      cat("  Columns:", paste(names(data), collapse = ", "), "\n")
      
      # Check year range
      if ("time" %in% names(data)) {
        year_range <- range(data$time, na.rm = TRUE)
        cat("  Year range available:", year_range[1], "-", year_range[2], "\n")
      }
      
      results[[dataset$id]] <- list(status = "OK", rows = nrow(data))
    } else {
      cat("  ⚠ Dataset accessible but returned 0 rows\n")
      results[[dataset$id]] <- list(status = "EMPTY", rows = 0)
    }
  }, error = function(e) {
    cat("  ✗ Error:", as.character(e), "\n")
    results[[dataset$id]] <- list(status = "ERROR", error = as.character(e))
  })
  cat("\n")
}

# Test 3: Check latest available year for energy data
cat("Test 3: Checking latest available year for energy data...\n")
tryCatch({
  data <- get_eurostat(id = "nrg_bal_c",
                      time_format = "num",
                      filters = list(geo = "FR", unit = "TJ"),
                      cache = FALSE)
  
  if ("time" %in% names(data) && nrow(data) > 0) {
    latest_year <- max(data$time, na.rm = TRUE)
    cat("✓ Latest available year for energy data:", latest_year, "\n\n")
  }
}, error = function(e) {
  cat("✗ Could not determine latest year\n\n")
})

# Summary
cat(paste(rep("=", 60), collapse = ""), "\n")
cat("SUMMARY\n")
cat(paste(rep("=", 60), collapse = ""), "\n\n")

success_count <- sum(sapply(results, function(x) x$status == "OK"))
cat("Datasets tested:", length(results), "\n")
cat("Successful:", success_count, "\n")
cat("Failed/Empty:", length(results) - success_count, "\n\n")

if (success_count == length(results)) {
  cat("✓ All datasets accessible! Eurostat API is working.\n")
  cat("\nRecommendation: Proceed with updating year ranges in config.yml\n")
} else {
  cat("⚠ Some datasets had issues. Review errors above.\n")
  cat("\nRecommendation: Investigate failed datasets before proceeding.\n")
}

cat("\nNext steps:\n")
cat("  1. Update config.yml with latest year ranges\n")
cat("  2. Test data download for sample countries\n")
cat("  3. Verify data structure compatibility\n")
