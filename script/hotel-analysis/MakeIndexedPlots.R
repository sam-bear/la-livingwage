# Group comparison using cleaned data only; avoids unrelated map/table inputs.
source("script/0-config.R")
source("script/0-loadFunctions.R")
library(dplyr)
library(readr)
library(MetBrewer)
pal <- met.brewer("Tiepolo", 8)
        add = read_rds(file.path(clean_path, "AnalysisData_LargeGroups.rds")) %>% filter(date>="2020-01-01")
        pal_sub = pal[c(1,8,7,5)]
        
        pal_sub[2:4]<-add.alpha(pal_sub[2:4], .8)
        pal_wt = c(3,rep(1,3))
        
        
        df_plot <- add %>%
          filter(group %in% c("AllTreated", "CG_Small", "CG_Union", "CG_EmbCity")) %>%
          arrange(group, date) %>%
          group_by(group) %>%
          mutate(
            base_adr = ADR[date == as.Date("2025-04-01")][1],
            adr_index = 100 * ADR / base_adr,
            base_revpar = RevPAR[date == as.Date("2025-04-01")][1],
            revpar_index = 100*RevPAR/base_revpar
          ) %>%
          ungroup() %>% filter(date>="2023-01-01")
        
        
        
        
        
        pdf("figures/raw/fig4-ts-revpar-adr.pdf", width = 10, height = 9)
        par(mfrow = c(2,1))
        
        plot(NULL,
             xlim = range(df_plot$date),
             ylim = range(c(90, 110, df_plot$adr_index), na.rm = TRUE),
             xlab = "",
             ylab = "ADR (Index: April 2025 = 100)", axes = F)
        
        rect(xleft =as.Date("2025-05-01"), xright = as.Date("2025-09-01"), ybottom = par("usr")[3], ytop = par("usr")[4] , border = NA, col = add.alpha('gray90', 0.5))
        rect(xleft =as.Date("2025-09-01"), xright = max(df_plot$date), ybottom = par("usr")[3], ytop = par("usr")[4] , border = NA, col = add.alpha('gray70', 0.5))
        
        # lines
        gg = 0
        for(g in unique(df_plot$group)) {
          gg = gg + 1
          d <- df_plot[df_plot$group == g, ]
          
          lines(d$date, d$adr_index,
                col = pal_sub[gg],
                lwd = pal_wt[gg])
        }
        
        # vertical lines
        abline(v = as.Date("2025-09-01"), lty = 2)
        abline(h = 100, col = 'gray')
        
        axis.Date(
          side = 1,
          at = seq(min(df_plot$date), max(df_plot$date), by = "month"),
          labels = FALSE,
          tck = -0.02   # short ticks
        )
        
        # yearly labels (with longer ticks)
        axis.Date(
          side = 1,
          at = seq(as.Date("2023-01-01"), max(df_plot$date), by = "year"),
          format = "%Y",
          tck = -0.05, cex=1.25   # longer ticks for emphasis
        )
        
        axis(2, las = 2)
        mtext(side = 3, adj = 0, text = "Average Daily Rate (ADR)",cex=2)
        
        
        
        
        plot(NULL,
             xlim = range(df_plot$date),
             ylim = range(c(70, 120, df_plot$revpar_index), na.rm = TRUE),
             xlab = "",
             ylab = "RevPAR (Index: April 2025 = 100)", axes = F)
        
        rect(xleft =as.Date("2025-05-01"), xright = as.Date("2025-09-01"), ybottom = par("usr")[3], ytop = par("usr")[4] , border = NA, col = add.alpha('gray90', 0.5))
        rect(xleft =as.Date("2025-09-01"), xright = max(df_plot$date), ybottom = par("usr")[3], ytop = par("usr")[4] , border = NA, col = add.alpha('gray70', 0.5))
        
        # lines
        gg = 0
        for(g in unique(df_plot$group)) {
          gg = gg + 1
          d <- df_plot[df_plot$group == g, ]
          
          lines(d$date, d$revpar_index,
                col = pal_sub[gg],
                lwd = pal_wt[gg])
        }
        
        # vertical lines
        abline(v = as.Date("2025-09-01"), lty = 2)
        abline(h = 100, col = 'gray')
        
        axis.Date(
          side = 1,
          at = seq(min(df_plot$date), max(df_plot$date), by = "month"),
          labels = FALSE,
          tck = -0.02   # short ticks
        )
        
        # yearly labels (with longer ticks)
        axis.Date(
          side = 1,
          at = seq(as.Date("2023-01-01"), max(df_plot$date), by = "year"),
          format = "%Y",
          tck = -0.05 ,cex=1.25  # longer ticks for emphasis
        )
        
        axis(2, las = 2)
        mtext(side = 3, adj = 0, text = "Revenue Per Available Room (RevPAR)",cex=2)
      mtext(paste("Through", format(max(df_plot$date), "%B %Y")), side = 1, line = 3, adj = 1, cex = 0.75)
      dev.off()

dir.create("output/hotel-time-series", recursive = TRUE, showWarnings = FALSE)
write.csv(df_plot, "output/hotel-time-series/monthly-indices.csv", row.names = FALSE)
