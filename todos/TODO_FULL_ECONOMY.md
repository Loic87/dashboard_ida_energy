# TODO: Full Economy Energy Analysis

## Status

**NOT IMPLEMENTED** - Batch processing only, not integrated into dashboard

## Current Implementation

The script `scripts/4_all_sectors/full_energy.R` generates static charts for **full economy total energy consumption** across all sectors and energy products.

**Key Difference from Current Dashboard:**

- Dashboard: Sector-specific decompositions (Industry, Transport)
- This script: Aggregate view of entire energy system

## Root Cause

The script uses the **old data loading approach**:

- Line 36: Loads combined `.Rda` file for ALL countries at once
- Expected file: `nrg_bal_c.Rda`

However, the modernized data pipeline now creates **per-country `.feather` files**:

- `nrg_bal_c_BE.feather`, `nrg_bal_c_FR.feather`, etc.

## Data Availability

✅ **All required data exists** in per-country feather format:

- `nrg_bal_c_*.feather` - Complete energy balance (347,616 rows per country, 1990-2023)
  - All sectors: Industry (FC_IND_E), Transport (FC_TRA_E), Residential (FC_OTH_HH_E), Services, Agriculture
  - All energy products: Electricity, Gas, Oil products, Coal, Renewables, Heat
  - All flows: Final energy, Primary energy, Transformation, Losses

✅ **Load function already exists** in `scripts/0_support/data_load.R`:

- `load_industry_energy_consumption(country)` - loads full nrg_bal_c (not just industry)

## Technical Details

### Scope: Total Energy System

**Coverage (from nrg_bal_c):**

1. **Final Energy Consumption** by sector:
   - Industry (FC_IND_E)
   - Transport (FC_TRA_E)
   - Residential/Households (FC_OTH_HH_E)
   - Commercial/Services (FC_OTH_CP_E)
   - Agriculture (FC_OTH_AF_E)
   - Non-energy use (FC_NE)

2. **Energy Products:**
   - Electricity (E7000)
   - Natural gas (G3000)
   - Oil products (O4000XBIO, O4100, etc.)
   - Solid fuels (C0000X0350-0370)
   - Renewables (RA000, RA100, etc.)
   - Heat (H8000)

3. **Energy Flows:**
   - Primary production (PPRD)
   - Imports/Exports (IMP, EXP)
   - Transformation (TI, TO)
   - Distribution losses (DL)
   - Final consumption (FC)

### Analysis Types (lines 40-348)

The script produces high-level overview charts:

- **Sankey diagrams**: Energy flows from primary to final
- **Stacked area charts**: Total consumption by sector over time
- **Product mix charts**: Share of electricity, gas, oil, renewables
- **Context charts**: Energy consumption vs GDP, population, degree days

**No LMDI decomposition** - this is a descriptive/exploratory analysis, not causal decomposition.

## Required Work

### 1. Refactor Data Loading (lines 24-40)

**Current approach:**

```r
full_energy_final <- function(first_year, last_year, country, data_path, chart_path) {
  load(paste0(data_path, "/nrg_bal_c.Rda"))
  
  # Processes all countries at once
  country_list <- geo_codes
}
```

**Modernized approach:**

```r
full_energy_final <- function(first_year, last_year, country) {
  source("scripts/0_support/data_load.R")
  
  nrg_bal_c <- load_industry_energy_consumption(country)  # Full energy balance
  
  country_list <- c(country)  # Single country
}
```

### 2. Add Dashboard UI Tab (scripts/ui.R)

Add new tab for economy-wide energy overview:

```r
tabPanel("Full Economy",
  fluidRow(
    column(12,
      h3("Total Energy System Overview"),
      p("Aggregate energy consumption across all sectors and energy products"),
      
      h4("Energy Balance"),
      plotlyOutput("full_energy_sankey", height = "500px"),
      
      h4("Sectoral Breakdown"),
      plotlyOutput("full_energy_sectors", height = "400px"),
      
      h4("Energy Product Mix"),
      plotlyOutput("full_energy_products", height = "400px"),
      
      h4("Context Indicators"),
      plotlyOutput("full_energy_context", height = "400px")
    )
  )
)
```

