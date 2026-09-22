# Monthly EDD employment in the 2020 PUMA containing Los Angeles International
# Airport. The plotted industries are private scheduled air transportation
# (NAICS 4811) and private support activities for air transportation (4881).

source("script/0-config.R")

policy_date <- as.Date("2025-09-01")
lax_puma <- "3748"
lax_puma_name_pattern <- "Southwest/Marina del Rey"

emp <- readRDS(file.path(clean_path, "edd_emp_monthly.rds"))

# PUMA 3748 contains LAX under the 2020 PUMA definitions used by EDD. Confirm
# both its name and that the two private airport-industry series are complete.
lax <- emp |>
    dplyr::filter(
        puma == lax_puma,
        naics4 %in% c("4811", "4881"),
        ownership_code == 5
    ) |>
    dplyr::mutate(
        industry_short = dplyr::recode(
            naics4,
            "4811" = "Scheduled air transportation",
            "4881" = "Support activities for air transportation"
        )
    )

stopifnot(nrow(lax) == 72,
          all(grepl(lax_puma_name_pattern, lax$puma_name)),
          !any(lax$employment_suppressed),
          !any(is.na(lax$employment)),
          all(dplyr::count(lax, naics4)$n == 36))

airport_total <- lax |>
    dplyr::group_by(date) |>
    dplyr::summarise(employment = sum(employment), .groups = "drop") |>
    dplyr::mutate(naics4 = "total",
                  industry_short = "Combined airport industries")
airport <- dplyr::bind_rows(
    dplyr::select(lax, date, naics4, industry_short, employment),
    airport_total
) |>
    dplyr::arrange(naics4, date) |>
    dplyr::group_by(naics4) |>
    dplyr::mutate(yoy_percent = 100 * (employment / dplyr::lag(employment, 12) - 1)) |>
    dplyr::ungroup()

dir.create("output", recursive = TRUE, showWarnings = FALSE)
dir.create("figures/raw", recursive = TRUE, showWarnings = FALSE)
utils::write.csv(airport, "output/EDD-LAX-PUMA-employment-series.csv",
                 row.names = FALSE)

colors <- c("4811" = "#35618F", "4881" = "#D0802F", "total" = "#A62C2B")
line_widths <- c("4811" = 1.5, "4881" = 1.5, "total" = 2.5)
series_order <- c("total", "4811", "4881")
series_labels <- c(
    "total" = "Combined 4811 + 4881",
    "4811" = "4811 Scheduled air transportation",
    "4881" = "4881 Support activities"
)

pdf("figures/raw/EDD-LAX-PUMA-airport-employment.pdf", width = 9, height = 8,
    useDingbats = FALSE)
par(mfrow = c(2, 1), mar = c(3.5, 5, 2.5, 1), oma = c(2, 0, 2, 0))

# Employment levels ------------------------------------------------------
level_ylim <- range(airport$employment)
plot(range(airport$date), level_ylim, type = "n", axes = FALSE,
     xlab = "", ylab = "Employment", main = "Monthly employment levels")
rect(policy_date, par("usr")[3], as.Date("2026-01-01"), par("usr")[4],
     col = grDevices::adjustcolor("gray80", alpha.f = 0.45), border = NA)
for (series in series_order) {
    d <- dplyr::filter(airport, naics4 == series)
    lines(d$date, d$employment, col = colors[series], lwd = line_widths[series])
}
axis.Date(1, at = seq(min(airport$date), max(airport$date), by = "3 months"),
          format = "%b\n%Y")
axis(2, at = pretty(level_ylim), labels = format(pretty(level_ylim), big.mark = ","),
     las = 2)
abline(v = policy_date, lty = 2)
legend("topleft", legend = series_labels[series_order],
       col = colors[series_order], lwd = line_widths[series_order],
       bty = "n", cex = 0.8)

# Year-over-year changes -------------------------------------------------
yoy <- dplyr::filter(airport, !is.na(yoy_percent))
yoy_ylim <- range(yoy$yoy_percent)
plot(range(yoy$date), yoy_ylim, type = "n", axes = FALSE,
     xlab = "", ylab = "Year-over-year change (%)",
     main = "Year-over-year employment change")
rect(policy_date, par("usr")[3], as.Date("2026-01-01"), par("usr")[4],
     col = grDevices::adjustcolor("gray80", alpha.f = 0.45), border = NA)
abline(h = 0, col = "gray70", lty = 3)
for (series in series_order) {
    d <- dplyr::filter(yoy, naics4 == series)
    lines(d$date, d$yoy_percent, col = colors[series], lwd = line_widths[series])
}
axis.Date(1, at = seq(min(yoy$date), max(yoy$date), by = "3 months"),
          format = "%b\n%Y")
axis(2, las = 2)
abline(v = policy_date, lty = 2)

mtext("Private airport-industry employment in the PUMA containing LAX",
      side = 3, outer = TRUE, line = 0.4, cex = 1.15)
mtext("PUMA 3748 | Gray area begins September 2025 | Source: California EDD",
      side = 1, outer = TRUE, line = 0.5, cex = 0.75)
