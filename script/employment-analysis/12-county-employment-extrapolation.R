# Review figures: PUMA-based history plus explicitly extrapolated Jan-Mar 2026.
# County QCEW private employment, same four-digit NAICS, same calendar month.
# Inputs: official EDD CSV downloads; saved outputs from scripts 10 and 11.
# These estimates are descriptive and never enter the policy regressions.
source("script/0-config.R")
suppressPackageStartupMessages(library(data.table))
setDTthreads(2)
dir.create(edd_extrapolation_path, recursive = TRUE, showWarnings = FALSE)

# Official downloads are retained unchanged for reproducibility.
files <- file.path(qcew_county_path, c("qcew-2023-2025q4.csv", "qcew-2026-q1.csv"))
urls <- c(
    "https://data.ca.gov/dataset/3f08b68e-1d1a-4ba4-a07d-1ec3392ed191/resource/119eef38-3b59-499f-8f7c-9bea4768469d/download/qcew-2023-2025q4.csv",
    "https://data.ca.gov/dataset/3f08b68e-1d1a-4ba4-a07d-1ec3392ed191/resource/a8d3fd99-c666-4311-8902-dc95cda62ac6/download/qcew-2026-q1.csv")
dir.create(qcew_county_path, recursive = TRUE, showWarnings = FALSE)
for (i in seq_along(files)) {
    if (!file.exists(files[i])) download.file(urls[i], files[i], mode = "wb")
}
stopifnot(all(file.exists(files)))
county <- rbindlist(lapply(files, fread))
county <- county[`Area Type` == "County" & `Area Name` == "Los Angeles County" &
                 Ownership == "Private" & `NAICS Level` == 4 &
                 `NAICS Code` %in% c("7211", "4811", "4881") &
                 `Time Period` %in% c("1st Qtr", "2nd Qtr", "3rd Qtr", "4th Qtr")]
county[, quarter := match(`Time Period`, c("1st Qtr", "2nd Qtr", "3rd Qtr", "4th Qtr"))]
county <- melt(county, id.vars = c("Year", "quarter", "NAICS Code"),
               measure.vars = c("1st Month Emp", "2nd Month Emp", "3rd Month Emp"),
               variable.name = "month_in_quarter", value.name = "county_employment")
county[, date := as.Date(sprintf("%d-%02d-01", Year,
                  3L * (quarter - 1L) + as.integer(month_in_quarter)))]
setnames(county, "NAICS Code", "naics4")
county <- county[, .(date, naics4, county_employment)]
setorder(county, naics4, date)
stopifnot(nrow(county) == 117, !anyDuplicated(county[, .(date, naics4)]),
          all(is.finite(county$county_employment) & county$county_employment > 0))
expected_dates <- seq(as.Date("2023-01-01"), as.Date("2026-03-01"), by = "month")
for (industry in unique(county$naics4)) {
    stopifnot(identical(county[naics4 == industry]$date, expected_dates))
}
county[, county_prior := shift(county_employment, 12), by = naics4]
county[, growth_factor := county_employment / county_prior]
fwrite(county, file.path(edd_extrapolation_path, "county-monthly.csv"))

# Benchmark all reported PUMAs and the fixed 36-month reporting panel separately.
puma <- as.data.table(readRDS(file.path(clean_path, "edd_emp_monthly.rds")))
puma <- puma[ownership_code == 5 & naics4 %in% c("7211", "4811", "4881")]
stopifnot(!anyDuplicated(puma[, .(puma, naics4, date)]))
complete <- puma[, .(complete = sum(!is.na(employment)) == 36), by = .(puma, naics4)]
puma <- merge(puma, complete, by = c("puma", "naics4"))
coverage <- puma[, .(reported_employment = sum(employment, na.rm = TRUE),
                     balanced_employment = sum(employment[complete], na.rm = TRUE),
                     reported_pumas = sum(!is.na(employment)),
                     suppressed_rows = sum(is.na(employment))), by = .(date, naics4)]
coverage <- merge(coverage, county, by = c("date", "naics4"))
coverage[, `:=`(reported_share = reported_employment / county_employment,
                balanced_share = balanced_employment / county_employment,
                county_minus_reported = county_employment - reported_employment)]
fwrite(coverage, file.path(edd_extrapolation_path, "puma-county-coverage.csv"))

# Retain the existing local history; do not imply that hotel allocations are observed jobs.
hotel <- fread("output/EDD-LA-city-hotel-employment-allocated-monthly.csv")
airport <- fread("output/EDD-LAX-PUMA-employment-series.csv")
history <- rbindlist(list(
    hotel[, .(date = as.Date(date), naics4 = "7211", employment = estimated_city_employment)],
    airport[naics4 %in% c("4811", "4881"), .(date = as.Date(date), naics4, employment)]))
