# Reconstruct the saved fare method without replacing the approved figures.
# Run from the repository root. Inputs are the original Dropbox files; outputs
# stay in output/airport-fare-audit. No OneDrive input is opened.
source("script/0-config.R")
suppressPackageStartupMessages({
    library(arrow)
    library(data.table)
    library(dplyr)
    library(tidyr)
    library(lubridate)
    library(MetBrewer)
})
setDTthreads(2)
set_cpu_count(2)

audit_path <- file.path("output", "airport-fare-audit")
dir.create(audit_path, recursive = TRUE, showWarnings = FALSE)
historical_path <- file.path(dropbox_living_wage_path, "new")
routes <- c("LAS", "SEA", "SFO", "SLC")
route_ids <- c("12889" = "LAS", "14747" = "SEA",
               "14771" = "SFO", "14869" = "SLC")
historical_files <- list.files(historical_path, pattern = "\\.csv$", full.names = TRUE)
public_files <- list.files(flight_price_path,
    pattern = "^DB1C\\.PUBLIC\\.2025(07|08|09|10|11|12)\\..*parquet$", full.names = TRUE)
stopifnot(length(historical_files) == 10, length(public_files) == 6)
stopifnot(!anyDuplicated(sub(".*PUBLIC\\.([0-9]{6}).*", "\\1", public_files)))

# Original DB1B market selection and weighted means. Read one quarter at a time.
historical <- list()
manifest <- list()
for (i in seq_along(historical_files)) {
    f <- historical_files[i]
    message("Historical: ", basename(f))
    d <- fread(f, select = c("YEAR", "QUARTER", "ORIGIN_AIRPORT_ID",
        "DEST_AIRPORT_ID", "MARKET_FARE", "PASSENGERS", "MARKET_DISTANCE"),
        nThread = 2)
    stopifnot(nrow(unique(d[, .(YEAR, QUARTER)])) == 1)
    manifest[[i]] <- data.table(file = basename(f), rows = nrow(d),
        year = d$YEAR[1], quarter = d$QUARTER[1])
    d <- d[(ORIGIN_AIRPORT_ID == 12892 & DEST_AIRPORT_ID %in% names(route_ids)) |
           (DEST_AIRPORT_ID == 12892 & ORIGIN_AIRPORT_ID %in% names(route_ids))]
    d[, route := unname(route_ids[as.character(ifelse(ORIGIN_AIRPORT_ID == 12892,
                                                   DEST_AIRPORT_ID, ORIGIN_AIRPORT_ID))])]
    historical[[i]] <- d[, .(
        fare = sum(MARKET_FARE * PASSENGERS, na.rm = TRUE) / sum(PASSENGERS, na.rm = TRUE),
        passengers = sum(PASSENGERS, na.rm = TRUE), n_obs = .N,
        avg_dist = sum(MARKET_DISTANCE * PASSENGERS, na.rm = TRUE) / sum(PASSENGERS, na.rm = TRUE)
    ), by = .(YEAR, QUARTER, route)]
    rm(d)
    gc()
}
historical <- rbindlist(historical)
stopifnot(nrow(historical) == 40, !anyDuplicated(historical[, .(YEAR, QUARTER, route)]))
fwrite(rbindlist(manifest), file.path(audit_path, "historical-inputs.csv"))

