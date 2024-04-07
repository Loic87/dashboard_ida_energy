library(fs)
library(tidyverse)
library(tidyr)
library(dplyr)
library(ggplot2)
library(futile.logger)
# FINAL ENERGY CONSUMPTION IN INDUSTRY
source("scripts/0_support/outputs.R")
source("scripts/0_support/year_selection.R")
source("scripts/0_support/mapping_sectors.R")
source("scripts/0_support/mapping_products.R")
source("scripts/0_support/mapping_colors.R")
source("scripts/0_support/manual_corrections.R")
source("scripts/4_all_sectors/shared.R")

# Data preparation
industry_GVA_final <- function(
    first_year,
    last_year,
    country,
    data_path,
    chart_path) {
  flog.info("Prepare the data for final energy consumption in industry (gva based) decomposition (all countries)")

  # Define the list as the whole list
  country_list <- geo_codes

  # DATA PREPARATION

  # Energy consumption (and supply) from the energy balance (nrg_bal_c)
  load(paste0(data_path, "/nrg_bal_c.Rda"))

  # Economic activity from the national account data (nama_10_a64)
  load(paste0(data_path, "/nama_10_a64.Rda"))

  # Energy consumption by fuel
  industry_energy_breakdown <- prepare_energy_product_breakdown(
    # take industry end uses
    nrg_bal_c %>% filter(nrg_bal %in% NRG_IND_SECTORS),
    first_year = first_year,
    last_year = last_year,
    country_list = country_list
  )

  # energy consumption (and supply) from the energy balance (nrg_bal_c)
  industry_energy_final <- prepare_energy_consumption(
    nrg_bal_c,
    first_year = first_year,
    last_year = last_year,
    country_list = country_list
  )

  # economic activity from the national account data (nama_10_a64)
  industry_GVA <- prepare_activity(
    nama_10_a64,
    first_year = first_year,
    last_year = last_year,
    country_list = country_list
  )

  # Joining datasets
  industry_GVA_final_complete <- full_join(
    industry_GVA,
    industry_energy_final,
    by = c("geo", "time", "sector")
  ) %>%
    join_energy_consumption_activity()

  # filter out sectors with incomplete data
  industry_GVA_final_filtered <- filter_energy_consumption_activity(
    industry_GVA_final_complete,
    first_year = first_year,
    last_year = last_year
  )

  # Effects calculation

  # calculate the required indicators for the 3 effects
  industry_GVA_final_augmented <- add_share_sectors(industry_GVA_final_filtered)
  industry_GVA_final_total <- add_total_sectors(industry_GVA_final_augmented)

  # Calculate the indexed and indexed indicators
  industry_GVA_final_full <- industry_GVA_final_augmented %>%
    rbind(industry_GVA_final_total) %>%
    add_index_delta()

  # Calculate the effects using the LMDI formulas
  industry_GVA_final_LMDI <- apply_LMDI(industry_GVA_final_full)

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
    first_year_chart <- industry_GVA_base_year(country = country_chart, first_year = first_year)
    last_year_chart <- industry_GVA_last_year(country = country_chart, final_year = last_year)

    flog.info(paste("Prepare the charts and data for", country_name, "(", first_year_chart, "-", last_year_chart, ")"))
    flog.info(paste("Saved in", output_path))

    tryCatch(
      {
        generate_energy_breakdown_charts(
          industry_energy_breakdown,
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
          industry_GVA_final_complete,
          country_chart = country_chart,
          country_name = country_name,
          first_year = first_year,
          last_year = last_year,
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
          industry_GVA_final_full,
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
          industry_GVA_final_LMDI,
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
            industry_GVA_final_complete,
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
            industry_GVA_final_full,
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
  prepare_industry_energy(
    nrg_bal_c,
    first_year = first_year,
    last_year = last_year,
    country_list = country_list
  ) %>%
    filter(siec == "TOTAL") %>%
    select(-c(siec)) %>%
    # reshape to long
    pivot_longer(
      cols = -c(geo, time),
      names_to = "sector",
      values_to = "energy_consumption"
    )
}

prepare_activity <- function(
    nama_10_a64,
    first_year,
    last_year,
    country_list) {
  prepare_industry_GVA(
    nama_10_a64,
    first_year = first_year,
    last_year = last_year,
    country_list = country_list
  ) %>%
    apply_gva_corrections() %>%
    reverse_negative_gva()
}

join_energy_consumption_activity <- function(df) {
  df %>%
    # correcting for missing GVA / Energy
    mutate(
      GVA = case_when(
        (GVA == 0 & energy_consumption > 0) ~ NA_real_,
        TRUE ~ GVA
      ),
      energy_consumption = case_when(
        (energy_consumption == 0 & GVA > 0) ~ NA_real_,
        TRUE ~ energy_consumption
      ),
      # intensity calculated here for the charts, will be recalculated later once the totals are included
      intensity = case_when(
        (GVA == 0 & energy_consumption > 0) ~ NA_real_,
        (GVA == 0 & energy_consumption == 0) ~ 0,
        TRUE ~ energy_consumption / GVA
      )
    ) %>%
    # For each country and each year
    group_by(geo, time) %>%
    mutate(
      # Calculate the total energy consumption and value added of the overall industry sector, as the sum of all subsectors
      total_energy_consumption = sum(energy_consumption, na.rm = TRUE),
      total_GVA = sum(GVA, na.rm = TRUE)
    ) %>%
    # For each country, each year and each subsector
    ungroup() %>%
    mutate(
      # Calculate the share of the subsector in the overall energy consumption and in the overall value added of the industry sector
      share_energy_consumption = energy_consumption / total_energy_consumption,
      share_GVA = GVA / total_GVA
    )
}

add_share_sectors <- function(df) {
  df %>%
    # For each country and each year
    group_by(geo, time) %>%
    mutate(
      # Calculate the total energy consumption and value added of the overall industry sector, as the sum of all subsectors selected
      total_energy_consumption = sum(energy_consumption, na.rm = TRUE),
      total_GVA = sum(GVA, na.rm = TRUE)
    ) %>%
    ungroup() %>%
    # For each country, each year and each subsector
    mutate(
      # Calculate the share of the subsector in the overall energy consumption and in the overall value added of the industry sector
      share_energy_consumption = energy_consumption / total_energy_consumption,
      share_GVA = GVA / total_GVA
    ) %>%
    # Remove the total columns, not required any longer
    select(-c(
      total_energy_consumption,
      total_GVA,
      intensity
    )) %>%
    ungroup()
}

filter_energy_consumption_activity <- function(
    df,
    first_year,
    last_year) {
  filter_industry_GVA(
    df,
    first_year = first_year,
    last_year = last_year
  )
}

add_total_sectors <- function(df) {
  df %>%
    group_by(geo, time) %>%
    summarize(
      GVA = sum(GVA, na.rm = TRUE),
      energy_consumption = sum(energy_consumption, na.rm = TRUE),
      # the sum of shares should be one, calculated here for checking
      share_GVA = sum(share_GVA, na.rm = TRUE),
      share_energy_consumption = sum(share_energy_consumption, na.rm = TRUE)
    ) %>%
    ungroup() %>%
    mutate(sector = "Total")
}

add_index_delta <- function(df) {
  df %>%
    # calculate intensity again, to include the total intensity
    mutate(
      intensity = case_when(
        (GVA == 0 & energy_consumption > 0) ~ NA_real_,
        (GVA == 0 & energy_consumption == 0) ~ 0,
        TRUE ~ energy_consumption / GVA
      )
    ) %>%
    pivot_longer(
      cols = -c(geo, time, sector),
      names_to = "measure",
      values_to = "value"
    ) %>%
    group_by(geo, sector, measure) %>%
    mutate(
      value_indexed = case_when(
        value[time == industry_GVA_base_year(country = .data[["geo"]], first_year = first_year)] == 0 ~ 0,
        is.na(value[time == industry_GVA_base_year(country = .data[["geo"]], first_year = first_year)]) ~ NA_real_,
        TRUE ~ value / value[time == industry_GVA_base_year(country = .data[["geo"]], first_year = first_year)]
      ),
      value_delta = value - value[time == industry_GVA_base_year(country = .data[["geo"]], first_year = first_year)],
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
      activity_log = ifelse(value_indexed_GVA == 0, 0, log(value_indexed_GVA)),
      structure_log = ifelse(value_indexed_share_GVA == 0, 0, log(value_indexed_share_GVA)),
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
    mutate(base_year = industry_GVA_base_year(country = .data[["geo"]], first_year = first_year)) %>%
    ungroup() %>%
    group_by(geo) %>%
    mutate(
      value_energy_consumption_total_baseline = value_energy_consumption[sector == "Total" & time == base_year]
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
      value_energy_consumption_total_end = mean(value_energy_consumption_total_end)
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
          # na.rm = TRUE
        )
    )
}

generate_country_charts <- function(
    industry_GVA_final_complete,
    first_year,
    last_year,
    country_name,
    country_chart,
    output_path) {
  # Country data
  industry_GVA_final_country_data <-
    industry_GVA_final_complete %>%
    filter(
      geo == country_chart,
      time <= last_year
    ) %>%
    mutate(sector = factor(sector, levels = IDA_IND_SECTOR))

  # Table used to provide figures in the text of the report
  table_industry_GVA_final_country_data <-
    industry_GVA_final_country_data %>%
    mutate(
      GVA = round(GVA, 2),
      energy_consumption = round(energy_consumption, 2),
      share_GVA = round(share_GVA, 2),
      share_energy_consumption = round(share_energy_consumption, 2)
    )

  save_data(
    table_industry_GVA_final_country_data,
    filename="Part1_sector.csv",
    output_path=output_path
  )

  # Energy consumption by subsector

  year <- as.Date(as.character(industry_GVA_final_country_data$time), "%Y")

  p <- industry_GVA_final_country_data %>%
    cbind(year) %>%
    select(-time) %>%
    mutate(year = lubridate::year(year)) %>%
    ggplot(aes(x = year, y = energy_consumption / 1000)) +
    geom_bar(aes(fill = sector), stat = "identity") +
    scale_fill_manual(values = ManufacturingSectorsColors, limits = force) +
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
    filename = paste0(country_chart, "_Figure03.jpg"),
    output_path = output_path,
    width = 2400,
    height = 2400,
    res = 300
  )

  # 2 years share

  p <- industry_GVA_final_country_data %>%
    filter(time %in% c(first_year, last_year)) %>%
    mutate(sector = factor(sector, levels = IDA_IND_SECTOR)) %>%
    ggplot(aes(
      x = factor(time),
      y = share_energy_consumption,
      fill = sector
    )) +
    geom_bar(position = "fill", stat = "identity") +
    scale_fill_manual(values = ManufacturingSectorsColors, limits = force) +
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
    filename = paste0(country_chart, "_Figure03B.jpg"),
    output_path = output_path,
    width = 2400,
    height = 2400,
    res = 300
  )

  # GVA by subsector

  p <- industry_GVA_final_country_data %>%
    cbind(year) %>%
    select(-time) %>%
    mutate(year = lubridate::year(year)) %>%
    ggplot(aes(x = year, y = GVA / 1000)) +
    geom_bar(aes(fill = sector), stat = "identity") +
    scale_fill_manual(values = ManufacturingSectorsColors, limits = force) +
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
    ylab(paste("Gross Value Added (Billion EUR)")) +
    ggtitle(paste("Industry gross value added by subsector for", country_name))

  print_chart(p,
    filename = paste0(country_chart, "_Figure04.jpg"),
    output_path = output_path,
    width = 2400,
    height = 2400,
    res = 300
  )

  # 2 years share

  p <- industry_GVA_final_country_data %>%
    filter(time %in% c(first_year, last_year)) %>%
    ggplot(aes(
      x = factor(time),
      y = share_GVA,
      fill = sector
    )) +
    geom_bar(position = "fill", stat = "identity") +
    scale_fill_manual(values = ManufacturingSectorsColors, limits = force) +
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
    geom_text(aes(label = paste0(round(share_GVA * 100, 0), "%")),
      position = position_stack(vjust = 0.5)
    ) +
    ylab(paste("Share of Gross Value Added")) +
    ggtitle(paste("Industry gross value added by subsector for", country_name))

  print_chart(p,
    filename = paste0(country_chart, "_Figure04B.jpg"),
    output_path = output_path,
    width = 2400,
    height = 2400,
    res = 300
  )

  # Sectoral intensity comparison chart

  # Prepare data for the intensity comparison chart
  industry_GVA_final_intensity_comparison_sector <-
    industry_GVA_final_complete %>%
    mutate(sector = factor(sector, levels = IDA_IND_SECTOR)) %>%
    filter(time <= last_year) %>%
    select(-c(
      GVA, energy_consumption,
      total_energy_consumption, total_GVA,
      share_energy_consumption, share_GVA
    )) %>%
    pivot_wider(names_from = geo, values_from = intensity)

  min_EU <-
    apply(
      select_if(
        industry_GVA_final_intensity_comparison_sector[, -1],
        is.numeric
      ),
      1,
      min,
      na.rm = TRUE
    )
  max_EU <-
    apply(
      select_if(
        industry_GVA_final_intensity_comparison_sector[, -1],
        is.numeric
      ),
      1,
      max,
      na.rm = TRUE
    )
  avg_EU <-
    apply(
      select_if(
        industry_GVA_final_intensity_comparison_sector[, -1],
        is.numeric
      ),
      1,
      mean,
      na.rm = TRUE
    )


  year <-
    as.Date(as.character(industry_GVA_final_intensity_comparison_sector$time), "%Y")

  industry_GVA_final_intensity_comparison_sector <-
    industry_GVA_final_intensity_comparison_sector %>%
    cbind(min_EU) %>%
    cbind(max_EU) %>%
    cbind(avg_EU) %>%
    cbind(year) %>%
    select(c(sector, year, !!country_chart, min_EU, max_EU)) %>%
    mutate(
      year = lubridate::year(year),
      sector = factor(sector, levels = IDA_IND_SECTOR)
    )

  # Plot the intensity comparison as line chart
  p <- industry_GVA_final_intensity_comparison_sector %>%
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
      legend.position = c(0.75, 0.05),
      legend.box = "horizontal",
      text = element_text(size = 15)
    ) +
    # scale_y_continuous(labels = scales::number) +
    expand_limits(y = 0) +
    scale_y_continuous(breaks = scales::breaks_extended(Q = c(0, 1, 2, 3))) +
    ylab("Energy intensity (MJ / EUR)") +
    scale_x_continuous(breaks = c(first_year, round((first_year + last_year) / 2), last_year)) +
    ggtitle(paste("Energy intensity in", country_name, "'s manufacturing industry compared to \naverage European countries")) +
    facet_wrap(~sector,
      scales = "free",
      ncol = 3
    )

  print_chart(p,
    filename = paste0(country_chart, "_Figure08.jpg"),
    output_path = output_path,
    width = 2400,
    height = 2400,
    res = 300
  )
}

