# Preliminary EDD hotel-employment regressions using PUMA treatment exposure.
# These are work-in-progress estimates with only four post-policy months.

source("script/0-config.R")

policy_date <- as.Date("2025-09-01")
reference_date <- as.Date("2025-08-01")

emp <- readRDS(file.path(clean_path, "edd_emp_monthly.rds"))
exposure <- readRDS(file.path(clean_path,
                              "puma_treated_room_share_countywide.rds"))

# Private traveler-accommodation employment is the hotel-sector outcome.
hotel <- emp |>
    dplyr::filter(naics4 == "7211", ownership_code == 5) |>
    dplyr::left_join(
        dplyr::select(exposure, puma, treated_room_share, total_rooms,
                      intersects_la_city),
        by = "puma"
    ) |>
    dplyr::mutate(
        post = date >= policy_date,
        post_exposure = treated_room_share * as.numeric(post),
        asinh_employment = asinh(employment),
        log_employment = ifelse(employment > 0, log(employment), NA_real_)
    )

stopifnot(!any(is.na(hotel$treated_room_share)),
          all(is.na(hotel$employment) == hotel$employment_suppressed),
          min(hotel$date) == as.Date("2023-01-01"),
          max(hotel$date) == as.Date("2025-12-01"))

# Balanced-panel sensitivity: require a reported value in all 36 months.
puma_coverage <- hotel |>
    dplyr::group_by(puma) |>
    dplyr::summarise(observed_months = sum(!is.na(employment)), .groups = "drop")
hotel <- dplyr::left_join(hotel, puma_coverage, by = "puma")
hotel_balanced <- dplyr::filter(hotel, observed_months == 36)

# Continuous-exposure difference-in-differences on a fixed set of PUMAs. A
# coefficient corresponds to moving from zero to 100% treated rooms; scale by
# 0.5 for a 50 percentage-point contrast.
models <- list(
    "Asinh employment: balanced PUMAs" = fixest::feols(
        asinh_employment ~ post_exposure | puma + date,
        cluster = ~puma, data = hotel_balanced
    ),
    "Log employment: balanced PUMAs" = fixest::feols(
        log_employment ~ post_exposure | puma + date,
        cluster = ~puma, data = hotel_balanced
    ),
    "Employment level: balanced PUMAs" = fixest::feols(
        employment ~ post_exposure | puma + date,
        cluster = ~puma, data = hotel_balanced
    )
)

# Quarterly outcomes. Q4 2025 is the sole post-policy quarter, so these are
# exploratory. Quarterly wages per worker divide total quarterly wages by the
# corresponding average monthly employment; the result is quarterly, not
# annualized, earnings per worker.
qtr <- readRDS(file.path(clean_path, "edd_qtr_panel.rds")) |>
    dplyr::filter(naics4 == "7211", ownership_code == 5) |>
    dplyr::left_join(
        dplyr::select(exposure, puma, treated_room_share), by = "puma"
    ) |>
    dplyr::semi_join(dplyr::distinct(hotel_balanced, puma), by = "puma")

qtr_employment <- hotel_balanced |>
    dplyr::mutate(quarter = (month - 1L) %/% 3L + 1L,
                  quarter_date = as.Date(sprintf("%d-%02d-01", year,
                                                 3L * quarter - 2L))) |>
    dplyr::group_by(puma, quarter_date) |>
    dplyr::summarise(avg_monthly_employment = mean(employment), .groups = "drop")
qtr <- qtr |>
    dplyr::left_join(qtr_employment, by = c("puma", "quarter_date")) |>
    dplyr::mutate(
        post_exposure = treated_room_share *
            as.numeric(quarter_date >= as.Date("2025-10-01")),
        wages_per_worker = wages / avg_monthly_employment,
        asinh_wages = asinh(wages),
        log_wages = ifelse(wages > 0, log(wages), NA_real_),
        log_wages_per_worker = ifelse(wages_per_worker > 0,
                                      log(wages_per_worker), NA_real_)
    )
