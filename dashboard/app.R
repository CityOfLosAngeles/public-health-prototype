## app.R ##
library(shiny)
library(shinydashboard)
library(leaflet)

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
      dateRangeInput('date', 'Date Range', start = NULL, end = NULL, min = NULL,
                     max = NULL, format = "yyyy-mm-dd", startview = "month",
                     weekstart = 0, language = "en", separator = " to ", width = NULL,
                     autoclose = TRUE)
    ),
    fluidRow(
      box(plotOutput("plot1", height = 250)),
      
      box(
        title = "Controls",
        sliderInput("slider", "Number of observations:", 1, 100, 50)
      )
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
  
  set.seed(122)
  histdata <- rnorm(500)
  
  output$plot1 <- renderPlot({
    data <- histdata[seq_len(input$slider)]
    hist(data)
  })
  
  div(
    output$dateText  <- renderText({
      paste("input$date is", as.character(input$date))
    })
  )
}

shinyApp(ui, server)