# Prepare for potential exceptions
full_sector_base_year <- function(country, first_year) {
  year <- case_when(
    TRUE ~ first_year
  )
  year
}

full_sector_last_year <- function(country, final_year) {
  year <- case_when(
    TRUE ~ final_year
  )
  year
}


industry_GVA_base_year <- function(country, first_year) {
  year <- case_when(
    country == "MT" ~ 2012,
    TRUE ~ first_year
  )
  year
}

industry_GVA_last_year <- function(country, final_year) {
  year <- case_when(
    country == "BE" ~ 2020,
    country == "DE" ~ 2020,
    country == "CY" ~ 2020,
    country == "DK" ~ 2020,
    country == "ES" ~ 2020,
    country == "FR" ~ 2020,
    country == "IT" ~ 2020,
    country == "LT" ~ 2020,
    country == "LV" ~ 2020,
    country == "PL" ~ 2020,
    country == "PT" ~ 2020,
    country == "SE" ~ 2020,
    country == "EU27" ~ 2020,
    TRUE ~ final_year
  )
  year
}

economy_emp_base_year <- function(country, first_year) {
  year <- case_when(
    TRUE ~ first_year
  )
  year
}

economy_emp_last_year <- function(country, final_year) {
  year <- case_when(
    TRUE ~ final_year
  )
  year
}

household_base_year <- function(country, first_year) {
  case_when(
    TRUE ~ first_year
  )
}

household_last_year <- function(country, final_year) {
  case_when(
    country == "HU" ~ 2019,
    TRUE ~ final_year
  )
}

transport_base_year <- function(country, first_year) {
  case_when(
    country == "BE" ~ 2013,
    country == "DE" ~ 2013,
    country == "DK" ~ 2013,
    country == "FR" ~ 2013,
    country == "EE" ~ 2013,
    country == "HU" ~ 2013,
    country == "IE" ~ 2013,
    country == "MT" ~ 2013,
    country == "NL" ~ 2013,
    country == "RO" ~ 2011,
    country == "SE" ~ 2013,
    country == "SI" ~ 2015,
    TRUE ~ first_year
  )
}

transport_last_year <- function(country, final_year) {
  case_when(
    country == "AT" ~ 2017,
    country == "BE" ~ 2015,
    country == "CY" ~ 2011,
    country == "PL" ~ 2015,
    country == "FI" ~ 2020,
    TRUE ~ final_year
  )
}