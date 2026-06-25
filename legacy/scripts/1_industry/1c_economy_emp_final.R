# TODO: ECONOMY-WIDE EMPLOYMENT-BASED DECOMPOSITION - BATCH CHART GENERATION
# This script generates static charts saved to output/ folder for batch processing.
# Currently NOT integrated into the dashboard (which uses interactive plotly charts).
# To integrate:
#   1. Add UI tab in scripts/ui.R
#   2. Add reactive logic in scripts/server.R
#   3. Adapt chart generation functions to return plotly objects instead of saving files

library(fs)
library(tidyverse)
library(tidyr)
library(dplyr)
library(ggplot2)
library(futile.logger)
# FINAL ENERGY CONSUMPTION IN ECONOMY
source("scripts/0_support/outputs.R")
source("scripts/0_support/year_selection.R")
source("scripts/0_support/mapping_sectors.R")
source("scripts/0_support/mapping_products.R")
source("scripts/0_support/mapping_colors.R")
source("scripts/0_support/manual_corrections.R")
source("scripts/4_all_sectors/shared.R")

# Data preparation
economy_emp_final <- function(
    first_year,
    last_year,
    country,
    data_path,
    chart_path) {
  flog.info("Prepare the data for final energy consumption in economy (employment based) decomposition (all countries)")
  # Define the list as the whole list
  country_list <- geo_codes

  # DATA PREPARATION

  # Energy consumption (and supply) from the energy balance (nrg_bal_c)
  load(paste0(data_path, "/nrg_bal_c.Rda"))

  # Employment data from the national account (nama_10_a10_e)
  load(paste0(data_path, "/nama_10_a10_e.Rda"))

  # Energy consumption by fuel
  economy_energy_breakdown <- prepare_energy_product_breakdown(
    # take economy sectors end uses
    nrg_bal_c %>% filter(nrg_bal %in% NRG_ECO_SECTORS),
    first_year = first_year,
    last_year = last_year,
    country_list = country_list
  )

  # energy consumption (and supply) from the energy balance (nrg_bal_c)
  economy_energy_final <- prepare_energy_consumption(
    nrg_bal_c,
    first_year = first_year,
    last_year = last_year,
    country_list = country_list
  )

  # prepare employment data
  economy_employment <- prepare_activity(
    nama_10_a10_e,
    first_year = first_year,
    last_year = last_year,
    country_list = country_list
  )

  # joining datasets
  economy_emp_final_complete <- full_join(
    economy_energy_final,
    economy_employment,
    by = c("geo", "time", "sector")
  ) %>%
    join_energy_consumption_activity()


  # filter out sectors with incomplete data
  economy_emp_final_filtered <- filter_energy_consumption_activity(
    economy_emp_final_complete,
    first_year = first_year,
    last_year = last_year
  )

  # Effects calculation

  # calculate the required indicators for the 3 effects
  economy_emp_final_augmented <- add_share_sectors(economy_emp_final_filtered)
  economy_emp_final_total <- add_total_sectors(economy_emp_final_augmented)

  # Calculate the indexed and differenced indicators
  economy_emp_final_full <- economy_emp_final_augmented %>%
    rbind(economy_emp_final_total) %>%
    add_index_delta()

  # Calculate the effects using the LMDI formulas
  economy_emp_final_LMDI <- apply_LMDI(economy_emp_final_full)

  ### CHARTS ###

  if (country == "all") {
    countries <- geo_codes
  } else {
    countries <- country
  }

  for (country_chart in countries) {
    # Long name for the country
    country_name <- ifelse(country_chart == "EU27", "EU27", filter(eu27, code == country_chart)$name)
    # Output charts
    output_path <- paste0(chart_path, "/", country_chart, "/")
    # first and last year shown in charts
    first_year_chart <- economy_emp_base_year(country = country_chart, first_year = first_year)
    last_year_chart <- economy_emp_last_year(country = country_chart, final_year = last_year)

    flog.info(paste("Prepare the charts and data for", country_name, "(", first_year_chart, "-", last_year_chart, ")"))
    flog.info(paste("Saved in", output_path))

    tryCatch(
      {
        generate_energy_breakdown_charts(
          economy_energy_breakdown,
          country_chart = country_chart,
          country_name = country_name,
          first_year = first_year,
          last_year = last_year,
          output_path = output_path
        )
      },
      error = function(e) {
        flog.error("Error preparing energy beakdown charts: ", e)
      }
    )

    tryCatch(
      {
        generate_country_charts(
          economy_emp_final_complete,
          first_year = first_year,
          last_year = last_year,
          country_name = country_name,
          country_chart = country_chart,
          output_path = output_path
        )
      },
      error = function(e) {
        flog.error("Error preparing country charts: ", e)
      }
    )

    tryCatch(
      {
        generate_subsectors_charts(
          economy_emp_final_full,
          country_name = country_name,
          country_chart = country_chart,
          first_year_chart = first_year_chart,
          last_year_chart = last_year_chart,
          output_path = output_path
        )
      },
      error = function(e) {
        flog.error("Error preparing subsector charts: ", e)
      }
    )

    tryCatch(
      {
        # Simple effect decomposition
        generate_final_effects_charts(
          economy_emp_final_LMDI,
          country_chart = country_chart,
          country_name = country_name,
          first_year = first_year,
          last_year = last_year,
          first_year_chart = first_year_chart,
          last_year_chart = last_year_chart,
          output_path = output_path
        )
      },
      error = function(e) {
        flog.error("Error preparing final effects charts: ", e)
      }
    )

    if (country_chart == "EU27") {
      output_path <- paste0(chart_path, "/EU27/")
      flog.info(paste("Additional charts and data for EU27 (", first_year_chart, "-", last_year_chart, ")"))

      tryCatch(
        {
          generate_coverage_chart(
            economy_emp_final_complete,
            last_year_chart = last_year_chart,
            output_path = output_path
          )
        },
        error = function(e) {
          flog.error("Error preparing coverage charts: ", e)
        }
      )
      tryCatch(
        {
          generate_eu_comparison_chart(
            economy_emp_final_full,
            first_year_chart = first_year_chart,
            last_year_chart = last_year_chart,
            output_path = output_path
          )
        },
        error = function(e) {
          flog.error("Error preparing eu comparison charts: ", e)
        }
      )
    }
  }
}

