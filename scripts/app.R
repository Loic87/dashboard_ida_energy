rm()

library(eurostat)
library(tidyr)
library(dplyr)
library(feather)
library(shiny)
library(shinydashboard)
library(ggplot2)
library(waterfalls)
library(plotly)
library(futile.logger)

source("server.R")
source("ui.R")

shinyApp(ui, server)