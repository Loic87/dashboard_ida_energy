library(futile.logger)
library(tidyr)
library(dplyr)
library(ggplot2)
library(waterfalls)

script_directory <- dirname(rstudioapi::getActiveDocumentContext()$path)
setwd(file.path(script_directory))

source("0_support/mapping_sectors.R")
source("0_support/mapping_products.R")
source("0_support/mapping_colors.R")

prepare_transport_energy_consumption_by_product <- function(
    nrg_bal_c,
    first_year,
    last_year) {
  nrg_bal_c %>%
    filter(
      # from first year
      time >= first_year,
      # to last year
      time <= last_year,
      # work with total energy consumption, in TJ
      siec %in% TRA_PRODS,
      # take industry end uses
      nrg_bal %in% NRG_TRA,
      unit == "TJ"
    ) %>%
    group_by(geo, time, siec) %>%
    summarise(
      values = sum(values, na.rm = TRUE),
      .groups = "drop_last") %>%
    ungroup() %>%
    # reshape to wide
    pivot_wider(
      names_from = siec,
      values_from = values
    ) %>%
    # aggregate
    mutate(
      # Coal, manufactured gases, peat and peat products
      CPS = rowSums(select(., all_of(COAL_PRODS)), na.rm = TRUE),
      # Gasoline
      GASOLINE = rowSums(select(., all_of(GASOLINE_PRODS)), na.rm = TRUE),
      # Biogasoline
      BIOGASOLINE = rowSums(select(., all_of(BIOGASOLINE_PRODS)), na.rm = TRUE),
      # Diesel
      DIESEL = rowSums(select(., all_of(DIESEL_PRODS)), na.rm = TRUE),
      # Biodiesel
      BIODIESEL = rowSums(select(., all_of(BIODIESEL_PRODS)), na.rm = TRUE),
      # LPG
      LPG = rowSums(select(., all_of(LPG_PRODS)), na.rm = TRUE),
      # Kerosene
      KEROSENE = rowSums(select(., all_of(KEROSENE_PRODS)), na.rm = TRUE),
      # Other oil
      OTHER_OIL = rowSums(select(., all_of(OTHER_OIL_PRODS)), na.rm = TRUE),
      # Other bioliquids
      OTHER_BIOLIQUIDS = rowSums(select(., all_of(OTHER_BIOLIQUIDS_PRODS)), na.rm = TRUE),
      # Biogases
      BIOGAS = rowSums(select(., all_of(BIOGAS_PRODS)), na.rm = TRUE),
      # Solid biofuels and wastes
      OTH = rowSums(select(., all_of(OTH_BIOWASTE_PRODS)), na.rm = TRUE)
    ) %>%
    # keep only relevant columns
    select(-all_of(c(CPS, GASOLINE, BIOGASOLINE, DIESEL, BIODIESEL, LPG, KEROSENE, OTHER_OIL, OTHER_BIOLIQUIDS, BIOGAS, OTH))) %>%
    # rename to explicit names
    rename(
      "Coal" = "CPS",
      "Gasoline" = "GASOLINE",
      "Biogasoline" = "BIOGASOLINE",
      "Diesel" = "DIESEL",
      "Biodiesel" = "BIODIESEL",
      "LPG" = "LPG",
      "Kerosene" = "KEROSENE",
      "Other oil products" = "OTHER_OIL",
      "Other liquid biofuels" = "OTHER_BIOLIQUIDS",
      "Gas" = "G3000",
      "Biogas" = "BIOGAS",
      "Solid biofuels and wastes" = "OTH",
      "Electricity" = "E7000"
    ) %>%
    # reshape to long
    pivot_longer(
      cols = -c(geo, time),
      names_to = "product",
      values_to = "energy_consumption"
    ) %>%
    filter(energy_consumption > 0) %>%
    mutate(product = factor(product, level = IDA_TRA_PROD)) %>%
    group_by(geo, time) %>%
    mutate(share_energy_consumption = energy_consumption / sum(energy_consumption)) %>%
    ungroup()
}

prepare_transport_energy_consumption_by_mode <- function(
    nrg_bal_c,
    first_year,
    last_year) {
  nrg_bal_c %>%
    filter(
      # from first year
      time >= first_year,
      # to last year
      time <= last_year,
      # take transport end uses
      nrg_bal %in% NRG_TRA,
      # work with total energy consumption, in TJ
      siec == "TOTAL",
      unit == "TJ"
    ) %>%
    # keep only relevant columns
    select(-c(siec, unit)) %>%
    # convert all figures to vkm
    rename(energy = values) %>%
    # reshape to wide (mode in columns)
    pivot_wider(
      names_from = nrg_bal,
      values_from = energy
    ) %>%
    # rename
    rename(
      Road = FC_TRA_ROAD_E,
      Rail = FC_TRA_RAIL_E,
      Navigation = FC_TRA_DNAVI_E
    ) %>%
    pivot_longer(
      cols = c(Road, Rail, Navigation),
      names_to = "mode",
      values_to = "energy_consumption"
    )
}

