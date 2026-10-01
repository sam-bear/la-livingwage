# Quantify the effect of replacing whole-ticket selection with directional
# journeys in July-December 2025. Run audit-original-fares.R first.
# Uses legacy trip breaks and coupon-distance allocation as a reconstruction
# of the DB1B market concept, not as a verified replication of DB1C MARKET.
source("script/0-config.R")
suppressPackageStartupMessages({
    library(arrow)
    library(data.table)
})
setDTthreads(2)
set_cpu_count(2)

audit_path <- file.path("output", "airport-fare-audit")
out_path <- file.path(audit_path, "harmonized")
dir.create(out_path, recursive = TRUE, showWarnings = FALSE)
baseline <- fread(file.path(audit_path, "reconstructed-quarterly-fares.csv"))
old_counts <- fread(file.path(audit_path, "public-journey-counts.csv"))
files <- list.files(flight_price_path,
    pattern = "^DB1C\\.PUBLIC\\.2025(07|08|09|10|11|12)\\..*parquet$", full.names = TRUE)
stopifnot(length(files) == 6,
          !anyDuplicated(sub(".*PUBLIC\\.([0-9]{6}).*", "\\1", files)))
routes <- c("LAS", "SEA", "SFO", "SLC")
source("script/flight-analysis/summarize-public-journeys.R")
result <- summarize_public_journeys(files, routes, out_path)
monthly <- result$monthly
checks <- list(result$checks)
count_check <- merge(monthly, old_counts, by = c("route", "RpYear", "RpMonth"),
                     suffixes = c("_new", "_audit"))
stopifnot(nrow(count_check) == 24,
    all(count_check$journey_passengers_new == count_check$journey_passengers_audit),
    all(count_check$excluded_ticket_passengers == count_check$from_excluded_tickets),
    all(count_check$roundtrip_passengers == count_check$from_roundtrip_tickets))
monthly[, QUARTER := (RpMonth - 1L) %/% 3L + 1L]
fwrite(monthly, file.path(out_path, "monthly-journey-sums.csv"))
fwrite(rbindlist(checks), file.path(out_path, "allocation-checks.csv"))
q <- monthly[, lapply(.SD, sum), by = .(YEAR = RpYear, QUARTER, route),
             .SDcols = setdiff(names(monthly), c("RpYear", "RpMonth", "QUARTER", "route"))]
q[, `:=`(harmonized_fare = fare_sum / passengers,
          observed_only_fare = fare_sum / observed_fare_passengers,
          retained_ticket_fare = retained_fare_sum / retained_passengers,
          added_ticket_fare = added_fare_sum / added_passengers,
          nonsurface_fare = nonsurface_fare_sum / nonsurface_passengers)]
old <- baseline[YEAR == 2025 & QUARTER >= 3, .(YEAR, QUARTER, route, old_fare = fare)]
prior <- baseline[YEAR == 2024 & QUARTER >= 3, .(QUARTER, route, prior_fare = fare)]
comparison <- merge(merge(q, old, by = c("YEAR", "QUARTER", "route")),
                    prior, by = c("QUARTER", "route"))
comparison[, `:=`(dollar_change = harmonized_fare - old_fare,
    percent_change = 100 * (harmonized_fare / old_fare - 1),
    old_yoy_percent = 100 * (old_fare / prior_fare - 1),
    harmonized_yoy_percent = 100 * (harmonized_fare / prior_fare - 1),
    yoy_change_pp = 100 * (harmonized_fare - old_fare) / prior_fare)]
setorder(comparison, route, QUARTER)
fwrite(comparison, file.path(out_path, "quarterly-comparison.csv"))
print(comparison[, .(route, QUARTER, old_fare, harmonized_fare, percent_change,
                     old_yoy_percent, harmonized_yoy_percent)])

# Standalone review figure. Keep the approved raw/clean figures unchanged.
pdf(file.path(out_path, "fare-comparison.pdf"), width = 8, height = 7)
par(mfrow = c(2, 2), mar = c(4, 4.5, 3, 1), oma = c(2, 0, 1, 0))
for (r in routes) {
    d <- comparison[route == r]
    plot(d$QUARTER, d$old_fare, type = "b", pch = 16, col = "#802417",
         lwd = 2, xlim = c(2.85, 4.15), ylim = range(d$old_fare, d$harmonized_fare) * c(.95, 1.05),
         axes = FALSE, xlab = "2025", ylab = "Average fare ($)", main = paste0("LAX-", r))
    lines(d$QUARTER, d$harmonized_fare, type = "b", pch = 17, lwd = 2, col = "#21618C")
    axis(1, at = 3:4, labels = c("Q3", "Q4"))
    axis(2, las = 1)
    legend("topright", legend = c("Approved series", "Reconstructed journeys"),
           col = c("#802417", "#21618C"), pch = c(16, 17), lty = 1, bty = "n", cex = .75)
}
mtext("PUBLIC data; legacy trip breaks; ticket amounts allocated by coupon distance.",
      side = 1, outer = TRUE, line = .5, cex = .8)
dev.off()