generate_subsectors_charts <- function(
    industry_GVA_final_full,
    country_chart,
    country_name,
    first_year_chart,
    last_year_chart,
    output_path) {
  # full data (after filtering)
  industry_GVA_final_subsector <-
    industry_GVA_final_full %>%
    filter(
      geo == country_chart,
      time >= first_year_chart,
      time <= last_year_chart
    )

  # Chart indexed variation of total industry
  industry_GVA_final_country_indexed <-
    industry_GVA_final_subsector %>%
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
      GVA
    )) %>%
    rename(
      "Energy intensity" = "intensity",
      "Energy consumption" = "energy_consumption",
      "Gross Value Added" = "GVA"
    )

  year <- as.Date(as.character(industry_GVA_final_country_indexed$time), "%Y")

  p <- industry_GVA_final_country_indexed %>%
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
    scale_color_manual(values = IndustryGVAColorsIndex) +
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
    ylab(paste("Index (", industry_GVA_base_year(country = country_chart, first_year = first_year), "=1)")) +
    ggtitle(paste("Indexed indicators for", country_chart, "'s total industry energy consumption, \ngross value added and energy intensity variation, \nall years related to", as.character(first_year)))

  print_chart(p,
    filename = paste0(country_chart, "_Figure05B.jpg"),
    output_path = output_path,
    width = 2400,
    height = 2400,
    res = 300
  )

  # indexed variation by subsector

  year <- as.Date(as.character(industry_GVA_final_subsector$time), "%Y")

  p <- industry_GVA_final_subsector %>%
    cbind(year) %>%
    select(-time) %>%
    filter(
      sector != "Total",
      measure == "intensity"
    ) %>%
    mutate(sector = factor(sector, levels = IDA_IND_SECTOR)) %>%
    ggplot() +
    geom_blank(aes(x = year)) +
    geom_line(aes(x = year, y = value_indexed, color = sector), size = 1) +
    scale_color_manual(values = ManufacturingSectorsColors, limits = force) +
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
    ylab(paste("Index (", industry_GVA_base_year(country = country_chart, first_year = first_year), "=1)")) +
    ggtitle(paste("Indexed variation for", country_name, "'s energy intensity in industry subsectors, \nall years related to", as.character(first_year)))

  print_chart(p,
    filename = paste0(country_chart, "_Figure05C.jpg"),
    output_path = output_path,
    width = 2400,
    height = 2400,
    res = 300
  )

  # Total intensity comparison chart

  # Prepare data for the intensity comparison chart
  industry_GVA_final_intensity_comparison_total <-
    industry_GVA_final_full %>%
    filter(
      measure == "intensity",
      time <= last_year_chart,
      sector == "Total"
    ) %>%
    select(-c(value_indexed, value_delta)) %>%
    pivot_wider(names_from = geo, values_from = value)

  min_EU <-
    apply(
      select_if(
        industry_GVA_final_intensity_comparison_total[, -1],
        is.numeric
      ),
      1,
      min,
      na.rm = TRUE
    )
  max_EU <-
    apply(
      select_if(
        industry_GVA_final_intensity_comparison_total[, -1],
        is.numeric
      ),
      1,
      max,
      na.rm = TRUE
    )
  avg_EU <-
    apply(
      select_if(
        industry_GVA_final_intensity_comparison_total[, -1],
        is.numeric
      ),
      1,
      mean,
      na.rm = TRUE
    )
  year <-
    as.Date(
      as.character(industry_GVA_final_intensity_comparison_total$time),
      "%Y"
    )

  industry_GVA_final_intensity_comparison_total <-
    industry_GVA_final_intensity_comparison_total %>%
    cbind(min_EU) %>%
    cbind(max_EU) %>%
    cbind(avg_EU) %>%
    cbind(year) %>%
    select(c(year, !!country_chart, min_EU, max_EU)) %>%
    mutate(year = lubridate::year(year))

  # Plot the intensity comparison as line chart
  p <- industry_GVA_final_intensity_comparison_total %>%
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
    ylab("Energy intensity (MJ / EUR)") +
    scale_x_continuous(breaks = c(first_year, round((first_year + last_year) / 2), last_year)) +
    ggtitle(paste("Energy intensity in", country_name, "'s manufacturing industry compared to \naverage European countries"))

  print_chart(p,
    filename = paste0(country_chart, "_Figure07.jpg"),
    output_path = output_path,
    width = 2400,
    height = 2400,
    res = 300
  )
}

