library(shiny)
library(shinydashboard)
#library(shinyjs)
library(tidyverse)
library(stringr)
library(lubridate)
library(leaflet)

source("load_data.R")
source("value_counts.R")

# JS function ------------------------------------------------------------------ 
#scroll <- "
#shinyjs.scroll = function() { 
#$('body').animate({ scrollTop: 0 }, 'slow'); } "



# Read data -------------------------------------------------------------------- 
data <- load_data()

# Get map
#map <- create_map(data)

# Prep Lists / etc -------------------------------------------------------------
nc_names <- data$neighborhood_council_name %>% unique()
# ui --------------------------------------------------------------------------- 
header <- dashboardHeader(
  title = tags$a(href = "",
                 tags$img(src = "seal_of_los_angeles.png", height = "45", width = "40",
                          style = "display: block; padding-top: 5px;"))
)

sidebar <- dashboardSidebar(
  sidebarMenu(
    menuItem("Requests", tabName = "requests", icon = icon("cloud-download"))
  )
)

body <- dashboardBody(
  fluidRow(
    column(6,
      # Input: Selector for variable for Neighborhood Council ----
      selectInput("neighborhoodCouncil", "Neighborhood Council:",
                  nc_names),
      # Input: Selector for Month
      selectInput('month', "Select a Month",
                  c('January' = 1, 
                    'Febuary' = 2,
                    'March' = 3,
                    'April' = 4,
                    'May' = 5,
                    'June' = 6,
                    'July' = 7,
                    'August' = 8,
                    'September' = 9,
                    'October' = 10,
                    'November' = 11,
                    'December' = 12
                  )
      ),
      selectInput('year', "Select a Year",
                  c(seq(2015,2020))),

      # Box with over time chart
      box(
        title = "Closed SR over Time", status = "primary", solidHeader = TRUE,
        collapsible = TRUE,
        plotOutput("overTimeCount", height = 250)
      )
    ),
    column(6, leafletOutput("map"))
  ),
  fluidRow(
    # rendering of the table
    dataTableOutput('table')
  )
) # body

ui <- dashboardPage(header, sidebar, body)

# server ----------------------------------------------------------------------- 
server <- function(input, output) { 
  # make the data 
  subsetData <- reactive({data %>% 
      filter(neighborhood_council_name == input$neighborhoodCouncil) %>% 
      filter(closed_date %>% year == input$year) %>% 
      filter(closed_date %>% month == input$month)
  })
  output$table <- renderDataTable(subsetData())
  
  data %>%
    mutate(month = format(closed_date, "%m"), year = format(closed_date, "%Y")) %>%
    group_by(year, month)  %>%
    count()

  output$map <- renderLeaflet({
    leaflet() %>%
      addProviderTiles(providers$Stamen.TonerLite,
                       options = providerTileOptions(noWrap = TRUE)
      )
  })
} # end server


# run app ---------------------------------------------------------------------- 
shinyApp(ui, server)