stopifnot(nrow(history) == 108, max(history$date) == as.Date("2025-12-01"))
history[, status := "PUMA-based"]
future <- county[date >= as.Date("2026-01-01")]
future[, prior_date := as.Date(sprintf("2025-%s", format(date, "%m-%d")))]
future <- merge(future, history[, .(prior_date = date, naics4, local_prior = employment)],
                by = c("prior_date", "naics4"))
future[, `:=`(employment = local_prior * growth_factor, status = "County-growth extrapolation")]
stopifnot(nrow(future) == 9, all(is.finite(future$employment)),
          all(future$date <= as.Date("2026-03-01")))
fwrite(future, file.path(edd_extrapolation_path, "extrapolation-calculations.csv"))
local <- rbindlist(list(history, future[, .(date, naics4, employment, status)]))
# Sum separately extrapolated airline/support series rather than applying one pooled growth factor.
airport_total <- local[naics4 %in% c("4811", "4881"),
    .(employment = sum(employment)), by = .(date, status)]
airport_total[, naics4 := "airport_total"]
local <- rbindlist(list(local, airport_total), use.names = TRUE)
setorder(local, naics4, date)
local[, yoy_percent := 100 * (employment / shift(employment, 12) - 1), by = naics4]
stopifnot(nrow(local) == 156, all(local[, .N, by = naics4]$N == 39))
fwrite(local, file.path(edd_extrapolation_path, "local-monthly-history-and-extrapolation.csv"))
# Check the growth assumption directly for each underlying industry.
check <- merge(local[date >= as.Date("2026-01-01") & naics4 != "airport_total"],
               county, by = c("date", "naics4"))
stopifnot(max(abs(check$yoy_percent - 100 * (check$growth_factor - 1))) < 1e-8)

# A common figure design makes the observation/extrapolation boundary explicit.
policy_date <- as.Date("2025-09-01")
last_observed <- as.Date("2025-12-01")
forecast_boundary <- as.Date("2025-12-16")
x_limits <- as.Date(c("2023-01-01", "2026-03-01"))
ticks <- c(seq(x_limits[1], as.Date("2026-01-01"), by = "6 months"), x_limits[2])
plot_series <- function(d, value, title, ylab, color = "#8C2D19") {
    d <- d[is.finite(get(value))]
    y <- d[[value]]
    panel_limits <- c(min(d$date), max(x_limits))
    panel_ticks <- ticks[ticks >= panel_limits[1]]
    yr <- range(y, if (value == "yoy_percent") 0 else y)
    pad <- max(diff(yr) * .15, .1)
    plot(d$date, y, type = "n", axes = FALSE, xlim = panel_limits,
         ylim = yr + c(-pad, pad), xlab = "", ylab = ylab, main = title)
    rect(policy_date, par("usr")[3], max(x_limits), par("usr")[4],
         col = "#F2F2F2", border = NA)
    rect(forecast_boundary, par("usr")[3], max(x_limits), par("usr")[4],
         col = "#E5EDF5", border = NA)
    abline(v = policy_date, lty = 3, col = "grey50")
    abline(v = forecast_boundary, lty = 3, col = "#35618F")
    if (value == "yoy_percent") abline(h = 0, col = "grey60", lty = 2)
    h <- d$date <= last_observed
    f <- d$date >= last_observed
    lines(d$date[h], y[h], col = color, lwd = 2)
    lines(d$date[f], y[f], col = color, lwd = 2.5, lty = 3)
    points(d$date[!h], y[!h], col = color, pch = 1, cex = 1.1)
    axis.Date(1, at = panel_ticks, format = "%b\n%Y", cex.axis = .75)
    axis(2, las = 1)
    legend("topleft", c("PUMA-based history", "County-growth extrapolation"),
           col = color, lty = c(1, 3), lwd = 2, bty = "n", cex = .75)
}

for (outcome in c("employment", "yoy_percent")) {
    filename <- if (outcome == "employment") "employment-totals.pdf" else "employment-yoy.pdf"
    pdf(file.path(edd_extrapolation_path, filename), width = 10, height = 9, useDingbats = FALSE)
    par(mfrow = c(2, 1), mar = c(4, 5, 3, 1), oma = c(3, 0, 0, 0))
    for (sector in c("7211", "airport_total")) {
        d <- local[naics4 == sector]
        title <- if (sector == "7211") "LA City hotels: room-share allocated estimate" else "LAX-area PUMA: scheduled air transport + support activities"
        if (outcome == "employment") d[, employment := employment / 1000]
        plot_series(d, outcome, title, if (outcome == "employment") "Jobs (thousands)" else "Year-over-year change (%)")
    }
    mtext("Gray: policy period from Sep 2025. Blue: Jan-Mar 2026 extrapolation using county YoY growth.",
          side = 1, outer = TRUE, line = .3, cex = .75)
    mtext("Hotels: fixed room shares and reporting-PUMA coverage; airport: area/industry proxy. Not policy-effect estimates.",
          side = 1, outer = TRUE, line = 1.5, cex = .7)
    dev.off()
}

