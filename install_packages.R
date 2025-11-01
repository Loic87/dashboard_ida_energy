#!/usr/bin/env Rscript

# Install all required packages for Energy IDA Dashboard
cat("Installing required packages for Energy IDA Dashboard...\n\n")

# List of required packages
required_packages <- c(
  # Shiny framework
  "shiny",
  "shinydashboard",
  "shinyjs",
  
  # Visualization
  "plotly",
  "ggplot2",
  "waterfalls",
  "RColorBrewer",
  
  # Data manipulation
  "dplyr",
  "tidyr",
  "tidyverse",
  
  # Data I/O
  "feather",
  "arrow",
  
  # Eurostat API
  "eurostat",
  
  # Utilities
  "futile.logger",
  "fs",
  "yaml",
  "here"
)

# Check which packages are already installed
installed <- installed.packages()[, "Package"]
to_install <- required_packages[!required_packages %in% installed]

if (length(to_install) > 0) {
  cat("Installing", length(to_install), "packages:\n")
  cat(paste("-", to_install, collapse = "\n"), "\n\n")
  
  # Install missing packages
  install.packages(
    to_install,
    repos = "https://cloud.r-project.org",
    dependencies = TRUE
  )
  
  cat("\n✓ Package installation complete!\n")
} else {
  cat("✓ All required packages are already installed!\n")
}

# Verify installation
cat("\nVerifying package installation...\n")
failed <- c()
for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    failed <- c(failed, pkg)
    cat("✗", pkg, "- FAILED\n")
  } else {
    cat("✓", pkg, "- OK\n")
  }
}

if (length(failed) > 0) {
  cat("\n⚠ Warning: Some packages failed to install:\n")
  cat(paste("-", failed, collapse = "\n"), "\n")
  cat("\nPlease install them manually:\n")
  cat("install.packages(c('", paste(failed, collapse = "', '"), "'))\n")
} else {
  cat("\n✓ All packages installed successfully!\n")
  cat("\nYou can now run the dashboard with:\n")
  cat("  shiny::runApp('scripts')\n")
}
