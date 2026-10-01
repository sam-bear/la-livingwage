source("script/0-loadFunctions.R")
source("script/0-loadPackages.R")

# Read one annual file at a time; the download omits YEAR in some files.
# Keep the original T-100 MARKET endpoint definition and all carrier records.
airp <- list()
coverage <- list()
yrs <- 2023:2026
for (y in seq_along(yrs)) {
    input_file <- file.path(flight_traffic_path,
                           paste0("T_T100D_MARKET_ALL_CARRIER_", yrs[y], ".csv"))
    d <- data.table::fread(input_file)
    stopifnot(all(c("MONTH", "ORIGIN", "DEST", "PASSENGERS") %in% names(d)))
    if ("YEAR" %in% names(d)) stopifnot(all(d$YEAR == yrs[y]))
    stopifnot(all(d$MONTH %in% 1:12),
              all(is.finite(d$PASSENGERS) & d$PASSENGERS >= 0))
    months <- sort(unique(d$MONTH))
    stopifnot(identical(as.integer(months), seq_len(max(months))))
    if (yrs[y] < max(yrs)) stopifnot(length(months) == 12L)
    coverage[[y]] <- data.frame(year = yrs[y], file = basename(input_file),
                               rows = nrow(d), first_month = min(months),
                               last_month = max(months), exact_duplicate_rows = sum(duplicated(d)))
    # Repeated rows are reported, not dropped: download fields may omit dimensions.
    airp[[y]] <- d[ORIGIN == "LAX" | DEST == "LAX",
                  .(passengers = sum(PASSENGERS) / 1e6), by = MONTH]
    airp[[y]][, YEAR := yrs[y]]
}
lax_monthly <- as.data.frame(data.table::rbindlist(airp)) %>% arrange(YEAR, MONTH)
stopifnot(!anyDuplicated(lax_monthly[c("YEAR", "MONTH")]),
          all(lax_monthly$passengers > 0))
