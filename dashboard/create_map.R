library(lubridate)
library(leaflet)

neighborhood_councils <- sf::st_read(
  "https://opendata.arcgis.com/datasets/674f80b8edee4bf48551512896a1821d_0.geojson"
)

create_base_map <- function() {
  map <- leaflet(
      options = leafletOptions(minZoom = 9, maxZoom = 18)
    ) %>%
    addProviderTiles(providers$CartoDB.Positron) %>%
    setView(lng = -118.4, lat = 34.0, zoom = 9)

  return(map)
}

prepare_map_data <- function(map_data) {
  service_request_data <- map_data %>%
    drop_na("longitude", "latitude") %>%
    sf::st_as_sf(coords=c("longitude", "latitude"), crs=4326) %>%
    sf::st_join(neighborhood_councils, join=sf::st_within, left=TRUE) %>%
    group_by(Name) %>%
    tally()
  neighborhood_service_requests <- left_join(
    neighborhood_councils,
    sf::st_drop_geometry(service_request_data),
    by="Name"
  )
  return(sf::st_zm(neighborhood_service_requests))
}

draw_map_data <- function(map, neighborhood_service_requests) {
  pal <- colorNumeric("magma", NULL)

  labels <- sprintf(
    "<strong>%s</strong><br/>Service Requests: %g",
    neighborhood_service_requests$Name, neighborhood_service_requests$n
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