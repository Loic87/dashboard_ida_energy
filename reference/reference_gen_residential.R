#!/usr/bin/env Rscript
# Reference outputs for the RESIDENTIAL sector parity tests.
#
# The residential functions are reproduced here from
# scripts/2_household/households.R, with two changes required to make them run
# and match the dashboard's interactive year selection:
#   1. a trailing-comma bug in join_energy_consumption_activity is fixed
#      (`c("space_heating", "space_cooling",)` -> errors in R as written);
#   2. base year is the computed first-year-with-data (household_base_year in
#      the original simply returns first_year, with no country exceptions).
# The decomposition math is otherwise identical to the R source.

suppressMessages({library(arrow); library(dplyr); library(tidyr); library(here)})

root <- here::here()
out_dir <- file.path(root, "reference")
COUNTRIES <- c("FR", "DE", "IT")
UI_FIRST <- 2005
UI_LAST <- 2021

read_ds <- function(id, code) {
  p <- file.path(root, "data", paste0(id, "_", code, ".feather"))
  if (file.exists(p)) arrow::read_feather(p) else data.frame()
}
write_ref <- function(df, code, stage) {
  if (is.null(df) || nrow(df) == 0) return(invisible())
  df <- df %>% arrange(across(everything()))
  write.csv(df, file.path(out_dir, paste0(code, "_res_", stage, ".csv")),
            row.names = FALSE)
}

prepare_energy_consumption <- function(nrg_bal_c, nrg_d_hhq, first_year, last_year) {
  agg <- nrg_bal_c %>%
    filter(time >= first_year, time <= last_year, nrg_bal == "FC_OTH_HH_E",
           siec == "TOTAL", unit == "TJ") %>%
    select(geo, time, values) %>% rename(total_bal = values)
  dis <- nrg_d_hhq %>%
    filter(time >= first_year, time <= last_year, siec == "TOTAL", unit == "TJ") %>%
    pivot_wider(names_from = nrg_bal, values_from = values) %>%
    select(-c(siec, unit)) %>%
    rename(total_res = FC_OTH_HH_E, space_heating = FC_OTH_HH_E_SH,
           space_cooling = FC_OTH_HH_E_SC, water_heating = FC_OTH_HH_E_WH,
           cooking = FC_OTH_HH_E_CK, light_appliances = FC_OTH_HH_E_LE,
           other = FC_OTH_HH_E_OE)
  na0 <- function(x) replace(x, which(x <= 0), NA)
  agg$total_bal <- na0(agg$total_bal)
  for (c0 in c("total_res", "cooking", "light_appliances", "other",
               "space_cooling", "space_heating", "water_heating"))
    dis[[c0]] <- na0(dis[[c0]])
  full_join(agg, dis, by = c("geo", "time"))
}

prepare_activity <- function(demo_gind, ilc_lvph01, nrg_chdd_a, first_year, last_year) {
  pop <- demo_gind %>%
    filter(time >= first_year, time <= last_year, indic_de == "AVG") %>%
    select(-indic_de) %>% rename(total_pop = values)
  size_HH <- ilc_lvph01 %>%
    filter(time >= first_year, time <= last_year) %>%
    select(-unit) %>% rename(HH_size = values)
  CHDD <- nrg_chdd_a %>%
    pivot_wider(names_from = indic_nrg, values_from = values) %>%
    group_by(geo) %>%
    mutate(CDD_norm = CDD / mean(CDD), HDD_norm = HDD / mean(HDD)) %>%
    filter(time >= first_year, time <= last_year) %>% select(-unit) %>% ungroup()
  na0 <- function(x) replace(x, which(x <= 0), NA)
  pop$total_pop <- na0(pop$total_pop)
  size_HH$HH_size <- na0(size_HH$HH_size)
  CHDD$CDD_norm <- na0(CHDD$CDD_norm)
  CHDD$HDD_norm <- na0(CHDD$HDD_norm)
  pop %>% full_join(size_HH, by = c("geo", "time")) %>%
    full_join(CHDD, by = c("geo", "time"))
}

