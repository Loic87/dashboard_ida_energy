
all_countries <- eu_countries %>% 
  rbind(efta_countries) %>%
  rbind(eu_candidate_countries) %>%
  rbind(data.frame(code = "UK", name = "United Kingdom", label = "United Kingdom"))

get_country_long <-function(country_code){
  filter(all_countries, code == country_code)$name
}

get_country_code <-function(country_name){
  filter(all_countries, name == country_name)$code
}

country_code_list <- all_countries$code
country_long_list <- all_countries$name