pdf(file.path(edd_extrapolation_path, "airport-industry-detail.pdf"), width = 10, height = 9, useDingbats = FALSE)
par(mfrow = c(2, 1), mar = c(4, 5, 3, 1), oma = c(2, 0, 0, 0))
for (industry in c("4811", "4881")) {
    d <- local[naics4 == industry]; d[, employment := employment / 1000]
    plot_series(d, "employment", if (industry == "4811") "Scheduled air transportation (4811)" else "Support activities for air transportation (4881)", "Jobs (thousands)")
}
mtext("LAX-area PUMA 3748. Each industry's Jan-Mar 2026 values use its own LA County YoY growth.", side = 1, outer = TRUE, cex = .75)
dev.off()

# Optional hotel split stops at observed PUMA coverage; no artificial split forecast.
pdf(file.path(edd_extrapolation_path, "hotel-covered-uncovered.pdf"), width = 10, height = 6, useDingbats = FALSE)
par(mar = c(4, 5, 3, 1), oma = c(2, 0, 0, 0))
hotel[, date := as.Date(date)]
ref <- hotel[date == as.Date("2025-08-01")]
hotel[, covered_index := 100 * estimated_covered_employment / ref$estimated_covered_employment]
hotel[, uncovered_index := 100 * estimated_uncovered_employment / ref$estimated_uncovered_employment]
plot(hotel$date, hotel$covered_index, type = "n", axes = FALSE,
     ylim = range(hotel$covered_index, hotel$uncovered_index), xlab = "",
     ylab = "Employment index (Aug 2025 = 100)", main = "LA City hotels: allocated covered and uncovered employment")
rect(policy_date, par("usr")[3], last_observed, par("usr")[4], col = "#F2F2F2", border = NA)
lines(hotel$date, hotel$covered_index, col = "#8C2D19", lwd = 2)
lines(hotel$date, hotel$uncovered_index, col = "#35618F", lwd = 2)
abline(v = policy_date, lty = 3)
axis.Date(1, at = c(seq(min(hotel$date), last_observed, by = "6 months"), last_observed), format = "%b\n%Y")
axis(2, las = 1)
legend("topleft", c("Allocated to covered hotels", "Allocated to uncovered hotels"), col = c("#8C2D19", "#35618F"), lty = 1, lwd = 2, bty = "n", cex = .8)
mtext("Through Dec 2025 only. Fixed room shares allocate PUMA jobs; these are not observed hotel-specific employment counts.", side = 1, outer = TRUE, cex = .7)
dev.off()
fwrite(hotel, file.path(edd_extrapolation_path, "hotel-allocation-split.csv"))

# County benchmark figure displays actual published county levels, not local estimates.
pdf(file.path(edd_extrapolation_path, "county-and-puma-coverage.pdf"), width = 10, height = 11, useDingbats = FALSE)
par(mfrow = c(3, 1), mar = c(4, 5, 3, 1), oma = c(2, 0, 0, 0))
for (industry in c("7211", "4811", "4881")) {
    c <- county[naics4 == industry]; p <- coverage[naics4 == industry][order(date)]
    title <- c("7211" = "Traveler accommodation", "4811" = "Scheduled air transportation", "4881" = "Air transportation support")[[industry]]
    plot(c$date, c$county_employment / 1000, type = "n", axes = FALSE,
         ylim = range(c$county_employment, p$reported_employment, p$balanced_employment) / 1000,
         xlab = "", ylab = "Jobs (thousands)", main = title)
    lines(c$date, c$county_employment / 1000, col = "black", lwd = 2)
    lines(p$date, p$reported_employment / 1000, col = "#35618F", lwd = 2)
    lines(p$date, p$balanced_employment / 1000, col = "#D0802F", lwd = 2, lty = 2)
    axis.Date(1, at = ticks, format = "%b\n%Y", cex.axis = .75); axis(2, las = 1)
    legend("topleft", c("Published LA County", "All reported PUMAs", "Fixed reporting panel"),
           col = c("black", "#35618F", "#D0802F"), lty = c(1, 1, 2), lwd = 2, bty = "n", cex = .7)
}
mtext("Private employment, matching NAICS. Gaps may reflect suppression, geographic assignment, or different data vintages.", side = 1, outer = TRUE, cex = .7)
dev.off()
print(future[, .(date, naics4, local_prior, growth_factor, employment)])
print(coverage[date == as.Date("2025-12-01"), .(naics4, reported_share, balanced_share, county_minus_reported)])
