#!/usr/bin/env Rscript

# Install packages using renv
cat("Installing packages with renv...\n\n")

# Ensure renv is loaded
library(renv)

# List of packages to install
packages <- c(
  "shiny", "shinydashboard", "shinyjs",
  "plotly", "ggplot2", "waterfalls", "RColorBrewer",
  "dplyr", "tidyr", "tidyverse",
  "feather", "arrow", "eurostat",
  "futile.logger", "fs", "yaml", "here"
)

cat("Installing", length(packages), "packages using renv...\n\n")

# Install packages via renv
renv::install(packages)

cat("\n✓ Installation complete!\n")
cat("\nCreating snapshot...\n")
renv::snapshot(prompt = FALSE)

cat("\n✓ Phase 1 complete! Environment setup is ready.\n")
cat("\nNext steps:\n")
cat("  - Update config.yml with desired year range\n")
cat("  - Test data download: source('scripts/0_support/data_download.R')\n")
cat("  - Run dashboard: shiny::runApp('scripts')\n")
