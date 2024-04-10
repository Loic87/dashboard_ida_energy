library(eurostat)
library(tidyr)
library(dplyr)
library(feather)
library(here)
library(futile.logger)

source("scripts/0_support/mapping_countries.R")

for (country_code in country_code_list) {
  country_long <- get_country_long(country_code)
  tryCatch(
    {
    nrg_bal_c <- get_eurostat(
      id = "nrg_bal_c", 
      time_format = "num", 
      filters = list(
        geo = country_code,
        unit = c("TJ", "GWH")
        )
      )
    
    write_feather(
      nrg_bal_c, 
      paste0("data/nrg_bal_c_", country_code, ".feather")
      )
    flog.info(paste0("Loaded data from nrg_bal_c for: ", country_long))
    },
    error = function(e) {
      flog.error(paste0("Error in updating data from nrg_bal_c, country: ", country_long, ", error :"), e)
    }
  )
}
