library(shiny)
library(shinydashboard)
library(tidyverse)
library(stringr)
library(lubridate)
library(leaflet)
library(scales)

source("create_map.R")
source("load_data.R")
source("value_counts.R")


# Read data -------------------------------------------------------------------- 
data <- load_data()
geo_data <- data %>%
  drop_na("longitude", "latitude") %>%
  sf::st_as_sf(coords=c("longitude", "latitude"), crs=4326)

# Read cleanstat data
cleanstat_data <- summarize_cleanstat()

# Get map
map <- create_base_map()

# Prep Lists / etc -------------------------------------------------------------
neighborhood_council_names <- neighborhood_councils$Name %>% unique()

lapd_division_names <- lapd_divisions$APREC %>% unique()

council_district_names <- council_districts$NAME %>% unique()

# ui --------------------------------------------------------------------------- 
header <- dashboardHeader(
  title = tags$span(
    tags$img(
      src = "seal_of_los_angeles.png",
      height = "45",
      width = "40",
      style = "display: block; padding-top: 5px;"
    ),
    tags$p(
      "City of Los Angeles Public Health Dashboard"
    ),
    style="display: flex;"
  ),
  titleWidth = 480
)

sidebar <- dashboardSidebar(
  sidebarMenu(
    menuItem("Summary", tabName = "summary", icon = icon("list-alt")),
    menuItem("Service Request Map", tabName = "map", icon = icon("map"))
  )
)

body <- dashboardBody(
  tags$head(
    tags$link(rel = "stylesheet", type = "text/css", href = "custom.css")
  ),
  tabItems(
    tabItem(
      tabName = "map",
      fluidRow(
        column(3,
          # Input for what geography to aggregate by.
          selectInput("geog_type", "Geographic Division:",
                      c(
                        "Neighborhood Council"="nc",
                        "LAPD Division" = "lapd",
                        "City Council District" = "cd"
                        )
                      ),
          # Input: Selector for variable for Neighborhood Council ----
          uiOutput("geog_name"),
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
                      selected = 2020)

        ),
        column(9, leafletOutput("map"))
      ),
      fluidRow(
        # Box with over time chart
        box(
          title = "Closed Service Requests over Time", status = "primary", solidHeader = TRUE,
          collapsible = TRUE, width = 6,
          plotOutput("overTimeCount", height = 250)
        ),
        box(
          title = "Average Solve Time", status = "primary", solidHeader = TRUE,
          collapsible = TRUE, width = 6,
          plotOutput("solveTimeCount", height = 250)
        )
      ),
      fluidRow(
        # rendering of the table
        dataTableOutput('table')
      )
    ), # end requests tab
    tabItem(
      tabName = 'summary',
      titlePanel(
        "Summary Statistics - 1/1/2020 to present"
      ),
      fluidRow(
        infoBoxOutput("code55opened"),
        infoBoxOutput("code55closed"),
        infoBoxOutput("code55time")
      ),
      fluidRow(
        infoBoxOutput("code75opened"),
        infoBoxOutput("code75closed"),
        infoBoxOutput("code75time")
      ),
      fluidRow(
        infoBoxOutput("rapopened"),
        infoBoxOutput("rapclosed"),
        infoBoxOutput("raptime")
      ),
      fluidRow(
        infoBoxOutput("cleanstatbulky"),
        infoBoxOutput("cleanstatweeds"),
        infoBoxOutput("cleanstatlitter"),
        infoBoxOutput("cleanstatillegaldumping")
      )
    ) # end counts tab.
  ) # end tabItems 
) # body

ui <- dashboardPage(header, sidebar, body)

