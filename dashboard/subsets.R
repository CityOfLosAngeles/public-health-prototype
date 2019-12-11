#' This script loads the subsets that will help power the dashboard

subset_data <- function(data) {
  data <- data %>% 
    group_by(request_source) %>% 
    mutate(request_source_total = n()) %>%
    ungroup()
  
  data <- data %>% 
    mutate(created_date_static = created_date,
           created_date_week = lubridate::week(created_date),
           created_date_month = lubridate::month(created_date, 
                                                 label = T, abbr = F))
  data <- data %>% 
    group_by(request_source, created_date_static) %>%
    mutate(request_by_day = n()) %>%
    ungroup() %>%
    group_by(request_source, created_date_week) %>%
    mutate(request_by_week = n()) %>%
    ungroup() %>%
    group_by(request_source, created_date_month) %>%
    mutate(request_by_month = n()) %>%
    ungroup()
  
  data <- data %>%
    mutate(day = lubridate::wday(created_date, label = TRUE),
           hour = lubridate::hour(created_date)) 
  
  data <- data %>% 
    group_by(council_district) %>%
    mutate(total_requests_by_district = n()) %>%
    ungroup()
  # broken not needed
  # data <- data %>%
  #   mutate(
  #     time_to_solve = round(created_date %--% closed_date / ddays(1), 2),
  #     update_not_solved = if_else(
  #       is.na(closed_date),
  #       round(created_date %--% updated_date / ddays(1), 2),
  #       parse_double(NA_integer_)),
  #     request_to_service = round(created_date %--% service_date / ddays(1), 2),
  #     service_to_closed = round(service_date %--% closed_date / ddays(1), 2))  
  # 
  return(data)
}