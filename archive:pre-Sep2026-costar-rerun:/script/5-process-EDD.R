# Import the custom LA County EDD/QCEW workplace-PUMA extract.
# Run from the repository root. Inputs remain in the shared OneDrive data folder.
# Outputs in memory: edd (annual source rows), emp_monthly, qtr_panel,
# and edd_coverage. Clean panels are saved to data/clean in OneDrive.

# Configuration and inputs -----------------------------------------------
    source("script/0-config.R")

    edd_file <- file.path(data_path, "EDD",
                         "40627_2023 Q1-2025 Q3_ Los Angeles County_PUMA Level.xlsx")
    edd_update_file <- file.path(data_path, "EDD",
                                "40627_2025_Los Angeles County_PUMA Level.xlsx")

    if (!file.exists(edd_file)) stop("Original EDD workbook is missing: ", edd_file)
    if (!file.exists(edd_update_file)) stop("Updated EDD workbook is missing: ", edd_update_file)

# Read years separately so the full-year update replaces all of original 2025.
# Read as text to preserve identifiers and confidentiality markers.
    edd_2023 <- readxl::read_excel(edd_file, sheet = "2023", skip = 8,
                                 col_types = "text", na = c("", ".", "***"))
    edd_2024 <- readxl::read_excel(edd_file, sheet = "2024", skip = 8,
                                 col_types = "text", na = c("", ".", "***"))
    edd_2025 <- readxl::read_excel(edd_update_file, sheet = "2025", skip = 8,
                                 col_types = "text", na = c("", ".", "***"))

# The update splits the Ownership Code heading across two rows.
# Rename its column here; the extra header row is removed below.
    edd_2025 <- dplyr::rename(edd_2025, "Ownership Code" = "Ownership")
    stopifnot(identical(names(edd_2023), names(edd_2024)),
              identical(names(edd_2023), names(edd_2025)))

    edd_2023$year <- 2023L
    edd_2024$year <- 2024L
    edd_2025$year <- 2025L
    edd <- dplyr::bind_rows(edd_2023, edd_2024, edd_2025)

# Standardize headings and retain only industry-PUMA records.
    names(edd) <- tolower(gsub("[ -]+", "_", names(edd)))
    edd <- dplyr::rename(edd, naics4 = `4_digit_naics`)
    edd <- dplyr::filter(edd, !is.na(puma), grepl("^[0-9]{4}$", naics4))
    edd$ownership_code <- as.integer(edd$ownership_code)
    edd$confidential <- trimws(toupper(edd$confidential))

# Monthly employment -----------------------------------------------------
    month_columns <- paste0(tolower(month.abb), "_employment")
    emp_monthly <- dplyr::select(
        edd, year, puma, puma_name, naics4, industry,
        ownership_code, ownership_title, confidential,
        dplyr::all_of(month_columns)
    )
    emp_monthly <- tidyr::pivot_longer(
        emp_monthly, cols = dplyr::all_of(month_columns),
        names_to = "month_name", values_to = "employment"
    )
    emp_monthly <- dplyr::mutate(
        emp_monthly,
        month = match(month_name, month_columns),
        date = as.Date(sprintf("%d-%02d-01", year, month)),
        employment_suppressed = !is.na(confidential) & confidential == "YES",
        employment = as.numeric(employment)
    )
    emp_monthly <- dplyr::select(
        emp_monthly, year, month, date, puma, puma_name, naics4, industry,
        ownership_code, ownership_title, employment,
        employment_suppressed, confidential
    )
    emp_monthly <- dplyr::arrange(emp_monthly, naics4, ownership_code, puma, date)

