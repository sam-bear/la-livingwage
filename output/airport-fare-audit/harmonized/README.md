# Effect of harmonizing the 2025 fare journey selection

Calculated September 24, 2026 from the original July–December 2025 DB1C PUBLIC files. The approved figures and the 2023 Q1–2025 Q2 values remain unchanged.

## Results

Using legacy journey breaks and distance-proportional allocation lowers all eight route-quarter means by 8.4%–13.5%. Year-over-year growth falls by 9.4–18.5 percentage points. LAX–SLC Q4 changes from a year-over-year increase to a decrease. These are reconstructed journey-level estimates under the method below, not a verified replication of the official DB1C MARKET product.

| Route | 2025 quarter | Approved fare | Reconstructed fare | Change ($) | Change (%) | Approved YoY | Reconstructed YoY | YoY change (pp) |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| LAX–LAS | Q3 | $112.36 | $99.66 | -12.71 | -11.31% | +15.10% | +2.08% | -13.01 |
| LAX–LAS | Q4 | $118.90 | $108.93 | -9.97 | -8.38% | +12.01% | +2.62% | -9.39 |
| LAX–SEA | Q3 | $215.27 | $191.09 | -24.18 | -11.23% | +32.93% | +18.00% | -14.93 |
| LAX–SEA | Q4 | $226.86 | $199.83 | -27.03 | -11.92% | +34.07% | +18.09% | -15.98 |
| LAX–SFO | Q3 | $144.84 | $126.89 | -17.95 | -12.39% | +28.55% | +12.62% | -15.93 |
| LAX–SFO | Q4 | $158.24 | $139.80 | -18.43 | -11.65% | +38.51% | +22.38% | -16.13 |
| LAX–SLC | Q3 | $171.14 | $148.06 | -23.08 | -13.49% | +36.86% | +18.40% | -18.46 |
| LAX–SLC | Q4 | $174.68 | $155.16 | -19.52 | -11.18% | +8.22% | -3.88% | -12.09 |

[Comparison figure](fare-comparison.pdf) · [Full numerical results](quarterly-comparison.csv)

## Method

1. Read all rows in the six existing PUBLIC files in bounded batches. Use the same four routes and reporting periods as the approved figures.
2. Split each ticket at legacy directional trip breaks (`TripBk19_7 == "X"`) and its final endpoint. Keep journeys with LAX at one endpoint and LAS, SEA, SFO, or SLC at the other. Journeys merely passing through LAX do not qualify. Both qualifying directions of round trips are included.
3. Allocate the tax-inclusive ticket amount to each journey in proportion to its share of summed coupon distances: `journey fare = TotalAmt × journey coupon miles / total ticket coupon miles`.
4. Compute passenger-weighted route-quarter means directly from journey sums. Preserve the original inclusion of zero/low fares and the original missing-fare denominator convention to isolate journey selection and allocation. Report a sensitivity excluding missing fares.
5. Compute year-over-year changes relative to the unchanged corresponding 2024 DB1B fare.

BTS describes the legacy fields as directional trip breaks and the coupon distances as nonstop coupon mileage. Historical DB1B market fares are based on itinerary yield times market miles flown. The reconstruction follows that proportional-allocation concept, but PUBLIC coupon distances are not independently verified as identical to the official flown-mile inputs in every case (including via points or surface segments).

Sources: [PUBLIC field definitions](https://www.bts.gov/sites/bts.dot.gov/files/DB1C_Description_for_Bookstore.pdf) and [DB1B MARKET field definitions](https://transtats.bts.gov/Fields.asp?gnoyr_VQ=FHK).

## Why the means change

Both effects matter: the old filter omits relevant journeys on round-trip and other tickets, and some tickets that it retains contain more than one journey. Their entire ticket price should not all be assigned to the named route.

The table below applies the reconstructed journey allocation to two ticket cohorts. “Previously retained” means the ticket passed the old whole-ticket endpoint filter; “newly included” means it did not. These are descriptive cohort means, not a causal decomposition. Journeys can be reassigned to different routes when a multi-market ticket is split.

| Route | Quarter | Journey fare: previously retained tickets | Journey fare: newly included tickets |
| --- | --- | ---: | ---: |
| LAX–LAS | Q3 | $104.02 | $95.40 |
| LAX–LAS | Q4 | $110.04 | $107.77 |
| LAX–SEA | Q3 | $209.70 | $181.94 |
| LAX–SEA | Q4 | $220.94 | $190.64 |
| LAX–SFO | Q3 | $129.95 | $124.35 |
| LAX–SFO | Q4 | $143.05 | $137.13 |
| LAX–SLC | Q3 | $163.71 | $140.40 |
| LAX–SLC | Q4 | $166.83 | $150.13 |

## Validation and sensitivity

- Processed all 79,857,726 PUBLIC rows, yielding 1,090,386 relevant sample passenger-journeys across the four routes.
- All 24 route-month journey counts, counts on previously excluded tickets, and counts on round-trip tickets exactly match the independent saved audit counts.
- Every candidate ticket was completely partitioned: allocated journey distances sum exactly to total ticket distance. Thus the distance shares conserve the total ticket amount across all journeys. No relevant journey was excluded for unusable allocation distances.
- Excluding missing fares from the denominator changes any route-quarter mean by at most $0.036.
- Excluding tickets with recorded surface operators (`--`, `BUS`, or `TRN`) changes any route-quarter mean by at most $0.733. Neither sensitivity explains the main differences.
- The July 2025 survey redesign, carrier coverage changes, fare-validity rules, and alternative DB1C trip-break definitions remain separate comparability questions. This exercise does not remove all possible cross-survey differences or estimate policy effects.

## Reproduction and status

Run from the repository root after the original fare audit:

```sh
Rscript -e 'source("script/flight-analysis/harmonize-2025-fares.R")'
```

Per-file summaries, monthly sums, allocation checks, the quarterly comparison, and a review PDF are saved here. The production fare script, approved figure files, and client report have not been replaced. These results quantify the consequences of harmonizing journey selection; adopting revised historical points is a separate next step.

## Subsequent MARKET reconciliation

The [September 25 overlap check](../reconciliation/README.md) explains the native
MARKET discrepancy through newer journey-break rules and air-mile allocation.
With those definitions aligned, 2026 route-month passenger counts match exactly
and mean fares agree within $0.0018. This does not require switching the legacy
journey convention used here. The linked audit quantifies a separate, small
air-mile allocation sensitivity for the existing legacy series. These figures
have not been replaced.
