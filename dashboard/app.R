library(shiny)
library(shinydashboard)
#library(shinyjs)
library(tidyverse)
library(stringr)
library(lubridate)
library(leaflet)

source("create_map.R")
source("load_data.R")
source("value_counts.R")


# Read data -------------------------------------------------------------------- 
data <- load_data()

# Get map
map <- create_base_map()

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
                  ), 
                  selected = 1
      ),
      selectInput('year', "Select a Year",
                  c(seq(2015,2020)),
                  selected = 2020),

      # Box with over time chart
      box(
        title = "Closed SR over Time", status = "primary", solidHeader = TRUE,
        collapsible = TRUE, width = 6,
        plotOutput("overTimeCount", height = 250)
      ),
      box(
        title = "Average Solve Time", status = "primary", solidHeader = TRUE,
        collapsible = TRUE, width = 6,
        plotOutput("solveTimeCount", height = 250)
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
  timeSubset <- reactive({
      data %>% 
      filter(closed_date %>% year == input$year) %>% 
      filter(closed_date %>% month == input$month)
  })
  ncSubset <- reactive({
      timeSubset() %>% 
      filter(neighborhood_council_name == input$neighborhoodCouncil)
  })
  output$table <- renderDataTable(ncSubset())

  output$overTimeCount <- renderPlot({data %>%
    filter(neighborhood_council_name == input$neighborhoodCouncil) %>% 
    drop_na(closed_date) %>% 
    mutate(month = format(closed_date, "%m"), year = format(closed_date, "%Y")) %>%
    group_by(year, month)  %>%
    count() %>% 
    mutate(yearmon = paste(year, month)) %>% 
    ggplot(aes(x = yearmon, y = n )) + 
    geom_line(aes(group=1)) +
    ggtitle(sprintf("Service Requests Closed by Month in %s", input$neighborhoodCouncil)) + 
    xlab("Time") + 
    ylab("Number of Service Requests Closed")
    })
  
  output$solveTimeCount <- renderPlot({data %>%
      filter(neighborhood_council_name == input$neighborhoodCouncil) %>% 
      drop_na(closed_date, created_date) %>%
      mutate(solve_time_days = round(created_date %--% closed_date / ddays(1), 2)) %>%
      mutate(month = format(closed_date, "%m"), year = format(closed_date, "%Y")) %>%
      group_by(year, month)  %>%
      summarize(average_solve_time = mean(solve_time_days)) %>% 
      mutate(yearmon = paste(year, month)) %>% 
      ggplot(aes(x = yearmon, y = average_solve_time )) + 
      geom_line(aes(group=1)) +
      ggtitle(sprintf("Average Days Until Service Requests are Closed in %s", input$neighborhoodCouncil)) + 
      xlab("Month") + 
      ylab("Average Number of Days")
  })
    

  observe({
    if (nrow(timeSubset()) == 0) {
      leafletProxy("map") %>% clearControls() %>% clearShapes()
      return()
    }
    map_data = prepare_map_data(timeSubset())
    leafletProxy("map", data=map_data) %>%
      draw_map_data(map_data)
  })
  output$map <- renderLeaflet(map)
} # end server


# run app ---------------------------------------------------------------------- 
shinyApp(ui, server)
