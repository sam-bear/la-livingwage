# PUBLIC fare extension through June 2026

Completed September 25, 2026. These are review outputs using the reconstructed directional-journey method. Approved raw/clean PDFs, the production fare script, and the client report remain unchanged.

## Outputs

- [Fare levels, 2023 Q1–2026 Q2](Flight-Prices-lax.pdf)
- [Year-over-year changes, 2024 Q1–2026 Q2](Flight-Prices-lax-yoy.pdf)
- [Year-over-year changes, 2025 Q1–2026 Q2](Flight-Prices-lax-yoy-2025-onward.pdf)
- [Quarterly data and source labels](quarterly-fares-2023Q1-2026Q2.csv)

The figures retain the original four vertical route panels, red lines/points, and September 2025 policy marker. Quarter/year labels and axis ranges extend to include the new observations. The long YoY axis label is slightly smaller to prevent clipping. Client-edited annotations in the clean figures have not been recreated here.

## Newly added periods

| Route | Quarter | Average fare | Year-over-year change |
| --- | --- | ---: | ---: |
| LAX–LAS | 2026 Q1 | $114.22 | +7.48% |
| LAX–LAS | 2026 Q2 | $154.48 | +60.09% |
| LAX–SEA | 2026 Q1 | $193.41 | +21.89% |
| LAX–SEA | 2026 Q2 | $202.54 | +19.50% |
| LAX–SFO | 2026 Q1 | $156.82 | +35.48% |
| LAX–SFO | 2026 Q2 | $152.36 | +20.88% |
| LAX–SLC | 2026 Q1 | $173.16 | +6.63% |
| LAX–SLC | 2026 Q2 | $183.93 | +20.16% |

## Construction and validation

- 2023 Q1–2025 Q2 retains the original ten DB1B MARKET input files and reconstructed baseline values.
- July 2025–June 2026 uses PUBLIC legacy directional trip breaks, LAX journey endpoints, and coupon-distance allocation of ticket prices. It includes qualifying round trips and excludes journeys merely connecting at LAX. The method and qualifications are described in the [2025 harmonization audit](../harmonized/README.md).
- The 2025 and 2026 calculations now call one shared routine, `script/flight-analysis/summarize-public-journeys.R`. A fresh July 2025 run reproduces the saved monthly summary within numerical tolerance 1e-12.
- The eight reconstructed 2025 Q3–Q4 values are unchanged by the extension (checked to tolerance 1e-8). The approved whole-ticket-based Q3–Q4 points are preserved separately, rather than used in this reconstructed series.
- Read all 75,112,475 rows in the six new files. Every row's reporting year/month was checked against its filename. No duplicate monthly releases were selected.
- All route-quarters contain three months. The combined PUBLIC panel has 48 route-months, and the full historical/extended series has 56 route-quarters.
- Ticket distance allocations conserve total distance exactly. No candidate ticket had unusable allocation distance in the six 2026 inputs.
- Quarter fares use passenger-weighted sums; YoY comparisons join explicitly to the same quarter in the previous year.

## MARKET overlap diagnostic

December 2025 MARKET arrived during the extension run; April–June 2026 MARKET were already present. The diagnostic compares native MARKET endpoint fares with the PUBLIC reconstruction, retaining the same unfiltered fare convention. This does not yet establish equivalence between the two constructions.

| Overlap period | Route | PUBLIC reconstruction | Native MARKET | PUBLIC relative to MARKET |
| --- | --- | ---: | ---: | ---: |
| December 2025 only | LAX–LAS | $102.56 | $97.52 | +5.17% |
| December 2025 only | LAX–SEA | $204.75 | $203.41 | +0.66% |
| December 2025 only | LAX–SFO | $142.52 | $136.17 | +4.67% |
| December 2025 only | LAX–SLC | $164.10 | $163.04 | +0.65% |
| 2026 Q2 (all 3 months) | LAX–LAS | $154.48 | $145.91 | +5.87% |
| 2026 Q2 (all 3 months) | LAX–SEA | $202.54 | $200.66 | +0.94% |
| 2026 Q2 (all 3 months) | LAX–SFO | $152.36 | $145.62 | +4.63% |
| 2026 Q2 (all 3 months) | LAX–SLC | $183.93 | $181.94 | +1.09% |

The LAS Q2 increase is also visible in native MARKET amounts: its Q2 fare is $145.91, versus $154.48 in the reconstruction. Thus the jump is not solely produced by our PUBLIC allocation, but its exact magnitude depends on the construction.

**Subsequent validation completed September 25:** The [PUBLIC–MARKET reconciliation](../reconciliation/README.md) explains the discrepancy through break rules and surface-distance allocation. Newer PUBLIC breaks reproduce all 2026 overlapping passenger counts exactly; allocating fares by air mileage then reproduces monthly MARKET fares within $0.0018. The legacy-break figures here remain unchanged. December fares agree within $0.021 after matching methods, with passenger differences of 0–8; different releases and individual records have not been reconciled. December alone is not a complete 2025 Q4 comparison. The linked audit also measures the much smaller allocation refinement for the legacy-break series.

See [monthly overlap data](public-market-monthly-comparison.csv) and [period aggregates with month counts](public-market-quarterly-comparison.csv). The MARKET observations are diagnostics only and are not spliced into the PUBLIC series.

## Reproduction

From the repository root, after the original and 2025 harmonization audits:

```sh
Rscript -e 'source("script/flight-analysis/extend-public-fares.R")'
Rscript -e 'source("script/flight-analysis/check-public-market-overlap.R")'
```

The extension reads the saved audit baseline and 2025 monthly sums explicitly; it does not depend on R session state. Its six raw 2026 inputs are recorded in [allocation-checks-2026.csv](allocation-checks-2026.csv).
