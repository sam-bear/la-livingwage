library(dplyr)
library(scales)
library(MetBrewer)
library(readxl)
source("script/0-config.R")

df <- readRDS(file.path(clean_path, "AnalysisData_LargeGroups.rds"))

# groups already in df:
# AllTreated, CG_Small, CG_Union, CG_EmbCity

plot_groups <- c("AllTreated", "CG_Small", "CG_Union", "CG_EmbCity")

df_plot <- df %>%
  filter(group %in% plot_groups) %>%
  filter(!is.na(date), date >= as.Date("2023-01-01"), !is.na(ADR.Chg..YOY.)) %>%
  arrange(group, date)

# labels
labs <- c(
  "AllTreated" = "Hotels subject to HWMWO",
  "CG_Small"   = "Control: 40-59 rooms",
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

ylim <- range(df_plot$adr_yoy, na.rm = TRUE)
xlim <- range(df_plot$date, na.rm = TRUE)
latest_date <- max(df_plot$date)
coverage <- df_plot %>% group_by(group) %>% summarise(first = min(date), last = max(date), .groups = "drop")
stopifnot(all(coverage$last == latest_date), !anyDuplicated(df_plot[c("group", "date")]))
stopifnot(all(is.finite(df_plot$adr_yoy)), all(is.finite(df_plot$revpar_yoy)))
dir.create("output/hotel-time-series", recursive = TRUE, showWarnings = FALSE)
write.csv(coverage, "output/hotel-time-series/coverage.csv", row.names = FALSE)
write.csv(df_plot, "output/hotel-time-series/monthly-yoy.csv", row.names = FALSE)

      pdf("figures/raw/figX_ADRRevPAR_yoy_full_plot.pdf", width = 8, height = 8, useDingbats = FALSE)
            
      par(mfrow = c(2,1))
            par(mar = c(4.5, 5.5, 1.5, 0.5), xpd = NA)
            
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
      
            
            par(mar = c(4.5, 5.5, 1.5, 0.5), xpd = NA)
            
            plot(
              NA,
              xlim = xlim,
              ylim = range(df_plot$revpar_yoy),
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
            axis(2, at = pretty(range(df_plot$revpar_yoy)), labels = percent(pretty(range(df_plot$revpar_yoy)), accuracy = 1), las = 2)
            
            abline(h = 0, lty = 1,lwd =0.5, col = "gray60")
            abline(v = as.Date("2025-09-01"), lty = 2, lwd = 1)
            
            gg=0
            for (g in plot_groups) {
              gg=gg+1
              dsub <- df_plot %>% filter(group == g)
              lines(dsub$date, dsub$revpar_yoy, lwd = c(3,1,1,1)[gg], col = cols[g])
            }
            
            
            
      mtext(paste("Through", format(latest_date, "%B %Y")), side = 3, line = 0, adj = 1, cex = 0.7)
      dev.off()

# ----------------------------
# 2) focused October 2025 through latest available month
# ----------------------------
df_focus <- df_plot %>%
  filter(date >= as.Date("2025-10-01"),
         date <= latest_date)

annotation_end <- seq(latest_date, by = "month", length.out = 2)[2]
write.csv(df_focus, "output/hotel-time-series/focused-yoy.csv", row.names = FALSE)
ylim2 <- range(df_focus$adr_yoy, na.rm = TRUE)
ylim3 <- range(df_focus$revpar_yoy, na.rm = TRUE)


# Historical filename retained; actual coverage is shown on the axis.
pdf("figures/raw/ADR_yoy_sep25mar26_plot.pdf", width = 8, height = 8, useDingbats = FALSE)
                      par(mfrow = c(2,1))
                      par(mar = c(4, 4.5, 1.5, 0.5), xpd = NA)
                      
                      
                      cols_df = data.frame(group =names(cols), col = cols)
                      ave = df_focus %>% group_by(group) %>% summarise(yoy_ave = mean(adr_yoy), revpar_yoy = mean(revpar_yoy, na.rm = T)) %>% left_join(cols_df, by = "group")
                      write.csv(ave, "output/hotel-time-series/focused-period-averages.csv", row.names = FALSE)
                      
                      plot(
                        NA,
                        xlim = c(min(df_focus$date), annotation_end),
                        ylim = ylim2,
                        xlab = "",
                        ylab = "YoY ADR change",
                        xaxt = "n",
                        yaxt = "n",
                        bty = "l"
                      )
                      
                      axis.Date(1, at = sort(unique(df_focus$date)), format = "%b\n%Y", cex.axis = 0.75)
                      axis(2, at = pretty(ylim2), labels = percent(pretty(ylim2), accuracy = 1))
                      
                      abline(h = 0, lty = 3, col = "gray60")
                      
                      for (g in plot_groups) {
                        dsub <- df_focus %>% filter(group == g)
                        lines(dsub$date, dsub$adr_yoy, lwd = 2, col = cols[g])
                        points(dsub$date, dsub$adr_yoy, pch = 16, cex = 2.5, col = cols[g])
                      }
                      
                      legend(
                        "topleft",
                        legend = paste0(labs[plot_groups], " (mean: ", percent(ave$yoy_ave[match(plot_groups, ave$group)], accuracy = 0.1), ")"),
                        col = cols[plot_groups],
                        lwd = 2,
                        pch = 16,
                        bty = "n",
                        cex = 0.75
                      )
                      
                      

                      
                      
                      
                      
                      
                      plot(
                        NA,
                        xlim = c(min(df_focus$date), annotation_end),
                        ylim =ylim3,
                        xlab = "",
                        ylab = "YoY RevPAR change",
                        xaxt = "n",
                        yaxt = "n",
                        bty = "l"
                      )
                      
                      axis.Date(1, at = sort(unique(df_focus$date)), format = "%b\n%Y", cex.axis = 0.75)
                      axis(2, at = pretty(ylim3), labels = percent(pretty(ylim3), accuracy = 1))
                      
                      abline(h = 0, lty = 3, col = "gray60")
                      
                      for (g in plot_groups) {
                        dsub <- df_focus %>% filter(group == g)
                        lines(dsub$date, dsub$revpar_yoy, lwd = 2, col = cols[g])
                        points(dsub$date, dsub$revpar_yoy, pch = 16, cex = 2.5, col = cols[g])
                      }
                      
                      legend(
                        "topleft",
                        legend = paste0(labs[plot_groups], " (mean: ", percent(ave$revpar_yoy[match(plot_groups, ave$group)], accuracy = 0.1), ")"),
                        col = cols[plot_groups],
                        lwd = 2,
                        pch = 16,
                        bty = "n",
                        cex = 0.75
                      )
                      
                      
dev.off()

# Citywide background figure: run MakeCityLevelsPlots.R separately.
