# Hotel time-series plotting corrections — September 25, 2026

The offline cleaned `AnalysisData_LargeGroups.rds` contains all four comparison
groups through **August 2026**. Group figures now display those observations:

- `figures/raw/ADR_yoy_sep25mar26_plot.pdf`: October 2025–August 2026. The historical
  filename is retained for existing links. Date limits and period averages now
  derive from the data. Averages appear in the legend to avoid overlapping labels.
  The second panel is correctly labeled RevPAR.
- `figures/raw/figX_ADRRevPAR_yoy_full_plot.pdf`: January 2023–August 2026. The start
  is fixed to the recent comparison window, avoiding the newly imported 2016–2022
  history and pandemic swings dominating the chart. Each outcome has its own
  vertical range, and the exact latest month is labeled.
- `figures/raw/fig4-ts-revpar-adr.pdf`: January 2023–August 2026. Post-policy shading
  extends through the last observation, vertical limits include all values, and
  the latest month is labeled. The April 2025 normalization is unchanged.

No underlying data or regression estimates were changed. Complete monthly
coverage was verified for all groups: 44 months in the full charts and 11 in the
focused chart. All three PDFs were rendered and visually checked. Monthly data,
coverage, and focused-period averages are saved alongside this README.

Reproduce from the repository root:

```sh
Rscript --vanilla -e 'source("script/hotel-analysis/MakeLevelsPlots.R"); source("script/hotel-analysis/MakeIndexedPlots.R")'
python3 script/hotel-analysis/compare-archived-figures.py
```

The indexed plot now has a standalone script sourced by `3-makeTables.R`, so
updating it does not require rerunning unrelated maps/tables. The citywide
background plot was separated into `MakeCityLevelsPlots.R`; it uses the distinct
`costar/AggregateCityData.xlsx` workbook. That workbook is still online-only and
was not opened. Its coverage and potential extension remain pending sync; the
citywide background PDF has not been regenerated in this correction.

The 26-page hotel comparison PDF was rebuilt with the corrected group figures.
The archived previous versions are unchanged.

## Pooled-regression coverage verification

The four models behind `fig4-pooled-est.pdf` were independently rerun against
`AnalysisData_SubGroups.rds`. Each uses 1,012 observations: 23 hotel groups over
44 months, January 2023–August 2026. Every post-policy month from September 2025
through August 2026 has all 23 groups in the actual estimation sample. Both ADR
and RevPAR, with and without the separate anticipation period, include all 12
post-policy months.

With standard errors clustered by hotel-group label, the rerun reproduces the
existing pooled PDF's decompressed graphics streams exactly. The four main
models now explicitly set `vcov = ~label` so reproducing the existing uncertainty
intervals does not depend on a session-wide fixest setting. The saved figure and
its estimates were not replaced during this verification.

## Event-study correction

A separate hard-coded `event_time < 5` filter was found in the hotel performance
event study. It restricted estimation to January 2026 even with newer data loaded.
That cutoff was removed. The corrected `figAX-eventStudyReg.pdf` now uses
September 2024–August 2026, with 23 groups in each of 24 months, including all
12 post-policy months (event times 0–11). The pre-policy window, August 2025
reference month, weights, and clustering are retained. Axis labels were adjusted
for the longer window. Coefficients are in `event-study-estimates.csv`.
The side-by-side comparison was rebuilt with this corrected figure. The earlier
visual similarity was not evidence that this event-study extension was complete.
