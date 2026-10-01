# Citywide background uses a separate workbook; run only when it is local.
library(dplyr)
library(readxl)
source("script/0-config.R")

############# FIG 1 LEVELS PLOT ###############

dir <- costar_downloads_path

data = read_excel(file.path(dir, "AllHotels_LA_monthly.xlsx"))


lac = data %>% dplyr::select(Period, Occupancy, ADR, RevPAR, Demand)


lac$date <- as.Date(paste0("1 ", lac$Period), format = "%d %b %Y")
lac = lac %>% filter(date>="2023-01-01")
fig_dt = lac %>% arrange(date)
stopifnot(!anyNA(fig_dt), !anyDuplicated(fig_dt$date),
          identical(fig_dt$date, seq(min(fig_dt$date), max(fig_dt$date), by = "month")))
dir.create("output/hotel-time-series", showWarnings = FALSE, recursive = TRUE)
write.csv(fig_dt, "output/hotel-time-series/citywide-monthly.csv", row.names = FALSE)
          
          pdf("figures/raw/fig1_IndusryBackgroundTS_plot.pdf", width = 8, height = 10, useDingbats = FALSE)
                    
                    par(mfrow = c(4,1))
                    par(mar = c(3.5, 6.5, 2, 0.5), oma = c(2, 0, 2, 0), xpd = FALSE)
                    
                    
                    #Occupancy
                    #Demand
                    #ADR
                    #RevPAR
                    
                    
                    policy_date <- as.Date("2025-09-01")
                    
                    plot_panel <- function(x, y, ylab, main = "", plotX = T) {
                      plot(
                        x, y,
                        type = "l",
                        lwd = 2,
                        xlab = "",
                        ylab = ylab,
                        main = main,
                        xaxt = "n", axes = F
                      )
                      abline(v = policy_date, lty = 2, lwd = 1.5)
                      axis(2, las = 2)
                      
                      if(plotX == T){
                      axis.Date(
                        1,
                        at = seq(min(fig_dt$date), max(fig_dt$date), by = "1 month"),
                        labels = FALSE,
                        tcl = -0.25,line=0
                      )
                      
                      axis.Date(
                        1,
                        at = seq(min(fig_dt$date), max(fig_dt$date), by = "6 months"),
                        labels = F,
                        tcl = -0.5
                      )    
                      axis.Date(
                        1,
                        at = seq(min(fig_dt$date), max(fig_dt$date), by = "6 months"),
                        format = "%b\n%Y",
                        tick = F, line=1
                      )    
                      }else{
                        axis.Date(
                          1,
                          at = seq(min(fig_dt$date), max(fig_dt$date), by = "1 month"),
                          labels = FALSE,
                          tcl = -0.25,line=3
                        )
                        
                        axis.Date(
                          1,
                          at = seq(min(fig_dt$date), max(fig_dt$date), by = "6 months"),
                          labels = F,
                          tcl = -0.5, line=3
                        )   
                        
                      }
                      
                      
                      }
                    
                    plot_panel(fig_dt$date, 100 * fig_dt$Occupancy, "Occupancy (%)", "Occupancy", plotX = T)
                    plot_panel(fig_dt$date, fig_dt$Demand / 1e6, "Demand (Million Room Nights)", "Demand", plotX = T)
                    plot_panel(fig_dt$date, fig_dt$ADR, "ADR ($)", "Average Daily Rate", plotX = T)
                    plot_panel(fig_dt$date, fig_dt$RevPAR, "RevPAR ($)", "Revenue per Available Room")
                    
                    mtext("Trends in Los Angeles Hotel Market Performance", outer = TRUE, cex = 1.1, font = 2)
                    mtext("Dashed line marks September 2025 HWMO implementation", side = 1, outer = TRUE, line = 1)
                    
          
                  
          dev.off()
          
          
          ### for text reporting
          
          
          data$date = as.Date(paste0("1 ", data$Period), format = "%d %b %Y")

          data$`Occupancy Chg (YOY)` = as.numeric(data$`Occupancy Chg (YOY)`)
          data$`Demand Chg (YOY)` = as.numeric(data$`Demand Chg (YOY)`)
          data$`ADR Chg (YOY)` = as.numeric(data$`ADR Chg (YOY)`)
          data$`RevPAR Chg (YOY)` = as.numeric(data$`RevPAR Chg (YOY)`)
          
          df_post <- data[data$date >= as.Date("2025-09-01") & data$date <= max(fig_dt$date),]
          

          mean(df_post$`Occupancy Chg (YOY)`)
          mean(df_post$`Demand Chg (YOY)`)
          mean(df_post$`ADR Chg (YOY)`)
          mean(df_post$`RevPAR Chg (YOY)`)
          
          
          
          
          
