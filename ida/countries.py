"""Country code -> display name (EU, EFTA, candidate countries + UK)."""

COUNTRY_NAMES = {
    "AL": "Albania", "AT": "Austria", "BE": "Belgium", "BG": "Bulgaria",
    "CH": "Switzerland", "CY": "Cyprus", "CZ": "Czechia", "DE": "Germany",
    "DK": "Denmark", "EE": "Estonia", "EL": "Greece", "ES": "Spain",
    "FI": "Finland", "FR": "France", "HR": "Croatia", "HU": "Hungary",
    "IE": "Ireland", "IS": "Iceland", "IT": "Italy", "LT": "Lithuania",
    "LU": "Luxembourg", "LV": "Latvia", "MD": "Moldova", "ME": "Montenegro",
    "MK": "North Macedonia", "MT": "Malta", "NL": "Netherlands", "NO": "Norway",
    "PL": "Poland", "PT": "Portugal", "RO": "Romania", "RS": "Serbia",
    "SE": "Sweden", "SI": "Slovenia", "SK": "Slovakia", "TR": "Türkiye",
    "UA": "Ukraine", "UK": "United Kingdom",
}


def name(code: str) -> str:
    return COUNTRY_NAMES.get(code, code)
