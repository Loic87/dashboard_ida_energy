script_directory <- dirname(rstudioapi::getActiveDocumentContext()$path)
setwd(file.path(script_directory))
print(getwd())
source("4_all_sectors/shared.R")

nrg_bal_c = read_feather(
  paste0("../data/nrg_bal_c_BE.feather")
)
first_year = 1960
last_year = 2022
country = "Belgique"


energy_product_breakdown <- prepare_energy_product_breakdown(
  nrg_bal_c,
  first_year,
  last_year
)

ggplot(energy_product_breakdown, aes(x = time, y = energy_consumption / 1000)) +
  geom_bar(aes(fill = product), stat = "identity") +
  scale_fill_manual(values = FinalProductsColors, limits = force) +
  theme_classic() +
  theme(axis.title.x = element_blank()) +
  scale_y_continuous(labels = scales::number) +
  ylab(paste("Energy consumption (PJ)")) +
  ggtitle(paste("Industry energy consumption by fuel for", country))
