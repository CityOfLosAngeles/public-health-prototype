
#' A Quick Group-by, Summarise, Mutate function inspired by Pandas
#'
#' This function allows you to select one or more variables from a data frame
#' to perform (1st) a group_by() operation, (2nd) a summarise() count operation
#' with n(), and (3rd) then mutate() operation to create a percent variable.
#' Since it uses dplyr, it returns a data frame, which is easier to plot with.
#' @param
#' @keywords
#' @export
#' @example
#' value_counts()
value_counts <- function(.data, ...) {
  value_counts_(.data, .dots = lazyeval::lazy_dots(...))
}

value_counts_ <- function(.data, ..., .dots) {
  dots <- lazyeval::all_dots(.dots, ..., all_named = TRUE)
  out <- dplyr::group_by_(.data, .dots = dots)
  out <- dplyr::summarise(out, n = n())
  out <- dplyr::mutate(out, percent = round(n / sum(n) * 100, 2))
  out <- dplyr::arrange(out, desc(n))
  return(out)
}