#!/usr/bin/env Rscript
# Reference outputs for the ECONOMY-WIDE (employment) sector parity tests.
# Functions reproduced from scripts/1_industry/1c_economy_emp_final.R, with
# economy_emp_base_year() returning first_year (its only behaviour) and the base
# year set to the computed first-year-with-data (matching the dashboard).

suppressMessages({library(arrow); library(dplyr); library(tidyr); library(here)})

root <- here::here()
source(file.path(root, "legacy", "scripts", "0_support", "mapping_sectors.R"))
source(file.path(root, "legacy", "scripts", "0_support", "mapping_years.R"))
out_dir <- file.path(root, "reference")
COUNTRIES <- c("FR", "DE", "IT")
UI_FIRST <- 2000
UI_LAST <- 2021

read_ds <- function(id, code) {
  p <- file.path(root, "data", paste0(id, "_", code, ".feather"))
  if (file.exists(p)) arrow::read_feather(p) else data.frame()
}
write_ref <- function(df, code, stage) {
  if (is.null(df) || nrow(df) == 0) return(invisible())
  df <- df %>% arrange(across(everything()))
  write.csv(df, file.path(out_dir, paste0(code, "_eco_", stage, ".csv")), row.names = FALSE)
}

prepare_energy_consumption <- function(nrg_bal_c, first_year, last_year) {
  d <- nrg_bal_c %>%
    filter(time >= first_year, time <= last_year, nrg_bal %in% NRG_ECO_SECTORS,
           siec == "TOTAL", unit == "TJ") %>%
    select(c("geo", "time", "nrg_bal", "values")) %>%
    pivot_wider(names_from = nrg_bal, values_from = values) %>%
    mutate(A = rowSums(select(., any_of(NRG_AGRI)), na.rm = TRUE),
           C = rowSums(select(., any_of(NRG_MAN)), na.rm = TRUE),
           B_D_E = rowSums(select(., any_of(NRG_OTH)), na.rm = TRUE)) %>%
    select(-any_of(c(NRG_AGRI, NRG_MAN, NRG_OTH))) %>%
    rename("Agricult., forest. and fish." = "A", "Construction" = "FC_IND_CON_E",
           "Manufacturing" = "C", "Other industries" = "B_D_E",
           "Comm. and pub. services" = "FC_OTH_CP_E") %>%
    pivot_longer(cols = -c(geo, time), names_to = "sector", values_to = "energy_consumption")
  d$energy_consumption <- replace(d$energy_consumption, which(d$energy_consumption <= 0), NA)
  d
}

prepare_activity <- function(nama_10_a10_e, first_year, last_year) {
  d <- nama_10_a10_e %>%
    filter(time >= first_year, time <= last_year, nace_r2 %in% EMP_ECO_SECTORS,
           na_item == "EMP_DC", unit == "THS_PER") %>%
    pivot_wider(names_from = nace_r2, values_from = values) %>%
    rename("B_E" = "B-E", "G_I" = "G-I", "O_Q" = "O-Q", "R_U" = "R-U") %>%
    mutate(B_D_E = B_E - C,
           G_U = rowSums(select(., c("G_I", "J", "K", "L", "M_N", "O_Q", "R_U")), na.rm = TRUE)) %>%
    select(-c(na_item, unit, B_E, G_I, J, K, L, M_N, O_Q, R_U)) %>%
    rename("Agricult., forest. and fish." = "A", "Manufacturing" = "C",
           "Construction" = "F", "Other industries" = "B_D_E",
           "Comm. and pub. services" = "G_U") %>%
    pivot_longer(cols = -c(geo, time), names_to = "sector", values_to = "employment")
  d$employment <- replace(d$employment, which(d$employment <= 0), NA)
  d
}

join_energy_consumption_activity <- function(df) {
  df %>%
    mutate(
      employment = case_when((employment == 0 & energy_consumption > 0) ~ NA_real_, TRUE ~ employment),
      energy_consumption = case_when((energy_consumption == 0 & employment > 0) ~ NA_real_, TRUE ~ energy_consumption),
      intensity = case_when((employment == 0 & energy_consumption > 0) ~ NA_real_,
                            (employment == 0 & energy_consumption == 0) ~ 0,
                            TRUE ~ energy_consumption / employment)) %>%
    group_by(geo, time) %>%
    mutate(total_energy_consumption = sum(energy_consumption, na.rm = TRUE),
           total_employment = sum(employment, na.rm = TRUE)) %>% ungroup() %>%
    mutate(share_energy_consumption = energy_consumption / total_energy_consumption,
           share_employment = employment / total_employment)
}

filter_energy_consumption_activity <- function(df, first_year, last_year) {
  for (country in unique(df$geo)) for (sector in unique(df$sector)) {
    sub <- df[df$geo == country & df$sector == sector & df$time <= last_year & df$time >= first_year, ]
    if (any(is.na(sub$employment) | sub$employment == 0)) {
      df <- df[!(df$geo == country & df$sector == sector), ]
    } else if (any((is.na(sub$energy_consumption) | sub$energy_consumption == 0) &
                   (!is.na(sub$employment) & sub$employment != 0))) {
      df <- df[!(df$geo == country & df$sector == sector), ]
    }
  }
  df
}