prepare_transport_vkm <- function(
    road_tf_vehmov,
    rail_tf_trainmv,
    iww_tf_vetf,
    first_year,
    last_year) {
  # prepare road traffic data
  
  # subset the road traffic data from road_tf_vehmov to keep only total vehicle transport in VKM, for EU28 countries from 2010.
  traffic_road <- road_tf_vehmov %>%
    filter(
      # from first year
      time >= first_year,
      # to last year
      time <= last_year,
      # work with total road vehicles on national territory (goods + passenger), in million VKM
      regisveh %in% c("TERNAT_REG", "TERNAT_REGNAT"),
      vehicle == "TOTAL",
      unit == "MIO_VKM"
    ) %>%
    pivot_wider(
      names_from = regisveh,
      values_from = values
    ) %>%
    mutate(values = ifelse(is.na(TERNAT_REG), TERNAT_REGNAT, TERNAT_REG)) %>%
    select(-c("TERNAT_REG", "TERNAT_REGNAT")) %>%
    # convert all figures to vkm, add mode
    mutate(
      VKM = values * 1000000,
      mode = "Road"
    ) %>%
    # keep only relevant columns
    select(-c(unit, vehicle, values))

  # prepare rail traffic data}
  
  # subset the rail traffic data from rail_tf_trainmv to keep only total vehicle transport in VKM, for EU28 countries from 2010.
  traffic_rail <- rail_tf_trainmv %>%
    filter(
      # from first year
      time >= first_year,
      # to last year
      time <= last_year,
      # work with total trains (goods + passenger), in thousand VKM
      train == "TOTAL",
      unit == "THS_TRKM"
    ) %>%
    # convert all figures to vkm, add mode
    mutate(
      VKM = values * 1000,
      mode = "Rail"
    ) %>%
    # keep only relevant columns
    select(-c(unit, train, values))
  
  # prepare vessel traffic data}
  
  # subset the vessel traffic data from iww_tf_vetf to keep only national transport in VKM, for EU28 countries from 2010.
  traffic_water <- iww_tf_vetf %>%
    filter(
      # from first year
      time >= first_year,
      # to last year
      time <= last_year,
      # work with total (loaded and empty) and transport from all nationalities, in thousand VKM
      tra_cov == "TOTAL",
      loadstat == "TOTAL",
      unit == "THS_VESKM"
    ) %>%
    # convert all figures to vkm, add mode
    mutate(
      VKM = values * 1000,
      mode = "Navigation"
    ) %>%
    # keep only relevant columns
    select(-c(unit, tra_cov, loadstat, values))
  
  # joining datasets
  traffic <- traffic_road %>%
    bind_rows(traffic_rail) %>%
    bind_rows(traffic_water)
  
  traffic
}

prepare_transport_vkm_decomposition <- function(
    traffic,
    transport_energy,
    first_year,
    last_year
){
  # Joining datasets
  transport_complete <- full_join(
    transport_energy,
    traffic,
    by = c("geo", "time", "mode")
  ) %>%
    join_transport_energy_consumption_vkm()
  
  # filter out sectors with incomplete data
  transport_filtered <- filter_energy_consumption_activity(
    transport_complete,
    first_year = first_year,
    last_year = last_year
  )
  
  # Effects calculation
  
  # calculate the required indicators for the 3 effects
  transport_augmented <- add_share_transport_modes(transport_filtered$df)
  transport_total <- add_total_transport_modes(transport_augmented)
  
  # calculate the indexed and differenced indicators
  transport_full <- transport_augmented %>%
    rbind(transport_total) %>%
    add_index_delta()
  
  list(df = transport_full, notifications = transport_filtered$notifications)
}

join_transport_energy_consumption_vkm <- function(df) {
  df %>%
    # correcting for missing VKM / Energy
    mutate(
      VKM = case_when(
        (VKM == 0 & energy_consumption > 0) ~ NA_real_,
        TRUE ~ VKM
      ),
      energy_consumption = case_when(
        (energy_consumption == 0 & VKM > 0) ~ NA_real_,
        TRUE ~ energy_consumption
      ),
      # intensity calculated here for the charts, will be recalculated later once the totals are included
      intensity = case_when(
        (VKM == 0 & energy_consumption > 0) ~ NA_real_,
        (VKM == 0 & energy_consumption == 0) ~ 0,
        TRUE ~ energy_consumption / VKM
      )
    ) %>%
    # for each country and each year
    group_by(geo, time) %>%
    mutate(
      # calculate the total energy consumption and VKM of the overall transport sector, as the sum of all mode selected
      total_energy_consumption = sum(energy_consumption, na.rm = TRUE),
      total_VKM = sum(VKM, na.rm = TRUE)
    ) %>%
    # for each country, each year and each mode
    ungroup() %>%
    mutate(
      # calculate the share of the subsecto in the overall energy consumption and in the overall traffic
      share_energy_consumption = energy_consumption / total_energy_consumption,
      share_VKM = VKM / total_VKM
    )
}

