## .Rprofile -- Configuration for R session initialization
##
## This file is executed when R starts up. It sets up the environment
## for the Energy IDA Dashboard project.

# Activate renv for this project if it exists
if (file.exists("renv/activate.R")) {
  source("renv/activate.R")
}

# Set project root using here package
if (requireNamespace("here", quietly = TRUE)) {
  here::i_am(".Rprofile")
}

# Set options for better package management
options(
  repos = c(CRAN = "https://cloud.r-project.org"),
  browserNLdisabled = TRUE,
  deparse.max.lines = 2
)

# Display welcome message
if (interactive()) {
  cat("\n")
  cat("╔═══════════════════════════════════════════════════════════════╗\n")
  cat("║   Energy Decomposition Analysis Dashboard                     ║\n")
  cat("║   Eurostat IDA Energy Project                                 ║\n")
  cat("╚═══════════════════════════════════════════════════════════════╝\n")
  cat("\n")
  cat("Project initialized. Working directory:", getwd(), "\n")
  cat("\n")
  cat("Quick start:\n")
  cat("  1. Run the dashboard: shiny::runApp('scripts')\n")
  cat("  2. Update data: source('scripts/0_support/data_download.R')\n")
  cat("  3. Edit config: edit('config.yml')\n")
  cat("\n")
}