dir.create("output/airport-passenger-audit", recursive = TRUE, showWarnings = FALSE)
write.csv(bind_rows(coverage), "output/airport-passenger-audit/input-coverage.csv", row.names = FALSE)
write.csv(lax_monthly, "output/airport-passenger-audit/monthly-passengers.csv", row.names = FALSE)
latest_month <- max(lax_monthly$MONTH[lax_monthly$YEAR == max(yrs)])
latest_label <- paste("2026 through", month.name[latest_month])

        lax_2023 <- lax_monthly %>% filter(YEAR == 2023) %>% arrange(MONTH)
        lax_2024 <- lax_monthly %>% filter(YEAR == 2024) %>% arrange(MONTH)
        lax_2025 <- lax_monthly %>% filter(YEAR == 2025) %>% arrange(MONTH)
        lax_2026 <- lax_monthly %>% filter(YEAR == 2026) %>% arrange(MONTH)
        pal <- met.brewer("Tiepolo", 8)
        
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

        # Add 2024, 2025, and available 2026 months
        lines(1:12, lax_2024$passengers, lty = 2, col = pal[6], lwd = 1)
        lines(lax_2025$MONTH, lax_2025$passengers, col = pal[1], lwd = 1,lty=2)
        lines(lax_2026$MONTH, lax_2026$passengers, col = pal[2], lwd = 2)
        points(1:12, lax_2023$passengers, pch = 21, cex = 1.5, col = pal[4])
        points(1:12, lax_2024$passengers, pch = 21, cex = 1.5, col = pal[6])
        points(1:12, lax_2025$passengers, pch = 21, cex = 1.5, col = pal[1])
        points(lax_2026$MONTH, lax_2026$passengers, pch = 16, cex = 1.5, col = pal[2])
        
        lines(lax_2025$MONTH[lax_2025$MONTH>=9], lax_2025$passengers[lax_2025$MONTH>=9], col = pal[1], lwd = 3)
        points(9:12, lax_2025$passengers[lax_2025$MONTH>=9], pch = 16, cex = 2, col = pal[1])

        # Policy line
        abline(v = 9, lty = 3, col = "black", lwd = 1)
        text(9.2,5, "LWO start (Sep 2025)",
             adj = c(0, 1.2), cex = 0.75)
        
        # X axis
        axis(1, at = 1:12, labels = month_labels)
        
        # Legend
        legend("bottomright",
               legend = c("2023", "2024", "2025", latest_label),
               col = pal[c(4,6,1,2)],
               lty = c(2, 2, 2, 1), lwd = c(1.5, 1.5, 2, 2),
               bty = "n", cex = 0.85)
        
        # Caption
        mtext("Source: BTS T-100 Domestic Market. LAX market endpoints; includes some connecting travelers.",
              side = 1, line = 4, cex = 0.7, adj = 0)
        
        dev.off()

        yoy_2025 <- lax_2025 %>%
          select(MONTH, current = passengers) %>%
          left_join(lax_2024 %>% select(MONTH, prior = passengers), by = "MONTH") %>%
          mutate(yoy = (current - prior) / prior, comparison = "2025 vs. 2024")
        yoy_2026 <- lax_2026 %>%
          select(MONTH, current = passengers) %>%
          left_join(lax_2025 %>% select(MONTH, prior = passengers), by = "MONTH") %>%
          mutate(yoy = (current - prior) / prior, comparison = "2026 vs. 2025")
        yoy <- bind_rows(yoy_2025, yoy_2026)
        stopifnot(all(is.finite(yoy$yoy)), all(yoy$prior > 0))
        write.csv(yoy, "output/airport-passenger-audit/monthly-yoy.csv", row.names = FALSE)
        yoy_range <- range(100 * yoy$yoy, 0, na.rm = TRUE)
        yoy_pad <- max(diff(yoy_range) * 0.08, 1)

        # Use a continuous timeline so the post-policy months stay together.
        yoy$date <- as.Date(sprintf("%d-%02d-01",
                            ifelse(yoy$comparison == "2025 vs. 2024", 2025, 2026), yoy$MONTH))
        yoy <- yoy[order(yoy$date), ]
        stopifnot(!anyDuplicated(yoy$date), nrow(yoy) == 12 + latest_month)
        write.csv(yoy, "output/airport-passenger-audit/monthly-yoy.csv", row.names = FALSE)
        policy_date <- as.Date("2025-09-01")
        post <- yoy$date >= policy_date
        pdf("figures/raw/FigX1-yoy-passengers-lax.pdf", width = 9, height = 8)
        plot(yoy$date, 100 * yoy$yoy, type = "n", axes = FALSE,
             ylim = yoy_range + c(-yoy_pad, yoy_pad), xlab = "",
             ylab = "Year-over-Year Change (%)")
        rect(policy_date, par("usr")[3], max(yoy$date), par("usr")[4],
             col = add.alpha("gray80", .5), border = NA)
        abline(h = 0, lty = 2, col = "grey50")
        lines(yoy$date, 100 * yoy$yoy, col = pal[1], lty = 2, lwd = 2)
        points(yoy$date, 100 * yoy$yoy, col = add.alpha(pal[1], .5), pch = 16, cex = 1.5)
        lines(yoy$date[post], 100 * yoy$yoy[post], col = pal[1], lwd = 2)
        points(yoy$date[post], 100 * yoy$yoy[post], col = pal[1], pch = 16, cex = 1.7)
        axis(2, las = 2)
        ticks <- unique(c(seq(min(yoy$date), max(yoy$date), by = "3 months"), max(yoy$date)))
        axis.Date(1, at = ticks, format = "%b\n%Y", cex.axis = .85)
        abline(v = policy_date, lty = 3)
        text(policy_date + 12, par("usr")[4], "LWO start (Sep 2025)",
             adj = c(0, 1.2), cex = .75)
        mtext("Source: BTS T-100 Domestic Market. LAX market endpoints; includes some connecting travelers.",
              side = 1, line = 4, cex = .7, adj = 0)
        dev.off()
