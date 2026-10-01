# Airport analysis: current work and suggested updates

Status reconstructed from repository code, Git history, local Dropbox file inspection, and discussion on September 24, 2026. The subsequent fare audit reproduced all three original raw fare PDFs exactly at the graphics-stream level. Passenger figures were extended through June 2026 on September 25, with both original PDFs reproduced exactly before extension; employment figures have not been rerun in this review. Distinguish the original analysis from unfinished changes in the working tree.

## 1. Current analysis and data sources

The airport work describes employment, passenger volumes, and fares around the September 2025 wage-policy implementation. The scripts summarized here produce descriptive trends and year-over-year comparisons, rather than causal airport-policy estimates.

The intended passenger/fare population is travelers whose journey starts or ends at LAX. Travelers who only connect at LAX should be excluded. A round trip starting at LAX contains relevant outbound and return journeys; the endpoints of the whole ticket are not sufficient to identify those journeys.

### Employment

- **Script:** `script/employment-analysis/10-plot-EDD-airport-employment.R`.
- **Source:** Custom California EDD/QCEW PUMA-level employment data, processed into `clean/edd_emp_monthly.rds` under the configured project data directory.
- **Period:** January 2023–December 2025. The user confirmed that no newer EDD data are available.
- **Coverage:** Private employment in scheduled air transportation (NAICS 4811) and support activities for air transportation (4881), separately and combined. LAX is represented by PUMA 3748; PUMA 3720 provides a Burbank comparison. These are industry employment counts within PUMAs, not counts of workers confirmed covered by the ordinance.
- **Analysis:** Employment levels and year-over-year percentage changes, with September 2025 marked as policy implementation. The script checks completeness and absence of suppressed values in the selected cells.
- **Outputs:** `figures/raw/EDD-LAX-PUMA-airport-employment.pdf`, `figures/raw/EDD-LAX-vs-Burbank-PUMA-airport-employment.pdf`, and corresponding series CSVs in `output/`.

### Passenger volumes

- **Script:** `script/flight-analysis/LAWA.R`. `script/process-flight-data.R` is a short exploratory script reading only the 2025 file.
- **Source:** BTS T-100 Domestic Market, all carriers: `T_T100D_MARKET_ALL_CARRIER_YYYY.csv`.
- **Location:** `flight_traffic_path`, the synced OneDrive project data directory's `Flights/T100` folder, as defined in `script/0-config.R`.
- **Original period:** 2023–2025.
- **Extension completed (September 25):** Both passenger figures now include January–June 2026. The synced original `T100` files reproduce both pre-extension PDFs exactly at the graphics-stream level. Coverage, complete historical years, duplicate rows, and YoY denominators were checked; both extended PDFs were visually inspected. See the [passenger extension checks](output/airport-passenger-audit/README.md).
- **Analysis:** Sum passengers for records with LAX as origin or destination; plot monthly levels by year and year-over-year changes. The extension adds 2026 versus 2025 to the existing 2025 versus 2024 comparison.
- **Outputs:** `figures/raw/FigX1-levels-passengers-lax.pdf` and `figures/raw/FigX1-yoy-passengers-lax.pdf`.