prepare_energy_consumption <- function(
    nrg_bal_c,
    first_year,
    last_year,
    country_list) {
  economy_energy_final <- nrg_bal_c %>%
    filter(
      geo %in% country_list,
      # from first year
      time >= first_year,
      # to last year
      time <= last_year,
      # take economy sectors
      nrg_bal %in% NRG_ECO_SECTORS,
      # work with total energy consumption, in TJ
      siec == "TOTAL",
      unit == "TJ"
    ) %>%
    select(c("geo", "time", "nrg_bal", "values")) %>%
    # reshape to wide
    pivot_wider(
      names_from = nrg_bal,
      values_from = values
    ) %>%
    # aggregate
    mutate(
      # Agriculture, forestry and fishing
      A = rowSums(select(., all_of(NRG_AGRI)), na.rm = TRUE),
      # Manufacturing
      C = rowSums(select(., all_of(NRG_MAN)), na.rm = TRUE),
      # Other industries
      B_D_E = rowSums(select(., all_of(NRG_OTH)), na.rm = TRUE)
    ) %>%
    # keep only relevant columns
    select(
      -c(
        FC_OTH_AF_E,
        FC_OTH_FISH_E,
        FC_IND_MQ_E,
        NRG_CM_E,
        NRG_OIL_NG_E,
        FC_IND_FBT_E,
        FC_IND_TL_E,
        FC_IND_WP_E,
        FC_IND_PPP_E,
        NRG_PR_E,
        FC_IND_CPC_E,
        FC_IND_NMM_E,
        FC_IND_IS_E,
        NRG_CO_E,
        NRG_BF_E,
        FC_IND_NFM_E,
        FC_IND_MAC_E,
        FC_IND_TE_E,
        NRG_PF_E,
        NRG_BKBPB_E,
        NRG_CL_E,
        NRG_GTL_E,
        NRG_CPP_E,
        NRG_NSP_E,
        FC_IND_NSP_E,
        # TI_EHG_E,
        NRG_EHG_E,
        NRG_GW_E,
        NRG_LNG_E,
        NRG_BIOG_E,
        NRG_NI_E
      )
    ) %>%
    # rename to explicit names
    rename(
      # "Agriculture, forestry and fishing" = "A",
      "Agricult., forest. and fish." = "A",
      "Construction" = "FC_IND_CON_E",
      "Manufacturing" = "C",
      "Other industries" = "B_D_E",
      # "Commercial and public services" = "FC_OTH_CP_E"
      "Comm. and pub. services" = "FC_OTH_CP_E"
    ) %>%
    # reshape to long
    pivot_longer(
      cols = -c(geo, time),
      names_to = "sector",
      values_to = "energy_consumption"
    )

  # Remove negative and 0 Energy consumption
  economy_energy_final$energy_consumption <-
    replace(
      economy_energy_final$energy_consumption,
      which(economy_energy_final$energy_consumption <= 0),
      NA
    )

  economy_energy_final
}

prepare_activity <- function(
    nama_10_a10_e,
    first_year,
    last_year,
    country_list) {
  economy_employment <- nama_10_a10_e %>%
    filter(
      # take only EU countries
      geo %in% country_list,
      # from first year
      time >= first_year,
      # to last year
      time <= last_year,
      # take economy sectors
      nace_r2 %in% EMP_ECO_SECTORS,
      # work with Total employment domestic concept, in Thousand persons
      na_item == "EMP_DC",
      unit == "THS_PER"
    ) %>%
    # reshape to wide
    pivot_wider(names_from = nace_r2, values_from = values) %>%
    rename(
      "B_E" = "B-E",
      "G_I" = "G-I",
      "O_Q" = "O-Q",
      "R_U" = "R-U"
    ) %>%
    # aggregate
    mutate( # Other industry
      B_D_E = B_E - C,
      # Commercial and Public Services
      G_U = rowSums(select(., c("G_I", "J", "K", "L", "M_N", "O_Q", "R_U")),
        na.rm = TRUE
      )
    ) %>%
    # keep only relevant columns
    select(-c(na_item, unit, B_E, G_I, J, K, L, M_N, O_Q, R_U)) %>%
    # rename to explicit names
    rename(
      # "Agriculture, forestry and fishing" = "A",
      "Agricult., forest. and fish." = "A",
      "Manufacturing" = "C",
      "Construction" = "F",
      "Other industries" = "B_D_E",
      # "Commercial and public services" = "G_U"
      "Comm. and pub. services" = "G_U"
    ) %>%
    # reshape to long
    pivot_longer(
      cols = -c(geo, time),
      names_to = "sector",
      values_to = "employment"
    )

  # Remove negative and 0 employment
  economy_employment$employment <-
    replace(
      economy_employment$employment,
      which(economy_employment$employment <= 0),
      NA
    )

  economy_employment
}

join_energy_consumption_activity <- function(df) {
  df %>%
    # correction for missing employment / Energy
    mutate(
      employment = case_when(
        (employment == 0 & energy_consumption > 0) ~ NA_real_,
        TRUE ~ employment
      ),
      energy_consumption = case_when(
        (energy_consumption == 0 & employment > 0) ~ NA_real_,
        TRUE ~ energy_consumption
      ),
      # intensity calculated here for the charts, will be recalculated later once the totals are included
      intensity = case_when(
        (employment == 0 & energy_consumption > 0) ~ NA_real_,
        (employment == 0 & energy_consumption == 0) ~ 0,
        TRUE ~ energy_consumption / employment
      )
    ) %>%
    # For each country and each year
    group_by(geo, time) %>%
    mutate(
      # Calculate the total energy consumption and value added of the overall industry sector, as the sum of all subsectors
      total_energy_consumption = sum(energy_consumption, na.rm = TRUE),
      total_employment = sum(employment, na.rm = TRUE)
    ) %>%
    # For each country, each year and each subsector
    ungroup() %>%
    mutate(
      # Calculate the share of the subsector in the overall energy consumption and in the overall value added of the industry sector
      share_energy_consumption = energy_consumption / total_energy_consumption,
      share_employment = employment / total_employment
    )
}