filter_transport_vkm <- function(
    df,
    first_year,
    last_year) {
  unique_countries <- unique(df$geo)
  unique_mode <- unique(df$mode)
  my_warnings = c()
  for (country in unique_countries) {
    for (mode in unique_mode) {
      subset_df <- df[
        df$geo == country &
          df$mode == mode &
          df$time <= last_year&
          df$time >= first_year,
      ]
      # For this decomposition, due to the many gaps, we only remove mode where first or last year are missing
      if (any((is.na(subset_df$VKM) | subset_df$VKM == 0) & (subset_df$time %in% c(last_year_shown, first_year_shown)))) {
        missing_years <- subset_df$time[is.na(subset_df$VKM) | subset_df$VKM == 0]
        df <- df[!(df$geo == country & df$mode == mode), ]
        warning_message <- paste(
          "Country:", country, ", Mode:", mode,
          "- removed (missing VKM in years:",
          paste(missing_years, collapse = ", "), ")"
        )
        my_warnings <- c(my_warnings, warning_message)
        flog.warn(warning_message)
      } else if (any((is.na(subset_df$energy_consumption) | subset_df$energy_consumption == 0) & (!is.na(subset_df$VKM) & subset_df$VKM != 0) & (subset_df$time %in% c(last_year_shown, first_year_shown)))) {
        missing_years <- subset_df$time[is.na(subset_df$energy_consumption) | subset_df$energy_consumption == 0]
        df <- df[!(df$geo == country & df$mode == mode), ]
        warning_message <- paste(
          "Country:", country, ", Mode:", mode,
          "- removed (missing energy consumption in years:",
          paste(missing_years, collapse = ", "), ")"
        )
        my_warnings <- c(my_warnings, warning_message)
        flog.warn(warning_message)
      }
    }
  }
  list(df = df, notifications = my_warnings)
}

add_share_transport_modes <- function(df) {
  df %>%
    # For each country and each year
    group_by(geo, time) %>%
    mutate(
      # Calculate the total energy consumption and value added of the overall industry sector, as the sum of all subsectors selected
      total_energy_consumption = sum(energy_consumption, na.rm = TRUE),
      total_VKM = sum(VKM, na.rm = TRUE)
    ) %>%
    ungroup() %>%
    # For each country, each year and each subsector
    mutate(
      # Calculate the share of the subsector in the overall energy consumption and in the overall value added of the industry sector
      share_energy_consumption = energy_consumption / total_energy_consumption,
      share_VKM = VKM / total_VKM
    ) %>%
    # remove the total columns, not required any longer
    select(-c(
      total_energy_consumption,
      total_VKM,
      intensity
    )) %>%
    ungroup()
}

add_total_transport_modes <- function(df) {
  df %>%
    group_by(geo, time) %>%
    summarize(
      VKM = sum(VKM, na.rm = TRUE),
      energy_consumption = sum(energy_consumption, na.rm = TRUE),
      # the sum of shares should be one, calculated here for checking
      share_VKM = sum(share_VKM, na.rm = TRUE),
      share_energy_consumption = sum(share_energy_consumption, na.rm = TRUE),
      .groups = "drop_last"
    ) %>%
    ungroup() %>%
    mutate(mode = "Total")
}

add_index_delta_transport_modes <- function(df) {
  df %>%
    # calculate intensity again, to include the total intensity
    mutate(intensity = case_when(
      (VKM == 0 & energy_consumption > 0) ~ NA_real_,
      (VKM == 0 & energy_consumption == 0) ~ 0,
      TRUE ~ energy_consumption / VKM
    )) %>%
    pivot_longer(
      cols = -c(geo, time, mode),
      names_to = "measure",
      values_to = "value"
    ) %>%
    group_by(geo, mode, measure) %>%
    mutate(
      value_indexed = value / value[time == transport_base_year(country = .data[["geo"]], first_year = first_year)],
      value_delta = value - value[time == transport_base_year(country = .data[["geo"]], first_year = first_year)],
      time = as.integer(time)
    ) %>%
    ungroup()
}

