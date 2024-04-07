library(eurostat)
library(tidyr)
library(dplyr)
library(yaml)

config <- yaml.load_file("config.yml")

# Set global parameters
eu27 <- eu_countries %>% filter(code != "UK")
geo_codes <- eu27$code %>% append("EU27")

first_year <- as.double(config$year$first)
last_year <- as.double(config$year$last)
country <- config$country

# Actions
download <- config$actions$download
clear <- config$actions$clear
run_context <- config$actions$context
run_industry_GVA_final <- config$actions$industry_GVA_final
run_industry_GVA_primary <- config$actions$industry_GVA_primary
run_economy_emp_final <- config$actions$economy_emp_final
run_household_final <- config$actions$household_final
run_transport_final <- config$actions$transport_final

# Set paths
data_path <- "data"
output_path <- "output"