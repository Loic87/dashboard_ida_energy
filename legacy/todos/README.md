# TODO: Future Dashboard Integrations

This folder contains detailed implementation plans for energy decompositions that are **not yet integrated** into the interactive dashboard.

## Overview

All scripts in this folder currently exist as **batch processing scripts** that generate static charts. They use the old `.Rda` data loading approach and need to be modernized to work with the dashboard's per-country `.feather` files and interactive plotly charts.

## Recommended Implementation Order

### 1. Full Economy Energy Analysis (Priority: HIGH)

**File:** [`TODO_FULL_ECONOMY.md`](./TODO_FULL_ECONOMY.md)  
**Script:** `scripts/4_all_sectors/full_energy.R`  
**Complexity:** Low-Medium (3-5 hours)

High-level overview of the total energy system across all sectors and products. Should be the **first tab** in the dashboard to provide context before sector-specific details.

**Why first:**

- Simplest integration (only one data source)
- Provides essential context for users
- Natural entry point before detailed decompositions

---

### 2. Residential Sector (Priority: MEDIUM-HIGH)

**File:** [`TODO_RESIDENTIAL.md`](./TODO_RESIDENTIAL.md)  
**Script:** `scripts/2_household/households.R`  
**Complexity:** Medium-High (6-10 hours)

Household/residential energy consumption decomposition. Important for complete sectoral coverage (currently missing from dashboard).

**Key challenges:**

- Multiple data sources (5 datasets)
- Complex heating degree day adjustments
- Household demographics integration

---

### 3. Economy-Wide Employment Decomposition (Priority: MEDIUM)

**File:** [`TODO_ECONOMY_EMPLOYMENT.md`](./TODO_ECONOMY_EMPLOYMENT.md)  
**Script:** `scripts/1_industry/1c_economy_emp_final.R`  
**Complexity:** Medium-High (5-8 hours)

Full economy energy consumption decomposed by employment (workers) instead of GVA. Provides labor productivity perspective.

**Key insights:**

- Energy efficiency per worker
- Structural changes (manufacturing → services)
- Links energy policy to labor markets

---

### 4. Industry Primary Energy (Priority: LOW)

**File:** [`TODO_INDUSTRY_PRIMARY.md`](./TODO_INDUSTRY_PRIMARY.md)  
**Script:** `scripts/1_industry/1b_industry_gva_primary.R`  
**Complexity:** Medium (4-6 hours)

Industry energy consumption using **primary energy** (includes upstream transformation losses) instead of final energy.

**Why lower priority:**

- Dashboard already has industry final energy decomposition
- Primary energy provides additional context but not essential
- Could be added as toggle/tab within existing Industry section

---

## Common Integration Pattern

All TODO files follow the same refactoring pattern:

### 1. Data Loading Modernization

**Old approach:**

```r
load(paste0(data_path, "/dataset.Rda"))  # All countries
country_list <- geo_codes
```

**New approach:**

```r
source("scripts/0_support/data_load.R")
dataset <- load_dataset_function(country)  # Single country
country_list <- c(country)
```

### 2. Dashboard Integration

- Add UI tab in `scripts/ui.R`
- Add reactive logic in `scripts/server.R`
- Adapt chart functions to return ggplot/plotly objects (not save files)

### 3. Testing

- Verify per-country data loading
- Test with multiple countries
- Validate chart interactivity

---

## Data Availability

✅ **All required data exists** in per-country `.feather` format:

- Energy balance: `nrg_bal_c_*.feather`
- Industry GVA: `nama_10_a64_*.feather`, `nama_10_a10_e_*.feather`
- Household data: `nrg_d_hhq_*.feather`, `demo_gind_*.feather`, etc.
- Transport data: Already integrated in dashboard

✅ **Load functions available** in `scripts/0_support/data_load.R`

---

## Related Documentation

- **Project Structure:** [`../README.md`](../README.md)
- **Setup Guide:** [`../docs/SETUP_GUIDE.md`](../docs/SETUP_GUIDE.md)
- **Development History:** [`../docs/history/`](../docs/history/)

---

## Contributing

When implementing any of these TODOs:

1. Follow the integration pattern outlined in the specific TODO file
2. Test thoroughly with multiple countries and year ranges
3. Update the main [`README.md`](../README.md) project structure
4. Mark the TODO file as complete or move to `docs/history/`
5. Commit with clear message linking to the TODO file

---

Last updated: 2 November 2025
