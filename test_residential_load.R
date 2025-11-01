#!/usr/bin/env Rscript

# Test residential sector data loading with new load functions
library(arrow)
library(here)
library(dplyr)

# Source files
source(here("scripts", "0_support", "mapping_countries.R"))
source(here("scripts", "0_support", "data_load.R"))

# Test countries
test_countries <- c("Belgium", "France", "Germany")

cat("\n=== Testing Residential Sector Data Loading ===\n")

for (country in test_countries) {
  cat(sprintf("\n--- Testing %s ---\n", country))
  
  # Load data using new functions
  nrg_bal_c <- load_industry_energy_consumption(country)
  nrg_d_hhq <- load_household_energy_breakdown(country)
  nrg_chdd_a <- load_heating_cooling_degree_days(country)
  demo_gind <- load_household_demographics(country)
  ilc_lvph01 <- load_household_size(country)
  
  # Check data
  cat(sprintf("  nrg_bal_c: %d rows\n", nrow(nrg_bal_c)))
  cat(sprintf("  nrg_d_hhq: %d rows\n", nrow(nrg_d_hhq)))
  cat(sprintf("  nrg_chdd_a: %d rows\n", nrow(nrg_chdd_a)))
  cat(sprintf("  demo_gind: %d rows\n", nrow(demo_gind)))
  cat(sprintf("  ilc_lvph01: %d rows\n", nrow(ilc_lvph01)))
  
  # Check if we can filter household energy consumption
  if (nrow(nrg_bal_c) > 0) {
    hh_energy <- nrg_bal_c %>% filter(nrg_bal == "FC_OTH_HH_E")
    cat(sprintf("  Household energy (FC_OTH_HH_E): %d rows\n", nrow(hh_energy)))
    
    if (nrow(hh_energy) > 0) {
      cat(sprintf("  ✓ Years: %d to %d\n", min(hh_energy$time), max(hh_energy$time)))
      cat(sprintf("  ✓ PASS\n"))
    } else {
      cat(sprintf("  ✗ FAIL: No household energy data found\n"))
    }
  } else {
    cat(sprintf("  ✗ FAIL: No nrg_bal_c data found\n"))
  }
}

cat("\n=== Test Complete ===\n")
