source("script/0-loadFunctions.R")
source("script/0-loadPackages.R")


    #step 1: identify top routes in the pre data

          data_path <- flight_traffic_path
          
          fls <- list.files(data_path, pattern = "\\.csv$", full.names = TRUE)
          
          dat <- vector("list", length(fls))
          
          for (i in seq_along(fls)) {
            
            # load data
            pre <- read_csv(fls[i], show_col_types = FALSE)
            
            # keep markets involving LAX
            pre_lax <- pre %>%
              filter(ORIGIN_AIRPORT_ID == 12892 | DEST_AIRPORT_ID == 12892)
            
            # aggregate to quarter
            dat[[i]] <-pre_lax
          }
          
          pre_clean <- rbindlist(dat)
          
          top_routes <- pre_clean %>%
            filter(ORIGIN_AIRPORT_ID == 12892 | DEST_AIRPORT_ID == 12892) %>%
            mutate(
              route = ifelse(
                ORIGIN_AIRPORT_ID == 12892,
                DEST_AIRPORT_ID,
                ORIGIN_AIRPORT_ID
              )
            ) %>%
            group_by(route) %>%
            summarise(passengers = sum(PASSENGERS), .groups = "drop") %>%
            arrange(desc(passengers)) %>%
            head(15)
          
          
        # ok now limit to top routes  
        keep_routes = c(14771, 12889, 14747, 14869)

        
    ## now pull data and group by routes in pre data    
        
        key_routes <- pre_clean %>%
          filter( (ORIGIN_AIRPORT_ID == 12892 | DEST_AIRPORT_ID == 12892) &  (ORIGIN_AIRPORT_ID %in% keep_routes | DEST_AIRPORT_ID %in% keep_routes)) %>%
          mutate(
            route = ifelse(
              ORIGIN_AIRPORT_ID == 12892,
              DEST_AIRPORT_ID,
              ORIGIN_AIRPORT_ID
            )
          ) %>%
          group_by(route, YEAR, QUARTER) %>%
          summarise(passengers = sum(PASSENGERS),dist = mean(MARKET_DISTANCE), .groups = "drop") %>%
          arrange(desc(passengers)) %>% arrange(route, YEAR, QUARTER)


      
       
    #now pull in data for post data      
      
         
        data_path <- flight_price_path
        
        
        fls <- list.files(data_path, pattern = ".parquet")
        dat = list()
        length(dat) = length(fls)
           
        dat <- vector("list", length(fls))
        
        for (i in seq_along(fls)) {
          
          post <- read_parquet(paste0(data_path,fls[i]))
          
          apt_mat <- as.matrix(post[, apt_cols])
          
          dest_final <- apt_mat[
            cbind(seq_len(nrow(apt_mat)), pmin(post$CouponSeg + 1, ncol(apt_mat)))
          ]
          
          post_sub <- post %>%
            mutate(
              origin = Apt_1,
              dest_final = dest_final
            ) %>%
            filter(
              (origin == "LAX" & dest_final %in% routes_keep) |
                (dest_final == "LAX" & origin %in% routes_keep)
            ) %>%
            mutate(
              route = ifelse(origin == "LAX", dest_final, origin)
            )
          
          # optional: build itinerary distance once, if useful
          dist_cols <- grep("^Coupon_SegDist_", names(post_sub), value = TRUE)
          if (length(dist_cols) > 0) {
            post_sub$itin_dist <- rowSums(post_sub[, dist_cols, drop = FALSE], na.rm = TRUE)
          } else {
            post_sub$itin_dist <- NA_real_
          }
          
          # aggregate immediately
          dat[[i]] <- post_sub %>%
            group_by(RpYear, RpMonth, route) %>%
            summarise(
              fare = sum(TotalAmt * NumPax, na.rm = TRUE) / sum(NumPax, na.rm = TRUE),
              passengers = sum(NumPax, na.rm = TRUE),
              n_obs = n(),
              avg_dist = sum(itin_dist * NumPax, na.rm = TRUE) / sum(NumPax, na.rm = TRUE),
              connecting = sum((CouponSeg > 1) * NumPax, na.rm = TRUE) / sum(NumPax, na.rm = TRUE),
              median_fare = weightedMedian(TotalAmt, w = NumPax, na.rm = TRUE),
              .groups = "drop"
            )
          
          # free memory aggressively
          rm(post, post_sub, route_flag)
          gc()
        }
        

        
        
      post_clean <- data.frame(rbindlist(dat))
      
      
      
      
      
      
      post_clean$quarter <-3
      post_clean$quarter[post_clean$RpMonth %in% 10:12]<-4
      
      
      #ag to quarter
      dat_q <- post_clean %>%
        group_by(RpYear, quarter, route) %>%
        summarise(
          fare = sum(fare * passengers) / sum(passengers),
          passengers = sum(passengers),
          n_obs = sum(n_obs),
          avg_dist = sum(avg_dist * passengers) / sum(passengers),
          connecting = sum(connecting * passengers) / sum(passengers),
          median_fare = sum(median_fare * passengers) / sum(passengers), # optional (approx)
          .groups = "drop"
        )


      dat_q = dat_q %>% rename(YEAR = RpYear, QUARTER = quarter)
      
      ##########################################################
      
      


      
      data_path <- flight_traffic_path
      
      fls <- list.files(data_path, pattern = "\\.csv$", full.names = TRUE)
      
      # selected comparison routes
      routes_keep_ids <- c(14771, 12889, 14747, 14869)  # SFO, LAS, SEA, SLC
      
      dat <- vector("list", length(fls))
      
      for (i in seq_along(fls)) {
        
        # load data
        pre <- read_csv(fls[i], show_col_types = FALSE)
        
        # keep only selected LAX routes and define route as non-LAX endpoint
        pre_sub <- pre %>%
          filter(
            (ORIGIN_AIRPORT_ID == 12892 & DEST_AIRPORT_ID %in% routes_keep_ids) |
              (DEST_AIRPORT_ID == 12892 & ORIGIN_AIRPORT_ID %in% routes_keep_ids)
          ) %>%
          mutate(
            route = ifelse(ORIGIN_AIRPORT_ID == 12892, DEST_AIRPORT_ID, ORIGIN_AIRPORT_ID)
          )
        
        # aggregate to quarter x route
        dat[[i]] <- pre_sub %>%
          group_by(YEAR, QUARTER, route) %>%
          summarise(
            fare = sum(MARKET_FARE * PASSENGERS, na.rm = TRUE) / sum(PASSENGERS, na.rm = TRUE),
            passengers = sum(PASSENGERS, na.rm = TRUE),
            n_obs = n(),
            avg_dist = sum(MARKET_DISTANCE * PASSENGERS, na.rm = TRUE) / sum(PASSENGERS, na.rm = TRUE),
            .groups = "drop"
          )
      }
      
      dat_pre_q <- bind_rows(dat) %>%
        arrange(route, YEAR, QUARTER)
      
      dat_q = dat_q %>% dplyr::select(-connecting, -median_fare)
      dat_pre_q$route = as.character(dat_pre_q$route)
      dat_pre_q$route[dat_pre_q$route=="12889"]<-"LAS"
      dat_pre_q$route[dat_pre_q$route=="14747"]<-"SEA"
      dat_pre_q$route[dat_pre_q$route=="14771"]<-"SFO"
      dat_pre_q$route[dat_pre_q$route=="14869"]<-"SLC"
      
      
      
      dat_all_q <- bind_rows(dat_pre_q, dat_q) %>%
        arrange(route, YEAR, QUARTER)
      
      
      write_rds(dat_all_q, file = file.path(clean_path, "AirportPrices.rds"))
      
      
      
      #########
      ############
      ################
      pal <- met.brewer("Tiepolo", 8)
      COL = pal[1]
      
      
      # make a quarterly time variable
      plot_dat <- dat_all_q
      plot_dat <- plot_dat %>%
        mutate(
          q_date = make_date(YEAR, (QUARTER - 1) * 3 + 1, 1)
        )      
      # routes to plot
      routes <- c("LAS", "SEA", "SFO", "SLC")
      
      # y-axis range shared across panels
      ylim <- range(plot_dat$fare[plot_dat$route %in% routes], na.rm = TRUE)
      
      # quarter tick marks
      x_at <- seq(2023, 2025.75, .25)
      x_lab <- c("2023 Q1", "Q2", "Q3", "Q4","2024 Q1", "Q2", "Q3", "Q4", "2025 Q1", "Q2", "Q3", "Q4")
      
      
      
      
      pdf("figures/raw/Flight-Prices-lax.pdf", width = 6, height = 9)
      par(mfrow = c(4, 1),
          mar = c(3, 4, 3, 1),
          oma = c(4, 0, 0, 0))
      
      for (r in routes) {
        
        d <- subset(plot_dat, route == r)
        
        plot(d$q_date, d$fare,
             type = "o",
             pch = 16,
             lwd = 2,
             xaxt = "n",
             xlab = "",
             ylab = "Average fare ($)",
             ylim = ylim,
             main = paste0("LAX-", r), axes = F, col= COL, cex =2)
        
        axis(2, las = 2)

        # axis.Date(
        #   1,
        #   at = seq(min(d$q_date), max(d$q_date), by = "3 months"),
        #   labels = rep(c("Q1","Q2","Q3","Q4"),3),
        #   format = "%b\n%Y", tick = T
        # )
          
            axis.Date(
              1,
              at = seq(as.Date("2023-01-01"), as.Date("2023-10-01"), by = "3 months"),
              labels = rep(c("Q1","Q2","Q3","Q4"),1),
              format = "%b\n%Y", tick = T
            )
            
            axis.Date(
              1,
              at = seq(as.Date("2024-01-01"), as.Date("2024-10-01"), by = "3 months"),
              labels = rep(c("Q1","Q2","Q3","Q4"),1),
              format = "%b\n%Y", tick = T
            )
          
            axis.Date(
              1,
              at = seq(as.Date("2025-01-01"), as.Date("2025-10-01"), by = "3 months"),
              labels = rep(c("Q1","Q2","Q3","Q4"),1),
              format = "%b\n%Y", tick = T
            )
            
            
             if(r == "SLC"){
            
            axis.Date(
              1,
              at = c("2023-05-15","2024-05-15","2025-05-15"),
              labels = 2023:2025,
              format = "%b\n%Y", tick = F,line=2, cex.axis =1.5
            )
        }
                
        # first post period: 2025 Q4
        abline(v = as.Date("2025-09-01"), lty = 3)
      }

      
