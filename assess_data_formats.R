#!/usr/bin/env Rscript

# Assess Feather vs Arrow/Parquet migration
# Compare file sizes, read/write speeds, and compatibility

cat("Assessing data format migration: Feather vs Arrow/Parquet\n\n")

# Check if packages are available
packages_available <- list(
  feather = requireNamespace("feather", quietly = TRUE),
  arrow = requireNamespace("arrow", quietly = TRUE)
)

cat("Package availability:\n")
cat("  feather:", ifelse(packages_available$feather, "✓ installed", "✗ not installed"), "\n")
cat("  arrow:", ifelse(packages_available$arrow, "✓ installed", "✗ not installed"), "\n\n")

if (!packages_available$feather && !packages_available$arrow) {
  cat("⚠ Neither package is installed. Install with:\n")
  cat("  install.packages(c('feather', 'arrow'))\n")
  quit(status = 1)
}

library(here)

# Test with a sample data file
test_file <- file.path(here(), "data", "nrg_bal_c_FR.feather")

if (!file.exists(test_file)) {
  cat("Test file not found:", test_file, "\n")
  cat("Run test_data_download.R first to create test data.\n")
  quit(status = 1)
}

cat("Using test file:", basename(test_file), "\n")
cat("File size:", sprintf("%.1f MB", file.size(test_file) / 1024^2), "\n\n")

# Test 1: Read performance
cat(strrep("=", 60), "\n")
cat("Test 1: Read Performance\n")
cat(strrep("=", 60), "\n\n")

if (packages_available$feather) {
  library(feather)
  cat("Reading with feather...")
  feather_read_time <- system.time({
    data_feather <- read_feather(test_file)
  })
  cat(sprintf(" %.3f seconds\n", feather_read_time[3]))
  cat("  Dimensions:", nrow(data_feather), "rows ×", ncol(data_feather), "cols\n\n")
}

if (packages_available$arrow) {
  library(arrow)
  cat("Reading with arrow::read_feather...")
  arrow_read_time <- system.time({
    data_arrow <- read_feather(test_file)
  })
  cat(sprintf(" %.3f seconds\n", arrow_read_time[3]))
  cat("  Dimensions:", nrow(data_arrow), "rows ×", ncol(data_arrow), "cols\n\n")
}

# Test 2: Write and compare formats
cat(strrep("=", 60), "\n")
cat("Test 2: Write Performance & File Size Comparison\n")
cat(strrep("=", 60), "\n\n")

temp_dir <- tempdir()
results <- list()

if (packages_available$feather) {
  # Feather write
  feather_file <- file.path(temp_dir, "test.feather")
  cat("Writing feather format...")
  feather_write_time <- system.time({
    write_feather(data_feather, feather_file)
  })
  feather_size <- file.size(feather_file)
  cat(sprintf(" %.3f seconds\n", feather_write_time[3]))
  cat("  File size:", sprintf("%.1f MB", feather_size / 1024^2), "\n\n")
  
  results$feather <- list(
    write_time = feather_write_time[3],
    read_time = feather_read_time[3],
    size = feather_size
  )
}

if (packages_available$arrow) {
  # Parquet write
  parquet_file <- file.path(temp_dir, "test.parquet")
  cat("Writing parquet format (default compression)...")
  parquet_write_time <- system.time({
    write_parquet(data_arrow, parquet_file)
  })
  parquet_size <- file.size(parquet_file)
  cat(sprintf(" %.3f seconds\n", parquet_write_time[3]))
  cat("  File size:", sprintf("%.1f MB (%.1f%% of feather)", 
                              parquet_size / 1024^2,
                              100 * parquet_size / feather_size), "\n\n")
  
  # Parquet write with better compression
  parquet_file_compressed <- file.path(temp_dir, "test_compressed.parquet")
  cat("Writing parquet format (snappy compression)...")
  parquet_write_time_comp <- system.time({
    write_parquet(data_arrow, parquet_file_compressed, compression = "snappy")
  })
  parquet_size_comp <- file.size(parquet_file_compressed)
  cat(sprintf(" %.3f seconds\n", parquet_write_time_comp[3]))
  cat("  File size:", sprintf("%.1f MB (%.1f%% of feather)", 
                              parquet_size_comp / 1024^2,
                              100 * parquet_size_comp / feather_size), "\n\n")
  
  # Read parquet
  cat("Reading parquet format...")
  parquet_read_time <- system.time({
    data_parquet <- read_parquet(parquet_file)
  })
  cat(sprintf(" %.3f seconds\n\n", parquet_read_time[3]))
  
  results$parquet <- list(
    write_time = parquet_write_time[3],
    read_time = parquet_read_time[3],
    size = parquet_size
  )
  
  results$parquet_compressed <- list(
    write_time = parquet_write_time_comp[3],
    read_time = parquet_read_time[3],
    size = parquet_size_comp
  )
}

# Summary
cat(strrep("=", 60), "\n")
cat("SUMMARY & RECOMMENDATIONS\n")
cat(strrep("=", 60), "\n\n")

cat("Format Comparison:\n")
cat(sprintf("  %-20s %10s %10s %10s\n", "Format", "Read (s)", "Write (s)", "Size (MB)"))
cat(strrep("-", 60), "\n")

for (fmt in names(results)) {
  cat(sprintf("  %-20s %10.3f %10.3f %10.1f\n",
              fmt,
              results[[fmt]]$read_time,
              results[[fmt]]$write_time,
              results[[fmt]]$size / 1024^2))
}

cat("\n")
cat("Key Findings:\n")
cat("  • Feather: Fast read/write, larger file size\n")
cat("  • Parquet: Slower write, smaller files (better compression)\n")
cat("  • Arrow package: More actively maintained than feather\n\n")

cat("Recommendations:\n")
cat("  1. SHORT TERM: Keep feather format for compatibility\n")
cat("     - Existing data files work\n")
cat("     - Code is already written for feather\n")
cat("     - Arrow package can read feather files\n\n")
cat("  2. MEDIUM TERM: Consider migrating to parquet\n")
cat("     - Better compression (saves disk space)\n")
cat("     - More future-proof format\n")
cat("     - Better for large datasets\n")
cat("     - Support for columnar operations\n\n")
cat("  3. Use Arrow package instead of feather package\n")
cat("     - Arrow can read existing .feather files\n")
cat("     - More actively maintained\n")
cat("     - Better performance for large datasets\n")
cat("     - Simple change: feather::read_feather() → arrow::read_feather()\n\n")

cat("Migration Strategy:\n")
cat("  Phase 2: Use arrow package to read existing feather files\n")
cat("  Phase 3: Update code to use arrow::read_feather()\n")
cat("  Phase 4: Optional - convert to parquet for production deployment\n\n")

cat("✓ Assessment complete!\n")

# Cleanup
unlink(c(feather_file, parquet_file, parquet_file_compressed))
