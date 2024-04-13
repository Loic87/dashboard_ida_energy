library(feather)

script_directory <- dirname(rstudioapi::getActiveDocumentContext()$path)
setwd(file.path(script_directory))

source("0_support/mapping_countries.R")

load_data <- function(
    dataset_id,
    country
){
  read_feather(
    paste0("../data/", dataset_id, "_", get_country_code(country), ".feather")
  )
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