# Import the custom LA County EDD/QCEW workplace-PUMA extract.
# Run from the repository root. Inputs remain in the shared OneDrive data folder.
# Outputs in memory: edd (annual source rows), emp_monthly, qtr_panel,
# and edd_coverage. This script does not write files.

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
