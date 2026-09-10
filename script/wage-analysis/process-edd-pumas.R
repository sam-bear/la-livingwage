source("script/0-loadFunctions.R")
source("script/0-loadPackages.R")

library(readxl)
library(dplyr)
library(purrr)


library(dplyr)
library(tidyr)
library(readr)
library(janitor)


file <- "data/edd/40627_2023 Q1-2025 Q3_ Los Angeles County_PUMA Level.xlsx"

years <- c("2023", "2024", "2025")

edd_raw <- map_dfr(
  years,
  function(y) {
    
    read_excel(
      file,
      sheet = y,
      skip = 8,
      col_types = "text",
      na = c(".", "")
    ) %>%
      mutate(year = as.integer(y), .before = 1)
  }
)

# ------------------------------------------------------------
# 1. Standardize column names
# ------------------------------------------------------------

edd <- edd_raw %>%
  clean_names()

names(edd)

# ------------------------------------------------------------
# 2. Make identifier variables consistent
# ------------------------------------------------------------

edd <- edd %>%
  mutate(
    year           = as.integer(year),
    naics4         = as.character(x4_digit_naics),
    ownership_code = as.integer(ownership_code),
    puma            = as.character(puma)
  )

edd <- edd %>%
  filter(
    !is.na(puma),
    !is.na(naics4),
    grepl("^[0-9]{4}$", naics4)
  )

# ------------------------------------------------------------
# 3. Reshape monthly employment
# ------------------------------------------------------------

emp_monthly <- edd %>%
  select(
    year,
    naics4,
    industry,
    ownership_code,
    ownership_title,
    puma,
    puma_name,
    confidential,
    ends_with("_employment")
  ) %>%
  
  # Drop annual-average employment
  select(-annual_average_employment) %>%
  
  pivot_longer(
    cols = ends_with("_employment"),
    names_to = "month_name",
    values_to = "employment"
  ) %>%
  
  mutate(
    month_name = sub("_employment$", "", month_name),
    
    month = match(
      month_name,
      c(
        "jan", "feb", "mar", "apr", "may", "jun",
        "jul", "aug", "sep", "oct", "nov", "dec"
      )
    ),
    
    employment_suppressed = coalesce(confidential == "YES", FALSE),
    employment = na_if(employment, "***"),
    employment = parse_number(employment),
    
    date = as.Date(
      sprintf("%d-%02d-01", year, month)
    )
  ) %>%
  
  select(
    year,
    month,
    date,
    puma,
    puma_name,
    naics4,
    industry,
    ownership_code,
    ownership_title,
    employment,
    employment_suppressed,
    confidential
  ) %>%
  
  arrange(naics4, ownership_code, puma, date)






############ Quality Checks ##############


glimpse(emp_monthly)

summary(emp_monthly$employment)

table(emp_monthly$month)

range(emp_monthly$date)

table(emp_monthly$year, emp_monthly$month)

sum(emp_monthly$employment_suppressed)






# ------------------------------------------------------------
# 4. Reshape quarterly establishments and wages
# ------------------------------------------------------------

qtr_panel <- edd %>%
  select(
    year,
    naics4,
    industry,
    ownership_code,
    ownership_title,
    puma,
    puma_name,
    confidential,
    matches("^qtr_[1-4]_")
  ) %>%
  
  pivot_longer(
    cols = matches("^qtr_[1-4]_"),
    names_to = c("quarter", ".value"),
    names_pattern = "qtr_([1-4])_(.*)"
  ) %>%
  
  mutate(
    quarter = as.integer(quarter),
    
    suppressed = coalesce(confidential == "YES", FALSE),
    
    establishments = na_if(establishments, "***"),
    establishments = parse_number(establishments),
    
    wages = na_if(wages, "***"),
    wages = parse_number(wages),
    
    quarter_date = as.Date(
      sprintf("%d-%02d-01", year, c(1, 4, 7, 10)[quarter])
    )
  ) %>%
  
  select(
    year,
    quarter,
    quarter_date,
    puma,
    puma_name,
    naics4,
    industry,
    ownership_code,
    ownership_title,
    establishments,
    wages,
    suppressed,
    confidential
  ) %>%
  
  arrange(naics4, ownership_code, puma, quarter_date)
