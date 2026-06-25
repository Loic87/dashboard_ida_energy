library(RColorBrewer)

IndustryGVAColorsIndex <- c(
  "Energy consumption" = "blue4",
  "Gross Value Added" = "red4",
  "Energy intensity" = "green4"
)

IndustryGVAPrimaryColorsIndex <- c(
  "Primary energy consumption" = "blue4",
  "Gross Value Added" = "red4",
  "Final energy intensity" = "green4",
  "Primary to final energy transformation" = "yellow4"
)

EconomyEmploymentColorsIndex <- c(
  "Energy consumption" = "blue4",
  "Employment" = "red4",
  "Energy consumption per employee" = "green4"
)

HouseholdColorsIndex <- c(
  "Energy consumption" = "blue4",
  "Population" = "red4",
  "Dwelling per capita" = "purple4",
  "Energy per dwelling" = "green4",
  "Weather" = "yellow4"
)

TransportColorsIndex <- c(
  "Energy consumption" = "blue4",
  "Traffic" = "red4",
  "Energy intensity" = "green4"
)

IndustryGVAColorsEffect <- c(
  "Activity" = "red4",
  "Intensity" = "green4",
  "Structure" = "purple4"
)

IndustryGVAPrimaryColorsEffect <- c(
  "Activity" = "red4",
  "Intensity" = "green4",
  "Structure" = "purple4",
  "Transformation" = "yellow4"
)

EconomyEmploymentColorsEffect <- c(
  "Activity" = "red4",
  "Intensity" = "green4",
  "Structure" = "purple4"
)

AllSectorsColors <- c(
  # "Agriculture, forestry and fishing" = brewer.pal(5, "Set3")[1],
  "Agricult., forest. and fish." = brewer.pal(7, "Set3")[3],
  "Manufacturing" = brewer.pal(7, "Set3")[2],
  "Construction" = brewer.pal(7, "Set3")[1],
  "Other industries" = brewer.pal(7, "Set3")[4],
  # "Commercial and public services" = brewer.pal(5, "Set3")[5]
  "Comm. and pub. services" = brewer.pal(7, "Set3")[5],
  "Residential" = brewer.pal(7, "Set3")[7],
  "Transport" = brewer.pal(7, "Set3")[6]
)

HouseholdColorsEffect <- c(
  "Population" = "red4",
  "Energy per dwelling" = "green4",
  "Dwelling per capita" = "purple4",
  "Weather" = "yellow4"
)

TransportColorsEffect <- c(
  "Activity" = "red4",
  "Intensity" = "green4",
  "Structure" = "purple4"
)

ManufacturingSectorsColors <- c(
  "Construction" = brewer.pal(12, "Set3")[1],
  "Mining and quarrying" = brewer.pal(12, "Set3")[2],
  # "Food, beverages and tobacco" = brewer.pal(12, "Set3")[3],
  "Food, bev. and tobacco" = brewer.pal(12, "Set3")[3],
  "Textile and leather" = brewer.pal(12, "Set3")[4],
  "Wood and wood products" = brewer.pal(12, "Set3")[5],
  "Paper, pulp and printing" = brewer.pal(12, "Set3")[6],
  # "Coke and refined petroleum products" = brewer.pal(12, "Set3")[7],
  "Coke and ref. pet. products" = brewer.pal(12, "Set3")[7],
  # "Chemical and petrochemical" = brewer.pal(12, "Set3")[8],
  "Chemical and petrochem." = brewer.pal(12, "Set3")[8],
  "Non-metallic minerals" = brewer.pal(12, "Set3")[9],
  "Basic metals" = brewer.pal(12, "Set3")[10],
  "Machinery" = brewer.pal(12, "Set3")[11],
  "Transport equipment" = brewer.pal(12, "Set3")[12],
  "Other manufacturing" = "grey"
)