apply_LMDI_transport_vkm <- function(
    df,
    first_year) {
  if (nrow(df) == 0) {
    stop("No data available for LMDI calculation.")
  }
  df %>%
    # Reshape to wide (moving all measures calculated in Value, index and delta, all in separate columns)
    pivot_wider(
      names_from = measure,
      values_from = c(value, value_indexed, value_delta)
    ) %>%
    # Calculate the effects
    mutate(
      # the weighting factor links the effect calculated on the indexed variation to the total energy consumption variation
      weighting_factor = ifelse(
        value_delta_energy_consumption == 0,
        value_energy_consumption,
        value_delta_energy_consumption / log(value_indexed_energy_consumption)
      ),
      # Apply natural logarithm to the indexed values for each mode
      activity_log = ifelse(value_indexed_VKM == 0, 0, log(value_indexed_VKM)),
      structure_log = ifelse(value_indexed_share_VKM == 0, 0, log(value_indexed_share_VKM)),
      intensity_log = ifelse(value_indexed_intensity == 0, 0, log(value_indexed_intensity))
    ) %>%
    # Keep only the relevant columns
    select(
      geo,
      time,
      mode,
      weighting_factor,
      value_energy_consumption,
      value_delta_energy_consumption,
      activity_log,
      structure_log,
      intensity_log
    ) %>%
    # The baseline figures need to be expanded across all mode, and across all years
    rowwise() %>%
    mutate(base_year = first_year) %>%
    ungroup() %>%
    group_by(geo) %>%
    mutate(
      value_energy_consumption_total_baseline = value_energy_consumption[mode == "Total" & time == base_year]
      ) %>%
    ungroup() %>%
    # Similarly, the figures calculated for the total mode and the end figures need to be expanded across all modes
    group_by(geo, time) %>%
    mutate(
      activity_log_total = activity_log[mode == "Total"],
      value_delta_energy_consumption_total = value_delta_energy_consumption[mode == "Total"],
      value_energy_consumption_total_end = value_energy_consumption[mode == "Total"]
    ) %>%
    ungroup() %>%
    # Now the total mode is not required any longer
    filter(mode != "Total") %>%
    # Multiply the weighting factor * log(indexed mode), or weighting factor * log(indexed total modes)
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
    # Now the figures calculated at mode level need to be aggregated
    group_by(geo, time) %>%
    # The aggregation is performed differently:
    summarize(
      # Either by summing all mode
      activity_effect = sum(ACT, na.rm = TRUE),
      structural_effect = sum(STR, na.rm = TRUE),
      intensity_effect = sum(INT, na.rm = TRUE),
      # By keeping the mean figure when only one exist across all modes
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
          select(
            .,
            c(
              "activity_effect",
              "structural_effect",
              "intensity_effect"
            )
          ),
        )
    )
}

### Charts

generate_country_charts <- function(
    transport_complete,
    first_year,
    last_year,
    country_name,
    country_chart,
    output_path) {
  # Country data
  transport_country_data <-
    transport_complete %>%
    filter(
      geo == country_chart,
      time <= last_year
    ) %>%
    mutate(mode = factor(mode, levels = IDA_TRA_MODES))

  # Table used to provide figures in the text of the report
  table_transport_country_data <-
    transport_country_data %>%
    mutate(
      VKM = round(VKM, 2),
      energy_consumption = round(energy_consumption, 2),
      share_VKM = round(share_VKM, 2),
      share_energy_consumption = round(share_energy_consumption, 2)
    )

  save_data(
    table_transport_country_data,
    filename = "Part5_mode.csv",
    output_path = output_path
  )

  # energy consumption and VKM by mode

  year <-
    as.Date(as.character(transport_country_data$time), "%Y")

  # Transport energy consumption by mode
  p <- transport_country_data %>%
    cbind(year) %>%
    select(-time) %>%
    mutate(year = lubridate::year(year)) %>%
    ggplot(aes(x = year, y = energy_consumption / 1000)) +
    geom_bar(aes(fill = mode), stat = "identity") +
    scale_fill_manual(values = TransportModeColors, limits = force) +
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
    ggtitle(paste("Transport energy consumption by mode for", country_name))

  print_chart(p,
    filename = paste0(country_chart, "_Figure27.jpg"),
    output_path = output_path,
    width = 2400,
    height = 2400,
    res = 300
  )

  # 2 years share

  p <- transport_country_data %>%
    filter(time %in% c(first_year, last_year)) %>%
    ggplot(aes(
      x = factor(time),
      y = share_energy_consumption,
      fill = mode
    )) +
    geom_bar(position = "fill", stat = "identity") +
    scale_fill_manual(values = TransportModeColors, limits = force) +
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
    ggtitle(paste("Energy consumption by mode for", country_name))

  print_chart(p,
    filename = paste0(country_chart, "_Figure27B.jpg"),
    output_path = output_path,
    width = 2400,
    height = 2400,
    res = 300
  )

  # Transport traffic by mode
  p <- transport_country_data %>%
    cbind(year) %>%
    select(-time) %>%
    mutate(year = lubridate::year(year)) %>%
    ggplot(aes(x = year, y = VKM / 1000000)) +
    geom_bar(aes(fill = mode), stat = "identity") +
    scale_fill_manual(values = TransportModeColors, limits = force) +
    theme_classic() +
    theme(
      axis.title.x = element_blank(),
      legend.title = element_blank(),
      legend.position = "bottom",
      legend.box = "horizontal",
      text = element_text(size = 15)
    ) +
    guides(fill = guide_legend(ncol = 3)) +
    scale_x_continuous(breaks = c(
      first_year,
      # round((first_year + last_year) / 2),
      last_year
    )) +
    scale_y_continuous(labels = scales::number) +
    ylab(paste("Traffic (Million VKM)")) +
    ggtitle(paste("Traffic by mode for", country_name))

  print_chart(p,
    filename = paste0(country_chart, "_Figure28.jpg"),
    output_path = output_path,
    width = 2400,
    height = 2400,
    res = 300
  )

  # 2 years share

  p <- transport_country_data %>%
    filter(time %in% c(first_year, last_year)) %>%
    ggplot(aes(
      x = factor(time),
      y = share_VKM,
      fill = mode
    )) +
    geom_bar(position = "fill", stat = "identity") +
    scale_fill_manual(values = TransportModeColors, limits = force) +
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
    geom_text(aes(label = paste0(round(share_VKM * 100, 0), "%")),
      position = position_stack(vjust = 0.5)
    ) +
    ylab(paste("Share of traffic")) +
    ggtitle(paste("Traffic by mode for", country_name))

  print_chart(p,
    filename = paste0(country_chart, "_Figure28B.jpg"),
    output_path = output_path,
    width = 2400,
    height = 2400,
    res = 300
  )
}

