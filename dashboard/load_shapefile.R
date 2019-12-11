library(tidyverse)

load_shapefile <- function(data) {
  
  # load the shapefiles
  districts <- rgdal::readOGR(
    dsn = "data/shapefiles/la_city_council_district_2012.shp", 
    layer = "la_city_council_district_2012",
    verbose = F
  )
  
  # start organizing the data request numbers by council district 
  council_service_totals <- data %>%
    group_by(council_district, request_type) %>%
    count() %>%
    spread(request_type, n)
  
  # make the new variable names easier to work with 
  colnames(council_service_totals) <- colnames(council_service_totals) %>% 
    stringr::str_to_lower() %>% 
    stringr::str_replace_all(" |/", "_")
  
  # now sum all categories to get a total number of requests
  council_service_totals <-
    group_by(council_service_totals, council_district) %>%
    mutate(total_requests = sum(
      bulky_items, dead_animal_removal, 
      electronic_waste, feedback,
      graffiti_removal, homeless_encampment,
      illegal_dumping_pickup, metal_household_appliances,
      multiple_streetlight_issue, other, report_water_waste,
      single_streetlight_issue)
    ) 
  
  # make the variable name for 'district' match the shapefile 
  colnames(council_service_totals)[1] <- "DISTRICT"
  
  # convert DISTRICT and name to int so we can join data
  districts@data$DISTRICT <- parse_integer(districts@data$DISTRICT)
  districts@data$name <- parse_integer(districts@data$name)
  
  # left join the data to the shapefile
  districts@data <- left_join(districts@data, council_service_totals, by = "DISTRICT")
  
  # convert the district variable to factor
  districts@data$DISTRICT <- parse_factor(
    districts@data$DISTRICT,
    levels = c(
      "1", "2", "3", "4", "5", "6", "7", 
      "8", "9", "10", "11", "12", "13",
      "14", "15"
    ))
  
  # return the spatial polygons df
  return(districts)
  
}