# TODO: Residential Sector Integration

## Status

**NOT IMPLEMENTED** - Deferred for future work

## Issue Description

The residential/household sector is not integrated into the dashboard. Investigation on 2 Nov 2025 identified the root cause.

## Root Cause

The household script (`scripts/2_household/households.R`) uses the **old data loading approach**:

- Lines 30-42: Loads combined `.Rda` files for ALL countries at once
- Expected files: `nrg_bal_c.Rda`, `nrg_d_hhq.Rda`, `nrg_chdd_a.Rda`, `demo_gind.Rda`, `ilc_lvph01.Rda`

However, the modernized data pipeline now creates **per-country `.feather` files**:

- `nrg_bal_c_BE.feather`, `nrg_d_hhq_FR.feather`, etc.
- This matches the industry and transport sectors

## Data Availability

✅ **All required data exists** in per-country feather format:

- `nrg_bal_c_*.feather` - Energy balance (347,616 rows per country, 1990-2023)
- `nrg_d_hhq_*.feather` - Disaggregated household energy (98 rows per country, 2010-2023)
- `nrg_chdd_a_*.feather` - Heating/cooling degree days (92 rows per country, 1979-2024)
- `demo_gind_*.feather` - Population demographics (66 rows per country, 1960-2025)
- `ilc_lvph01_*.feather` - Average household size (22 rows per country, 2003-2024)

✅ **Load functions added** to `scripts/0_support/data_load.R`:

- `load_household_energy_breakdown(country)`
- `load_household_demographics(country)`
- `load_household_size(country)`
- `load_heating_cooling_degree_days(country)`
- `load_industry_energy_consumption(country)` (for nrg_bal_c)

✅ **Tested successfully** for Belgium, France, Germany:

- All data loads correctly
- Household energy data (FC_OTH_HH_E) spans 1990-2023

## Required Work

### 1. Refactor Data Loading in `households.R`

**Current approach (lines 17-80):**

```r
household_final <- function(first_year, last_year, country, data_path, chart_path) {
  # Loads ALL countries from .Rda files
  load(paste0(data_path, "/nrg_bal_c.Rda"))
  load(paste0(data_path, "/nrg_d_hhq.Rda"))
  # ... etc
  
  # Uses country_list = geo_codes (all countries)
  country_list <- geo_codes
}
```

**Required approach (follow industry pattern):**

```r
household_final <- function(first_year, last_year, country, data_path, chart_path) {
  # Source data_load.R
  source(here("scripts", "0_support", "data_load.R"))
  
  # Load data for specific country
  nrg_bal_c <- load_industry_energy_consumption(country)
  nrg_d_hhq <- load_household_energy_breakdown(country)
  nrg_chdd_a <- load_heating_cooling_degree_days(country)
  demo_gind <- load_household_demographics(country)
  ilc_lvph01 <- load_household_size(country)
  
  # Process for single country
  country_code <- get_country_code(country)
}
```

### 2. Dashboard Integration

**Current state:**

- `ui.R` line 17: Menu item exists
- `ui.R` line 60: Tab item is **EMPTY**

**Required:**

- Add reactive data loading in `server.R` (similar to industry sector)
- Create charts/plots for residential energy decomposition
- Add UI panels with plotly outputs

### 3. Testing

After refactoring, test with multiple countries:

- Belgium, France, Germany, Austria, Spain, Italy
- Verify energy consumption decomposition works
- Check LMDI calculations for household sector

## Reference Implementation

See `scripts/1_industry/1a_industry_gva_final.R` and `scripts/server.R` (lines 18-100) for the pattern to follow:

1. Reactive data loading per country
2. Pass country-specific data to processing functions
3. Generate charts/plots for dashboard

## Files Modified (Prep Work Done)

- ✅ `scripts/0_support/data_load.R` - Added household load functions
- ✅ Created test scripts: `test_residential.R`, `test_residential_load.R`

## Files To Modify (Future Work)

- `scripts/2_household/households.R` - Refactor data loading
- `scripts/server.R` - Add residential reactive processing
- `scripts/ui.R` - Add residential charts/plots to tab

## Estimated Effort

**Medium** - Similar scope to industry sector integration (2-4 hours)

- Data loading refactor: 30 min
- Server integration: 1 hour  
- UI/charts integration: 1-2 hours
- Testing: 30 min

## Priority

**Low-Medium** - Dashboard works for Industry and Transport sectors. Residential is a nice-to-have for complete coverage.
