# Separate the effect of PUBLIC legacy versus provisional DB1C journey breaks.
# This diagnostic does not replace any plotted fares.
source("script/0-config.R")
suppressPackageStartupMessages({
    library(arrow)
    library(data.table)
})
set_cpu_count(2)
setDTthreads(2)
source("script/flight-analysis/summarize-public-journeys.R")

out_path <- file.path("output", "airport-fare-audit", "reconciliation")
dir.create(out_path, recursive = TRUE, showWarnings = FALSE)
extended_path <- file.path("output", "airport-fare-audit", "extended-public")
old <- fread(file.path(extended_path, "public-market-monthly-comparison.csv"))
periods <- unique(sprintf("%d%02d", old$RpYear, old$RpMonth))
files <- list.files(flight_price_path, pattern = "^DB1C\\.PUBLIC\\..*parquet$", full.names = TRUE)
files <- files[substr(basename(files), 13, 18) %in% periods]
stopifnot(length(files) == length(periods), !anyDuplicated(substr(basename(files), 13, 18)))

# Hold input releases, weights, and mileage allocation fixed; change only breaks.
new <- summarize_public_journeys(files, c("LAS", "SEA", "SFO", "SLC"),
                                out_path, break_logic = "TripBk19_8")
fwrite(new$monthly, file.path(out_path, "new-break-monthly-sums.csv"))
fwrite(new$checks, file.path(out_path, "new-break-allocation-checks.csv"))
x <- merge(old, new$monthly[, .(RpYear, RpMonth, route,
                               new_break_passengers = passengers,
                               new_break_fare_sum = fare_sum)],
           by = c("RpYear", "RpMonth", "route"))
stopifnot(nrow(x) == nrow(old))
x[, new_break_fare := new_break_fare_sum / new_break_passengers]
x[, `:=`(legacy_minus_market = public_fare - market_fare,
         break_effect = public_fare - new_break_fare,
         new_minus_market = new_break_fare - market_fare,
         passenger_difference = new_break_passengers - market_passengers)]
fwrite(x, file.path(out_path, "break-rule-monthly-comparison.csv"))
q <- x[, .(months = .N,
           legacy_fare = sum(public_fare_sum) / sum(public_passengers),
           new_break_fare = sum(new_break_fare_sum) / sum(new_break_passengers),
           market_fare = sum(market_fare_sum) / sum(market_passengers),
           legacy_passengers = sum(public_passengers),
           new_break_passengers = sum(new_break_passengers),
           market_passengers = sum(market_passengers)),
       by = .(RpYear, QUARTER = (RpMonth - 1L) %/% 3L + 1L, route)]
q[, `:=`(legacy_minus_market_percent = 100 * (legacy_fare / market_fare - 1),
         new_minus_market_percent = 100 * (new_break_fare / market_fare - 1))]
fwrite(q, file.path(out_path, "break-rule-quarterly-comparison.csv"))
print(q)
