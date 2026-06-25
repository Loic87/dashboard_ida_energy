library(shiny)
library(shinydashboard)
library(here)

source(here("scripts", "server.R"))
source(here("scripts", "ui.R"))

shinyApp(ui, server)