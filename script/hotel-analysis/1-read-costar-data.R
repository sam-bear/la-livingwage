source("script/0-loadFunctions.R")
source("script/0-loadPackages.R")

  #directory with data
      dir <- costar_downloads_path

  #load list of all hotels in city (roughly in city haven't verified boundaries)
      allhotels <- read_excel(file.path(dir, "AllHotels_LA_hotelinfo_raw.xlsx"))
      
  #it seems like all the non matches are either slight text name mismatches, hotel name changed, outside city boundaries, or abandoned/closed properties
      check <- read_rds(file.path(data_path, "CLEAN_COVERED_HOTEL_LIST_DEC2025.rds"))
      

  #label the files that are aggregated data for overveiw but not analysis
        agg_label <- c("AllTreated","CG_EmbCity","CG_Small","CG_Union")
        agg_info <- paste0(agg_label, "_hotelinfo.xlsx")


  #identify data groupings for analysis (treat + control)
      hotelinfo_fls <- list.files(dir, pattern= ".xlsx") %>% grep(pattern ="_hotelinfo", value = T) 
      hotelinfo_fls <- hotelinfo_fls[hotelinfo_fls %in% agg_info == F]
      hotelinfo_fls <- hotelinfo_fls[hotelinfo_fls %in% c("AllTreated_hotelinfo_monthly.xlsx","AllHotels_LA_hotelinfo_raw.xlsx","AllTreated_hotelinfo_daily.xlsx"  )==F]
      hotelinfo_group <- substr(hotelinfo_fls,1,3)

  #bring in hotel level info for analysis data
  #NOTE: this dataset only includes hotels that report data so should be used for data but not for defining sample
  #there are 30ish hotels that we know are treated but don't report data they are in the aggregated data
    hi <- list()
    for(i in 1:length(hotelinfo_fls)){
      hi[[i]] <- read_xlsx(file.path(dir, hotelinfo_fls[i])) %>% mutate(label = hotelinfo_group[i])
                                          }

  #clean up labeling (eg T01 = treatment group 1, C03 = control group 3)
    hi <- data.frame(rbindlist(hi))
    hi$treated = 0
    hi$treated[substr(hi$label,1,1)=="T"]<-1
    hi$group <- as.numeric(substr(hi$label,2,4))
    write_rds(hi, file = file.path(clean_path, "AnalysisHotelInfo_DataReported.rds"))
    
    
  #now bring in the aggregated group hotel info
  #this includes both hotels that do and do not report data
  
    hi_ag <- list()
    for(i in 1:length(agg_info)){
      hi_ag[[i]] <- read_excel(file.path(dir, agg_info[i])) %>% mutate(label = agg_label[i])
        }
    hi_ag = data.frame(rbindlist(hi_ag))
    
    
    #check inside city of LA:
    
        # 1) make sf points from lat/lon
          hi_ag_sf <- hi_ag %>%
          st_as_sf(coords = c("Longitude", "Latitude"), crs = 4326, remove = FALSE)
        
        # 2) make sure both layers use same CRS
        lac <- st_transform(lac, st_crs(hi_ag_sf))
        
        # 3) check whether each point falls inside LA city boundary
        inside_mat <- st_within(hi_ag_sf, lac, sparse = FALSE)
        
        # if lac has one polygon row:
        hi_ag_sf <- hi_ag_sf %>%
          mutate(in_la_city = inside_mat[, 1])
        
        
        hi_ag <- data.frame(hi_ag_sf) %>% dplyr::select(-geometry)
        
        
        
        
        
        hi_ag %>% filter(in_la_city== F & label == "AllTreated")        
        #11442137 incorrectly included in treated
        
        hi_ag <-  hi_ag %>% filter(!(in_la_city== F & label == "AllTreated"))        
        
        
    
    write_rds(hi_ag, file = file.path(clean_path, "AnalysisHotelInfo_aggData_includeNoDataReported.rds"))
    #this is the full list of hotels regardless of whether they report data
    

   #check counts
        table(hi$treated)
        table(hi_ag$label)
        #note: there are ~34 treated hotels that don't report data to costar so numbers won't match perfectly
        #analysis data will have fewer hotels that the full list of treated hotels
    
  #check cities
    #Marina Del Rey and Univeral City are outside LA boundaries (unincoroprated) so verify treated hotels int hese places are inside LA boundaries
    #looked up parcels on county assessor site and they're actually in la city so ok
    
    
    
  #check all hotels against the treat/control gorup make sure not missing any
    
    #just a few that were in our other data but not the master list can add them - most have small technicalities for why they're omitted
    addon = filter(hi_ag, PropertyID %in% allhotels$PropertyID == F & label != "CG_EmbCity")
    addon <- addon[,1:ncol(allhotels)]
    names(addon)<-names(allhotels)
    allhotels = rbind(allhotels, addon)
    
  #verify against manually collected list to check for discrpeancies (expect the loaded data to be more correct but double check)  
    
    lac <- read_sf(council_district_file)
    
  
    # 1) make sf points from lat/lon
    hotels_sf <- allhotels %>%
      st_as_sf(coords = c("Longitude", "Latitude"), crs = 4326, remove = FALSE)
    
    # 2) make sure both layers use same CRS
    lac <- st_transform(lac, st_crs(hotels_sf))
    
    # 3) check whether each point falls inside LA city boundary
    inside_mat <- st_within(hotels_sf, lac, sparse = FALSE)
    
    # if lac has one polygon row:
    hotels_sf <- hotels_sf %>%
      mutate(in_la_city = inside_mat[, 1])
    
    
    allhotels <- data.frame(hotels_sf) %>% dplyr::select(-geometry)
    allhotels <- allhotels %>% filter(in_la_city == TRUE)
    
    table(allhotels$City)
    
    allhotels$treated = 0
    allhotels$treated[allhotels$PropertyID %in% hi_ag$PropertyID[hi_ag$label=="AllTreated"]]<-1
    
    write_rds(allhotels, file = file.path(clean_path, "HotelsLACInfo_allSizeallTreatStatus.rds"))
    
   
    
    
    
    
    
    
    
    
    #########################. LOAD ACTUAL DATA ##################

    
  ### FIRST DO IT FOR LARGE GROUPS ####  
          
          agg_label <- c("AllTreated","CG_EmbCity","CG_Small","CG_Union")
          agg_dat <- paste0(agg_label, "_monthly.xlsx")
          add = list()
          for(i in 1:length(agg_dat)){add[[i]] = read_xlsx(file.path(dir, agg_dat[i])); add[[i]]$group = agg_label[i]}
          add = data.frame(rbindlist(add))
          
          add = add %>% mutate(month = substr(Period,1,3), year = as.numeric(substr(Period,4,8)), date = as.Date(paste("01",month,year,sep="-"),format = "%d-%b-%Y"))
          add = add %>% filter(year %in% 2016:2026)
          
          add <- add %>%
            mutate(
              across(
                starts_with("X12"),
                ~ parse_number(as.character(.))
              )
            )
          
          add <- add %>%
            mutate(
              across(
                starts_with("Market."),
                ~ parse_number(as.character(.))
              )
            )
          
          
          
         
          add$RevPAR <- as.numeric(add$RevPAR)
          add$ADR <- as.numeric(add$ADR)
          add$Occupancy <- as.numeric(add$Occupancy)
          add$Demand <- as.numeric(add$Demand)
          add$Supply <- as.numeric(add$Supply)
          add$Revenue <- as.numeric(add$Revenue)
          
          
          #bring in covariates
       
          
          covar <- read_rds(file.path(clean_path, "AnalysisHotelInfo_aggData_includeNoDataReported.rds")) %>%  sf::st_drop_geometry() %>%
            rename(group = label) %>%
            mutate(
              income  = X2024.Avg.HH.Inc.1m.,
              homeval = X2024.Median.Home.Value.1m.,
              hisp  = X2024.Hisp.Lat.Amer.Indian.and.Alaska.Nat.1m. +
                X2024.Hisp.Lat.Black.or.Afr.Amer.1m. +
                X2024.Hisp.Lat.Two.or.More.Races.1m. +
                X2024.Hisp.Lat.Asian.1m. +
                X2024.Hisp.Lat.Nat.Haw.n.and.Pac.Isldr.1m. +
                X2024.Hisp.Lat.White.1m.,
              black = X2024.Not.Hisp.Lat..Blk.or.Afr.Amer.1m.,
              mult  = X2024.Not.Hisp.Lat.Two.or.More.Races.1m.,
              asian = X2024.Not.Hisp.Lat.Asian.1m.,
              white = X2024.Not.Hisp.Lat..White.1m.,
              tot = hisp + black + asian + mult + white,
              share_hisp  = hisp / tot,
              share_black = black / tot,
              share_white = white / tot,
              share_asian = asian / tot,
              rest_num= ifelse(Restaurant == "Yes", 1, 0)
            ) %>% dplyr::select(-Restaurant)
          
          # ---------------------------
          # helper functions
          # ---------------------------
          
       
          
          # optional: weighted mode for categorical vars
          wmode_na <- function(x, w) {
            ok <- !is.na(x) & x != "" & !is.na(w) & w > 0
            if (sum(ok) == 0) return(NA_character_)
            tmp <- tapply(w[ok], x[ok], sum)
            names(tmp)[which.max(tmp)]
          }
          
          # ---------------------------
          # choose variables to exclude
          # ---------------------------
          
          drop_vars <- c(
            "PropertyID", "Property.Address", "Property.Name",
            "Parcel.Number.1.Min.", "Parcel.Number.2.Max.",
            "Latitude", "Longitude", "geometry"
          )
          
          # identify numeric and character variables after cleaning
          num_vars <- covar %>%
            select(-any_of(drop_vars), -group) %>%
            select(where(is.numeric)) %>%
            names()
          
          chr_vars <- covar %>%
            select(-any_of(drop_vars), -group) %>%
            select(where(~ is.character(.) || is.factor(.))) %>%
            names()
          
          # ---------------------------
          # aggregate to composite/group level
          # ---------------------------
          
          covar_group <- covar %>% mutate(wt_rooms = Rooms) %>% 
            group_by(group) %>%
            summarise(
              n_hotels = n(),
              rooms_total = sum(wt_rooms, na.rm = TRUE),
              
              # keep total rooms explicitly
              Rooms = sum(Rooms, na.rm = TRUE),
              
              # weighted numeric summaries
              across(
                all_of(setdiff(num_vars, "Rooms")),
                ~ weighted.mean(.x, wt_rooms, na.rm = T),
                .names = "{.col}"
              ),
              
              # modal categorical summaries
              across(
                all_of(chr_vars),
                ~ wmode_na(as.character(.x), wt_rooms),
                .names = "{.col}"
              ),
              
              .groups = "drop"
            )
          
          
          add = left_join(add, covar_group)
          
          
          write_rds(add, file = file.path(clean_path, "AnalysisData_LargeGroups.rds"))

          
          
  ### NOW DO IT FOR SMALL GROUPS ####  
          
          
          #identify data groupings for analysis (treat + control)
          hoteldat_fls <- list.files(dir, pattern= ".xlsx") %>% grep(pattern ="_monthly", value = T) 
          hoteldat_fls <- hoteldat_fls[hoteldat_fls %in% agg_dat == F]
          hoteldat_group <- substr(hoteldat_fls,1,3)
          
          #bring in hotel level info for analysis data
          #NOTE: this dataset only includes hotels that report data so should be used for data but not for defining sample
          #there are 30ish hotels that we know are treated but don't report data they are in the aggregated data
          hd <- list()
          for(i in 1:length(hoteldat_fls)){
            hd[[i]] <- read_xlsx(file.path(dir, hoteldat_fls[i])) %>% mutate(label = hoteldat_group[i])
          }
          
          #clean up labeling (eg T01 = treatment group 1, C03 = control group 3)
          hd <- data.frame(rbindlist(hd))
          hd$treated = 0
          hd$treated[substr(hd$label,1,1)=="T"]<-1
          hd$group <- as.numeric(substr(hd$label,2,4))

          hd = hd %>% mutate(month = substr(Period,1,3), year = as.numeric(substr(Period,4,8)), date = as.Date(paste("01",month,year,sep="-"),format = "%d-%b-%Y"))
          
          covar <- read_rds(file.path(clean_path, "AnalysisHotelInfo_DataReported.rds")) %>%  sf::st_drop_geometry() %>%
            mutate(
              income  = X2024.Avg.HH.Inc.1m.,
              homeval = X2024.Median.Home.Value.1m.,
              hisp  = X2024.Hisp.Lat.Amer.Indian.and.Alaska.Nat.1m. +
                X2024.Hisp.Lat.Black.or.Afr.Amer.1m. +
                X2024.Hisp.Lat.Two.or.More.Races.1m. +
                X2024.Hisp.Lat.Asian.1m. +
                X2024.Hisp.Lat.Nat.Haw.n.and.Pac.Isldr.1m. +
                X2024.Hisp.Lat.White.1m.,
              black = X2024.Not.Hisp.Lat..Blk.or.Afr.Amer.1m.,
              mult  = X2024.Not.Hisp.Lat.Two.or.More.Races.1m.,
              asian = X2024.Not.Hisp.Lat.Asian.1m.,
              white = X2024.Not.Hisp.Lat..White.1m.,
              tot = hisp + black + asian + mult + white,
              share_hisp  = hisp / tot,
              share_black = black / tot,
              share_white = white / tot,
              share_asian = asian / tot,
              rest_num= ifelse(Restaurant == "Yes", 1, 0)
            ) %>% dplyr::select(-Restaurant)
          
          # ---------------------------
          # helper functions
          # ---------------------------
          
          
          
          # optional: weighted mode for categorical vars
          wmode_na <- function(x, w) {
            ok <- !is.na(x) & x != "" & !is.na(w) & w > 0
            if (sum(ok) == 0) return(NA_character_)
            tmp <- tapply(w[ok], x[ok], sum)
            names(tmp)[which.max(tmp)]
          }
          
          # ---------------------------
          # choose variables to exclude
          # ---------------------------
          
          drop_vars <- c(
            "PropertyID", "Property.Address", "Property.Name",
            "Parcel.Number.1.Min.", "Parcel.Number.2.Max.",
            "Latitude", "Longitude", "geometry"
          )
          
          # identify numeric and character variables after cleaning
          num_vars <- covar %>%
            select(-any_of(drop_vars), -label) %>%
            select(where(is.numeric)) %>%
            names()
          
          chr_vars <- covar %>%
            select(-any_of(drop_vars), -label) %>%
            select(where(~ is.character(.) || is.factor(.))) %>%
            names()
          
          # ---------------------------
          # aggregate to composite/group level
          # ---------------------------
          
          covar_group <- covar %>% mutate(wt_rooms = Rooms) %>% 
            group_by(label) %>%
            summarise(
              n_hotels = n(),
              rooms_total = sum(wt_rooms, na.rm = TRUE),
              
              # keep total rooms explicitly
              Rooms = sum(Rooms, na.rm = TRUE),
              
              # weighted numeric summaries
              across(
                all_of(setdiff(num_vars, "Rooms")),
                ~ weighted.mean(.x, wt_rooms, na.rm = T),
                .names = "{.col}"
              ),
              
              # modal categorical summaries
              across(
                all_of(chr_vars),
                ~ wmode_na(as.character(.x), wt_rooms),
                .names = "{.col}"
              ),
              
              .groups = "drop"
            )
          
          
          hd = left_join(hd, covar_group)
          
          hd$RevPAR <- as.numeric(hd$RevPAR)
          hd$ADR <- as.numeric(hd$ADR)
          hd$Occupancy <- as.numeric(hd$Occupancy)
          hd$Demand <- as.numeric(hd$Demand)
          hd$Supply <- as.numeric(hd$Supply)
          hd$Revenue <- as.numeric(hd$Revenue)
          
      
          hd$cat = NA
          hd$cat[hd$label %in% paste0("T",sprintf("%02d",1:13))]<-"treated"
          hd$cat[hd$label %in% paste0("C",sprintf("%02d",1:4))]<-"control-union"
          hd$cat[hd$label %in% paste0("C",sprintf("%02d",5:6))]<-"control-small"
          hd$cat[hd$label %in% paste0("C",sprintf("%02d",7:11))]<-"control-othercity"
          
          
          
         
          
          
          
          write_rds(hd, file = file.path(clean_path, "AnalysisData_SubGroups.rds"))
          

          
          
          
          
