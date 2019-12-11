library(shiny)
library(shinydashboard)
#library(shinyjs)
library(tidyverse)
library(stringr)
library(lubridate)
library(plotly)
library(leaflet)

source("load_data.R")
source("subsets.R")
source("load_shapefile.R")
source("value_counts.R")

# JS function ------------------------------------------------------------------ 
#scroll <- "
#shinyjs.scroll = function() { 
#$('body').animate({ scrollTop: 0 }, 'slow'); } "

# Colors ----------------------------------------------------------------------- 
pal <- RColorBrewer::brewer.pal(11, "Spectral")
qual5 <- c(pal[1], pal[3], pal[4], pal[9], pal[10])
qual6 <- c(pal[1], pal[3], pal[4], pal[8], pal[9], pal[10])
qual7 <- c(pal[1], pal[3], pal[4], pal[7], pal[8], pal[9], pal[10])
cool <- c(pal[7], pal[8], pal[9], pal[10], pal[11])
warm <- c(pal[5], pal[4], pal[3], pal[2], pal[1])
cool_gradient <- data_frame(
  range = c(0.000, 0.115, 0.290, 0.750, 1.000),
  hex = cool
)
warm_gradient <- data_frame(
  range = c(0.000, 0.115, 0.290, 0.750, 1.000),
  hex = warm
)

# Read data -------------------------------------------------------------------- 
data <- load_data()
data <- subset_data(data)
districts <- load_shapefile(data)

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
    # Requests ----------------------------------------------------------------- 
    tabItem(
      tabName = "requests",
      fluidRow(
        box(
          title = "Time Series of Requests by Source", width = 12,
          plotlyOutput("requests_by_source")        
        ),
        box(
          title = "Heatmap of Request Traffic by Day and Time", width = 12,
          selectInput("request_source_heat", label = NULL, 
                      selected = "Mobile App", width = "12em",
                      choices = c(
                        "Call", "Driver Self Report",
                        "Mobile App", "Self Service",
                        "Email"
                      )),
          plotlyOutput("day_time_heatmap")
        )
      ) 
    ),
    # Maps ---------------------------------------------------------------------- 
    tabItem(
      tabName = "maps",
      tags$style(type = "text/css", "#district_map {height: calc(100vh - 80px)!important;}"),
      leafletOutput("district_map"),
      absolutePanel(
        top = 80, right = 30,
        selectInput(
          "map_request_type", label = NULL,
          selected = "total_requests", choices = c(
            "Total Requests" = "total_requests",
            "Bulky Items" = "bulky_items", 
            "Dead Animal Removal" = "dead_animal_removal", 
            "Electronic Waste" = "electronic_waste", 
            "Graffiti Removal" = "graffiti_removal",
            "Homeless Encampment" = "homeless_encampment",
            "Illegal Dumping Pickup" = "illegal_dumping_pickup",
            "Metal Household Appliances" = "metal_household_appliances",
            "Multiple Streetlight Issue" = "multiple_streetlight_issue",
            "Other" = "other", "Report Water Waste"  = "report_water_waste",
            "Single Streetlight Issue" = "single_streetlight_issue"
          )
        )
      )
    ),
    # Services ----------------------------------------------------------------- 
    tabItem(
      tabName = "services",
      fluidRow(
        box(
          input <- dateRangeInput(
            "service_date_range",
            label = "Select Date Range:",
            start = today() - 365, 
            end = today() - 2),
          width = 12
        ),
        box(
          title = "", 
          width = 12,
          plotlyOutput("request_type_date_range")
        ),
        box(
          title = "",
          width = 12,
          plotlyOutput("mean_completion_time_date_range")
        ) 
      )
    )
  ) # end tabItems
) # body

ui <- dashboardPage(header, sidebar, body)

