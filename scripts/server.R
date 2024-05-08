library(plotly)

source("0_support/data_load.R")
source("1_industry/1a_industry_gva_final.R")
source("3_transport/transport_VKM.R")

warning_duration = 5

server <- function(input, output) {
  first_year <- reactive(input$YearRange[1])
  last_year <- reactive(input$YearRange[2])
  country <- reactive(input$country)
  
  # Load data
  nrg_bal_c <- reactive(load_industry_energy_consumption(country()))
  nama_10_a64 <- reactive(load_industry_GVA(country()))
  road_tf_vehmov = reactive(load_road_vkm(country()))
  rail_tf_trainmv = reactive(load_rail_vkm(country()))
  iww_tf_vetf = reactive(load_iwww_vkm(country()))
  
  # Industry GVA decomposition

  ## Industry energy consumption by fuel
  industry_energy_consumption_by_product <- reactive({
    prepare_industry_energy_consumption_by_product(
      nrg_bal_c = nrg_bal_c(),
      first_year = first_year(),
      last_year = last_year()
    )
  })

  ## Industry energy consumption by sector
  industry_energy_consumption_by_sector <- reactive({
    prepare_industry_energy_consumption_by_sector(
      nrg_bal_c = nrg_bal_c(),
      first_year = first_year(),
      last_year = last_year()
    )
  })

  ## Industry economic activity (GVA) by sector
  industry_GVA_by_sector <- reactive({
    prepare_industry_GVA_by_sector(
      nama_10_a64 = nama_10_a64(),
      first_year = first_year(),
      last_year = last_year()
    )
  })

  ## Show warnings
  observe({
    result <- industry_GVA_by_sector()
    if (!is.null(result$notifications) && length(result$notifications) > 0) {
      for (warning in result$notifications) {
        showNotification(warning, type = "warning", duration = warning_duration)
      }
    }
  })

  ## Industry GVA decomposition
  industry_GVA_final_full <- reactive({
    prepare_industry_GVA_decomposition(
      industry_GVA_by_sector()$df,
      industry_energy_consumption_by_sector(),
      first_year = first_year(),
      last_year = last_year()
    )
  })

  ## Show warnings
  observe({
    result <- industry_GVA_final_full()
    if (!is.null(result$notifications) & length(result$notifications) > 0) {
      for (warning in result$notifications) {
        showNotification(warning, type = "warning", duration = warning_duration)
      }
    }
  })

  ## Apply LMDI decomposition
  industry_GVA_final_LMDI <- reactive({
    apply_LMDI_industry_gva(
      industry_GVA_final_full()$df,
      first_year = first_year()
    )
  })

  ## Plot energy consumption by product
  output$industry_energy_consumption_by_product_plot <- renderPlotly({
    p <- prepare_industry_energy_consumption_by_product_charts(
      industry_energy_consumption_by_product(),
      country()
    )
    ggplotly(p)
  })

  ## Plot energy consumption by sector
  output$industry_energy_consumption_by_sector_plot <- renderPlotly({
    p <- prepare_industry_energy_consumption_by_sector_charts(
      industry_energy_consumption_by_sector(),
      country()
    )
    ggplotly(p)
  })

  ## Plot GVA by sector
  output$industry_GVA_by_sector_plot <- renderPlotly({
    p <-prepare_industry_GVA_by_sector_charts(
      industry_GVA_by_sector()$df,
      country()
    )
    ggplotly(p)
  })

  ## Plot indexed indicators
  output$industry_GVA_indexed_plot <- renderPlotly({
    validate(
      need(nrow(industry_GVA_final_full()$df) > 0, "Please select years with data available")
    )
    p <- prepare_industry_indexed_chart(
      industry_GVA_final_full()$df,
      first_year = first_year(),
      country = country()
    )
    ggplotly(p)
  })

  ## Plot waterfall chart
  output$industry_GVA_final_waterfall_plot <- renderPlotly({
    validate(
      need(nrow(industry_GVA_final_LMDI()) > 0, "Please select years with data available")
    )
    p <- prepare_industry_waterfall_chart(
        industry_GVA_final_LMDI(),
        first_year = first_year(),
        last_year = last_year(),
        country = country()
      )
    ggplotly(p)
  })

  ## Plot intensity effects
  output$industry_GVA_final_intensity_effects_plot <- renderPlotly({
    validate(
      need(nrow(industry_GVA_final_LMDI()) > 0, "Please select years with data available")
    )
    p <- prepare_industry_intensity_effects_chart(
      industry_GVA_final_LMDI(),
      first_year = first_year(),
      last_year = last_year(),
      country = country()
    )
    ggplotly(p)
  })

  # Transport VKM decomposition

  ## Transport energy consumption by fuel
  transport_energy_consumption_by_product <- reactive({
    prepare_transport_energy_consumption_by_product(
      nrg_bal_c = nrg_bal_c(),
      first_year = first_year(),
      last_year = last_year()
    )
  })

  ## Transport energy consumption by sector
  transport_energy_consumption_by_mode <- reactive({
    prepare_transport_energy_consumption_by_mode(
      nrg_bal_c = nrg_bal_c(),
      first_year = first_year(),
      last_year = last_year()
    )
  })

  ## Transport activity (VKM) by sector
  transport_VKM_by_mode <- reactive({
    prepare_transport_vkm(
      road_tf_vehmov = road_tf_vehmov(),
      rail_tf_trainmv = rail_tf_trainmv(),
      iww_tf_vetf = iww_tf_vetf(),
      first_year = first_year(),
      last_year = last_year()
    )
  })

  ## Show warnings
  observe({
    result <- transport_VKM_by_mode()
    if (!is.null(result$notifications) && length(result$notifications) > 0) {
      for (warning in result$notifications) {
        showNotification(warning, type = "warning", duration = warning_duration)
      }
    }
  })

  ## Transport VKM decomposition
  transport_VKM_full <- reactive({
    prepare_transport_vkm_decomposition(
      transport_VKM_by_mode(),
      transport_energy_consumption_by_mode(),
      first_year = first_year(),
      last_year = last_year()
    )
  })

  ## Show warnings
  observe({
    result <- transport_VKM_full()
    if (!is.null(result$notifications) && length(result$notifications) > 0) {
      for (warning in result$notifications) {
        showNotification(warning, type = "warning", duration = warning_duration)
      }
    }
  })

  ## Apply LMDI decomposition
  transport_VKM_LMDI <- reactive({
    apply_LMDI_transport_vkm(
      transport_VKM_full()$df,
      first_year = first_year()
    )
  })

  ## Plot energy consumption by product
  output$transport_energy_consumption_by_product_plot <- renderPlotly({
    p <- prepare_transport_energy_consumption_by_product_charts(
      transport_energy_consumption_by_product(),
      country()
    )
    ggplotly(p)
  })

  ## Plot energy consumption by sector
  output$transport_energy_consumption_by_mode_plot <- renderPlotly({
    p <- prepare_transport_energy_consumption_by_mode_charts(
      transport_energy_consumption_by_mode(),
      country()
    )
    ggplotly(p)
  })

  ## Plot VKM by sector
  output$transport_VKM_by_mode_plot <- renderPlotly({
    p <- prepare_transport_VKM_by_mode_charts(
      transport_VKM_by_mode(),
      country()
    )
    ggplotly(p)
  })

  ## Plot indexed indicators
  output$transport_VKM_indexed_plot <- renderPlotly({
    validate(
      need(nrow(transport_VKM_full()$df) > 0, "Please select years with data available")
    )
    p <- prepare_transport_indexed_chart(
      transport_VKM_full()$df,
      first_year = first_year(),
      country = country()
    )
    ggplotly(p)
  })

  ## Plot waterfall chart
  output$transport_VKM_waterfall_plot <- renderPlotly({
    validate(
      need(nrow(transport_VKM_LMDI()) > 0, "Please select years with data available")
    )
    p <- prepare_transport_waterfall_chart(
      transport_VKM_LMDI(),
      first_year = first_year(),
      last_year = last_year(),
      country = country()
    )
    ggplotly(p)
  })

  ## Plot intensity effects
  output$transport_VKM_intensity_effects_plot <- renderPlotly({
    validate(
      need(nrow(transport_VKM_LMDI()) > 0, "Please select years with data available")
    )
    p <- prepare_industry_intensity_effects_chart(
      transport_VKM_LMDI(),
      first_year = first_year(),
      last_year = last_year(),
      country = country()
    )
    ggplotly(p)
  })
  
}