# Passenger figure extension

Completed September 25, 2026. `script/flight-analysis/LAWA.R` now extends both
raw passenger figures through June 2026. The user synced the original
`Flights/T100` folder; configuration now points to that folder. All four annual
files were confirmed local before reading. The smaller `Traffic` copies were
not needed.

- [Year-over-year figure](../../figures/raw/FigX1-yoy-passengers-lax.pdf)
- [Passenger levels](../../figures/raw/FigX1-levels-passengers-lax.pdf)
- [Monthly series](monthly-passengers.csv)
- [Year-over-year calculations](monthly-yoy.csv)

The original PDFs are preserved here as `*-before-extension.pdf`. Re-running
the original committed plotting code against the synced 2023–2025 inputs
reproduces **both original PDFs exactly at the decompressed graphics-stream
level**. See `original-figure-checks.csv` and `recreated-FigX1-*.pdf`. Thus the
historical data are unchanged by this extension.

The complete updated script ran successfully in a fresh R session. All historical
years contain 12 months; 2026 contains January–June. All four inputs have zero
exact duplicate rows. The six new YoY values match the earlier independent
Python calculation within 1e-10 percentage points. Both generated PDFs were
rendered and visually inspected.

## Verified local data

- `Flights/Traffic/T_T100D_MARKET_ALL_CARRIER_2026.csv`: January–June, 127,286 rows.
- Local original-folder `Flights/T100` copies for 2025 and 2026 were also read.
- The two 2026 copies produce exactly equal LAX totals in every month.
- Using that local 2025 copy, new year-over-year values are:

| 2026 month | LAX passengers | YoY |
| --- | ---: | ---: |
| January | 3,591,128 | +0.46% |
| February | 3,313,068 | −0.18% |
| March | 4,101,790 | −0.23% |
| April | 3,976,969 | −2.14% |
| May | 4,302,863 | −2.53% |
| June | 4,551,813 | −1.65% |

See `2026-yoy-local-inputs.csv`. The complete historical series has now been read, checked against the saved
figures, and plotted successfully.

## Definition

The calculation preserves the existing sum of T-100 Domestic MARKET passengers
with LAX at either endpoint. This is an on-flight market definition (same flight
number), not a whole-ticket journey definition. Someone changing flights at LAX
can appear in these counts. The updated caption makes that limitation explicit;
no switch of passenger measure has been made.

Source: [BTS T-100 definitions](https://www.transtats.bts.gov/DatabaseInfo.asp?QO_VQ=EEE).

Run from the repository root:

```sh
Rscript --vanilla -e 'source("script/flight-analysis/LAWA.R")'
```

The script checks contiguous months, full historical years, valid passenger
counts and prior-year denominators, writes monthly series and a file-coverage
manifest, and derives the latest-month label from the data. Repeated rows are
reported without dropping them because the smaller download omits some source
dimensions (including service class).
