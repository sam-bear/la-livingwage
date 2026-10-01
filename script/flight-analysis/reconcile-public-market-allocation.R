# Test surface-distance allocation separately from journey-break selection.
# All outputs are diagnostics; existing fare figures remain unchanged.
source("script/0-config.R")
suppressPackageStartupMessages({library(arrow); library(data.table); library(dplyr)})
set_cpu_count(2)
setDTthreads(2)
source("script/flight-analysis/summarize-public-journeys.R")
out_path <- file.path("output", "airport-fare-audit", "reconciliation")
old <- fread(file.path("output", "airport-fare-audit", "extended-public",
                       "public-market-monthly-comparison.csv"))
periods <- unique(sprintf("%d%02d", old$RpYear, old$RpMonth))
files <- list.files(flight_price_path, pattern = "^DB1C\\.PUBLIC\\..*parquet$", full.names = TRUE)
files <- files[substr(basename(files), 13, 18) %in% periods]
stopifnot(length(files) == length(periods), !anyDuplicated(substr(basename(files), 13, 18)))

# MARKET identifies ground-only journeys directly through zero flown miles.
market_files <- unique(file.path(flight_price_path, old$market_file))
market <- list()
for (f in market_files) {
    market[[basename(f)]] <- open_dataset(f) |>
        filter((Origin == "LAX" & Dest %in% c("LAS", "SEA", "SFO", "SLC")) |
               (Dest == "LAX" & Origin %in% c("LAS", "SEA", "SFO", "SLC"))) |>
        mutate(route = if_else(Origin == "LAX", Dest, Origin)) |>
        group_by(RpYear, RpMonth, route) |>
        summarise(market_passengers = sum(Passengers),
                  market_fare_sum = sum(MktAmount * Passengers, na.rm = TRUE),
                  ground_passengers = sum(if_else(MilesTraveled == 0, Passengers, 0)),
                  ground_fare_sum = sum(if_else(MilesTraveled == 0, MktAmount * Passengers, 0), na.rm = TRUE),
                  flying_passengers = sum(if_else(MilesTraveled > 0, Passengers, 0)),
                  flying_fare_sum = sum(if_else(MilesTraveled > 0, MktAmount * Passengers, 0), na.rm = TRUE)) |>
        collect()
}
market <- as.data.table(bind_rows(market, .id = "market_file"))
fwrite(market, file.path(out_path, "market-surface-summary.csv"))

for (logic in c("TripBk19_8", "TripBk19_7")) {
    destination <- file.path(out_path, logic)
    dir.create(destination, recursive = TRUE, showWarnings = FALSE)
    result <- summarize_public_journeys(files, c("LAS", "SEA", "SFO", "SLC"),
                                       destination, logic, allocation_diagnostics = TRUE)
    fwrite(result$monthly, file.path(destination, "monthly-sums.csv"))
    fwrite(result$checks, file.path(destination, "allocation-checks.csv"))
    x <- merge(result$monthly, market, by = c("RpYear", "RpMonth", "route"),
               suffixes = c("_public", "_market"))
    stopifnot(nrow(x) == nrow(old))
    x[, `:=`(original_fare = fare_sum / passengers,
             air_allocation_fare = air_allocation_fare_sum / passengers,
             public_flying_fare = flying_fare_sum_public / flying_passengers_public,
             market_fare = market_fare_sum / market_passengers,
             market_flying_fare = flying_fare_sum_market / flying_passengers_market)]
    fwrite(x, file.path(destination, "allocation-monthly-comparison.csv"))
    q <- x[, .(months = .N, passengers = sum(passengers),
               market_passengers = sum(market_passengers),
               original_fare = sum(fare_sum) / sum(passengers),
               air_allocation_fare = sum(air_allocation_fare_sum) / sum(passengers),
               public_flying_fare = sum(flying_fare_sum_public) / sum(flying_passengers_public),
               market_fare = sum(market_fare_sum) / sum(market_passengers),
               market_flying_fare = sum(flying_fare_sum_market) / sum(flying_passengers_market),
               ground_only_passengers = sum(ground_only_passengers),
               market_ground_passengers = sum(ground_passengers)),
           by = .(RpYear, QUARTER = (RpMonth - 1L) %/% 3L + 1L, route)]
    fwrite(q, file.path(destination, "allocation-quarterly-comparison.csv"))
    print(q)
}

# Confirm diagnostics preserve the previously plotted calculation exactly.
legacy <- fread(file.path(out_path, "TripBk19_7", "allocation-monthly-comparison.csv"))
check <- merge(legacy[, .(RpYear, RpMonth, route, passengers, original_fare)],
               old[, .(RpYear, RpMonth, route, public_passengers, public_fare)],
               by = c("RpYear", "RpMonth", "route"))
stopifnot(nrow(check) == nrow(old), all(check$passengers == check$public_passengers),
          max(abs(check$original_fare - check$public_fare)) < 1e-8)
new <- fread(file.path(out_path, "TripBk19_8", "allocation-monthly-comparison.csv"))
check_2026 <- new[RpYear == 2026]
stopifnot(all(check_2026$passengers == check_2026$market_passengers),
          all(check_2026$ground_only_passengers == check_2026$ground_passengers))
validation <- data.table(
    check = c("legacy_fare_max_absolute_difference_from_saved_series",
              "new_break_2026_max_absolute_fare_difference_from_MARKET",
              "new_break_2026_max_absolute_ground_passenger_difference"),
    value = c(max(abs(check$original_fare - check$public_fare)),
              max(abs(check_2026$air_allocation_fare - check_2026$market_fare)),
              max(abs(check_2026$ground_only_passengers - check_2026$ground_passengers))))
fwrite(validation, file.path(out_path, "validation.csv"))
print(validation)
