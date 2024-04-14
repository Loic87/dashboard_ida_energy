library(ggplot2)

script_directory <- dirname(rstudioapi::getActiveDocumentContext()$path)
setwd(file.path(script_directory))
print(getwd())

source("0_support/mapping_countries.R")
source("0_support/shared_functions.R")
source("1_industry/1a_industry_gva_final.R")

first_year = 1990
last_year = 2020
country = "Belgium"

nrg_bal_c = load_industry_energy_consumption(country_test)
nama_10_a64 = load_industry_GVA(country_test)

industry_GVA <- prepare_activity(
  nama_10_a64 = nama_10_a64,
  first_year = first_year_test,
  last_year = last_year_test
)

# energy consumption (and supply) from the energy balance (nrg_bal_c)
industry_energy_final <- prepare_energy_consumption(
    nrg_bal_c = nrg_bal_c,
    first_year = first_year_test,
    last_year = last_year_test
  )

industry_GVA_final_full <- prepare_decomposition(
  industry_GVA,
  industry_energy_final,
  first_year = first_year_test,
  last_year = last_year_test
  )

industry_GVA_final_LMDI <- apply_LMDI(
  industry_GVA_final_full,
  first_year = first_year_test
)

industry_GVA_final_waterfall_chart <- prepare_waterfall_chart(
    industry_GVA_final_LMDI,
    first_year = first_year_test,
    last_year = last_year_test,
    country = country_test
  )
plot(industry_GVA_final_waterfall_chart)