filter_energy_consumption_activity <- function(
    df,
    first_year,
    last_year) {
  unique_countries <- unique(df$geo)
  unique_sectors <- unique(df$sector)

  for (country in unique_countries) {
    first_year_shown <- economy_emp_base_year(country = country, first_year = first_year)
    last_year_shown <- economy_emp_last_year(country = country, final_year = last_year)
    for (sector in unique_sectors) {
      subset_df <- df[
        df$geo == country &
          df$sector == sector &
          df$time <= last_year_shown &
          df$time >= first_year_shown,
      ]
      if (any(is.na(subset_df$employment) | subset_df$employment == 0)) {
        missing_years <- subset_df$time[is.na(subset_df$employment) | subset_df$employment == 0]
        df <- df[!(df$geo == country & df$sector == sector), ]
        flog.warn(
          paste(
            "Country:", country, ", Sector:", sector,
            "- removed (missing employment in years:",
            paste(missing_years, collapse = ", "), ")"
          )
        )
      } else if (any((is.na(subset_df$energy_consumption) | subset_df$energy_consumption == 0) & (!is.na(subset_df$employment) & subset_df$employment != 0))) {
        missing_years <- subset_df$time[is.na(subset_df$energy_consumption) | subset_df$energy_consumption == 0]
        df <- df[!(df$geo == country & df$sector == sector), ]
        message(
          paste(
            "Country:", country, ", Sector:", sector,
            "- removed (missing energy consumption in years:",
            paste(missing_years, collapse = ", "), ")"
          )
        )
      }
    }
  }
  return(df)
}

add_share_sectors <- function(df) {
  df %>%
    # for each country and each year
    group_by(geo, time) %>%
    mutate(
      # calculate the total energy consumption and value added of the overall economy, as the sum of all sectors selected
      total_energy_consumption = sum(energy_consumption, na.rm = TRUE),
      total_employment = sum(employment, na.rm = TRUE)
    ) %>%
    ungroup() %>%
    # for each country, each year and each subsector
    mutate(
      # calculate the share of each sector in the overall energy consumption and in the overall employment of the economy
      share_energy_consumption = energy_consumption / total_energy_consumption,
      share_employment = employment / total_employment
    ) %>%
    # remove the total columns, not required any longer
    select(-c(
      total_energy_consumption,
      total_employment,
      intensity
    )) %>%
    ungroup()
}

add_total_sectors <- function(df) {
  df %>%
    group_by(geo, time) %>%
    summarize(
      employment = sum(employment, na.rm = TRUE),
      energy_consumption = sum(energy_consumption, na.rm = TRUE),
      # the sum of shares should be one, calculated here for checking
      share_employment = sum(share_employment, na.rm = TRUE),
      share_energy_consumption = sum(share_energy_consumption, na.rm = TRUE),
      .groups = "drop_last"
    ) %>%
    ungroup() %>%
    mutate(sector = "Total")
}

add_index_delta <- function(df) {
  df %>%
    # calculate intensity again, to include the total intensity
    mutate(intensity = case_when(
      (employment == 0 & energy_consumption > 0) ~ NA_real_,
      (employment == 0 & energy_consumption == 0) ~ 0,
      TRUE ~ energy_consumption / employment
    )) %>%
    pivot_longer(
      cols = -c(geo, time, sector),
      names_to = "measure",
      values_to = "value"
    ) %>%
    group_by(geo, sector, measure) %>%
    mutate(
      value_indexed = case_when(
        value[time == economy_emp_base_year(country = .data[["geo"]], first_year = first_year)] == 0 ~ 0,
        is.na(value[time == economy_emp_base_year(country = .data[["geo"]], first_year = first_year)]) ~ NA_real_,
        TRUE ~ value / value[time == economy_emp_base_year(country = .data[["geo"]], first_year = first_year)]
      ),
      value_delta = value - value[time == economy_emp_base_year(country = .data[["geo"]], first_year = first_year)],
      time = as.integer(time)
    ) %>%
    ungroup()
}

apply_LMDI <- function(df) {
  df %>%
    # Reshape to wide (moving all measures calculated in Value, index and delta, all in separate columns)
    pivot_wider(
      names_from = measure,
      values_from = c(value, value_indexed, value_delta)
    ) %>%
    # Calculate the effects
    mutate(
      # The weighting factor links the effect calculated on the indexed variation to the total energy consumption variation
      weighting_factor = ifelse(
        value_delta_energy_consumption == 0,
        value_energy_consumption,
        value_delta_energy_consumption / log(value_indexed_energy_consumption)
      ),
      # Apply natural logarithm to the indexed values for each sub sectors
      activity_log = ifelse(value_indexed_employment == 0, 0, log(value_indexed_employment)),
      structure_log = ifelse(value_indexed_share_employment == 0, 0, log(value_indexed_share_employment)),
      intensity_log = ifelse(value_indexed_intensity == 0, 0, log(value_indexed_intensity))
    ) %>%
    # Keep only the relevant columns
    select(
      geo,
      time,
      sector,
      weighting_factor,
      value_energy_consumption,
      value_delta_energy_consumption,
      activity_log,
      structure_log,
      intensity_log
    ) %>%
    # The baseline figures need to be expanded across all sub sectors, and across all years
    rowwise() %>%
    mutate(base_year = economy_emp_base_year(country = .data[["geo"]], first_year = first_year)) %>%
    ungroup() %>%
    group_by(geo) %>%
    mutate(
      value_energy_consumption_total_baseline = value_energy_consumption[sector == "Total" &
        time == base_year]
    ) %>%
    ungroup() %>%
    # Similarly, the figures calculated for the total sector and the end figures need to be expanded across all subsectors
    group_by(geo, time) %>%
    mutate(
      activity_log_total = activity_log[sector == "Total"],
      value_delta_energy_consumption_total = value_delta_energy_consumption[sector == "Total"],
      value_energy_consumption_total_end = value_energy_consumption[sector == "Total"]
    ) %>%
    ungroup() %>%
    # Now the total sector is not required any longer
    filter(sector != "Total") %>%
    # Multiply the weighting factor * log(indexed subsectors), or weighting factor * log(indexed total sector)
    mutate(
      ACT = weighting_factor * activity_log_total,
      STR = weighting_factor * structure_log,
      INT = weighting_factor * intensity_log
    ) %>%
    # Remove unnecessary columns
    select(
      -c(
        weighting_factor,
        activity_log,
        activity_log_total,
        structure_log,
        intensity_log
      )
    ) %>%
    # Now the figures calculated at subsector level need to be aggregated
    group_by(geo, time) %>%
    # The aggregation is performed differently:
    summarize(
      # Either by summing all subsectors
      activity_effect = sum(ACT), # na.rm = TRUE),
      structural_effect = sum(STR), # na.rm = TRUE),
      intensity_effect = sum(INT), # na.rm = TRUE),
      # By keeping the mean figure when only one exist across all subsectors
      energy_consumption_var_obs = mean(value_delta_energy_consumption_total),
      value_energy_consumption_total_baseline = mean(value_energy_consumption_total_baseline),
      value_energy_consumption_total_end = mean(value_energy_consumption_total_end),
      .groups = "drop_last"
    ) %>%
    ungroup() %>%
    # For checking purposes, recalculate the total energy consumption calculated as the sum of the effects
    mutate(
      energy_consumption_var_calc =
        rowSums(
          select(., c(
            "activity_effect",
            "structural_effect",
            "intensity_effect"
          )),
          # na.rm = TRUE
        )
    )
}

