# RUN THIS FIRST TO DEFINE GLOBAL PARAMETERS

# Load required packages

# install package (if not already done)
# install.packages("futile.logger")
# install.packages("fs")
# install.packages("yaml")
# install.packages("tidyverse")
# install.packages("tidyr")
# install.packages("dplyr")
# install.packages("ggplot2")
# install.packages("RColorBrewer")
# install.packages("plotly")
# install.packages("waterfalls")
# install.packages("eurostat")
# install.packages("ggpubr")
#install.packages("shinydashboard")


# Load required packages
library(futile.logger)
library(fs)
library(here)
library(yaml)
library(tidyverse)
library(tidyr)
library(dplyr)
library(ggplot2)
library(RColorBrewer)
# library(plotly)
library(waterfalls)
library("ggpubr")

rm()
# Source parameters
source("scripts/0_support/parameters.R")
flog.info("Starting processing for:")
flog.info(paste("  Country: ", country))
flog.info(paste("  First year: ", first_year))
flog.info(paste("  Last year: ", last_year))
flog.info("The following tasks will be performed:")
if (download) {
  flog.info("  Download raw data from Eurostat API")
}
if (clear) {
  flog.info("  Clear the country repository")
}
if (run_context) {
  flog.info("  Generate context charts (Part 1)")
}
if (run_industry_GVA_final) {
  flog.info("  Run the decomposition of the final energy consumption in the industry sector, based on GVA")
}
if (run_industry_GVA_primary) {
  flog.info("  Run the decomposition of the primary energy consumption in the industry sector, based on GVA")
}
if (run_economy_emp_final) {
  flog.info("  Run the decomposition of the final energy consumption in the different economy sector, based on employment")
}
if (run_household_final) {
  flog.info("  Run the decomposition of the final energy consumption in the residential sector")
}
if (run_transport_final) {
  flog.info("  Run the decomposition of the final energy consumption in the industry sector, based on VKM")
}

# If requested, download all the data from Eurostat website
if (download) {
  source("scripts/0_support/data_download.R")
  download_eurostat_data(first_year, last_year, data_path)
}
# If requested, clean the folder first
if (clear) {
  source("scripts/0_support/folders_management.R")
  clear_all(country, output_path)
}
# If requested, calculate all the required indicators, Generate the charts by country
if (run_context) {
  tryCatch(
    {
      source("scripts/4_all_sectors/full_energy.R")
      full_energy_final(first_year, last_year, country, data_path, output_path)
    },
    error = function(e) {
      flog.error("Error preparing full energy context: ", e)
    }
  )
}
if (run_industry_GVA_final) {
  tryCatch(
    {
      source("scripts/1_industry/1a_industry_gva_final.R")
      industry_GVA_final(first_year, last_year, country, data_path, output_path)
    },
    error = function(e) {
      flog.error("Error preparing industry gva final energy consumption decomposition: ", e)
    }
  )
}
if (run_industry_GVA_primary) {
  tryCatch(
    {
      source("scripts/1_industry/1b_industry_gva_primary.R")
      industry_GVA_primary(first_year, last_year, country, data_path, output_path)
    },
    error = function(e) {
      flog.error("Error preparing industry gva primary energy consumption decomposition: ", e)
    }
  )
}
if (run_economy_emp_final) {
  tryCatch(
    {
      source("scripts/1_industry/1c_economy_emp_final.R")
      economy_emp_final(first_year, last_year, country, data_path, output_path)
    },
    error = function(e) {
      flog.error("Error preparing economy employment energy consumption decomposition: ", e)
    }
  )
}
if (run_household_final) {
  tryCatch(
    {
      source("scripts/2_household/households.R")
      household_final(first_year, last_year, country, data_path, output_path)
    },
    error = function(e) {
      flog.error("Error preparing residential energy consumption decomposition: ", e)
    }
  )
}
if (run_transport_final) {
  tryCatch(
    {
      source("scripts/3_transport/transport_vkm.R")
      transport_final(first_year, last_year, country, data_path, output_path)
    },
    error = function(e) {
      flog.error("Error preparing transport traffic energy consumption decomposition: ", e)
    }
  )
}