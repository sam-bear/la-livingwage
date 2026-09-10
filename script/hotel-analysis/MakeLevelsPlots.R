library(dplyr)
library(scales)
library(MetBrewer)

# groups already in df:
# AllTreated, CG_Small, CG_Union, CG_EmbCity

plot_groups <- c("AllTreated", "CG_Small", "CG_Union", "CG_EmbCity")

df_plot <- df %>%
  filter(group %in% plot_groups) %>%
  filter(!is.na(date), !is.na(ADR.Chg..YOY.)) %>%
  arrange(group, date)

# labels
labs <- c(
  "AllTreated" = "Hotels subject to HWMWO",
  "CG_Small"   = "Control: 40–59 rooms",
  "CG_Union"   = "Control: union hotels",
  "CG_EmbCity" = "Control: outside city"
)

# colors
pal <- met.brewer("Tiepolo", 8)
cols <- c(
  "AllTreated" = pal[1],
  "CG_Small"   = pal[7],
  "CG_Union"   = pal[5],
  "CG_EmbCity" = pal[8]
)

# ----------------------------
# 1) full monthly YoY ADR plot
# ----------------------------

df_plot$ADR.Chg..YOY. = as.numeric(df_plot$ADR.Chg..YOY.)
df_plot$RevPAR.Chg..YOY. = as.numeric(df_plot$RevPAR.Chg..YOY.)

df_plot = df_plot %>% dplyr::select(date, group, adr_yoy = ADR.Chg..YOY.,revpar_yoy = RevPAR.Chg..YOY.)

newdat = data.frame(date = as.Date("2026-03-01"), group = plot_groups, adr_yoy = c(.045,.036,.052,.096), revpar_yoy = c(.07,.039,.094,.207))

df_plot = rbind(df_plot, newdat)
ylim <- range(df_plot$adr_yoy, na.rm = TRUE)
xlim <- range(df_plot$date, na.rm = TRUE)

      pdf("figures/raw/figX_ADRRevPAR_yoy_full_plot.pdf", width = 8, height = 8, useDingbats = FALSE)
            
      par(mfrow = c(2,1))
            par(mar = c(4, 4.5, 1.5, 0.5), xpd = NA)
            
            plot(
              NA,
              xlim = xlim,
              ylim = ylim,
              xlab = "",
              ylab = "YoY ADR change",
              xaxt = "n",
              yaxt = "n",
              bty = "l"
            )
            
            # axis.Date(
            #   1,
            #   at = seq(min(df_plot$date), max(df_plot$date), by = "6 months"),
            #   format = "%b\n%Y", tick = F
            # )
            axis(2, at = pretty(ylim), labels = percent(pretty(ylim), accuracy = 1), las = 2)
            
            abline(h = 0, lty = 1,lwd=0.5, col = "gray60")
            abline(v = as.Date("2025-09-01"), lty = 2, lwd = 1)
            
            gg=0
            for (g in plot_groups) {
              gg=gg+1
              dsub <- df_plot %>% filter(group == g)
              lines(dsub$date, dsub$adr_yoy, lwd = c(3,1,1,1)[gg], col = cols[g])
            }
            
            legend(
              "topleft",
              legend = labs[plot_groups],
              col = cols[plot_groups],
              lwd = 2,
              bty = "n",
              cex = 0.9
            )
            
            # mtext(
            #   "September 2025 policy implementation",
            #   side = 3,
            #   at = as.Date("2025-09-01"),
            #   line = -1.2,
            #   cex = 0.8
            # )
      
            
            par(mar = c(4, 4.5, 1.5, 0.5), xpd = NA)
            
            plot(
              NA,
              xlim = xlim,
              ylim = ylim,
              xlab = "",
              ylab = "YoY RevPAR change",
              xaxt = "n",
              yaxt = "n",
              bty = "l"
            )
            
            axis.Date(
              1,
              at = seq(min(df_plot$date), max(df_plot$date), by = "6 months"),
              format = "%b\n%Y", tick = F
            )
            axis(2, at = pretty(ylim), labels = percent(pretty(ylim), accuracy = 1), las = 2)
            
            abline(h = 0, lty = 1,lwd =0.5, col = "gray60")
            abline(v = as.Date("2025-09-01"), lty = 2, lwd = 1)
            
            gg=0
            for (g in plot_groups) {
              gg=gg+1
              dsub <- df_plot %>% filter(group == g)
              lines(dsub$date, dsub$revpar_yoy, lwd = c(3,1,1,1)[gg], col = cols[g])
            }
            
            
            
      dev.off()

# ----------------------------
# 2) focused Sep-Dec 2025 plot
# ----------------------------
df_focus <- df_plot %>%
  filter(date >= as.Date("2025-10-01"),
         date <= as.Date("2026-03-01"))

ylim2 <- range(df_focus$adr_yoy, na.rm = TRUE)
ylim3 <- range(df_focus$revpar_yoy, na.rm = TRUE)