generate_country_charts <- function(
    economy_emp_final_complete,
    first_year,
    last_year,
    country_name,
    country_chart,
    output_path) {
  # Country data
  economy_emp_final_country_data <-
    economy_emp_final_complete %>%
    filter(
      geo == country_chart,
      time <= last_year
    ) %>%
    mutate(sector = factor(sector, levels = IDA_ECO_SECTORS))

  # Table used to provide figures in the text of the report
  table_economy_emp_final_country_data <- economy_emp_final_country_data %>%
    mutate(
      employment = round(employment, 2),
      energy_consumption = round(energy_consumption, 2),
      share_employment = round(share_employment, 2),
      share_energy_consumption = round(share_energy_consumption, 2)
    )

  save_data(
    table_economy_emp_final_country_data,
    filename="Part3_sector.csv",
    output_path=output_path
  )

  # Energy consumption by subsector

  year <- as.Date(as.character(economy_emp_final_country_data$time), "%Y")

  p <- economy_emp_final_country_data %>%
    cbind(year) %>%
    select(-time) %>%
    mutate(year = lubridate::year(year)) %>%
    ggplot(aes(x = year, y = energy_consumption / 1000)) +
    geom_bar(aes(fill = sector), stat = "identity") +
    scale_fill_manual(values = EconomySectorsColors, limits = force) +
    theme_classic() +
    theme(
      axis.title.x = element_blank(),
      legend.title = element_blank(),
      legend.position = "bottom",
      legend.box = "horizontal",
      text = element_text(size = 15)
    ) +
    guides(fill = guide_legend(ncol = 3)) +
    scale_x_continuous(breaks = c(first_year, round((first_year + last_year) / 2), last_year)) +
    scale_y_continuous(labels = scales::number) +
    ylab(paste("Energy consumption (PJ)")) +
    ggtitle(paste("Total energy consumption by economy subsector for", country_name))

  print_chart(p,
    filename = paste0(country_chart, "_Figure15.jpg"),
    output_path = output_path,
    width = 2400,
    height = 2400,
    res = 300
  )

  # 2 years share

  p <- economy_emp_final_country_data %>%
    filter(time %in% c(first_year, last_year)) %>%
    mutate(sector = factor(sector, levels = IDA_ECO_SECTORS)) %>%
    ggplot(aes(x = factor(time), y = share_energy_consumption, fill = sector)) +
    geom_bar(position = "fill", stat = "identity") +
    scale_fill_manual(values = EconomySectorsColors, limits = force) +
    theme_classic() +
    theme(
      axis.title.x = element_blank(),
      legend.title = element_blank(),
      legend.position = "bottom",
      legend.box = "horizontal",
      text = element_text(size = 15)
    ) +
    guides(fill = guide_legend(ncol = 3)) +
    scale_y_continuous(labels = scales::percent) +
    geom_text(aes(label = paste0(round(share_energy_consumption * 100, 0), "%")),
      position = position_stack(vjust = 0.5)
    ) +
    ylab(paste("Share of energy consumption")) +
    ggtitle(paste("Economy energy consumption by subsector for", country_name))

  print_chart(p,
    filename = paste0(country_chart, "_Figure15B.jpg"),
    output_path = output_path,
    width = 2400,
    height = 2400,
    res = 300
  )

  # employment by subsector

  p <- economy_emp_final_country_data %>%
    cbind(year) %>%
    select(-time) %>%
    mutate(year = lubridate::year(year)) %>%
    ggplot(aes(x = year, y = employment / 1000)) +
    geom_bar(aes(fill = sector), stat = "identity") +
    scale_fill_manual(values = EconomySectorsColors, limits = force) +
    theme_classic() +
    theme(
      axis.title.x = element_blank(),
      legend.title = element_blank(),
      legend.position = "bottom",
      legend.box = "horizontal",
      text = element_text(size = 15)
    ) +
    guides(fill = guide_legend(ncol = 3)) +
    scale_x_continuous(breaks = c(first_year, round((first_year + last_year) / 2), last_year)) +
    scale_y_continuous(labels = scales::number) +
    ylab(paste("Employment (millions)")) +
    ggtitle(paste("Employment by subsector for", country_name))

  print_chart(p,
    filename = paste0(country_chart, "_Figure16.jpg"),
    output_path = output_path,
    width = 2400,
    height = 2400,
    res = 300
  )

  # 2 years share

  p <- economy_emp_final_country_data %>%
    filter(time %in% c(first_year, last_year)) %>%
    ggplot(aes(x = factor(time), y = share_employment, fill = sector)) +
    geom_bar(position = "fill", stat = "identity") +
    scale_fill_manual(values = EconomySectorsColors, limits = force) +
    theme_classic() +
    theme(
      axis.title.x = element_blank(),
      legend.title = element_blank(),
      legend.position = "bottom",
      legend.box = "horizontal",
      text = element_text(size = 15)
    ) +
    guides(fill = guide_legend(ncol = 3)) +
    scale_y_continuous(labels = scales::percent) +
    geom_text(aes(label = paste0(round(share_employment * 100, 0), "%")),
      position = position_stack(vjust = 0.5)
    ) +
    ylab(paste("Share of employment")) +
    ggtitle(paste("Economy energy consumption by subsector for", country_name))

  print_chart(p,
    filename = paste0(country_chart, "_Figure16B.jpg"),
    output_path = output_path,
    width = 2400,
    height = 2400,
    res = 300
  )
  # Sectoral intensity comparison chart

  # prepare data for the intensity comparison chart
  economy_emp_final_intensity_comparison_sector <-
    economy_emp_final_complete %>%
    mutate(sector = factor(sector, levels = IDA_ECO_SECTORS)) %>%
    filter(time <= last_year) %>%
    select(-c(
      employment, energy_consumption,
      total_energy_consumption, total_employment,
      share_energy_consumption, share_employment
    )) %>%
    pivot_wider(names_from = geo, values_from = intensity)

  min_EU <-
    apply(select_if(economy_emp_final_intensity_comparison_sector[, -1], is.numeric),
      1,
      min,
      na.rm = TRUE
    )
  max_EU <-
    apply(select_if(economy_emp_final_intensity_comparison_sector[, -1], is.numeric),
      1,
      max,
      na.rm = TRUE
    )
  avg_EU <-
    apply(select_if(economy_emp_final_intensity_comparison_sector[, -1], is.numeric),
      1,
      mean,
      na.rm = TRUE
    )
  year <-
    as.Date(
      as.character(economy_emp_final_intensity_comparison_sector$time),
      "%Y"
    )

  economy_emp_final_intensity_comparison_sector <-
    economy_emp_final_intensity_comparison_sector %>%
    cbind(min_EU) %>%
    cbind(max_EU) %>%
    cbind(avg_EU) %>%
    cbind(year) %>%
    select(c(year, sector, !!country_chart, min_EU, max_EU)) %>%
    mutate(
      year = lubridate::year(year),
      sector = factor(sector, levels = IDA_ECO_SECTORS)
    )

  # Plot the intensity comparison as line chart
  p <- economy_emp_final_intensity_comparison_sector %>%
    ggplot(aes(x = year)) +
    # geom_blank(aes(x = year)) +
    geom_ribbon(aes(
      x = year,
      ymax = max_EU,
      ymin = min_EU,
      fill = "grey"
    )) +
    geom_line(aes(x = year, y = avg_EU, color = "black"), size = 1) +
    geom_line(aes(x = year, y = .data[[!!country_chart]], color = "red"), size = 1) +
    scale_fill_identity(guide = "legend", labels = c("Europe range")) +
    scale_colour_manual(
      values = c("black" = "black", "red" = "red"),
      labels = c("Europe average", country_name)
    ) +
    theme_classic() +
    theme(
      axis.title.x = element_blank(),
      legend.title = element_blank(),
      legend.position = c(0.8, 0.2),
      text = element_text(size = 15)
    ) +
    ylab("Energy consumption per employee (MJ / employee)") +
    scale_x_continuous(breaks = c(first_year, round((first_year + last_year) / 2), last_year)) +
    # scale_y_continuous(labels = scales::number) +
    expand_limits(y = 0) +
    scale_y_continuous(breaks = scales::breaks_extended(Q = c(0, 1, 2, 3))) +
    ggtitle(paste("Energy consumption per employee in", country_name, "'s subsectors compared to \nother European countries")) +
    facet_wrap(~sector, scales = "free", ncol = 3)

  print_chart(p,
    filename = paste0(country_chart, "_Figure19.jpg"),
    output_path = output_path,
    width = 2400,
    height = 1600,
    res = 300
  )
}
generate_subsectors_charts <- function(
    economy_emp_final_full,
    country_chart,
    country_name,
    first_year_chart,
    last_year_chart,
    output_path) {
  # full data (after filtering)
  economy_emp_final_subsector <-
    economy_emp_final_full %>%
    filter(
      geo == country_chart,
      time >= first_year_chart,
      time <= last_year_chart
    )

  # indexed variation by subsector

  year <-
    as.Date(as.character(economy_emp_final_subsector$time), "%Y")

  p <- economy_emp_final_subsector %>%
    cbind(year) %>%
    filter(
      sector != "Total",
      measure == "intensity"
    ) %>%
    mutate(sector = factor(sector, levels = IDA_ECO_SECTORS)) %>%
    select(-c("time", "value", "value_delta")) %>%
    ggplot() +
    geom_blank(aes(x = year)) +
    geom_line(aes(x = year, y = value_indexed, color = sector), size = 1) +
    scale_color_manual(values = EconomySectorsColors, limits = force) +
    theme_classic() +
    theme(
      axis.title.x = element_blank(),
      legend.title = element_blank(),
      legend.position = "bottom",
      legend.box = "horizontal",
      text = element_text(size = 15)
    ) +
    guides(fill = guide_legend(ncol = 3)) +
    scale_y_continuous(labels = scales::number) +
    ylab(paste("Index (", economy_emp_base_year(country = country_chart, first_year = first_year), "=1)")) +
    ggtitle(paste("Indexed variation for", country_name, "'s energy consumption per employee in sectors of the economy, \nall years related to", as.character(first_year)))

  print_chart(p,
    filename = paste0(country_chart, "_Figure17C.jpg"),
    output_path = output_path,
    width = 2400,
    height = 2400,
    res = 300
  )

  # chart indexed variation of total economy

  economy_emp_final_country_indexed <-
    economy_emp_final_subsector %>%
    filter(sector == "Total") %>%
    select(-c(value, value_delta)) %>%
    pivot_wider(
      names_from = measure,
      values_from = value_indexed
    ) %>%
    select(c(
      geo,
      time,
      intensity,
      energy_consumption,
      employment
    )) %>%
    rename(
      "Energy consumption per employee" = "intensity",
      "Energy consumption" = "energy_consumption",
      "Employment" = "employment"
    )

  year <- as.Date(as.character(economy_emp_final_country_indexed$time), "%Y")

  p <- economy_emp_final_country_indexed %>%
    cbind(year) %>%
    select(-time) %>%
    pivot_longer(
      cols = -c(geo, year),
      names_to = "measure",
      values_to = "value"
    ) %>%
    ggplot() +
    geom_blank(aes(x = year)) +
    geom_line(aes(x = year, y = value, color = measure), size = 1) +
    scale_color_manual(values = EconomyEmploymentColorsIndex) +
    theme_classic() +
    theme(
      axis.title.x = element_blank(),
      legend.title = element_blank(),
      legend.position = "bottom",
      legend.box = "horizontal",
      text = element_text(size = 15)
    ) +
    guides(fill = guide_legend(ncol = 3)) +
    scale_y_continuous(labels = scales::number) +
    ylab(paste("Index (", economy_emp_base_year(country = country_chart, first_year = first_year), "=1)")) +
    ggtitle(paste("Indexed indicators for", country_name, "'s total energy consumption, \nproduction index and energy consumption per employee, \nall years related to", as.character(first_year)))

  print_chart(p,
    filename = paste0(country_chart, "_Figure17B.jpg"),
    output_path = output_path,
    width = 2400,
    height = 2400,
    res = 300
  )

  # Total intensity comparison chart

  # prepare data for the intensity comparison chart
  economy_emp_final_intensity_comparison <-
    economy_emp_final_full %>%
    filter(
      measure == "intensity",
      time <= last_year,
      sector == "Total"
    ) %>%
    select(-c(value_indexed, value_delta)) %>%
    pivot_wider(names_from = geo, values_from = value)

  min_EU <-
    apply(
      select_if(
        economy_emp_final_intensity_comparison[, -1],
        is.numeric
      ),
      1,
      min,
      na.rm = TRUE
    )
  max_EU <-
    apply(select_if(economy_emp_final_intensity_comparison[, -1], is.numeric),
      1,
      max,
      na.rm = TRUE
    )
  avg_EU <-
    apply(select_if(economy_emp_final_intensity_comparison[, -1], is.numeric),
      1,
      mean,
      na.rm = TRUE
    )
  year <-
    as.Date(
      as.character(economy_emp_final_intensity_comparison$time),
      "%Y"
    )

  economy_emp_final_intensity_comparison <-
    economy_emp_final_intensity_comparison %>%
    cbind(min_EU) %>%
    cbind(max_EU) %>%
    cbind(avg_EU) %>%
    cbind(year) %>%
    select(c(year, !!country_chart, min_EU, max_EU)) %>%
    mutate(year = lubridate::year(year))

  # Plot the intensity comparison as line chart
  p <- economy_emp_final_intensity_comparison %>%
    ggplot(aes(x = year)) +
    # geom_blank(aes(x = year)) +
    geom_ribbon(aes(
      x = year,
      ymax = max_EU,
      ymin = min_EU,
      fill = "grey"
    )) +
    geom_line(aes(x = year, y = avg_EU, color = "black"), size = 1) +
    geom_line(aes(x = year, y = .data[[!!country_chart]], color = "red"), size = 1) +
    scale_fill_identity(guide = "legend", labels = c("Europe range")) +
    scale_colour_manual(
      values = c("black" = "black", "red" = "red"),
      labels = c("Europe average", country_name)
    ) +
    theme_classic() +
    theme(
      axis.title.x = element_blank(),
      legend.title = element_blank(),
      legend.position = "bottom",
      legend.box = "horizontal",
      text = element_text(size = 15)
    ) +
    guides(fill = guide_legend(ncol = 3)) +
    scale_y_continuous(labels = scales::number) +
    ylab("Energy consumption per employee (TJ / Thousand employee)") +
    scale_x_continuous(breaks = c(first_year, round((first_year + last_year) / 2), last_year)) +
    ggtitle(paste("Energy consumption per employee in", country_name, "'s economy compared to \nother European countries"))

  print_chart(p,
    filename = paste0(country_chart, "_Figure19B.jpg"),
    output_path = output_path,
    width = 2400,
    height = 2400,
    res = 300
  )
}

