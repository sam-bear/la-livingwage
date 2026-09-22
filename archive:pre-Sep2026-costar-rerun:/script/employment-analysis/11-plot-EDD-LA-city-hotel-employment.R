# Monthly private NAICS 7211 employment allocated to LA City hotels.
# EDD observes employment by workplace PUMA, not by city or hotel. These are
# room-share allocations, NOT directly observed treated/untreated worker counts.
# Run from the repository root after building the reviewed countywide crosswalk.

source("script/0-config.R")

policy_date <- as.Date("2025-09-01")
hotel_file <- file.path(clean_path, "hotel_countywide_puma_crosswalk.rds")
employment_file <- file.path(clean_path, "edd_emp_monthly.rds")
stopifnot(file.exists(hotel_file), file.exists(employment_file))

hotels <- readRDS(hotel_file)
employment <- readRDS(employment_file) |>
    dplyr::filter(naics4 == "7211", ownership_code == 5)

stopifnot(!anyDuplicated(employment[c("puma", "date")]),
          all(is.na(employment$employment) == employment$employment_suppressed),
          identical(sort(unique(employment$date)),
                    seq(as.Date("2023-01-01"), as.Date("2025-12-01"), by = "month")))

# A fixed reporting panel prevents suppression changes from creating apparent
# jumps in the plotted workforce. PUMAs with no EDD row are also omitted.
reporting <- employment |>
    dplyr::group_by(puma) |>
    dplyr::summarise(reported_months = sum(!is.na(employment)), .groups = "drop")
balanced_pumas <- reporting$puma[reporting$reported_months == 36L]

# The reviewed CoStar roster supplies all rooms (including outside LA City)
# and the two LA City components. Hotels outside LA remain in the denominator.
room_allocation <- hotels |>
    dplyr::filter(in_scope, puma_matches == 1, !is.na(rooms), rooms > 0) |>
    dplyr::group_by(puma) |>
    dplyr::summarise(
        all_rooms = sum(rooms),
        city_rooms = sum(rooms[in_la_city]),
        covered_city_rooms = sum(rooms[in_la_city & treated == 1]),
        uncovered_city_rooms = sum(rooms[in_la_city & treated == 0]),
        .groups = "drop"
    ) |>
    dplyr::mutate(
        city_share = city_rooms / all_rooms,
        covered_city_share = covered_city_rooms / all_rooms,
        uncovered_city_share = uncovered_city_rooms / all_rooms
    )
stopifnot(all(room_allocation$city_rooms ==
                  room_allocation$covered_city_rooms +
                      room_allocation$uncovered_city_rooms),
          all(room_allocation$city_share <= 1))

# Use the same roster weights in each month. These are current reviewed hotel
# rooms, not a historical inventory reconstructed separately for each year.
allocation_panel <- employment |>
    dplyr::filter(puma %in% balanced_pumas) |>
    dplyr::left_join(room_allocation, by = "puma") |>
    dplyr::mutate(
        city_share = dplyr::coalesce(city_share, 0),
        covered_city_share = dplyr::coalesce(covered_city_share, 0),
        uncovered_city_share = dplyr::coalesce(uncovered_city_share, 0),
        estimated_city_employment = employment * city_share,
        estimated_covered_employment = employment * covered_city_share,
        estimated_uncovered_employment = employment * uncovered_city_share
    )
stopifnot(!any(is.na(allocation_panel$employment)),
          !any(is.na(allocation_panel$estimated_city_employment)))

city_series <- allocation_panel |>
    dplyr::group_by(date) |>
    dplyr::summarise(
        estimated_city_employment = sum(estimated_city_employment),
        estimated_covered_employment = sum(estimated_covered_employment),
        estimated_uncovered_employment = sum(estimated_uncovered_employment),
        reporting_pumas = dplyr::n(),
        .groups = "drop"
    )
stopifnot(nrow(city_series) == 36L,
          all(city_series$reporting_pumas == length(balanced_pumas)),
          isTRUE(all.equal(city_series$estimated_city_employment,
                           city_series$estimated_covered_employment +
                               city_series$estimated_uncovered_employment)))

