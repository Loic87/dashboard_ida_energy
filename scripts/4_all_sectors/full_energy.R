library(fs)
library(tidyverse)
library(tidyr)
library(dplyr)
library(ggplot2)
library(futile.logger)
# FULL ENERGY CONSUMPTION
source("scripts/0_support/outputs.R")
source("scripts/0_support/year_selection.R")
source("scripts/0_support/mapping_sectors.R")
source("scripts/0_support/mapping_colors.R")

# Data preparation
full_energy_final <- function(first_year,
                              last_year,
                              country,
                              data_path,
                              chart_path) {

  flog.info("Prepare the data for full energy context (all countries)")

  # Define the list as the whole list
  country_list <- geo_codes

  # DATA PREPARATION

  # Energy consumption (and supply) from the energy balance (nrg_bal_c)
  load(paste0(data_path, "/nrg_bal_c.Rda"))

  # Energy consumption by fuel
  full_energy_context <- prepare_full_energy_context(
    first_year = first_year,
    last_year = last_year,
    nrg_bal_c = nrg_bal_c,
    country_list = country_list
  )

  # Energy consumption by fuel
  full_energy_breakdown <- prepare_full_energy_breakdown(
    first_year = first_year,
    last_year = last_year,
    nrg_bal_c = nrg_bal_c,
    country_list = country_list
  )

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
    first_year_chart <- full_sector_base_year(country = country_chart, first_year = first_year)
    last_year_chart <- full_sector_last_year(country = country_chart, final_year = last_year)

    flog.info(paste("Prepare the charts and data for", country_name, "(", first_year_chart, "-", last_year_chart, ")"))
    flog.info(paste("Saved in", output_path))
    # Energy consumption by subsector

    tryCatch(
      {
        generate_table_full_energy_context(
          full_energy_context,
          country_chart = country_chart,
          country_name = country_name,
          first_year = first_year,
          last_year = last_year,
          output_path = output_path
        )
      },
      error = function(e) {
        flog.error("Error preparing full energy context charts: ", e)
      }
    )

    tryCatch(
      {
        generate_full_energy_breakdown_charts(
          full_energy_breakdown,
          country_chart = country_chart,
          country_name = country_name,
          first_year = first_year,
          last_year = last_year,
          output_path = output_path
        )
      },
      error = function(e) {
        flog.error("Error preparing full energy breakdown charts: ", e)
      }
    )
  }
}

prepare_full_energy_context <- function(first_year,
                                        last_year,
                                        nrg_bal_c,
                                        country_list) {
  nrg_bal_c %>%
    filter(
      geo %in% country_list,
      # from first year
      time >= first_year,
      # to last year
      time <= last_year,
      # take industry end uses
      nrg_bal %in% NRG_SUPPLY,
      # work with total energy consumption, in TJ
      siec == "TOTAL",
      unit == "TJ"
    ) %>%
    select(c("geo", "time", "nrg_bal", "values"))
}

