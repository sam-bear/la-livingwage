source("script/0-loadFunctions.R")
source("script/0-loadPackages.R")

hotel_list <- read_rds(file.path(data_path, "CLEAN_COVERED_HOTEL_LIST_DEC2025.rds")) %>% filter(city_boundary_check!="Other")



dist_hotel = hotel_list %>% group_by(councilmember, district_no) %>% summarise(hotels = n(), rooms = sum(rooms)) %>% arrange(district_no)



#bring in CES4

    #load the two shapefiles
      dist <- read_sf(council_district_file)
      ces <- read_sf(ces_boundary_file)
    #get in same crs
      ces <- ces %>% st_transform(st_crs(dist))
    
    #having geometry issues
        dist = st_make_valid(dist)
        ces = st_make_valid(ces)
        sf_use_s2(FALSE)
        
        
    #Bring in averege home value and rent from ACS and add it to ACS at census tract before joining
        
        acs_year <- 2023                 
        state_fips <- "CA"
        county_fips <- "037"                    
        vars <- c(
          median_gross_rent = "B25064_001",
          median_home_value = "B25077_001"
        )
        
        # --- Download data ---
        la_housing_tract <- get_acs(
          geography = "tract",
          variables = vars,
          state = state_fips,
          county = county_fips,
          year = acs_year,
          survey = "acs5",
          geometry = F,     # FALSE if you only want tabular data
          output = "wide",
        ) %>%
          transmute(
            GEOID,
            NAME,
            median_gross_rent      = median_gross_rentE,
            median_gross_rent_moe  = median_gross_rentM,
            median_home_value     = median_home_valueE,
            median_home_value_moe = median_home_valueM,
            year = acs_year
          )
        la_housing_tract <- la_housing_tract %>% rename(Tract = GEOID) %>% mutate(Tract = as.numeric(Tract))
        
        
        ces = ces %>% left_join(la_housing_tract[,c("Tract","median_gross_rent","median_home_value")])
        
    #find overlap between CES and council district
        
        dist <- dist %>% st_join(ces, join = st_intersects) #gives every tract that overlaps every council district
        dist <- dist %>% st_drop_geometry() %>% as.data.frame()
        dist[dist==-999]=NA
        dist[dist==-1998]=NA
        
              
              
      #take average but looks like some variable a large negative number maybe used to indicate not enough data or something because getting weird means
            dist = dist %>% group_by(NAME, District, District_N) %>% summarise(across(TotPop19:median_home_value, ~mean(., na.rm = T)))
              
      
    #now bring in the hotel counts from the beginning
            dist =dist %>% rename(district_no = District)
            dist = dist %>% left_join(dist_hotel)
            dist$hotels[is.na(dist$hotels)]<-0
            dist$rooms[is.na(dist$rooms)]<-0
            dist = dist %>% dplyr::select(-councilmember)
            
      write_rds(dist, file = file.path(data_path, "CES4_by_councilDistrict.rds"))
      
      
      
      #### Try for hotel workers and wages by census tract
      
                  
                  # ------------------------------------------------------------
                  # Tract-level "hotel worker" surface for LA County (ACS proxy)
                  # + occupation-weighted wages (using your OES wage table)
                  # + optional calibration to trusted LA City total employment
                  #
                  # You provide:
                  #   1) oes_wages: data.frame with columns: soc, wage
                  #   2) crosswalk: data.frame with columns: occ_group, soc, within_group_weight (optional)
                  #   3) (optional) city_sf: sf polygon for LA City boundary (you can clip yourself too)
                  #   4) (optional) city_total_trusted: single number (trusted hotel employment total for LA City)
                  # ------------------------------------------------------------
                  
                  library(tidycensus)
                  library(dplyr)
                  library(stringr)
                  library(sf)
                  library(tidyr)
                  
                  # --- helpers ---
                  moe_sum <- function(moe_vec) sqrt(sum(moe_vec^2, na.rm = TRUE))
                  
                  # Drop geometry only when present
                  drop_geom_if <- function(df) {
                    if (inherits(df, "sf")) sf::st_drop_geometry(df) else df
                  }
                  
                  # ------------------------------------------------------------
                  # 1) ACS occupation-proxy: pull LA County tract occupation counts + shares
                  #    Uses collapsed occupation table C24010 (ACS 5-year; tracts require acs5).
                  #    Default occupation groups are "hotel-ish" but EDITABLE.
                  # ------------------------------------------------------------
                  get_la_tract_hotel_occ_proxy <- function(
    year = 2023,
    state = "CA",
    county = "037",
    keep_geometry = TRUE,
    occ_patterns = c(
      mgmt     = "Management, business, and financial",
      admin    = "Office and administrative support",
      food     = "Food preparation and serving related",
      cleaning = "Building and grounds cleaning and maintenance",
      personal = "Personal care and service"
    )
                  ) {
                    x <- get_acs(
                      geography = "tract",
                      table = "C24010",
                      state = state,
                      county = county,
                      year = year,
                      survey = "acs5",
                      geometry = keep_geometry   # ✅ correct arg name
                    )
                    
                    occ_long <- bind_rows(lapply(names(occ_patterns), function(g) {
                      pat <- occ_patterns[[g]]
                      x %>%
                        filter(str_detect(NAME, pat)) %>%
                        transmute(
                          GEOID,
                          occ_group = g,
                          n = estimate,
                          moe = moe
                        )
                    }))
                    
                    # If geometry is present, keep sf class throughout; otherwise stay as tibble
                    if (keep_geometry && !inherits(occ_long, "sf")) occ_long <- st_as_sf(occ_long)
                    
                    occ_by_tract <- occ_long %>%
                      group_by(GEOID, occ_group) %>%
                      summarise(
                        n = sum(n, na.rm = TRUE),
                        moe = moe_sum(moe),
                        .groups = "drop"
                      )
                    
                    totals <- occ_by_tract %>%
                      group_by(GEOID) %>%
                      summarise(
                        proxy_workers = sum(n, na.rm = TRUE),
                        proxy_workers_moe = moe_sum(moe),
                        .groups = "drop"
                      )
                    
                    shares <- occ_by_tract %>%
                      left_join(drop_geom_if(totals), by = "GEOID") %>%
                      mutate(share_within_proxy = if_else(proxy_workers > 0, n / proxy_workers, NA_real_))
                    
                    list(shares = shares, totals = totals)
                  }
                  
                  build_la_hotel_surface <- function(
    year = 2023,
    keep_geometry = TRUE,
    oes_wages,
    crosswalk,
    occ_patterns = c(
      mgmt     = "Management, business, and financial",
      admin    = "Office and administrative support",
      food     = "Food preparation and serving related",
      cleaning = "Building and grounds cleaning and maintenance",
      personal = "Personal care and service"
    ),
    city_sf = NULL,
    city_total_trusted = NULL
                  ) {
                    res <- get_la_tract_hotel_occ_proxy(
                      year = year,
                      keep_geometry = keep_geometry,   # ✅ use the argument, don’t hardcode T
                      occ_patterns = occ_patterns
                    )
                    
                    w <- impute_proxy_wage_by_tract(
                      occ_shares = res$shares,
                      oes_wages  = oes_wages,
                      crosswalk  = crosswalk
                    )
                    
                    tracts <- res$totals %>%
                      left_join(w, by = "GEOID")
                    
                    if (!is.null(city_sf) && !is.null(city_total_trusted)) {
                      out_city <- calibrate_to_city_total(
                        tracts_sf = tracts,
                        city_sf = city_sf,
                        city_total_trusted = city_total_trusted
                      )
                      return(list(tracts_county = tracts, tracts_city = out_city))
                    } else {
                      return(list(tracts_county = tracts))
                    }
                  }
                  
                  
                  # ------------------------------------------------------------
                  # USAGE EXAMPLE (you edit these objects)
                  # ------------------------------------------------------------
                  
                  wages_h = read_rds(file.path(research_clean_path, "oes-hotel-worker-wage-distribution.rds"))     %>% rename(occsoc = sococc)
                  hwk <- read_rds(file.path(research_clean_path, "projected_hotel_workers_by_industry_occupation_2024_2030.rds"))
                  hwk = left_join(hwk, wages_h[,c("occsoc","avewage")])
                  hwk = hwk %>% filter(year == 2025)
                  hwk = hwk %>% dplyr::select(occsoc, occ_desc, jobs, avewage)
                  
                  
                  oes_wages <- data.frame(soc = hwk$occsoc, wage = hwk$avewage)
                 
                  crosswalk <- hwk %>%
                    mutate(
                      occ_group = case_when(
                        str_detect(occ_desc, regex("manager|supervisor|director", ignore_case = TRUE)) ~ "mgmt",
                        str_detect(occ_desc, regex("administr|office|secretary|clerk", ignore_case = TRUE)) ~ "admin",
                        str_detect(occ_desc, regex("cook|server|waiter|dish|food|kitchen|bartend", ignore_case = TRUE)) ~ "food",
                        str_detect(occ_desc, regex("housekeep|maid|janitor|clean|grounds|mainten", ignore_case = TRUE)) ~ "cleaning",
                        str_detect(occ_desc, regex("concierge|bell|guest|personal care|service", ignore_case = TRUE)) ~ "personal",
                        TRUE ~ NA_character_
                      )
                    ) %>%
                    filter(!is.na(occ_group)) %>%
                    transmute(
                      occ_group,
                      soc = occsoc,
                      within_group_weight = jobs
                    )

                  # Optional: your LA City boundary (sf polygon), e.g. from your own shapefile:
                   city_sf <- st_read(city_boundary_file) %>% st_make_valid()
                   city_total_trusted <- sum(hwk$jobs)

                  out <- build_la_hotel_surface(
                    year = 2023,
                    keep_geometry = F,
                    oes_wages = oes_wages,
                    crosswalk = crosswalk
                     #, city_sf = city_sf
                    # , city_total_trusted = city_total_trusted
                  )

                  county_tracts <- out$tracts_county
                  # if city inputs provided:
                   city_tracts <- out$tracts_city

                  county_tracts %>% select(GEOID, proxy_workers, proxy_avg_wage) %>% head()
                  