generate_energy_breakdown_charts <- function(
    economy_energy_breakdown,
    country_chart,
    country_name,
    first_year,
    last_year,
    output_path) {
  # Breakdown of energy consumption by fuel
  economy_energy_breakdown_filtered <- economy_energy_breakdown %>%
    filter(
      geo == country_chart,
      !energy_consumption == 0
    )

  # Table used to provide figures in the text of the report
  table_economy_energy_breakdown_filtered <- economy_energy_breakdown_filtered %>%
    mutate(
      energy_consumption = round(energy_consumption, 2),
      share_energy_consumption = round(share_energy_consumption, 3)
    )

  save_data(
    table_economy_energy_breakdown_filtered,
    filename="Part3_fuel.csv",
    output_path=output_path
  )

  # Final energy consumption by fuel

  year <-
    as.Date(
      as.character(economy_energy_breakdown_filtered$time),
      "%Y"
    )

  p <- economy_energy_breakdown_filtered %>%
    cbind(year) %>%
    select(-time) %>%
    mutate(year = lubridate::year(year)) %>%
    ggplot(aes(x = year, y = energy_consumption / 1000)) +
    geom_bar(aes(fill = product), stat = "identity") +
    scale_fill_manual(values = FinalProductsColors, limits = force) +
    theme_classic() +
    theme(
      axis.title.x = element_blank(),
      legend.title = element_blank(),
      legend.position = "bottom",
      legend.box = "horizontal",
      text = element_text(size = 15)
    ) +
    guides(fill = guide_legend(ncol = 3)) +
    scale_x_continuous(breaks = c(first_year, round((first_year + last_year) / 2), last_year)) +
    scale_y_continuous(labels = scales::number) +
    ylab(paste("Energy consumption (PJ)")) +
    ggtitle(paste("Economy energy consumption by fuel for", country_name))

  print_chart(p,
    filename = paste0(country_chart, "_Figure14.jpg"),
    output_path = output_path,
    width = 2400,
    height = 2400,
    res = 300
  )

  # 2 years

  p <- economy_energy_breakdown_filtered %>%
    filter(time %in% c(first_year, last_year)) %>%
    ggplot(aes(x = factor(time), y = share_energy_consumption, fill = product)) +
    geom_bar(position = "fill", stat = "identity") +
    scale_fill_manual(values = FinalProductsColors, limits = force) +
    theme_classic() +
    theme(
      axis.title.x = element_blank(),
      legend.title = element_blank(),
      legend.position = "bottom",
      legend.box = "horizontal",
      text = element_text(size = 15)
    ) +
    guides(fill = guide_legend(ncol = 3)) +
    scale_y_continuous(labels = scales::percent) +
    geom_text(aes(label = paste0(round(share_energy_consumption * 100, 0), "%")),
      position = position_stack(vjust = 0.5)
    ) +
    ylab(paste("Share in final energy consumption")) +
    ggtitle(paste("Economy energy consumption by fuel for", country_name))

  print_chart(p,
    filename = paste0(country_chart, "_Figure14B.jpg"),
    output_path = output_path,
    width = 2400,
    height = 2400,
    res = 300
  )
}

