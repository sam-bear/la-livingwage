source("script/0-loadFunctions.R")
source("script/0-loadPackages.R")


hotels <- list()
hotels[[1]] <- read.csv(file.path(hotel_lists_path, "hotel_tax_finance.csv"))
hotels[[2]] <- read.csv(file.path(hotel_lists_path, "hotels_los_angeles_building_safety.csv"))
hotels[[3]] <- read.csv(file.path(hotel_lists_path, "LA Hotels by Councilmember Districts 03182025_AHLA.csv"))
hotels[[4]] <- read.csv(file.path(hotel_lists_path, "tourism_board_list.csv"))
names(hotels)<-c("finance","blddpt","ahla","tourism")



aha_list <- hotels[["ahla"]] %>% filter( Rooms >= 60 & Unionized!="Yes" ) #%>% nrow()
bldsafe_list <- hotels[["blddpt"]] %>% drop_na(ROOMS) %>% filter(ROOMS>=60 & USE_DESC == "Hotel") #%>% nrow()
tourism_list <- hotels[["tourism"]] %>% filter(Rooms >= 60)


#what should i pull from finance?

#start with tourism board since list is longest
hotel_list <- tourism_list %>% rename(rooms_tourism = Rooms); hotel_list$Name.of.Establishment[hotel_list$Name.of.Establishment=="Sonder The Winfield"]<-"The Winfield"
hotel_list <- hotel_list %>% full_join(aha_list, join_by(Name.of.Establishment==Hotel.Name)) %>% rename(rooms_aha = Rooms)

bldsafe_list = bldsafe_list %>% filter(tolower(Address) %in% tolower(hotel_list$Address.1)==F)
write_csv(bldsafe_list, file = file.path(hotel_lists_path, "bldsafe_list_2check.csv"))
#this has now combined tourism and aha. Now add in building safety





