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

- **R** >= 4.1.0
- **RStudio** (recommended) or any R environment
- Internet connection (for downloading Eurostat data)

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/Loic87/dashboard_ida_energy.git
cd dashboard_ida_energy
```

### 2. Install R Dependencies

#### Option A: Using renv (Recommended)

```r
# Install renv if not already installed
install.packages("renv")

# Restore project dependencies
renv::restore()
```

#### Option B: Manual Installation

```r
# Install required packages
install.packages(c(
  "shiny", "shinydashboard", "shinyjs",
  "plotly", "ggplot2",
  "dplyr", "tidyr", "tidyverse",
  "eurostat", "feather", "arrow",
  "RColorBrewer", "waterfalls",
  "futile.logger", "fs",
  "yaml", "here"
))
```

## Configuration

Edit `config.yml` to customize your analysis:

```yaml
country: all  # Specific country code (e.g., "FR", "DE") or "all"

year:
  first: 2011  # Start year
  last: 2024   # End year (update to latest available)

actions:
  download: False  # True: download fresh data, False: use cached data
  clear: True      # Clear existing charts before generating new ones
  context: True    # Generate context data
  industry_GVA_final: True     # Industry decomposition by GVA
  industry_GVA_primary: True   # Primary energy in industry
  economy_emp_final: True      # Economy-wide by employment
  household_final: True        # Residential sector
  transport_final: True        # Transport by VKM
```

## Usage

### Running the Dashboard

#### From RStudio
1. Open `eurostat_ida_energy.Rproj`
2. Open `scripts/app.R`
3. Click "Run App" button

#### From R Console

```r
# Set working directory to scripts folder
setwd("scripts")

# Run the app
shiny::runApp()
```

#### From Command Line

```r
R -e "shiny::runApp('scripts')"
```

The dashboard will open in your default web browser at `http://127.0.0.1:XXXX`

### Downloading Data

First-time setup or to refresh data:

1. Set `download: True` in `config.yml`
2. Run `scripts/0_support/data_download.R`
3. Data will be cached in `data/` folder as `.feather` files

```r
source("scripts/0_support/data_download.R")
```

## Project Structure

```
dashboard_ida_energy/
├── config.yml                 # Configuration file
├── DESCRIPTION               # R package dependencies
├── README.md                 # This file
├── data/                     # Cached Eurostat data (.feather files)
├── output/                   # Generated charts by country
├── scripts/
│   ├── app.R                # Main Shiny app entry point
│   ├── ui.R                 # User interface definition
│   ├── server.R             # Server logic
│   ├── 0_support/           # Helper functions
│   │   ├── data_download.R  # Eurostat data fetching
│   │   ├── data_load.R      # Data loading utilities
│   │   ├── mapping_*.R      # Country/sector/product mappings
│   ├── 1_industry/          # Industry sector analysis
│   ├── 2_household/         # Residential sector analysis
│   ├── 3_transport/         # Transport sector analysis
│   └── 4_all_sectors/       # Economy-wide analysis
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
- **Energy**: Final and primary energy consumption by sector and product
- **Economic**: GVA by economic sector (NACE classification)
- **Transport**: Vehicle kilometers by transport mode
- **Residential**: Household energy consumption, heating degree days
- **Demographics**: Population and household counts

## Troubleshooting

### Common Issues

1. **Package installation errors**
   ```r
   # Update all packages
   update.packages(ask = FALSE)
   ```

2. **Data download failures**
   - Check internet connection
   - Verify Eurostat API is accessible
   - Some countries may have limited data availability

3. **Missing data warnings**
   - Not all countries have complete data for all years
   - Dashboard will show warnings for missing data
   - Adjust year range in the UI to match available data

4. **RStudio API errors**
   - If you see `rstudioapi` errors when running outside RStudio
   - This is expected and will be fixed in Phase 3

## Development Roadmap

- [x] Phase 1: Environment & dependency management
- [ ] Phase 2: Data & API updates (2025 data)
- [ ] Phase 3: Code modernization (remove RStudio dependencies)
- [ ] Phase 4: Testing & validation
- [ ] Phase 5: Enhanced documentation
- [ ] Phase 6: Production deployment

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

For questions or issues, please open an issue on GitHub or contact [your.email@example.com]

## Acknowledgments

- Data provided by [Eurostat](https://ec.europa.eu/eurostat)
- LMDI methodology based on Ang, B.W. (2004, 2015)
- Built with R Shiny framework