add_share_sectors <- function(df) {
  df %>% group_by(geo, time) %>%
    mutate(total_energy_consumption = sum(energy_consumption, na.rm = TRUE),
           total_employment = sum(employment, na.rm = TRUE)) %>% ungroup() %>%
    mutate(share_energy_consumption = energy_consumption / total_energy_consumption,
           share_employment = employment / total_employment) %>%
    select(-c(total_energy_consumption, total_employment, intensity)) %>% ungroup()
}

add_total_sectors <- function(df) {
  df %>% group_by(geo, time) %>%
    summarize(employment = sum(employment, na.rm = TRUE),
              energy_consumption = sum(energy_consumption, na.rm = TRUE),
              share_employment = sum(share_employment, na.rm = TRUE),
              share_energy_consumption = sum(share_energy_consumption, na.rm = TRUE),
              .groups = "drop_last") %>% ungroup() %>% mutate(sector = "Total")
}

add_index_delta <- function(df, base_year) {
  df %>%
    mutate(intensity = case_when((employment == 0 & energy_consumption > 0) ~ NA_real_,
                                 (employment == 0 & energy_consumption == 0) ~ 0,
                                 TRUE ~ energy_consumption / employment)) %>%
    pivot_longer(cols = -c(geo, time, sector), names_to = "measure", values_to = "value") %>%
    group_by(geo, sector, measure) %>%
    mutate(value_indexed = case_when(value[time == base_year] == 0 ~ 0,
                                     is.na(value[time == base_year]) ~ NA_real_,
                                     TRUE ~ value / value[time == base_year]),
           value_delta = value - value[time == base_year],
           time = as.integer(time)) %>% ungroup()
}

apply_LMDI <- function(df, base_year) {
  df %>%
    pivot_wider(names_from = measure, values_from = c(value, value_indexed, value_delta)) %>%
    mutate(weighting_factor = ifelse(value_delta_energy_consumption == 0, value_energy_consumption,
             value_delta_energy_consumption / log(value_indexed_energy_consumption)),
           activity_log = ifelse(value_indexed_employment == 0, 0, log(value_indexed_employment)),
           structure_log = ifelse(value_indexed_share_employment == 0, 0, log(value_indexed_share_employment)),
           intensity_log = ifelse(value_indexed_intensity == 0, 0, log(value_indexed_intensity))) %>%
    select(geo, time, sector, weighting_factor, value_energy_consumption,
           value_delta_energy_consumption, activity_log, structure_log, intensity_log) %>%
    mutate(base_year = base_year) %>%
    group_by(geo) %>%
    mutate(value_energy_consumption_total_baseline =
             value_energy_consumption[sector == "Total" & time == base_year]) %>% ungroup() %>%
    group_by(geo, time) %>%
    mutate(activity_log_total = activity_log[sector == "Total"],
           value_delta_energy_consumption_total = value_delta_energy_consumption[sector == "Total"],
           value_energy_consumption_total_end = value_energy_consumption[sector == "Total"]) %>% ungroup() %>%
    filter(sector != "Total") %>%
    mutate(ACT = weighting_factor * activity_log_total,
           STR = weighting_factor * structure_log,
           INT = weighting_factor * intensity_log) %>%
    select(-c(weighting_factor, activity_log, activity_log_total, structure_log, intensity_log)) %>%
    group_by(geo, time) %>%
    summarize(activity_effect = sum(ACT), structural_effect = sum(STR), intensity_effect = sum(INT),
              energy_consumption_var_obs = mean(value_delta_energy_consumption_total),
              value_energy_consumption_total_baseline = mean(value_energy_consumption_total_baseline),
              value_energy_consumption_total_end = mean(value_energy_consumption_total_end),
              .groups = "drop_last") %>% ungroup() %>%
    mutate(energy_consumption_var_calc = rowSums(select(., c("activity_effect",
             "structural_effect", "intensity_effect"))))
}

for (code in COUNTRIES) {
  nrg_bal_c <- read_ds("nrg_bal_c", code)
  nama_10_a10_e <- read_ds("nama_10_a10_e", code)

  energy <- prepare_energy_consumption(nrg_bal_c, UI_FIRST, UI_LAST)
  employment <- prepare_activity(nama_10_a10_e, UI_FIRST, UI_LAST)
  years <- get_years_with_data(employment, "employment", energy, "energy_consumption", UI_FIRST, UI_LAST)
  fy <- years[[1]]; ly <- years[[2]]

  complete <- full_join(energy, employment, by = c("geo", "time", "sector")) %>%
    join_energy_consumption_activity()
  filtered <- filter_energy_consumption_activity(complete, fy, ly)
  augmented <- add_share_sectors(filtered)
  total <- add_total_sectors(augmented)
  full <- rbind(augmented, total) %>% add_index_delta(fy)
  lmdi <- apply_LMDI(full, fy)

  write_ref(energy, code, "energy_by_sector")
  write_ref(employment, code, "employment_by_sector")
  write_ref(full, code, "decomposition")
  write_ref(lmdi, code, "lmdi")
  cat(sprintf("%s economy: base=%s last=%s lmdi_rows=%d\n", code, fy, ly, nrow(lmdi)))
}
cat("Economy reference generation complete.\n")