# Quarterly establishments and total wages -------------------------------
# Keep these separate from monthly employment to avoid repeating wage totals.
    qtr_panel <- dplyr::select(
        edd, year, puma, puma_name, naics4, industry,
        ownership_code, ownership_title, confidential,
        dplyr::matches("^qtr_[1-4]_")
    )
    qtr_panel <- tidyr::pivot_longer(
        qtr_panel, cols = dplyr::matches("^qtr_[1-4]_"),
        names_to = c("quarter", ".value"),
        names_pattern = "qtr_([1-4])_(.*)"
    )
    qtr_panel <- dplyr::mutate(
        qtr_panel,
        quarter = as.integer(quarter),
        quarter_date = as.Date(sprintf("%d-%02d-01", year, 3 * quarter - 2)),
        establishments = as.numeric(establishments),
        wages = as.numeric(wages),
        suppressed = !is.na(confidential) & confidential == "YES"
    )
    qtr_panel <- dplyr::arrange(qtr_panel, naics4, ownership_code, puma, quarter_date)

# Checks and an exploration summary --------------------------------------
# Missing outcomes must agree with EDD's confidentiality flag, never become zero.
    stopifnot(
        !anyDuplicated(emp_monthly[c("puma", "naics4", "ownership_code", "date")]),
        !anyDuplicated(qtr_panel[c("puma", "naics4", "ownership_code", "quarter_date")]),
        all(is.na(emp_monthly$employment) == emp_monthly$employment_suppressed),
        all(is.na(qtr_panel$establishments) == qtr_panel$suppressed),
        all(is.na(qtr_panel$wages) == qtr_panel$suppressed),
        identical(sort(unique(emp_monthly$date)),
                  seq(as.Date("2023-01-01"), as.Date("2025-12-01"), by = "month")),
        identical(sort(unique(qtr_panel$quarter_date)),
                  seq(as.Date("2023-01-01"), as.Date("2025-10-01"), by = "3 months"))
    )

    edd_coverage <- dplyr::group_by(emp_monthly, year, naics4, ownership_code)
    edd_coverage <- dplyr::summarise(
        edd_coverage,
        pumas = dplyr::n_distinct(puma),
        monthly_cells = dplyr::n(),
        observed_cells = sum(!is.na(employment)),
        suppressed_cells = sum(employment_suppressed),
        .groups = "drop"
    )
    print(edd_coverage, n = Inf)

# Spot checks against Excel ----------------------------------------------
# Choose one reported airport row, one reported hotel row, and one suppressed
# row per year. Excel row numbers include the eight introductory rows and header.
    edd_source_rows <- edd
    edd_source_rows$excel_row <- c(
        which(!is.na(edd_2023$PUMA) & grepl("^[0-9]{4}$", edd_2023$`4-digit NAICS`)) + 9,
        which(!is.na(edd_2024$PUMA) & grepl("^[0-9]{4}$", edd_2024$`4-digit NAICS`)) + 9,
        which(!is.na(edd_2025$PUMA) & grepl("^[0-9]{4}$", edd_2025$`4-digit NAICS`)) + 9
    )
    edd_source_rows <- dplyr::mutate(
        edd_source_rows,
        workbook = ifelse(year == 2025, basename(edd_update_file), basename(edd_file)),
        sheet = as.character(year),
        check_group = dplyr::case_when(
            confidential == "YES" ~ "suppressed",
            naics4 %in% c("4811", "4881") ~ "airport",
            naics4 == "7211" ~ "hotel"
        )
    )
    spot_keys <- dplyr::group_by(edd_source_rows, year, check_group)
    spot_keys <- dplyr::slice_head(spot_keys, n = 1)
    spot_keys <- dplyr::ungroup(spot_keys)
    spot_keys <- dplyr::select(spot_keys, year, puma, naics4, ownership_code,
                               workbook, sheet, excel_row, check_group)

# Display cleaned values in source-column order for side-by-side inspection.
    spot_monthly <- tidyr::pivot_wider(
        dplyr::select(emp_monthly, year, puma, naics4, ownership_code, month, employment),
        names_from = month, values_from = employment, names_prefix = "month_"
    )
    spot_quarterly <- tidyr::pivot_wider(
        dplyr::select(qtr_panel, year, puma, naics4, ownership_code,
                      quarter, establishments, wages),
        names_from = quarter, values_from = c(establishments, wages),
        names_sep = "_q"
    )
    edd_spot_check <- dplyr::left_join(
        spot_keys, spot_monthly, by = c("year", "puma", "naics4", "ownership_code")
    )
    edd_spot_check <- dplyr::left_join(
        edd_spot_check, spot_quarterly,
        by = c("year", "puma", "naics4", "ownership_code")
    )

