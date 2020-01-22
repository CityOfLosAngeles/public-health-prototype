library(shiny)
library(shinydashboard)
#library(shinyjs)
library(tidyverse)
library(stringr)
library(lubridate)
library(plotly)
library(leaflet)

source("load_data.R")
source("value_counts.R")

# JS function ------------------------------------------------------------------ 
#scroll <- "
#shinyjs.scroll = function() { 
#$('body').animate({ scrollTop: 0 }, 'slow'); } "



# Read data -------------------------------------------------------------------- 
data <- load_data()

# ui --------------------------------------------------------------------------- 
header <- dashboardHeader(
  title = tags$a(href = "",
                 tags$img(src = "seal_of_los_angeles.png", height = "45", width = "40",
                          style = "display: block; padding-top: 5px;"))
)

sidebar <- dashboardSidebar(
  sidebarMenu(
    menuItem("Requests", tabName = "requests", icon = icon("cloud-download")),
    menuItem("Maps", tabName = "maps", icon = icon("map-o")),
    menuItem("Services", tabName = "services", icon = icon("truck"))
  )
)

body <- dashboardBody(
  #useShinyjs(),
  #extendShinyjs(text = scroll),
  tags$body(id = "body"),
  tabItems(



  ) # end tabItems
) # body

ui <- dashboardPage(header, sidebar, body)

# server ----------------------------------------------------------------------- 
server <- function(input, output) { 
  

  
} # end server


# run app ---------------------------------------------------------------------- 
shinyApp(ui, server)
