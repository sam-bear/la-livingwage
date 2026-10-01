# City finance TOT extract: retain Grand Total, as in the original figure.
library(readxl)
library(dplyr)
library(tidyr)
source("script/0-config.R")

input_file <- file.path(tot_path, "INC0959940 - Monthly TOT Revenue by Council District for CY 2023-2026 As Of 20260928.xlsx")
extract_date <- as.Date("2026-09-28")
out <- "output/tot-update"
dir.create(out, recursive = TRUE, showWarnings = FALSE)

# Sheets contain merged district labels and a final annual total row.
parts <- list()
for (sheet in excel_sheets(input_file)) {
  raw <- suppressMessages(read_excel(input_file, sheet = sheet, col_names = FALSE,
                                    col_types = "text"))
  names(raw) <- c("district", "period", "revenue_type", "liability", "interest",
                  "penalty", "fee", "overpayment", "total")
  annual_total <- as.numeric(raw$total[raw$district == "Grand Total" & !is.na(raw$district)])
  rows <- raw |> fill(district) |> filter(grepl("^[0-9]{4}/[0-9]{2}$", period))
  rows$date <- as.Date(paste0(rows$period, "/01"), "%Y/%m/%d")
  rows$district <- as.integer(rows$district)
  rows$total <- as.numeric(rows$total)
  stopifnot(!anyNA(rows$total), all(rows$district %in% 1:15),
            all(rows$revenue_type == "Trans Occupancy Tax"),
            length(annual_total) == 1, abs(sum(rows$total) - annual_total) < 0.01)
  parts[[sheet]] <- rows
}
districts <- bind_rows(parts)
stopifnot(!anyDuplicated(districts[c("district", "date")]))
monthly <- districts |> group_by(date) |>
  summarise(total = sum(total), districts = n_distinct(district), .groups = "drop") |>
  arrange(date)
stopifnot(all(monthly$districts == 15),
          identical(monthly$date, seq(min(monthly$date), max(monthly$date), by = "month")))
monthly$potentially_incomplete <- monthly$date >= as.Date(format(extract_date, "%Y-%m-01"))
monthly$yoy <- monthly$total / lag(monthly$total, 12) - 1
write.csv(monthly, file.path(out, "monthly-tot.csv"), row.names = FALSE)

# Compare the revised extract with the original rounded-dollar CSV.
old <- read.csv(file.path(tot_path, "hotel_TOT_2023_2025.csv"))
old$date <- as.Date(paste0(old$Year.Month, "/01"), "%Y/%m/%d")
old$total <- as.numeric(gsub("[^0-9.-]", "", old$Grand.Total))
old_monthly <- old |> filter(!is.na(date)) |> group_by(date) |>
  summarise(previous = sum(total), .groups = "drop")
comparison <- inner_join(monthly, old_monthly, by = "date")
comparison$revision <- comparison$total - comparison$previous
comparison$revision_pct <- 100 * comparison$revision / comparison$previous
write.csv(comparison, file.path(out, "historical-revisions.csv"), row.names = FALSE)

# Continuous dates keep the post-policy period in chronological order.
plot_data <- filter(monthly, !potentially_incomplete)
policy_date <- as.Date("2025-09-01")
pdf("figures/raw/TOT-raw.pdf", width = 9, height = 7, useDingbats = FALSE)
par(mfrow = c(2, 1), mar = c(3.5, 5, 2, 1), oma = c(2, 0, 1, 0))
for (panel in c("total", "yoy")) {
  d <- plot_data[!is.na(plot_data[[panel]]), ]
  values <- if (panel == "total") d$total / 1e6 else 100 * d$yoy
  plot(d$date, values, type = "n", axes = FALSE, xlab = "", ylab = "",
       main = if (panel == "total") "Los Angeles hotel TOT revenue" else "Year-over-year change")
  usr <- par("usr")
  rect(policy_date, usr[3], max(d$date), usr[4], col = "gray95", border = NA)
  abline(v = policy_date, lty = 2, col = "gray50")
  if (panel == "yoy") abline(h = 0, lty = 2, col = "gray65")
  lines(d$date, values, col = "#355C7D", lwd = 2)
  axis(2, las = 1)
  axis.Date(1, at = seq(min(d$date), max(d$date), by = "6 months"), format = "%b\n%Y")
  mtext(if (panel == "total") "Revenue ($ millions)" else "Change (%)", side = 2, line = 3)
}
mtext("Dashed line: September 2025 policy. September 2026 excluded: extract dated September 28.",
      side = 1, outer = TRUE, cex = 0.8)
dev.off()
print(tail(monthly, 4))
print(comparison[which.max(abs(comparison$revision_pct)), c("date", "revision", "revision_pct")])
