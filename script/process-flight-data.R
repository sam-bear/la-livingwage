library(tidyverse)

x = read_csv("~/Downloads/T_T100D_MARKET_ALL_CARRIER_2025.csv")

x = x %>% filter(!(DEST=="LAX" & ORIGIN == "LAX"))

ob = x %>% filter(ORIGIN == "LAX")
ib = x %>% filter(DEST == "LAX")
