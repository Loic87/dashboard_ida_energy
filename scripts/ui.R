library(plotly)
library(shinydashboard)
library(eurostat)
library(shinyjs)

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
            tabPanel('Energy consumption and GVA by sector',
              plotlyOutput("industry_energy_consumption_by_sector_plot"),
              plotlyOutput("industry_GVA_by_sector_plot")
            ),
            tabPanel('Decomposition of energy consumption',
                     fluidRow(
                       column(6, plotlyOutput("industry_GVA_indexed_plot")),
                       column(6, plotlyOutput("industry_GVA_final_waterfall_plot"))
                     ),
                     plotlyOutput("industry_GVA_final_intensity_effects_plot")
            ),
            tabPanel('Energy consumption by product',
                     plotlyOutput("industry_energy_consumption_by_product_plot")
            ),
        )
      ),
      tabItem(
        tabName = "transport",
        tabsetPanel(
          tabPanel('Energy consumption and VKM by mode',
                   plotlyOutput("transport_energy_consumption_by_mode_plot"),
                   plotlyOutput("transport_VKM_by_mode_plot")
          ),
          tabPanel('Decomposition of energy consumption',
                   fluidRow(
                     column(6, plotlyOutput("transport_VKM_indexed_plot")),
                     column(6, plotlyOutput("transport_VKM_waterfall_plot"))
                   ),
                   plotlyOutput("transport_VKM_intensity_effects_plot")
          ),
          tabPanel('Energy consumption by product',
                   plotlyOutput("transport_energy_consumption_by_product_plot")
          ),
        )
      ),
      tabItem(tabName = "residential")
    )
  )
)