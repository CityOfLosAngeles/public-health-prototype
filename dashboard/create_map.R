library(lubridate)
library(leaflet)

source("load_data.R")


neighborhoodCouncils <- sf::st_read(
  "https://opendata.arcgis.com/datasets/674f80b8edee4bf48551512896a1821d_0.geojson"
)
service_request_data <- load_data() %>%
  drop_na("longitude", "latitude") %>%
  sf::st_as_sf(coords=c("longitude", "latitude"), crs=4326) %>%
  sf::st_join(neighborhoodCouncils, join=sf::st_within, left=TRUE) %>%
  group_by(Name) %>%
  tally()
neighborhood_service_requests = left_join(
  neighborhoodCouncils,
  sf::st_drop_geometry(service_request_data),
  by="Name"
)

pal <- colorNumeric("magma", NULL)

labels <- sprintf(
  "<strong>%s</strong><br/>Service Requests: %g",
  neighborhood_service_requests$Name, neighborhood_service_requests$n
) %>% lapply(htmltools::HTML)

m <- leaflet(
    sf::st_zm(neighborhood_service_requests),
    options = leafletOptions(minZoom = 10, maxZoom = 18)
  ) %>%
  addProviderTiles(providers$CartoDB.Positron) %>%
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
  ) %>%
  setView(lng = -118.4, lat = 34.0, zoom = 10)
m  # Print the map