generate_subsectors_charts <- function(
    transport_full,
    country_chart,
    country_name,
    first_year_chart,
    last_year_chart,
    output_path) {
  # full data (after filtering)
  transport_mode <-
    transport_full %>%
    filter(
      geo == country_chart,
      time >= first_year_chart,
      time <= last_year_chart
    )

  # chart indexed variation of total transport

  transport_data <-
    transport_mode %>%
    filter(
      mode == "Total",
      measure %in% c("intensity", "energy_consumption", "VKM")
    ) %>%
    select(-c(
      value,
      value_delta
    )) %>%
    mutate(measure = case_when(
      measure == "intensity" ~ "Energy intensity",
      measure == "energy_consumption" ~ "Energy consumption",
      measure == "VKM" ~ "Traffic",
      TRUE ~ measure
    ))

  year <- as.Date(as.character(transport_data$time), "%Y")

  p <- transport_data %>%
    cbind(year) %>%
    select(-time) %>%
    ggplot() +
    geom_blank(aes(x = year)) +
    geom_line(aes(x = year, y = value_indexed, color = measure), size = 1) +
    scale_color_manual(values = TransportColorsIndex) +
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
    ylab(paste("Index (", transport_base_year(country = country_chart, first_year = first_year), "=1)")) +
    ggtitle(paste("Indexed indicators for", country_name, "'s total energy consumption, \ntraffic and energy intensity variation of the transport sector, \nall years related to", as.character(first_year_chart)))

  print_chart(p,
    filename = paste0(country_chart, "_Figure29B.jpg"),
    output_path = output_path,
    width = 2400,
    height = 2400,
    res = 300
  )

  # Indexed variation by mode

  year <- as.Date(as.character(transport_mode$time), "%Y")

  p <- transport_mode %>%
    cbind(year) %>%
    select(-time) %>%
    filter(
      mode != "Total",
      measure == "intensity"
    ) %>%
    mutate(mode = factor(mode, levels = IDA_TRA_MODES)) %>%
    ggplot() +
    geom_blank(aes(x = year)) +
    geom_line(aes(x = year, y = value_indexed, color = mode), size = 1) +
    scale_color_manual(values = TransportModeColors, limits = force) +
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
    ylab(paste("Index (", transport_base_year(country = country_chart, first_year = first_year), "=1)")) +
    ggtitle(paste("Indexed variation for", country_name, "'s energy intensity by transport mode, \nall years related to", as.character(first_year)))

  print_chart(p,
    filename = paste0(country_chart, "_Figure29C.jpg"),
    output_path = output_path,
    width = 2400,
    height = 2400,
    res = 300
  )
  # intensity comparison chart 1

  # Prepare data for the intensity comparison chart
  transport_intensity_comparison_data <- transport_full %>%
    filter(
      measure == "intensity",
      time <= last_year_chart,
      mode != "Total"
    ) %>%
    select(-c(value_indexed, value_delta)) %>%
    mutate(value = value * 1000000) %>%
    pivot_wider(names_from = geo, values_from = value)

  min_EU <-
    apply(select_if(transport_intensity_comparison_data[, -1], is.numeric),
      1,
      min,
      na.rm = TRUE
    )
  max_EU <-
    apply(select_if(transport_intensity_comparison_data[, -1], is.numeric),
      1,
      max,
      na.rm = TRUE
    )
  avg_EU <-
    apply(select_if(transport_intensity_comparison_data[, -1], is.numeric),
      1,
      mean,
      na.rm = TRUE
    )
  year <-
    as.Date(
      as.character(transport_intensity_comparison_data$time),
      "%Y"
    )

  transport_intensity_comparison_data <-
    transport_intensity_comparison_data %>%
    cbind(min_EU) %>%
    cbind(max_EU) %>%
    cbind(avg_EU) %>%
    cbind(year) %>%
    select(c(year, mode, !!country_chart, min_EU, max_EU)) %>%
    mutate(year = lubridate::year(year))

  # Plot the intensity comparison as line chart
  p <- transport_intensity_comparison_data %>%
    ggplot(aes(x = year)) +
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
      text = element_text(size = 15)
    ) +
    ylab("Energy intensity (TJ / Million VKM)") +
    scale_x_continuous(breaks = c(first_year, round((
      first_year + last_year
    ) / 2), last_year)) +
    # scale_y_continuous(labels = scales::number) +
    expand_limits(y = 0) +
    scale_y_continuous(breaks = scales::breaks_extended(Q = c(0, 1, 2, 3))) +
    ggtitle(paste("Energy intensity in", country_name, "'s transport by mode compared to \nother European countries")) +
    facet_wrap(~mode, scales = "free")

  print_chart(p,
    filename = paste0(country_chart, "_Figure31.jpg"),
    output_path = output_path,
    width = 2400,
    height = 1600,
    res = 300
  )

  # intensity comparison chart 2

  # prepare data for the intensity comparison across mode chart
  mode_comparison_data <- transport_full %>%
    filter(
      geo == country_chart,
      measure == "intensity",
      mode != "Total",
      time <= last_year
    ) %>%
    mutate(value = value * 1000000)

  year <- as.Date(as.character(mode_comparison_data$time), "%Y")

  mode_comparison_data <- mode_comparison_data %>%
    cbind(year) %>%
    select(c(year, mode, value)) %>%
    mutate(year = lubridate::year(year))

  # Plot the intensity comparison as line chart
  p <- mode_comparison_data %>%
    ggplot(aes(x = year, y = value, color = mode)) +
    geom_line(size = 1) +
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
    ylab("Energy intensity (TJ / Million VKM)") +
    scale_x_continuous(breaks = c(first_year, round((
      first_year + last_year
    ) / 2), last_year)) +
    ggtitle(paste("Energy intensity in", country_name, "compared by mode"))

  print_chart(p,
    filename = paste0(country_chart, "_Figure31B.jpg"),
    output_path = output_path,
    width = 2400,
    height = 2400,
    res = 300
  )

  # intensity comparison chart 3

  # prepare data for the intensity comparison across mode chart
  mode_comparison_data <- transport_full %>%
    filter(
      geo == country_chart,
      measure == "intensity",
      mode != "Total",
      time <= last_year
    ) %>%
    mutate(value = value * 1000000)

  year <- as.Date(as.character(mode_comparison_data$time), "%Y")

  mode_comparison_data <- mode_comparison_data %>%
    cbind(year) %>%
    select(c(year, mode, value)) %>%
    mutate(year = lubridate::year(year))
}

