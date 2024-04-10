source("0_support/mapping_countries.R")

ui <- fluidPage(
  titlePanel(title = "Energy consumption"),
  sidebarLayout(
    sidebarPanel(
      selectInput("country", "Select country", country_long_list),
      sliderInput("YearRange","Select base year and last year", min = 1990, max = 2023, value = c(1990, 2022))
    ),
    mainPanel(
      tabsetPanel(
        tabPanel('Industry', 
                 plotlyOutput("plot1")
                 ),
        tabPanel('Services'),
        tabPanel('Transport'),
        tabPanel('Residential')
      )
    )
  )
)