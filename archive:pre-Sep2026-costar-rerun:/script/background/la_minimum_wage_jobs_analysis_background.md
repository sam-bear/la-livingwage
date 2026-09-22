# LA Minimum Wage Project — Jobs Analysis Background

## Purpose

This repository contains the employment-side analysis for evaluating recent Los Angeles minimum wage changes affecting airport and hotel workers. The immediate goal is to estimate short-run employment effects using custom California EDD/QCEW data aggregated to Public Use Microdata Areas (PUMAs) within Los Angeles County.

The jobs analysis is intended to answer a reduced-form question:

> Did employment in the affected industries change after the minimum wage policy took effect, relative to appropriate comparison geographies and/or less-exposed industry-geography cells?

This is distinct from the earlier ex ante coverage analysis, which required assumptions about occupational composition in order to estimate how many workers would be directly covered. For the ex post employment analysis, the primary outcome is total industry employment, so the analysis can be conducted directly at the NAICS level without requiring occupational composition assumptions.

## Policy Context

Los Angeles adopted minimum wage increases affecting workers in the hotel and airport sectors.

For the airport-worker policy, the key implementation date for the current analysis is September 2025. There was earlier policy anticipation and legal/political activity before implementation, so specifications should not assume that September 2025 is necessarily the only economically relevant break. Event-study-style diagnostics and sensitivity to alternative treatment timing should be considered.

A separate but related hotel minimum wage policy applies to covered hotels in the City of Los Angeles. Hotel treatment status is heterogeneous: the law applies to hotels above the relevant room-count threshold, while unionized hotels are exempt. Smaller hotels are also outside the covered group. These within-city exempt hotels are potentially useful controls because they share Los Angeles-specific shocks such as utility price changes and local tourism conditions.

A contemporaneous Los Angeles utility-price shock is a potential confounder when using hotels in neighboring cities as controls, because neighboring-city hotels may not face the same LADWP-related changes. This strengthens the case for same-city exempt hotels as primary controls where feasible.

## EDD/QCEW Employment Data

The project uses a custom California EDD/QCEW extract produced specifically for this research.

### Requested structure

EDD was asked to provide QCEW data for Los Angeles County aggregated to the PUMA level using custom GIS/spatial processing to assign establishments to PUMA geographies before aggregation.

The extract covers:

- 2023 Q1 through 2025 Q4
- PUMA geography within Los Angeles County
- 4-digit NAICS industries:
  - `4811` — Scheduled Air Transportation
  - `4881` — Support Activities for Air Transportation
  - `7211` — Traveler Accommodation
- Private and government ownership categories
- Monthly employment
- Quarterly establishment counts
- Quarterly total wages
- Confidentiality/suppression indicators

The 2025 Q4 data are particularly important because the September 2025 minimum wage change leaves only one fully post-policy quarter in the current extract.

### Important data limitation

The current employment panel has only a short post-policy window:

- Pre-period: January 2023 through August 2025
- Policy implementation: September 2025
- Post-period currently available: September through December 2025

Thus, this is initially a short-run impact analysis rather than a long-run employment study.

## Data Organization

The raw EDD workbook should remain unchanged.

The cleaned data should be organized into two master panels.

### Monthly employment panel

Unit of observation:

`PUMA × NAICS4 × ownership × month`

Core fields:

- `year`
- `month`
- `date` — proper R `Date`, using first day of month
- `puma`
- `puma_name`
- `naics4`
- `industry`
- `ownership_code`
- `ownership_title`
- `employment`
- `employment_suppressed`
- `confidential`

Suppressed values should be stored as `NA`, not zero.

The EDD confidentiality flag is the authoritative suppression indicator. In the cleaned employment panel, QA confirmed that all missing employment observations correspond to suppressed cells and all observed employment values are unsuppressed.

### Quarterly wages/establishments panel

Unit of observation:

`PUMA × NAICS4 × ownership × quarter`

Core fields:

- `year`
- `quarter`
- `quarter_date` — first day of quarter
- `puma`
- `puma_name`
- `naics4`
- `industry`
- `ownership_code`
- `ownership_title`
- `establishments`
- `wages`
- `suppressed`
- `confidential`

Employment and wages/establishments should remain separate master datasets because their source frequencies differ.

## Primary Outcomes

The main jobs outcome is:

- Monthly total employment by PUMA and industry

Secondary labor-market outcomes may include:

- Quarterly total wages
- Quarterly establishments
- Employment per establishment
- Average wages per worker, constructed carefully using quarterly wage totals and appropriate employment denominators

The primary causal analysis should focus first on employment. Wage and establishment responses are complementary outcomes.

## Industry Interpretation

The 4-digit industries are broader than the exact set of directly covered workers.

### Airport

`4811` and `4881` capture major airport-related employment categories, but not every worker in these industries is necessarily covered by the LAX minimum wage ordinance, and some workers may perform work outside LAX.

The key identification issue is therefore geographic exposure to LAX within each PUMA, rather than occupational composition.

### Hotels

`7211` is Traveler Accommodation, which is broader than the exact statutory set of covered hotels and includes traveler accommodation beyond treated non-union hotels above the room threshold.

For hotel employment effects, treatment intensity should therefore be constructed using hotel-level CoStar information and mapped into PUMAs.

## Treatment Exposure Measures

Treatment should not simply be assigned as a binary PUMA indicator unless the geography maps cleanly to the policy.

Preferred exposure measures should be constructed separately and merged onto the EDD panel.