generate_energy_breakdown_charts <- function(
    industry_energy_breakdown,
    country_chart,
    country_name,
    first_year,
    last_year,
    output_path) {
  # Breakdown of energy consumption by fuel
  industry_energy_breakdown_filtered <-
    industry_energy_breakdown %>%
    filter(
      geo == country_chart,
      !energy_consumption == 0
    )

  # Table used to provide figures in the text of the report
  table_industry_energy_breakdown_filtered <-
    industry_energy_breakdown_filtered %>%
    mutate(
      energy_consumption = round(energy_consumption, 2),
      share_energy_consumption = round(share_energy_consumption, 3)
    )

  save_data(
    table_industry_energy_breakdown_filtered,
    filename="Part1_fuel.csv",
    output_path=output_path
  )

  # Final energy consumption by fuel

  year <- as.Date(as.character(industry_energy_breakdown_filtered$time), "%Y")

  p <- industry_energy_breakdown_filtered %>%
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
    ggtitle(paste("Industry energy consumption by fuel for", country_name))

  print_chart(p,
    filename = paste0(country_chart, "_Figure02.jpg"),
    output_path = output_path,
    width = 2400,
    height = 2400,
    res = 300
  )

  # 2 years

  p <- industry_energy_breakdown_filtered %>%
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
      aes(label = paste0(round(share_energy_consumption * 100, 0), "%")),
      position = position_stack(vjust = 0.5)
    ) +
    ylab(paste("Share in final energy consumption")) +
    ggtitle(paste("Industry energy consumption by fuel for", country_name))

  print_chart(p,
    filename = paste0(country_chart, "_Figure02B.jpg"),
    output_path = output_path,
    width = 2400,
    height = 2400,
    res = 300
  )
}