stopifnot(all(!is.na(qtr$wages)), all(!is.na(qtr$establishments)),
          all(!is.na(qtr$avg_monthly_employment)))

models <- c(models, list(
    "Asinh quarterly wages: balanced PUMAs" = fixest::feols(
        asinh_wages ~ post_exposure | puma + quarter_date,
        cluster = ~puma, data = qtr
    ),
    "Log quarterly wages: balanced PUMAs" = fixest::feols(
        log_wages ~ post_exposure | puma + quarter_date,
        cluster = ~puma, data = qtr
    ),
    "Establishments: balanced PUMAs" = fixest::feols(
        establishments ~ post_exposure | puma + quarter_date,
        cluster = ~puma, data = qtr
    ),
    "Log quarterly wages per worker: balanced PUMAs" = fixest::feols(
        log_wages_per_worker ~ post_exposure | puma + quarter_date,
        cluster = ~puma, data = qtr
    )
))

extract_result <- function(model, specification, pumas) {
    ct <- fixest::coeftable(model)
    term <- "post_exposure"
    stopifnot(term %in% rownames(ct))
    data.frame(
        specification = specification,
        term = term,
        estimate = unname(ct[term, "Estimate"]),
        std_error = unname(ct[term, "Std. Error"]),
        p_value = unname(ct[term, "Pr(>|t|)"]),
        conf_low = unname(ct[term, "Estimate"] - 1.96 * ct[term, "Std. Error"]),
        conf_high = unname(ct[term, "Estimate"] + 1.96 * ct[term, "Std. Error"]),
        observations = stats::nobs(model),
        pumas = pumas,
        stringsAsFactors = FALSE
    )
}
model_pumas <- rep(dplyr::n_distinct(hotel_balanced$puma), length(models))
results <- dplyr::bind_rows(Map(extract_result, models, names(models),
                                model_pumas)) |>
    dplyr::mutate(
        effect_for_50pp_exposure = 0.5 * estimate,
        approximate_percent_for_50pp = dplyr::if_else(
            grepl("Asinh|Log", specification),
            100 * (exp(0.5 * estimate) - 1), NA_real_
        ),
        approximate_percent_low_50pp = dplyr::if_else(
            grepl("Asinh|Log", specification),
            100 * (exp(0.5 * conf_low) - 1), NA_real_
        ),
        approximate_percent_high_50pp = dplyr::if_else(
            grepl("Asinh|Log", specification),
            100 * (exp(0.5 * conf_high) - 1), NA_real_
        )
    )

dir.create("output", recursive = TRUE, showWarnings = FALSE)
dir.create("figures/raw", recursive = TRUE, showWarnings = FALSE)
utils::write.csv(results, "output/EDD-hotel-regression-results.csv",
                 row.names = FALSE)
saveRDS(models, file.path(clean_path, "edd_hotel_regression_models.rds"))
print(results)

# Compact presentation figure for percentage-scale outcomes.
coefficient_plot <- results |>
    dplyr::filter(specification %in% c(
        "Asinh employment: balanced PUMAs",
        "Asinh quarterly wages: balanced PUMAs",
        "Log quarterly wages per worker: balanced PUMAs"
    )) |>
    dplyr::mutate(
        label = dplyr::recode(
            specification,
            "Asinh employment: balanced PUMAs" = "Monthly employment",
            "Asinh quarterly wages: balanced PUMAs" = "Quarterly total wages",
            "Log quarterly wages per worker: balanced PUMAs" =
                "Quarterly wages per worker"
        ),
        y = dplyr::row_number()
    )
pdf("figures/raw/EDD-hotel-regression-coefficients.pdf", width = 9.5, height = 5,
    useDingbats = FALSE)
par(mar = c(6.5, 12, 4.5, 1.5))
plot(NA, xlim = range(c(coefficient_plot$approximate_percent_low_50pp,
                        coefficient_plot$approximate_percent_high_50pp, 0)),
     ylim = c(0.5, nrow(coefficient_plot) + 0.5), axes = FALSE,
     xlab = "Estimated change for 50 percentage-point greater exposure (%)",
     ylab = "")
