# Test dashboard functionality with multiple countries
# This script verifies that the data compatibility fixes work across different countries

library(here)
library(arrow)
library(dplyr)

# Source the data loading functions
source(here("scripts", "0_support", "data_load.R"))
source(here("scripts", "0_support", "mapping_years.R"))
source(here("scripts", "1_industry", "1a_industry_gva_final.R"))

# Test countries
test_countries <- c("Belgium", "France", "Germany", "Austria", "Spain", "Italy")

cat("=================================================================\n")
cat("Testing Industry GVA Data Compatibility\n")
cat("=================================================================\n\n")

results <- data.frame(
  Country = character(),
  Data_Available = logical(),
  NACE_Codes = integer(),
  Has_C17 = logical(),
  Has_C18 = logical(),
  Years_Available = character(),
  Status = character(),
  stringsAsFactors = FALSE
)

for (country in test_countries) {
  cat(paste0("Testing: ", country, "\n"))
  cat(paste0(rep("-", 50), collapse = ""), "\n")
  
  tryCatch({
    # Load the data
    nama_data <- load_industry_GVA(country)
    
    if (nrow(nama_data) == 0) {
      results <- rbind(results, data.frame(
        Country = country,
        Data_Available = FALSE,
        NACE_Codes = 0,
        Has_C17 = FALSE,
        Has_C18 = FALSE,
        Years_Available = "N/A",
        Status = "No data",
        stringsAsFactors = FALSE
      ))
      cat("  ✗ No data available\n\n")
      next
    }
    
    # Check NACE codes
    nace_codes <- unique(nama_data$nace_r2)
    has_c17 <- "C17" %in% nace_codes
    has_c18 <- "C18" %in% nace_codes
    
    # Check years
    years <- sort(unique(nama_data$time))
    year_range <- paste(min(years), "-", max(years))
    
    # Try to prepare the data (this will catch any processing errors)
    prepared_data <- prepare_industry_GVA_by_sector(
      nama_10_a64 = nama_data,
      first_year = max(min(years), 2015),
      last_year = max(years)
    )
    
    processing_ok <- !is.null(prepared_data$df) && nrow(prepared_data$df) > 0
    
    # Record results
    status <- if (processing_ok && has_c17 && has_c18) {
      "✓ PASS"
    } else if (!processing_ok) {
      "✗ Processing failed"
    } else {
      "⚠ Missing NACE codes"
    }
    
    results <- rbind(results, data.frame(
      Country = country,
      Data_Available = TRUE,
      NACE_Codes = length(nace_codes),
      Has_C17 = has_c17,
      Has_C18 = has_c18,
      Years_Available = year_range,
      Status = status,
      stringsAsFactors = FALSE
    ))
    
    cat(paste0("  Data rows: ", nrow(nama_data), "\n"))
    cat(paste0("  NACE codes: ", length(nace_codes), "\n"))
    cat(paste0("  Has C17: ", has_c17, "\n"))
    cat(paste0("  Has C18: ", has_c18, "\n"))
    cat(paste0("  Years: ", year_range, "\n"))
    cat(paste0("  Processing: ", ifelse(processing_ok, "✓ OK", "✗ FAILED"), "\n"))
    cat(paste0("  Status: ", status, "\n\n"))
    
  }, error = function(e) {
    results <- rbind(results, data.frame(
      Country = country,
      Data_Available = FALSE,
      NACE_Codes = 0,
      Has_C17 = FALSE,
      Has_C18 = FALSE,
      Years_Available = "N/A",
      Status = paste0("✗ ERROR: ", e$message),
      stringsAsFactors = FALSE
    ))
    cat(paste0("  ✗ ERROR: ", e$message, "\n\n"))
  })
}

cat("=================================================================\n")
cat("SUMMARY\n")
cat("=================================================================\n\n")

print(results)

# Count successes
passed <- sum(grepl("PASS", results$Status))
total <- nrow(results)

cat("\n")
cat(paste0("Passed: ", passed, " / ", total, "\n"))

if (passed == total) {
  cat("\n✅ All tests passed! Data compatibility confirmed across all countries.\n")
} else {
  cat("\n⚠️  Some tests failed. Review the results above.\n")
}