######################################################################################################
#     Closures
          
          
          
          #load list of all hotels in city (roughly in city haven't verified boundaries)
          all = read_rds(file.path(clean_path, "AnalysisHotelInfo_aggData_includeNoDataReported.rds"))
          closures <- read_excel(file.path(costar_path, "Costar_PermanentClosures_Date.xlsx")) %>% rename(name = `Building Name`, closeDate = `Change Date`)
          cl_info <- read_excel(file.path(costar_path, "Costar_PermanentClosures_HotelList.xlsx")) %>% dplyr::select(PropertyID, name = `Property Name`,Rooms)
          closures = left_join(closures, cl_info)      
          closures$closeDate = as.Date(closures$closeDate, format = "%m/%d/%Y")
          closures$closeDateMonth = as.Date(format(closures$closeDate, "%Y-%m-01"))
          
          closures$treat = NA
          closures$treat[closures$closeDate < "2025-09-01"]<-0
          closures$treat[closures$PropertyID %in% all$PropertyID[all$label=="AllTreated"] & closures$closeDate >="2025-06-01"]<-1
          closures$treat[closures$PropertyID %in% all$PropertyID[all$label%in%c("CG_Union","CG_Small")]]<-0
          closures$treat[closures$Rooms < 60]<-0
          
          
          
          cdat_all = closures %>% group_by(closeDate) %>% summarise(n= n(), rooms = sum(Rooms))
          cdat_trt = closures %>% group_by(closeDate, treat) %>% summarise(n= n(), rooms = sum(Rooms))
          
          
          template = data.frame(closeDate = seq.Date(
            from = as.Date("2023-01-01"),
            to   = as.Date("2026-04-01"),
            by   = "month"
          ))
          
          
          cdat_all = template %>% left_join(cdat_all) %>% mutate(n = replace(n, is.na(n), 0), rooms = replace(rooms, is.na(rooms), 0)  )
          cdat_trt = template %>% left_join(cdat_trt) %>% mutate(n = replace(n, is.na(n), 0), rooms = replace(rooms, is.na(rooms), 0), treat = replace(treat, is.na(treat), 0)  )
          
          
          
          
          ######
          
          cinfo = read_xlsx(file.path(costar_path, "HotelClosureHotelInfo.xlsx")) %>% mutate(`Building Name` = `Property Name`) %>% dplyr::select(`Building Name`,Rooms,Restaurant, `Star Rating`)
          closures = read_xlsx(file.path(costar_path, "HotelClosureChanges.xlsx")) %>% filter(`Change Type`=="Operational Status Changes" & (`New Value`=="Permanently Closed" | `New Value` == "Temporarily Closed"))

          closures$date= as.Date(closures$`Change Date`, format = "%m/%d/%Y")
          closures$month = month(closures$date)
          
          closures = closures %>% filter(month %in% c(9:12, 1:4))
          
          closures$period = year(closures$date)
          closures$period[closures$month %in%9:12]<-closures$period[closures$month %in%9:12]+1
          closures = closures %>% left_join(cinfo)
          
          closures = closures %>% mutate(treat = Rooms>= 60)
          closures$treat[is.na(closures$treat)]<-0
          
          closures %>%  group_by(period, `New Value`, treat) %>% summarise(count = n()) %>% filter(period>=2023)
          
          closures %>%  group_by(period,  treat) %>% summarise(count = n(), star = mean(`Star Rating`, na.rm = T)) %>% filter(period>=2023)
