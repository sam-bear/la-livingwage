# Diagnose whether the retained DB1B baseline includes zero-distance markets.
source("script/0-config.R")
suppressPackageStartupMessages(library(data.table))
setDTthreads(2)
files <- list.files(file.path(dropbox_living_wage_path, "new"), pattern = "csv$", full.names = TRUE)
route_ids <- c("12889" = "LAS", "14747" = "SEA", "14771" = "SFO", "14869" = "SLC")
results <- list()
for (f in files) {
    d <- fread(f, select = c("YEAR", "QUARTER", "ORIGIN_AIRPORT_ID", "DEST_AIRPORT_ID",
                            "PASSENGERS", "MARKET_FARE", "MARKET_DISTANCE"))
    d <- d[(ORIGIN_AIRPORT_ID == 12892 & DEST_AIRPORT_ID %in% names(route_ids)) |
           (DEST_AIRPORT_ID == 12892 & ORIGIN_AIRPORT_ID %in% names(route_ids))]
    d[, route := unname(route_ids[as.character(ifelse(ORIGIN_AIRPORT_ID == 12892,
                                                    DEST_AIRPORT_ID, ORIGIN_AIRPORT_ID))])]
    results[[basename(f)]] <- d[, .(passengers = sum(PASSENGERS),
        zero_distance_passengers = sum(PASSENGERS[MARKET_DISTANCE == 0], na.rm = TRUE),
        zero_distance_fare_sum = sum((MARKET_FARE * PASSENGERS)[MARKET_DISTANCE == 0], na.rm = TRUE),
        missing_distance_passengers = sum(PASSENGERS[is.na(MARKET_DISTANCE)])),
        by = .(YEAR, QUARTER, route)]
}
x <- rbindlist(results, idcol = "file")
fwrite(x, "output/airport-fare-audit/reconciliation/historical-zero-distance.csv")
print(x[, .(passengers = sum(passengers), zero_distance_passengers = sum(zero_distance_passengers),
            zero_distance_fare_sum = sum(zero_distance_fare_sum)), by = route])
