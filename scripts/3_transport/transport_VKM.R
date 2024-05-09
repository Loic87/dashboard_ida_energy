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

placeholder_text = paste("\nPlease select country and years with available data\n")
placeholder_plot <- ggplot() + 
  annotate("text", x = 4, y = 25, size=8, label = placeholder_text) + 
  theme_void()

prepare_transport_energy_consumption_by_product <- function(
    nrg_bal_c,
    first_year,
    last_year) {
  if (nrow(nrg_bal_c) == 0) {
    return (data.frame())
  } else {
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
      select(-all_of(c(COAL_PRODS, GASOLINE_PRODS, BIOGASOLINE_PRODS, DIESEL_PRODS, BIODIESEL_PRODS, LPG_PRODS, KEROSENE_PRODS, OTHER_OIL_PRODS, OTHER_BIOLIQUIDS_PRODS, BIOGAS_PRODS, OTH_BIOWASTE_PRODS))) %>%
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
}

prepare_transport_energy_consumption_by_mode <- function(
    nrg_bal_c,
    first_year,
    last_year) {
  if (nrow(nrg_bal_c) == 0) {
    return (data.frame())
  } else {
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
}

prepare_transport_vkm <- function(
    road_tf_vehmov,
    rail_tf_trainmv,
    iww_tf_vetf,
    first_year,
    last_year) {
  
  # prepare road traffic data
  if (nrow(road_tf_vehmov) > 0){
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
  } else {
    traffic_road <- data.frame()
  }

  # prepare rail traffic data}
  if (nrow(rail_tf_trainmv) > 0){
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
  } else {
    traffic_rail <- data.frame()
  }
  
  # prepare vessel traffic data}
  if (nrow(iww_tf_vetf) > 0){
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
  } else {
    traffic_water <- data.frame()
  }
  
  # joining datasets
  traffic <- traffic_road %>%
    bind_rows(traffic_rail) %>%
    bind_rows(traffic_water)
  
  list(df = traffic, notifications = c())
}

prepare_transport_vkm_decomposition <- function(
    traffic,
    transport_energy,
    first_year,
    last_year
){
  if ((nrow(transport_energy) > 0) & (nrow(traffic) > 0)) {
    # Joining datasets
    transport_complete <- full_join(
      transport_energy,
      traffic,
      by = c("geo", "time", "mode")
    ) %>%
      join_transport_energy_consumption_vkm()
    
    # filter out sectors with incomplete data
    transport_filtered <- filter_transport_vkm(
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
      add_index_delta_transport_modes(first_year = first_year)
    
    list(df = transport_full, notifications = transport_filtered$notifications)
  } else {
    list(df = data.frame(), notifications = c("No data available for LMDI calculation."))
  }
}

join_transport_energy_consumption_vkm <- function(df) {
  if (nrow(df) > 0) {
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
  } else {
    df
  }
}

filter_transport_vkm <- function(
    df,
    first_year,
    last_year) {
  if (nrow(df) == 0) {
    return (list(df = df, notifications = c("No data available for LMDI calculation.")))
  } else {
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
        if (any((is.na(subset_df$VKM) | subset_df$VKM == 0) & (subset_df$time %in% c(last_year, first_year)))) {
          missing_years <- subset_df$time[is.na(subset_df$VKM) | subset_df$VKM == 0]
          df <- df[!(df$geo == country & df$mode == mode), ]
          warning_message <- paste(
            "Country:", country, ", Mode:", mode,
            "- removed (missing VKM in years:",
            paste(missing_years, collapse = ", "), ")"
          )
          my_warnings <- c(my_warnings, warning_message)
          flog.warn(warning_message)
        } else if (any((is.na(subset_df$energy_consumption) | subset_df$energy_consumption == 0) & (!is.na(subset_df$VKM) & subset_df$VKM != 0) & (subset_df$time %in% c(last_year, first_year)))) {
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
}

add_share_transport_modes <- function(df) {
  if (nrow(df) == 0) {
    return(df)
  } else {
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
}

add_total_transport_modes <- function(df) {
  if (nrow(df) == 0) {
    return(df)
  } else {
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
}

add_index_delta_transport_modes <- function(
    df,
    first_year) {
  if (nrow(df) == 0) {
    return(df)
  } else {
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
        value_indexed = value / value[time == first_year],
        value_delta = value - value[time == first_year],
        time = as.integer(time)
      ) %>%
      ungroup()
  }
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

prepare_transport_energy_consumption_by_product_charts <- function(
    transport_energy_consumption_by_product,
    country) {
  if (nrow(transport_energy_consumption_by_product) == 0) {
    return(placeholder_plot)
  } else {
    transport_energy_consumption_by_product %>%
      ggplot(aes(x = time, y = energy_consumption / 1000)) +
      geom_bar(aes(fill = product), stat = "identity") +
      scale_fill_manual(values = TransportProductColors, limits = force) +
      theme_classic() +
      theme(axis.title.x = element_blank()) +
      scale_y_continuous(labels = scales::number) +
      ylab(paste("Energy consumption (PJ)")) +
      ggtitle(paste("Transport energy consumption by fuel for", country))
  }
}

prepare_transport_energy_consumption_by_mode_charts <- function(
    transport_energy_consumption_by_mode,
    country){
  if (nrow(transport_energy_consumption_by_mode) == 0) {
    return(placeholder_plot)
  } else {
    transport_energy_consumption_by_mode %>%
      ggplot(aes(x = time, y = energy_consumption / 1000)) +
      geom_bar(aes(fill = mode), stat = "identity") +
      scale_fill_manual(values = TransportModeColors, limits = force) +
      theme_classic() +
      theme(axis.title.x = element_blank()) +
      scale_y_continuous(labels = scales::number) +
      ylab(paste("Energy consumption (PJ)")) +
      ggtitle(paste("Transport energy consumption by mode for", country))
  }
}

prepare_transport_VKM_by_mode_charts <- function(
    transport_traffic_by_mode,
    country){
  if (nrow(transport_traffic_by_mode) == 0) {
    return(placeholder_plot)
  } else {
    transport_traffic_by_mode %>%
      ggplot(aes(x = time, y = VKM / 1000000)) +
      geom_bar(aes(fill = mode), stat = "identity") +
      scale_fill_manual(values = TransportModeColors, limits = force) +
      theme_classic() +
      theme(axis.title.x = element_blank()) +
      scale_y_continuous(labels = scales::number) +
      ylab(paste("Traffic (Million VKM)")) +
      ggtitle(paste("Traffic by mode for", country))
  }
}

prepare_transport_indexed_chart <- function(
  transport_vkm_full,
  first_year,
  country
) {
  if (nrow(transport_vkm_full) == 0) {
    return(placeholder_plot)
  } else {
    transport_vkm_full %>%
      filter(mode == "Total")  %>%
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
        VKM
      )) %>%
      rename(
        "Energy intensity" = "intensity",
        "Energy consumption" = "energy_consumption",
        "Traffic" = "VKM"
      ) %>%
      pivot_longer(
        cols = -c(geo, time),
        names_to = "measure",
        values_to = "value"
      ) %>%
      ggplot() +
      geom_blank(aes(x = time)) +
      geom_line(aes(x = time, y = value, color = measure), size = 1) +
      scale_color_manual(values = TransportColorsIndex) +
      theme_classic() +
      theme(axis.title.x = element_blank()) +
      scale_y_continuous(labels = scales::number) +
      ylab(paste("Index (", first_year, "=1)")) +
      ggtitle(paste("Indexed indicators for", country, "\nall years related to", as.character(first_year)))
  }
}

prepare_transport_waterfall_chart <- function(
    transport_vkm_LMDI,
    first_year_chart,
    last_year_chart,
    country) {
  
  if (nrow(transport_vkm_LMDI) == 0) {
    return(placeholder_plot)
  } else {
  
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
    
    # prepare data for the waterfall chart
    transport_vkm_waterfall_data <- transport_vkm_LMDI %>%
      filter(
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
      ) %>%
      filter(x != Result_label) %>%
      select(x, y) %>%
      mutate(y = round(y / 1000, 2))
    
    waterfall(
      transport_vkm_waterfall_data,
      calc_total = TRUE,
    ) +
    theme_classic() +
    xlab("Effects") +
    theme(axis.title.x = element_blank()) +
    scale_y_continuous(labels = scales::number) +
    ylab("Energy consumption level and effect (PJ)") +
    scale_x_discrete(labels = levels_waterfall) + 
    ggtitle(paste("Decomposition of energy consumption variation for", country))
  }
}
  
prepare_transport_intensity_effects_chart <- function(
    transport_vkm_LMDI,
    first_year_chart,
    last_year_chart,
    country) {
  
  if (nrow(transport_vkm_LMDI) == 0) {
    return(placeholder_plot)
  } else {
  
    # Intensity effect chart
    
    # prepare data for the intensity effect chart
    transport_intensity_effect_data <- transport_LMDI %>%
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
    
    transport_intensity_effect_data %>%
      ggplot() +
      geom_bar(
        data = (transport_intensity_effect_data %>%
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
        data = (transport_intensity_effect_data %>%
                  filter(measure == "Without intensity effect")),
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
      theme(axis.title.x = element_blank()) +
      scale_y_continuous(labels = scales::number) +
      ylab("Energy consumption (PJ)") +
      expand_limits(y = 0) +
      ggtitle(paste("Actual energy consumption in the transport sector vs theoretical (without energy intensity improvements) for", country))
  }
}