generate_final_effects_charts <- function(
    industry_GVA_final_LMDI,
    country_chart,
    country_name,
    first_year,
    last_year,
    first_year_chart,
    last_year_chart,
    output_path) {
  # prepare data for the simple effect chart
  industry_GVA_final_effects <- industry_GVA_final_LMDI %>%
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

  industry_GVA_final_results <- industry_GVA_final_LMDI %>%
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
    data = industry_GVA_final_effects,
    aes(
      x = factor(time),
      y = value / 1000
    )
  ) +
    geom_bar(aes(fill = Effect),
      stat = "identity"
    ) +
    scale_fill_manual(values = IndustryGVAColorsEffect, limits = force) +
    geom_point(
      data = industry_GVA_final_results,
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
    ggtitle(paste("Decompostion analysis of", country_name, "'s industry energy consumption variation, \n  all years related to", as.character(first_year)))

  print_chart(p,
    filename = paste0(country_chart, "_Figure05D.jpg"),
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
  industry_GVA_final_Waterfall_data <- industry_GVA_final_LMDI %>%
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
        x == !!Result_label ~ "total",
        TRUE ~ "relative"
      )
    )

  save_data(
    industry_GVA_final_Waterfall_data,
    filename="Part1_waterfall.csv",
    output_path=output_path
  )

  p <- industry_GVA_final_Waterfall_data %>%
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
    filename = paste0(country_chart, "_Figure05.jpg"),
    output_path = output_path,
    width = 2400,
    height = 1600,
    res = 300
  )

  # Intensity effect chart

  # Prepare data for the intensity effect chart
  industry_GVA_final_intensity_effect <-
    industry_GVA_final_LMDI %>%
    filter(
      geo == country_chart,
      time <= last_year,
      time >= first_year
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
    industry_GVA_final_intensity_effect,
    filename="Part1_intensity_effect.csv",
    output_path=output_path
  )

  # Plot the intensity effect as area chart
  p <- industry_GVA_final_intensity_effect %>%
    ggplot() +
    geom_bar(
      data = (industry_GVA_final_intensity_effect %>%
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
      data = (
        industry_GVA_final_intensity_effect %>%
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
    ggtitle(paste("Actual energy consumption in the industry vs theoretical \n(without energy intensity improvements) for ", country_name))

  print_chart(p,
    filename = paste0(country_chart, "_Figure06.jpg"),
    output_path = output_path,
    width = 2400,
    height = 1600,
    res = 300
  )
}

generate_coverage_chart <- function(
    industry_GVA_final_complete,
    last_year_chart,
    output_path) {
  # Data coverage chart
  missing_data <- industry_GVA_final_complete %>%
    filter(
      sector != "Total",
      geo != "EU27",
      time <= last_year_chart
    ) %>%
    select(c("geo", "time", "sector", "energy_consumption", "GVA")) %>%
    replace(is.na(.), 0) %>%
    mutate(
      missing =
        case_when(
          (energy_consumption > 0 & GVA > 0) |
            (energy_consumption == 0 & GVA == 0) ~ 0,
          TRUE ~ 1
        )
    ) %>%
    select(-c("energy_consumption", "GVA")) %>%
    group_by(geo, time) %>%
    summarize(missing = sum(missing))

  save_data(
    missing_data,
    filename="Part1_missing_data.csv",
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
      limits = c(0, 13),
      breaks = scales::pretty_breaks(n = 4)(0:13)
    ) +
    theme(
      axis.title.x = element_blank(),
      axis.title.y = element_blank()
    ) +
    labs(fill = "Missing sub-sectors") +
    ggtitle("Completeness of coverage (energy and activity data) for European countries")

  print_chart(p,
    filename = "EU27_Figure08C.jpg",
    output_path = output_path,
    width = 2400,
    height = 3200,
    res = 300
  )
}

generate_eu_comparison_chart <- function(
    industry_GVA_final_full,
    first_year_chart,
    last_year_chart,
    output_path) {
  # Prepare the data
  EU_comparison <- industry_GVA_final_full %>%
    filter(
      measure == "intensity",
      time %in% c(first_year_chart, last_year_chart),
      sector == "Total",
      geo != "EU27"
    ) %>%
    select(-c(value_indexed, value_delta)) %>%
    merge(eu_countries, by.x = "geo", by.y = "code") %>%
    select(-c("geo", "label"))

  save_data(
    EU_comparison,
    filename="Part1_EU27.csv",
    output_path=output_path
  )


  # Rank the countries by intensity on last year
  country_ranked <- EU_comparison %>%
    filter(time == last_year_chart) %>%
    arrange(value) %>%
    pull(name)

  # Output charts
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
    guides(fill = guide_legend(ncol = 3)) +
    scale_y_continuous(labels = scales::number) +
    ylab("Energy intensity (TJ / million EUR)") +
    ggtitle(paste("Energy intensity of manufacturing industry of European countries"))

  print_chart(p,
    filename = "EU27_Figure08B.jpg",
    output_path = output_path,
    width = 2400,
    height = 2400,
    res = 300
  )
}