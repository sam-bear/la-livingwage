# Original airport fare audit — September 24, 2026

## Result

**Follow-up:** The journey-selection change has now been quantified in a separate
[harmonization comparison](harmonized/README.md). The eight 2025 Q3–Q4 fares are
8.4%–13.5% lower under legacy journey breaks and distance-proportional ticket
allocation. The original audit below describes the unchanged baseline; its
statements that no revised series had yet been estimated refer to that initial
audit. No revised series has replaced the approved figures.

The original fare figures are reproducible. All decompressed graphics streams
match the original PDFs exactly for all three figures:

- `Flight-Prices-lax.pdf`
- `Flight-Prices-lax-yoy.pdf`
- `Flight-Prices-lax-yoy-2025.pdf`

Original files in `figures/raw/` and `figures/clean/` were not overwritten.
Reconstructed figures and supporting data are in this directory. PDF metadata
such as creation timestamps can differ; graphics streams do not.

The arithmetic and plotting reproduce, but the historical series changes its
population and fare unit in July 2025. It should not yet be treated as a
consistent measure of all directional journeys starting or ending at LAX.

## Inputs and reproduction

The original ten DB1B MARKET CSVs in Dropbox `Living Wage Data/new/` provide
2023 Q1–2025 Q2. Each file was read in full, one at a time, and the selected
routes aggregated using the original passenger-weighted formula. The input
manifest records the actual year, quarter, and row count of each file.

The six original DB1C PUBLIC files in Dropbox `Living Wage Data/Prices/` provide
July–December 2025. All rows were processed in bounded Parquet row groups,
reading only required columns. The reconstruction preserves the original
first/last-ticket-airport selection, passenger weights, and monthly-to-quarterly
aggregation. The undefined `apt_cols` object was reconstructed in numeric airport
order; matching all three PDFs confirms this produces the original plotted
results. No OneDrive data were opened.

To reproduce from the repository root:

```sh
Rscript script/flight-analysis/audit-original-fares.R
python3 script/flight-analysis/compare-approved-fares.py
```

The comparison also recovers all 48 fare points and 48 year-over-year points
from the original PDFs' vector paths and axis ticks. Maximum differences from
these approximately recovered values are $0.0135 and 0.00453 percentage points,
respectively, attributable to PDF coordinate rounding. The stronger check is
the exact graphics-stream match, recorded in `approved-pdf-stream-checks.csv`.

## Journey endpoint findings

The user wants journeys starting or ending at LAX, excluding passengers merely
connecting there. The saved PUBLIC code selects tickets whose first airport is
LAX and last airport is one of the four destinations, or the reverse. It excludes
ordinary round trips such as LAX–SEA–LAX. It can also include tickets containing
more than one directional market, assigning the entire ticket amount to the
first-to-last airport pair.

Using PUBLIC's legacy directional trip-break flags (`TripBk19_7`) to identify
journeys gives the following diagnostic counts for July–December 2025. A journey
may include connections. LAX must be one of its endpoints; passing through LAX
alone does not qualify. Counts are sample passenger-journeys, not population
estimates or unique people.

| Route | Relevant passenger-journeys | Share on tickets excluded by old filter | Share on round-trip tickets |
| --- | ---: | ---: | ---: |
| LAX–LAS | 288,730 | 49.77% | 49.27% |
| LAX–SEA | 248,218 | 68.27% | 67.23% |
| LAX–SFO | 402,940 | 54.72% | 54.27% |
| LAX–SLC | 150,498 | 68.56% | 68.03% |

The historical DB1B code has no corresponding whole-ticket restriction. BTS
defines its MARKET records as directional markets and its market fare as
itinerary yield multiplied by market miles flown. Thus it uses allocated market
fares, whereas the later PUBLIC code uses entire ticket amounts for the selected
ticket subset. The extracts in `new/` do not retain itinerary identifiers or
round-trip indicators, so the exact historical round-trip share cannot be
measured from those extracts alone.

Sources: [DB1B MARKET description](https://www.transtats.bts.gov/TableInfo.asp?QO_fu146_anzr=b4vtv0+n0q+Qr56v0n6v10+f748rB&gnoyr_VQ=FHK),
[DB1B fields](https://transtats.bts.gov/Fields.asp?gnoyr_VQ=FHK), and
[DB1C PUBLIC fields and trip-break definitions](https://www.bts.gov/sites/bts.dot.gov/files/DB1C_Description_for_Bookstore.pdf).

This establishes a substantive change in selection, not its effect on average
fares. The exclusion shares do not measure fare bias. No corrected market-fare
series has been estimated or substituted in this audit. The diagnostic uses
legacy breaks for comparison with the historical source; it is not a validation
of every distinction between legacy and newer DB1C trip-break rules.

## Other checks

- Historical inputs cover ten distinct quarters; the six PUBLIC input months
  have no duplicate releases selected. There are 48 route-quarter baseline rows.
- Selected PUBLIC tickets with missing amounts remain in the original mean's
  passenger denominator. There are 78 such passengers for LAS, 4 for SEA, 53 for
  SFO, and 2 for SLC across the six months, under 0.06% of each selected route's
  passengers. This is a small downward arithmetic effect, separate from the
  much larger population-selection issue.
- Among selected tickets, 1.06%–2.40% have an internal legacy market break.
  Whole-ticket fares for these tickets are not necessarily fares for a single
  directional journey between the named endpoints.
- Amounts at or below reported taxes occur for 6.39%–10.51% of selected
  passengers by route. These observations are retained to reproduce the old
  figures. Their treatment should be aligned with historical fare-validity
  rules; this check does not establish that they are data errors.
- PUBLIC `TotalAmt` includes taxes and fees according to BTS. Do not subtract
  taxes only from the new periods. Full cross-survey harmonization of fare
  validity, reporting coverage, and definitions is not established by matching
  the PDFs. The July 2025 transition also changes sampling from quarterly 10%
  to monthly 40% and expands reporting coverage; see the
  [BTS transition explanation](https://www.bts.gov/newsroom/first-quarter-od40-data-live).

## Implication for the extension

The approved figure design can be retained. PUBLIC remains a usable data source,
and changing to MARKET is not inherently required. However, simply appending
2026 under the original code would preserve the verified selection break.

Before describing the full line as a consistent journey-level fare series,
compare a harmonized PUBLIC journey calculation or an overlapping MARKET month
with the reproduced 2025 Q3–Q4 points. Show the effect on those historical values
before adopting any correction. Keep the 2023 Q1–2025 Q2 baseline and all approved
files intact during that comparison.

For the period extension, BTS currently lists January–June 2026 PUBLIC/Product
downloads. Extract all six into Dropbox `Living Wage Data/Prices/` while retaining
the original 2025 files:
[BTS Product downloads](https://www.bts.gov/topics/airlines-and-airports/origin-and-destination-survey-data-product).
