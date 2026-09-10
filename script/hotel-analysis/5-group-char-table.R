df <- read_rds('data/clean/AnalysisData_SubGroups.rds') %>% filter(date>="2023-01-01") 

        
        #clean up labeling ---
        plot_labels <- df %>% filter(substr(label,1,1)=="T") %>% 
          mutate(rooms_per = Rooms/n_hotels) %>% 
          group_by(label, Hotel.Class, Submarket.Name) %>% 
          summarise(stars = mean(Star.Rating), mstar = min(Star.Rating), rooms = mean(rooms_per)) %>% 
          mutate(
            rooms_label = "Small", 
            rooms_label = replace(rooms_label, rooms >=90 & rooms<120, "Medium"),
            rooms_label = replace(rooms_label, rooms >=120 & rooms<300, "Large"),
            rooms_label = replace(rooms_label, rooms >=300 , "Mega"),
            
            mkt_label = "Hollywood/West LA",
            mkt_label = replace(mkt_label, Submarket.Name == "Los Angeles Airport", "Airport"),
            mkt_label = replace(mkt_label, Submarket.Name == "Los Angeles CBD", "Downtown (CBD)"),
            mkt_label = replace(mkt_label, Submarket.Name == "Los Angeles North", "North LA"),
            mkt_label = replace(mkt_label, Submarket.Name == "Los Angeles Airport", "Airport"),
            
            class_label = "Luxury",
            class_label = replace(class_label, Hotel.Class == "Upper Midscale", "Midscale"),
            class_label = replace(class_label, Hotel.Class == "Upscale", "Upscale"),
            class_label = replace(class_label, Hotel.Class == "Upper Upscale" & mkt_label!="North LA", "Upscale"),
            class_label = replace(class_label, Hotel.Class == "Upper Upscale" & mkt_label=="North LA" & stars>3.8, "Luxury"),
            
            
          ) %>% 
          as.data.frame() %>% arrange(Submarket.Name) %>% 
          mutate(plot_label = paste(mkt_label, class_label, rooms_label, sep =" - ")) %>% 
          dplyr::select(label, plot_label)



tdat  <- df %>% mutate(rooms_per = Rooms/n_hotels) %>% 
      group_by(label) %>% 
      summarise(
        NumberofHotels = mean(n_hotels, na.rm = T),
        share_rooms= sum(Rooms, na.rm = T),
        Rooms = mean(rooms_per, na.rm = T),
        ShareRestaurant = mean(rest_num, na.rm = T),
        Stars =mean(Star.Rating, na.rm = T),
        YearBuilt = mean(Year.Built, na.rm = T),
        YearLastRenovated = mean(Year.Renovated, na.rm = T),
        TaxesPaid = mean(Taxes.Total, na.rm =T),
        ADR = mean(ADR, na.rm = T),
        RevPAR = mean(RevPAR, na.rm = T),
        Revenue = mean(Revenue, na.rm = T),
        Occupancy = mean(Occupancy, na.rm = T),
        Demand =mean(Demand, na.rm = T),
        MedianIncome = mean(income, na.rm = T),
        shareWhite = mean(share_white, na.rm = T),
        shareHisp = mean(share_hisp, na.rm = T),
        shareBlack = mean(share_black, na.rm = T),
        shareAsian = mean(share_asian, na.rm = T)
      ) %>% 
  left_join(plot_labels) %>% filter(substr(label,1,1)=="T")
        
        
        
tdat = tdat %>% arrange(plot_label) 
        

tdat[,grep(x = names(tdat), pattern ="Year")] <- round(tdat[,grep(x = names(tdat), pattern ="Year")], 0)     
tdat[,grep(x = names(tdat), pattern ="share")] <- round(100*tdat[,grep(x = names(tdat), pattern ="share")], 1)     
  tdat$MedianIncome = round(tdat$MedianIncome/1000  )  
  tdat$Demand = round(tdat$Demand  )  
  tdat$Occupancy = round(100*tdat$Occupancy, 1  )  
  tdat$ShareRestaurant = round(100*tdat$ShareRestaurant, 1  )  
  tdat$RevPAR = round(tdat$RevPAR, 2  )  
  tdat$ADR = round(tdat$ADR, 2  )  
  tdat$TaxesPaid = round(tdat$TaxesPaid/1000, 0  ) 

  tdat$Revenue = round(tdat$Revenue/1000000, 1  ) 
  tdat$Rooms = round(tdat$Rooms)
  tdat$Stars = round(tdat$Stars,1)
  
  
  write_xlsx(tdat, "output/ATable-group-char.xlsx")
  
  
  
  
  #check hotel counts
  
  rmct = df %>% mutate(rooms_per = Rooms/n_hotels) %>% dplyr::select(label, Rooms, rooms_per) %>% distinct() %>% filter(substr(label,1,1)=="T")