dev.off()

print(airport |>
          dplyr::filter(date >= policy_date) |>
          dplyr::select(date, naics4, industry_short, employment, yoy_percent))

# LAX versus Burbank PUMA comparison ------------------------------------
# Use identical colors for industries and line type to distinguish place.
comparison_pumas <- c("3748" = "LAX PUMA 3748",
                      "3720" = "Burbank PUMA 3720")
comparison <- emp |>
    dplyr::filter(puma %in% names(comparison_pumas),
                  naics4 %in% c("4811", "4881"), ownership_code == 5) |>
    dplyr::mutate(
        puma_label = unname(comparison_pumas[puma]),
        industry_short = dplyr::recode(
            naics4,
            "4811" = "Scheduled air transportation",
            "4881" = "Support activities for air transportation"
        )
    )
stopifnot(nrow(comparison) == 144,
          !any(comparison$employment_suppressed),
          !any(is.na(comparison$employment)))

comparison_total <- comparison |>
    dplyr::group_by(puma, puma_label, date) |>
    dplyr::summarise(employment = sum(employment), .groups = "drop") |>
    dplyr::mutate(naics4 = "total",
                  industry_short = "Combined airport industries")
comparison <- dplyr::bind_rows(
    dplyr::select(comparison, puma, puma_label, date, naics4,
                  industry_short, employment),
    comparison_total
) |>
    dplyr::arrange(puma, naics4, date) |>
    dplyr::group_by(puma, naics4) |>
    dplyr::mutate(yoy_percent = 100 *
                      (employment / dplyr::lag(employment, 12) - 1)) |>
    dplyr::ungroup()
utils::write.csv(comparison, "output/EDD-LAX-vs-Burbank-PUMA-employment-series.csv",
                 row.names = FALSE)

puma_line_types <- c("LAX PUMA 3748" = 1, "Burbank PUMA 3720" = 3)
pdf("figures/raw/EDD-LAX-vs-Burbank-PUMA-airport-employment.pdf",
    width = 10, height = 8, useDingbats = FALSE)
par(mfrow = c(2, 1), mar = c(3.5, 5, 2.5, 1), oma = c(2, 0, 2, 0))

comparison_ylim <- range(comparison$employment)
plot(range(comparison$date), comparison_ylim, type = "n", axes = FALSE,
     xlab = "", ylab = "Employment", main = "Monthly employment levels")
rect(policy_date, par("usr")[3], as.Date("2026-01-01"), par("usr")[4],
     col = grDevices::adjustcolor("gray80", alpha.f = 0.45), border = NA)
for (place in names(puma_line_types)) {
    for (series in series_order) {
        d <- dplyr::filter(comparison, puma_label == place, naics4 == series)
        lines(d$date, d$employment, col = colors[series],
              lwd = line_widths[series], lty = puma_line_types[place])
    }
}
axis.Date(1, at = seq(min(comparison$date), max(comparison$date), by = "3 months"),
          format = "%b\n%Y")
axis(2, at = pretty(comparison_ylim),
     labels = format(pretty(comparison_ylim), big.mark = ","), las = 2)
abline(v = policy_date, lty = 2)
legend("topleft", legend = series_labels[series_order],
       col = colors[series_order], lwd = line_widths[series_order],
       lty = 1, bty = "n", cex = 0.76)
legend("left", legend = names(puma_line_types), col = "black", lwd = 1.8,
       lty = puma_line_types, bty = "n", cex = 0.76)

comparison_yoy <- dplyr::filter(comparison, !is.na(yoy_percent))
comparison_yoy_ylim <- range(comparison_yoy$yoy_percent)
plot(range(comparison_yoy$date), comparison_yoy_ylim, type = "n", axes = FALSE,
     xlab = "", ylab = "Year-over-year change (%)",
     main = "Year-over-year employment change")
rect(policy_date, par("usr")[3], as.Date("2026-01-01"), par("usr")[4],
     col = grDevices::adjustcolor("gray80", alpha.f = 0.45), border = NA)
abline(h = 0, col = "gray70", lty = 3)
for (place in names(puma_line_types)) {
    for (series in series_order) {
        d <- dplyr::filter(comparison_yoy,
                           puma_label == place, naics4 == series)
        lines(d$date, d$yoy_percent, col = colors[series],
              lwd = line_widths[series], lty = puma_line_types[place])
    }
}
axis.Date(1, at = seq(min(comparison_yoy$date), max(comparison_yoy$date),
                      by = "3 months"), format = "%b\n%Y")
axis(2, las = 2)
abline(v = policy_date, lty = 2)

mtext("Private airport-industry employment: LAX versus Burbank PUMA",
      side = 3, outer = TRUE, line = 0.4, cex = 1.15)
mtext("Solid: PUMA 3748 (LAX) | Dotted: PUMA 3720 (Burbank) | Gray area begins September 2025",
      side = 1, outer = TRUE, line = 0.5, cex = 0.72)
dev.off()
