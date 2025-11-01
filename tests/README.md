# Test Scripts

Validation and testing scripts for the dashboard project.

## Available Tests

### Data & API Tests
- **test_eurostat_api.R** - Validates Eurostat API connectivity and data retrieval
- **test_data_download.R** - Tests data download functionality for all datasets

### Code Modernization Tests
- **test_code_modernization.R** - Verifies scripts load without RStudio dependencies
  - Tests data_load.R, industry analysis, transport analysis
  - Ensures portable path resolution with `here` package

### Sector-Specific Tests
- **test_countries.R** - Multi-country validation for industry sector
  - Tests 6 countries: Belgium, France, Germany, Austria, Spain, Italy
  - Validates NACE code presence (C17, C18), data completeness, year ranges

- **test_industry_transport_manual.R** - Manual testing script for industry and transport
  - Interactive test for Belgium
  - Tests full pipeline: data loading → processing → decomposition → charts
  - Useful for development and debugging
  
- **test_residential.R** - Residential sector data file validation
  - Checks for required feather files and old .Rda files
  
- **test_residential_load.R** - Residential sector data loading
  - Tests new load functions for household data
  - Validates data for Belgium, France, Germany

## Running Tests

```r
# Run a specific test
source(here::here("tests", "test_countries.R"))

# Or from command line
Rscript tests/test_countries.R
```

## Test Results Summary

✅ **Industry Sector**: Fully validated across 6 countries
- All countries have 96 NACE codes including C17, C18
- Data spans 1975-2024, 4800 rows per country

✅ **Code Modernization**: All scripts load without RStudio dependencies

✅ **Residential Sector Data**: Files exist and load correctly
- Integration into dashboard pending (see TODO_RESIDENTIAL.md)

## Adding New Tests

When adding new tests:
1. Name files with `test_` prefix
2. Add descriptive output with ✓/✗ symbols
3. Document the test purpose in this README
4. Include error handling with informative messages
