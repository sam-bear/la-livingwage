# Compare available native MARKET files with the reconstructed PUBLIC series.
# This is a diagnostic: MARKET's native break rules may differ from legacy
# PUBLIC breaks. No fare-validity filter is added, and no series is replaced.
source("script/0-config.R")
suppressPackageStartupMessages({
    library(arrow)
    library(dplyr)
})
set_cpu_count(2)
out_path <- file.path("output", "airport-fare-audit", "extended-public")
public <- read.csv(file.path(out_path, "monthly-journey-sums.csv")) |>
    mutate(public_fare = fare_sum / passengers,
           period = sprintf("%d%02d", RpYear, RpMonth))
files <- list.files(flight_price_path, pattern = "^DB1C\\.MARKET\\..*parquet$", full.names = TRUE)
periods <- substr(basename(files), 13, 18)
files <- files[periods %in% public$period]
stopifnot(length(files) > 0, !anyDuplicated(substr(basename(files), 13, 18)))
results <- list()
for (f in files) {
    d <- open_dataset(f)
    results[[basename(f)]] <- d |>
        filter((Origin == "LAX" & Dest %in% c("LAS", "SEA", "SFO", "SLC")) |
               (Dest == "LAX" & Origin %in% c("LAS", "SEA", "SFO", "SLC"))) |>
        mutate(route = if_else(Origin == "LAX", Dest, Origin)) |>
        group_by(RpYear, RpMonth, route) |>
        summarise(market_passengers = sum(Passengers, na.rm = TRUE),
                  market_fare_sum = sum(MktAmount * Passengers, na.rm = TRUE)) |>
        collect()
}
market <- bind_rows(results, .id = "market_file") |>
    ungroup() |>
    mutate(market_fare = market_fare_sum / market_passengers)
comparison <- public |>
    select(RpYear, RpMonth, route, public_passengers = passengers, public_fare,
           public_fare_sum = fare_sum) |>
    inner_join(market, by = c("RpYear", "RpMonth", "route")) |>
    mutate(public_minus_market_percent = 100 * (public_fare / market_fare - 1))
write.csv(comparison, file.path(out_path, "public-market-monthly-comparison.csv"), row.names = FALSE)
quarterly <- comparison |>
    mutate(QUARTER = (RpMonth - 1L) %/% 3L + 1L) |>
    group_by(RpYear, QUARTER, route) |>
    summarise(months = n(),
              public_fare = sum(public_fare_sum) / sum(public_passengers),
              market_fare = sum(market_fare_sum) / sum(market_passengers),
              .groups = "drop") |>
    mutate(public_minus_market_percent = 100 * (public_fare / market_fare - 1))
write.csv(quarterly, file.path(out_path, "public-market-quarterly-comparison.csv"), row.names = FALSE)
print(quarterly)
