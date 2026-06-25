library(ggplot2)
library(here)  # For portable path resolution

# Source all required files using here for portable paths
source(here("scripts", "0_support", "mapping_countries.R"))
source(here("scripts", "0_support", "data_load.R"))
source(here("scripts", "0_support", "mapping_years.R"))
source(here("scripts", "1_industry", "1a_industry_gva_final.R"))
source(here("scripts", "3_transport", "transport_VKM.R"))

first_year_test = 1990
last_year_test = 2023
country_test = "Belgium"

nrg_bal_c = load_industry_energy_consumption(country_test)
nama_10_a64 = load_industry_GVA(country_test)
road_tf_vehmov = load_road_vkm(country_test)
rail_tf_trainmv = load_rail_vkm(country_test)
iww_tf_vetf = load_iwww_vkm(country_test)


industry_energy_consumption_by_product <- prepare_industry_energy_consumption_by_product(
    nrg_bal_c = nrg_bal_c,
    first_year = first_year_test,
    last_year = country_test
  )

## Industry energy consumption by sector
industry_energy_consumption_by_sector <- prepare_industry_energy_consumption_by_sector(
    nrg_bal_c = nrg_bal_c,
    first_year = first_year_test,
    last_year = last_year_test
  )

## Industry economic activity (GVA) by sector
industry_GVA_by_sector <- prepare_industry_GVA_by_sector(
    nama_10_a64 = nama_10_a64,
    first_year = first_year_test,
    last_year = last_year_test
  )

## Show warnings
print(industry_GVA_by_sector$notifications)

years_with_data <- get_years_with_data(
  activity_df = industry_GVA_by_sector$df,
  activity_col = "GVA",
  energy_df = industry_energy_consumption_by_sector,
  energy_col = "energy_consumption",
  first_year = first_year_test,
  last_year = last_year_test
)

first_year_with_data <- years_with_data[[1]]
last_year_with_data <- years_with_data[[2]]

## Industry GVA decomposition
industry_GVA_final_full <- prepare_industry_GVA_decomposition(
    industry_GVA_by_sector$df,
    industry_energy_consumption_by_sector,
    first_year = first_year_with_data,
    last_year = last_year_with_data
  )

## Show warnings
print(industry_GVA_final_full$notifications)


industry_GVA <- industry_GVA_by_sector$df
industry_energy_final <- industry_energy_consumption_by_sector
first_year <- first_year_test
last_year <- last_year_test

transport_VKM_by_mode <- prepare_transport_vkm(
  road_tf_vehmov = road_tf_vehmov,
  rail_tf_trainmv = rail_tf_trainmv,
  iww_tf_vetf = iww_tf_vetf,
  first_year = first_year_test,
  last_year = last_year_test
)

# energy consumption (and supply) from the energy balance (nrg_bal_c)
transport_energy_consumption_by_mode <- prepare_transport_energy_consumption_by_mode(
    nrg_bal_c = nrg_bal_c,
    first_year = first_year_test,
    last_year = last_year_test
  )



transport_VKM_years_with_data <- get_years_with_data(
  activity_df = transport_VKM_by_mode$df,
  activity_col = "VKM",
  energy_df = transport_energy_consumption_by_mode,
  energy_col = "energy_consumption",
  first_year = first_year_test,
  last_year = last_year_test
)

transport_VKM_first_year_with_data <- transport_VKM_years_with_data[[1]]
transport_VKM_last_year_with_data <- transport_VKM_years_with_data[[2]]

## Transport energy consumption by fuel
transport_energy_consumption_by_product <- prepare_transport_energy_consumption_by_product(
    nrg_bal_c = nrg_bal_c,
    first_year = transport_VKM_first_year_with_data,
    last_year = transport_VKM_last_year_with_data
  )

transport_energy_consumption_by_product_plot <- prepare_transport_energy_consumption_by_product_charts(
    transport_energy_consumption_by_product,
    country_test
  )

transport_VKM_by_mode_plot <- prepare_transport_VKM_by_mode_charts(
  transport_VKM,
  country_test
  )

transport_VKM_full <- prepare_transport_vkm_decomposition(
  transport_energy_consumption_by_mode,
  transport_VKM,
  first_year = transport_VKM_first_year_with_data,
  last_year = transport_VKM_last_year_with_data
  )

transport_VKM_indexed_plot <- prepare_transport_indexed_chart(
  transport_VKM_full$df,
  first_year = transport_VKM_first_year_with_data,
  country = country_test
)

warnings <- transport_VKM_full$notifications

transport_VKM_final_LMDI <- apply_LMDI_transport_vkm(
  transport_VKM_full$df,
  first_year = transport_VKM_first_year_with_data
)

transport_waterfall_chart <- prepare_transport_waterfall_chart(
  transport_VKM_final_LMDI,
  first_year = transport_VKM_first_year_with_data,
  last_year = transport_VKM_last_year_with_data,
  country = country_test
)
plot(transport_waterfall_chart)