generate_energy_breakdown_charts <- function(
    transport_energy_breakdown,
    country_chart,
    country_name,
    first_year,
    last_year,
    output_path) {
  # Breakdown of energy consumption by fuel
  transport_energy_breakdown_filtered <-
    transport_energy_breakdown %>%
    filter(
      geo == country_chart,
      !energy_consumption == 0
    )

  # Table used to provide figures in the text of the report
  table_transport_energy_breakdown_filtered <-
    transport_energy_breakdown_filtered %>%
    mutate(
      energy_consumption = round(energy_consumption, 2),
      share_energy_consumption = round(share_energy_consumption, 3)
    )

  save_data(
    table_transport_energy_breakdown_filtered,
    filename = "Part5_fuel.csv",
    output_path = output_path
  )

  # Final energy consumption by fuel

  year <-
    as.Date(
      as.character(transport_energy_breakdown_filtered$time),
      "%Y"
    )

  p <- transport_energy_breakdown_filtered %>%
    cbind(year) %>%
    select(-time) %>%
    mutate(year = lubridate::year(year)) %>%
    ggplot(aes(x = year, y = energy_consumption / 1000)) +
    geom_bar(aes(fill = product), stat = "identity") +
    scale_fill_manual(values = TransportProductColors, limits = force) +
    theme_classic() +
    theme(
      axis.title.x = element_blank(),
      legend.title = element_blank(),
      legend.position = "bottom",
      legend.box = "horizontal",
      text = element_text(size = 15)
    ) +
    guides(fill = guide_legend(ncol = 3)) +
    scale_x_continuous(breaks = c(first_year, round((first_year + last_year
    ) / 2), last_year)) +
    scale_y_continuous(labels = scales::number) +
    ylab(paste("Energy consumption (PJ)")) +
    ggtitle(paste("Transport energy consumption by fuel for", country_name))

  print_chart(p,
    filename = paste0(country_chart, "_Figure26.jpg"),
    output_path = output_path,
    width = 2400,
    height = 2400,
    res = 300
  )

  # 2 years

  p <- transport_energy_breakdown_filtered %>%
    filter(time %in% c(first_year, last_year)) %>%
    ggplot(aes(
      x = factor(time),
      y = share_energy_consumption,
      fill = product
    )) +
    geom_bar(position = "fill", stat = "identity") +
    scale_fill_manual(values = TransportProductColors, limits = force) +
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
      aes(label = paste0(round(share_energy_consumption * 100, 0), "%")),
      position = position_stack(vjust = 0.5)
    ) +
    ylab(paste("Share in final energy consumption")) +
    ggtitle(paste("Transport energy consumption by fuel for", country_name))

  print_chart(p,
    filename = paste0(country_chart, "_Figure26B.jpg"),
    output_path = output_path,
    width = 2400,
    height = 2400,
    res = 300
  )
}

