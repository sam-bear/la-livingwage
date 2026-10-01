# Extend the reconstructed PUBLIC journey series through 2026 Q2.
# Run audit-original-fares.R and harmonize-2025-fares.R first. Outputs are review
# files; approved raw and clean figures and the production fare script are intact.
source("script/0-config.R")
suppressPackageStartupMessages({
    library(arrow)
    library(data.table)
    library(MetBrewer)
})
setDTthreads(2)
set_cpu_count(2)
source("script/flight-analysis/summarize-public-journeys.R")

audit_path <- file.path("output", "airport-fare-audit")
out_path <- file.path(audit_path, "extended-public")
dir.create(out_path, recursive = TRUE, showWarnings = FALSE)
baseline <- fread(file.path(audit_path, "reconstructed-quarterly-fares.csv"))
monthly_2025 <- fread(file.path(audit_path, "harmonized", "monthly-journey-sums.csv"))
comparison_2025 <- fread(file.path(audit_path, "harmonized", "quarterly-comparison.csv"))
files <- list.files(flight_price_path,
    pattern = "^DB1C\\.PUBLIC\\.2026(01|02|03|04|05|06)\\..*parquet$", full.names = TRUE)
periods <- substr(basename(files), 13, 18)
stopifnot(identical(periods, sprintf("2026%02d", 1:6)))
routes <- c("LAS", "SEA", "SFO", "SLC")
result <- summarize_public_journeys(files, routes, out_path)
monthly_2026 <- result$monthly
monthly_2026[, QUARTER := (RpMonth - 1L) %/% 3L + 1L]
monthly <- rbindlist(list(monthly_2025, monthly_2026), use.names = TRUE)
stopifnot(nrow(monthly) == 48,
          !anyDuplicated(monthly[, .(RpYear, RpMonth, route)]),
          all(monthly[, .N, by = .(RpYear, QUARTER, route)]$N == 3))
fwrite(monthly, file.path(out_path, "monthly-journey-sums.csv"))
fwrite(result$checks, file.path(out_path, "allocation-checks-2026.csv"))

# Aggregate sums rather than averaging monthly means with equal weights.
q <- monthly[, .(fare = sum(fare_sum) / sum(passengers),
    passengers = sum(passengers), journey_passengers = sum(journey_passengers),
    missing_fare_passengers = sum(passengers - observed_fare_passengers),
    invalid_distance_passengers = sum(invalid_distance_passengers),
    observed_only_fare = sum(fare_sum) / sum(observed_fare_passengers),
    nonsurface_fare = sum(nonsurface_fare_sum) / sum(nonsurface_passengers)),
    by = .(YEAR = RpYear, QUARTER, route)]
check_2025 <- merge(q[YEAR == 2025], comparison_2025, by = c("YEAR", "QUARTER", "route"))
stopifnot(nrow(check_2025) == 8,
          max(abs(check_2025$fare - check_2025$harmonized_fare)) < 1e-8)
fwrite(q, file.path(out_path, "public-quarterly-fares.csv"))
historical <- baseline[YEAR < 2025 | (YEAR == 2025 & QUARTER <= 2),
                       .(YEAR, QUARTER, route, fare, passengers)]
historical[, source := "DB1B MARKET"]
public <- q[, .(YEAR, QUARTER, route, fare, passengers)]
public[, source := "DB1C PUBLIC reconstructed journeys"]
series <- rbindlist(list(historical, public))
series[, date := as.Date(sprintf("%d-%02d-01", YEAR, (QUARTER - 1L) * 3L + 1L))]
setorder(series, route, YEAR, QUARTER)
prior <- series[, .(YEAR = YEAR + 1L, QUARTER, route, prior_fare = fare)]
series <- merge(series, prior, by = c("YEAR", "QUARTER", "route"), all.x = TRUE)
series[, yoy_percent := 100 * (fare / prior_fare - 1)]
setorder(series, route, YEAR, QUARTER)
stopifnot(nrow(series) == 56, all(series[, .N, by = route]$N == 14),
          !anyNA(series$fare), all(series$passengers > 0))
fwrite(series, file.path(out_path, "quarterly-fares-2023Q1-2026Q2.csv"))
saveRDS(series, file.path(out_path, "quarterly-fares-2023Q1-2026Q2.rds"))

# Keep the original four vertical route panels, colors, point sizes, and policy
# line. Extend quarter/year labels and scale the axes to include the new values.
pal <- met.brewer("Tiepolo", 8)
for (figure in c("levels", "yoy", "yoy-2025-onward")) {
    is_levels <- figure == "levels"
    d_all <- if (is_levels) copy(series) else series[!is.na(yoy_percent)]
    if (figure == "yoy-2025-onward") d_all <- d_all[YEAR >= 2025]
    d_all[, value := if (is_levels) fare else yoy_percent]
    filename <- switch(figure, levels = "Flight-Prices-lax.pdf",
        yoy = "Flight-Prices-lax-yoy.pdf", "yoy-2025-onward" = "Flight-Prices-lax-yoy-2025-onward.pdf")
    pdf(file.path(out_path, filename), width = if (is_levels) 6 else 4, height = 9)
    par(mfrow = c(4, 1), mar = c(3, 4, 3, 1), oma = c(4, 0, 0, 0))
    limits <- range(d_all$value, if (!is_levels) 0, na.rm = TRUE)
    for (r in routes) {
        d <- d_all[route == r]
        plot(d$date, d$value, type = "o", pch = 16, lwd = 2, col = pal[1], cex = 2,
             xaxt = "n", xlab = "", ylab = if (is_levels) "Average fare ($)" else "Year-over-year change in fares (%)",
             ylim = limits, main = paste0("LAX-", r), axes = FALSE,
             cex.lab = if (is_levels) 1 else .8)
        ticks <- pretty(limits)
        axis(2, las = 2, at = ticks, labels = if (is_levels) ticks else paste0(ticks, "%"))
        for (yr in sort(unique(d$YEAR))) {
            dates <- d[YEAR == yr]
            axis.Date(1, at = dates$date, labels = paste0("Q", dates$QUARTER))
            if (r == "SLC") axis.Date(1, at = as.Date(mean(as.numeric(dates$date)), origin = "1970-01-01"),
                labels = yr, tick = FALSE, line = 2, cex.axis = 1.5)
        }
        abline(v = as.Date("2025-09-01"), lty = 3)
        if (!is_levels) abline(h = 0, lwd = .5, col = "gray")
    }
    dev.off()
}
print(series[YEAR == 2026, .(route, QUARTER, fare, yoy_percent)])
