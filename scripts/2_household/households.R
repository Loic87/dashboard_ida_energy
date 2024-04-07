library(fs)
library(tidyverse)
library(tidyr)
library(dplyr)
library(ggplot2)
library(futile.logger)
# ENERGY CONSUMPTION IN RESIDENTIAL SECTOR
source("scripts/0_support/outputs.R")
source("scripts/0_support/year_selection.R")
source("scripts/0_support/mapping_sectors.R")
source("scripts/0_support/mapping_products.R")
source("scripts/0_support/mapping_colors.R")
source("scripts/0_support/manual_corrections.R")
source("scripts/4_all_sectors/shared.R")

# Data preparation
household_final <- function(
    first_year,
    last_year,
    country,
    data_path,
    chart_path) {
  flog.info("Prepare the data for residential energy consumption decomposition (all countries)")
  # Define the list as the whole list
  country_list <- geo_codes

  # DATA PREPARATION

  # Energy consumption (and supply) from the energy balance (nrg_bal_c)
  load(paste0(data_path, "/nrg_bal_c.Rda"))

  # Disaggregated final energy consumption in households (nrg_d_hhq)
  load(paste0(data_path, "/nrg_d_hhq.Rda"))

  # Cooling and heating degree days (nrg_chdd_a)
  load(paste0(data_path, "/nrg_chdd_a.Rda"))

  # Population from the demographic balance (demo_gind)
  load(paste0(data_path, "/demo_gind.Rda"))

  # Average household size from the EU-SILC survey (ilc_lvph01)
  load(paste0(data_path, "/ilc_lvph01.Rda"))

  # Energy consumption by fuel
  HH_energy_breakdown <- prepare_energy_product_breakdown(
    # take economy sectors end uses
    nrg_bal_c %>% filter(nrg_bal == "FC_OTH_HH_E"),
    first_year = first_year,
    last_year = last_year,
    country_list = country_list
  )

  # energy consumption from the energy balance (nrg_bal_c)
  # and disaggregated energy balance (nrg_d_hhq)
  HH_energy_consumption <- prepare_energy_consumption(
    nrg_bal_c,
    nrg_d_hhq,
    first_year = first_year,
    last_year = last_year,
    country_list = country_list
  )

  # Prepare household activity
  HH_activity <- prepare_activity(
    demo_gind,
    ilc_lvph01,
    nrg_chdd_a,
    first_year = first_year,
    last_year = last_year,
    country_list = country_list
  )

  # joining datasets
  HH <- full_join(
    HH_energy_consumption,
    HH_activity,
    by = c("geo", "time")
  )

  HH_augmented <- join_energy_consumption_activity(HH)

  # Effects calculation

  # calculate the indexed and differenced indicators
  HH_full <- add_index_delta(HH_augmented)

  # Calculate the effects using the LMDI formulas
  HH_LMDI <- apply_LMDI(HH_full)

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
    first_year_chart <- household_base_year(country = country_chart, first_year = first_year)
    last_year_chart <- household_last_year(country = country_chart, final_year = last_year)

    flog.info(paste("Prepare the charts and data for", country_name, "(", first_year_chart, "-", last_year_chart, ")"))
    flog.info(paste("Saved in", output_path))

    tryCatch(
      {
        generate_energy_breakdown_charts(
          HH_energy_breakdown,
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
          HH,
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
        generate_household_energy_charts(
          HH_augmented,
          country_name = country_name,
          country_chart = country_chart,
          first_year = first_year,
          last_year = last_year,
          output_path = output_path
        )
      },
      error = function(e) {
        flog.error("Error preparing household energy charts: ", e)
      }
    )
    tryCatch(
      {
        generate_subsectors_charts(
          HH_full,
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
          HH_LMDI,
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
            HH_augmented,
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
            HH_augmented,
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
    nrg_d_hhq,
    first_year,
    last_year,
    country_list) {
  # energy consumption (and supply) from the energy balance (nrg_bal_c)
  energy_HH_aggregated <- nrg_bal_c %>%
    filter(
      geo %in% country_list,
      # from first year
      time >= first_year,
      # to last year
      time <= last_year,
      # take residential end use
      nrg_bal == "FC_OTH_HH_E",
      # work with total energy consumption, in TJ
      siec == "TOTAL",
      unit == "TJ"
    ) %>%
    # keep only relevant columns
    select(-c(nrg_bal, siec, unit)) %>%
    rename(total_bal = values)

  # prepare residential disaggregated data

  # subset the disaggregated energy data from nrg_d_hhq to keep only total energy consumption in TJ, for EU28 countries from 2010.
  energy_HH_disaggregated <- nrg_d_hhq %>%
    filter(
      # take only EU countries
      geo %in% country_list,
      # from first year
      time >= first_year,
      # to last year
      time <= last_year,
      # work with total energy consumption, in TJ
      siec == "TOTAL",
      unit == "TJ"
    ) %>%
    pivot_wider(names_from = nrg_bal, values_from = values) %>%
    # keep only relevant columns
    select(-c(siec, unit)) %>%
    rename(
      total_res = FC_OTH_HH_E,
      space_heating = FC_OTH_HH_E_SH,
      space_cooling = FC_OTH_HH_E_SC,
      water_heating = FC_OTH_HH_E_WH,
      cooking = FC_OTH_HH_E_CK,
      light_appliances = FC_OTH_HH_E_LE,
      other = FC_OTH_HH_E_OE
    )

  # Prepare data
  energy_HH_aggregated$total_bal <-
    replace(
      energy_HH_aggregated$total_bal,
      which(energy_HH_aggregated$total_bal <= 0),
      NA
    )
  energy_HH_disaggregated$total_res <-
    replace(
      energy_HH_disaggregated$total_res,
      which(energy_HH_disaggregated$total_res <= 0),
      NA
    )
  energy_HH_disaggregated$cooking <-
    replace(
      energy_HH_disaggregated$cooking,
      which(energy_HH_disaggregated$cooking <= 0),
      NA
    )

  energy_HH_disaggregated$light_appliances <-
    replace(
      energy_HH_disaggregated$light_appliances,
      which(energy_HH_disaggregated$light_appliances <= 0),
      NA
    )
  energy_HH_disaggregated$other <-
    replace(
      energy_HH_disaggregated$other,
      which(energy_HH_disaggregated$other <= 0),
      NA
    )
  energy_HH_disaggregated$space_cooling <-
    replace(
      energy_HH_disaggregated$space_cooling,
      which(energy_HH_disaggregated$space_cooling <= 0),
      NA
    )
  energy_HH_disaggregated$space_heating <-
    replace(
      energy_HH_disaggregated$space_heating,
      which(energy_HH_disaggregated$space_heating <= 0),
      NA
    )
  energy_HH_disaggregated$water_heating <-
    replace(
      energy_HH_disaggregated$water_heating,
      which(energy_HH_disaggregated$water_heating <= 0),
      NA
    )

  # joining datasets

  HH_energy_consumption <- energy_HH_aggregated %>%
    full_join(energy_HH_disaggregated, by = c("geo", "time"))

  HH_energy_consumption
}

prepare_activity <- function(
    demo_gind,
    ilc_lvph01,
    nrg_chdd_a,
    first_year,
    last_year,
    country_list) {
  # prepare population data
  pop <- demo_gind %>%
    filter( # take only EU countries
      geo %in% country_list,
      # from first year
      time >= first_year,
      # to last year
      time <= last_year,
      # take total population
      indic_de == "AVG"
    ) %>%
    # keep only relevant columns
    select(-indic_de) %>%
    rename(total_pop = values)

  # prepare household data
  size_HH <- ilc_lvph01 %>%
    filter( # take only EU countries
      geo %in% country_list,
      # from first year
      time >= first_year,
      # to last year
      time <= last_year
    ) %>%
    # keep only relevant columns
    select(-unit) %>%
    rename(HH_size = values)

  # prepare cooling and heating data
  CHDD <- nrg_chdd_a %>%
    filter( # take only EU countries
      geo %in% country_list
    ) %>%
    pivot_wider(names_from = indic_nrg, values_from = values) %>%
    group_by(geo) %>%
    mutate(
      CDD_norm = CDD / mean(CDD),
      HDD_norm = HDD / mean(HDD)
    ) %>%
    filter( # from first year
      time >= first_year,
      # to last year
      time <= last_year
    ) %>%
    select(-unit)

  pop$total_pop <-
    replace(
      pop$total_pop,
      which(pop$total_pop <= 0),
      NA
    )
  size_HH$HH_size <-
    replace(
      size_HH$HH_size,
      which(size_HH$HH_size <= 0),
      NA
    )
  CHDD$CDD_norm <-
    replace(
      CHDD$CDD_norm,
      which(CHDD$CDD_norm <= 0),
      NA
    )
  CHDD$HDD_norm <-
    replace(
      CHDD$HDD_norm,
      which(CHDD$HDD_norm <= 0),
      NA
    )

  HH_activity <- pop %>%
    full_join(size_HH, by = c("geo", "time")) %>%
    full_join(CHDD, by = c("geo", "time"))

  HH_activity
}

join_energy_consumption_activity <- function(df) {
  # indicators calculations

  # Include corrections and additional information
  df %>%
    mutate(
      # Calculate the number of occupied dwellings based on average occupancy and total population
      occupied_dwellings = total_pop / HH_size,
      # Correct heating and cooling energy consumption based on the normalized HDD and CDD
      space_heating_corrected = ifelse(is.na(HDD_norm), space_heating, space_heating / HDD_norm),
      space_cooling_corrected = ifelse(is.na(CDD_norm), space_cooling, space_cooling / CDD_norm)
    ) %>%
    mutate(
      # Correct total energy consumption based on corrected heating and cooling energy consumption
      # total_res_corrected = rowSums(select(
      #   .,
      #   c(
      #     "space_heating_corrected",
      #     "space_cooling_corrected",
      #     "water_heating",
      #     "cooking",
      #     "light_appliances",
      #     "other"
      #   )
      # ), na.rm = TRUE),
      total_res_corrected = rowSums(select(
        .,
        c(
          "total_bal",
          "space_heating_corrected",
          "space_cooling_corrected"
        )
      ), na.rm = TRUE) - rowSums(select(
        .,
        c(
          "space_heating",
          "space_cooling",
        )
      ), na.rm = TRUE),
      # where the detailed end use is not available, use the total from the energy balance  (which is not temperature corrected)
      # total_res = ifelse(is.na(total_res), total_bal, total_res),
      total_res = total_bal,
      total_res_corrected = ifelse(
        is.na(total_res_corrected) |
          (total_res_corrected == 0),
        total_bal,
        total_res_corrected
      ),
      # the reciprocal of the occupancy will be used as structural indicator
      dwelling_per_cap = 1 / HH_size,
      # The ratio of energy consumption to corrected energy consumption will be used to determine the weather effect
      temperature_correction = ifelse(
        total_res_corrected == 0,
        total_res,
        total_res / total_res_corrected
      ),
      # the corrected energy consumption per dwelling will be used as intensity indicator
      energy_per_dwelling = total_res_corrected / occupied_dwellings
    ) %>%
    # reshape to long (group all the calculated indicators under Measure)
    pivot_longer(
      cols = -c(geo, time),
      names_to = "measure",
      values_to = "value"
    ) %>%
    arrange(time) %>%
    mutate(time = as.integer(time))
}

add_index_delta <- function(df) {
  df %>%
    group_by(geo, measure) %>%
    mutate(
      value_indexed = value / value[time == household_base_year(country = .data[["geo"]], first_year = first_year)],
      value_delta = value - value[time == household_base_year(country = .data[["geo"]], first_year = first_year)],
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
        value_delta_total_res == 0,
        value_total_res,
        value_delta_total_res / log(value_indexed_total_res)
      ),
      # Apply natural logarithm to the indexed values
      population_log = log(value_indexed_total_pop),
      household_size_log = log(value_indexed_dwelling_per_cap),
      weather_log = log(value_indexed_temperature_correction),
      household_consumption_log = log(value_indexed_energy_per_dwelling)
    ) %>%
    # Keep only the relevant columns
    select(
      geo,
      time,
      weighting_factor,
      value_total_res,
      value_delta_total_res,
      population_log,
      household_size_log,
      weather_log,
      household_consumption_log
    ) %>%
    mutate(
      # the baseline and end figures of the energy consumption will be used for charts, they are calculated for the total sector
      value_energy_consumption_end = value_total_res
    ) %>%
    # the baseline figures need to be expanded across all sub sectors, and across all years
    rowwise() %>%
    mutate(base_year = household_base_year(country = .data[["geo"]], first_year = first_year)) %>%
    ungroup() %>%
    group_by(geo) %>%
    # the trick used here was to use the fill method to replace all NA with the figures existing (going both up and down, within each country)
    mutate(value_energy_consumption_baseline = value_total_res[time == base_year]) %>%
    ungroup() %>%
    # multiply the weighting factor * log(indexed)
    mutate(
      population = weighting_factor * population_log,
      household_size = weighting_factor * household_size_log,
      weather = weighting_factor * weather_log,
      household_consumption = weighting_factor * household_consumption_log,
    ) %>%
    # remove unnecessary columns
    select(
      -c(
        value_total_res,
        weighting_factor,
        population_log,
        household_size_log,
        weather_log,
        household_consumption_log
      )
    ) %>%
    # for checking purposes, recalculate the total energy consumption calculated as the sum of the effects
    mutate(energy_consumption_delta_calc = rowSums(select(
      .,
      c(
        "population",
        "household_size",
        "weather",
        "household_consumption"
      )
    ), na.rm = TRUE))
}

generate_subsectors_charts <- function(
    HH_full,
    country_chart,
    country_name,
    first_year_chart,
    last_year_chart,
    output_path) {
  # chart indexed variation of residential

  residential_data <- HH_full %>%
    filter(
      geo == country_chart,
      time <= last_year_chart,
      measure %in% c(
        "total_pop",
        "dwelling_per_cap",
        "energy_per_dwelling",
        "temperature_correction",
        "total_res"
      )
    ) %>%
    select(-c(value_delta, value)) %>%
    pivot_wider(names_from = measure, values_from = value_indexed) %>%
    rename(
      "Population" = "total_pop",
      "Dwelling per capita" = "dwelling_per_cap",
      "Energy per dwelling" = "energy_per_dwelling",
      "Weather" = "temperature_correction",
      "Energy consumption" = "total_res"
    )

  year <- as.Date(as.character(residential_data$time), "%Y")

  p <- residential_data %>%
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
    scale_color_manual(values = HouseholdColorsIndex) +
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
    ylab(paste("Index (", household_base_year(country = country_chart, first_year = first_year), "=1)")) +
    ggtitle(paste("Indexed indicators for", country_name, "'s total residential energy consumption, \ntemperature correction, population, dwelling per capita and energy per dwelling variation, \nall years related to", as.character(first_year)))

  print_chart(p,
    filename = paste0(country_chart, "_Figure22B.jpg"),
    output_path = output_path,
    width = 2400,
    height = 2400,
    res = 300
  )

  # chart indexed variation by end use

  subsector_data <- HH_full %>%
    filter(
      geo == country_chart,
      measure %in% c(
        "space_heating",
        "space_cooling",
        "water_heating",
        "cooking",
        "light_appliances",
        "other"
      ),
      time >= first_year_chart,
      time <= last_year_chart,
    ) %>%
    select(-c(value_delta, value)) %>%
    pivot_wider(names_from = measure, values_from = value_indexed) %>%
    rename(
      "Space heating" = "space_heating",
      "Space cooling" = "space_cooling",
      "Water heating" = "water_heating",
      "Cooking" = "cooking",
      "Lighting and appliances" = "light_appliances",
      "Other" = "other"
    ) %>%
    pivot_longer(
      cols = -c(geo, time),
      names_to = "end_use",
      values_to = "value"
    ) %>%
    mutate(end_use = factor(end_use, levels = end_use_list))

  year <- as.Date(as.character(subsector_data$time), "%Y")

  p <- subsector_data %>%
    cbind(year) %>%
    select(-time) %>%
    ggplot() +
    geom_blank(aes(x = year)) +
    geom_line(aes(x = year, y = value, color = end_use), size = 1) +
    scale_color_manual(values = EndUseColors, limits = force) +
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
    ylab(paste("Index (", household_base_year(country = country_chart, first_year = first_year), "=1)")) +
    ggtitle(paste("Indexed variation for", country_name, "'s energy consumption by end use \nin the residential sectors, all years related to", as.character(first_year)))

  print_chart(p,
    filename = paste0(country_chart, "_Figure22C.jpg"),
    output_path = output_path,
    width = 2400,
    height = 2400,
    res = 300
  )
}

generate_household_energy_charts <- function(
    HH_augmented,
    country_chart,
    country_name,
    first_year,
    last_year,
    output_path) {
  # Table used to provide figures in the text of the report
  table_HH_augmented <- HH_augmented %>%
    filter(geo == country_chart) %>%
    mutate(value = round(value, 1)) %>%
    pivot_wider(names_from = measure, values_from = value)

  save_data(
    table_HH_augmented,
    filename = "Part4_enduse.csv",
    output_path = output_path
  )

  # heating degree day chart
  HDD_CDD_HH <- HH_augmented %>%
    filter(
      measure %in% c("HDD", "CDD", "HH_size"),
      geo == country_chart
    )

  save_data(
    HDD_CDD_HH,
    filename = "Part4_HDD_CDD_HH.csv",
    output_path = output_path
  )

  # Plot the heating degree day comparison as line chart
  HDD_CDD_size_comparison_data <- HH_augmented %>%
    filter(measure %in% c("HDD", "CDD", "HH_size")) %>%
    pivot_wider(names_from = geo, values_from = value)

  min_EU <-
    apply(select_if(HDD_CDD_size_comparison_data[, -1], is.numeric),
      1,
      min,
      na.rm = TRUE
    )
  max_EU <-
    apply(select_if(HDD_CDD_size_comparison_data[, -1], is.numeric),
      1,
      max,
      na.rm = TRUE
    )
  avg_EU <-
    apply(select_if(HDD_CDD_size_comparison_data[, -1], is.numeric),
      1,
      mean,
      na.rm = TRUE
    )
  year <-
    as.Date(as.character(HDD_CDD_size_comparison_data$time), "%Y")

  HDD_CDD_size_comparison_data <- HDD_CDD_size_comparison_data %>%
    cbind(min_EU) %>%
    cbind(max_EU) %>%
    cbind(avg_EU) %>%
    cbind(year) %>%
    select(c(year, measure, !!country_chart, min_EU, max_EU, avg_EU)) %>%
    mutate(year = lubridate::year(year))

  # Plot the HDD CDD size comparison as line charts
  p <- HDD_CDD_size_comparison_data %>%
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
      axis.title.y = element_blank(),
      legend.title = element_blank(),
      legend.position = "bottom",
      text = element_text(size = 15)
    ) +
    # ylab("Degree day") +
    scale_x_continuous(breaks = c(first_year, round((
      first_year + last_year
    ) / 2), last_year)) +
    # scale_y_continuous(labels = scales::number) +
    expand_limits(y = 0) +
    scale_y_continuous(breaks = scales::breaks_extended(Q = c(0, 1, 2, 3))) +
    ggtitle(paste("Heating and cooling degree day in", country_name, " compared to other European countries")) +
    facet_wrap(
      ~measure,
      scales = "free",
      ncol = 3,
      labeller = labeller(
        measure = c(
          "CDD" = "Cooling Degree Days",
          "HDD" = "Heating Degree Days",
          "HH_size" = "Household size"
        )
      )
    )

  print_chart(p,
    filename = paste0(country_chart, "_Figure24.jpg"),
    output_path = output_path,
    width = 2400,
    height = 1600,
    res = 300
  )

  # Household intensities

  # Plot the indicators comparison as line chart
  intensity_comparison_data <-
    HH_augmented %>%
    filter(
      measure %in% c(
        "energy_per_dwelling",
        "space_cooling_corrected",
        "space_heating_corrected",
        "water_heating",
        "cooking",
        "light_appliances",
        "other",
        "occupied_dwellings"
      )
    ) %>%
    pivot_wider(
      names_from = measure,
      values_from = value
    ) %>%
    mutate(
      cooling_per_dwelling = space_cooling_corrected / occupied_dwellings,
      heating_per_dwelling = space_heating_corrected / occupied_dwellings,
      water_heating_per_dwelling = water_heating / occupied_dwellings,
      cooking_per_dwelling = cooking / occupied_dwellings,
      light_appliances_per_dwelling = light_appliances / occupied_dwellings,
      other_per_dwelling = other / occupied_dwellings,
    ) %>%
    rename(
      "Total" = "energy_per_dwelling",
      "Space heating" = "heating_per_dwelling",
      "Space cooling" = "cooling_per_dwelling",
      "Water heating" = "water_heating_per_dwelling",
      "Cooking" = "cooking_per_dwelling",
      "Lighting and appliances" = "light_appliances_per_dwelling",
      "Other" = "other_per_dwelling"
    ) %>%
    pivot_longer(
      cols = -c(geo, time),
      names_to = "measure",
      values_to = "value"
    ) %>%
    # from TJ to MJ
    mutate(value = value * 100000) %>%
    pivot_wider(names_from = geo, values_from = value)

  min_EU <-
    apply(select_if(intensity_comparison_data[, -1], is.numeric),
      1,
      min,
      na.rm = TRUE
    )
  max_EU <-
    apply(select_if(intensity_comparison_data[, -1], is.numeric),
      1,
      max,
      na.rm = TRUE
    )
  avg_EU <-
    apply(select_if(intensity_comparison_data[, -1], is.numeric),
      1,
      mean,
      na.rm = TRUE
    )
  year <-
    as.Date(as.character(intensity_comparison_data$time), "%Y")

  intensity_comparison_data <- intensity_comparison_data %>%
    cbind(min_EU) %>%
    cbind(max_EU) %>%
    cbind(avg_EU) %>%
    cbind(year) %>%
    select(c(year, measure, !!country_chart, avg_EU, min_EU, max_EU)) %>%
    mutate(year = lubridate::year(year))

  # Plot the intensity comparison as line chart
  p <- intensity_comparison_data %>%
    filter(measure %in% measure_list) %>%
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
      legend.position = c(0.9, 0.1),
      text = element_text(size = 15)
    ) +
    ylab("Residential intensity by end use (MJ / household)") +
    scale_x_continuous(breaks = c(first_year, round((
      first_year + last_year
    ) / 2), last_year)) +
    scale_y_continuous(labels = scales::number) +
    ggtitle(paste("Intensity by end use size in", country_name, " compared to other European countries")) +
    facet_wrap(~ factor(measure, levels = (measure_list)),
      scales = "free",
      ncol = 3
    )

  print_chart(p,
    filename = paste0(country_chart, "_Figure25.jpg"),
    output_path = output_path,
    width = 2400,
    height = 3200,
    res = 300
  )
}

generate_energy_breakdown_charts <- function(
    HH_energy_breakdown,
    country_chart,
    country_name,
    first_year,
    last_year,
    output_path) {
  # Breakdown of energy consumption by fuel

  HH_energy_breakdown_filtered <- HH_energy_breakdown %>%
    filter(geo == country_chart, !energy_consumption == 0)

  # Table used to provide figures in the text of the report
  table_HH_energy_breakdown_filtered <-
    HH_energy_breakdown_filtered %>%
    mutate(
      energy_consumption = round(energy_consumption, 2),
      share_energy_consumption = round(share_energy_consumption, 3)
    )

  save_data(
    table_HH_energy_breakdown_filtered,
    filename = "Part4_fuel.csv",
    output_path = output_path
  )

  year <-
    as.Date(
      as.character(HH_energy_breakdown_filtered$time),
      "%Y"
    )

  p <- HH_energy_breakdown_filtered %>%
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
    scale_x_continuous(breaks = c(first_year, round((
      first_year + last_year
    ) / 2), last_year)) +
    scale_y_continuous(labels = scales::number) +
    ylab(paste("Energy consumption (PJ)")) +
    ggtitle(paste("Economy energy consumption by fuel for", country_name))

  print_chart(p,
    filename = paste0(country_chart, "_Figure20.jpg"),
    output_path = output_path,
    width = 2400,
    height = 2400,
    res = 300
  )

  p <- HH_energy_breakdown_filtered %>%
    filter(time %in% c(first_year, last_year)) %>%
    ggplot(aes(
      x = factor(time),
      y = share_energy_consumption,
      fill = product
    )) +
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
    geom_text(
      aes(label = paste0(
        round(share_energy_consumption * 100, 0), "%"
      )),
      position = position_stack(vjust = 0.5)
    ) +
    ylab(paste("Share in final energy consumption")) +
    ggtitle(paste("Economy energy consumption by fuel for", country_name))

  print_chart(p,
    filename = paste0(country_chart, "_Figure20B.jpg"),
    output_path = output_path,
    width = 2400,
    height = 2400,
    res = 300
  )
}

generate_country_charts <- function(
    HH,
    first_year,
    last_year,
    country_name,
    country_chart,
    output_path) {
  # energy consumption by end-use

  HH_filtered_data <- HH %>%
    filter(geo == country_chart) %>%
    rename(
      "Space heating" = "space_heating",
      "Space cooling" = "space_cooling",
      "Water heating" = "water_heating",
      "Cooking" = "cooking",
      "Lighting and appliances" = "light_appliances",
      "Other" = "other"
    ) %>%
    pivot_longer(
      cols = -c(geo, time),
      names_to = "end_use",
      values_to = "value"
    ) %>%
    filter(
      end_use %in% c(
        "Space heating",
        "Space cooling",
        "Water heating",
        "Cooking",
        "Lighting and appliances",
        "Other"
      ), !value == 0
    ) %>%
    mutate(end_use = factor(end_use, levels = end_use_list))

  HH_totals <- HH %>%
    filter(geo == country_chart) %>%
    rename("Total reported" = "total_bal") %>%
    pivot_longer(
      cols = -c(geo, time),
      names_to = "end_use",
      values_to = "value"
    ) %>%
    filter(end_use == "Total reported")

  year <- as.Date(as.character(HH_filtered_data$time), "%Y")
  year2 <- as.Date(as.character(HH_totals$time), "%Y")

  p <- HH_filtered_data %>%
    cbind(year) %>%
    select(-time) %>%
    mutate(year = lubridate::year(year)) %>%
    ggplot(aes(x = year, y = value / 1000)) +
    geom_bar(aes(fill = end_use), stat = "identity") +
    scale_fill_manual(values = EndUseColors, limits = force) +
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
    scale_x_continuous(breaks = c(first_year, round((
      first_year + last_year
    ) / 2), last_year)) +
    ylab(paste("Energy consumption (PJ)")) +
    geom_point(
      data = HH_totals %>%
        mutate(year2 = lubridate::year(year2)),
      aes(
        x = year2,
        y = value / 1000,
        color = end_use
      ),
      size = 3
    ) +
    scale_color_manual(name = "", values = "black") +
    ggtitle(paste("Residential energy consumption by end-use"))

  print_chart(p,
    filename = paste0(country_chart, "_Figure21.jpg"),
    output_path = output_path,
    width = 2400,
    height = 2400,
    res = 300
  )

  # 2 years share

  p <- HH_filtered_data %>%
    filter(
      time %in% c(first_year, last_year),
      geo == country_chart
    ) %>%
    mutate(end_use = factor(end_use, levels = end_use_list)) %>%
    group_by(geo, time) %>%
    mutate(value = value / sum(value, na.rm = TRUE)) %>%
    ungroup() %>%
    ggplot(aes(
      x = factor(time),
      y = value,
      fill = end_use
    )) +
    geom_bar(position = "fill", stat = "identity") +
    scale_fill_manual(values = EndUseColors, limits = force) +
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
    geom_text(aes(label = paste0(round(value * 100, 0), "%")),
      position = position_stack(vjust = 0.5)
    ) +
    ylab(paste("Share of energy consumption")) +
    ggtitle(paste("Economy energy consumption by subsector for", country_name))

  print_chart(p,
    filename = paste0(country_chart, "_Figure21B.jpg"),
    output_path = output_path,
    width = 2400,
    height = 2400,
    res = 300
  )
}

generate_final_effects_charts <- function(
    HH_LMDI,
    country_chart,
    country_name,
    first_year,
    last_year,
    first_year_chart,
    last_year_chart,
    output_path) {
  # prepare data for the simple effect chart
  effects_df <- HH_LMDI %>%
    filter(
      geo == country_chart,
      time <= last_year_chart,
      time >= first_year_chart
    ) %>%
    rename(
      "Population" = "population",
      "Dwelling per capita" = "household_size",
      "Energy per dwelling" = "household_consumption",
      "Weather" = "weather"
    ) %>%
    pivot_longer(
      cols = -c(geo, time),
      names_to = "Effect",
      values_to = "value"
    ) %>%
    filter(
      Effect %in% c(
        "Population",
        "Dwelling per capita",
        "Energy per dwelling",
        "Weather"
      )
    )

  results_df <- HH_LMDI %>%
    filter(
      geo == country_chart,
      time <= last_year_chart,
      time >= first_year_chart
    ) %>%
    pivot_longer(
      cols = -c(geo, time),
      names_to = "measure",
      values_to = "value"
    ) %>%
    filter(measure == "value_delta_total_res")

  # Plot the simple effect as bar chart
  p <- ggplot(
    data = effects_df,
    aes(
      x = factor(time),
      y = value / 1000
    )
  ) +
    geom_bar(aes(fill = Effect),
      stat = "identity"
    ) +
    scale_fill_manual(values = HouseholdColorsEffect) +
    geom_point(
      data = results_df,
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
    ggtitle(paste("Decompostion analysis of", country_name, "'s residential energy consumption variation, \n  all years related to", as.character(first_year)))

  print_chart(p,
    filename = paste0(country_chart, "_Figure22D.jpg"),
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
    "Population",
    "Dwelling/cap.",
    "Energy/dwell.",
    "Weather",
    Result_label
  )

  # prepare data for the waterfall chart (see plotly waterfall for explanations)
  household_Waterfall_data <- HH_LMDI %>%
    filter(
      geo == country_chart,
      time == last_year_chart
    ) %>%
    rename(
      "Population" = "population",
      "Dwelling/cap." = "household_size",
      "Energy/dwell." = "household_consumption",
      "Weather" = "weather",
      !!Base_label := "value_energy_consumption_baseline",
      !!Result_label := "value_energy_consumption_end"
    ) %>%
    select(
      !!Base_label,
      "Population",
      "Dwelling/cap.",
      "Energy/dwell.",
      "Weather",
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
    household_Waterfall_data,
    filename = "Part4_waterfall.csv",
    output_path = output_path
  )

  p <- household_Waterfall_data %>%
    filter(x != Result_label) %>%
    select(x, y) %>%
    mutate(y = round(y / 1000, 2)) %>%
    waterfall(calc_total = TRUE, rect_text_size = 1.5) +
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
    filename = paste0(country_chart, "_Figure22.jpg"),
    output_path = output_path,
    width = 2400,
    height = 1600,
    res = 300
  )

  # Intensity effect chart

  # prepare data for the intensity effect chart
  HH_intensity_effect_data <-
    HH_LMDI %>%
    filter(
      geo == country_chart,
      time >= first_year,
      time <= last_year
    ) %>%
    group_by(geo, time) %>%
    mutate(
      "Without intensity effect" = sum(
        c(
          value_energy_consumption_baseline,
          population,
          household_size
        ),
        na.rm = TRUE
      ),
      "Temperature-corrected energy consumption" = sum(
        c(
          value_energy_consumption_baseline,
          population,
          household_size,
          household_consumption
        ),
        na.rm = TRUE
      )
    ) %>%
    ungroup() %>%
    select(
      -c(
        household_consumption,
        value_energy_consumption_end,
        weather,
        population,
        household_size,
        value_delta_total_res,
        base_year,
        value_energy_consumption_baseline,
        energy_consumption_delta_calc
      )
    ) %>%
    pivot_longer(
      cols = -c(geo, time),
      names_to = "measure",
      values_to = "value"
    ) %>%
    mutate(measure = factor(
      measure,
      levels = c(
        "Without intensity effect",
        "Temperature-corrected energy consumption"
      )
    )) %>%
    arrange(measure)

  save_data(
    HH_intensity_effect_data,
    filename = "Part4_intensity_effect.csv",
    output_path = output_path
  )

  # Plot the intensity effect as area chart
  p <- HH_intensity_effect_data %>%
    ggplot() +
    geom_bar(
      data = (
        HH_intensity_effect_data %>%
          filter(measure == "Temperature-corrected energy consumption")
      ),
      aes(
        y = value / 1000,
        x = time,
        fill = measure
      ),
      stat = "identity",
      alpha = 0.5
    ) +
    scale_fill_manual(values = c("Corrected energy consumption" = "blue4")) +
    geom_point(
      data = (
        HH_intensity_effect_data %>%
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
    ggtitle(paste("Corrected energy consumption in households vs theoretical \n(without energy improvements) for", country_name))

  print_chart(p,
    filename = paste0(country_chart, "_Figure23.jpg"),
    output_path = output_path,
    width = 2400,
    height = 2400,
    res = 300
  )
}

generate_coverage_chart <- function(
    HH_augmented,
    last_year_chart,
    output_path) {
  # Data coverage chart
  missing_data <- HH_augmented %>%
    filter(
      measure %in% c(
        "space_heating",
        "space_cooling",
        "water_heating",
        "cooking",
        "light_appliances",
        "other"
      ),
      geo != "EU27",
    ) %>%
    mutate(
      missing =
        case_when(
          !is.na(value) ~ 0,
          TRUE ~ 1
        )
    ) %>%
    select(-measure) %>%
    group_by(geo, time) %>%
    summarize(
      missing = sum(missing),
      .groups = "drop_last"
    )

  save_data(
    missing_data,
    filename = "Part4_missing_data.csv",
    output_path = output_path
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
      limits = c(0, 6),
      breaks = scales::pretty_breaks(n = 6)(0:6)
    ) +
    theme(
      axis.title.x = element_blank(),
      axis.title.y = element_blank()
    ) +
    labs(fill = "Missing end-uses") +
    ggtitle("Completeness of coverage (end use energy consumption) \nfor European countries across years")

  print_chart(p,
    filename = "EU27_Figure25C.jpg",
    output_path = output_path,
    width = 2400,
    height = 3200,
    res = 300
  )
}

generate_eu_comparison_chart <- function(
    HH_augmented,
    first_year_chart,
    last_year_chart,
    output_path) {
  # EU intensity comparison chart
  household_intensity_EU_comparison_data <-
    HH_augmented %>%
    filter(
      measure == "energy_per_dwelling",
      time %in% c(first_year_chart, last_year_chart),
      geo != "EU27"
    ) %>%
    arrange(value) %>%
    merge(eu_countries, by.x = "geo", by.y = "code") %>%
    select(-c("geo", "label"))

  save_data(
    household_intensity_EU_comparison_data,
    filename = "Part4_EU27.csv",
    output_path = output_path
  )

  # Rank the countries by intensity on last year
  country_ranked <- household_intensity_EU_comparison_data %>%
    filter(time == last_year_chart) %>%
    arrange(value) %>%
    pull(name)

  p <- household_intensity_EU_comparison_data %>%
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
    ylab("Energy intensity (TJ / dwelling)") +
    ggtitle(paste("Energy comsumption per household in European countries"))

  print_chart(p,
    filename = "EU27_Figure25B.jpg",
    output_path = output_path,
    width = 2400,
    height = 1600,
    res = 300
  )
}