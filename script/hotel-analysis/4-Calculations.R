
source("script/0-loadFunctions.R")
source("script/0-loadPackages.R")

############# Calculations for report #############
allhotels <- read_rds(file.path(clean_path, "HotelsLACInfo_allSizeallTreatStatus.rds")) %>%
  mutate(treat = treated)

smz =    allhotels %>% group_by(treat) %>% 
  summarise(rooms = sum(Rooms), count = n()) %>% as.data.frame() %>% dplyr::select(-any_of("geometry"))

smz$share_room = smz$room/sum(smz$room)    
smz$share_count = smz$count/sum(smz$count)



########    Make table with basic summary #####
allhotels$restaurant_num <- ifelse(allhotels$Restaurant == "Yes", 1, 0)

summary_tab_small <- allhotels %>% as.data.frame() %>% dplyr::select(-any_of("geometry")) %>%
  group_by(treat) %>%
  summarise(
    `Hotels` = n(),
    `Total rooms` = sum(Rooms, na.rm = TRUE),
    `Average rooms` = mean(Rooms, na.rm = TRUE),
    `Average star rating` = mean(Star.Rating, na.rm = TRUE),
    `Share with restaurant` = 100*mean(restaurant_num, na.rm = TRUE),
    `Average meeting rooms` = mean(Mtg.Rooms, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    treat = ifelse(treat == 1, "Yes", "No"),
    # `Share with restaurant` = percent(`Share with restaurant`, accuracy = 0.1)
  ) %>%
  pivot_longer(-treat, names_to = "Measure", values_to = "Value") %>%
  pivot_wider(names_from = treat, values_from = Value)

summary_tab_small


library(flextable)

ft <- flextable(summary_tab_small)
ft <- autofit(ft)







summary_tab_small <- allhotels %>% as.data.frame() %>% dplyr::select(-any_of("geometry")) %>% mutate(income = X2025.Avg.HH.Inc.1m., homeval = X2025.Median.Home.Value.1m.) %>%
  mutate(hisp = X2025.Hisp.Lat.Amer.Indian.and.Alaska.Nat.1m. + X2025.Hisp.Lat.Black.or.Afr.Amer.1m. + X2025.Hisp.Lat.Two.or.More.Races.1m. + X2025.Hisp.Lat.Asian.1m.+X2025.Hisp.Lat.Nat.Haw.n.and.Pac.Isldr.1m.+X2025.Hisp.Lat.White.1m.,
         black = X2025.Not.Hisp.Lat..Blk.or.Afr.Amer.1m., mult = X2025.Not.Hisp.Lat.Two.or.More.Races.1m.,asian = X2025.Not.Hisp.Lat.Asian.1m., white = X2025.Not.Hisp.Lat..White.1m.,
         tot = hisp + black + asian + mult + white, share_hisp = hisp/tot, share_black = black/tot, share_white = white/tot, share_asian = asian/tot) %>% 
  
  group_by(treat) %>%
  summarise(
    `Hotels` = n(),
    `Total rooms` = sum(Rooms, na.rm = TRUE),
    `Average rooms` = mean(Rooms, na.rm = TRUE),
    `Median rooms` = median(Rooms, na.rm = TRUE),
    `Average star rating` = mean(Star.Rating, na.rm = TRUE),
    `Share with restaurant` = 100*mean(restaurant_num, na.rm = TRUE),
    `Average meeting rooms` = mean(Mtg.Rooms, na.rm = TRUE),
    `Average neighborhood income` = mean(income, na.rm = T),
    `Median neighborhood home value` = mean(homeval, na.rm = T),
    `Share neighborhood pop Hispanic` = 100*mean(share_hisp, na.rm = T),
    `Share neighborhood pop NH White` = 100*mean(share_white, na.rm = T),
    `Share neighborhood pop NH Black` = 100*mean(share_black, na.rm = T),
    `Share neighborhood pop NH Asian` = 100*mean(share_asian, na.rm = T),
    
    .groups = "drop"
  ) %>%
  mutate(
    treat = ifelse(treat == 1, "Yes", "No"),
    # `Share with restaurant` = percent(`Share with restaurant`, accuracy = 0.1)
  ) %>%
  pivot_longer(-treat, names_to = "Measure", values_to = "Value") %>%
  pivot_wider(names_from = treat, values_from = Value)

write_xlsx(summary_tab_small,  "tables/hotel_treat_char.xlsx")







#######################