#############
  
  
  
  
  
  
  df <- read_rds('data/clean/AnalysisData_SubGroups.rds') %>% filter(date>="2023-01-01") 
  
  
  #clean up labeling ---
  plot_labels <- df %>% filter(substr(label,1,1)=="C") %>% 
    mutate(rooms_per = Rooms/n_hotels) %>% 
    group_by(label, Hotel.Class, Submarket.Name, cat) %>% 
    summarise(stars = mean(Star.Rating), mstar = min(Star.Rating), rooms = mean(rooms_per)) %>% 
    mutate(
      rooms_label = "Small", 
      rooms_label = replace(rooms_label, rooms >=90 & rooms<120, "Medium"),
      rooms_label = replace(rooms_label, rooms >=120 & rooms<300, "Large"),
      rooms_label = replace(rooms_label, rooms >=300 , "Mega"),
      
      mkt_label = "Hollywood/West LA",
      mkt_label = replace(mkt_label, Submarket.Name == "Los Angeles Airport", "Airport"),
      mkt_label = replace(mkt_label, Submarket.Name == "Los Angeles CBD", "Downtown (CBD)"),
      mkt_label = replace(mkt_label, Submarket.Name == "Los Angeles North", "North LA"),
      mkt_label = replace(mkt_label, Submarket.Name == "Los Angeles Airport", "Airport"),
      
      class_label = "Luxury",
      class_label = replace(class_label, Hotel.Class == "Upper Midscale", "Midscale"),
      class_label = replace(class_label, Hotel.Class == "Upscale", "Upscale"),
      class_label = replace(class_label, Hotel.Class == "Upper Upscale" & mkt_label!="North LA", "Upscale"),
      class_label = replace(class_label, Hotel.Class == "Upper Upscale" & mkt_label=="North LA" & stars>3.8, "Luxury"),
      
      
    ) %>% 
    as.data.frame() %>% arrange(Submarket.Name) %>% 
    mutate(plot_label = paste(mkt_label, class_label, rooms_label, sep =" - ")) %>% 
    dplyr::select(label, plot_label)
  
  
  
  tdat  <- df %>% mutate(rooms_per = Rooms/n_hotels) %>% 
    group_by(label, cat) %>% 
    summarise(
      NumberofHotels = mean(n_hotels, na.rm = T),
      share_rooms= sum(Rooms, na.rm = T),
      Rooms = mean(rooms_per, na.rm = T),
      ShareRestaurant = mean(rest_num, na.rm = T),
      Stars =mean(Star.Rating, na.rm = T),
      YearBuilt = mean(Year.Built, na.rm = T),
      YearLastRenovated = mean(Year.Renovated, na.rm = T),
      TaxesPaid = mean(Taxes.Total, na.rm =T),
      ADR = mean(ADR, na.rm = T),
      RevPAR = mean(RevPAR, na.rm = T),
      Revenue = mean(Revenue, na.rm = T),
      Occupancy = mean(Occupancy, na.rm = T),
      Demand =mean(Demand, na.rm = T),
      MedianIncome = mean(income, na.rm = T),
      shareWhite = mean(share_white, na.rm = T),
      shareHisp = mean(share_hisp, na.rm = T),
      shareBlack = mean(share_black, na.rm = T),
      shareAsian = mean(share_asian, na.rm = T)
    ) %>% 
    left_join(plot_labels) %>% filter(substr(label,1,1)=="C")
  
  
  
  tdat = tdat %>% arrange(plot_label) 
  
  
  tdat[,grep(x = names(tdat), pattern ="Year")] <- round(tdat[,grep(x = names(tdat), pattern ="Year")], 0)     
  tdat[,grep(x = names(tdat), pattern ="share")] <- round(100*tdat[,grep(x = names(tdat), pattern ="share")], 1)     
  tdat$MedianIncome = round(tdat$MedianIncome/1000  )  
  tdat$Demand = round(tdat$Demand  )  
  tdat$Occupancy = round(100*tdat$Occupancy, 1  )  
  tdat$ShareRestaurant = round(100*tdat$ShareRestaurant, 1  )  
  tdat$RevPAR = round(tdat$RevPAR, 2  )  
  tdat$ADR = round(tdat$ADR, 2  )  
  tdat$TaxesPaid = round(tdat$TaxesPaid/1000, 0  ) 
  
  tdat$Revenue = round(tdat$Revenue/1000000, 1  ) 
  tdat$Rooms = round(tdat$Rooms)
  tdat$Stars = round(tdat$Stars,1)
  
  
  write_xlsx(tdat, "output/ATable-group-char-control.xlsx")
  
  