# The original apt_cols object was not saved in the script. Reconstruct the
# intended numeric airport order, including LastApt for the maximum 23 coupons.
# Process 100,000-row Parquet groups to keep memory bounded. In addition to the
# old method, count journey endpoints using the legacy trip-break flags. These
# diagnostic journey counts do NOT allocate fares or replace baseline estimates.
monthly <- list()
diagnostics <- list()
journey_counts <- list()
for (i in seq_along(public_files)) {
    f <- public_files[i]
    message("PUBLIC: ", basename(f))
    reader <- ParquetFileReader$create(f)
    fields <- reader$GetSchema()$names
    apt_cols <- grep("^Apt_[0-9]+$", fields, value = TRUE)
    apt_cols <- apt_cols[order(as.integer(sub("Apt_", "", apt_cols)))]
    apt_cols <- c(apt_cols, "LastApt")
    dist_cols <- grep("^Coupon_SegDist_", fields, value = TRUE)
    break_cols <- grep("^TripBk19_7_[0-9]+$", fields, value = TRUE)
    break_cols <- break_cols[order(as.integer(sub("TripBk19_7_", "", break_cols)))]
    stopifnot(length(apt_cols) == 24, length(break_cols) == 22)
    columns <- c("RpYear", "RpMonth", "CouponSeg", "TotalAmt", "TaxAmt", "NumPax",
                 apt_cols, dist_cols, break_cols, "TripBk19_7_last")
    stopifnot(all(columns %in% fields))
    group_totals <- list()
    group_diagnostics <- list()
    group_journeys <- list()
    for (g in seq_len(reader$num_row_groups)) {
        d <- as.data.table(reader$ReadRowGroup(g - 1L, match(columns, fields) - 1L))
        stopifnot(all(d$RpYear == 2025), all(d$RpMonth == 6 + i),
                  all(d$CouponSeg >= 1 & d$CouponSeg <= 23))
        apt <- as.matrix(d[, ..apt_cols])
        final <- apt[cbind(seq_len(nrow(d)), d$CouponSeg + 1L)]
        selected <- (d$Apt_1 == "LAX" & final %in% routes) |
                    (final == "LAX" & d$Apt_1 %in% routes)
        selected[is.na(selected)] <- FALSE
        roundtrip <- d$Apt_1 == final
        internal_break <- rep(FALSE, nrow(d))
        for (j in seq_along(break_cols)) {
            internal_break <- internal_break |
                (d$CouponSeg > j & !is.na(d[[break_cols[j]]]) & d[[break_cols[j]]] == "X")
        }
        d[, route := ifelse(Apt_1 == "LAX", final, Apt_1)]
        sub <- d[selected]
        sub[, itin_dist := rowSums(.SD, na.rm = TRUE), .SDcols = dist_cols]
        sub[, has_internal_break := internal_break[selected]]
        group_totals[[g]] <- sub[, .(
            fare_sum = sum(TotalAmt * NumPax, na.rm = TRUE),
            passengers = sum(NumPax, na.rm = TRUE), n_obs = .N,
            dist_sum = sum(itin_dist * NumPax, na.rm = TRUE),
            missing_fare_passengers = sum(NumPax[is.na(TotalAmt)], na.rm = TRUE),
            nonpositive_passengers = sum(NumPax[!is.na(TotalAmt) & TotalAmt <= 0], na.rm = TRUE),
            tax_only_passengers = sum(NumPax[!is.na(TotalAmt) & !is.na(TaxAmt) & TotalAmt <= TaxAmt], na.rm = TRUE),
            multiple_market_passengers = sum(NumPax[has_internal_break], na.rm = TRUE)
        ), by = .(RpYear, RpMonth, route)]
        group_diagnostics[[g]] <- data.table(
            rows = nrow(d), selected_rows = sum(selected),
            lax_roundtrip_rows = sum(roundtrip & d$Apt_1 == "LAX", na.rm = TRUE),
            missing_final_rows = sum(is.na(final)))

        # Split at legacy directional breaks, or the end of the ticket. Count
        # only journeys with LAX as an endpoint, regardless of via airports.
        start <- d$Apt_1
        for (k in 2:24) {
            flag <- if (k < 24) d[[break_cols[k - 1L]]] else d$TripBk19_7_last
            at_end <- d$CouponSeg == k - 1L
            at_break <- d$CouponSeg >= k - 1L & !is.na(flag) & flag == "X"
            finish <- at_end | at_break
            endpoint <- apt[, k]
            use <- finish & ((start == "LAX" & endpoint %in% routes) |
                              (endpoint == "LAX" & start %in% routes))
            use[is.na(use)] <- FALSE
            if (any(use)) {
                z <- data.table(route = ifelse(start[use] == "LAX", endpoint[use], start[use]),
                    passengers = d$NumPax[use], ticket_selected = selected[use],
                    roundtrip_ticket = roundtrip[use])
                group_journeys[[length(group_journeys) + 1L]] <- z[, .(
                    journey_passengers = sum(passengers, na.rm = TRUE),
                    from_excluded_tickets = sum(passengers[!ticket_selected], na.rm = TRUE),
                    from_roundtrip_tickets = sum(passengers[roundtrip_ticket], na.rm = TRUE)
                ), by = route]
            }
            start[finish] <- endpoint[finish]
        }
    }
    totals <- rbindlist(group_totals)
    monthly[[i]] <- totals[, lapply(.SD, sum), by = .(RpYear, RpMonth, route)]
    diagnostics[[i]] <- cbind(data.table(file = basename(f)),
        rbindlist(group_diagnostics)[, lapply(.SD, sum)])
    journey_counts[[i]] <- rbindlist(group_journeys)[, lapply(.SD, sum), by = route][
        , `:=`(RpYear = 2025L, RpMonth = 6L + i)]
    message("Completed ", basename(f))
    rm(d, apt, sub, group_totals, group_journeys)
    gc()
}
monthly <- rbindlist(monthly)
monthly[, fare := fare_sum / passengers]
monthly[, QUARTER := (RpMonth - 1L) %/% 3L + 1L]
fwrite(monthly, file.path(audit_path, "public-monthly-baseline-and-checks.csv"))
fwrite(rbindlist(diagnostics), file.path(audit_path, "public-file-checks.csv"))
fwrite(rbindlist(journey_counts), file.path(audit_path, "public-journey-counts.csv"))
post <- monthly[, .(fare = sum(fare * passengers) / sum(passengers),
    passengers = sum(passengers), n_obs = sum(n_obs),
    avg_dist = sum(dist_sum) / sum(passengers)), by = .(YEAR = RpYear, QUARTER, route)]