### 3. Add Server Logic (scripts/server.R)

Create reactive expressions:

```r
full_energy_data <- reactive({
  req(input$country, input$year_range)
  
  source("scripts/4_all_sectors/full_energy.R")
  result <- full_energy_final(
    first_year = input$year_range[1],
    last_year = input$year_range[2],
    country = input$country
  )
  result
})

output$full_energy_sankey <- renderPlotly({
  data <- full_energy_data()
  # May need special handling for Sankey diagrams
  data$sankey_chart
})

output$full_energy_sectors <- renderPlotly({
  data <- full_energy_data()
  ggplotly(data$sectors_chart)
})

output$full_energy_products <- renderPlotly({
  data <- full_energy_data()
  ggplotly(data$products_chart)
})
```

### 4. Adapt Chart Generation (lines 40-348)

**Current:** Functions save static files to `output/` folder

```r
ggsave(filename = paste0(chart_path, "/full_energy_overview.png"), ...)
```

**Needed:** Functions return ggplot/plotly objects

```r
create_full_energy_overview <- function(data) {
  p <- ggplot(data, ...) + ...
  return(p)
}

create_energy_sankey <- function(data) {
  # Sankey may need plotly directly (not ggplot)
  plot_ly(data, type = "sankey", ...)
}
```

### 5. Test Data Pipeline

Verify data loading covers all sectors:

```r
source("scripts/0_support/data_load.R")
nrg_bal_c_be <- load_industry_energy_consumption("BE")

# Check sector coverage
unique(nrg_bal_c_be$siec)  # Should include FC_IND_E, FC_TRA_E, FC_OTH_HH_E, etc.
unique(nrg_bal_c_be$nrg_bal)  # Energy products
```

### 6. Consider Interactive Features

Since this is an overview tab, add interactivity:

- **Hover details**: Show exact values, percentages
- **Click-through**: Link to sector-specific tabs (e.g., click "Industry" → go to Industry tab)
- **Comparison mode**: Side-by-side view of two time periods
- **Download data**: Export underlying data tables

## Benefits of Integration

- **Big Picture View**: Users see total energy system before diving into sectors
- **Context Setting**: Understand relative size of sectors (e.g., transport vs industry)
- **Product Mix Analysis**: Track shift from fossil fuels to renewables/electricity
- **Navigation Hub**: Entry point that links to detailed sector analyses

## Complexity: Low-Medium

**Estimated Effort:** 3-5 hours

- Data loading refactor: 30 minutes (simpler than others - only nrg_bal_c)
- Chart adaptation: 2-3 hours (Sankey diagrams may need special handling)
- UI/Server integration: 1 hour
- Testing: 1 hour

## Priority

**High** - This provides essential context and should be the **first tab** users see. It's a natural entry point before diving into sector-specific decompositions.

## Dependencies

- ✅ Data pipeline modernized (feather files exist)
- ✅ Load function available in data_load.R
- ⚠️ Sankey diagram library: May need `networkD3` or `plotly` sankey support

## Notes

- **Tab Ordering**: Consider making this the first tab (before Industry)
- **Simplicity**: This is the simplest script to integrate (only one data source)
- **Navigation**: Could add buttons/links to jump to sector-specific tabs
- **Completeness**: Once integrated, dashboard will cover all major energy sectors

## Recommended Approach

Start with this script for integration practice:

1. ✅ Single data source (nrg_bal_c only)
2. ✅ No complex decomposition logic (just aggregation/visualization)
3. ✅ Provides immediate user value (overview tab)
4. Then use lessons learned for more complex scripts (1b, 1c, households)

## User Experience Flow

Suggested dashboard tab order:

1. **Full Economy** (this) - Overview and context
2. **Industry (Final Energy)** (existing 1a) - Detailed industry analysis
3. **Industry (Primary Energy)** (TODO 1b) - Upstream impacts
4. **Transport** (existing 3) - Transport decomposition
5. **Residential** (TODO households) - Household energy
6. **Economy (Employment)** (TODO 1c) - Labor productivity view

This creates a logical flow: Overview → Detailed sector analyses → Alternative perspectives.