write_csv(hotel_list, file = file.path(hotel_lists_path, "Complete_Hotel_list.csv"))

  ### next step is manually fill the missing addresses and reconcile variables across datasets

    #manually filled in missing addresses so join that back in
        hotel_list1 <- read_csv(file.path(hotel_lists_path, "Complete_Hotel_list_manualAddressFill.csv")); names(hotel_list1) <- c("hotel_name","address","city","zip")
        hotel_list <- read_csv(file.path(hotel_lists_path, "Complete_Hotel_list.csv")); names(hotel_list)<-c("hotel_name","rooms_tb","district_no","councilmember","address","city","zip","rooms_aha","chain","class","rstrnt_yn","operation","unionized","unionized_count")
        hotel_list = hotel_list %>% dplyr::rename(address1 = address, city1 = city, zip1 = zip) #rename to check join worked
        hotel_list <- hotel_list %>% left_join(hotel_list1)
        
    #joining by name make sure the non missing addresses worked correctly then can drop duplicate address var if no issue
        if (sum(hotel_list$address1 != hotel_list$address & !is.na(hotel_list$address), na.rm = T)>0){print('something wrong with merge')}
    
    
    hotel_list <- hotel_list %>% dplyr::select(-address1, -city1, -zip1)
      #5 hotels have missing addresses but manual check susggests they should all be dropped
        hotel_list <- hotel_list %>% drop_na(address)
        hotel_list <- hotel_list %>% rename(street = address)
        hotel_list <- hotel_list %>% mutate(address = paste(street, city, zip, sep=", "))
       
    #join rooms - tb seems to have better data less missings and more reliable plus aha never seems to contradict just has more missings but some that tb doesn't have
        hotel_list$rooms_tb[is.na(hotel_list$rooms_tb)] <- hotel_list$rooms_aha[is.na(hotel_list$rooms_tb)] 
        hotel_list <- hotel_list %>% dplyr::select(-rooms_aha) %>% rename(rooms = rooms_tb)
        
        
        
    #now geocode addresses to get lat/lon (from cgbt)
        
             
               
                census_geocode_one <- function(address, city = NULL, state = "CA", zip = NULL) {
                  # Prefer one-line input if you have it
                  q <- list(
                    benchmark = "Public_AR_Current",
                    format = "json"
                  )
                  
                  if (!is.null(address) && is.null(city) && is.null(zip)) {
                    q$address <- address
                    url <- "https://geocoding.geo.census.gov/geocoder/locations/onelineaddress"
                  } else {
                    q$street <- address
                    q$city <- city
                    q$state <- state
                    if (!is.null(zip)) q$zip <- zip
                    url <- "https://geocoding.geo.census.gov/geocoder/locations/address"
                  }
                  
                  resp <- request(url) |> req_url_query(!!!q) |> req_perform()
                  txt <- resp_body_string(resp)
                  js <- fromJSON(txt)
                  
                  matches <- js$result$addressMatches
                  if (length(matches) == 0) {
                    return(tibble(match = FALSE, matched_address = NA_character_, lon = NA_real_, lat = NA_real_))
                  }
                  
                  best <- matches[1, ]
                  tibble(
                    match = TRUE,
                    matched_address = best$matchedAddress,
                    lon = best$coordinates$x,
                    lat = best$coordinates$y
                  )
                }
                
                # Example: df has a column `full_address`
                # df <- tibble(full_address = c("200 N Spring St, Los Angeles, CA 90012", "1 World Way, Los Angeles, CA 90045"))
                
                hotel_list <- hotel_list %>% 
                  mutate(row_id = row_number()) %>%
                  rowwise() %>%
                  do(bind_cols(., census_geocode_one(.$address))) %>%
                  ungroup()
                
                #4 addresses didn't work for some reason do those manually
                filter(df_geo, is.na(lon)) %>% as.data.frame()
                hotel_list = as.data.frame(hotel_list)
                hotel_list[(hotel_list$hotel_name=="Holiday Inn Express West Los Angeles Santa Monica"),c("lon","lat")]<-c(-118.44722778854485, 34.0468248467163)
                hotel_list[(hotel_list$hotel_name=="Hyatt House LA University Medical Center"),c("lon","lat")]<-c(-118.20218128854411, 34.06460530858508)
                hotel_list[(hotel_list$hotel_name=="The Godfrey Hotel Hollywood"),c("lon","lat")]<-c(-118.32917425970669,34.096610262799864)
                hotel_list[(hotel_list$hotel_name=="UCLA Meyer & Renee Luskin Conference Center Hotel"),c("lon","lat")]<-c(-118.4457852038879, 34.069479881787714)

                
              ####now pull the district####
                      dist <- read_sf(council_district_file)
                      
                
                        # Convert hotels to sf points 
                        hotels_sf <- st_as_sf(
                          hotel_list,
                          coords = c("lon", "lat"),   
                          crs = 4326,
                          remove = FALSE
                        )
                        
                        #  Transform points to district CRS (just as check prob not necessary)
                        hotels_sf <- st_transform(hotels_sf, st_crs(dist))
                        
                        #Spatial join: attach district attributes to each hotel point
                        hotels_with_dist <- st_join(hotels_sf, dist, left = TRUE, join = st_within)
                        hotels_with_dist <- hotels_with_dist %>% st_drop_geometry() %>% dplyr::select(hotel_name, lon, lat, NAME, District)
                        
                        # join back in
                        
                        hotels <- left_join(hotel_list, hotels_with_dist)
                        hotels$NAME[hotels$NAME=="Kevin de León"]<-"Ysabel Jurado"
                        hotels$councilmember[is.na(hotels$councilmember)] <- hotels$NAME[is.na(hotels$councilmember)]
                        hotels$district_no[is.na(hotels$district_no)] <- hotels$District[is.na(hotels$district_no)]
                        
                        hotels %>% dplyr::select(councilmember, district_no) %>% distinct() %>% arrange(district_no)
                        hotels$councilmember[hotels$councilmember=="Hugo Soto-Martínez"] <- "Hugo Soto-Martinez"
                        
                        hotels$councilmember[hotels$hotel_name=="Holiday Inn Los Angeles LAX Airport"] <- "Traci Park"
                        hotels$district_no[hotels$hotel_name=="Holiday Inn Los Angeles LAX Airport"] <- 11
                        
                        
                  
                  #####check whether in border of Los Angeles ####
                        
                        lac <- read_sf(city_boundary_file) %>% filter(CITY_NAME=="Los Angeles")
                        
                        # Convert hotels to sf points 
                        hotels_sf <- st_as_sf(
                          hotels,
                          coords = c("lon", "lat"),   
                          crs = 4326,
                          remove = FALSE
                        )
                        hotels_sf <- st_transform(hotels_sf, st_crs(lac))
                        hotels_with_city <- st_join(hotels_sf, lac, left = TRUE, join = st_within)
                        hotels_with_city = hotels_with_city %>% dplyr::select(hotel_name, CITY = CITY_NAME) %>% st_drop_geometry() 
                        hotels <- left_join(hotels, hotels_with_city)
                        
                        filter(hotels, is.na(CITY)) #west hollywood clearly outside other 2 look very close looks like just outside even with LA address prob want to drop eventually
                        
                        hotels = filter(hotels, hotel_name != "AKA West Hollywood")
                        hotels = hotels %>% dplyr::select(-geometry) %>% rename(city_boundary_check = CITY) %>% dplyr::select(-NAME, -District, -row_id, -match)
                        hotels$city_boundary_check[hotels$city_boundary_check!="Los Angeles"] <- "Other"
                        
                        
                        
                  #to check other dataset geocde and compare lat lon to see if any unique (maybe after slight rounding)
                      write_rds(hotels, file = file.path(data_path, "CLEAN_COVERED_HOTEL_LIST_DEC2025.rds"))
                        
                  
                  