### Airport exposure

Potential measures include:

- Indicator for PUMAs containing or immediately surrounding LAX
- Share of airport-related establishments/employment plausibly tied to LAX
- Distance or spatial proximity to LAX
- Other continuous measures of airport exposure if available

The most defensible measure should reflect that NAICS 4811/4881 establishments in distant LA County PUMAs are unlikely to be directly exposed to the LAX ordinance.

### Hotel exposure

Using CoStar property data, construct PUMA-level measures such as:

- Number of treated hotels
- Number of union-exempt hotels
- Number of small exempt hotels
- Treated hotel rooms
- Total hotel rooms
- Share of hotel rooms in treated properties
- Share of hotels treated

A useful continuous treatment measure is:

`treated hotel rooms / total hotel rooms in PUMA`

This handles PUMAs that cross Los Angeles city boundaries better than a simple city indicator.

## Control Groups

### Airport analysis

Potential controls should come from low- or zero-exposure PUMAs within Los Angeles County, with careful attention to whether they have comparable pre-trends in the same NAICS industries.

The analysis can also exploit the presence of two airport-related industries, although these should not automatically be treated as interchangeable controls.

### Hotel analysis

Preferred controls include:

1. Small hotels within the City of Los Angeles that are below the statutory room threshold.
2. Unionized hotels within Los Angeles that are exempt from the wage law.
3. Neighboring-city hotels as secondary controls or robustness checks.

Same-city controls are attractive because they share local shocks such as LADWP utility-price changes, city tourism conditions, and other Los Angeles-specific policies.

## Empirical Strategy

The first stage of analysis should be descriptive and diagnostic.

### Descriptive work

Produce:

- Monthly employment trends by industry
- Employment trends by PUMA
- Employment indexed to a common pre-policy baseline
- Maps of employment levels and treatment intensity
- Pre-policy trend comparisons between more- and less-exposed PUMAs
- Counts of suppressed observations by PUMA, industry, and ownership

### Baseline causal specifications

Candidate specifications include difference-in-differences or continuous-treatment models of the form:

`employment_{p,t} = FE + beta * exposure_p × post_t + error_{p,t}`

where `exposure_p` may be binary or continuous.

Preferred fixed effects should absorb:

- PUMA-invariant differences
- common month-year shocks
- potentially industry-specific time shocks when pooling multiple NAICS industries

Event-study specifications should be used to inspect:

- pre-trends
- anticipation
- immediate post-policy response
- whether September 2025 should be treated separately from later post months

Because only one post quarter is currently available, inference should be framed as short-run and estimates should be interpreted cautiously.

## Ownership

Ownership categories should remain preserved in the master data.

For hotels, private ownership will likely dominate.

For airport industries, public/government ownership may matter substantively. The main analysis should first inspect employment separately by ownership before deciding whether to aggregate.

Do not permanently collapse ownership categories during cleaning.

## Suppression and Missing Data

EDD suppresses cells for confidentiality, particularly where there are few establishments.

Rules:

- Suppressed values are `NA`, never zero.
- Preserve explicit suppression flags.
- Do not interpret absence of a reported value as zero employment.
- Check suppression rates by:
  - NAICS
  - PUMA
  - ownership
  - time

Suppression is likely more severe for airport industries in PUMAs with few relevant establishments.

## Occupational Composition

Occupational composition is not required for the primary ex post jobs analysis.

Earlier ex ante policy work used national occupational composition mapped to local industry employment to estimate the number of workers directly affected. That remains useful for interpreting treatment intensity or translating reduced-form employment effects into effects on directly covered workers.

However, the primary ex post estimand is the effect on total industry employment, so NAICS-level employment is the preferred outcome without additional occupational assumptions.

## Related Data Sources

Other project datasets that may be useful for later integration include:

- CoStar hotel property characteristics and performance
- Hotel treatment/exemption status
- Los Angeles TOT data
- Citywide STR TOT data
- Airport passenger flows from BTS T-100
- Airline fare data from BTS DB1B/DB1C
- LADWP and neighboring utility service-territory/rate information

These should be merged only as needed for specific analyses rather than incorporated into the cleaned EDD master panel.

## Suggested Analysis Order

1. Finish cleaning and validating the 2025 Q4 EDD update.
2. Confirm monthly employment completeness through December 2025.
3. Confirm quarterly wages and establishments through 2025 Q4.
4. Summarize suppression patterns.
5. Plot raw employment trends for each NAICS.
6. Inspect private vs government ownership separately.
7. Map employment by PUMA.
8. Construct airport exposure measures.
9. Construct hotel treatment intensity using CoStar.
10. Examine pre-policy balance and trends.
11. Estimate simple before/after and DiD specifications.
12. Estimate event-study specifications.
13. Test alternative exposure definitions.
14. Add wage and establishment outcomes.
15. Conduct sensitivity analyses for anticipation and treatment timing.
16. Treat estimates as short-run effects until additional post-2025 data become available.

## Coding Principles

The analysis code should:

- Keep raw data immutable.
- Separate cleaning from analysis.
- Avoid hard-coding specific PUMAs where possible.
- Preserve NAICS and ownership identifiers.
- Use proper `Date` objects.
- Preserve suppression indicators.
- Store treatment/exposure measures in separate lookup tables.
- Make figures and regression tables reproducible from scripts.
- Avoid silently converting suppressed or missing values to zero.
- Keep descriptive, main-regression, and robustness scripts separate.
