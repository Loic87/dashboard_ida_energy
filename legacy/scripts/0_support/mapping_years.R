get_min_year <- function(df, column_name){
  df %>% 
    filter(!is.na(!!sym(column_name))) %>%
    filter(!!sym(column_name) > 0) %>%
    select(c("time")) %>%
    min()
}

get_max_year <- function(df, column_name){
  df %>% 
    filter(!is.na(!!sym(column_name))) %>%
    filter(!!sym(column_name) > 0) %>%
    select(c("time")) %>%
    max()
}

get_years_with_data <- function(
    activity_df,
    activity_col,
    energy_df,
    energy_col,
    first_year,
    last_year
) {
  first_year_activity <- get_min_year(activity_df, activity_col)
  last_year_activity <- get_max_year(activity_df, activity_col)
  first_year_energy <- get_min_year(energy_df, energy_col)
  last_year_energy <- get_max_year(energy_df, energy_col)
  
  first_year_with_data <- max(first_year_activity, first_year_energy, first_year)
  last_year_with_data <- min(last_year_activity, last_year_energy, last_year)
  
  list(first_year_with_data, last_year_with_data)
}