generate_final_effects_charts <- function(
    transport_LMDI,
    country_chart,
    country_name,
    first_year,
    last_year,
    first_year_chart,
    last_year_chart,
    output_path) {
  # prepare data for the simple effect chart
  transport_effects <- transport_LMDI %>%
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

  results_df <- transport_LMDI %>%
    filter(
      geo == country_chart,
      time <= last_year
    ) %>%
    pivot_longer(
      cols = -c(geo, time),
      names_to = "measure",
      values_to = "value"
    ) %>%
    filter(measure == "energy_consumption_var_obs")

  # Plot the simple effect as bar chart
  p <- ggplot(
    data = transport_effects,
    aes(
      x = factor(time),
      y = value / 1000
    )
  ) +
    geom_bar(aes(fill = Effect),
      stat = "identity"
    ) +
    scale_fill_manual(values = TransportColorsEffect, limits = force) +
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
    ggtitle(paste("Decompostion analysis of", country_name, "'s transport energy consumption variation, \n  all years related to", as.character(first_year_chart)))

  print_chart(p,
    filename = paste0(country_chart, "_Figure29D.jpg"),
    output_path = output_path,
    width = 2400,
    height = 1600,
    res = 300
  )

  # waterfall chart

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
  transport_Waterfall_data <- transport_LMDI %>%
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
      text = paste(as.character(round(y, 2)), "PJ", sep = " "),
      measure = case_when(
        (x == !!Result_label) ~ "total",
        TRUE ~ "relative"
      )
    )

  save_data(
    transport_Waterfall_data,
    filename = "Part5_waterfall.csv",
    output_path = output_path
  )


  p <- transport_Waterfall_data %>%
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
    filename = paste0(country_chart, "_Figure29.jpg"),
    output_path = output_path,
    width = 2400,
    height = 1600,
    res = 300
  )

  # Intensity effect chart

  # prepare data for the intensity effect chart
  transport_intensity_effect_data <-
    transport_LMDI %>%
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
    transport_intensity_effect_data,
    filename = "Part5_intensity_effect.csv",
    output_path = output_path
  )

  # Plot the intensity effect as area chart
  p <- transport_intensity_effect_data %>%
    ggplot() +
    geom_bar(
      data = (
        transport_intensity_effect_data %>%
          filter(measure == "Actual energy consumption")
      ),
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
      data = (
        transport_intensity_effect_data %>%
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
    ggtitle(paste("Actual energy consumption in the transport sector vs theoretical \n(without energy intensity improvements) for", country_name))

  print_chart(p,
    filename = paste0(country_chart, "_Figure30.jpg"),
    output_path = output_path,
    width = 2400,
    height = 2400,
    res = 300
  )
}


generate_coverage_chart <- function(
    transport_complete,
    last_year_chart,
    output_path) {
  # Data coverage chart
  missing_data <- transport_complete %>%
    filter(
      mode != "Total",
      geo != "EU27",
      time <= last_year
    ) %>%
    select(c("geo", "time", "mode", "energy_consumption", "VKM")) %>%
    replace(is.na(.), 0) %>%
    mutate(
      missing =
        case_when(
          (energy_consumption > 0 & VKM > 0) |
            (energy_consumption == 0 & VKM == 0) ~ 0,
          TRUE ~ 1
        )
    ) %>%
    select(-c("energy_consumption", "VKM")) %>%
    group_by(geo, time) %>%
    summarize(
      missing = sum(missing),
      .groups = "drop_last"
      )

  save_data(
    missing_data,
    filename = "Part5_missing_data.csv",
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
      limits = c(0, 3),
      breaks = scales::pretty_breaks(n = 3)(0:3)
    ) +
    theme(
      axis.title.x = element_blank(),
      axis.title.y = element_blank()
    ) +
    labs(fill = "Missing modes") +
    ggtitle("Completeness of coverage (energy and activity data) for European countries across years")

  print_chart(p,
    filename = "EU27_Figure31D.jpg",
    output_path = output_path,
    width = 2400,
    height = 3200,
    res = 300
  )
}

generate_eu_comparison_chart <- function(
    transport_full,
    first_year_chart,
    last_year_chart,
    output_path) {
  # EU intensity comparison chart
  transport_intensity_EU_comparison_data <-
    transport_full %>%
    filter(
      measure == "intensity",
      time %in% c(first_year_chart, last_year_chart),
      mode != "Total",
      geo != "EU27"
    ) %>%
    arrange(value) %>%
    merge(eu_countries, by.x = "geo", by.y = "code") %>%
    select(-c("geo", "label"))

  save_data(
    transport_intensity_EU_comparison_data %>% mutate(value = value * 1000000),
    filename = "Part5_EU27.csv",
    output_path = output_path
  )

  # Rank the countries by intensity on last year
  country_ranked_road <- transport_intensity_EU_comparison_data %>%
    filter(
      time == last_year_chart,
      mode == "Road"
    ) %>%
    arrange(value) %>%
    pull(name)

  country_ranked_rail <- transport_intensity_EU_comparison_data %>%
    filter(
      time == last_year_chart,
      mode == "Rail"
    ) %>%
    arrange(value) %>%
    pull(name)

  country_ranked_water <- transport_intensity_EU_comparison_data %>%
    filter(
      time == last_year_chart,
      mode == "Navigation"
    ) %>%
    arrange(value) %>%
    pull(name)

  road_chart <- transport_intensity_EU_comparison_data %>%
    filter(mode == "Road") %>%
    ggplot(aes(
      x = factor(name, levels = country_ranked_road),
      y = value * 1000000,
      color = as.factor(time)
    )) +
    geom_point() +
    geom_line(aes(group = name), colour = "grey") +
    coord_flip() +
    theme_classic() +
    theme(
      axis.title.y = element_blank(),
      legend.title = element_blank(),
      legend.position = "bottom",
      legend.box = "horizontal"
    ) +
    ylab("Energy intensity (TJ / Million VKM)") +
    scale_y_continuous(labels = scales::number) +
    ggtitle(paste("Energy intensity of road transport in European countries"))

  rail_chart <- transport_intensity_EU_comparison_data %>%
    filter(mode == "Rail") %>%
    ggplot(aes(
      x = factor(name, levels = country_ranked_rail),
      y = value * 1000000,
      color = as.factor(time)
    )) +
    geom_point() +
    geom_line(aes(group = name), colour = "grey") +
    coord_flip() +
    theme_classic() +
    theme(
      axis.title.y = element_blank(),
      legend.title = element_blank(),
      legend.position = "bottom",
      legend.box = "horizontal"
    ) +
    ylab("Energy intensity (TJ / Million VKM)") +
    scale_y_continuous(labels = scales::number) +
    ggtitle(paste("Energy intensity of rail transport in European countries"))

  water_chart <- transport_intensity_EU_comparison_data %>%
    filter(mode == "Navigation") %>%
    ggplot(aes(
      x = factor(name, levels = country_ranked_water),
      y = value * 1000000,
      color = as.factor(time)
    )) +
    geom_point() +
    geom_line(aes(group = name), colour = "grey") +
    coord_flip() +
    theme_classic() +
    theme(
      axis.title.y = element_blank(),
      legend.title = element_blank(),
      legend.position = "bottom",
      legend.box = "horizontal"
    ) +
    ylab("Energy intensity (TJ / Million VKM)") +
    scale_y_continuous(labels = scales::number) +
    ggtitle(paste("Energy intensity of rail transport in European countries"))

  p <- ggarrange(
    road_chart,
    rail_chart,
    water_chart,
    ncol = 3,
    nrow = 1,
    labels = c("Road", "Rail", "Navigation"),
    label.x = 0.5,
    align = "hv",
    common.legend = TRUE,
    legend = "bottom"
  )

  print_chart(p,
    filename = "EU27_Figure31C.jpg",
    output_path = output_path,
    width = 3000,
    height = 3200,
    res = 300
  )
}