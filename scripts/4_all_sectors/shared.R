# FUNCTIONS CALLED BY DIFFERENT PROCESSES
library(futile.logger)

reverse_negative_gva <- function(df) {
  for (i in 1:nrow(df)) {
    if (!is.na(df$GVA[i]) && df$GVA[i] < 0) {
      df$GVA[i] <- -df$GVA[i]
      flog.warn(paste("Country:", df$geo[i], ", Sector:", df$sector[i], ", Year:", df$time[i], " - ", "negative GVA reversed"))
    }
  }
  return(df)
}

filter_industry_GVA <- function(
    df,
    first_year,
    last_year) {
  unique_countries <- unique(df$geo)
  unique_sectors <- unique(df$sector)

  for (country in unique_countries) {
    first_year_shown <- industry_GVA_base_year(country = country, first_year = first_year)
    last_year_shown <- industry_GVA_last_year(country = country, final_year = last_year)
    for (sector in unique_sectors) {
      subset_df <- df[
        df$geo == country &
          df$sector == sector &
          df$time <= last_year_shown &
          df$time >= first_year_shown,
      ]
      if (any(is.na(subset_df$GVA) | subset_df$GVA == 0)) {
        missing_years <- subset_df$time[is.na(subset_df$GVA) | subset_df$GVA == 0]
        df <- df[!(df$geo == country & df$sector == sector), ]
        flog.warn(
          paste(
            "Country:", country, ", Sector:", sector,
            "- removed (missing GVA in years:",
            paste(missing_years, collapse = ", "), ")"
          )
        )
      } else if (any((is.na(subset_df$energy_consumption) | subset_df$energy_consumption == 0) & (!is.na(subset_df$GVA) & subset_df$GVA != 0))) {
        missing_years <- subset_df$time[is.na(subset_df$energy_consumption) | subset_df$energy_consumption == 0]
        df <- df[!(df$geo == country & df$sector == sector), ]
        flog.warn(
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

prepare_energy_product_breakdown <- function(
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
      # work with total energy consumption, in TJ
      siec %in% NRG_PRODS,
      unit == "TJ"
    ) %>%
    group_by(geo, time, siec) %>%
    summarise(values = sum(values, na.rm = TRUE), .groups = "drop_last") %>%
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
      values_to = "energy_consumption"
    ) %>%
    mutate(product = factor(product, level = IDA_FINAL_PROD)) %>%
    group_by(geo, time) %>%
    mutate(share_energy_consumption = energy_consumption / sum(energy_consumption)) %>%
    ungroup()
}

prepare_industry_GVA <- function(
    nama_10_a64,
    first_year,
    last_year,
    country_list) {
  nama_10_a64 %>%
    filter(
      geo %in% country_list,
      # from first year
      time >= first_year,
      # to last year
      time <= last_year,
      # take industry sub sectors
      nace_r2 %in% GVA_IND_SECTORS,
      # Gross Value Added in Chain linked volumes (2015), million euro
      na_item == "B1G",
      unit == "CLV15_MEUR"
    ) %>%
    select(c("geo", "time", "nace_r2", "values")) %>%
    # reshape to wide
    pivot_wider(
      names_from = nace_r2,
      values_from = values
    ) %>%
    # aggregate
    mutate(
      # Paper
      "C17-C18" = rowSums(select(., c("C17", "C18")), na.rm = TRUE),
      # Chem and petchem
      "C20-C21" = rowSums(select(., c("C20", "C21")), na.rm = TRUE),
      # Non-metallic minerals
      "C22-C23" = rowSums(select(., c("C22", "C23")), na.rm = TRUE),
      # Machinery
      "C25-C28" = rowSums(select(., c("C25", "C26", "C27", "C28")), na.rm = TRUE),
      # Transport equipment
      "C29-C30" = rowSums(select(., c("C29", "C30")), na.rm = TRUE)
    ) %>%
    # keep only relevant columns
    select(-c(C17, C18, C20, C21, C22, C23, C25, C26, C27, C28, C29, C30)) %>%
    # Rename to explicit names
    rename(
      "Construction" = "F",
      "Mining and quarrying" = "B",
      # "Food, beverages and tobacco" = "C10-C12",
      "Food, bev. and tobacco" = "C10-C12",
      "Textile and leather" = "C13-C15",
      "Wood and wood products" = "C16",
      "Paper, pulp and printing" = "C17-C18",
      # "Coke and refined petroleum products" = "C19",
      "Coke and ref. pet. products" = "C19",
      # "Chemical and petrochemical" = "C20-C21",
      "Chemical and petrochem." = "C20-C21",
      "Non-metallic minerals" = "C22-C23",
      "Basic metals" = "C24",
      "Machinery" = "C25-C28",
      "Transport equipment" = "C29-C30",
      "Other manufacturing" = "C31_C32"
    ) %>%
    # Reshape to long
    pivot_longer(
      cols = -c(geo, time),
      names_to = "sector",
      values_to = "GVA"
    )
}

prepare_industry_energy <- function(
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
      # take industry end uses
      nrg_bal %in% NRG_IND_SECTORS,
      # work with total energy consumption, in TJ
      siec %in% c(NRG_PRODS, "TOTAL"),
      unit == "TJ"
    ) %>%
    select(-c(unit)) %>%
    # reshape to wide
    pivot_wider(
      names_from = nrg_bal,
      values_from = values
    ) %>%
    replace(is.na(.), 0) %>%
    # aggregate
    mutate(
      # basic metals
      FC_MBM = rowSums(
        select(., c(
          "FC_IND_IS_E",
          "NRG_CO_E",
          "NRG_BF_E",
          "FC_IND_NFM_E"
        )),
        na.rm = TRUE
      ),
      # mining and quarrying
      FC_MQ = rowSums(
        select(., c(
          "FC_IND_MQ_E",
          "NRG_CM_E",
          "NRG_OIL_NG_E"
        )),
        na.rm = TRUE
      ),
      # other manufacturing
      FC_NSP = rowSums(
        select(., c(
          "NRG_PF_E",
          "NRG_BKBPB_E",
          "NRG_CL_E",
          "NRG_GTL_E",
          "NRG_CPP_E",
          "NRG_NSP_E",
          "FC_IND_NSP_E"
        )),
        na.rm = TRUE
      )
    ) %>%
    # keep only relevant columns
    select(
      -c(
        FC_IND_IS_E,
        NRG_CO_E,
        NRG_BF_E,
        FC_IND_NFM_E,
        FC_IND_MQ_E,
        NRG_CM_E,
        NRG_OIL_NG_E,
        NRG_PF_E,
        NRG_BKBPB_E,
        NRG_CL_E,
        NRG_GTL_E,
        NRG_CPP_E,
        NRG_NSP_E,
        FC_IND_NSP_E
      )
    ) %>%
    # rename to explicit names
    rename(
      "Construction" = "FC_IND_CON_E",
      "Mining and quarrying" = "FC_MQ",
      # "Food, beverages and tobacco" = "FC_IND_FBT_E",
      "Food, bev. and tobacco" = "FC_IND_FBT_E",
      "Textile and leather" = "FC_IND_TL_E",
      "Wood and wood products" = "FC_IND_WP_E",
      "Paper, pulp and printing" = "FC_IND_PPP_E",
      # "Coke and refined petroleum products" = "NRG_PR_E",
      "Coke and ref. pet. products" = "NRG_PR_E",
      # "Chemical and petrochemical" = "FC_IND_CPC_E",
      "Chemical and petrochem." = "FC_IND_CPC_E",
      "Non-metallic minerals" = "FC_IND_NMM_E",
      "Basic metals" = "FC_MBM",
      "Machinery" = "FC_IND_MAC_E",
      "Transport equipment" = "FC_IND_TE_E",
      "Other manufacturing" = "FC_NSP"
    )
}