prepare_full_energy_breakdown <- function(first_year,
                                          last_year,
                                          nrg_bal_c,
                                          country_list) {
  nrg_bal_c %>%
    filter(
      geo %in% country_list,
      # from first year
      time >= first_year,
      # to last year
      time <= last_year,
      # take industry end uses
      nrg_bal %in% NRG_FULL_SECTORS,
      # work with total energy consumption, in TJ
      siec == "TOTAL",
      unit == "TJ"
    ) %>%
    select(c("geo", "time", "nrg_bal", "values")) %>%
    # reshape to wide
    pivot_wider(names_from = nrg_bal, values_from = values) %>%
    # aggregate
    mutate(
      # Agriculture, forestry and fishing
      A = rowSums(select(., all_of(NRG_AGRI)), na.rm = TRUE),
      # Manufacturing
      C = rowSums(select(., all_of(NRG_MAN)), na.rm = TRUE),
      # Other industries
      B_D_E = rowSums(select(., all_of(NRG_OTH)), na.rm = TRUE),
      # Other industries
      TRA = rowSums(select(., all_of(NRG_TRA)), na.rm = TRUE)
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
        NRG_NI_E,
        FC_TRA_RAIL_E,
        FC_TRA_ROAD_E,
        FC_TRA_DNAVI_E
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
      "Comm. and pub. services" = "FC_OTH_CP_E",
      "Residential" = "FC_OTH_HH_E",
      "Transport" = "TRA"
    ) %>%
    # reshape to long
    pivot_longer(
      cols = -c(geo, time),
      names_to = "sector",
      values_to = "energy_consumption"
    ) %>%
    # For each country and each year
    group_by(geo, time) %>%
    mutate(
      # Calculate the total energy consumption and value added of the overall industry sector, as the sum of all subsectors selected
      total_energy_consumption = sum(energy_consumption, na.rm = TRUE)
    ) %>%
    ungroup() %>%
    # For each country, each year and each subsector
    mutate(
      # Calculate the share of the subsector in the overall energy consumption and in the overall value added of the industry sector
      share_energy_consumption = energy_consumption / total_energy_consumption
    )
  # Remove the total columns, not required any longer
  # select(-c(total_energy_consumption))
}

generate_table_full_energy_context <- function(
    full_energy_context,
    country_chart,
    country_name,
    first_year,
    last_year,
    output_path) {
  # Table used to provide figures in the text of the report
  table_full_energy_context <- full_energy_context %>%
    filter(geo == country_chart) %>%
    mutate(values = round(values, 1))

  save_data(
    table_full_energy_context,
    filename="Context.csv",
    output_path=output_path
  )
}

generate_full_energy_breakdown_charts <- function(
    full_energy_breakdown,
    country_chart,
    country_name,
    first_year,
    last_year,
    output_path) {
  # Table used to provide figures in the text of the report
  table_full_energy_breakdown <- full_energy_breakdown %>%
    filter(
      geo == country_chart
    ) %>%
    mutate(
      energy_consumption = round(energy_consumption, 1),
      share_energy_consumption = round(share_energy_consumption, 3)
    )

  save_data(
    table_full_energy_breakdown,
    filename="Intro.csv",
    output_path=output_path
  )

  full_energy_breakdown_filtered_data <-
    full_energy_breakdown %>%
    filter(
      geo == country_chart,
      sector != "Total",
      time <= last_year
    ) %>%
    mutate(sector = factor(sector, levels = IDA_FULL_SECTORS))

  year <- as.Date(as.character(full_energy_breakdown_filtered_data$time), "%Y")

  p <- full_energy_breakdown_filtered_data %>%
    cbind(year) %>%
    select(-time) %>%
    mutate(year = lubridate::year(year)) %>%
    ggplot(aes(x = year, y = energy_consumption / 1000)) +
    geom_bar(aes(fill = sector), stat = "identity") +
    scale_fill_manual(values = AllSectorsColors) +
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
    ggtitle(paste("Industry energy consumption by subsector for", country_name))

  print_chart(p,
    filename = paste0(country_chart, "_Figure01.jpg"),
    output_path = output_path,
    width = 2400,
    height = 2400,
    res = 300
  )

  p <- full_energy_breakdown_filtered_data %>%
    filter(
      time %in% c(first_year, last_year),
      geo == country_chart,
      sector != "Total"
    ) %>%
    mutate(sector = factor(sector, levels = IDA_FULL_SECTORS)) %>%
    ggplot(aes(x = factor(time), y = share_energy_consumption, fill = sector)) +
    geom_bar(position = "fill", stat = "identity") +
    scale_fill_manual(values = AllSectorsColors) +
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
    ggtitle(paste("Industry energy consumption by subsector for", country_name))

  print_chart(p,
    filename = paste0(country_chart, "_Figure01B.jpg"),
    output_path = output_path,
    width = 2400,
    height = 2400,
    res = 300
  )
}