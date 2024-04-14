library(plotly)

source("1_industry/1a_industry_gva_final.R")
source("0_support/data_load.R")

warning_duration = 5

server <- function(input, output) {
  first_year <- reactive(input$YearRange[1])
  last_year <- reactive(input$YearRange[2])
  country <- reactive(input$country)
  
  # Load data
  nrg_bal_c <- reactive(load_industry_energy_consumption(country()))
  nama_10_a64 <- reactive(load_industry_GVA(country()))
  
  # Energy consumption by fuel
  industry_energy_consumption_by_product <- reactive({
    prepare_industry_energy_consumption_by_product(
      nrg_bal_c = nrg_bal_c(),
      first_year = first_year(),
      last_year = last_year()
    )
  })
  
  # energy consumption (and supply) from the energy balance (nrg_bal_c)
  industry_energy_consumption_by_sector <- reactive({
    prepare_industry_energy_consumption_by_sector(
      nrg_bal_c = nrg_bal_c(),
      first_year = first_year(),
      last_year = last_year()
    )
  })
  
  # economic activity from the national account data (nama_10_a64)
  industry_GVA_by_sector <- reactive({
    prepare_industry_GVA_by_sector(
      nama_10_a64 = nama_10_a64(),
      first_year = first_year(),
      last_year = last_year()
    )
  })
  
  observe({
    result <- industry_GVA_by_sector()
    if (!is.null(result$notifications) && length(result$notifications) > 0) {
      for (warning in result$notifications) {
        showNotification(warning, type = "warning", duration = warning_duration)
      }
    }
  })
  
  industry_GVA_final_full <- reactive({
    prepare_industry_GVA_decomposition(
      industry_GVA_by_sector()$df,
      industry_energy_consumption_by_sector(),
      first_year = first_year(),
      last_year = last_year()
    )
  })
  
  observe({
    result <- industry_GVA_final_full()
    if (!is.null(result$notifications) && length(result$notifications) > 0) {
      for (warning in result$notifications) {
        showNotification(warning, type = "warning", duration = warning_duration)
      }
    }
  })
  
  industry_GVA_final_LMDI <- reactive({
    apply_LMDI_industry_gva(
      industry_GVA_final_full()$df,
      first_year = first_year()
    )
  })
  
  output$industry_energy_consumption_by_product_plot <- renderPlotly({
    p <- prepare_industry_energy_consumption_by_product_charts(
      industry_energy_consumption_by_product(),
      country()
    )
    ggplotly(p)
  })
  
  output$industry_energy_consumption_by_sector_plot <- renderPlotly({
    p <- prepare_industry_energy_consumption_by_sector_charts(
      industry_energy_consumption_by_sector(),
      country()
    )
    ggplotly(p)
  })
  
  output$industry_GVA_by_sector_plot <- renderPlotly({
    p <-prepare_industry_GVA_by_sector_charts(
      industry_GVA_by_sector()$df,
      country()
    )
    ggplotly(p)
  })
  
  output$industry_GVA_indexed_plot <- renderPlotly({
    validate(
      need(nrow(industry_GVA_final_full()$df) > 0, "Please select years with data available")
    )
    p <- prepare_indexed_chart(
      industry_GVA_final_full()$df,
      first_year = first_year(),
      country = country()
    )
    ggplotly(p)
  })
  
  output$industry_GVA_final_waterfall_plot <- renderPlotly({
    validate(
      need(nrow(industry_GVA_final_LMDI()) > 0, "Please select years with data available")
    )
    p <- prepare_waterfall_chart(
        industry_GVA_final_LMDI(),
        first_year = first_year(),
        last_year = last_year(),
        country = country()
      )
    ggplotly(p)
  })
  
  output$industry_GVA_final_intensity_effects_plot <- renderPlotly({
    validate(
      need(nrow(industry_GVA_final_LMDI()) > 0, "Please select years with data available")
    )
    p <- prepare_intensity_effects_chart(
      industry_GVA_final_LMDI(),
      first_year = first_year(),
      last_year = last_year(),
      country = country()
    )
    ggplotly(p)
  })
}