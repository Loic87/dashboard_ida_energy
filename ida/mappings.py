"""Code -> label mappings ported from scripts/0_support/mapping_*.R

These mirror the Eurostat code groupings used by the R dashboard so that the
Python pipeline produces numerically identical aggregates.
"""

# --- Energy products (nrg_bal_c `siec`) ---------------------------------------

COAL_PRODS = [
    "C0110", "C0121", "C0129", "C0210", "C0220", "C0311", "C0312", "C0320",
    "C0330", "C0340", "C0350", "C0360", "C0371", "C0379", "P1100", "P1200",
]

OIL_PRODS = [
    "O4100_TOT", "O4200", "O4300", "O4400X4410", "O4500", "O4610", "O4620",
    "O4630", "O4640", "O4651", "O4652XR5210B", "O4669", "O4671XR5220B",
    "O4653", "O4661XR5230B", "O4680", "O4691", "O4692", "O4693", "O4694",
    "O4695", "O4699", "S2000",
]

BIO_PRODS = [
    "R5110-5150_W6000RI", "R5160", "R5210P", "R5210B", "R5220P", "R5220B",
    "R5230P", "R5230B", "R5290", "R5300", "W6210",
]

OTH_PRODS = ["W6100", "W6220"]

OTH_REN = ["RA200", "RA300", "RA410", "RA420", "RA500", "RA600"]

NRG_PRODS = (
    COAL_PRODS + OIL_PRODS + ["G3000"] + BIO_PRODS + OTH_PRODS
    + ["RA100"] + OTH_REN + ["N900H", "E7000", "H8000"]
)

# Aggregated product groups: aggregate column name -> source siec codes.
# Single-code groups (Gas, Nuclear, Hydro, Heat, Electricity) are renamed directly.
PRODUCT_GROUPS = {
    "Coal": COAL_PRODS,
    "Oil": OIL_PRODS,
    "Biofuels and renewable wastes": BIO_PRODS,
    "Non-renewable wastes": OTH_PRODS,
    "Wind, solar, geothermal, etc.": OTH_REN,
}
PRODUCT_RENAME = {
    "G3000": "Gas",
    "N900H": "Nuclear",
    "RA100": "Hydro",
    "H8000": "Heat",
    "E7000": "Electricity",
}

# Final-energy product order (Nuclear/Hydro excluded, as in the R dashboard).
IDA_FINAL_PROD = [
    "Coal", "Oil", "Gas", "Biofuels and renewable wastes",
    "Non-renewable wastes", "Wind, solar, geothermal, etc.",
    "Heat", "Electricity",
]

# --- Industry energy sectors (nrg_bal_c `nrg_bal`) ----------------------------

BASIC_METALS = ["FC_IND_IS_E", "NRG_CO_E", "NRG_BF_E", "FC_IND_NFM_E"]
MINING_QUARRYING = ["FC_IND_MQ_E", "NRG_CM_E", "NRG_OIL_NG_E"]
OTHER_MANUFACTURING = [
    "NRG_PF_E", "NRG_BKBPB_E", "NRG_CL_E", "NRG_GTL_E",
    "NRG_CPP_E", "NRG_NSP_E", "FC_IND_NSP_E",
]

NRG_IND_SECTORS = (
    BASIC_METALS + MINING_QUARRYING + OTHER_MANUFACTURING
    + ["NRG_PR_E", "FC_IND_CON_E", "FC_IND_CPC_E", "FC_IND_FBT_E",
       "FC_IND_MAC_E", "FC_IND_NMM_E", "FC_IND_PPP_E", "FC_IND_TE_E",
       "FC_IND_TL_E", "FC_IND_WP_E"]
)

# Aggregated energy-sector groups: aggregate name -> source nrg_bal codes.
ENERGY_SECTOR_GROUPS = {
    "Basic metals": BASIC_METALS,
    "Mining and quarrying": MINING_QUARRYING,
    "Other manufacturing": OTHER_MANUFACTURING,
}
ENERGY_SECTOR_RENAME = {
    "FC_IND_CON_E": "Construction",
    "FC_IND_FBT_E": "Food, bev. and tobacco",
    "FC_IND_TL_E": "Textile and leather",
    "FC_IND_WP_E": "Wood and wood products",
    "FC_IND_PPP_E": "Paper, pulp and printing",
    "NRG_PR_E": "Coke and ref. pet. products",
    "FC_IND_CPC_E": "Chemical and petrochem.",
    "FC_IND_NMM_E": "Non-metallic minerals",
    "FC_IND_MAC_E": "Machinery",
    "FC_IND_TE_E": "Transport equipment",
}

# --- Industry GVA sectors (nama_10_a64 `nace_r2`) -----------------------------

GVA_IND_SECTORS = [
    "F", "B", "C10-C12", "C13-C15", "C16", "C17", "C18", "C19", "C20", "C21",
    "C22", "C23", "C24", "C25", "C26", "C27", "C28", "C29", "C30", "C31_C32",
]

# Aggregated NACE groups: aggregate name -> source nace_r2 codes.
GVA_SECTOR_GROUPS = {
    "C17-C18": ["C17", "C18"],
    "C20-C21": ["C20", "C21"],
    "C22-C23": ["C22", "C23"],
    "C25-C28": ["C25", "C26", "C27", "C28"],
    "C29-C30": ["C29", "C30"],
}
GVA_SECTOR_RENAME = {
    "F": "Construction",
    "B": "Mining and quarrying",
    "C10-C12": "Food, bev. and tobacco",
    "C13-C15": "Textile and leather",
    "C16": "Wood and wood products",
    "C17-C18": "Paper, pulp and printing",
    "C19": "Coke and ref. pet. products",
    "C20-C21": "Chemical and petrochem.",
    "C22-C23": "Non-metallic minerals",
    "C24": "Basic metals",
    "C25-C28": "Machinery",
    "C29-C30": "Transport equipment",
    "C31_C32": "Other manufacturing",
}