T-100 traffic records and DB1B/DB1C ticket-survey records are different sources. BTS defines T-100 markets by travel under the same flight number. Thus the existing endpoint filter can include travelers changing flights at LAX; it does not identify only whole-journey origins/destinations. The extension preserves the existing measure and clarifies the caption. [BTS definitions](https://www.transtats.bts.gov/DatabaseInfo.asp?QO_VQ=EEE).

### Fares

- **Script:** `script/AirportPrices.R`.
- **Routes:** LAX–LAS, LAX–SEA, LAX–SFO, and LAX–SLC, pooling both directions.
- **Original historical source:** BTS DB1B MARKET quarterly CSVs in `~/Dropbox (Personal)/Living Wage Data/new/`. Git history confirms this original path. Reading the first record of each of its ten files identified quarters covering **2023 Q1–2025 Q2**.
- **Original later source:** DB1C PUBLIC monthly Parquet files in `~/Dropbox (Personal)/Living Wage Data/Prices/`, covering **July–December 2025**. This is consistent with the original script's Q3/Q4 assignment and plot labels through 2025.
- **Analysis:** Passenger-weighted quarterly average fares, followed by year-over-year changes using a four-quarter lag. The year-over-year figure selects dates from 2025 onward. The script also computes supporting passenger counts and distance statistics.
- **Outputs:** `clean/AirportPrices.rds` under the configured data directory, `figures/raw/Flight-Prices-lax.pdf`, and `figures/raw/Flight-Prices-lax-yoy-2025.pdf`.

The original input period was 2023–2025, not 2016 onward. The larger DB1B collection now in `Prices/` has filenames spanning 2016 Q1–2025 Q2, but it was not the original historical input folder.

#### Current paths and reproducibility issues

The September 15 path refactor replaced the original fare CSV path, `Living Wage Data/new/`, with `flight_traffic_path`. That points to the traffic folder and does not preserve the original fare input selection. The current uncommitted configuration points `flight_price_path` back to Dropbox `Prices/`.

The fare script selects all Parquet files in that folder, even though it currently contains both PUBLIC and MARKET schemas. Its code expects PUBLIC fields. It also concatenates the directory and filename with `paste0`, although the configured directory has no trailing separator, and relies on objects such as `apt_cols` and `routes_keep` that are not defined within this script. These issues mean the saved script's ability to run in a fresh session needs checking; they do not establish that the previously generated figures failed to run in their original environment.

#### Files inspected in Dropbox Prices

| Format | Available periods | Inspection performed |
| --- | --- | --- |
| DB1B MARKET CSV | Filenames: 2016 Q1–2025 Q2 | Directory inventory and a 2025 Q1 sample |
| DB1C PUBLIC Parquet | July 2025–June 2026 | All twelve months processed with the shared bounded-batch journey reconstruction |
| DB1C MARKET Parquet | December 2025; April–June 2026 | Native route means compared with PUBLIC in all four overlap months |

PUBLIC and MARKET now overlap in **December 2025 and April–June 2026**. The native
MARKET endpoint means are 0.6%–5.9% below the legacy PUBLIC reconstruction in the
December and full-Q2 comparisons. The subsequent [reconciliation](output/airport-fare-audit/reconciliation/README.md) explains the discrepancy through journey-break rules and surface-distance allocation. With newer PUBLIC breaks and air-mile allocation, all 2026 overlap passenger counts match MARKET exactly and monthly mean fares agree within $0.0018. The legacy and native definitions are different; this check does not make their unadjusted values interchangeable.

PUBLIC provides whole-ticket fields such as `TotalAmt`, `NumPax`, airport sequences, and trip-break indicators. MARKET provides directional market fields including `Origin`, `Dest`, `MktAmount`, `Passengers`, and connection information. Both describe the DB1C ticket survey, but records and fare amounts are not automatically interchangeable.

Examples read from the files illustrate the distinction: December PUBLIC contains LAX–HNL–LAX with a whole-ticket amount of $603.41; April MARKET contains LAX–JFK with a market amount of $215.90. These are different observations in different months, not a matched comparison.

In both entire MARKET files inspected, `V_Yield` is either zero or missing, including records with ordinary-looking positive fares. Filtering to `V_Yield == 1` would discard every row. Its interpretation or implementation needs clarification before use as a validity filter.

### Source documentation

- [BTS Origin and Destination Survey overview](https://www.bts.gov/topics/airlines-and-airports/origin-and-destination-survey-data): DB1B used quarterly 10% sampling; DB1C uses monthly 40% sampling beginning July 2025.
- [BTS DB1C MARKET downloads and description](https://www.bts.gov/topics/airlines-and-airports/origin-and-destination-survey-data-market).
- [BTS DB1C PUBLIC record description](https://www.bts.gov/sites/bts.dot.gov/files/DB1C_Description_for_Bookstore.pdf).
- [BTS DB1C MARKET record description](https://www.bts.gov/sites/bts.dot.gov/files/DB1C_Description_for_Market.pdf).
- [BTS explanation of the DB1C transition](https://www.bts.gov/newsroom/first-quarter-od40-data-live), including expanded reporting coverage.

## 2. Suggested updates

The client's existing figures have already been approved. The user's priority is
to preserve their design and analytical definitions where correct, extending
only the periods. Reproduce and audit the original fares before making any
change to historical estimates. Keep any necessary methodological correction
separate from the date extension and explain its effect first.

### Preserve and reproduce the existing fare analysis first

**Completed audit:** All three original fare figures reproduce exactly. However,
the PUBLIC whole-ticket endpoint selection excludes 49.77%–68.56% of relevant
directional passenger-journeys in July–December 2025, depending on route, mostly
on round-trip tickets. The historical DB1B calculation has no equivalent
whole-ticket restriction. This confirms a selection break, not the magnitude
or direction of any fare bias. See the
[audit findings and reproducible outputs](output/airport-fare-audit/README.md).
Approved figures remain unchanged; no corrected fare series has been adopted.

**Quantified follow-up:** Reconstructing legacy directional journeys from the
same PUBLIC files and allocating ticket amounts by coupon distance lowers the
eight 2025 Q3–Q4 route means by 8.4%–13.5%. Corresponding year-over-year changes
fall by 9.4–18.5 percentage points; LAX–SLC Q4 changes from +8.2% to −3.9%.
These are reconstructed estimates using legacy journey breaks. The subsequent
MARKET reconciliation validates aggregate fares after matching break and
allocation rules; native MARKET itself uses different journey selection. See the
[full comparison, method, and validation](output/airport-fare-audit/harmonized/README.md).
The approved figures and historical input values have not been replaced.

The separate audit script uses explicit references to the original ten DB1B
files in `new/` and the July–December 2025 PUBLIC files, with self-contained
definitions and corrected path construction. It saves reconstructed figures
outside the approved output folders. The production fare script has not yet
been changed; its path and session-state fixes remain to be carried over when
implementing the extension.

This step should distinguish changes needed to run the script from changes to the analysis itself. Switching formats is **not required simply to extend the time period**, and no decision to replace historical PUBLIC-based estimates has been made.

### Extend fares through 2026 Q2

**Completed September 25:** The reconstructed PUBLIC series and review figures
now extend through June 2026. All quarters contain three months; the historical
DB1B values and previously reconstructed 2025 points are unchanged. See the
[extended figures, data, validation, and MARKET comparison](output/airport-fare-audit/extended-public/README.md).
Approved figures and the client report have not been replaced.

The working approach is to use the same PUBLIC journey reconstruction for July
2025–June 2026, retaining the original DB1B MARKET inputs through 2025 Q2.
All six January–June 2026 PUBLIC files have been downloaded into
`Dropbox (Personal)/Living Wage Data/Prices/`. No additional PUBLIC download is
needed for this extension.

December 2025 MARKET arrived during the extension run and was included alongside
April–June 2026. **The aggregate reconciliation is now completed:** newer journey
breaks plus air-mile allocation reproduce native MARKET fares to fractional-cent
precision in 2026. December differs by at most $0.021 and 8 passenger-journeys
per route; its release dates differ and individual records were not matched.
December alone does not represent a complete Q4 MARKET comparison. See the
[reconciliation results and legacy-method sensitivity](output/airport-fare-audit/reconciliation/README.md).
No fare figures were replaced during this check, and switching to native MARKET
is not necessary to explain the discrepancy. The air-mile allocation sensitivity changes the current legacy Q2 2026 route means by at most $0.023 (or $0.027 including removal of ground-only journeys), so the substantive fare pattern is unchanged.

For either path, compute quarters correctly for all twelve months, select files by format and reporting period, and extend plot labels through 2026 Q2. Check for duplicate releases and complete quarters before aggregation. Keep the original 2023 Q1–2025 Q2 DB1B inputs rather than substituting the larger historical collection without validation.

### Verify journey endpoints and fare comparability

The target is travel starting or ending at LAX, excluding travel that merely connects there. For example, SFO–LAX–JFK with only a connection at LAX should be excluded, while both directions of LAX–JFK–LAX should be represented.

The saved PUBLIC code identifies the first and last airport of the whole ticket. That excludes ordinary round trips whose first and last airport are both LAX. Determine how that selection affected the original results before correcting it. PUBLIC trip-break fields or MARKET endpoints may support the intended definition, but the treatment of stopovers and market breaks needs verification.

If a correction is needed, document and quantify its effect on historical results separately from the effect of adding 2026 observations. Verify tax treatment, fare allocation, passenger weights, and validity rules across DB1B and DB1C. The July 2025 survey transition is close to policy implementation, so changes in sampling and reporting coverage also need attention.

### Complete the passenger-volume extension

**Completed September 25:** After the user confirmed `T100` was synced, all four
annual files were verified local. Configuration now points to `Flights/T100`.
The full script ran in a fresh session and regenerated the levels and YoY PDFs
through June 2026, preserving the existing historical values and plot styling.
Both original PDFs were independently reproduced exactly from the synced data.
The new 2026 YoY values range from +0.46% in January to −2.53% in May; June is
−1.65%. The earlier smaller `Traffic` files were not read while online-only.

The T-100 on-flight endpoint interpretation is retained, with the caption
clarifying that some connecting travelers are included. Source coverage and
full monthly calculations are saved in `output/airport-passenger-audit/`.

### Leave EDD coverage unchanged

Keep the employment analysis through December 2025. No newer EDD data are available, so extending employment is not part of the current update.
