"""Color palettes ported from scripts/0_support/mapping_colors.R.

Hex values are the RColorBrewer Set3 palette and base-R named colors the R
dashboard used, so charts stay visually consistent with the original.
"""

# RColorBrewer Set3 (qualitative; brewer.pal(k) == first k of these)
_SET3 = [
    "#8DD3C7", "#FFFFB3", "#BEBADA", "#FB8072", "#80B1D3", "#FDB462",
    "#B3DE69", "#FCCDE5", "#D9D9D9", "#BC80BD", "#CCEBC5", "#FFED6F",
]

# base-R named colors
_BLUE4, _RED4, _GREEN4, _PURPLE4, _GREY = "#00008B", "#8B0000", "#008B00", "#551A8B", "#BEBEBE"

FINAL_PRODUCTS_COLORS = {
    "Coal": _SET3[9],
    "Oil": _SET3[5],
    "Gas": _SET3[7],
    "Biofuels and renewable wastes": _SET3[6],
    "Non-renewable wastes": _SET3[8],
    "Wind, solar, geothermal, etc.": _SET3[0],
    "Heat": _SET3[3],
    "Electricity": _SET3[2],
}

MANUFACTURING_SECTORS_COLORS = {
    "Construction": _SET3[0],
    "Mining and quarrying": _SET3[1],
    "Food, bev. and tobacco": _SET3[2],
    "Textile and leather": _SET3[3],
    "Wood and wood products": _SET3[4],
    "Paper, pulp and printing": _SET3[5],
    "Coke and ref. pet. products": _SET3[6],
    "Chemical and petrochem.": _SET3[7],
    "Non-metallic minerals": _SET3[8],
    "Basic metals": _SET3[9],
    "Machinery": _SET3[10],
    "Transport equipment": _SET3[11],
    "Other manufacturing": _GREY,
}

INDEX_COLORS = {
    "Energy consumption": _BLUE4,
    "Gross Value Added": _RED4,
    "Energy intensity": _GREEN4,
}

EFFECT_COLORS = {
    "Activity": _RED4,
    "Structure": _PURPLE4,
    "Intensity": _GREEN4,
}

# RColorBrewer Paired (12)
_PAIRED = [
    "#A6CEE3", "#1F78B4", "#B2DF8A", "#33A02C", "#FB9A99", "#E31A1C",
    "#FDBF6F", "#FF7F00", "#CAB2D6", "#6A3D9A", "#FFFF99", "#B15928",
]

TRANSPORT_MODE_COLORS = {
    "Road": _SET3[0],
    "Rail": _SET3[1],
    "Navigation": _SET3[2],
}

TRANSPORT_PRODUCT_COLORS = {
    "Coal": _SET3[9],
    "Gasoline": _PAIRED[0],
    "Biogasoline": _PAIRED[1],
    "Diesel": _PAIRED[6],
    "Biodiesel": _PAIRED[7],
    "LPG": _PAIRED[8],
    "Kerosene": _PAIRED[9],
    "Other oil products": _PAIRED[10],
    "Other liquid biofuels": _PAIRED[11],
    "Gas": _SET3[7],
    "Biogas": _PAIRED[5],
    "Solid biofuels and wastes": _PAIRED[3],
    "Electricity": _SET3[2],
}

TRANSPORT_INDEX_COLORS = {
    "Energy consumption": _BLUE4,
    "Traffic": _RED4,
    "Energy intensity": _GREEN4,
}

_YELLOW4 = "#8B8B00"

# Residential
HOUSEHOLD_INDEX_COLORS = {
    "Energy consumption": _BLUE4,
    "Population": _RED4,
    "Dwelling per capita": _PURPLE4,
    "Energy per dwelling": _GREEN4,
    "Weather": _YELLOW4,
}
HOUSEHOLD_EFFECT_COLORS = {
    "Population": _RED4,
    "Dwelling/cap.": _PURPLE4,
    "Energy/dwell.": _GREEN4,
    "Weather": _YELLOW4,
}
END_USE_COLORS = {
    "Space heating": _SET3[5],
    "Space cooling": _SET3[4],
    "Water heating": _SET3[3],
    "Cooking": _SET3[2],
    "Lighting and appliances": _SET3[1],
    "Other": _SET3[0],
}

# Economy-wide
ECONOMY_SECTORS_COLORS = {
    "Agricult., forest. and fish.": _SET3[2],
    "Manufacturing": _SET3[1],
    "Construction": _SET3[0],
    "Other industries": _SET3[3],
    "Comm. and pub. services": _SET3[4],
}
ECONOMY_INDEX_COLORS = {
    "Energy consumption": _BLUE4,
    "Employment": _RED4,
    "Energy consumption per employee": _GREEN4,
}