dev.off()






plot_dat <- plot_dat %>%
  group_by(route) %>%
  arrange(YEAR, QUARTER) %>%
  mutate(
    yoy = fare / lag(fare, 4) - 1
  )


ylim <- range(plot_dat$yoy[plot_dat$route %in% routes], na.rm = TRUE)



pdf("figures/raw/Flight-Prices-lax-yoy-2025.pdf", width = 4, height = 9)
par(mfrow = c(4, 1),
    mar = c(3, 4, 3, 1),
    oma = c(4, 0, 0, 0))

for (r in routes) {
  
  d <- subset(plot_dat, route == r) %>% drop_na(yoy) %>% filter(q_date>="2025-01-01")
  
  plot(d$q_date, d$yoy,
       type = "o",
       pch = 16,
       lwd = 2,
       xaxt = "n",
       xlab = "",
       ylab = "Year-over-year change in fares (%)",
       ylim = ylim,
       main = paste0("LAX-", r), axes = F, col= COL, cex =2)
  
  axis(2, las = 2, at = seq(-.1, .4, .1), labels = paste0(seq(-.1, .4, .1)*100,"%"))
  
  # axis.Date(
  #   1,
  #   at = seq(min(d$q_date), max(d$q_date), by = "3 months"),
  #   labels = rep(c("Q1","Q2","Q3","Q4"),3),
  #   format = "%b\n%Y", tick = T
  # )
  
  axis.Date(
    1,
    at = seq(as.Date("2023-01-01"), as.Date("2023-10-01"), by = "3 months"),
    labels = rep(c("Q1","Q2","Q3","Q4"),1),
    format = "%b\n%Y", tick = T
  )
  
  axis.Date(
    1,
    at = seq(as.Date("2024-01-01"), as.Date("2024-10-01"), by = "3 months"),
    labels = rep(c("Q1","Q2","Q3","Q4"),1),
    format = "%b\n%Y", tick = T
  )
  
  axis.Date(
    1,
    at = seq(as.Date("2025-01-01"), as.Date("2025-10-01"), by = "3 months"),
    labels = rep(c("Q1","Q2","Q3","Q4"),1),
    format = "%b\n%Y", tick = T
  )
  
  
  if(r == "SLC"){
    
    axis.Date(
      1,
      at = c("2023-05-15","2024-05-15","2025-05-15"),
      labels = 2023:2025,
      format = "%b\n%Y", tick = F,line=2, cex.axis =1.5
    )
  }
  
  # first post period: 2025 Q4
  abline(v = as.Date("2025-09-01"), lty = 3)
  abline(h = 0,  lwd = 0.5,lty=1, col = 'gray')

  
    
  
}


dev.off()