join_energy_consumption_activity <- function(df) {
  df %>%
    mutate(
      occupied_dwellings = total_pop / HH_size,
      space_heating_corrected = ifelse(is.na(HDD_norm), space_heating, space_heating / HDD_norm),
      space_cooling_corrected = ifelse(is.na(CDD_norm), space_cooling, space_cooling / CDD_norm)
    ) %>%
    mutate(
      total_res_corrected = rowSums(select(., c("total_bal", "space_heating_corrected",
        "space_cooling_corrected")), na.rm = TRUE) -
        rowSums(select(., c("space_heating", "space_cooling")), na.rm = TRUE),
      total_res = total_bal,
      total_res_corrected = ifelse(is.na(total_res_corrected) | (total_res_corrected == 0),
        total_bal, total_res_corrected),
      dwelling_per_cap = 1 / HH_size,
      temperature_correction = ifelse(total_res_corrected == 0, total_res,
        total_res / total_res_corrected),
      energy_per_dwelling = total_res_corrected / occupied_dwellings
    ) %>%
    pivot_longer(cols = -c(geo, time), names_to = "measure", values_to = "value") %>%
    arrange(time) %>% mutate(time = as.integer(time))
}

add_index_delta <- function(df, base_year) {
  df %>% group_by(geo, measure) %>%
    mutate(value_indexed = value / value[time == base_year],
           value_delta = value - value[time == base_year]) %>% ungroup()
}

apply_LMDI <- function(df, base_year) {
  df %>%
    pivot_wider(names_from = measure, values_from = c(value, value_indexed, value_delta)) %>%
    mutate(
      weighting_factor = ifelse(value_delta_total_res == 0, value_total_res,
        value_delta_total_res / log(value_indexed_total_res)),
      population_log = log(value_indexed_total_pop),
      household_size_log = log(value_indexed_dwelling_per_cap),
      weather_log = log(value_indexed_temperature_correction),
      household_consumption_log = log(value_indexed_energy_per_dwelling)
    ) %>%
    select(geo, time, weighting_factor, value_total_res, value_delta_total_res,
           population_log, household_size_log, weather_log, household_consumption_log) %>%
    mutate(value_energy_consumption_end = value_total_res) %>%
    group_by(geo) %>%
    mutate(value_energy_consumption_baseline = value_total_res[time == base_year]) %>%
    ungroup() %>%
    mutate(
      population = weighting_factor * population_log,
      household_size = weighting_factor * household_size_log,
      weather = weighting_factor * weather_log,
      household_consumption = weighting_factor * household_consumption_log
    ) %>%
    select(-c(value_total_res, weighting_factor, population_log, household_size_log,
              weather_log, household_consumption_log)) %>%
    mutate(energy_consumption_delta_calc = rowSums(select(., c("population",
      "household_size", "weather", "household_consumption")), na.rm = TRUE))
}

years_with_data <- function(consumption, activity, first_year, last_year) {
  e <- consumption %>% filter(!is.na(total_bal), total_bal > 0)
  a <- activity %>% filter(!is.na(total_pop), total_pop > 0, !is.na(HH_size), HH_size > 0)
  if (nrow(e) == 0 || nrow(a) == 0) return(NULL)
  list(max(min(e$time), min(a$time), first_year), min(max(e$time), max(a$time), last_year))
}

for (code in COUNTRIES) {
  nrg_bal_c <- read_ds("nrg_bal_c", code)
  nrg_d_hhq <- read_ds("nrg_d_hhq", code)
  demo_gind <- read_ds("demo_gind", code)
  ilc_lvph01 <- read_ds("ilc_lvph01", code)
  nrg_chdd_a <- read_ds("nrg_chdd_a", code)

  consumption <- prepare_energy_consumption(nrg_bal_c, nrg_d_hhq, UI_FIRST, UI_LAST)
  activity <- prepare_activity(demo_gind, ilc_lvph01, nrg_chdd_a, UI_FIRST, UI_LAST)
  yrs <- years_with_data(consumption, activity, UI_FIRST, UI_LAST)
  fy <- yrs[[1]]; ly <- yrs[[2]]

  augmented <- join_energy_consumption_activity(full_join(consumption, activity,
    by = c("geo", "time")))
  indexed <- add_index_delta(augmented, fy)
  lmdi <- apply_LMDI(indexed, fy) %>% filter(time >= fy, time <= ly)

  write_ref(augmented, code, "augmented")
  write_ref(lmdi, code, "lmdi")
  cat(sprintf("%s residential: base=%s last=%s  lmdi_rows=%d\n", code, fy, ly, nrow(lmdi)))
}
cat("Residential reference generation complete.\n")
