source("1_industry/1a_industry_gva_final.R")
source("4_all_sectors/shared.R")

server <- function(input, output) {
  first_year <- reactive(input$YearRange[1])
  last_year <- reactive(input$YearRange[2])
  country <- reactive(input$country)
  
  # Load data
  nrg_bal_c <- reactive(load_industry_energy_consumption(country()))
  
  nama_10_a64 <- reactive(load_industry_GVA(country()))
  
  # Energy consumption by fuel
  industry_energy_consumption_by_product <- reactive({
    prepare_energy_product_breakdown(
      nrg_bal_c = nrg_bal_c(),
      first_year = first_year(),
      last_year = last_year()
    )
  })
  
  # energy consumption (and supply) from the energy balance (nrg_bal_c)
  industry_energy_consumption_by_sector <- reactive({
    prepare_energy_consumption(
      nrg_bal_c = nrg_bal_c(),
      first_year = first_year(),
      last_year = last_year()
    )
  })
  
  # economic activity from the national account data (nama_10_a64)
  industry_GVA_by_sector <- reactive({
    prepare_activity(
      nama_10_a64 = nama_10_a64(),
      first_year = first_year(),
      last_year = last_year()
    )
  })
  
  industry_GVA_final_LMDI <- reactive({
    prepare_decomposition(
      industry_GVA_by_sector(),
      industry_energy_consumption_by_sector(),
      first_year = first_year(),
      last_year = last_year()
    )
  })
  
  output$industry_energy_consumption_by_product <- renderPlotly({
    p <- prepare_industry_energy_consumption_by_product_charts(
      industry_energy_consumption_by_product(),
      country()
    )
    ggplotly(p)
  })
  
  output$industry_energy_consumption_by_sector <- renderPlotly({
    p <- prepare_industry_energy_consumption_by_sector_charts(
      industry_energy_consumption_by_sector(),
      country()
    )
    ggplotly(p)
  })
  
  output$industry_GVA_by_sector <- renderPlotly({
    p <-prepare_industry_GVA_by_sector_charts(
      industry_GVA_by_sector(),
      country()
    )
    ggplotly(p)
  })
  
  output$industry_GVA_final_waterfall <- renderPlotly({
    p <- prepare_waterfall_chart(
        industry_GVA_final_LMDI(),
        first_year = first_year(),
        last_year = last_year(),
        country = country()
      )
    ggplotly(p)
  })
  
  output$industry_GVA_final_intensity_effects<- renderPlotly({
    # Plot the intensity effect as area chart
    p <- prepare_intensity_effects_chart(
      industry_GVA_final_LMDI(),
      first_year = first_year(),
      last_year = last_year(),
      country = country()
    )
    ggplotly(p)
  })
}