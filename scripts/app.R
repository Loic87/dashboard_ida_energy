rm()

library(shiny)
library(shinydashboard)


source("server.R")
source("ui.R")

shinyApp(ui, server)