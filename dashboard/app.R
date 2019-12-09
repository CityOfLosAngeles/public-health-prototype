## app.R ##
library(shiny)
library(shinydashboard)
library(leaflet)
library(tidyverse)
library(lubridate)

source("load_data.R")

r_colors <- rgb(t(col2rgb(colors()) / 255))
names(r_colors) <- colors()

ui <- dashboardPage(
  skin='black',
  dashboardHeader(
    title = div(
            tags$a(href = "",
                  tags$img(src = "seal_of_los_angeles.png", height = "45", width = "40",
                          style = "display: block; padding-top: 5px;")),
            h1("Public Health Metrics"))
  
  ),
  dashboardSidebar(),
  dashboardBody(
    # Boxes need to be put in a row (or column)
    fluidPage(
      # create date picker
      dateRangeInput('dates', 'Date Range',
                     start = Sys.Date() - 2,
                     end = Sys.Date(),
                     min = NULL,
                     max = NULL, format = "yyyy-mm-dd", startview = "month",
                     weekstart = 0, language = "en", separator = " to ", width = NULL,
                     autoclose = TRUE)
    ),
    fluidRow(
      box(tableOutput("requestTable"))
    ),
    fluidRow(leafletOutput("mymap"))
  )
)

server <- function(input, output, session) { 
  points <- eventReactive(input$recalc, {
    cbind(rnorm(40) * 2 + 13, rnorm(40) + 48)
  }, ignoreNULL = FALSE)
  
  output$mymap <- renderLeaflet({
    leaflet() %>%
      addProviderTiles(providers$Stamen.TonerLite,
                       options = providerTileOptions(noWrap = TRUE)
      ) %>%
      addMarkers(data = points())
  })  

  # source plot 
  service_start <- reactive({parse_date(input$dates[1],
    locale = locale(tz = "US/Pacific"))}) 
  service_end <- reactive({parse_date(input$dates[2],
    locale = locale(tz = "US/Pacific"))})
  service_period <- reactive({service_start() %--% service_end()}) 

    subsetCases <- reactive({cases %>% 
                           filter(closeddate %within% service_period()) %>%
                           head(5)})
    #reactive({cases %>% filter(closeddate > service_start())})
  
    #    %>% renderPlot(ggplot(aes(createdbyuserorganization)) +
    #                   geom_bar() +
    #                   labs(title ="Source of Closed Tickets in Selected Date Range"))
  output$requestTable <- renderTable(subsetCases())
  div(
    output$dateText  <- renderText({
      paste("input$date is", as.character(input$date))
    })
  )
}


shinyApp(ui, server)