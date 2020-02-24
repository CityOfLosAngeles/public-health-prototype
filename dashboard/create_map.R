library(lubridate)
library(leaflet)

neighborhood_councils <- sf::st_read(
  "https://opendata.arcgis.com/datasets/674f80b8edee4bf48551512896a1821d_0.geojson"
)

council_districts <- sf::st_read(
  "https://opendata.arcgis.com/datasets/76104f230e384f38871eb3c4782f903d_13.geojson"
)

lapd_divisions <- sf::st_read(
  "https://opendata.arcgis.com/datasets/031d488e158144d0b3aecaa9c888b7b3_0.geojson"
)

latimes_neighborhoods <- sf::st_read(
  "https://s3-us-west-2.amazonaws.com/boundaries.latimes.com/archive/1.0/boundary/torrance-la-county-neighborhood-current.geojson"
)

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
    drop_na("longitude", "latitude") %>%
    sf::st_as_sf(coords=c("longitude", "latitude"), crs=4326) %>%
    sf::st_join(aggregation_level, join=sf::st_within, left=TRUE) %>%
    group_by_(join_key) %>%
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