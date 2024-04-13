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
source("0_support/shared_functions.R")

prepare_energy_consumption <- function(
    nrg_bal_c,
    first_year,
    last_year) {
  prepare_industry_energy(
    nrg_bal_c,
    first_year = first_year,
    last_year = last_year) %>%
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
    last_year) {
  industry_GVA <- prepare_industry_GVA(
    nama_10_a64,
    first_year = first_year,
    last_year = last_year
  )
  #apply_gva_corrections() %>%
  reverse_negative_gva(industry_GVA)
}

prepare_decomposition <- function(
    industry_GVA,
    industry_energy_final,
    first_year,
    last_year
  ){
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
  industry_GVA_final_augmented <- add_share_sectors(industry_GVA_final_filtered$df)
  industry_GVA_final_total <- add_total_sectors(industry_GVA_final_augmented)
  
  # Calculate the indexed and indexed indicators
  industry_GVA_final_full <- industry_GVA_final_augmented %>%
    rbind(industry_GVA_final_total) %>%
    add_index_delta(first_year = first_year)

  list(df = industry_GVA_final_full, notifications = industry_GVA_final_filtered$notifications)
  
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

add_index_delta <- function(
    df,
    first_year) {
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
        value[time == first_year] == 0 ~ 0,
        is.na(value[time == first_year]) ~ NA_real_,
        TRUE ~ value / value[time == first_year]
      ),
      value_delta = value - value[time == first_year],
      time = as.integer(time)
    ) %>%
    ungroup()
}

apply_LMDI <- function(
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
    mutate(base_year = first_year) %>%
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

### Charts

prepare_industry_energy_consumption_by_product_charts <- function(
    industry_energy_consumption_by_product,
    country){
  industry_energy_consumption_by_product %>%
  ggplot(aes(x = time, y = energy_consumption / 1000)) +
  geom_bar(aes(fill = product), stat = "identity") +
  scale_fill_manual(values = FinalProductsColors, limits = force) +
  theme_classic() +
  theme(axis.title.x = element_blank()) +
  scale_y_continuous(labels = scales::number) +
  ylab(paste("Energy consumption (PJ)")) +
  ggtitle(paste("Industry energy consumption by product for", country))
}

prepare_industry_energy_consumption_by_sector_charts <- function(
    industry_energy_consumption_by_sector,
    country){
  industry_energy_consumption_by_sector %>%
    ggplot(aes(x = time, y = energy_consumption / 1000)) +
    geom_bar(aes(fill = sector), stat = "identity") +
    scale_fill_manual(values = ManufacturingSectorsColors, limits = force) +
    theme_classic() +
    theme(axis.title.x = element_blank()) +
    scale_y_continuous(labels = scales::number) +
    ylab(paste("Energy consumption (PJ)")) +
    ggtitle(paste("Industry energy consumption by subsector for", country))
}

prepare_industry_GVA_by_sector_charts <- function(
    industry_GVA_by_sector,
    country){
  industry_GVA_by_sector %>%
    ggplot(aes(x = time, y = GVA / 1000)) +
    geom_bar(aes(fill = sector), stat = "identity") +
    scale_fill_manual(values = ManufacturingSectorsColors, limits = force) +
    theme_classic() +
    theme(axis.title.x = element_blank()) +
    scale_y_continuous(labels = scales::number) +
    ylab(paste("Gross Value Added (Billion EUR)")) +
    ggtitle(paste("Industry gross value added by subsector for", country))
}

prepare_indexed_chart <- function(
    industry_GVA_final_full,
    first_year,
    country
){
  industry_GVA_final_full %>%
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
    ) %>%
    pivot_longer(
      cols = -c(geo, time),
      names_to = "measure",
      values_to = "value"
    ) %>%
    ggplot() +
    geom_blank(aes(x = time)) +
    geom_line(aes(x = time, y = value, color = measure), size = 1) +
    scale_color_manual(values = IndustryGVAColorsIndex) +
    theme_classic() +
    theme(
      axis.title.x = element_blank(),
    ) +
    scale_y_continuous(labels = scales::number) +
    ylab(paste("Index (", first_year, "=1)")) +
    ggtitle(paste("Indexed indicators for", country, "\nall years related to", as.character(first_year)))
}

prepare_waterfall_chart <- function(
    industry_GVA_final_LMDI,
    first_year_chart,
    last_year_chart,
    country) {

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

  # prepare data for the waterfall chart
  industry_GVA_final_waterfall_data <- industry_GVA_final_LMDI %>%
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
      text = paste(as.character(round(y, 2)), "TJ", sep = " "),
      measure = case_when(
        x == !!Result_label ~ "total",
        TRUE ~ "relative"
      )
    ) %>%
    filter(x != Result_label) %>%
    select(x, y) %>%
    mutate(y = round(y / 1000, 2))

  waterfall(
    industry_GVA_final_waterfall_data,
    calc_total = TRUE,
  ) +
    theme_classic() +
    xlab("Effects") +
    theme(
      axis.title.x = element_blank(),
    ) +
    scale_y_continuous(labels = scales::number) +
    ylab("Energy consumption (PJ)") +
    scale_x_discrete(labels = levels_waterfall) + 
    ggtitle(paste("Decomposition of energy consumption variation for", country))
}

prepare_intensity_effects_chart <- function(
    industry_GVA_final_LMDI,
    first_year_chart,
    last_year_chart,
    country) {
  
  # Intensity effect chart
  
  # Prepare data for the intensity effect chart
  industry_GVA_final_intensity_effect <- industry_GVA_final_LMDI %>%
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

  industry_GVA_final_intensity_effect %>%
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
      data = (industry_GVA_final_intensity_effect %>%
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
    ggtitle(paste("Actual energy consumption in the industry vs theoretical (without energy intensity effect) for", country))
}