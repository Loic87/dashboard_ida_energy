library(plotly)
library(shinydashboard)
library(eurostat)

source("0_support/mapping_countries.R")

ui <- dashboardPage(
  dashboardHeader(title = "IDA energy"),
  dashboardSidebar(
    sidebarMenu(
      selectInput("country", "Select country", country_long_list),
      sliderInput("YearRange", "Select base year and last year", min = 1990, max = 2023, value = c(2000, 2021)),
      menuItem("Industry", tabName = "industry"),
      menuItem("Transport", tabName = "transport"),
      menuItem("Residential", tabName = "residential")
    )
  ),
  dashboardBody(
    tabItems(
      tabItem(
        tabName = "industry",
          tabsetPanel(
            tabPanel('Energy consumption by product',
              plotlyOutput("industry_energy_consumption_by_product")
            ),
            tabPanel('Energy consumption by sector',
              plotlyOutput("industry_energy_consumption_by_sector"),
              plotlyOutput("industry_GVA_by_sector")
            ),
            tabPanel('Decomposition of energy consumption',
                     plotlyOutput("industry_GVA_final_intensity_effects"),
                     fluidRow(
                       column(6, plotlyOutput("industry_GVA_indexed")),
                       column(6, plotlyOutput("industry_GVA_final_waterfall"))
                     )
            )
        )
      ),
      tabItem(tabName = "transport"),
      tabItem(tabName = "residential")
    )
  )
)