generate_final_effects_charts <- function(
    economy_emp_final_LMDI,
    country_chart,
    country_name,
    first_year,
    last_year,
    first_year_chart,
    last_year_chart,
    output_path) {
  # prepare data for the simple effect chart
  economy_emp_final_effects <- economy_emp_final_LMDI %>%
    filter(
      geo == country_chart,
      time <= last_year_chart,
      time >= first_year_chart
    ) %>%
    rename(
      "Activity" = "activity_effect",
      "Intensity" = "intensity_effect",
      "Structure" = "structural_effect"
    ) %>%
    pivot_longer(
      cols = -c(geo, time),
      names_to = "Effect",
      values_to = "value"
    ) %>%
    filter(Effect == "Activity" |
      Effect == "Structure" |
      Effect == "Intensity")

  economy_emp_final_results <- economy_emp_final_LMDI %>%
    filter(
      geo == country_chart,
      time <= last_year_chart
    ) %>%
    pivot_longer(
      cols = -c(geo, time),
      names_to = "measure",
      values_to = "value"
    ) %>%
    filter(measure == "energy_consumption_var_obs")

  # Plot the simple effect as bar chart
  p <- ggplot(
    data = economy_emp_final_effects,
    aes(
      x = factor(time),
      y = value / 1000
    )
  ) +
    geom_bar(aes(fill = Effect),
      stat = "identity"
    ) +
    scale_fill_manual(values = EconomyEmploymentColorsEffect) +
    geom_point(
      data = economy_emp_final_results,
      aes(y = value / 1000),
      size = 3
    ) +
    theme_classic() +
    theme(
      axis.title.x = element_blank(),
      text = element_text(size = 15)
    ) +
    scale_y_continuous(labels = scales::number) +
    ylab("Energy consumption variation (PJ)") +
    ggtitle(paste("Decompostion analysis of", country_name, "'s total energy consumption variation, \n  all years related to", as.character(first_year)))

  print_chart(p,
    filename = paste0(country_chart, "_Figure17D.jpg"),
    output_path = output_path,
    width = 2400,
    height = 1600,
    res = 300
  )

  # Waterfall chart

  Base_label <- paste0(as.character(first_year_chart), " level")
  Result_label <- paste0(as.character(last_year_chart), " level")

  # define the levels used in the waterfall chart
  levels_waterfall <- c(
    Base_label,
    "Activity",
    "Structure",
    "Intensity",
    Result_label
  )

  # prepare data for the waterfall chart (see plotly waterfall for explanations)
  economy_emp_final_Waterfall_data <- economy_emp_final_LMDI %>%
    filter(
      geo == country_chart,
      time == last_year_chart
    ) %>%
    rename(
      "Activity" = "activity_effect",
      "Intensity" = "intensity_effect",
      "Structure" = "structural_effect",
      !!Base_label := "value_energy_consumption_total_baseline",
      !!Result_label := "value_energy_consumption_total_end"
    ) %>%
    select(
      !!Base_label,
      "Activity",
      "Structure",
      "Intensity",
      !!Result_label
    ) %>%
    pivot_longer(
      cols = everything(),
      names_to = "x",
      values_to = "y"
    ) %>%
    mutate(
      x = factor(x, level = levels_waterfall),
      text = paste(as.character(round(y, 2)), "TJ", sep = " "),
      measure = case_when(
        (x == !!Result_label) ~ "total",
        TRUE ~ "relative"
      )
    )

  save_data(
    economy_emp_final_Waterfall_data,
    filename="Part3_waterfall.csv",
    output_path=output_path
  )

  p <- economy_emp_final_Waterfall_data %>%
    filter(x != Result_label) %>%
    select(x, y) %>%
    mutate(y = round(y / 1000, 2)) %>%
    waterfall(
      calc_total = TRUE,
      rect_text_size = 1.5
    ) +
    theme_classic() +
    # xlab("Effects") +
    theme(
      axis.title.x = element_blank(),
      text = element_text(size = 15)
    ) +
    scale_y_continuous(labels = scales::number) +
    ylab("Energy consumption level and effect (PJ)") #+
    #scale_x_discrete(labels = levels_waterfall)

  print_chart(p,
    filename = paste0(country_chart, "_Figure17.jpg"),
    output_path = output_path,
    width = 2400,
    height = 1600,
    res = 300
  )

  # Intensity effect chart

  # prepare data for the intensity effect chart
  economy_emp_final_intensity_effect <-
    economy_emp_final_LMDI %>%
    filter(
      geo == country_chart,
      time >= first_year,
      time <= last_year
    ) %>%
    select(
      geo,
      time,
      value_energy_consumption_total_end,
      intensity_effect
    ) %>%
    mutate("Without intensity effect" = value_energy_consumption_total_end - intensity_effect) %>%
    rename("Actual energy consumption" = value_energy_consumption_total_end) %>%
    select(-c(intensity_effect)) %>%
    pivot_longer(
      cols = -c(geo, time),
      names_to = "measure",
      values_to = "value"
    ) %>%
    mutate(measure = factor(
      measure,
      levels = c(
        "Without intensity effect",
        "Actual energy consumption"
      )
    )) %>%
    arrange(measure)

  save_data(
    economy_emp_final_intensity_effect,
    filename="Part3_intensity_effect.csv",
    output_path=output_path
  )

  # Plot the intensity effect as area chart
  p <- economy_emp_final_intensity_effect %>%
    ggplot() +
    geom_bar(
      data = (economy_emp_final_intensity_effect %>%
        filter(measure == "Actual energy consumption")),
      aes(
        y = value / 1000,
        x = time,
        fill = measure
      ),
      stat = "identity",
      alpha = 0.5
    ) +
    scale_fill_manual(values = c("Actual energy consumption" = "blue4")) +
    geom_point(
      data = (economy_emp_final_intensity_effect %>%
        filter(
          measure == "Without intensity effect",
          time >= first_year_chart,
          time <= last_year_chart
        )
      ),
      aes(
        y = value / 1000,
        x = time,
        color = measure
      ),
      size = 3,
      alpha = 0.5
    ) +
    scale_color_manual(values = c("Without intensity effect" = "green4")) +
    theme_classic() +
    theme(
      axis.title.x = element_blank(),
      legend.title = element_blank(),
      legend.position = "bottom",
      legend.box = "horizontal",
      text = element_text(size = 15)
    ) +
    guides(fill = guide_legend(ncol = 3)) +
    scale_x_continuous(breaks = c(first_year, round((first_year + last_year) / 2), last_year)) +
    scale_y_continuous(labels = scales::number) +
    ylab("Energy consumption (PJ)") +
    expand_limits(y = 0) +
    ggtitle(paste("Actual energy consumption in the economy vs theoretical \n(without improvements in energy consumption per employee) for", country_name))

  print_chart(p,
    filename = paste0(country_chart, "_Figure18.jpg"),
    output_path = output_path,
    width = 2400,
    height = 2400,
    res = 300
  )
}