EconomySectorsColors <- c(
  # "Agriculture, forestry and fishing" = brewer.pal(5, "Set3")[1],
  "Agricult., forest. and fish." = brewer.pal(5, "Set3")[3],
  "Manufacturing" = brewer.pal(5, "Set3")[2],
  "Construction" = brewer.pal(5, "Set3")[1],
  "Other industries" = brewer.pal(5, "Set3")[4],
  # "Commercial and public services" = brewer.pal(5, "Set3")[5]
  "Comm. and pub. services" = brewer.pal(5, "Set3")[5]
)

FinalProductsColors <- c(
  "Coal" = brewer.pal(10, "Set3")[10],
  "Oil" = brewer.pal(10, "Set3")[6],
  "Gas" = brewer.pal(10, "Set3")[8],
  "Biofuels and renewable wastes" = brewer.pal(10, "Set3")[7],
  "Non-renewable wastes" = brewer.pal(10, "Set3")[9],
  #    "Nuclear" = brewer.pal(10, "Set3")[2],
  #    "Hydro" = brewer.pal(10, "Set3")[5],
  "Wind, solar, geothermal, etc." = brewer.pal(10, "Set3")[1],
  "Heat" = brewer.pal(10, "Set3")[4],
  "Electricity" = brewer.pal(10, "Set3")[3]
)

PrimaryProductsColors <- c(
  "Coal" = brewer.pal(10, "Set3")[10],
  "Oil" = brewer.pal(10, "Set3")[6],
  "Gas" = brewer.pal(10, "Set3")[8],
  "Biofuels and renewable wastes" = brewer.pal(10, "Set3")[7],
  "Non-renewable wastes" = brewer.pal(10, "Set3")[9],
  "Nuclear" = brewer.pal(10, "Set3")[2],
  "Hydro" = brewer.pal(10, "Set3")[5],
  "Wind, solar, geothermal, etc." = brewer.pal(10, "Set3")[1],
  "Heat" = brewer.pal(10, "Set3")[4],
  "Electricity" = brewer.pal(10, "Set3")[3]
)

EndUseColors <- c(
  "Space heating" = brewer.pal(6, "Set3")[6],
  "Space cooling" = brewer.pal(6, "Set3")[5],
  "Water heating" = brewer.pal(6, "Set3")[4],
  "Cooking" = brewer.pal(6, "Set3")[3],
  "Lighting and appliances" = brewer.pal(6, "Set3")[2],
  "Other" = brewer.pal(6, "Set3")[1]
)

TransportModeColors <- c(
  "Road" = brewer.pal(3, "Set3")[1],
  "Rail" = brewer.pal(3, "Set3")[2],
  "Navigation" = brewer.pal(3, "Set3")[3]
)

TransportProductColors <- c(
  "Coal" = brewer.pal(12, "Set3")[10],
  "Gasoline" = brewer.pal(12, "Paired")[1],
  "Biogasoline" = brewer.pal(12, "Paired")[2],
  "Diesel" = brewer.pal(12, "Paired")[7],
  "Biodiesel" = brewer.pal(12, "Paired")[8],
  "LPG" = brewer.pal(12, "Paired")[9],
  "Kerosene" = brewer.pal(12, "Paired")[10],
  "Other oil products" = brewer.pal(12, "Paired")[11],
  "Other liquid biofuels" = brewer.pal(12, "Paired")[12],
  "Gas" = brewer.pal(12, "Set3")[8],
  "Biogas" = brewer.pal(12, "Paired")[6],
  "Solid biofuels and wastes" = brewer.pal(12, "Paired")[4],
  # "Nuclear" = brewer.pal(10, "Set3")[2],
  # "Hydro" = brewer.pal(10, "Set3")[5],
  # "Wind, solar, geothermal, etc." = brewer.pal(10, "Set3")[1],
  # "Heat" = brewer.pal(10, "Set3")[4],
  "Electricity" = brewer.pal(12, "Set3")[3]
)