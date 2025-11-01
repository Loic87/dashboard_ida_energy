# Energy IDA Dashboard - Quick Reference

## Installation (First Time)

```bash
# Clone repository
git clone https://github.com/Loic87/dashboard_ida_energy.git
cd dashboard_ida_energy

# Install all packages
Rscript install_with_renv.R
```

## Running the Dashboard

```r
# From R console
shiny::runApp('scripts')

# Or from terminal
R -e "shiny::runApp('scripts')"
```

## Common Tasks

### Update Data from Eurostat
```r
# Edit config first
edit('config.yml')  # Set download: True

# Run data download
source('scripts/0_support/data_download.R')
```

### Check Package Status
```bash
Rscript check_packages.R
```

### Update Packages
```r
library(renv)
renv::update()          # Update all
renv::update("shiny")   # Update specific
renv::snapshot()        # Save changes
```

### View Project Status
```r
renv::status()           # Check sync status
renv::dependencies()     # List all dependencies
```

## Configuration (config.yml)

```yaml
country: "FR"    # or "all" for all countries
year:
  first: 2011
  last: 2024
actions:
  download: True  # Fetch fresh data
```

## File Locations

- **Scripts**: `scripts/`
- **Data Cache**: `data/` (feather files)
- **Output Charts**: `output/`
- **Config**: `config.yml`

## Troubleshooting

### App won't start
```r
# Check for errors
shiny::runApp('scripts', test.mode = TRUE)
```

### Package issues
```r
renv::restore()  # Reset to lockfile
```

### Data issues
```r
# Re-download data
source('scripts/0_support/data_download.R')
```

## Project Structure

```
dashboard_ida_energy/
├── scripts/
│   ├── app.R              # Main app
│   ├── ui.R               # Interface
│   ├── server.R           # Logic
│   ├── 0_support/         # Utilities
│   ├── 1_industry/        # Industry analysis
│   ├── 2_household/       # Residential analysis
│   └── 3_transport/       # Transport analysis
├── data/                  # Cached Eurostat data
├── output/                # Generated charts
└── config.yml             # Configuration
```

## Key Commands

```r
# Package management
renv::status()
renv::install("package")
renv::snapshot()
renv::restore()

# Run app
shiny::runApp('scripts')

# Data download
source('scripts/0_support/data_download.R')
```

## Getting Help

- Full setup: See `SETUP_GUIDE.md`
- Documentation: See `README.md`
- Phase 1 details: See `PHASE1_COMPLETE.md`

## Next Steps

1. Install packages: `Rscript install_with_renv.R`
2. Configure: Edit `config.yml`
3. Run: `shiny::runApp('scripts')`

---

**Version**: 0.2.0  
**Last Updated**: November 1, 2025
