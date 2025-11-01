# Energy Decomposition Analysis Dashboard

An interactive Shiny dashboard for **Index Decomposition Analysis (IDA)** of energy consumption across European countries using the LMDI (Logarithmic Mean Divisia Index) methodology.

## Overview

This dashboard analyzes energy consumption changes over time by decomposing them into different effects:

### Sectors Analyzed
- **Industry**: Energy consumption decomposed by Gross Value Added (GVA) and employment
- **Transport**: Energy consumption decomposed by Vehicle Kilometers (VKM) traveled
- **Residential**: Household energy consumption analysis
- **Economy-wide**: Full economy energy consumption patterns

### Data Source
All data is retrieved from [Eurostat](https://ec.europa.eu/eurostat) using their API, covering 40+ European countries.

## Features

- Interactive selection of countries and time periods
- Multiple decomposition methodologies (LMDI)
- Visualization of:
  - Energy consumption by sector and product
  - Economic activity indicators (GVA, employment, VKM)
  - Decomposition effects (activity, structure, intensity)
  - Waterfall charts showing contribution of each effect
- Support for 40+ European countries

## Prerequisites

- **R** >= 4.3.0
- Internet connection (for downloading Eurostat data)
- No RStudio required - runs in any R environment or directly from terminal

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/Loic87/dashboard_ida_energy.git
cd dashboard_ida_energy
```

### 2. Install R Dependencies

The project uses `renv` for reproducible dependency management.

```r
# renv will automatically bootstrap when you open the project
# To manually restore dependencies:
renv::restore()
```

**Key packages used:**
- **Dashboard**: `shiny`, `shinydashboard`, `shinyjs`, `plotly`, `ggplot2`
- **Data**: `eurostat` (v4.0.0), `arrow`, `dplyr`, `tidyr`
- **Utilities**: `here`, `futile.logger`, `RColorBrewer`, `waterfalls`

## Configuration

The dashboard uses country and year selectors in the UI. The `config.yml` file is used for batch chart generation:

```yaml
country: all  # Specific country code (e.g., "BE", "FR", "DE") or "all"

year:
  first: 2011  # Start year
  last: 2023   # End year (latest Eurostat data as of Nov 2025)

actions:
  download: False  # True: download fresh data, False: use cached data
  clear: True      # Clear existing charts before generating new ones
  context: True    # Generate context data
  industry_GVA_final: True     # Industry decomposition by GVA
  industry_GVA_primary: True   # Primary energy in industry
  economy_emp_final: True      # Economy-wide by employment
  household_final: True        # Residential sector (not yet in dashboard)
  transport_final: True        # Transport by VKM
```

**Country Codes**: Use ISO 3166-1 alpha-2 codes (e.g., `BE` for Belgium, `FR` for France, `DE` for Germany)

## Usage

### Running the Dashboard

#### Quick Start (Recommended)

```r
# From project root directory
R -e "shiny::runApp('scripts', port=8080)"
```

The dashboard will be available at `http://127.0.0.1:8080`

#### From R Console

```r
library(shiny)
library(here)

# Run from project root
shiny::runApp('scripts', port=8080)
```

#### Usage
1. Select a country from the dropdown (40+ European countries available)
2. Adjust the year range slider (1990-2023)
3. Navigate between tabs:
   - **Industry**: Energy and GVA decomposition by industrial sector
   - **Transport**: Energy and VKM decomposition by transport mode
   - **Residential**: (Not yet implemented - see `TODO_RESIDENTIAL.md`)

### Downloading Data

Data is automatically downloaded from Eurostat on first run and cached locally.

To manually download/refresh data:

```r
source(here::here("scripts", "0_support", "data_download.R"))
```

**Data files** are stored in `data/` as Apache Arrow `.feather` files (one per country per dataset):
- `nama_10_a64_BE.feather` - Industry GVA (NACE Rev.2 A64 classification, 96 sectors)
- `nrg_bal_c_BE.feather` - Energy balance
- `nrg_d_hhq_BE.feather` - Household energy consumption
- `demo_gind_BE.feather` - Population data
- `ilc_lvph01_BE.feather` - Household size
- `nrg_chdd_a_BE.feather` - Heating/cooling degree days
- `road_tf_vehmov_BE.feather` - Road transport VKM
- `rail_tf_trainmv_BE.feather` - Rail transport VKM
- `iww_tf_vetf_BE.feather` - Inland waterway transport VKM

**Note**: Data is downloaded per country and covers 1990-2023 (varies by dataset and country availability)

## Project Structure

```
dashboard_ida_energy/
├── config.yml                   # Configuration for batch chart generation
├── renv.lock                    # Locked R package versions
├── README.md                    # This file
├── TODO_RESIDENTIAL.md          # Residential sector implementation plan
├── LICENSE                      # MIT License
├── DESCRIPTION                  # R package metadata
├── eurostat_ida_energy.Rproj    # R project file (optional, not required)
│
├── data/                        # Cached Eurostat data (*.feather files)
│   ├── nama_10_a64_BE.feather   # Industry GVA by NACE sector
│   ├── nrg_bal_c_BE.feather     # Energy balance
│   ├── nrg_d_hhq_BE.feather     # Household energy
│   └── ...                      # (per-country files)
│
├── output/                      # Generated static charts by country
│   ├── BE/                      # Belgium charts
│   ├── FR/                      # France charts
│   └── ...
│
├── tests/                       # Test and validation scripts
│   ├── README.md                # Test documentation
│   ├── test_countries.R         # Multi-country validation
│   ├── test_residential.R       # Residential data checks
│   ├── test_code_modernization.R  # RStudio dependency tests
│   └── ...
│
├── docs/                        # Documentation
│   ├── QUICKSTART.md            # Quick start guide
│   ├── SETUP_GUIDE.md           # Detailed setup instructions
│   └── history/                 # Development phase summaries
│       ├── PHASE1_COMPLETE.md
│       ├── PHASE2_COMPLETE.md
│       └── PHASE3_SUMMARY.md
│
└── scripts/                     # Dashboard and analysis code
    ├── app.R                    # Main Shiny app entry point
    ├── ui.R                     # Dashboard UI definition
    ├── server.R                 # Dashboard server logic
    │
    ├── 0_support/               # Core utilities
    │   ├── data_download.R      # Eurostat API data fetching
    │   ├── data_load.R          # Per-country data loading functions
    │   ├── mapping_countries.R  # Country code mappings
    │   ├── mapping_sectors.R    # NACE sector classifications
    │   ├── mapping_products.R   # Energy product classifications
    │   ├── mapping_colors.R     # Chart color schemes
    │   └── outputs.R            # Chart generation utilities
    │
    ├── 1_industry/              # Industry sector LMDI analysis
    │   └── 1a_industry_gva_final.R
    │
    ├── 2_household/             # Residential sector (not yet integrated)
    │   └── households.R
    │
    ├── 3_transport/             # Transport sector LMDI analysis
    │   └── transport_*.R
    │
    └── 4_all_sectors/           # Economy-wide analysis
        └── full_energy.R
```

## Methodology

### LMDI Decomposition
The Logarithmic Mean Divisia Index (LMDI) method decomposes energy consumption changes into:

1. **Activity Effect**: Changes due to overall economic activity (GVA, employment, VKM)
2. **Structure Effect**: Changes in the composition of sectors/modes
3. **Intensity Effect**: Changes in energy efficiency (energy per unit of activity)

Formula:
```
ΔE = ΔE_activity + ΔE_structure + ΔE_intensity
```

### Data Coverage

**Eurostat Datasets Used:**
- `nama_10_a64` - GVA by 96 NACE Rev.2 sectors (A64 detailed classification)
  - Chain-linked volumes (CLV10_MEUR - 2010 reference year)
  - Annual data 1975-2024
- `nrg_bal_c` - Complete energy balances (annual data)
  - Final energy consumption by sector and product
  - 72 energy products, 60+ balance items
- `nrg_d_hhq` - Disaggregated household energy consumption (2010-2023)
- `demo_gind` - Population and demographic indicators (1960-2025)
- `ilc_lvph01` - Average household size from EU-SILC survey (2003-2024)
- `nrg_chdd_a` - Heating and cooling degree days (1979-2024)
- `road_tf_vehmov` - Road vehicle kilometers
- `rail_tf_trainmv` - Rail vehicle kilometers
- `iww_tf_vetf` - Inland waterway transport

**NACE Rev.2 Sectors:** Industry analysis uses A64 detailed classification (96 sectors) including:
- C10-C12 (Food, beverages, tobacco)
- C13-C15 (Textile and leather)
- C16 (Wood products)
- C17-C18 (Paper, pulp, printing)
- C19 (Coke and refined petroleum)
- C20-C21 (Chemicals and pharmaceuticals)
- And 90 more detailed sectors...

## Troubleshooting

### Common Issues

1. **Package installation errors**
   ```r
   # Reset renv and restore
   renv::restore()
   ```

2. **Data download failures**
   - Check internet connection
   - Verify Eurostat API is accessible: https://ec.europa.eu/eurostat
   - Some countries may have limited data availability
   - Try reducing the year range if specific years fail

3. **Missing data warnings**
   - Not all countries have complete data for all years
   - Dashboard shows warnings for missing VKM data (transport) or missing sectors
   - Example: Belgium road VKM missing 2007-2012, 2016-2021
   - Adjust year range in the UI to match available data

4. **"Column 'C17' doesn't exist" errors**
   - Fixed in latest version (Nov 2025)
   - Ensure you have `nama_10_a64` data (not `nama_10_a10_e`)
   - Re-run data download if needed

5. **Residential sector not working**
   - Residential sector UI integration is not yet complete
   - See `TODO_RESIDENTIAL.md` for implementation status
   - Industry and Transport sectors are fully functional

## Development Roadmap

- [x] **Phase 1**: Environment & dependency management (renv setup)
- [x] **Phase 2**: Data & API updates (Eurostat 2023 data, latest eurostat package v4.0.0)
- [x] **Phase 3**: Code modernization
  - Removed all RStudio dependencies (rstudioapi)
  - Migrated from deprecated `feather` to `arrow` package
  - Portable path resolution with `here` package
  - Per-country data loading architecture
- [x] **Phase 4**: Data compatibility fixes
  - Fixed NACE sector mappings (nama_10_a64 A64 classification)
  - Updated unit filters (CLV10_MEUR / CLV15_MEUR compatibility)
  - Validated across 6+ countries
- [ ] **Phase 5**: Enhanced documentation (IN PROGRESS)
  - Updated README with current status
  - Data structure documentation
  - API usage examples
- [ ] **Phase 6**: Residential sector integration (see TODO_RESIDENTIAL.md)
- [ ] **Phase 7**: Production deployment & optimization

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

MIT License - see LICENSE file for details

## Citation

If you use this tool in your research, please cite:
```
[Your Name] (2025). Energy Decomposition Analysis Dashboard for European Countries.
GitHub repository: https://github.com/Loic87/dashboard_ida_energy
```

## Contact

For questions or issues, please open an issue on GitHub: https://github.com/Loic87/dashboard_ida_energy/issues

## Acknowledgments

- Data provided by [Eurostat](https://ec.europa.eu/eurostat)
- LMDI methodology based on Ang, B.W. (2004, 2015)
- Built with R Shiny framework