pdf("figures/raw/ADR_yoy_sep25mar26_plot.pdf", width = 8, height = 8, useDingbats = FALSE)
                      par(mfrow = c(2,1))
                      par(mar = c(4, 4.5, 1.5, 0.5), xpd = NA)
                      
                      
                      cols_df = data.frame(group =names(cols), col = cols)
                      ave = df_focus %>% group_by(group) %>% summarise(yoy_ave = mean(adr_yoy), revpar_yoy = mean(revpar_yoy, na.rm = T)) %>% left_join(cols_df)
                      
                      plot(
                        NA,
                        xlim = as.Date(c("2025-10-01", "2026-04-01")),
                        ylim = ylim2,
                        xlab = "",
                        ylab = "YoY ADR change",
                        xaxt = "n",
                        yaxt = "n",
                        bty = "l"
                      )
                      
                      axis.Date(1, at = sort(unique(df_focus$date)), format = "%b %Y")
                      axis(2, at = pretty(ylim2), labels = percent(pretty(ylim2), accuracy = 1))
                      
                      abline(h = 0, lty = 3, col = "gray60")
                      
                      for (g in plot_groups) {
                        dsub <- df_focus %>% filter(group == g)
                        lines(dsub$date, dsub$adr_yoy, lwd = 2, col = cols[g])
                        points(dsub$date, dsub$adr_yoy, pch = 16, cex = 2.5, col = cols[g])
                      }
                      
                      legend(
                        "topleft",
                        legend = labs[plot_groups],
                        col = cols[plot_groups],
                        lwd = 2,
                        pch = 16,
                        bty = "n",
                        cex = 0.9
                      )
                      
                      segments(x0 = as.Date("2026-03-15"),x1 = as.Date("2026-04-01"),y0 = ave$yoy_ave ,col = ave$col, lwd = 4)
                      text(x = as.Date("2026-03-10"),y = ave$yoy_ave ,label = paste0(round(100*ave$yoy_ave, 1),"%"))
                      

                      
                      
                      
                      
                      
                      plot(
                        NA,
                        xlim = as.Date(c("2025-10-01", "2026-04-01")),
                        ylim =ylim3,
                        xlab = "",
                        ylab = "YoY ADR change",
                        xaxt = "n",
                        yaxt = "n",
                        bty = "l"
                      )
                      
                      axis.Date(1, at = sort(unique(df_focus$date)), format = "%b %Y")
                      axis(2, at = pretty(ylim3), labels = percent(pretty(ylim3), accuracy = 1))
                      
                      abline(h = 0, lty = 3, col = "gray60")
                      
                      for (g in plot_groups) {
                        dsub <- df_focus %>% filter(group == g)
                        lines(dsub$date, dsub$revpar_yoy, lwd = 2, col = cols[g])
                        points(dsub$date, dsub$revpar_yoy, pch = 16, cex = 2.5, col = cols[g])
                      }
                      
                      legend(
                        "topleft",
                        legend = labs[plot_groups],
                        col = cols[plot_groups],
                        lwd = 2,
                        pch = 16,
                        bty = "n",
                        cex = 0.9
                      )
                      
                      segments(x0 = as.Date("2026-03-15"),x1 = as.Date("2026-04-01"),y0 = ave$revpar_yoy ,col = ave$col, lwd = 4)
                      text(x = as.Date("2026-03-10"),y = ave$revpar_yoy ,label = paste0(round(100*ave$revpar_yoy, 1),"%"))
                      
dev.off()










############# FIG 1 LEVELS PLOT ###############

dir <- "data/costar/"

data = read_excel(paste0(dir,"AggregateCityData.xlsx"))


lac = data %>% dplyr::select(Period, Occupancy, ADR, RevPAR, Demand)


lac$date <- as.Date(paste0("1 ", lac$Period), format = "%d %b %Y")
lac = lac %>% filter(date>="2023-01-01")
fig_dt = lac %>% arrange(date)
          
          pdf("figures/raw/fig1_IndusryBackgroundTS_plot.pdf", width = 8, height = 10, useDingbats = FALSE)
                    
                    par(mfrow = c(4,1))
                    par(mar = c(4, 6.5, 4, 0.5), xpd = NA)
                    
                    
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
                        tcl = -0.25,line=
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
                    
                    plot_panel(fig_dt$date, fig_dt$Occupancy, "Occupancy (% Available Rooms Sold)", "Occupancy", plotX = T)
                    plot_panel(fig_dt$date, fig_dt$Demand, "Demand (Rooms Sold)", "Demand", plotX = T)
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
          
          df_post <- data[data$date >= as.Date("2025-09-01") & data$date <= as.Date("2026-02-01"),]
          

          mean(df_post$`Occupancy Chg (YOY)`)
          mean(df_post$`Demand Chg (YOY)`)
          mean(df_post$`ADR Chg (YOY)`)
          mean(df_post$`RevPAR Chg (YOY)`)
          
          
          
          
          
          library(data.table)
          library(lubridate)
          
          setDT(df)
          
          df[
            lubridate::month(date) %in% c(9,10,11,12,1,2,3,4),
            .(
              occ    = mean(Occupancy, na.rm = TRUE),
              demand = mean(Demand, na.rm = TRUE),
              adr    = mean(ADR, na.rm = TRUE),
              revpar = mean(RevPAR, na.rm = TRUE)
            ),
            by = .(year = lubridate::year(date))
          ][order(year)]
          
