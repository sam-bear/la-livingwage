library(tidyverse)
source("script/0-config.R")

x = read_csv(file.path(flight_traffic_path, "T_T100D_MARKET_ALL_CARRIER_2025.csv"))

x = x %>% filter(!(DEST=="LAX" & ORIGIN == "LAX"))

ob = x %>% filter(ORIGIN == "LAX")
ib = x %>% filter(DEST == "LAX")