generate_coverage_chart <- function(
    economy_emp_final_complete,
    last_year_chart,
    output_path) {
  # Data coverage chart
  missing_data <- economy_emp_final_complete %>%
    filter(
      sector != "Total",
      geo != "EU27",
      time <= last_year_chart
    ) %>%
    select(c("geo", "time", "sector", "energy_consumption", "employment")) %>%
    replace(is.na(.), 0) %>%
    mutate(
      missing =
        case_when(
          (energy_consumption > 0 & employment > 0) |
            (energy_consumption == 0 & employment == 0) ~ 0,
          TRUE ~ 1
        )
    ) %>%
    select(-c("energy_consumption", "employment")) %>%
    group_by(geo, time) %>%
    summarize(
      missing = sum(missing), 
      .groups = "drop_last"
      ) %>% 
      ungroup()

  save_data(
    missing_data,
    filename="Part3_missing_data.csv",
    output_path=output_path
  )

  p <- missing_data %>%
    ggplot(aes(
      x = reorder(geo, desc(geo)),
      y = factor(time),
      fill = missing
    )) +
    coord_flip() +
    geom_tile() +
    theme_classic() +
    scale_fill_gradient(
      low = "white",
      high = "red",
      limits = c(0, 5),
      breaks = scales::pretty_breaks(n = 5)(0:5)
    ) +
    theme(
      axis.title.x = element_blank(),
      axis.title.y = element_blank()
    ) +
    labs(fill = "Missing sub-sectors") +
    ggtitle("Completeness of coverage (energy and activity data) for European countries across years")

  print_chart(p,
    filename = "EU27_Figure19D.jpg",
    output_path = output_path,
    width = 2400,
    height = 3200,
    res = 300
  )
}

