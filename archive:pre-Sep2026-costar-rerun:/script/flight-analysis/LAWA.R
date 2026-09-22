source("script/0-loadFunctions.R")
source("script/0-loadPackages.R")


airp = list()
yrs = 2023:2025
for(y in 1:3){airp[[y]] = read_csv(file.path(flights_path, "T100", paste0("T_T100D_MARKET_ALL_CARRIER_", yrs[y], ".csv")))}
airp = data.frame(rbindlist(airp))

AIRPORTS = c("SFO","LAX","SAN","SEA","LAS","PHX","SNA")




ap_month <- airp %>% filter(DEST %in% AIRPORTS | ORIGIN %in% AIRPORTS) %>% 
  group_by(YEAR, MONTH, ORIGIN, DEST) %>%
  summarise(
    passengers = sum(PASSENGERS, na.rm = TRUE)
  )

        
        # Aggregate monthly LAX passengers
        lax_monthly <- ap_month %>%
          filter(ORIGIN == "LAX" | DEST == "LAX") %>%
          group_by(YEAR, MONTH) %>%
          summarise(passengers = sum(passengers) / 1e6, .groups = "drop")
        
        lax_2023 <- lax_monthly %>% filter(YEAR == 2023) %>% arrange(MONTH)
        lax_2024 <- lax_monthly %>% filter(YEAR == 2024) %>% arrange(MONTH)
        lax_2025 <- lax_monthly %>% filter(YEAR == 2025) %>% arrange(MONTH)
        
        month_labels <- c("Jan","Feb","Mar","Apr","May","Jun",
                          "Jul","Aug","Sep","Oct","Nov","Dec")
        
        
        pdf("figures/raw/FigX1-levels-passengers-lax.pdf", width = 9, height = 8)
        
        # Set up plot window
        plot(1:12, lax_2023$passengers,
             type = "l", lty = 2, col = pal[4], lwd = 1,
             xlim = c(1, 12),
             ylim = range(lax_monthly$passengers, na.rm = TRUE) * c(0.9, 1.1),
             xaxt = "n", xlab = "", ylab = "Passengers (millions)",
             main = "Monthly LAX Passenger Volumes", axes = F)
          axis(2, las = 2, at = seq(3,5, .5))
        
          rect(xleft = 9, xright = 12, ybottom = 3, ytop =5.5, col= add.alpha('gray80',.5), border = NA)       
          
           
        # Add 2024 and 2025 lines
        
        pal <- met.brewer("Tiepolo",8)
        
        
        lines(1:12, lax_2024$passengers, lty = 2, col = pal[6], lwd = 1)
        lines(lax_2025$MONTH, lax_2025$passengers, col = pal[1], lwd = 1,lty=2)
        points(1:12, lax_2023$passengers, pch = 21, cex = 1.5, col = pal[4])
        points(1:12, lax_2024$passengers, pch = 21, cex = 1.5, col = pal[6])
        points(1:12, lax_2025$passengers, pch = 21, cex = 1.5, col = pal[1])
        
        lines(lax_2025$MONTH[lax_2025$MONTH>=9], lax_2025$passengers[lax_2025$MONTH>=9], col = pal[1], lwd = 3)
        points(9:12, lax_2025$passengers[lax_2025$MONTH>=9], pch = 16, cex = 2, col = pal[1])
        
        
        
        
        # Policy line
        abline(v = 9, lty = 3, col = "black", lwd = 1)
        text(9.2,5, "LWO Implementation",
             adj = c(0, 1.2), cex = 0.75)
        
        # X axis
        axis(1, at = 1:12, labels = month_labels)
        
        # Legend
        legend("bottomright",
               legend = c("2023", "2024", "2025"),
               col = pal[c(4,6,1)],
               lty = c(2, 2, 2), lwd = c(1.5, 1.5, 2),
               bty = "n", cex = 0.85)
        
        # Caption
        mtext("Source: BTS T-100 Dataset. Includes passengers with LAX as origin or destination.",
              side = 1, line = 4, cex = 0.7, adj = 0)
        
        dev.off()
        
        
        
        
        
        
        
        
        yoy = lax_2025 %>% rename(pass25 = passengers) %>% dplyr::select(-YEAR) %>% left_join(lax_2024) %>% dplyr::select(-YEAR) %>% rename(pass24 = passengers) %>% 
            mutate(yoy = (pass25-pass24)/pass24)
        
        
        
        pdf("figures/raw/FigX1-yoy-passengers-lax.pdf", width = 9, height = 8)
        plot(yoy$MONTH, yoy$yoy * 100,
             type = "l", col = "darkred", lwd = 2,
             xlim = c(1, 12),
             ylim = c(-10,2) ,
             xaxt = "n", xlab = "", 
             ylab = "Year-over-Year Change (%)",
             main = "", axes = F,lty=2)
        rect(xleft = 9, xright = 12, ybottom = -10, ytop =2, col= add.alpha('gray80',.5), border = NA)       
        
        
        points(1:12, yoy$yoy*100, pch = 16, cex = 1.5, col = add.alpha(pal[1], .5))
        lines(9:12, yoy$yoy[9:12]*100,  col = add.alpha(pal[1],1),lty=1, lwd = 2)
        points(9:12, yoy$yoy[9:12]*100, pch = 16, cex = 2, col = pal[1])
        
        
        axis(2, las = 2, at = -8:1)
        
        abline(h = 0, lty = 2, col = "grey50")
        abline(v = 9, lty = 3, col = "black", lwd = 1)
        text(9.2, par("usr")[4], "LWO Implementation",
             adj = c(0, 1.2), cex = 0.75)
        
        axis(1, at = 1:12, labels = month_labels)
        
        mtext("Source: BTS T-100 Dataset. Includes passengers with LAX as origin or destination.",
              side = 1, line = 4, cex = 0.7, adj = 0)
        
        dev.off()
        
        
        
        
        # 
        # 
        # 
        # 
        # lax_class <- 
        #   
        #   ap_month <- airp %>% filter(DEST %in% AIRPORTS | ORIGIN %in% AIRPORTS) %>% 
        #   group_by(YEAR, MONTH, ORIGIN, DEST, CLASS) %>%
        #   summarise(
        #     passengers = sum(PASSENGERS, na.rm = TRUE)
        #   ) %>%
        #   filter(ORIGIN == "LAX" | DEST == "LAX") %>%
        #   group_by(YEAR, MONTH, CLASS) %>%
        #   summarise(passengers = sum(passengers), .groups = "drop") %>%
        #   filter(CLASS %in% c("F", "L"))
