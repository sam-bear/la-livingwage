source("script/0-loadFunctions.R")
source("script/0-loadPackages.R")


dir <- clean_path


## ------------------------------------------------------------
## Figure 2. Pre-Policy Hotel Performance by Analysis Group
## ------------------------------------------------------------
        add = read_rds(file.path(clean_path, "AnalysisData_LargeGroups.rds"))
        
        # ---- build plotting data ----
        plot_dat <- add %>%
          filter(date == as.Date("2025-08-01")) %>%
          transmute(
            group = case_when(
              group == "AllTreated" ~ "Subject to\nHWMO",
              group == "CG_Small"   ~ "LA hotels\n(40-59 rooms)",
              group == "CG_Union"   ~ "LA hotels\n(union)",
              group == "CG_EmbCity" ~ "Adjacent cities",
              TRUE ~ group
            ),
            adr = X12.Mo.ADR,
            revpar = X12.Mo.RevPAR
          )
        
        # set plotting order to match text
        plot_dat$group <- factor(
          plot_dat$group,
          levels = c(
            "Subject to\nHWMO",
            "LA hotels\n(40-59 rooms)",
            "LA hotels\n(union)",
            "Adjacent cities"
          )
        )
        
        plot_dat = plot_dat[c(2,4,3,1),]
    ## ------------------------------------------------------------
        
        
    pdf("figures/raw/fig2-barplot-summary.pdf", width =10, height = 4.5)    
        # colors
        bar_cols <- c(rep(pal[7], nrow(plot_dat) - 1), pal[1])
        
        op <- par(no.readonly = TRUE)
        
        par(
          mfrow = c(1, 2),
          mar = c(4, 10, 4, 2),   # more left margin for labels
          oma = c(0, 0, 2, 0),
          las = 1,
          xpd = NA
        )
        
        # -------------------
        # Panel A: ADR
        # -------------------
        bp1 <- barplot(
          height = plot_dat$adr,
          names.arg = plot_dat$group,
          col = bar_cols,
          border = NA,
          horiz = TRUE,
          xlim = c(0, max(plot_dat$adr) * 1.18),
          xlab = "Average Daily Rate (ADR)",
          main = "A. ADR",
          cex.names = 0.95, axes = F
        )
        
        axis(
          side = 1,
          at = pretty(c(0, plot_dat$adr)),
          labels = dollar(pretty(c(0, plot_dat$adr)), accuracy = 1)
        )
        
        text(
          x = plot_dat$adr,
          y = bp1,
          labels = dollar(plot_dat$adr, accuracy = 0.01),
          pos = 4,     # to the right of bars
          cex = 0.95
        )
        
        # -------------------
        # Panel B: RevPAR
        # -------------------
        bp2 <- barplot(
          height = plot_dat$revpar,
          names.arg = plot_dat$group,
          col = bar_cols,
          border = NA,
          horiz = TRUE,
          xlim = c(0, max(plot_dat$revpar) * 1.18),
          xlab = "Revenue per Available Room (RevPAR)",
          main = "B. RevPAR",
          cex.names = 0.95, axes = F
        )
        
        axis(
          side = 1,
          at = seq(0,300,100),
          labels = dollar(seq(0,300,100), accuracy = 1)
        )
        
        text(
          x = plot_dat$revpar,
          y = bp2,
          labels = dollar(plot_dat$revpar, accuracy = 0.01),
          pos = 4,
          cex = 0.95
        )
        
        # mtext(
        #   "Figure 2. Pre-Policy Hotel Performance by Analysis Group (12 months ending August 2025)",
        #   outer = TRUE,
        #   cex = 1.2,
        #   font = 2
        # )
        
        par(op)
        dev.off()


#######################################


### make table at council district level

        hotels_sf$treated <- 0
        hotels_sf$treated[hotels_sf$PropertyID %in% treated$PropertyID]<-1
        
        cdist <- read_sf(council_district_file)
        
        hotels_cd = st_intersection(hotels_sf, cdist)
        
        
        ### Tables
        cdtab = hotels_cd %>% group_by(District) %>% summarise(no = sum(treated == 0),rooms_no = sum(Rooms[treated==0]), yes = sum(treated == 1), rooms_yes = sum(Rooms[treated == 1])) %>% as.data.frame() %>% dplyr::select(-geometry)
        flextable(cdtab)  
        
        
#######################################################################
      ####### Figure 3 ################  
        
        ## assume df has:
        ## date, group, adr
        
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
             ylim = c(90, 110),
             xlab = "",
             ylab = "ADR (Index: April 2025 = 100)", axes = F)
        
        rect(xleft =as.Date("2025-05-01"), xright = as.Date("2025-09-01"), ybottom = 80, ytop =120 , border = NA, col = add.alpha('gray90', 0.5))
        rect(xleft =as.Date("2025-09-01"), xright = as.Date("2026-03-01"), ybottom = 80, ytop =120 , border = NA, col = add.alpha('gray70', 0.5))
        
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
        abline(v = , lty = 2)
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
             ylim = c(70, 120),
             xlab = "",
             ylab = "RevPAR (Index: April 2025 = 100)", axes = F)
        
        rect(xleft =as.Date("2025-05-01"), xright = as.Date("2025-09-01"), ybottom = 70, ytop =120 , border = NA, col = add.alpha('gray90', 0.5))
        rect(xleft =as.Date("2025-09-01"), xright = as.Date("2026-03-01"), ybottom = 70, ytop =120 , border = NA, col = add.alpha('gray70', 0.5))
        
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
        abline(v = , lty = 2)
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
      dev.off()
        
        #################################################################################################################################################      
        ####### APPENDIX TABLE
        
        add = read_rds(file.path(clean_path, "AnalysisData_LargeGroups.rds"))
        
        tab_group_x12 <- add %>%
          group_by(group) %>%
          filter(date == as.Date("2025-08-01")) %>%
          ungroup() %>%
          transmute(
            group,
            Period = format(date, "%b %Y"),
            `12-mo Supply` = comma(round(X12.Mo.Supply, 0)),
            `12-mo Demand` = comma(round(X12.Mo.Demand, 0)),
            `12-mo Occupancy` = percent(X12.Mo.Occupancy, accuracy = 0.1),
            `12-mo ADR` = dollar(X12.Mo.ADR, accuracy = 0.01),
            `12-mo RevPAR` = dollar(X12.Mo.RevPAR, accuracy = 0.01),
            `12-mo Revenue` = dollar(X12.Mo.Revenue, accuracy = 1),
            `Sale price / room` = dollar(Market.Sale.Price.Room, accuracy = 1),
            `Cap rate` = percent(Market.Cap.Rate, accuracy = 0.1)
          ) %>%
          arrange(group) %>% mutate(group = replace(group, group=="AllTreated","Subject to HWMWO"),
                                    group = replace(group, group=="CG_Small","Not subject HWMWO (<60 rooms)"),
                                    group = replace(group, group=="CG_Union","Not subject HWMWO (union contracts)"),
                                    group = replace(group, group=="CG_EmbCity","Not subject to HWMWO (adjacent city)"))
        
        ft_x12 <- flextable(tab_group_x12) %>%
          autofit()
        
        ft_x12      
        
        
      ###################
        
        
