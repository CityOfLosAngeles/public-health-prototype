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

# Read cleanstat data
cleanstat_data <- summarize_cleanstat()

# Get map
map <- create_base_map()

# Prep Lists / etc -------------------------------------------------------------
nc_names <- data$neighborhood_council_name %>% unique()
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
  tabItems(
    tabItem(
      tabName = "map",
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
    mutate(month = as.Date(cut(
      (filter(data, neighborhood_council_name == input$neighborhoodCouncil))$closed_date, breaks = 'month'))) %>%
    group_by(month) %>%
    count() %>%
    ggplot(aes (x = month, y = n )) +
    geom_line(aes(group=1)) + 
    ggtitle(sprintf("Service Requests Closed by Month in %s", input$neighborhoodCouncil)) + 
    xlab("Month") + 
    ylab("Number of Service Requests Closed") +
    scale_x_date(labels = date_format("%b, %Y"))
    })
  
  output$solveTimeCount <- renderPlot({data %>%
      filter(neighborhood_council_name == input$neighborhoodCouncil) %>% 
      drop_na(closed_date, created_date) %>%
      mutate(solve_time_days = round(created_date %--% closed_date / ddays(1), 2)) %>%
      mutate(month = as.Date(cut(
        (filter(data, neighborhood_council_name == input$neighborhoodCouncil))$closed_date, breaks = 'month'))) %>%
      group_by(month)  %>%
      summarize(average_solve_time = mean(solve_time_days)) %>% 
      ggplot(aes(x = month, y = average_solve_time )) + 
      geom_line(aes(group=1)) +
      ggtitle(sprintf("Average Days Until Service Requests are Closed in %s", input$neighborhoodCouncil)) + 
      xlab("Month") + 
      ylab("Average Number of Days") +
      scale_x_date(labels = date_format("%b, %Y"))
  })
    

  output$code55opened <- renderInfoBox({
    infoBox(
      "Sanitation Code 55 Opened",
      data %>%
        filter(created_date > "2020-01-01") %>%
        filter(reason_code == "55") %>%
        count() %>%
        prettyNum(big.mark=","),
      icon = icon("trash-alt"),
      color = "yellow"
    )
  })
  
  output$code55closed <- renderInfoBox({
    infoBox(
      "Sanitation Code 55 Closed",
      data %>%
        filter(closed_date > "2020-01-01") %>%
        filter(reason_code == "55") %>%
        count() %>%
        prettyNum(big.mark=","),
      icon = icon("trash-alt"),
      color = "yellow"
    )
  })
  
  output$code55time <- renderInfoBox({
    infoBox(
      "Sanitation Code 55 Average Solve Time",
      data %>%
        filter(reason_code == "55") %>%
        drop_na(closed_date, created_date) %>%
        filter(closed_date > "2020-01-01") %>%
        mutate(solve_time_days = round(created_date %--% closed_date / ddays(1), 2)) %>%
        summarize(average_solve_time = mean(solve_time_days)) %>%
        prettyNum(digits=0, big.mark=",") %>%
        paste("Days"),
      icon = icon("trash-alt"),
      color = "yellow"
    )
  })
  
  output$code75opened <- renderInfoBox({
    infoBox(
      "Sanitation Code 75 Opened",
      data %>%
        filter(created_date > "2020-01-01") %>%
        filter(reason_code == "75") %>%
        count() %>%
        prettyNum(big.mark=","),
      icon = icon("briefcase-medical"),
      color = "green"
    )
  })
  
  output$code75closed <- renderInfoBox({
    infoBox(
      "Sanitation Code 75 Closed",
      data %>%
        filter(closed_date > "2020-01-01") %>%
        filter(reason_code == "75") %>%
        count() %>%
        prettyNum(big.mark=","),
      icon = icon("briefcase-medical"),
      color = "green"
    )
  })
  
  output$code75time <- renderInfoBox({
    infoBox(
      "Sanitation Code 75 Average Solve Time",
      data %>%
        filter(reason_code == "75") %>%
        drop_na(closed_date, created_date) %>%
        filter(closed_date > "2020-01-01") %>%
        mutate(solve_time_days = round(created_date %--% closed_date / ddays(1), 2)) %>%
        summarize(average_solve_time = mean(solve_time_days)) %>%
        prettyNum(digits=0, big.mark=",") %>%
        paste("Days"),
      icon = icon("briefcase-medical"),
      color = "green"
    )
  })
  
  output$rapopened <- renderInfoBox({
    infoBox(
      "Rec and Park Cases Opened",
      "TBD",
      icon = icon("fire"),
      color = "blue"
    )
  })
  
  output$rapclosed <- renderInfoBox({
    infoBox(
      "Rec and Park Cases Closed",
      "TBD",
      icon = icon("fire"),
      color = "blue"
    )
  })
  
  output$raptime <- renderInfoBox({
    infoBox(
      "Rec and Park Cases Solve Time",
      "TBD",
      icon = icon("fire"),
      color = "blue"
    )
  })
  
  output$cleanstatweeds <- renderInfoBox({
    infoBox(
      "CleanStat Streets with Weeds",
      cleanstat_data %>%
        filter(WeedScore > 1) %>%
        count() %>%
        prettyNum(big.mark=","),
      icon = icon("seedling"),
      color = "purple"
    )
  })
  
  output$cleanstatbulky <- renderInfoBox({
    infoBox(
      "Cleanstat Streets with Bulky Items",
      cleanstat_data %>%
        filter(BulkyScore > 1) %>%
        count() %>%
        prettyNum(big.mark=","),
      icon = icon("trash-alt"),
      color = "purple"
    )
  })
  
  output$cleanstatlitter <- renderInfoBox({
    infoBox(
      "CleanStat Streets with Litter",
      cleanstat_data %>%
        filter(LLScore > 1) %>%
        count() %>%
        prettyNum(big.mark=","),
      icon = icon("newspaper"),
      color = "purple"
    )
  })
  
  output$cleanstatillegaldumping <- renderInfoBox({
    infoBox(
      "CleanStat Streets with Illegal Dumping",
      cleanstat_data %>%
        filter(IDScore > 1) %>%
        count() %>%
        prettyNum(big.mark=","),
      icon = icon("couch"),
      color = "purple"
    )
  })
  observe({
    if (nrow(timeSubset()) == 0) {
      leafletProxy("map") %>% clearControls() %>% clearShapes()
      return()
    }
    map_data <- prepare_map_data(timeSubset())
    leafletProxy("map", data=map_data) %>%
      draw_map_data(map_data)
  })
  output$map <- renderLeaflet(map)
} # end server


# run app ---------------------------------------------------------------------- 
shinyApp(ui, server)
