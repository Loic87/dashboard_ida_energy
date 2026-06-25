# Coal, manufactured gases, peat and peat products
COAL_PRODS <- c(
  "C0110",
  "C0121",
  "C0129",
  "C0210",
  "C0220",
  "C0311",
  "C0312",
  "C0320",
  "C0330",
  "C0340",
  "C0350",
  "C0360",
  "C0371",
  "C0379",
  "P1100",
  "P1200"
)

# Oil, petroleum products, oil shale and oil sands
OIL_PRODS <- c(
  "O4100_TOT",
  "O4200",
  "O4300",
  "O4400X4410",
  "O4500",
  "O4610",
  "O4620",
  "O4630",
  "O4640",
  "O4651",
  "O4652XR5210B",
  "O4669",
  "O4671XR5220B",
  "O4653",
  "O4661XR5230B",
  "O4680",
  "O4691",
  "O4692",
  "O4693",
  "O4694",
  "O4695",
  "O4699",
  "S2000"
)

# Biofuels and renewable wastes
BIO_PRODS <- c(
  "R5110-5150_W6000RI",
  "R5160",
  "R5210P",
  "R5210B",
  "R5220P",
  "R5220B",
  "R5230P",
  "R5230B",
  "R5290",
  "R5300",
  "W6210"
)

# Non-renewable wastes
OTH_PRODS <- c(
  "W6100",
  "W6220"
)

# Other renewables
OTH_REN <- c(
  "RA200",
  "RA300",
  "RA410",
  "RA420",
  "RA500",
  "RA600"
)

# list of products, used for the subset of the energy balance (nrg_bal_c)
NRG_PRODS <- c(
  COAL_PRODS,
  OIL_PRODS,
  "G3000",
  BIO_PRODS,
  OTH_PRODS,
  "RA100",
  OTH_REN,
  "N900H",
  "E7000",
  "H8000"
)

# Gasoline
GASOLINE_PRODS <- c(
  "O4651",
  "O4652XR5210B",
  "O4653"
)

# Diesel
DIESEL_PRODS <- c("O4671XR5220B")

# Kerosene
KEROSENE_PRODS <- c(
  "O4661XR5230B",
  "O4669"
)

# LPG
LPG_PRODS <- c("O4630")

# Oil, petroleum products, oil shale and oil sands
OTHER_OIL_PRODS <- c(
  "O4100_TOT",
  "O4200",
  "O4300",
  "O4400X4410",
  "O4500",
  "O4610",
  "O4620",
  "O4640",
  "O4680",
  "O4691",
  "O4692",
  "O4693",
  "O4694",
  "O4695",
  "O4699",
  "S2000"
)

# Bio-Gasoline
BIOGASOLINE_PRODS <- c(
  "R5210P",
  "R5210B"
)

# Bio-Diesel
BIODIESEL_PRODS <- c(
  "R5220P",
  "R5220B"
)

# Other bioliquids
OTHER_BIOLIQUIDS_PRODS <- c(
  "R5230P",
  "R5230B",
  "R5290"
)
# Other biogas
BIOGAS_PRODS <- c("R5300")

# Other Biofuels and wastes
OTH_BIOWASTE_PRODS <- c(
  "R5110-5150_W6000RI",
  "R5160",
  "W6210",
  "W6100",
  "W6220"
)

# list of products, used for the subset of the energy balance (nrg_bal_c)
TRA_PRODS <- c(
  COAL_PRODS,
  GASOLINE_PRODS,
  DIESEL_PRODS,
  KEROSENE_PRODS,
  LPG_PRODS,
  OTHER_OIL_PRODS,
  "G3000",
  BIOGASOLINE_PRODS,
  BIODIESEL_PRODS,
  OTHER_BIOLIQUIDS_PRODS,
  BIOGAS_PRODS,
  OTH_BIOWASTE_PRODS,
  "E7000"
)

# list of products, as they will be named in the charts
IDA_FINAL_PROD <- c(
  "Coal",
  "Oil",
  "Gas",
  "Biofuels and renewable wastes",
  "Non-renewable wastes",
  #   "Nuclear",
  #   "Hydro",
  "Wind, solar, geothermal, etc.",
  "Heat",
  "Electricity"
)

# list of products, as they will be named in the charts
IDA_PRIMARY_PROD <- c(
  "Coal",
  "Oil",
  "Gas",
  "Biofuels and renewable wastes",
  "Non-renewable wastes",
  "Nuclear",
  "Hydro",
  "Wind, solar, geothermal, etc.",
  "Heat",
  "Electricity"
)

# list of products, as they will be named in the charts
IDA_TRA_PROD <- c(
  "Coal",
  "Gasoline",
  "Biogasoline",
  "Diesel",
  "Biodiesel",
  "LPG",
  "Kerosene",
  "Other oil products",
  "Other liquid biofuels",
  "Gas",
  "Biogas",
  "Solid biofuels and wastes",
  "Electricity"
)