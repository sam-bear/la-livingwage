# Explore workplace employment from the custom LA County EDD/QCEW extract.
# Run from the repository root after script/5-process-EDD.R.
# Clean inputs remain in OneDrive; maps are saved to figures/raw.

# Load clean panels ------------------------------------------------------
    source("script/0-config.R")
    emp_monthly <- readRDS(file.path(data_path, "clean", "edd_emp_monthly.rds"))
    qtr_panel <- readRDS(file.path(data_path, "clean", "edd_qtr_panel.rds"))

# Map settings: a single month and ownership avoids mixing coverage over time.
    map_date <- as.Date("2025-12-01")
    map_ownership <- 5L   # Private ownership
    map_industries <- c("4811", "4881", "7211")
    map_titles <- c("Scheduled air transportation",
                    "Support activities for air transportation",
                    "Traveler accommodation")

# Download Census boundaries through tigris; no Census API key is needed.
# The 2020 cartographic file contains the 2020 PUMA definitions matching EDD.
# Generalized boundaries are suitable for these maps, not city-boundary tests.
# Downloads use temporary storage rather than a machine-specific cache.
    ca_pumas <- tigris::pumas(state = "CA", year = 2020, cb = TRUE,
                             class = "sf", progress_bar = FALSE)
    la_pumas <- ca_pumas[grepl("Los Angeles County", ca_pumas$NAMELSAD20), ]
    la_pumas$puma <- as.character(as.integer(la_pumas$PUMACE20))
    la_pumas <- sf::st_transform(la_pumas, 3310)

# EDD omits the leading zero in Census PUMA codes. Check every code joins.
    stopifnot(nrow(la_pumas) == 71,
              !anyDuplicated(la_pumas$puma),
              all(emp_monthly$puma %in% la_pumas$puma))
    map_employment <- dplyr::filter(
        emp_monthly, date == map_date, ownership_code == map_ownership
    )
    stopifnot(nrow(map_employment) > 0,
              !anyDuplicated(map_employment[c("puma", "naics4")]))
    ownership_label <- unique(map_employment$ownership_title)
    stopifnot(length(ownership_label) == 1)

# Attach each industry's coverage to all county PUMAs, including absent rows.
# A missing EDD row is not evidence of zero employment.
    puma_coverage <- tidyr::expand_grid(puma = la_pumas$puma, naics4 = map_industries)
    map_employment$edd_row <- TRUE
    puma_coverage <- dplyr::left_join(
        puma_coverage,
        dplyr::select(map_employment, puma, naics4, employment,
                      employment_suppressed, edd_row),
        by = c("puma", "naics4")
    )
    puma_coverage <- dplyr::mutate(
        puma_coverage,
        coverage = dplyr::case_when(
            is.na(edd_row) ~ "No EDD row",
            employment_suppressed ~ "Suppressed",
            !is.na(employment) ~ "Reported",
            TRUE ~ "Other missing"
        )
    )
    stopifnot(!any(puma_coverage$coverage == "Other missing"))
    print(dplyr::count(puma_coverage, naics4, coverage))

# Three base R maps -------------------------------------------------------
# Coordinates are California Albers meters; omit coordinate labels for clarity.
# Plot mainland pieces only; islands remain in the underlying PUMA data.
    puma_parts <- suppressWarnings(sf::st_cast(la_pumas, "POLYGON"))
    part_centers <- sf::st_transform(sf::st_point_on_surface(sf::st_geometry(puma_parts)), 4326)
    mainland_parts <- puma_parts[sf::st_coordinates(part_centers)[, 2] > 33.5, ]
    map_bounds <- sf::st_bbox(mainland_parts)
    coverage_colors <- c("Reported" = "#238B45", "Suppressed" = "#FEC44F",
                         "No EDD row" = "gray90")
    dir.create("figures/raw", recursive = TRUE, showWarnings = FALSE)
    pdf("figures/raw/EDD-PUMA-employment-coverage.pdf", width = 14, height = 6)
    par(mfrow = c(1, 3), mar = c(1, 1, 3, 1), oma = c(3, 0, 2, 0))

    for (i in seq_along(map_industries)) {
        industry_coverage <- dplyr::filter(puma_coverage, naics4 == map_industries[i])
        puma_map <- dplyr::left_join(mainland_parts, industry_coverage, by = "puma")
        plot(sf::st_geometry(puma_map),
             col = coverage_colors[puma_map$coverage], border = "white", lwd = 0.5,
             xlim = map_bounds[c("xmin", "xmax")],
             ylim = map_bounds[c("ymin", "ymax")],
             axes = FALSE, main = paste(map_industries[i], map_titles[i], sep = "\n"))
        axis(1, labels = FALSE, tick = FALSE)
        axis(2, labels = FALSE, tick = FALSE)
        legend("bottomleft", legend = names(coverage_colors),
               fill = coverage_colors, border = NA, bty = "n", cex = 0.8)
    }
    mtext(paste("EDD employment availability -", ownership_label,
                "-", format(map_date, "%B %Y")), outer = TRUE, side = 3, line = 0.3)
    mtext("Workplace PUMAs | Reported includes observed zeros | Source: EDD; Census boundaries",
          outer = TRUE, side = 1, line = 1, cex = 0.8)
    dev.off()
