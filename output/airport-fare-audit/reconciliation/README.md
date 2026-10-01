# PUBLIC–MARKET reconciliation

September 25, 2026. The earlier discrepancy is substantially explained by journey
breaks and surface-distance allocation. No fare figure has been replaced during
this check.

## What the checks establish

1. Holding PUBLIC releases, coupon distances, and passenger weights fixed,
   replacing legacy `TripBk19_7` breaks with provisional `TripBk19_8` breaks
   reproduces MARKET passenger counts exactly for all 12 April–June 2026
   route-months. December 2025 differs by only 0–8 passenger-journeys per route.
2. With the newer breaks, setting surface-operator (`--`, `BUS`, `TRN`) coupon
   mileage to zero for fare allocation reproduces the 2026 MARKET route means
   within **$0.0018 per month**, and **$0.0013 for Q2**. This retains ground-only
   journeys in the denominator with zero fares to reproduce the native MARKET
   diagnostic; it is not a recommendation to include those journeys in airfare
   analysis.
3. Ground-only counts match MARKET's `MilesTraveled == 0` counts exactly in all
   16 overlapping route-months. Those native ground-only rows have zero fares.
   Under newer breaks they account for roughly 3.1% of LAS and 3.5% of SFO Q2
   journeys, versus 0.5% of SEA and 0.3% of SLC.
4. December fares agree within $0.021 after matching break/allocation rules.
   PUBLIC and MARKET use different release dates for December; the tiny residual
   passenger differences have not been reconciled at the individual-record
   level. PUBLIC lacks MARKET's shared itinerary identifier. Aggregate agreement
   does not establish record-by-record identity.

| 2026 Q2 route | Current legacy PUBLIC figure | New breaks, original allocation | New breaks, air-mile allocation | Native MARKET |
| --- | ---: | ---: | ---: | ---: |
| LAX–LAS | $154.4792 | $147.0117 | $145.9132 | $145.9120 |
| LAX–SEA | $202.5419 | $201.0219 | $200.6600 | $200.6593 |
| LAX–SFO | $152.3568 | $147.3150 | $145.6164 | $145.6152 |
| LAX–SLC | $183.9300 | $181.9339 | $181.9458 | $181.9448 |

The table changes break rules first and allocation second; it is a sequential
comparison, not a unique statistical decomposition. The remaining fractional-cent
2026 fare differences are small enough to be consistent with numerical fare
rounding, but the precise rounding rule has not been established.

## Implication for the existing figures

There is **no need to switch the whole extension to native MARKET merely to
resolve the overlap discrepancy**. Legacy PUBLIC breaks preserve the older
journey convention; native MARKET implements a different break rule. BTS says
the newer PUBLIC break flag can additionally mark stays over eight hours.
Changing break conventions at July 2025 would introduce another definition change.

Air-mile allocation is a separate methodological refinement. Its effect on the
current legacy-break series is quantified below. Ground-only journeys should be
separated when describing airfares. The retained DB1B inputs contain no selected
zero-distance markets across the ten historical quarters; their limited columns
do not allow a full surface-segment audit.

The DB1B/DB1C survey redesign remains a comparability limitation, and these
figures still describe changes rather than identify the ordinance's effect.
The `V_Yield` issue remains unresolved; no validity filter was silently added.

## Legacy-break sensitivity (existing figure method)

| 2026 Q2 route | Current figure fare | Air-mile allocation | Air-mile allocation, excluding ground-only journeys |
| --- | ---: | ---: | ---: |
| LAX–LAS | $154.4792 | $154.4833 | $154.4863 |
| LAX–SEA | $202.5419 | $202.5591 | $202.5681 |
| LAX–SFO | $152.3568 | $152.3789 | $152.3824 |
| LAX–SLC | $183.9300 | $183.9381 | $183.9467 |

Air-mile allocation alone changes these Q2 means by at most **$0.023**;
also excluding ground-only journeys changes them by at most **$0.027**.
December-only changes are at most $0.025 and $0.031, respectively. These checks
cover December 2025 and April–June 2026, not the other PUBLIC months. They do not
alter the substantive interpretation of the current fare plots.

The unchanged legacy calculation reproduces all 16 saved overlap-month means
within 1e-12 and reproduces passenger counts exactly. Default reconstruction
behavior has not changed: diagnostic options are explicit opt-ins.

## Reproduction and outputs

Run from the repository root after the existing fare extension and native overlap
diagnostic:

```sh
Rscript --vanilla -e 'source("script/flight-analysis/reconcile-public-market.R")'
Rscript --vanilla -e 'source("script/flight-analysis/reconcile-public-market-allocation.R")'
Rscript --vanilla script/flight-analysis/check-historical-zero-distance.R
```

- `break-rule-monthly-comparison.csv`: isolate journey-break changes.
- `TripBk19_8/allocation-monthly-comparison.csv`: native-break allocation check.
- `TripBk19_7/allocation-monthly-comparison.csv`: legacy-break sensitivity.
- Each subdirectory also contains quarter aggregates, with `months = 1` for
  December 2025 and `months = 3` for 2026 Q2. December is **not a full Q4 check**.
- `market-surface-summary.csv`: native flight and ground-only counts and amounts.
- `historical-zero-distance.csv`: retained DB1B diagnostic.
- `validation.csv`: comparison with the previously saved legacy calculations.

Sources: [BTS PUBLIC definitions](https://www.bts.gov/sites/bts.dot.gov/files/DB1C_Description_for_Bookstore.pdf)
and [BTS MARKET definitions](https://www.bts.gov/sites/bts.dot.gov/files/DB1C_Description_for_Market.pdf).
