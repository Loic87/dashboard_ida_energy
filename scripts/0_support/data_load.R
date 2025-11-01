library(arrow)  # Using arrow instead of feather (more actively maintained, backward compatible)
library(here)   # For portable path resolution

# Source mapping file using here for portable paths
source(here("scripts", "0_support", "mapping_countries.R"))

load_data <- function(
    dataset_id,
    country
){
  file_path <- here("data", paste0(dataset_id, "_", get_country_code(country), ".feather"))
  if (file.exists(file_path)) {
    file <- arrow::read_feather(file_path)
  } else {
    file <- data.frame()
  }
  if ("freq" %in% names(file)) {
    file <- file[,!(names(file) %in% "freq")]
  }
  file
}

load_industry_energy_consumption <- function(
    country
){
  load_data("nrg_bal_c", country)
}

load_industry_GVA <- function(
    country
){
  load_data("nama_10_a64", country)
}

load_road_vkm <- function(
    country
){
  load_data("road_tf_vehmov", country)
}

load_rail_vkm <- function(
    country
){
  load_data("rail_tf_trainmv", country)
}

load_iwww_vkm <- function(
    country
){
  load_data("iww_tf_vetf", country)
}

# Residential sector data loading functions
load_household_energy_breakdown <- function(
    country
){
  load_data("nrg_d_hhq", country)
}

load_household_demographics <- function(
    country
){
  load_data("demo_gind", country)
}

load_household_size <- function(
    country
){
  load_data("ilc_lvph01", country)
}

load_heating_cooling_degree_days <- function(
    country
){
  load_data("nrg_chdd_a", country)
}