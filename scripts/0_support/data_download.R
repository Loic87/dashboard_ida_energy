library(futile.logger)
library(eurostat)
library(tidyr)
library(dplyr)
library(feather)

script_directory <- dirname(rstudioapi::getActiveDocumentContext()$path)
setwd(file.path(script_directory))

source("0_support/mapping_countries.R")

# Function to fetch Eurostat data, write to a file, and log the process.
fetch_write_log <- function(country_code,
                            dataset_id,
                            filters) {
  country_long <- get_country_long(country_code)
  
  # Attempt to fetch data and handle errors within the function
  tryCatch({
    data <- get_eurostat(id = dataset_id,
                         time_format = "num",
                         filters = filters)
    # Check if 'freq' column exists and drop it
    if ("freq" %in% names(data)) {
      data <- data[,!(names(data) %in% "freq")]
    }
    # Constructing file path dynamically based on parameters
    file_path <-
      paste0("../data/", dataset_id, "_", country_code, ".feather")
    write_feather(data, file_path)
    flog.info(paste0("Loaded data from ", dataset_id, " for: ", country_long))
  }, error = function(e) {
    flog.error(
      paste0(
        "Error in updating data from ",
        dataset_id,
        ", country: ",
        country_long,
        ", error :"
      ),
      e
    )
  })
}

# Loop through each country code
for (country_code in country_code_list) {
  # Fetch and log datasets
  # fetch_write_log(country_code,
  #                 "nrg_bal_c",
  #                 list(geo = country_code, freq = "A", unit = c("TJ", "GWH"))
  #                 )
  # fetch_write_log(country_code,
  #                 "nama_10_a64",
  #                 list(geo = country_code, freq = "A", na_item = "B1G",unit = "CLV10_MEUR")
  #                 )
  # fetch_write_log(country_code,
  #                 "road_tf_vehmov",
  #                 list(geo = country_code, freq = "A", vehicle = "TOTAL")
  #                 )
  # fetch_write_log(country_code,
  #                 "rail_tf_trainmv",
  #                 list(geo = country_code, freq = "A", train = "TOTAL", unit = "THS_TRKM")
  #                 )
  # fetch_write_log(country_code,
  #                 "iww_tf_vetf",
  #                 list(geo = country_code, freq = "A", tra_cov = "TOTAL", loadstat = "TOTAL", unit = "THS_VESKM")
  #                 )
  fetch_write_log(country_code,
                  "nama_10_a10_e",
                  list(geo = country_code, freq = "A", na_item = "EMP_DC", unit = "THS_PER")
                  )
  fetch_write_log(country_code,
                  "nrg_d_hhq",
                  list(geo = country_code, freq = "A", siec = "TOTAL", unit = "TJ")
                  )
  fetch_write_log(country_code,
                  "nrg_chdd_a",
                  list(geo = country_code, freq = "A")
                  )
  fetch_write_log(country_code,
                  "demo_gind",
                  list(geo = country_code, freq = "A", indic_de = "AVG")
                  )
  fetch_write_log(country_code,
                  "ilc_lvph01",
                  list(geo = country_code, freq = "A", unit = "AVG")
                  )
  }