abline(v = 0, col = "gray60", lty = 2)
segments(coefficient_plot$approximate_percent_low_50pp, coefficient_plot$y,
         coefficient_plot$approximate_percent_high_50pp, coefficient_plot$y,
         lwd = 2, col = "gray40")
points(coefficient_plot$approximate_percent_for_50pp, coefficient_plot$y,
       pch = 16, cex = 1.3, col = "#A62C2B")
axis(1)
axis(2, at = coefficient_plot$y, labels = coefficient_plot$label,
     las = 1, tick = FALSE)
title("Preliminary continuous-exposure estimates", line = 1.2)
mtext("PUMA and period fixed effects; PUMA-clustered 95% confidence intervals",
      side = 3, line = 0, cex = 0.8)
mtext("Quarterly outcomes have only one post-policy quarter.",
      side = 1, line = 5, cex = 0.75)
dev.off()

# Descriptive indexed trends. Restrict to balanced PUMAs so changing EDD
# suppression does not mechanically change group composition over time.
trend <- hotel_balanced |>
    dplyr::group_by(puma) |>
    dplyr::mutate(
        pre_mean = mean(employment[date >= as.Date("2025-01-01") &
                                   date < policy_date]),
        employment_index = 100 * employment / pre_mean,
        exposure_group = ifelse(treated_room_share > 0,
                                "Positive treated-room exposure", "Zero exposure")
    ) |>
    dplyr::ungroup() |>
    dplyr::group_by(date, exposure_group) |>
    dplyr::summarise(index = mean(employment_index), pumas = dplyr::n(),
                     .groups = "drop")

plot_colors <- c("Positive treated-room exposure" = "#A62C2B",
                 "Zero exposure" = "#35618F")
pdf("figures/raw/EDD-hotel-employment-index.pdf", width = 9, height = 5.5,
    useDingbats = FALSE)
plot(range(trend$date), range(trend$index), type = "n", xlab = "", ylab = "",
     axes = FALSE)
rect(policy_date, par("usr")[3], as.Date("2026-01-01"), par("usr")[4],
     col = grDevices::adjustcolor("gray80", alpha.f = 0.45), border = NA)
abline(h = 100, col = "gray70", lty = 3)
abline(v = policy_date, lty = 2)
for (g in names(plot_colors)) {
    d <- dplyr::filter(trend, exposure_group == g)
    lines(d$date, d$index, col = plot_colors[g], lwd = 2)
}
axis.Date(1, at = seq(min(trend$date), max(trend$date), by = "3 months"),
          format = "%b\n%Y")
axis(2, las = 2)
mtext("Employment index (Jan-Aug 2025 average = 100)", side = 2, line = 3)
title("Private traveler-accommodation employment by PUMA exposure")
legend("topleft", legend = names(plot_colors), col = plot_colors,
       lwd = 2, bty = "n")
mtext("Balanced PUMAs; unweighted PUMA means. Gray area begins September 2025.",
      side = 1, line = 3.2, cex = 0.75)
dev.off()

# Indexed quarterly trends for presentation. Each PUMA is normalized to its
# own 2023 Q1-2025 Q3 mean before taking unweighted group averages.
qtr_trend <- qtr |>
    dplyr::mutate(
        exposure_group = ifelse(treated_room_share > 0,
                                "Positive treated-room exposure", "Zero exposure")
    ) |>
    dplyr::group_by(puma) |>
    dplyr::mutate(
        wages_index = 100 * wages / mean(wages[quarter_date < as.Date("2025-10-01")]),
        establishments_index = 100 * establishments /
            mean(establishments[quarter_date < as.Date("2025-10-01")]),
        wage_per_worker_index = 100 * wages_per_worker /
            mean(wages_per_worker[quarter_date < as.Date("2025-10-01")])
    ) |>
    dplyr::ungroup() |>
    tidyr::pivot_longer(
        c(wages_index, establishments_index, wage_per_worker_index),
        names_to = "outcome", values_to = "index"
    ) |>
    dplyr::group_by(quarter_date, exposure_group, outcome) |>
    dplyr::summarise(index = mean(index), .groups = "drop")

