# list of end uses sectors, used for the industry subset the energy balance (nrg_bal_c)
BASIC_METALS <- c(
  "FC_IND_IS_E",
  "NRG_CO_E",
  "NRG_BF_E",
  "FC_IND_NFM_E"
)

MINING_QUARRYING <- c(
  "FC_IND_MQ_E",
  "NRG_CM_E",
  "NRG_OIL_NG_E"
)

OTHER_MANUFACTURING <- c(
  "NRG_PF_E",
  "NRG_BKBPB_E",
  "NRG_CL_E",
  "NRG_GTL_E",
  "NRG_CPP_E",
  "NRG_NSP_E",
  "FC_IND_NSP_E"
)

NRG_IND_SECTORS <- c(
  BASIC_METALS,
  MINING_QUARRYING,
  OTHER_MANUFACTURING,
  "NRG_PR_E",
  "FC_IND_CON_E",
  "FC_IND_CPC_E",
  "FC_IND_FBT_E",
  "FC_IND_MAC_E",
  "FC_IND_NMM_E",
  "FC_IND_PPP_E",
  "FC_IND_TE_E",
  "FC_IND_TL_E",
  "FC_IND_WP_E"
)

# list of end uses sectors, used for the industry subset of the economic data (nama_10_a64)
GVA_IND_SECTORS <- c(
  "F",
  "B",
  "C10-C12",
  "C13-C15",
  "C16",
  "C17",
  "C18",
  "C19",
  "C20",
  "C21",
  "C22",
  "C23",
  "C24",
  "C25",
  "C26",
  "C27",
  "C28",
  "C29",
  "C30",
  "C31_C32"
)

# list of end uses sectors, as they will be named in the LMDI results
IDA_IND_SECTOR <- c(
  "Construction",
  "Mining and quarrying",
  # "Food, beverages and tobacco",
  "Food, bev. and tobacco",
  "Textile and leather",
  "Wood and wood products",
  "Paper, pulp and printing",
  # "Coke and refined petroleum products",
  "Coke and ref. pet. products",
  # "Chemical and petrochemical",
  "Chemical and petrochem.",
  "Non-metallic minerals",
  "Basic metals",
  "Machinery",
  "Transport equipment",
  "Other manufacturing"
)

# Inputs to electricity and heat generation
NRG_EHG_INPUT <-
  c(
    "TI_EHG_E",
    "TI_EHG_MAPE_E",
    "TI_EHG_MAPCHP_E",
    "TI_EHG_MAPH_E",
    "TI_EHG_APE_E",
    "TI_EHG_APCHP_E",
    "TI_EHG_APH_E",
    "TI_EHG_EDHP",
    "TI_EHG_EB",
    "TI_EHG_EPS",
    "TI_EHG_DHEP"
  )

# Output of electricity and heat
NRG_EHG_OUTPUT <-
  c(
    "TO_EHG",
    "TO_EHG_MAPE",
    "TO_EHG_MAPCHP",
    "TO_EHG_MAPH",
    "TO_EHG_APE",
    "TO_EHG_APCHP",
    "TO_EHG_APH",
    "TO_EHG_EDHP",
    "TO_EHG_EB",
    "TO_EHG_PH",
    "TO_EHG_OTH"
  )

# Agriculture, forestry and fishing
NRG_AGRI <- c(
  "FC_OTH_AF_E",
  "FC_OTH_FISH_E"
)
# Manufacturing
NRG_MAN <- c(
  "FC_IND_FBT_E",
  "FC_IND_TL_E",
  "FC_IND_WP_E",
  "FC_IND_PPP_E",
  "NRG_PR_E",
  "FC_IND_CPC_E",
  "FC_IND_NMM_E",
  "FC_IND_IS_E",
  "NRG_CO_E",
  "NRG_BF_E",
  "FC_IND_NFM_E",
  "FC_IND_MAC_E",
  "FC_IND_TE_E",
  "NRG_PF_E",
  "NRG_BKBPB_E",
  "NRG_CL_E",
  "NRG_GTL_E",
  "NRG_CPP_E",
  "NRG_NSP_E",
  "FC_IND_NSP_E"
)

# Other industries
NRG_OTH <- c(
  "FC_IND_MQ_E",
  "NRG_CM_E",
  "NRG_OIL_NG_E",
  # "TI_EHG_E", # removed because double counting with electricity
  "NRG_EHG_E",
  "NRG_GW_E",
  "NRG_LNG_E",
  "NRG_BIOG_E",
  "NRG_NI_E"
)

# list of end uses sectors, used in the subset
NRG_ECO_SECTORS <- c(
  NRG_AGRI,
  NRG_MAN,
  NRG_OTH,
  "FC_IND_CON_E",
  "FC_OTH_CP_E"
)

# list of transport mode, used for the transport subset of the energy balance (nrg_bal_c)
NRG_TRA <- c(
  "FC_TRA_RAIL_E",
  "FC_TRA_ROAD_E",
  "FC_TRA_DNAVI_E"
)

# list of end uses sectors, used in the subset
NRG_FULL_SECTORS <- c(
  NRG_AGRI,
  NRG_MAN,
  NRG_OTH,
  NRG_TRA,
  "FC_IND_CON_E",
  "FC_OTH_CP_E",
  "FC_OTH_HH_E"
)

# list of supply items, used in the context
NRG_SUPPLY <- c(
  "PPRD",
  "IMP",
  "EXP",
  "STK_CHG"
)

EMP_ECO_SECTORS <- c(
  "A",
  "B-E",
  "C",
  "F",
  "G-I",
  "J",
  "K",
  "L",
  "M_N",
  "O-Q",
  "R-U"
)

# list of end uses sectors, as they will be named in the LMDI results
IDA_ECO_SECTORS <- c(
  # "Agriculture, forestry and fishing",
  "Agricult., forest. and fish.",
  "Manufacturing",
  "Construction",
  # "Commercial and public services"
  "Comm. and pub. services",
  "Other industries"
)

# list of end uses sectors, as they will be named in the LMDI results
IDA_FULL_SECTORS <- c(
  # "Agriculture, forestry and fishing",
  "Agricult., forest. and fish.",
  "Manufacturing",
  "Construction",
  "Other industries",
  # "Commercial and public services"
  "Comm. and pub. services",
  "Residential",
  "Transport"
)

end_use_list <- c(
  "Space heating",
  "Space cooling",
  "Water heating",
  "Cooking",
  "Lighting and appliances",
  "Other"
)

measure_list <- c(
  "Total",
  end_use_list
)

# list of end uses modes, as they will be named in the LMDI results
IDA_TRA_MODES <- c(
  "Road",
  "Rail",
  "Navigation"
)