# server ----------------------------------------------------------------------- 
server <- function(input, output) { 
  
  # requests ------------------------------------------------------------------- 
  output$requests_by_source <- renderPlotly({
    requests <- data %>%
      filter(request_source %in% c(
        "Call", "Driver Self Reprenort",
        "Mobile App", "Self Service",
        "Email"
      )) %>%
      select(created_date_static, request_source,
             request_by_month, request_by_week) %>%
      arrange(created_date_static) %>%
      dplyr::distinct()
    
    p <- plot_ly(requests, x = ~created_date_static, 
                 color = ~request_source, colors = "Set1") %>%
      add_trace(y = ~request_by_week, type = "scatter",
                mode = "lines", visible = TRUE) %>%
      add_trace(y = ~request_by_month, type = "scatter",
                mode = "lines", visible = FALSE) 
    
    p %>% layout(
      xaxis = list(
        title = "\nDate request was created",
        rangeslider = list(type = "date")
      ),
      yaxis = list(
        title = "Number of requests\n"
      ),
      legend = list(x = 1, y = 0.9),
      updatemenus = list(
        list(
          x = 0.1, y = 1.2,
          buttons = list(
            list(method = "restyle",
                 args = list("visible", append(
                   rep(list(TRUE), 5),
                   rep(list(FALSE), 5)
                 )),
                 label = "Weekly"),
            list(method = "restyle",
                 args = list("visible", append(
                   rep(list(FALSE), 5),
                   rep(list(TRUE), 5)
                 )),
                 label = "Monthly")
          )
        )
      ))
    
  })
  
  output$day_time_heatmap <- renderPlotly({
    heat <- data %>%
      filter(request_source == input$request_source_heat) %>%
      group_by(day, hour) %>%
      count()
    
    p <- heat %>%
      plot_ly() %>%
      add_heatmap(x = ~day, y = ~hour, z = ~n,
                  colorscale = warm_gradient, showscale = F) 
    
    p %>% layout(xaxis = list(title = ""),
                 yaxis = list(title = "Hour of the day"))
  })
  
  # maps ----------------------------------------------------------------------- 
  districts_map <- reactive({
    districts@data <- districts@data %>% 
      select_("name", "DISTRICT", input$map_request_type) 
    
    colnames(districts@data) <- c("name", "district", "totals")
    
    districts
  })
  
  output$district_map <- renderLeaflet({
    
    mapbox <- "https://api.mapbox.com/styles/v1/robertmitchellv/cipr7teic001aekm72dnempan/tiles/256/{z}/{x}/{y}@2x?access_token=pk.eyJ1Ijoicm9iZXJ0bWl0Y2hlbGx2IiwiYSI6ImNpcHI2cXFnbTA3MHRmbG5jNWJzMzJtaDQifQ.vtvgLokcc_EJgnWVPL4vXw"
    
    pal <- colorBin(
      warm, 
      domain = districts_map()$totals, 
      bins = 6)
    
    labels <- sprintf(
      "<strong>District %s</strong><br/>%g requests",
      districts_map()$name, districts_map()$totals
    ) %>% lapply(htmltools::HTML)
    
    leaflet(districts_map()) %>%
      addTiles(mapbox) %>%
      setView(lng = -118.2427, lat = 34.0537, zoom = 9) %>%
      addPolygons(
        fillColor = ~pal(totals),
        weight = 1.5,
        fillOpacity = 0.7,
        smoothFactor = 0.5,
        color = "white",
        highlight = highlightOptions(
          weight = 3,
          color = "#54565b",
          bringToFront = TRUE
        ),
        label = labels,
        labelOptions = labelOptions(
          style = list("font-weight" = "normal", padding = "3px 8px"),
          textsize = "15px",
          direction = "auto"
        )
      ) %>%
      addLegend(
        pal = pal, values = ~totals, opacity = 0.7, 
        title = NULL, position = "bottomright"
      ) 
  }) 
  
  # services ------------------------------------------------------------------- 
  service_start <- reactive({parse_date(input$service_date_range[1],
                                        locale = locale(tz = "US/Pacific"))}) 
  service_end <- reactive({parse_date(input$service_date_range[2],
                                      locale = locale(tz = "US/Pacific"))})
  service_period <- reactive({service_start() %--% service_end()}) 
  
  output$request_type_date_range <- renderPlotly({
    title_string <- paste(
      "Request Types by Volume from", 
      wday(service_start(), label = T), month(service_start(), label = T, abbr = F), 
      day(service_start()), year(service_start()), "to", 
      wday(service_end(), label = T), month(service_end(), label = T, abbr = F), 
      day(service_end()), year(service_end()), sep = " "
    )
    
    data %>% 
      filter(created_date %within% service_period()) %>%
      group_by(request_type) %>%
      count() %>%
      ungroup() %>%
      mutate(request_type = str_wrap(request_type, width = 25)) %>%
      plot_ly(y = ~request_type, x = ~n, hoverinfo = "x",
              type = "bar", orientation = "h",
              marker = list(color = warm[4])) %>% 
      layout(
        title = title_string, 
        xaxis = list(title = "", range = ~c(0, max(n) + 40000)),
        yaxis = list(title = ""),
        margin = list(l = 220, pad = 10))
    
  })
  
  output$mean_completion_time_date_range <- renderPlotly({
    title_string <- paste(
      "Mean Service Solve Time for Service Requests from", 
      wday(service_start(), label = T), month(service_start(), label = T, abbr = F), 
      day(service_start()), year(service_start()), "to", 
      wday(service_end(), label = T), month(service_end(), label = T, abbr = F), 
      day(service_end()), year(service_end()), sep = " "
    )
    
    data %>%
      filter(service_date %within% service_period()) %>%
      group_by(request_type) %>%
      summarise(mean_time_to_solve_days = round(mean(time_to_solve, na.rm = T), 2)) %>%
      mutate(request_type = str_wrap(request_type, width = 25)) %>%
      plot_ly(x = ~mean_time_to_solve_days, y = ~request_type,
              text = ~paste(mean_time_to_solve_days, "days", sep = " "),
              hoverinfo = "text",
              type = "bar", orientation = "h",
              marker = list(color = warm[4])) %>% 
      layout(
        title = title_string,
        xaxis = list(title = "", range = ~c(0, max(mean_time_to_solve_days) + 20)),
        yaxis = list(title = ""),
        margin = list(l = 220, pad = 10))
  })
  
} # end server


# run app ---------------------------------------------------------------------- 
shinyApp(ui, server)
