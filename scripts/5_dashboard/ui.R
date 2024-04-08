library(shiny)
library(shinydashboard)
library(eurostat)

ui <- fluidPage(
  titlePanel(title = "Energy consumption"),
  sidebarLayout(
    sidebarPanel(
      selectInput("country", "Select country", eu_countries$name)
    ),
    mainPanel()
  )
)