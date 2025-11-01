#!/usr/bin/env Rscript

# Check package installation status and create renv snapshot
cat("Checking package installation status...\n\n")

# List of required packages
required_packages <- c(
  "shiny", "shinydashboard", "shinyjs",
  "plotly", "ggplot2", "waterfalls", "RColorBrewer",
  "dplyr", "tidyr", "tidyverse",
  "feather", "arrow", "eurostat",
  "futile.logger", "fs", "yaml", "here"
)

# Check installation
all_installed <- TRUE
for (pkg in required_packages) {
  status <- requireNamespace(pkg, quietly = TRUE)
  if (status) {
    cat("✓", pkg, "\n")
  } else {
    cat("✗", pkg, "- NOT INSTALLED\n")
    all_installed <- FALSE
  }
}

if (all_installed) {
  cat("\n✓ All packages are installed!\n\n")
  
  # Create renv snapshot
  if (requireNamespace("renv", quietly = TRUE)) {
    cat("Creating renv snapshot...\n")
    library(renv)
    renv::snapshot(prompt = FALSE)
    cat("\n✓ renv snapshot created successfully!\n")
    cat("\nYour environment is now locked and reproducible.\n")
  }
} else {
  cat("\n⚠ Some packages are missing. Run install_packages.R again.\n")
}
