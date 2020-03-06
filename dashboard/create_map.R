library(lubridate)
library(leaflet)



create_base_map <- function() {
  map <- leaflet(
      options = leafletOptions(minZoom = 9, maxZoom = 18)
    ) %>%
    addProviderTiles(providers$CartoDB.Positron) %>%
    setView(lng = -118.4, lat = 34.0, zoom = 9)

  return(map)
}

prepare_map_data <- function(map_data, aggregation_level, join_key) {
  service_request_data <- map_data %>%
    group_by(.data[[join_key]]) %>%
    tally()
  aggregate_service_requests <- left_join(
    aggregation_level,
    sf::st_drop_geometry(service_request_data),
    by=join_key
  )
  aggregate_service_requests[c("n")][is.na(aggregate_service_requests[c("n")])] <- 0
  return(sf::st_zm(aggregate_service_requests))
}

draw_map_data <- function(map, aggregate_service_requests, key) {
  pal <- colorNumeric("magma", NULL)

  labels <- sprintf(
    "<strong>%s</strong><br/>Service Requests: %g",
    aggregate_service_requests[[key]], aggregate_service_requests$n
  ) %>% lapply(htmltools::HTML)
  map <- map %>%
    clearShapes() %>%
    clearControls() %>%
    addPolygons(
      stroke = FALSE,
      smoothFactor = 0.0,
      fillOpacity = 0.6,
      fillColor = ~pal(n),
      label = labels,
      highlight = highlightOptions(
        fillOpacity=0.9
      )
    ) %>%
    addLegend("bottomright", pal = pal, values = ~n,
              title = "Service Requests",
              opacity = 1
    )
  return(map)
}