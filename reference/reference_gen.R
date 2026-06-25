#!/usr/bin/env Rscript
# Generate reference outputs from the R pipeline for Python parity testing.
# Writes CSVs to python/reference/<country>_<stage>.csv

suppressMessages({
  library(arrow)
  library(dplyr)
  library(tidyr)
  library(here)
  library(futile.logger)
})
flog.threshold(ERROR)

root <- here::here()
source(file.path(root, "legacy", "scripts", "0_support", "mapping_years.R"))
source(file.path(root, "legacy", "scripts", "1_industry", "1a_industry_gva_final.R"))
source(file.path(root, "legacy", "scripts", "3_transport", "transport_VKM.R"))

out_dir <- file.path(root, "reference")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

COUNTRIES <- c("FR", "DE", "IT")
FIRST_YEAR <- 2000
LAST_YEAR <- 2021

read_ds <- function(dataset_id, code) {
  path <- file.path(root, "data", paste0(dataset_id, "_", code, ".feather"))
  if (file.exists(path)) arrow::read_feather(path) else data.frame()
}

write_ref <- function(df, code, stage) {
  if (is.null(df) || nrow(df) == 0) return(invisible())
  # stable ordering for deterministic comparison
  df <- df %>% arrange(across(everything()))
  write.csv(df, file.path(out_dir, paste0(code, "_", stage, ".csv")), row.names = FALSE)
}

for (code in COUNTRIES) {
  nrg_bal_c <- read_ds("nrg_bal_c", code)
  nama_10_a64 <- read_ds("nama_10_a64", code)

  ebp <- prepare_industry_energy_consumption_by_product(nrg_bal_c, FIRST_YEAR, LAST_YEAR)
  ebs <- prepare_industry_energy_consumption_by_sector(nrg_bal_c, FIRST_YEAR, LAST_YEAR)
  gva <- prepare_industry_GVA_by_sector(nama_10_a64, FIRST_YEAR, LAST_YEAR)

  years <- get_years_with_data(
    activity_df = gva$df, activity_col = "GVA",
    energy_df = ebs, energy_col = "energy_consumption",
    first_year = FIRST_YEAR, last_year = LAST_YEAR)
  fy <- years[[1]]; ly <- years[[2]]

  decomp <- prepare_industry_GVA_decomposition(gva$df, ebs, fy, ly)
  lmdi <- apply_LMDI_industry_gva(decomp$df, fy)

  write_ref(ebp, code, "energy_by_product")
  write_ref(ebs, code, "energy_by_sector")
  write_ref(gva$df, code, "gva_by_sector")
  write_ref(decomp$df, code, "decomposition")
  write_ref(lmdi, code, "lmdi")
  cat(sprintf("%s: years_with_data=[%s, %s]  lmdi_rows=%d\n", code, fy, ly, nrow(lmdi)))
}

# --- Transport ----------------------------------------------------------------
# Eurostat transport VKM (road + inland-waterway) is sparse at series endpoints,
# so a mode survives the decomposition only where both endpoint years have data.
# Over 2012-2016, CZ and RO yield Navigation+Rail and NL yields Road, so the set
# collectively exercises all three modes with non-empty decompositions. (The
# previous LV/IT had no inland-waterway data at all -> Rail-only.)
TRA_COUNTRIES <- c("CZ", "RO", "NL")
TRA_FIRST <- 2012
TRA_LAST <- 2016

for (code in TRA_COUNTRIES) {
  nrg_bal_c <- read_ds("nrg_bal_c", code)
  road <- read_ds("road_tf_vehmov", code)
  rail <- read_ds("rail_tf_trainmv", code)
  iww <- read_ds("iww_tf_vetf", code)

  tebp <- prepare_transport_energy_consumption_by_product(nrg_bal_c, TRA_FIRST, TRA_LAST)
  tebm <- prepare_transport_energy_consumption_by_mode(nrg_bal_c, TRA_FIRST, TRA_LAST)
  vkm <- prepare_transport_vkm(road, rail, iww, TRA_FIRST, TRA_LAST)

  years <- get_years_with_data(
    activity_df = vkm$df, activity_col = "VKM",
    energy_df = tebm, energy_col = "energy_consumption",
    first_year = TRA_FIRST, last_year = TRA_LAST)
  fy <- years[[1]]; ly <- years[[2]]

  decomp <- prepare_transport_vkm_decomposition(vkm$df, tebm, fy, ly)
  lmdi <- apply_LMDI_transport_vkm(decomp$df, fy)

  write_ref(tebp, code, "tra_energy_by_product")
  write_ref(tebm, code, "tra_energy_by_mode")
  write_ref(vkm$df, code, "tra_vkm_by_mode")
  write_ref(decomp$df, code, "tra_decomposition")
  write_ref(lmdi, code, "tra_lmdi")
  cat(sprintf("%s (transport): years=[%s, %s]  lmdi_rows=%d\n", code, fy, ly, nrow(lmdi)))
}
cat("Reference generation complete.\n")
