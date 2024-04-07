# CLEAR THE REPOSITORIES
library(futile.logger)

create_folder_if_not_exists <- function(path) {
  if (!dir.exists(path)) {
    dir.create(path, recursive = TRUE)
    flog.info(paste("Create folder:", path))
  }
}

# Data preparation
clear_all <- function(country,
                      chart_path) {
  # Define the list as the whole list
  country_list <- geo_codes

  if (country == "all") {
    countries <- geo_codes
    flog.info(paste("Empty all the country folders"))
  } else {
    countries <- country
  }

  for (country_chart in countries) {
    # Output charts
    outputpath <- paste(chart_path, "/", country_chart, "/", sep = "")
    if (dir.exists(outputpath)){
      tryCatch(
        {
          unlink(paste0(outputpath, "*"))
          flog.info(paste("Empty the folder: ", outputpath))
        },
        error = function(e) {
          flog.error(paste("Error clearing the folder: ", country_chart), e)
        }
      )
    }
  }
}