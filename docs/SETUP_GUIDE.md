# Setup Guide - Energy IDA Dashboard

## Phase 1: Environment & Dependency Management ✓

This guide will help you set up the development environment for the Energy Decomposition Analysis Dashboard.

## Quick Start

### Option 1: Automated Setup (Recommended)

```bash
# From the project root directory
Rscript install_with_renv.R
```

This will:
1. Install all required packages via renv
2. Create a reproducible environment snapshot
3. Lock package versions for consistency

### Option 2: Manual Setup

1. **Initialize renv**
   ```r
   # In R console
   install.packages("renv")
   library(renv)
   renv::init(bare = TRUE)
   ```

2. **Install packages**
   ```r
   Rscript install_packages.R
   ```

3. **Create snapshot**
   ```r
   renv::snapshot()
   ```

## Verification

Check that all packages are installed:

```r
Rscript check_packages.R
```

Expected output: All packages should show ✓

## Package List

### Core Shiny Framework
- **shiny** (>= 1.7.0) - Web application framework
- **shinydashboard** (>= 0.7.2) - Dashboard UI components
- **shinyjs** (>= 2.1.0) - JavaScript operations in Shiny

### Visualization
- **plotly** (>= 4.10.0) - Interactive plots
- **ggplot2** (>= 3.4.0) - Static plots
- **waterfalls** (>= 1.0.0) - Waterfall charts for decomposition
- **RColorBrewer** (>= 1.1.3) - Color palettes

### Data Manipulation
- **dplyr** (>= 1.1.0) - Data transformation
- **tidyr** (>= 1.3.0) - Data tidying
- **tidyverse** (>= 2.0.0) - Collection of tidyverse packages

### Data I/O
- **feather** (>= 0.3.5) - Fast binary data format (legacy)
- **arrow** (>= 13.0.0) - Modern columnar data format

### Data Source
- **eurostat** (>= 4.0.0) - Eurostat API client

### Utilities
- **futile.logger** (>= 1.4.3) - Logging framework
- **fs** (>= 1.6.0) - File system operations
- **yaml** (>= 2.3.7) - YAML config parsing
- **here** (>= 1.0.1) - Project-relative paths

## File Structure Created

```
dashboard_ida_energy/
├── .Rprofile              # R session configuration
├── DESCRIPTION            # Package dependencies
├── renv.lock              # Locked package versions (after snapshot)
├── renv/                  # renv infrastructure
│   ├── activate.R
│   ├── library/          # Project-specific package library
│   └── settings.json
├── setup_renv.R           # Setup script
├── install_packages.R     # Package installation script
├── install_with_renv.R    # renv-based installation
└── check_packages.R       # Verification script
```

## Troubleshooting

### Issue: Package installation fails

**Solution 1**: Check internet connection and CRAN mirror
```r
options(repos = c(CRAN = "https://cloud.r-project.org"))
```

**Solution 2**: Install packages one by one to identify the problematic package
```r
install.packages("package_name")
```

### Issue: renv not activating

**Solution**: Manually source the activation script
```r
source("renv/activate.R")
```

### Issue: "Library not writable" error

**Solution**: Install to user library
```r
install.packages("package_name", lib = Sys.getenv("R_LIBS_USER"))
```

### Issue: Conflicting package versions

**Solution**: Use renv to restore known working versions
```r
renv::restore()
```

## System Requirements

- **R**: Version 4.1.0 or higher
- **Operating System**: macOS, Linux, or Windows
- **Memory**: At least 4GB RAM recommended
- **Disk Space**: ~2GB for packages and data

## R Version Information

To check your R version:
```r
R.version.string
```

Current project was developed with: R 4.3.3

## Known Issues & Limitations

1. **feather package**: Being replaced by arrow package (both included for compatibility)
2. **rstudioapi dependency**: Scripts use `rstudioapi::getActiveDocumentContext()` which only works in RStudio (will be fixed in Phase 3)
3. **tidyverse**: Large metapackage, consider installing only needed components for production

## Next Steps

After completing Phase 1:
1. ✓ Environment is set up
2. → Proceed to Phase 2: Update Eurostat data
3. → Phase 3: Modernize code
4. → Phase 4: Testing
5. → Phase 6: Deployment

## Getting Help

- Check package documentation: `?package_name`
- View installed package version: `packageVersion("package_name")`
- Check renv status: `renv::status()`
- View dependency tree: `renv::dependencies()`

## Maintenance

### Updating Packages

```r
# Update all packages
renv::update()

# Update specific package
renv::update("package_name")

# Create new snapshot after updates
renv::snapshot()
```

### Sharing Environment

Share the `renv.lock` file with collaborators. They can restore the exact environment:

```r
renv::restore()
```

### Removing renv

If you want to remove renv:
```r
renv::deactivate()
# Then delete the renv/ folder
```

---

**Status**: Phase 1 Complete ✓  
**Last Updated**: November 1, 2025  
**Next Phase**: Phase 2 - Data & API Updates