IDA_IND_SECTOR = [
    "Construction", "Mining and quarrying", "Food, bev. and tobacco",
    "Textile and leather", "Wood and wood products", "Paper, pulp and printing",
    "Coke and ref. pet. products", "Chemical and petrochem.",
    "Non-metallic minerals", "Basic metals", "Machinery",
    "Transport equipment", "Other manufacturing",
]

# --- Transport ----------------------------------------------------------------

GASOLINE_PRODS = ["O4651", "O4652XR5210B", "O4653"]
DIESEL_PRODS = ["O4671XR5220B"]
KEROSENE_PRODS = ["O4661XR5230B", "O4669"]
LPG_PRODS = ["O4630"]
OTHER_OIL_PRODS = [
    "O4100_TOT", "O4200", "O4300", "O4400X4410", "O4500", "O4610", "O4620",
    "O4640", "O4680", "O4691", "O4692", "O4693", "O4694", "O4695", "O4699",
    "S2000",
]
BIOGASOLINE_PRODS = ["R5210P", "R5210B"]
BIODIESEL_PRODS = ["R5220P", "R5220B"]
OTHER_BIOLIQUIDS_PRODS = ["R5230P", "R5230B", "R5290"]
BIOGAS_PRODS = ["R5300"]
OTH_BIOWASTE_PRODS = ["R5110-5150_W6000RI", "R5160", "W6210", "W6100", "W6220"]

TRA_PRODS = (
    COAL_PRODS + GASOLINE_PRODS + DIESEL_PRODS + KEROSENE_PRODS + LPG_PRODS
    + OTHER_OIL_PRODS + ["G3000"] + BIOGASOLINE_PRODS + BIODIESEL_PRODS
    + OTHER_BIOLIQUIDS_PRODS + BIOGAS_PRODS + OTH_BIOWASTE_PRODS + ["E7000"]
)

# Transport energy modes (nrg_bal_c `nrg_bal`)
NRG_TRA = ["FC_TRA_RAIL_E", "FC_TRA_ROAD_E", "FC_TRA_DNAVI_E"]
TRA_MODE_RENAME = {
    "FC_TRA_ROAD_E": "Road",
    "FC_TRA_RAIL_E": "Rail",
    "FC_TRA_DNAVI_E": "Navigation",
}

TRA_PRODUCT_GROUPS = {
    "Coal": COAL_PRODS,
    "Gasoline": GASOLINE_PRODS,
    "Biogasoline": BIOGASOLINE_PRODS,
    "Diesel": DIESEL_PRODS,
    "Biodiesel": BIODIESEL_PRODS,
    "LPG": LPG_PRODS,
    "Kerosene": KEROSENE_PRODS,
    "Other oil products": OTHER_OIL_PRODS,
    "Other liquid biofuels": OTHER_BIOLIQUIDS_PRODS,
    "Biogas": BIOGAS_PRODS,
    "Solid biofuels and wastes": OTH_BIOWASTE_PRODS,
}
TRA_PRODUCT_RENAME = {"G3000": "Gas", "E7000": "Electricity"}

IDA_TRA_PROD = [
    "Coal", "Gasoline", "Biogasoline", "Diesel", "Biodiesel", "LPG",
    "Kerosene", "Other oil products", "Other liquid biofuels", "Gas",
    "Biogas", "Solid biofuels and wastes", "Electricity",
]
IDA_TRA_MODES = ["Road", "Rail", "Navigation"]

# --- Economy-wide / employment ------------------------------------------------

# Energy sectors (nrg_bal_c `nrg_bal`)
NRG_AGRI = ["FC_OTH_AF_E", "FC_OTH_FISH_E"]
NRG_MAN = [
    "FC_IND_FBT_E", "FC_IND_TL_E", "FC_IND_WP_E", "FC_IND_PPP_E", "NRG_PR_E",
    "FC_IND_CPC_E", "FC_IND_NMM_E", "FC_IND_IS_E", "NRG_CO_E", "NRG_BF_E",
    "FC_IND_NFM_E", "FC_IND_MAC_E", "FC_IND_TE_E", "NRG_PF_E", "NRG_BKBPB_E",
    "NRG_CL_E", "NRG_GTL_E", "NRG_CPP_E", "NRG_NSP_E", "FC_IND_NSP_E",
]
NRG_OTH = [
    "FC_IND_MQ_E", "NRG_CM_E", "NRG_OIL_NG_E", "NRG_EHG_E", "NRG_GW_E",
    "NRG_LNG_E", "NRG_BIOG_E", "NRG_NI_E",
]
NRG_ECO_SECTORS = NRG_AGRI + NRG_MAN + NRG_OTH + ["FC_IND_CON_E", "FC_OTH_CP_E"]

ECO_ENERGY_GROUPS = {
    "Agricult., forest. and fish.": NRG_AGRI,
    "Manufacturing": NRG_MAN,
    "Other industries": NRG_OTH,
}
ECO_ENERGY_RENAME = {
    "FC_IND_CON_E": "Construction",
    "FC_OTH_CP_E": "Comm. and pub. services",
}

# Employment sectors (nama_10_a10_e `nace_r2`)
EMP_ECO_SECTORS = ["A", "B-E", "C", "F", "G-I", "J", "K", "L", "M_N", "O-Q", "R-U"]

IDA_ECO_SECTORS = [
    "Agricult., forest. and fish.", "Manufacturing", "Construction",
    "Comm. and pub. services", "Other industries",
]
