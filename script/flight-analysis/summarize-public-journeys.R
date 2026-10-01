# Shared bounded-memory PUBLIC journey reconstruction.
# Callers load arrow and data.table and supply explicit files and output folder.
# Legacy break and allocation rules are shared by the 2025 audit and extension.
summarize_public_journeys <- function(files, routes, out_path, break_logic = "TripBk19_7",
                                      allocation_diagnostics = FALSE) {
    stopifnot(break_logic %in% c("TripBk19_7", "TripBk19_8"))
    monthly <- list()
    checks <- list()

    for (i in seq_along(files)) {
        expected_year <- as.integer(substr(basename(files[i]), 13, 16))
        expected_month <- as.integer(substr(basename(files[i]), 17, 18))
        message("Harmonizing ", basename(files[i]))
        reader <- ParquetFileReader$create(files[i])
        fields <- reader$GetSchema()$names
        apt_cols <- grep("^Apt_[0-9]+$", fields, value = TRUE)
        apt_cols <- apt_cols[order(as.integer(sub("Apt_", "", apt_cols)))]
        apt_cols <- c(apt_cols, "LastApt")
        dist_cols <- grep("^Coupon_SegDist_[0-9]+$", fields, value = TRUE)
        dist_cols <- dist_cols[order(as.integer(sub("Coupon_SegDist_", "", dist_cols)))]
        break_cols <- grep(paste0("^", break_logic, "_[0-9]+$"), fields, value = TRUE)
        break_cols <- break_cols[order(as.integer(sub(paste0(break_logic, "_"), "", break_cols)))]
        break_cols <- c(break_cols, paste0(break_logic, "_last"))
        carrier_cols <- grep("^OpCarrier_[0-9]+$", fields, value = TRUE)
        carrier_cols <- carrier_cols[order(as.integer(sub("OpCarrier_", "", carrier_cols)))]
        columns <- c("RpYear", "RpMonth", "CouponSeg", "TotalAmt", "NumPax",
                     apt_cols, dist_cols, break_cols, carrier_cols)
        stopifnot(length(apt_cols) == 24, length(dist_cols) == 23,
                  length(break_cols) == 23, length(carrier_cols) == 23,
                  all(columns %in% fields))
        group_summaries <- list()
        group_checks <- list()
        for (g in seq_len(reader$num_row_groups)) {
            d <- as.data.table(reader$ReadRowGroup(g - 1L, match(columns, fields) - 1L))
            stopifnot(all(d$RpYear == expected_year), all(d$RpMonth == expected_month),
                      all(d$CouponSeg >= 1 & d$CouponSeg <= 23),
                      all(is.finite(d$NumPax) & d$NumPax > 0))
            rows_read <- nrow(d)
            apt <- as.matrix(d[, ..apt_cols])
            # A relevant journey must contain both LAX and one selected endpoint.
            has_lax <- rowSums(apt == "LAX", na.rm = TRUE) > 0
            has_route <- rowSums(matrix(apt %in% routes, nrow = nrow(d))) > 0
            d <- d[has_lax & has_route]
            if (nrow(d) == 0) {
                group_checks[[g]] <- data.table(rows_read = rows_read, candidate_tickets = 0L,
                    invalid_distance_tickets = 0L, max_allocation_error = 0)
                next
            }
            apt <- as.matrix(d[, ..apt_cols])
            distances <- as.matrix(d[, ..dist_cols])
            carriers <- as.matrix(d[, ..carrier_cols])
            active <- col(distances) <= d$CouponSeg
            valid_distance <- rowSums(active & (!is.finite(distances) | distances < 0)) == 0
            distances[!active | !is.finite(distances) | distances < 0] <- 0
            total_distance <- rowSums(distances)
            valid_distance <- valid_distance & total_distance > 0
            surface <- rowSums(active & matrix(carriers %in% c("--", "BUS", "TRN"),
                                             nrow = nrow(d))) > 0
            if (allocation_diagnostics) {
                air_distances <- distances
                air_distances[matrix(carriers %in% c("--", "BUS", "TRN"), nrow = nrow(d))] <- 0
                total_air_distance <- rowSums(air_distances)
                journey_air_distance <- rep(0, nrow(d))
            }
            final <- apt[cbind(seq_len(nrow(d)), d$CouponSeg + 1L)]
            old_selected <- (d$Apt_1 == "LAX" & final %in% routes) |
                            (final == "LAX" & d$Apt_1 %in% routes)
            old_selected[is.na(old_selected)] <- FALSE
            roundtrip <- d$Apt_1 == final
            start <- d$Apt_1
            journey_distance <- rep(0, nrow(d))
            allocated_distance <- rep(0, nrow(d))
            for (k in 2:24) {
                journey_distance <- journey_distance + distances[, k - 1L]
                if (allocation_diagnostics) {
                    journey_air_distance <- journey_air_distance + air_distances[, k - 1L]
                }
                flag <- d[[break_cols[k - 1L]]]
                finish <- (d$CouponSeg == k - 1L) |
                    (d$CouponSeg >= k - 1L & !is.na(flag) & flag == "X")
                endpoint <- apt[, k]
                use <- finish & ((start == "LAX" & endpoint %in% routes) |
                                  (endpoint == "LAX" & start %in% routes))
                use[is.na(use)] <- FALSE
                if (any(use)) {
                    z <- data.table(
                        route = ifelse(start[use] == "LAX", endpoint[use], start[use]),
                        passengers = d$NumPax[use], old_selected = old_selected[use],
                        roundtrip = roundtrip[use], surface = surface[use],
                        allocatable = valid_distance[use] & journey_distance[use] > 0,
                        fare = d$TotalAmt[use] * journey_distance[use] / total_distance[use])
                    z[allocatable == FALSE, fare := NA_real_]
                    if (allocation_diagnostics) {
                        z[, air_fare := d$TotalAmt[use] * journey_air_distance[use] /
                                            total_air_distance[use]]
                        z[, ground_only := journey_air_distance[use] == 0]
                        z[ground_only == TRUE, air_fare := 0]
                    }
                    group_summaries[[length(group_summaries) + 1L]] <- z[, .(
                        journey_passengers = sum(passengers),
                        excluded_ticket_passengers = sum(passengers[!old_selected]),
                        roundtrip_passengers = sum(passengers[roundtrip], na.rm = TRUE),
                        invalid_distance_passengers = sum(passengers[!allocatable]),
                        passengers = sum(passengers[allocatable]),
                        fare_sum = sum(fare * passengers, na.rm = TRUE),
                        observed_fare_passengers = sum(passengers[allocatable & is.finite(fare)]),
                        # Cohorts separate the included and newly added tickets.
                        retained_passengers = sum(passengers[allocatable & old_selected]),
                        retained_fare_sum = sum(fare[old_selected] * passengers[old_selected], na.rm = TRUE),
                        added_passengers = sum(passengers[allocatable & !old_selected]),
                        added_fare_sum = sum(fare[!old_selected] * passengers[!old_selected], na.rm = TRUE),
                        surface_passengers = sum(passengers[allocatable & surface]),
                        nonsurface_passengers = sum(passengers[allocatable & !surface]),
                        nonsurface_fare_sum = sum(fare[!surface] * passengers[!surface], na.rm = TRUE)
                    ), by = route]
                    if (allocation_diagnostics) {
                        j <- length(group_summaries)
                        extra <- z[, .(
                            air_allocation_fare_sum = sum(air_fare * passengers, na.rm = TRUE),
                            ground_only_passengers = sum(passengers[ground_only]),
                            ground_only_original_fare_sum = sum(fare[ground_only] * passengers[ground_only], na.rm = TRUE),
                            flying_passengers = sum(passengers[!ground_only]),
                            flying_fare_sum = sum(air_fare[!ground_only] * passengers[!ground_only], na.rm = TRUE)
                        ), by = route]
                        group_summaries[[j]] <- merge(group_summaries[[j]], extra, by = "route")
                    }
                }
                allocated_distance[finish] <- allocated_distance[finish] + journey_distance[finish]
                start[finish] <- endpoint[finish]
                journey_distance[finish] <- 0
                if (allocation_diagnostics) journey_air_distance[finish] <- 0
            }
            # Every ticket is completely partitioned. Consequently proportional
            # allocations across ALL its journeys conserve the total ticket fare.
            allocation_error <- max(abs(allocated_distance - total_distance))
            stopifnot(allocation_error < 1e-8)
            group_checks[[g]] <- data.table(rows_read = rows_read, candidate_tickets = nrow(d),
                invalid_distance_tickets = sum(!valid_distance), max_allocation_error = allocation_error)
        }
        monthly[[i]] <- rbindlist(group_summaries)[, lapply(.SD, sum), by = route][
            , `:=`(RpYear = expected_year, RpMonth = expected_month)]
        checks[[i]] <- rbindlist(group_checks)[, .(
            file = basename(files[i]), rows_read = sum(rows_read),
            candidate_tickets = sum(candidate_tickets),
            invalid_distance_tickets = sum(invalid_distance_tickets),
            max_allocation_error = max(max_allocation_error))]
        # Save each completed month; rerunning the script still reads every input.
        fwrite(monthly[[i]], file.path(out_path, sub("\\.parquet$", "-summary.csv", basename(files[i]))))
        message("Completed ", expected_year, "-", expected_month)
    }
    monthly <- rbindlist(monthly)
    list(monthly = monthly, checks = rbindlist(checks))
}
