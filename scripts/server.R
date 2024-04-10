source("0_support/mapping_countries.R")
source("0_support/mapping_sectors.R")
source("0_support/mapping_products.R")
source("0_support/mapping_colors.R")
source("1_industry/1_industry.R")

server <- function(input, output) {
  energy_product_breakdown <- reactive({
    prepare_energy_product_breakdown(
      nrg_bal_c = read_feather(paste0("../data/nrg_bal_c_", get_country_code(input$country), ".feather")),
      first_year = input$YearRange[1],
      last_year = input$YearRange[2]
    )
  })
  output$plot1 <- renderPlotly({
    p <- ggplot(energy_product_breakdown(), aes(x = time, y = energy_consumption / 1000)) +
      geom_bar(aes(fill = product), stat = "identity") +
      scale_fill_manual(values = FinalProductsColors, limits = force) +
      theme_classic() +
      theme(axis.title.x = element_blank()) +
      scale_y_continuous(labels = scales::number) +
      ylab(paste("Energy consumption (PJ)")) +
      ggtitle(paste("Industry energy consumption by fuel for", input$country))
    ggplotly(p)
  })
}