# server ----------------------------------------------------------------------- 
server <- function(input, output) {
  
  #######################################
  ##      SUMMARY STATISTICS           ##
  #######################################
  
  output$code55opened <- renderInfoBox({
    infoBox(
      "CARE+ Cases Opened",
      data %>%
        filter(created_date > "2020-01-01") %>%
        filter(reason_code == "55") %>%
        count() %>%
        prettyNum(big.mark=","),
      icon = icon("", class="cola-custom-icon care-plus")
    )
  })
  
  output$code55closed <- renderInfoBox({
    infoBox(
      "CARE+ Cases Closed",
      data %>%
        filter(closed_date > "2020-01-01") %>%
        filter(reason_code == "55") %>%
        count() %>%
        prettyNum(big.mark=","),
      icon = icon("", class="cola-custom-icon care-plus")
    )
  })
  
  output$code55time <- renderInfoBox({
    infoBox(
      "CARE+ Cases Average Solve Time",
      data %>%
        filter(reason_code == "55") %>%
        drop_na(closed_date, created_date) %>%
        filter(closed_date > "2020-01-01") %>%
        mutate(solve_time_days = round(created_date %--% closed_date / ddays(1), 2)) %>%
        summarize(average_solve_time = mean(solve_time_days)) %>%
        prettyNum(digits=0, big.mark=",") %>%
        paste("Days"),
      icon = icon("", class="cola-custom-icon care-plus")
    )
  })
  
  output$code75opened <- renderInfoBox({
    infoBox(
      "CARE Cases Opened",
      data %>%
        filter(created_date > "2020-01-01") %>%
        filter(reason_code == "75") %>%
        count() %>%
        prettyNum(big.mark=","),
      icon = icon("", class="cola-custom-icon care")
    )
  })
  
  output$code75closed <- renderInfoBox({
    infoBox(
      "CARE Cases Closed",
      data %>%
        filter(closed_date > "2020-01-01") %>%
        filter(reason_code == "75") %>%
        count() %>%
        prettyNum(big.mark=","),
      icon = icon("", class="cola-custom-icon care")
    )
  })
  
  output$code75time <- renderInfoBox({
    infoBox(
      "CARE Cases Average Solve Time",
      data %>%
        filter(reason_code == "75") %>%
        drop_na(closed_date, created_date) %>%
        filter(closed_date > "2020-01-01") %>%
        mutate(solve_time_days = round(created_date %--% closed_date / ddays(1), 2)) %>%
        summarize(average_solve_time = mean(solve_time_days)) %>%
        prettyNum(digits=0, big.mark=",") %>%
        paste("Days"),
      icon = icon("", class="cola-custom-icon care")
    )
  })
  
  output$rapopened <- renderInfoBox({
    infoBox(
      "Rec and Park Cases Opened",
      "TBD",
      icon = icon("", class="cola-custom-icon larap")
    )
  })
  
  output$rapclosed <- renderInfoBox({
    infoBox(
      "Rec and Park Cases Closed",
      "TBD",
      icon = icon("", class="cola-custom-icon larap")
    )
  })
  
  output$raptime <- renderInfoBox({
    infoBox(
      "Rec and Park Cases Solve Time",
      "TBD",
      icon = icon("", class="cola-custom-icon larap")
    )
  })
  
  output$cleanstatweeds <- renderInfoBox({
    infoBox(
      "CleanStat Streets with Weeds",
      cleanstat_data %>%
        filter(WeedScore > 1) %>%
        count() %>%
        prettyNum(big.mark=","),
      icon = icon("", class="cola-custom-icon lasan")
    )
  })
  
  output$cleanstatbulky <- renderInfoBox({
    infoBox(
      "Cleanstat Streets with Bulky Items",
      cleanstat_data %>%
        filter(BulkyScore > 1) %>%
        count() %>%
        prettyNum(big.mark=","),
      icon = icon("", class="cola-custom-icon lasan")
    )
  })
  
  output$cleanstatlitter <- renderInfoBox({
    infoBox(
      "CleanStat Streets with Litter",
      cleanstat_data %>%
        filter(LLScore > 1) %>%
        count() %>%
        prettyNum(big.mark=","),
      icon = icon("", class="cola-custom-icon lasan")
    )
  })
  
  output$cleanstatillegaldumping <- renderInfoBox({
    infoBox(
      "CleanStat Streets with Illegal Dumping",
      cleanstat_data %>%
        filter(IDScore > 1) %>%
        count() %>%
        prettyNum(big.mark=","),
      icon = icon("", class="cola-custom-icon lasan")
    )
  })
  
  ########################################
  ##       SERVICE REQUESTS MAP         ##
  ########################################
  geogType <- reactive({input$geog_type})
  
  output$geog_name <- renderUI({
    if (geogType() == "cd") {
      return(selectInput("cd_selector", "Council District Member:", council_district_names))
    } else if (geogType() == "nc") {
      return(selectInput("nc_selector", "Neighborhood Council:", neighborhood_council_names))
    } else if (geogType() == "lapd") {
      return(selectInput("lapd_selector", "LAPD District:", lapd_division_names))
    }
  })             
  geogKey <- reactive({
    if(geogType() == "cd") {
      return("NAME")
    } else if (geogType() == "nc") {
      return("Name")
    } else if (geogType() == "lapd") {
      return("APREC")
    }
  })
  geogDataset <- reactive({
    if(geogType() == "cd") {
      return(council_districts)
    } else if (geogType() == "nc") {
      return(neighborhood_councils)
    } else if (geogType() == "lapd") {
      return(lapd_divisions)
    }
  })
  geogSelection <- reactive({
    if(geogType() == "cd") {
      return(input$cd_selector)
    } else if (geogType() == "nc") {
      return(input$nc_selector)
    } else if (geogType() == "lapd") {
      return(input$lapd_selector)
    }
    return(NULL)
  })

  # make the data 
  timeSubset <- reactive({
    data %>% 
      filter(closed_date %>% year == input$year) %>% 
      filter(closed_date %>% month == input$month)
  })
  geogJoined <- reactive({
    req(geogDataset())
    geo_data %>%
      sf::st_join(geogDataset(), join=sf::st_within, left=TRUE)
  })
  geogSubset <- reactive({
    req(geogSelection())
    geogJoined() %>%
      filter(.data[[geogKey()]] == geogSelection()) # R Nonstandard Evaluation is wild...
  })
  geogTimeSubset <- reactive({
    req(input$year, input$month)
    geogSubset() %>%
      filter(closed_date %>% year == input$year) %>% 
      filter(closed_date %>% month == input$month)
  })

  output$map <- renderLeaflet(map)
  observe({
    subs <- geogJoined() %>%
      filter(closed_date %>% year == input$year) %>% 
      filter(closed_date %>% month == input$month)
    
    if (nrow(subs) == 0) {
      leafletProxy("map") %>% clearControls() %>% clearShapes()
      return()
    }
    
    map_data <- prepare_map_data(subs, geogDataset(), geogKey())
    leafletProxy("map", data=map_data) %>%
      draw_map_data(map_data, geogKey())
  })


  output$table <- renderDataTable(geogTimeSubset())

  output$overTimeCount <- renderPlot({
    geogSubset() %>%
      drop_na(closed_date, created_date) %>%
      mutate(month = as.Date(cut(closed_date, breaks='month'))) %>%
      group_by(month) %>%
      count() %>%
      ggplot(aes (x = month, y = n )) +
      geom_line(aes(group=1)) + 
      ggtitle(sprintf("Service Requests Closed by Month in %s", geogSelection())) + 
      xlab("Month") + 
      ylab("Number of Service Requests Closed") +
      scale_x_date(labels = date_format("%b, %Y"))
  })
  
  output$solveTimeCount <- renderPlot({

    geogSubset() %>%
      drop_na(closed_date, created_date) %>%
      mutate(solve_time_days = round(created_date %--% closed_date / ddays(1), 2)) %>%
      mutate(month = as.Date(cut(closed_date, breaks='month'))) %>%
      group_by(month) %>%
      summarize(average_solve_time = mean(solve_time_days)) %>%
      ggplot(aes(x = month, y = average_solve_time )) + 
      geom_line(aes(group=1)) +
      ggtitle(sprintf("Average Days Until Service Requests are Closed in %s", geogSelection())) + 
      xlab("Month") + 
      ylab("Average Number of Days") +
      scale_x_date(labels = date_format("%b, %Y"))
  })
} # end server


# run app ---------------------------------------------------------------------- 
shinyApp(ui, server)