outcome_titles <- c(wages_index = "Total quarterly wages",
                    establishments_index = "Establishments",
                    wage_per_worker_index = "Quarterly wages per worker")
pdf("figures/raw/EDD-hotel-quarterly-outcomes-index.pdf", width = 10, height = 8,
    useDingbats = FALSE)
par(mfrow = c(3, 1), mar = c(2.5, 4.5, 2.5, 1), oma = c(2, 0, 1, 0))
for (outcome_name in names(outcome_titles)) {
    d <- dplyr::filter(qtr_trend, outcome == outcome_name)
    plot(range(d$quarter_date), range(d$index), type = "n", axes = FALSE,
         xlab = "", ylab = "Index", main = outcome_titles[outcome_name])
    rect(as.Date("2025-10-01"), par("usr")[3], as.Date("2026-01-01"),
         par("usr")[4], col = grDevices::adjustcolor("gray80", alpha.f = 0.45),
         border = NA)
    abline(h = 100, col = "gray70", lty = 3)
    for (g in names(plot_colors)) {
        dg <- dplyr::filter(d, exposure_group == g)
        lines(dg$quarter_date, dg$index, col = plot_colors[g], lwd = 2)
    }
    quarter_ticks <- sort(unique(d$quarter_date))
    quarter_labels <- paste(format(quarter_ticks, "%Y"),
                            paste0("Q", (as.integer(format(quarter_ticks, "%m")) - 1L) %/% 3L + 1L))
    axis.Date(1, at = quarter_ticks, labels = quarter_labels, cex.axis = 0.7)
    axis(2, las = 2)
    if (outcome_name == names(outcome_titles)[1]) {
        legend("topleft", legend = names(plot_colors), col = plot_colors,
               lwd = 2, bty = "n", cex = 0.8)
    }
}
mtext("Balanced PUMAs; pre-policy PUMA average = 100. Gray area is 2025 Q4.",
      side = 1, outer = TRUE, line = 0.5, cex = 0.75)
dev.off()

# Monthly continuous-exposure event study. Month fixed effects absorb common
# shocks; August 2025 is the omitted reference month.
event_model <- fixest::feols(
    asinh_employment ~ i(date, treated_room_share, ref = reference_date) |
        puma + date,
    cluster = ~puma, data = hotel_balanced
)
saveRDS(event_model, file.path(clean_path, "edd_hotel_event_study_model.rds"))
pretrend_long <- fixest::wald(event_model, keep = "date::202[34]", print = FALSE)
pretrend_2025 <- fixest::wald(event_model, keep = "date::2025-0[1-7]", print = FALSE)

pdf("figures/raw/EDD-hotel-employment-event-study.pdf", width = 14, height = 5.5,
    useDingbats = FALSE)
fixest::iplot(
    event_model, ref.line = 0, ci.width = 0,
    main = "Hotel employment and treated-room exposure",
    xlab = "Month (August 2025 omitted)",
    ylab = "Coefficient on treated-room share"
)
dev.off()

cat("\nWork-in-progress caveats:\n",
    "- Only September-December 2025 are post-policy.\n",
    "- Suppressed employment cells remain missing, never zero.\n",
    "- Exposure is based on hotel rooms, not the share of workers covered.\n",
    "- Joint pre-trend p-value (2023-2024): ",
    format(pretrend_long$p, digits = 3), ".\n",
    "- Joint pre-trend p-value (Jan-Jul 2025): ",
    format(pretrend_2025$p, digits = 3), ".\n",
    "- The five newly identified treated hotels and their reviewed subgroup",
    " assignments are included in the PUMA exposure measure.\n", sep = "")