dat_all_q <- as.data.frame(rbindlist(list(historical, post)))
dat_all_q <- dat_all_q |> arrange(route, YEAR, QUARTER)
stopifnot(nrow(dat_all_q) == 48)
write.csv(dat_all_q, file.path(audit_path, "reconstructed-quarterly-fares.csv"), row.names = FALSE)
saveRDS(dat_all_q, file.path(audit_path, "reconstructed-quarterly-fares.rds"))

# Reuse the original plotting code verbatim, redirecting only its output folder.
# This isolates data/method reproduction from any change to the approved design.
original <- readLines("script/AirportPrices.R")
plot_start <- grep('pal <- met.brewer', original, fixed = TRUE)
stopifnot(length(plot_start) == 1)
plot_code <- original[plot_start:length(original)]
plot_code <- gsub("figures/raw/", paste0(audit_path, "/"), plot_code, fixed = TRUE)
eval(parse(text = plot_code))

# The repository also retains the earlier full 2024-2025 year-over-year figure.
# Its plotting block differs only in the output name and date subset.
yoy_start <- grep('pdf("figures/raw/Flight-Prices-lax-yoy-2025.pdf"', original, fixed = TRUE)
stopifnot(length(yoy_start) == 1)
yoy_code <- original[yoy_start:length(original)]
yoy_code <- gsub("figures/raw/", paste0(audit_path, "/"), yoy_code, fixed = TRUE)
yoy_code <- gsub("Flight-Prices-lax-yoy-2025.pdf", "Flight-Prices-lax-yoy.pdf", yoy_code, fixed = TRUE)
yoy_code <- gsub(' %>% filter(q_date>="2025-01-01")', "", yoy_code, fixed = TRUE)
eval(parse(text = yoy_code))
message("Audit outputs: ", audit_path)
