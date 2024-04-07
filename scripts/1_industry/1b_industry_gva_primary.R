library(fs)
library(tidyverse)
library(tidyr)
library(dplyr)
library(ggplot2)
library(futile.logger)
# PRIMARY ENERGY CONSUMPTION IN INDUSTRY
source("scripts/0_support/outputs.R")
source("scripts/0_support/year_selection.R")
source("scripts/0_support/mapping_sectors.R")
source("scripts/0_support/mapping_products.R")
source("scripts/0_support/mapping_colors.R")
source("scripts/0_support/manual_corrections.R")
source("scripts/4_all_sectors/shared.R")

# Data preparation
industry_GVA_primary <- function(
    first_year,
    last_year,
    country,
    data_path,
    chart_path) {
  flog.info("Prepare the data for primary energy consumption in industry (gva based) decomposition (all countries)")

  # Define the list as the whole list
  country_list <- geo_codes

  # DATA PREPARATION

  # Energy consumption (and supply) from the energy balance (nrg_bal_c)
  load(paste0(data_path, "/nrg_bal_c.Rda"))

  # Economic activity from the national account data (nama_10_a64)
  load(paste0(data_path, "/nama_10_a64.Rda"))

  # electricity and heat inputs

  # share of primary energy used for electricity and heat production

  ele_heat_share_primary <- prepare_ele_heat_share_primary(
    nrg_bal_c,
    first_year = first_year,
    last_year = last_year,
    country_list = country_list
  )

  # get input to electricity and heat plants by fuel

  ele_heat_input_breakdown <- prepare_ele_heat_input_breakdown(
    nrg_bal_c,
    first_year = first_year,
    last_year = last_year,
    country_list = country_list
  )

  # subset the energy data from nrg_bal_c to keep only total energy consumption in TJ in industry sectors, for EU28 countries from 2010.
  energy_EHG_TJ <- prepare_energy_EHG_TJ(
    nrg_bal_c,
    first_year = first_year,
    last_year = last_year,
    country_list = country_list
  )

  # prepare energy data

  # energy consumption (and supply) from the energy balance (nrg_bal_c)
  industry_energy_primary <- prepare_energy_consumption(
    nrg_bal_c,
    energy_EHG_TJ,
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
  industry_GVA_primary_complete <- full_join(
    industry_GVA,
    industry_energy_primary,
    by = c("geo", "time", "sector")
  ) %>%
    join_energy_consumption_activity()

  # filter out sectors with incomplete data
  industry_GVA_primary_filtered <- filter_energy_consumption_activity(
    industry_GVA_primary_complete,
    first_year = first_year,
    last_year = last_year
  )

  # Effects calculation

  # calculate the required indicators for the 3 effects
  industry_GVA_primary_augmented <- add_share_sectors(industry_GVA_primary_filtered)
  industry_GVA_primary_total <- add_total_sectors(industry_GVA_primary_augmented)

  # Calculate the indexed and indexed indicators
  industry_GVA_primary_full <- industry_GVA_primary_augmented %>%
    rbind(industry_GVA_primary_total) %>%
    add_index_delta()

  # Calculate the effects using the LMDI formulas
  industry_GVA_primary_LMDI <- apply_LMDI(industry_GVA_primary_full)

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
        generate_ele_heat_share_primary_charts(
          ele_heat_share_primary,
          country_chart = country_chart,
          country_name = country_name,
          first_year = first_year,
          last_year = last_year,
          output_path = output_path
        )
      },
      error = function(e) {
        flog.error("Error preparing electricity and heat primary energy share charts: ", e)
      }
    )

    tryCatch(
      {
        generate_ele_heat_consumption_breakdown_charts(
          energy_EHG_TJ,
          country_chart = country_chart,
          country_name = country_name,
          first_year = first_year,
          last_year = last_year,
          output_path = output_path
        )
      },
      error = function(e) {
        flog.error("Error preparing electricity and heat consumption breakdown charts: ", e)
      }
    )

    tryCatch(
      {
        generate_input_ele_heat_production_charts(
          ele_heat_input_breakdown,
          country_chart = country_chart,
          country_name = country_name,
          first_year = first_year,
          last_year = last_year,
          output_path = output_path
        )
      },
      error = function(e) {
        flog.error("Error preparing electricity and heat production charts: ", e)
      }
    )

    tryCatch(
      {
        generate_country_charts(
          industry_GVA_primary_complete,
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
          industry_GVA_primary_full,
          country_name = country_name,
          country_chart = country_chart,
          first_year_chart = first_year_chart,
          last_year_chart = last_year_chart,
          output_path = output_path
        )
      },
      error = function(e) {
        flog.error("Error preparing subsectors charts: ", e)
      }
    )

    tryCatch(
      {
        # Simple effect decomposition
        generate_primary_effects_charts(
          industry_GVA_primary_LMDI,
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
        flog.error("Error preparing primary effect charts: ", e)
      }
    )

    if (country_chart == "EU27") {
      output_path <- paste0(chart_path, "/EU27/")
      flog.info(paste("Additional charts and data for EU27 (", first_year_chart, "-", last_year_chart, ")"))

      tryCatch(
        {
          generate_coverage_chart(
            industry_GVA_primary_complete,
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
            energy_EHG_TJ,
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

prepare_ele_heat_share_primary <- function(
    nrg_bal_c,
    first_year,
    last_year,
    country_list) {
  nrg_bal_c %>%
    filter(
      geo %in% country_list,
      # from first year
      time >= first_year,
      # to last year
      time <= last_year,
      # take input to electricity and heat
      nrg_bal %in% c("TI_EHG_E", "PEC2020-2030"),
      # work with total energy consumption, in TJ
      siec == "TOTAL",
      unit == "TJ"
    ) %>%
    # reshape to wide
    pivot_wider(
      names_from = nrg_bal,
      values_from = values
    ) %>%
    mutate(share_EHG = TI_EHG_E / .data[["PEC2020-2030"]])
}

prepare_ele_heat_input_breakdown <- function(
    nrg_bal_c,
    first_year,
    last_year,
    country_list) {
  nrg_bal_c %>%
    filter(
      geo %in% country_list,
      # from first year
      time >= first_year,
      # to last year
      time <= last_year,
      # take input to electricity and heat
      nrg_bal == "TI_EHG_E",
      # work with total energy consumption, in TJ
      siec %in% NRG_PRODS,
      unit == "TJ"
    ) %>%
    select(-c(nrg_bal, unit)) %>%
    # reshape to wide
    pivot_wider(
      names_from = siec,
      values_from = values
    ) %>%
    # aggregate
    mutate(
      # Coal, manufactured gases, peat and peat products
      CPS = rowSums(select(., all_of(COAL_PRODS)), na.rm = TRUE),
      # Oil, petroleum products, oil shale and oil sands
      OS = rowSums(select(., all_of(OIL_PRODS)), na.rm = TRUE),
      # Biofuels and renewable wastes
      RW = rowSums(select(., all_of(BIO_PRODS)), na.rm = TRUE),
      # Non-renewable wastes
      NRW = rowSums(select(., all_of(OTH_PRODS)), na.rm = TRUE),
      # Wind, solar, geothermal, etc.
      MR = rowSums(select(., all_of(OTH_REN)), na.rm = TRUE)
    ) %>%
    # keep only relevant columns
    select(
      -c(
        C0110,
        C0121,
        C0129,
        C0210,
        C0220,
        C0311,
        C0312,
        C0320,
        C0330,
        C0340,
        C0350,
        C0360,
        C0371,
        C0379,
        P1100,
        P1200,
        O4100_TOT,
        O4200,
        O4300,
        O4400X4410,
        O4500,
        O4610,
        O4620,
        O4630,
        O4640,
        O4651,
        O4652XR5210B,
        O4669,
        O4671XR5220B,
        O4653,
        O4661XR5230B,
        O4680,
        O4691,
        O4692,
        O4693,
        O4694,
        O4695,
        O4699,
        S2000,
        .data[["R5110-5150_W6000RI"]],
        R5160,
        R5210P,
        R5210B,
        R5220P,
        R5220B,
        R5230P,
        R5230B,
        R5290,
        R5300,
        W6210,
        W6100,
        W6220,
        RA200,
        RA300,
        RA410,
        RA420,
        RA500,
        RA600
      )
    ) %>%
    # rename to explicit names
    rename(
      "Coal" = "CPS",
      "Oil" = "OS",
      "Gas" = "G3000",
      "Biofuels and renewable wastes" = "RW",
      "Non-renewable wastes" = "NRW",
      "Nuclear" = "N900H",
      "Hydro" = "RA100",
      "Wind, solar, geothermal, etc." = "MR",
      "Heat" = "H8000",
      "Electricity" = "E7000"
    ) %>%
    # reshape to long
    pivot_longer(
      cols = -c(geo, time),
      names_to = "product",
      values_to = "energy_input"
    ) %>%
    mutate(product = factor(product, level = IDA_PRIMARY_PROD)) %>%
    group_by(geo, time) %>%
    mutate(share_energy_input = energy_input / sum(energy_input)) %>%
    ungroup()
}

prepare_energy_EHG_TJ <- function(
    nrg_bal_c,
    first_year,
    last_year,
    country_list) {
  nrg_bal_c %>%
    filter(
      # take only EU countries
      geo %in% country_list,
      # from 2010 onward
      time >= first_year,
      # do not take 2019 for now (economic data incomplete)
      time <= last_year,
      # take industry end uses
      nrg_bal %in% c(NRG_EHG_INPUT, NRG_EHG_OUTPUT),
      # work with total energy consumption, in TJ
      siec %in% c("TOTAL", "E7000", "H8000"),
      unit == "TJ"
    ) %>%
    # reshape to wide
    pivot_wider(
      names_from = siec,
      values_from = values
    ) %>%
    # create a fuel input category
    pivot_wider(
      names_from = nrg_bal,
      values_from = c(E7000, H8000, TOTAL)
    ) %>%
    # calculate available electricity, heat, and input for the electricity and heat generation
    rowwise() %>%
    mutate(
      # total electricity available (gross output - used for heat production)
      E7000_available =
        sum(
          # output from Main Ele
          E7000_TO_EHG_MAPE,
          # output from Main CHP
          E7000_TO_EHG_MAPCHP,
          # output from Auto Ele
          E7000_TO_EHG_APE,
          # output from Auto CHP
          E7000_TO_EHG_APCHP,
          # output from Pumping Hydro
          E7000_TO_EHG_PH,
          # output from Other sources
          E7000_TO_EHG_OTH,
          # electricity input to Heat pump-E7000_TI_EHG_EDHP,
          # electricity input to electric boilers-E7000_TI_EHG_EB,
          na.rm = TRUE
        ),

      # total heat available (gross output - used for electricity production)
      H8000_available =
        sum(
          # output from Main CHP
          H8000_TO_EHG_MAPCHP,
          # output from Main Heat
          H8000_TO_EHG_MAPH,
          # output from Auto CHP
          H8000_TO_EHG_APCHP,
          # output from Auto Heat
          H8000_TO_EHG_APH,
          # output from Heat pumps
          H8000_TO_EHG_EDHP,
          # output from Electric boilers
          H8000_TO_EHG_EB,
          # output from Other sources
          H8000_TO_EHG_OTH,
          # derived heat for electricity production-H8000_TI_EHG_DHEP,
          na.rm = TRUE
        ),

      # Transformation input to Electricity generation
      TI_EG =
        sum(
          # input to Main Ele
          TOTAL_TI_EHG_MAPE_E,
          # input to Main CHP...
          TOTAL_TI_EHG_MAPCHP_E *
            # ...muliplied by the ratio of Main CHP electricity output...
            E7000_TO_EHG_MAPCHP /
            # ...over total Main CHP output
            TOTAL_TO_EHG_MAPCHP,
          # input to Auto Ele
          TOTAL_TI_EHG_APE_E,
          # input to Auto CHP...
          TOTAL_TI_EHG_APCHP_E *
            # ...muliplied by the ratio of Auto CHP electricity output...
            E7000_TO_EHG_APCHP /
            # ...over total Auto CHP output
            TOTAL_TO_EHG_APCHP,
          # input to Hydro pumping
          E7000_TI_EHG_EPS,
          # derived heat for electricity production
          H8000_TI_EHG_DHEP,
          na.rm = TRUE
        ),

      # Transformation input to Heat generation
      TI_HG =
        sum(
          # input to Main CHP...
          TOTAL_TI_EHG_MAPCHP_E *
            # ...muliplied by the ratio of Main CHP heat output...
            H8000_TO_EHG_MAPCHP /
            # ...over total Main CHP output
            TOTAL_TO_EHG_MAPCHP,
          # input to Main Heat
          TOTAL_TI_EHG_MAPH_E,
          # input to Auto CHP...
          TOTAL_TI_EHG_APCHP_E *
            # ...muliplied by the ratio of Main CHP heat output...
            H8000_TO_EHG_APCHP /
            # ...over total Main CHP output
            TOTAL_TO_EHG_APCHP,
          # input to Auto Heat
          TOTAL_TI_EHG_APH_E,
          # electricity input to Heat pumps
          E7000_TI_EHG_EDHP,
          # electricity input to electric boilers
          E7000_TI_EHG_EB,
          na.rm = TRUE
        ),

      # divide the total electricity / Heat available by the total input of energy
      E7000_INPUT = TI_EG / E7000_available,
      H8000_INPUT = TI_HG / H8000_available
    ) %>%
    select(geo, time, E7000_INPUT, H8000_INPUT)
}

prepare_energy_consumption <- function(
    nrg_bal_c,
    energy_EHG_TJ,
    first_year,
    last_year,
    country_list) {
  prepare_industry_energy(
    nrg_bal_c,
    first_year = first_year,
    last_year = last_year,
    country_list = country_list
  ) %>%
    filter(siec != "TOTAL") %>%
    # reshape to long
    pivot_longer(
      cols = -c(geo, time, siec),
      names_to = "sector",
      values_to = "final_energy_consumption"
    ) %>%
    merge(energy_EHG_TJ,
      all = TRUE,
      by = c("geo", "time")
    ) %>%
    mutate(
      primary_energy_consumption =
        case_when(
          siec == "E7000" ~ final_energy_consumption * E7000_INPUT,
          siec == "H8000" ~ final_energy_consumption * H8000_INPUT,
          TRUE ~ final_energy_consumption
        )
    ) %>%
    group_by(geo, time, sector) %>%
    summarize(
      final_energy_consumption = sum(final_energy_consumption, na.rm = TRUE),
      primary_energy_consumption = sum(primary_energy_consumption, na.rm = TRUE),
      .groups = "drop_last"
    ) %>%
    ungroup()
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
        (GVA == 0 & final_energy_consumption > 0) ~ NA_real_,
        TRUE ~ GVA
      ),
      final_energy_consumption = case_when(
        (final_energy_consumption == 0 & GVA > 0) ~ NA_real_,
        TRUE ~ final_energy_consumption
      ),
      # intensity calculated here for the charts, will be recalculated later once the totals are included
      intensity = case_when(
        (GVA == 0 & final_energy_consumption > 0) ~ NA_real_,
        (GVA == 0 & final_energy_consumption == 0) ~ 0,
        TRUE ~ final_energy_consumption / GVA
      ),
      transformation = case_when(
        (primary_energy_consumption > 0 & final_energy_consumption == 0) ~ NA_real_,
        (primary_energy_consumption == 0 & final_energy_consumption == 0) ~ 0,
        TRUE ~ primary_energy_consumption / final_energy_consumption
      )
    ) %>%
    # For each country and each year
    group_by(geo, time) %>%
    mutate(
      # Calculate the total energy consumption and value added of the overall industry sector, as the sum of all subsectors selected
      total_final_energy_consumption = sum(final_energy_consumption, na.rm = TRUE),
      total_primary_energy_consumption = sum(primary_energy_consumption, na.rm = TRUE),
      total_GVA = sum(GVA, na.rm = TRUE)
    ) %>%
    ungroup() %>%
    # For each country, each year and each subsector
    mutate(
      # Calculate the share of the subsector in the overall energy consumption and in the overall value added of the industry sector
      share_final_energy_consumption = final_energy_consumption / total_final_energy_consumption,
      share_primary_energy_consumption = primary_energy_consumption / total_primary_energy_consumption,
      share_GVA = GVA / total_GVA
    )
}

filter_energy_consumption_activity <- function(
    df,
    first_year,
    last_year) {
  df <- df %>%
    rename(energy_consumption = final_energy_consumption) %>%
    filter_industry_GVA(
      first_year = first_year,
      last_year = last_year
    ) %>%
    rename(final_energy_consumption = energy_consumption)
}

add_share_sectors <- function(df) {
  df %>%
    # For each country and each year
    group_by(geo, time) %>%
    mutate(
      # Calculate the total energy consumption and value added of the overall industry sector, as the sum of all subsectors selected
      total_primary_energy_consumption = sum(primary_energy_consumption, na.rm = TRUE),
      total_final_energy_consumption = sum(final_energy_consumption, na.rm = TRUE),
      total_GVA = sum(GVA, na.rm = TRUE)
    ) %>%
    ungroup() %>%
    # For each country, each year and each subsector
    mutate(
      # Calculate the share of the subsector in the overall energy consumption and in the overall value added of the industry sector
      share_primary_energy_consumption = primary_energy_consumption / total_primary_energy_consumption,
      share_final_energy_consumption = final_energy_consumption / total_final_energy_consumption,
      share_GVA = GVA / total_GVA
    ) %>%
    # Remove the total columns, not required any longer
    select(-c(
      total_primary_energy_consumption,
      total_final_energy_consumption,
      total_GVA,
      intensity,
      transformation
    )) %>%
    ungroup()
}

add_total_sectors <- function(df) {
  df %>%
    group_by(geo, time) %>%
    summarize(
      GVA = sum(GVA, na.rm = TRUE),
      primary_energy_consumption = sum(primary_energy_consumption, na.rm = TRUE),
      final_energy_consumption = sum(final_energy_consumption, na.rm = TRUE),
      # the sum of shares should be one, calculated here for checking
      share_GVA = sum(share_GVA, na.rm = TRUE),
      share_primary_energy_consumption = sum(share_primary_energy_consumption, na.rm = TRUE),
      share_final_energy_consumption = sum(share_final_energy_consumption, na.rm = TRUE),
      .groups = "drop_last"
    ) %>%
    ungroup() %>%
    mutate(sector = "Total")
}

add_index_delta <- function(df) {
  df %>%
    # calculate intensity again, to include the total intensity
    mutate(
      intensity = case_when(
        (GVA == 0 & final_energy_consumption > 0) ~ NA_real_,
        (GVA == 0 & final_energy_consumption == 0) ~ 0,
        TRUE ~ final_energy_consumption / GVA
      ),
      transformation = case_when(
        (primary_energy_consumption > 0 & final_energy_consumption == 0) ~ NA_real_,
        (primary_energy_consumption == 0 & final_energy_consumption == 0) ~ 0,
        TRUE ~ primary_energy_consumption / final_energy_consumption
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
      # the weighting factor links the effect calculated on the indexed variation to the total energy consumption variation
      weighting_factor = ifelse(
        value_delta_primary_energy_consumption == 0,
        value_primary_energy_consumption,
        value_delta_primary_energy_consumption / log(value_indexed_primary_energy_consumption)
      ),
      # Apply natural logarithm to the indexed values for each sub sectors
      activity_log = ifelse(value_indexed_GVA == 0, 0, log(value_indexed_GVA)),
      structure_log = ifelse(value_indexed_share_GVA == 0, 0, log(value_indexed_share_GVA)),
      intensity_log = ifelse(value_indexed_intensity == 0, 0, log(value_indexed_intensity)),
      transformation_log = ifelse(value_indexed_transformation == 0, 0, log(value_indexed_transformation))
    ) %>%
    # Keep only the relevant columns
    select(
      geo,
      time,
      sector,
      weighting_factor,
      value_primary_energy_consumption,
      value_delta_primary_energy_consumption,
      activity_log,
      structure_log,
      intensity_log,
      transformation_log
    ) %>%
    # The baseline figures need to be expanded across all sub sectors, and across all years
    rowwise() %>%
    mutate(base_year = industry_GVA_base_year(country = .data[["geo"]], first_year = first_year)) %>%
    ungroup() %>%
    group_by(geo) %>%
    mutate(
      value_primary_energy_consumption_total_baseline = value_primary_energy_consumption[sector == "Total" & time == base_year]
    ) %>%
    ungroup() %>%
    # Similarly, the figures calculated for the total sector and the end figures need to be expanded across all subsectors
    group_by(geo, time) %>%
    mutate(
      activity_log_total = activity_log[sector == "Total"],
      value_delta_primary_energy_consumption_total = value_delta_primary_energy_consumption[sector == "Total"],
      value_primary_energy_consumption_total_end = value_primary_energy_consumption[sector == "Total"]
    ) %>%
    ungroup() %>%
    # Now the total sector is not required any longer
    filter(sector != "Total") %>%
    # Multiply the weighting factor * log(indexed subsectors), or weighting factor * log(indexed total sector)
    mutate(
      ACT = weighting_factor * activity_log_total,
      STR = weighting_factor * structure_log,
      INT = weighting_factor * intensity_log,
      MIX = weighting_factor * transformation_log,
    ) %>%
    # Remove unnecessary columns
    select(
      -c(
        weighting_factor,
        activity_log,
        activity_log_total,
        structure_log,
        intensity_log,
        transformation_log
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
      transformation_effect = sum(MIX), # na.rm = TRUE),
      # By keeping the mean figure when only one exist across all subsectors
      primary_energy_consumption_var_obs = mean(value_delta_primary_energy_consumption_total),
      value_primary_energy_consumption_total_baseline = mean(value_primary_energy_consumption_total_baseline),
      value_primary_energy_consumption_total_end = mean(value_primary_energy_consumption_total_end),
      .groups = "drop_last"
    ) %>%
    ungroup() %>%
    # For checking purposes, recalculate the total energy consumption calculated as the sum of the effects
    mutate(
      primary_energy_consumption_var_calc =
        rowSums(
          select(
            .,
            c(
              "activity_effect",
              "structural_effect",
              "intensity_effect",
              "transformation_effect"
            )
          ),
          # na.rm = TRUE
        )
    )
}

generate_country_charts <- function(
    industry_GVA_primary_complete,
    first_year,
    last_year,
    country_name,
    country_chart,
    output_path) {
  # Country data
  industry_GVA_primary_country_data <-
    industry_GVA_primary_complete %>%
    filter(
      geo == country_chart,
      time <= last_year
    ) %>%
    mutate(sector = factor(sector, levels = IDA_IND_SECTOR))

  # Table used to provide figures in the text of the report
  table_industry_GVA_primary_country_data <- industry_GVA_primary_country_data %>%
    mutate(
      GVA = round(GVA, 2),
      final_energy_consumption = round(final_energy_consumption, 2),
      primary_energy_consumption = round(primary_energy_consumption, 2),
      share_GVA = round(share_GVA, 2),
      share_final_energy_consumption = round(share_final_energy_consumption, 2),
      share_primary_energy_consumption = round(share_primary_energy_consumption, 2)
    )

  save_data(
    table_industry_GVA_primary_country_data,
    filename="Part2_sector.csv",
    output_path=output_path
  )

  # Primary energy consumption by subsector

  year <- as.Date(as.character(industry_GVA_primary_country_data$time), "%Y")

  p <- industry_GVA_primary_country_data %>%
    cbind(year) %>%
    select(-time) %>%
    mutate(year = lubridate::year(year)) %>%
    ggplot(aes(x = year, y = primary_energy_consumption / 1000)) +
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
    ggtitle(paste("Industry primary energy consumption by subsector for", country_name))

  print_chart(p,
    filename = paste0(country_chart, "_Figure10.jpg"),
    output_path = output_path,
    width = 2400,
    height = 2400,
    res = 300
  )

  # 2 years share

  p <- industry_GVA_primary_country_data %>%
    filter(time %in% c(first_year, last_year)) %>%
    mutate(sector = factor(sector, levels = IDA_IND_SECTOR)) %>%
    ggplot(aes(x = factor(time), y = share_primary_energy_consumption, fill = sector)) +
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
    geom_text(aes(label = paste0(round(share_primary_energy_consumption * 100, 0), "%")),
      position = position_stack(vjust = 0.5)
    ) +
    ylab(paste("Share of primary energy consumption")) +
    ggtitle(paste("Industry gross value added by subsector for", country_name))

  print_chart(p,
    filename = paste0(country_chart, "_Figure10B.jpg"),
    output_path = output_path,
    width = 2400,
    height = 2400,
    res = 300
  )

  # Sectoral efficiency comparison chart

  # Prepare data for the efficiency comparison chart
  industry_GVA_primary_efficiency_comparison_sector <-
    industry_GVA_primary_complete %>%
    mutate(sector = factor(sector, levels = IDA_IND_SECTOR)) %>%
    select(-c(
      final_energy_consumption,
      primary_energy_consumption,
      total_final_energy_consumption,
      total_primary_energy_consumption,
      share_final_energy_consumption,
      share_primary_energy_consumption,
      GVA,
      total_GVA,
      share_GVA,
      intensity
    )) %>%
    pivot_wider(names_from = geo, values_from = transformation)

  min_EU <-
    apply(
      select_if(
        industry_GVA_primary_efficiency_comparison_sector[, -1],
        is.numeric
      ),
      1,
      min,
      na.rm = TRUE
    )
  max_EU <-
    apply(
      select_if(
        industry_GVA_primary_efficiency_comparison_sector[, -1],
        is.numeric
      ),
      1,
      max,
      na.rm = TRUE
    )
  avg_EU <-
    apply(
      select_if(
        industry_GVA_primary_efficiency_comparison_sector[, -1],
        is.numeric
      ),
      1,
      mean,
      na.rm = TRUE
    )
  year <-
    as.Date(
      as.character(industry_GVA_primary_efficiency_comparison_sector$time),
      "%Y"
    )

  industry_GVA_primary_efficiency_comparison_sector <-
    industry_GVA_primary_efficiency_comparison_sector %>%
    cbind(min_EU) %>%
    cbind(max_EU) %>%
    cbind(avg_EU) %>%
    cbind(year) %>%
    select(c(sector, year, !!country_chart, min_EU, max_EU)) %>%
    mutate(year = lubridate::year(year))

  # Plot the efficiency comparison as line chart
  p <- industry_GVA_primary_efficiency_comparison_sector %>%
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
    ylab("Primary energy intensity (MJ / EUR") +
    scale_x_continuous(breaks = c(first_year, round((first_year + last_year) / 2), last_year)) +
    scale_y_continuous(labels = scales::number) +
    ggtitle(paste("Energy transformation efficiency in", country_name, "'s manufacturing industry compared to \nother European countries")) +
    facet_wrap(~sector, scales = "free", ncol = 3)

  print_chart(p,
    filename = paste0(country_chart, "_Figure13C.jpg"),
    output_path = output_path,
    width = 2400,
    height = 3200,
    res = 300
  )
}

generate_subsectors_charts <- function(
    industry_GVA_primary_full,
    country_chart,
    country_name,
    first_year_chart,
    last_year_chart,
    output_path) {
  # Chart indexed variation of total industry
  industry_GVA_primary_country_indexed <-
    industry_GVA_primary_full %>%
    filter(
      geo == country_chart,
      sector == "Total",
      time <= last_year_chart
    ) %>%
    select(-c(value, value_delta)) %>%
    pivot_wider(names_from = measure, values_from = value_indexed) %>%
    select(c(
      geo,
      time,
      intensity,
      transformation,
      primary_energy_consumption,
      GVA
    )) %>%
    rename(
      "Final energy intensity" = "intensity",
      "Primary to final energy transformation" = "transformation",
      "Primary energy consumption" = "primary_energy_consumption",
      "Gross Value Added" = "GVA"
    )

  year <- as.Date(as.character(industry_GVA_primary_country_indexed$time), "%Y")

  p <- industry_GVA_primary_country_indexed %>%
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
    scale_color_manual(values = IndustryGVAPrimaryColorsIndex) +
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
    ggtitle(paste("Indexed indicators for", country_name, "'s total industry energy consumption, \ngross value added and energy intensity variation, \nall years related to", as.character(first_year)))

  print_chart(p,
    filename = paste0(country_chart, "_Figure11B.jpg"),
    output_path = output_path,
    width = 2400,
    height = 2400,
    res = 300
  )

  # chart indexed variation by subsector
  industry_GVA_primary_transformation <- industry_GVA_primary_full %>%
    filter(
      geo == country_chart,
      sector != "Total",
      measure == "transformation",
      time <= last_year_chart
    )

  year <-
    as.Date(
      as.character(industry_GVA_primary_transformation$time),
      "%Y"
    )

  p <- industry_GVA_primary_transformation %>%
    cbind(year) %>%
    select(-time) %>%
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
    ggtitle(paste("Indexed variation for", country_name, "'s transformation in industry subsectors, \nall years related to", as.character(first_year)))

  print_chart(p,
    filename = paste0(country_chart, "_Figure11C.jpg"),
    output_path = output_path,
    width = 2400,
    height = 2400,
    res = 300
  )

  # Total intensity comparison chart

  # Total transformation comparison chart
  # prepare data for the intensity comparison chart
  industry_GVA_primary_transformation_comparison <-
    industry_GVA_primary_full %>%
    filter(
      sector == "Total",
      measure == "transformation"
    ) %>%
    select(-c(value_indexed, value_delta)) %>%
    pivot_wider(names_from = geo, values_from = value)

  min_EU <-
    apply(
      select_if(industry_GVA_primary_transformation_comparison[, -1], is.numeric),
      1,
      min
    )
  max_EU <-
    apply(
      select_if(industry_GVA_primary_transformation_comparison[, -1], is.numeric),
      1,
      max
    )
  avg_EU <-
    apply(
      select_if(industry_GVA_primary_transformation_comparison[, -1], is.numeric),
      1,
      mean
    )
  year <-
    as.Date(
      as.character(industry_GVA_primary_transformation_comparison$time),
      "%Y"
    )

  industry_GVA_primary_transformation_comparison <-
    industry_GVA_primary_transformation_comparison %>%
    cbind(min_EU) %>%
    cbind(max_EU) %>%
    cbind(avg_EU) %>%
    cbind(year) %>%
    select(c(year, !!country_chart, min_EU, max_EU)) %>%
    mutate(year = lubridate::year(year))

  # Plot the intensity comparison as line chart
  p <- industry_GVA_primary_transformation_comparison %>%
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
    ylab("Energy transformation efficiency") +
    scale_x_continuous(breaks = c(first_year, round((first_year + last_year) / 2), last_year)) +
    scale_y_continuous(labels = scales::number) +
    ggtitle(paste("Energy transformation efficiency in", country_name, "'s manufacturing industry compared to \nother European countries"))

  print_chart(p,
    filename = paste0(country_chart, "_Figure13B.jpg"),
    output_path = output_path,
    width = 2400,
    height = 2400,
    res = 300
  )
}

generate_ele_heat_share_primary_charts <- function(
    ele_heat_share_primary,
    country_chart,
    country_name,
    first_year,
    last_year,
    output_path) {
  # Table used to provide figures in the text of the report
  table_ele_heat_share_primary_filtered <- ele_heat_share_primary %>%
    filter(geo == country_chart) %>%
    mutate(share_EHG = round(share_EHG, 3))

  save_data(
    table_ele_heat_share_primary_filtered,
    filename="Part2_share.csv",
    output_path=output_path
  )
}


generate_input_ele_heat_production_charts <- function(
    ele_heat_input_breakdown,
    country_chart,
    country_name,
    first_year,
    last_year,
    output_path) {
  # Breakdown of energy consumption by fuel
  ele_heat_input_breakdown_filtered <- ele_heat_input_breakdown %>%
    filter(
      geo == country_chart,
      !energy_input == 0
    )

  table_ele_heat_input_breakdown_filtered <- ele_heat_input_breakdown_filtered %>%
    mutate(
      energy_input = round(energy_input, 1),
      share_energy_input = round(share_energy_input, 3)
    )

  save_data(
    table_ele_heat_input_breakdown_filtered,
    filename="Part2_fuel.csv",
    output_path=output_path
  )

  # Breakdown of electricity and heat input by fuel

  year <-
    as.Date(
      as.character(ele_heat_input_breakdown_filtered$time),
      "%Y"
    )

  p <- ele_heat_input_breakdown_filtered %>%
    cbind(year) %>%
    select(-time) %>%
    mutate(year = lubridate::year(year)) %>%
    # filter(!product %in% c("Nuclear", "Hydro", "Wind, solar, geothermal, etc.")) %>%
    ggplot(aes(x = year, y = energy_input / 1000)) +
    geom_bar(aes(fill = product), stat = "identity") +
    scale_fill_manual(values = PrimaryProductsColors, limits = force) +
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
    ylab(paste("Energy input to electricity and heat production (PJ)")) +
    ggtitle(paste("Electricity and heat input by fuel for", country_name))

  print_chart(p,
    filename = paste0(country_chart, "_Figure09.jpg"),
    output_path = output_path,
    width = 2400,
    height = 2400,
    res = 300
  )

  # 2 years

  p <- ele_heat_input_breakdown_filtered %>%
    filter(time %in% c(first_year, last_year)) %>%
    ggplot(aes(x = factor(time), y = share_energy_input, fill = product)) +
    geom_bar(position = "fill", stat = "identity") +
    scale_fill_manual(values = PrimaryProductsColors, limits = force) +
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
    geom_text(aes(label = paste0(round(share_energy_input * 100, 0), "%")),
      position = position_stack(vjust = 0.5)
    ) +
    ylab(paste("Share in energy input to electricity and heat production ")) +
    ggtitle(paste("Industry energy consumption by fuel for", country_name))

  print_chart(p,
    filename = paste0(country_chart, "_Figure09B.jpg"),
    output_path = output_path,
    width = 2400,
    height = 2400,
    res = 300
  )
}

generate_ele_heat_consumption_breakdown_charts <- function(
    energy_EHG_TJ,
    country_chart,
    country_name,
    first_year,
    last_year,
    output_path) {
  # input for electricity and heat chart
  electricity_input_comparison <- energy_EHG_TJ %>%
    select(c(geo, time, E7000_INPUT)) %>%
    pivot_wider(names_from = geo, values_from = E7000_INPUT)

  min_EU <-
    apply(select_if(electricity_input_comparison[, -1], is.numeric),
      1,
      min,
      na.rm = TRUE
    )
  max_EU <-
    apply(select_if(electricity_input_comparison[, -1], is.numeric),
      1,
      max,
      na.rm = TRUE
    )
  avg_EU <-
    apply(select_if(electricity_input_comparison[, -1], is.numeric),
      1,
      mean,
      na.rm = TRUE
    )
  year <-
    as.Date(as.character(electricity_input_comparison$time), "%Y")

  electricity_input_comparison_full <- electricity_input_comparison %>%
    cbind(min_EU) %>%
    cbind(max_EU) %>%
    cbind(avg_EU) %>%
    cbind(year) %>%
    mutate(transformation = "electricity") %>%
    select(c(year, transformation, !!country_chart, avg_EU, min_EU, max_EU)) %>%
    mutate(year = lubridate::year(year))

  heat_input_comparison <- energy_EHG_TJ %>%
    select(c(geo, time, H8000_INPUT)) %>%
    pivot_wider(names_from = geo, values_from = H8000_INPUT)

  min_EU <-
    apply(select_if(heat_input_comparison[, -1], is.numeric), 1, min,
      na.rm =
        TRUE
    )
  max_EU <-
    apply(select_if(heat_input_comparison[, -1], is.numeric), 1, max,
      na.rm =
        TRUE
    )
  avg_EU <-
    apply(select_if(heat_input_comparison[, -1], is.numeric), 1, mean,
      na.rm =
        TRUE
    )
  year <- as.Date(as.character(heat_input_comparison$time), "%Y")

  heat_input_comparison_full <- heat_input_comparison %>%
    cbind(min_EU) %>%
    cbind(max_EU) %>%
    cbind(avg_EU) %>%
    cbind(year) %>%
    mutate(transformation = "heat") %>%
    select(c(year, transformation, !!country_chart, avg_EU, min_EU, max_EU)) %>%
    mutate(year = lubridate::year(year))

  ele_heat_comparison <- electricity_input_comparison_full %>%
    rbind(heat_input_comparison_full)

  # Plot the intensity comparison as line chart
  p <- ele_heat_comparison %>%
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
    ylab("Energy input (TJ input / TJ output)") +
    scale_x_continuous(breaks = c(first_year, round((first_year + last_year) / 2), last_year)) +
    # scale_y_continuous(labels = scales::number) +
    expand_limits(y = 0) +
    scale_y_continuous(breaks = scales::breaks_extended(Q = c(0, 1, 2, 3))) +
    ggtitle(paste("Energy input for electricity and heat in", country_name, "compared to other European countries")) +
    facet_wrap(~transformation)

  print_chart(p,
    filename = paste0(country_chart, "_Figure13.jpg"),
    output_path = output_path,
    width = 2400,
    height = 2400,
    res = 300
  )
}

generate_primary_effects_charts <- function(
    industry_GVA_primary_LMDI,
    country_chart,
    country_name,
    first_year,
    last_year,
    first_year_chart,
    last_year_chart,
    output_path) {
  # prepare data for the simple effect chart
  industry_GVA_primary_effects <- industry_GVA_primary_LMDI %>%
    filter(
      geo == country_chart,
      time <= last_year_chart
    ) %>%
    rename(
      "Activity" = "activity_effect",
      "Intensity" = "intensity_effect",
      "Structure" = "structural_effect",
      "Transformation" = "transformation_effect"
    ) %>%
    pivot_longer(
      cols = -c(geo, time),
      names_to = "Effect",
      values_to = "value"
    ) %>%
    filter(
      Effect == "Activity" |
        Effect == "Structure" |
        Effect == "Intensity" |
        Effect == "Transformation"
    )

  industry_GVA_primary_results <- industry_GVA_primary_LMDI %>%
    filter(
      geo == country_chart,
      time <= last_year_chart
    ) %>%
    pivot_longer(
      cols = -c(geo, time),
      names_to = "measure",
      values_to = "value"
    ) %>%
    filter(measure == "primary_energy_consumption_var_obs")

  # Plot the simple effect as bar chart
  p <- ggplot(
    data = industry_GVA_primary_effects,
    aes(
      x = factor(time),
      y = value / 1000
    )
  ) +
    geom_bar(aes(fill = Effect),
      stat = "identity"
    ) +
    scale_fill_manual(values = IndustryGVAPrimaryColorsEffect) +
    geom_point(
      data = industry_GVA_primary_results,
      aes(y = value / 1000),
      size = 3
    ) +
    theme_classic() +
    theme(
      axis.title.x = element_blank(),
      text = element_text(size = 15)
    ) +
    scale_y_continuous(labels = scales::number) +
    ylab("Primary energy consumption variation (PJ)") +
    ggtitle(paste("Decompostion analysis of", country_name, "'s industry primary energy consumption variation, \n  all years related to", as.character(first_year)))

  print_chart(p,
    filename = paste0(country_chart, "_Figure11D.jpg"),
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
    "Transformation",
    Result_label
  )

  # prepare data for the waterfall chart (see plotly waterfall for explanations)
  industry_GVA_primary_Waterfall_data <-
    industry_GVA_primary_LMDI %>%
    filter(
      geo == country_chart,
      time == last_year_chart
    ) %>%
    rename(
      "Activity" = "activity_effect",
      "Intensity" = "intensity_effect",
      "Structure" = "structural_effect",
      "Transformation" = "transformation_effect",
      !!Base_label := "value_primary_energy_consumption_total_baseline"
    ) %>%
    select(
      !!Base_label,
      "Activity",
      "Structure",
      "Intensity",
      "Transformation"
    ) %>%
    pivot_longer(
      cols = everything(),
      names_to = "x",
      values_to = "y"
    ) %>%
    mutate(x = factor(x, level = levels_waterfall)) %>%
    mutate(text = paste(as.character(round(y, 2)), "TJ", sep = " ")) %>%
    mutate(measure = case_when(
      (x == !!Result_label) ~ "total",
      TRUE ~ "relative"
    ))

  p <- industry_GVA_primary_Waterfall_data %>%
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
    filename = paste0(country_chart, "_Figure11.jpg"),
    output_path = output_path,
    width = 2400,
    height = 1600,
    res = 300
  )

  # Intensity and transformation effect chart

  # Prepare data for the intensity effect chart
  industry_GVA_primary_intensity_effect <-
    industry_GVA_primary_LMDI %>%
    filter(
      geo == country_chart,
      time >= first_year,
      time <= last_year
    ) %>%
    select(
      geo,
      time,
      value_primary_energy_consumption_total_end,
      intensity_effect,
      transformation_effect
    ) %>%
    mutate(
      "Without intensity and transformation effect" = value_primary_energy_consumption_total_end - intensity_effect - transformation_effect
    ) %>%
    rename("Actual primary energy consumption" = value_primary_energy_consumption_total_end) %>%
    select(-c(intensity_effect, transformation_effect)) %>%
    pivot_longer(
      cols = -c(geo, time),
      names_to = "measure",
      values_to = "value"
    ) %>%
    mutate(measure = factor(
      measure,
      levels = c(
        "Without intensity and transformation effect",
        "Actual primary energy consumption"
      )
    )) %>%
    arrange(measure)

  # Plot the intensity effect as area chart
  p <- industry_GVA_primary_intensity_effect %>%
    ggplot() +
    geom_bar(
      data = (industry_GVA_primary_intensity_effect %>%
        filter(measure == "Actual primary energy consumption")),
      aes(
        y = value / 1000,
        x = time,
        fill = measure
      ),
      stat = "identity",
      alpha = 0.5
    ) +
    scale_fill_manual(values = c("Actual primary energy consumption" = "blue4")) +
    geom_point(
      data = (industry_GVA_primary_intensity_effect %>%
        filter(
          measure == "Without intensity and transformation effect",
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
    scale_color_manual(values = c("Without intensity and transformation effect" = "green4")) +
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
    ylab("Primary energy consumption (PJ)") +
    expand_limits(y = 0) +
    ggtitle(paste("Actual primary energy consumption in the industry vs theoretical \n(without energy intensity and transformation improvements) for", country_name))

  print_chart(p,
    filename = paste0(country_chart, "_Figure12.jpg"),
    output_path = output_path,
    width = 2400,
    height = 2400,
    res = 300
  )
}

generate_coverage_chart <- function(
    industry_GVA_primary_complete,
    last_year_chart,
    output_path) {
  # Data coverage chart
  p <- industry_GVA_primary_complete %>%
    filter(
      sector != "Total",
      geo != "EU27",
      time <= last_year_chart
    ) %>%
    select(c("geo", "time", "sector", "primary_energy_consumption", "GVA")) %>%
    replace(is.na(.), 0) %>%
    mutate(
      missing =
        case_when(
          (primary_energy_consumption > 0 & GVA > 0) |
            (primary_energy_consumption == 0 & GVA == 0) ~ 0,
          TRUE ~ 1
        )
    ) %>%
    select(-c("primary_energy_consumption", "GVA")) %>%
    group_by(geo, time) %>%
    summarize(
      missing = sum(missing),
      .groups = "drop_last") %>%
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
    ggtitle("Completeness of coverage (energy and activity data) for European countries across years")

  print_chart(p,
    filename = "EU27_Figure13D.jpg",
    output_path = output_path,
    width = 2400,
    height = 3200,
    res = 300
  )
}

generate_eu_comparison_chart <- function(
    energy_EHG_TJ,
    first_year_chart,
    last_year_chart,
    output_path) {
  # Prepare the data
  EU_comparison <- energy_EHG_TJ %>%
    filter(
      time %in% c(first_year_chart, last_year_chart),
      geo != "EU27"
    ) %>%
    merge(eu_countries, by.x = "geo", by.y = "code") %>%
    select(-c("geo", "label")) %>%
    pivot_longer(
      cols = c("E7000_INPUT", "H8000_INPUT"),
      names_to = "measure",
      values_to = "value"
    )

  # Rank the countries by intensity on last year
  country_ranked_ELE <- EU_comparison %>%
    filter(
      time == last_year_chart,
      measure == "E7000_INPUT"
    ) %>%
    arrange(value) %>%
    pull(name)

  # Rank the countries by intensity on last year
  country_ranked_HEAT <- EU_comparison %>%
    filter(
      time == last_year_chart,
      measure == "H8000_INPUT"
    ) %>%
    arrange(value) %>%
    pull(name)

  # Electricity charts
  electricity_chart <- EU_comparison %>%
    filter(measure == "E7000_INPUT") %>%
    ggplot(aes(
      x = factor(name, levels = country_ranked_ELE),
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
    ylab("Energy input (TJ input / TJ output)") +
    ggtitle(paste("Energy input for electricity in European countries"))

  # Heat charts
  heat_chart <- EU_comparison %>%
    filter(measure == "H8000_INPUT") %>%
    ggplot(aes(
      x = factor(name, levels = country_ranked_HEAT),
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
    ylab("Energy input (TJ input / TJ output)") +
    ggtitle(paste("Energy input for heat in European countries"))

  p <- ggarrange(
    electricity_chart,
    heat_chart,
    ncol = 2,
    nrow = 1,
    labels = c("Electricity", "Heat"),
    label.x = 0.5,
    align = "hv",
    common.legend = TRUE,
    legend = "bottom"
  )

  print_chart(p,
    filename = "EU27_Figure13E.jpg",
    output_path = output_path,
    width = 2400,
    height = 3200,
    res = 300
  )
}