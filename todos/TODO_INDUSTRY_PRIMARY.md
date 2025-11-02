# TODO: Industry Primary Energy Decomposition

## Status

**NOT IMPLEMENTED** - Batch processing only, not integrated into dashboard

## Current Implementation

The script `scripts/1_industry/1b_industry_gva_primary.R` generates static charts for **primary energy consumption** in the industry sector, decomposed by NACE sectors.

**Key Difference from Current Dashboard:**

- Dashboard (1a): Final energy consumption (direct energy use)
- This script (1b): Primary energy consumption (includes upstream energy losses)

## Root Cause

The script uses the **old data loading approach**:

- Lines 39-42: Loads combined `.Rda` files for ALL countries at once
- Expected files: `nrg_bal_c.Rda`, `nama_10_a64.Rda`

However, the modernized data pipeline now creates **per-country `.feather` files**:

- `nrg_bal_c_BE.feather`, `nama_10_a64_FR.feather`, etc.

## Data Availability

✅ **All required data exists** in per-country feather format:

- `nrg_bal_c_*.feather` - Energy balance with primary energy data (347,616 rows per country, 1990-2023)
- `nama_10_a64_*.feather` - Industry GVA by NACE A64 sectors (36,372 rows per country, 1975-2023)

✅ **Load functions already exist** in `scripts/0_support/data_load.R`:

- `load_industry_energy_consumption(country)` - for nrg_bal_c
- `load_industry_gva(country)` - for nama_10_a64

## Technical Details

### Energy Flow Types

**Primary Energy (this script):**

- Captures total energy including transformation losses
- Flow: `FC_IND_E` (final) + upstream losses (electricity generation, refining, etc.)
- More complete picture of energy system impact

**Final Energy (dashboard 1a):**

- Direct energy consumed by industry
- Flow: `FC_IND_E` only
- What industries actually use

### Decomposition Structure

Same LMDI approach as 1a, but with primary energy:

1. **Activity Effect**: Changes in economic output (GVA by NACE sector)
2. **Structure Effect**: Shifts between industrial subsectors
3. **Intensity Effect**: Changes in energy efficiency (primary energy per unit GVA)

### Chart Types (lines 100-1879)

The script generates extensive static charts:

- Waterfall charts (LMDI decomposition)
- Time series (energy consumption trends)
- Sector breakdowns (NACE A64 classification)
- Cross-country comparisons

## Required Work

### 1. Refactor Data Loading (lines 32-60)

**Current approach:**

```r
industry_GVA_primary <- function(first_year, last_year, country, data_path, chart_path) {
  load(paste0(data_path, "/nrg_bal_c.Rda"))
  load(paste0(data_path, "/nama_10_a64.Rda"))
  
  country_list <- geo_codes  # All countries
}
```

**Modernized approach:**

```r
industry_GVA_primary <- function(first_year, last_year, country) {
  source("scripts/0_support/data_load.R")
  
  nrg_bal_c <- load_industry_energy_consumption(country)
  nama_10_a64 <- load_industry_gva(country)
  
  country_list <- c(country)  # Single country
}
```

### 2. Add Dashboard UI Tab (scripts/ui.R)

Add new tab after "Industry (Final Energy)":

```r
tabPanel("Industry (Primary Energy)",
  fluidRow(
    column(12,
      h3("Primary Energy Consumption in Industry"),
      p("Includes upstream transformation losses (electricity generation, refining, etc.)"),
      plotlyOutput("industry_primary_waterfall", height = "600px"),
      plotlyOutput("industry_primary_trends", height = "400px")
    )
  )
)
```

### 3. Add Server Logic (scripts/server.R)

Create reactive expressions similar to `industry_final_data`:

```r
industry_primary_data <- reactive({
  req(input$country, input$year_range)
  
  source("scripts/1_industry/1b_industry_gva_primary.R")
  result <- industry_GVA_primary(
    first_year = input$year_range[1],
    last_year = input$year_range[2],
    country = input$country
  )
  result
})

output$industry_primary_waterfall <- renderPlotly({
  data <- industry_primary_data()
  # Convert ggplot to plotly
  ggplotly(data$waterfall_chart)
})
```

### 4. Adapt Chart Generation (lines 100+)

**Current:** Functions save static PNG/JPG files to `output/` folder

```r
ggsave(filename = paste0(chart_path, "/industry_primary_waterfall.png"), ...)
```

**Needed:** Functions return ggplot objects for conversion to plotly

```r
create_industry_primary_waterfall <- function(data) {
  p <- ggplot(data, ...) + ...
  return(p)  # Return ggplot object
}
```

### 5. Test Data Pipeline

Verify per-country data loading works:

```r
source("scripts/0_support/data_load.R")
nrg_bal_c_be <- load_industry_energy_consumption("BE")
nama_10_a64_be <- load_industry_gva("BE")
```

## Benefits of Integration

- **Comprehensive View**: Users can compare final vs primary energy
- **Policy Insights**: Primary energy shows true environmental impact
- **Interactive Exploration**: Drill down by NACE sector and time period
- **Consistency**: Same UX as existing dashboard tabs

## Complexity: Medium

**Estimated Effort:** 4-6 hours

- Data loading refactor: 1 hour
- Chart adaptation: 2-3 hours (many charts in script)
- UI/Server integration: 1 hour
- Testing: 1 hour

## Priority

**Low** - Dashboard already has final energy for industry (1a). Primary energy provides additional context but is not essential for basic analysis.

## Dependencies

- ✅ Data pipeline modernized (feather files exist)
- ✅ Load functions available in data_load.R
- ⏳ Residential sector (TODO_RESIDENTIAL.md) - similar refactoring pattern

## Notes

- Script is well-structured with clear LMDI decomposition logic
- Main work is adapting from batch processing to interactive dashboard
- Consider adding toggle or tabs to switch between final/primary energy views