all_city_rooms <- sum(room_allocation$city_rooms)
balanced_room_allocation <- dplyr::filter(room_allocation,
                                          puma %in% balanced_pumas)
represented_city_rooms <- sum(balanced_room_allocation$city_rooms)
represented_covered_rooms <- sum(balanced_room_allocation$covered_city_rooms)
represented_uncovered_rooms <- sum(balanced_room_allocation$uncovered_city_rooms)
cat("Balanced reporting PUMAs:", length(balanced_pumas), "\n")
cat("LA City rooms represented:", represented_city_rooms, "of",
    all_city_rooms, "\n")
cat("Covered / uncovered LA City rooms represented:",
    represented_covered_rooms, "/", represented_uncovered_rooms, "\n")
print(dplyr::filter(city_series, date %in% as.Date(c("2023-01-01",
                                                  "2025-08-01",
                                                  "2025-12-01"))))

dir.create("output", recursive = TRUE, showWarnings = FALSE)
dir.create("figures/raw", recursive = TRUE, showWarnings = FALSE)
utils::write.csv(city_series,
                 "output/EDD-LA-city-hotel-employment-allocated-monthly.csv",
                 row.names = FALSE)

# Match the hotel's Tiepolo scheme: covered hotels use pal[1], untreated
# hotels use pal[7], and the aggregate uses the dark neutral pal[8].
pal <- MetBrewer::met.brewer("Tiepolo", 8)
colors <- c(city = pal[8], covered = pal[1], uncovered = pal[7])
x_limits <- range(city_series$date)
quarter_ticks <- seq(min(city_series$date), max(city_series$date),
                     by = "3 months")

draw_panel <- function(y_values, main, y_limits) {
    plot(x_limits, y_limits, type = "n", axes = FALSE, xlab = "", ylab = "",
         main = main)
    rect(policy_date, par("usr")[3], as.Date("2026-01-01"), par("usr")[4],
         col = grDevices::adjustcolor("gray80", alpha.f = 0.45), border = NA)
    abline(v = policy_date, lty = 2, col = "gray35")
    axis.Date(1, at = quarter_ticks, format = "%b\n%Y", cex.axis = 0.8)
    y_ticks <- pretty(y_limits)
    axis(2, at = y_ticks, labels = format(y_ticks, big.mark = ","), las = 2)
    box(bty = "l")
    mtext("Estimated workers", side = 2, line = 4)
    invisible(y_values)
}

pdf("figures/raw/EDD-LA-city-hotel-employment-allocated.pdf",
    width = 10, height = 8, useDingbats = FALSE)
par(mfrow = c(2, 1), mar = c(3.5, 5.5, 2.5, 1), oma = c(3, 0, 2, 0))

draw_panel(city_series$estimated_city_employment,
           "A. Total LA City hotel-industry employment",
           range(city_series$estimated_city_employment))
lines(city_series$date, city_series$estimated_city_employment,
      col = colors["city"], lwd = 2.5)

split_limits <- range(c(city_series$estimated_covered_employment,
                        city_series$estimated_uncovered_employment))
draw_panel(NULL, "B. Allocated by hotel coverage status", split_limits)
lines(city_series$date, city_series$estimated_covered_employment,
      col = colors["covered"], lwd = 2.5)
lines(city_series$date, city_series$estimated_uncovered_employment,
      col = colors["uncovered"], lwd = 2.5)
legend("center", legend = c("Covered LA hotels", "Uncovered LA hotels"),
       col = colors[c("covered", "uncovered")], lwd = 2.5,
       bty = "n", cex = 0.9)

mtext("Estimated private NAICS 7211 employment in LA City hotels",
      side = 3, outer = TRUE, line = 0.4, cex = 1.1)
mtext(paste0("EDD PUMA employment allocated by current room shares held fixed ",
             "across 2023-25; ", length(balanced_pumas),
             " reported PUMAs; gray area begins Sep 2025"),
      side = 1, outer = TRUE, line = 1.2, cex = 0.72)
dev.off()