# Column summaries for matching Excel filters -----------------------------
# These sums cover reported cells only; they are not complete county totals.
# Leave sums missing when a group has no reported cells.
    summary_monthly <- dplyr::filter(emp_monthly, month %in% c(1, 9, 12))
    summary_monthly <- dplyr::transmute(
        summary_monthly, year, naics4, ownership_code,
        measure = paste0(tolower(month.abb[month]), "_employment"), value = employment
    )
    summary_quarterly <- dplyr::filter(qtr_panel, quarter == 4)
    summary_quarterly <- dplyr::select(summary_quarterly, year, naics4,
                                      ownership_code, establishments, wages)
    summary_quarterly <- tidyr::pivot_longer(
        summary_quarterly, cols = c(establishments, wages),
        names_to = "measure", values_to = "value"
    )
    summary_quarterly$measure <- paste0("qtr_4_", summary_quarterly$measure)
    edd_summary_check <- dplyr::bind_rows(summary_monthly, summary_quarterly)
    edd_summary_check <- dplyr::group_by(
        edd_summary_check, year, naics4, ownership_code, measure
    )
    edd_summary_check <- dplyr::summarise(
        edd_summary_check,
        numeric_cells = sum(!is.na(value)),
        reported_sum = if (all(is.na(value))) NA_real_ else sum(value, na.rm = TRUE),
        .groups = "drop"
    )

# Annual figures provide an independent check against source totals -------
# Require all months/quarters; partial totals should not pass as annual values.
    annual_employment <- dplyr::group_by(emp_monthly, year, puma, naics4, ownership_code)
    annual_employment <- dplyr::summarise(
        annual_employment, months_observed = sum(!is.na(employment)),
        calculated_employment = mean(employment), .groups = "drop"
    )
    annual_wages <- dplyr::group_by(qtr_panel, year, puma, naics4, ownership_code)
    annual_wages <- dplyr::summarise(
        annual_wages, quarters_observed = sum(!is.na(wages)),
        calculated_wages = sum(wages), .groups = "drop"
    )
    edd_annual_check <- dplyr::transmute(
        edd_source_rows, year, puma, naics4, ownership_code, workbook, sheet, excel_row,
        source_employment = as.numeric(annual_average_employment),
        source_wages = as.numeric(total_annual_wages)
    )
    edd_annual_check <- dplyr::left_join(
        edd_annual_check, annual_employment,
        by = c("year", "puma", "naics4", "ownership_code")
    )
    edd_annual_check <- dplyr::left_join(
        edd_annual_check, annual_wages,
        by = c("year", "puma", "naics4", "ownership_code")
    )
    edd_annual_check <- dplyr::mutate(
        edd_annual_check,
        employment_difference = calculated_employment - source_employment,
        wages_difference = calculated_wages - source_wages,
        employment_flag = abs(employment_difference) > 0.5,
        wages_flag = abs(wages_difference) > 0
    )
    print(dplyr::filter(edd_annual_check, employment_flag | wages_flag), width = Inf)

# Explore interactively with View(edd_spot_check), View(edd_summary_check),
# and View(edd_annual_check). Missing annual comparisons are not passes.

# Save clean panels ------------------------------------------------------
# RDS preserves Date columns, identifiers, and suppression flags for later scripts.
    clean_path <- file.path(data_path, "clean")
    dir.create(clean_path, recursive = TRUE, showWarnings = FALSE)
    saveRDS(emp_monthly, file.path(clean_path, "edd_emp_monthly.rds"))
    saveRDS(qtr_panel, file.path(clean_path, "edd_qtr_panel.rds"))
