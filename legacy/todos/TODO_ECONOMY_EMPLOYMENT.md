# TODO: Economy-Wide Employment-Based Decomposition

## Status

**NOT IMPLEMENTED** - Batch processing only, not integrated into dashboard

## Current Implementation

The script `scripts/1_industry/1c_economy_emp_final.R` generates static charts for **economy-wide final energy consumption**, decomposed by employment across economic sectors.

**Key Difference from Current Dashboard:**

- Dashboard (1a): Industry decomposed by Gross Value Added (GVA)
- This script (1c): Full economy decomposed by employment (number of workers)

## Root Cause

The script uses the **old data loading approach**:

- Lines 38-41: Loads combined `.Rda` files for ALL countries at once
- Expected files: `nrg_bal_c.Rda`, `nama_10_a10_e.Rda`

However, the modernized data pipeline now creates **per-country `.feather` files**:

- `nrg_bal_c_BE.feather`, `nama_10_a10_e_FR.feather`, etc.

## Data Availability

✅ **All required data exists** in per-country feather format:

- `nrg_bal_c_*.feather` - Energy balance (347,616 rows per country, 1990-2023)
- `nama_10_a10_e_*.feather` - Employment by NACE A10 sectors (7,832 rows per country, 1995-2023)

✅ **Load functions already exist** in `scripts/0_support/data_load.R`:

- `load_industry_energy_consumption(country)` - for nrg_bal_c (covers all sectors)
- `load_employment_by_sector(country)` - for nama_10_a10_e

## Technical Details

### Decomposition Approach

**Employment-Based LMDI:**

1. **Activity Effect**: Changes in total employment (number of workers)
2. **Structure Effect**: Shifts between economic sectors (e.g., manufacturing → services)
3. **Intensity Effect**: Changes in energy per worker (energy productivity)

**Key Insight:** Different from GVA-based decomposition

- GVA measures economic value created
- Employment measures labor input
- Shows if economy is becoming more energy-efficient per worker

### Sector Coverage

Uses NACE A10 classification (broader than A64):

- **A**: Agriculture, forestry and fishing
- **B-E**: Industry (including energy)
- **F**: Construction
- **G-I**: Trade, transport, accommodation
- **J**: Information and communication
- **K**: Financial and insurance
- **L**: Real estate
- **M-N**: Professional and administrative services
- **O-Q**: Public admin, education, health
- **R-U**: Arts, entertainment, other services

### Chart Types (lines 50-1542)

The script generates comprehensive static charts:

- Waterfall charts (LMDI decomposition by sector)
- Time series (employment vs energy trends)
- Sector comparisons (energy intensity per worker)
- Cross-country benchmarking

## Required Work

### 1. Refactor Data Loading (lines 32-50)

**Current approach:**

```r
economy_emp_final <- function(first_year, last_year, country, data_path, chart_path) {
  load(paste0(data_path, "/nrg_bal_c.Rda"))
  load(paste0(data_path, "/nama_10_a10_e.Rda"))
  
  country_list <- geo_codes  # All countries
}
```

**Modernized approach:**

```r
economy_emp_final <- function(first_year, last_year, country) {
  source("scripts/0_support/data_load.R")
  
  nrg_bal_c <- load_industry_energy_consumption(country)  # Full energy balance
  nama_10_a10_e <- load_employment_by_sector(country)
  
  country_list <- c(country)  # Single country
}
```

### 2. Add Dashboard UI Tab (scripts/ui.R)

Add new tab for economy-wide analysis:

```r
tabPanel("Economy (by Employment)",
  fluidRow(
    column(12,
      h3("Economy-Wide Energy Consumption - Employment Decomposition"),
      p("LMDI decomposition: Activity (employment) × Structure (sector shifts) × Intensity (energy per worker)"),
      plotlyOutput("economy_emp_waterfall", height = "600px"),
      plotlyOutput("economy_emp_trends", height = "400px"),
      plotlyOutput("economy_emp_sectors", height = "400px")
    )
  )
)
```

### 3. Add Server Logic (scripts/server.R)

Create reactive expressions:

```r
economy_emp_data <- reactive({
  req(input$country, input$year_range)
  
  source("scripts/1_industry/1c_economy_emp_final.R")
  result <- economy_emp_final(
    first_year = input$year_range[1],
    last_year = input$year_range[2],
    country = input$country
  )
  result
})

output$economy_emp_waterfall <- renderPlotly({
  data <- economy_emp_data()
  # Convert ggplot to plotly
  ggplotly(data$waterfall_chart)
})

output$economy_emp_trends <- renderPlotly({
  data <- economy_emp_data()
  ggplotly(data$trends_chart)
})
```

### 4. Adapt Chart Generation (lines 50+)

**Current:** Functions save static files to `output/` folder

```r
ggsave(filename = paste0(chart_path, "/economy_emp_waterfall.png"), ...)
```

**Needed:** Functions return ggplot objects

```r
create_economy_emp_waterfall <- function(data) {
  p <- ggplot(data, ...) + ...
  return(p)  # Return for plotly conversion
}
```

### 5. Test Data Pipeline

Verify per-country data loading:

```r
source("scripts/0_support/data_load.R")
nrg_bal_c_be <- load_industry_energy_consumption("BE")
nama_10_a10_e_be <- load_employment_by_sector("BE")

# Check data ranges
summary(nama_10_a10_e_be)  # Should show 1995-2023
```

## Benefits of Integration

- **Labor Productivity View**: Energy efficiency per worker (complements GVA-based view)
- **Structural Change Analysis**: See how economy shifts between sectors (manufacturing → services)
- **Policy Relevance**: Links energy policy to employment/labor markets
- **Cross-Sector Insights**: Covers entire economy (not just industry or transport)

## Complexity: Medium-High

**Estimated Effort:** 5-8 hours

- Data loading refactor: 1-2 hours (employment data may need validation)
- Chart adaptation: 3-4 hours (complex multi-sector visualizations)
- UI/Server integration: 1-2 hours
- Testing: 1 hour

## Priority

**Medium** - Provides economy-wide perspective that current dashboard lacks. Shows labor productivity angle (complementary to GVA-based industry analysis).

## Dependencies

- ✅ Data pipeline modernized (feather files exist)
- ✅ Load functions available in data_load.R
- ⚠️ Employment data coverage: Check if all countries have complete data (1995-2023)

## Notes

- **Sector Aggregation**: Uses NACE A10 (10 sectors) vs A64 (64 subsectors in industry)
- **Data Completeness**: Employment data may have gaps for some countries/years
- **Comparison Opportunity**: Could add side-by-side view of GVA-based vs employment-based decomposition
- **Broader Scope**: This is truly economy-wide (includes services), not just industry

## Related Analysis

Consider pairing with:

- Industry GVA decomposition (1a) - compare economic value vs labor input
- Transport VKM decomposition (3) - another activity-based metric
- Residential sector (TODO_RESIDENTIAL.md) - complete sectoral coverage