generate_eu_comparison_chart <- function(
    economy_emp_final_full,
    first_year_chart,
    last_year_chart,
    output_path) {
  # Prepare the data
  EU_comparison <- economy_emp_final_full %>%
    filter(
      measure == "intensity",
      time %in% c(first_year_chart, last_year_chart),
      sector == "Total",
      geo != "EU27"
    ) %>%
    select(-c(value_indexed, value_delta)) %>%
    arrange(value) %>%
    merge(eu_countries, by.x = "geo", by.y = "code") %>%
    select(-c("geo", "label"))

  save_data(
    EU_comparison,
    filename="Part3_EU27.csv",
    output_path=output_path
  )

  # Rank the countries by intensity on last year
  country_ranked <- EU_comparison %>%
    filter(time == last_year_chart) %>%
    arrange(value) %>%
    pull(name)

  # EU intensity comparison chart

  p <- EU_comparison %>%
    ggplot(aes(
      x = factor(name, levels = country_ranked),
      y = value,
      color = as.factor(time)
    )) +
    geom_point() +
    geom_line(aes(group = name), colour = "grey") +
    coord_flip() +
    theme_classic() +
    theme(
      axis.title.y = element_blank(),
      legend.title = element_blank(),
      legend.position = c(0.8, 0.2),
      legend.box = "horizontal"
    ) +
    scale_y_continuous(labels = scales::number) +
    ylab("Energy consumption per employee (TJ / Thousand employee)") +
    ggtitle(paste("Energy consumption per employee of economic sectors of European countries"))

  print_chart(p,
    filename = "EU27_Figure19C.jpg",
    output_path = output_path,
    width = 2400,
    height = 1600,
    res = 300
  )
}