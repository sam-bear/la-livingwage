# Employment review figures and county-growth extrapolation

Generated September 26, 2026. [Open the five-page review PDF](employment-review.pdf).

1. [Local employment totals](employment-totals.pdf): allocated LA City hotel employment and LAX-area airport-industry employment.
2. [Year-over-year changes](employment-yoy.pdf).
3. [Covered/uncovered hotel allocation](hotel-covered-uncovered.pdf): indexed to August 2025; ends December 2025.
4. [Separate airport industries](airport-industry-detail.pdf).
5. [County totals and PUMA coverage](county-and-puma-coverage.pdf).

Solid local lines use the existing PUMA-based history through December 2025.
Dotted lines and open circles identify extrapolated January–March 2026 values;
the forecast region is shaded blue. Gray shading starts with September 2025
policy implementation. County lines in the coverage figure are published county
employment, including Q1 2026—not forecasts.

## Sources and reproduction

Official [California EDD QCEW downloads](https://lab.data.ca.gov/dataset/quarterly-census-of-employment-and-wages):

- [2023–2025 Q4 CSV](https://data.ca.gov/dataset/3f08b68e-1d1a-4ba4-a07d-1ec3392ed191/resource/119eef38-3b59-499f-8f7c-9bea4768469d/download/qcew-2023-2025q4.csv)
- [2026 Q1 CSV](https://data.ca.gov/dataset/3f08b68e-1d1a-4ba4-a07d-1ec3392ed191/resource/a8d3fd99-c666-4311-8902-dc95cda62ac6/download/qcew-2026-q1.csv)

Raw files are retained in `inputs/qcew-county`. Retrieval date and SHA-256 hashes
are in `download-manifest.json`. Selection is Los Angeles County, private
ownership, four-digit NAICS 7211, 4811 and 4881. Monthly employment fields are
used, not quarterly averages. No requested county employment value was missing.

Local history comes from the existing outputs of employment scripts 10 and 11:
`output/EDD-LAX-PUMA-employment-series.csv` and
`output/EDD-LA-city-hotel-employment-allocated-monthly.csv`. Coverage uses the
custom EDD `clean/edd_emp_monthly.rds` input. Source files and regression estimates
are not modified.

Run from the repository root:

```sh
Rscript --vanilla script/employment-analysis/12-county-employment-extrapolation.R
pdfunite output/edd-county-extrapolation/employment-totals.pdf output/edd-county-extrapolation/employment-yoy.pdf output/edd-county-extrapolation/hotel-covered-uncovered.pdf output/edd-county-extrapolation/airport-industry-detail.pdf output/edd-county-extrapolation/county-and-puma-coverage.pdf output/edd-county-extrapolation/employment-review.pdf
```

The R script downloads the two official files if absent. Paths are configured in
`script/0-config.R`. The merged review PDF uses the optional `pdfunite` utility.

## Estimation and interpretation

For each industry and each January–March month:

`local employment 2026 = local employment 2025 × county employment 2026 / county employment 2025`.

The two airport industries are extrapolated separately and then summed. This
preserves each industry's local base and avoids applying a pooled county growth
rate to a differently composed local workforce. The hotel covered/uncovered
split is not extrapolated: applying identical county growth to both would impose
their relative movement rather than measure it.

Hotel history is a fixed-room-share allocation of private NAICS 7211 PUMA jobs
to city hotels, restricted to PUMAs with complete reporting. It is not a direct
city employment count and has not been grossed up to cover omitted PUMAs.
Airport history is private 4811 + 4881 employment in workplace PUMA 3748, not a
precise airport-site, citywide, or ordinance-covered-worker count. Neither is
employment across all sectors of Los Angeles.

Extrapolation assumes each local industry's year-over-year growth matches the
county. The dotted YoY hotel line consequently reflects the assumed county
growth, not independent local evidence. No statistical confidence interval is
implied, and these extrapolations do not enter the policy regressions.

## Coverage diagnostic

December 2025 employment represented as a percentage of published county totals:

| Industry | All reported PUMAs | Fixed 36-month reporting panel |
| --- | ---: | ---: |
| Traveler accommodation (7211) | 94.29% | 94.26% |
| Scheduled air transportation (4811) | 89.55% | 89.55% |
| Air transportation support (4881) | 86.70% | 84.36% |

These are county-wide coverage ratios, not the share of city employment observed.
County minus reported PUMAs is an unexplained residual: suppression, geographic
assignment and different data vintages may contribute. It must not be allocated
entirely to the city or described as an exact suppression count. The fixed panel
is determined separately for each industry and excludes any PUMA lacking one or
more months of employment during 2023–2025.

## Validation and editable data

- County data have exactly 39 consecutive months per industry, January 2023–March 2026, with unique industry-month keys and positive employment.
- Local history contains all 36 original months per underlying industry.
- All nine industry-month extrapolations are finite and were independently checked against the raw arithmetic in the saved calculation table.
- Extrapolated industry YoY rates equal the corresponding county growth by construction; the combined airport total is the sum of the two components.
- All five figures were rendered and visually inspected.

CSV outputs include `county-monthly.csv`, `puma-county-coverage.csv`,
`extrapolation-calculations.csv`, `local-monthly-history-and-extrapolation.csv`,
and `hotel-allocation-split.csv`. Unrounded estimates are retained for revision;
they are not precise observed job counts.
