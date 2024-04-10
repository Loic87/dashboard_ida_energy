rm()

library(eurostat)
library(tidyr)
library(dplyr)
library(feather)
library(shiny)
library(shinydashboard)
library(ggplot2)
library(plotly)

source("server.R")
source("ui.R")

shinyApp(ui, server)