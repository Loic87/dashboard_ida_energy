#!/usr/bin/env Rscript

# Setup script for renv initialization
cat("Setting up renv for Energy IDA Dashboard...\n\n")

# Install renv if not available
if (!requireNamespace("renv", quietly = TRUE)) {
  cat("Installing renv package...\n")
  install.packages("renv", repos = "https://cloud.r-project.org")
}

# Load renv
library(renv)

# Initialize renv with bare setup (no snapshot yet)
cat("\nInitializing renv...\n")
renv::init(bare = TRUE, restart = FALSE)

cat("\nrenv initialized successfully!\n")
cat("Next steps:\n")
cat("  1. Install required packages: renv::restore()\n")
cat("  2. Or snapshot current packages: renv::snapshot()\n")
