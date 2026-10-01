# AllHotels city roster reconciliation

Checked September 29, 2026 against the locally available Sep2026 `AllHotels_LA_hotelinfo_raw.xlsx`, saved `HotelsLACInfo_allSizeallTreatStatus.rds`, reviewed `hotel_countywide_puma_crosswalk.rds`, and `output/costar_puma_treatment_manual_review_filled.csv`.

The raw workbook contains 491 distinct properties. It is an input, not a final corrected roster. The hotel processing script adds properties from treatment/control aggregate rosters and applies the council-district city boundary; its saved city roster contains 477 properties: 491 minus 24 plus 10.

- `remove-from-raw-city-selection.csv`: 24 raw properties excluded by the city boundary in the hotel pipeline. Of these, 23 also occur in the county crosswalk and all 23 are outside the city there; AKA West Hollywood is absent from that crosswalk.
- `add-to-match-clean-city-roster.csv`: 10 additions needed to reproduce the saved city roster. This is a reconciliation list, not a fresh verification of hotel operations.
- `clean-city-roster-477.csv`: full saved city roster for matching property IDs in CoStar.

All 48 manually reviewed properties marked in scope and inside the city are in the raw workbook. Neither manually excluded property (Canoga Hotel, ID 7349354; Sea Rock Inn, ID 4493967) is in the raw workbook. Manual notes excluding some small properties from regression controls do not exclude them from an all-city descriptive series.

All 461 in-scope city properties in the reviewed county roster occur in both the raw workbook and the saved city roster. The saved city roster also has 16 properties absent from the county extract: six already in the raw workbook and the ten additions. Absence from that extract alone is not an exclusion decision.

For a report export, use the corrected city geography and retain all treatment statuses. Before adopting all 477 as an operating-hotel selection, resolve the ten additions' current and historical reporting availability: Cameo Hotel, Retan Hotel, The Gilbert Hotel, and Daimaru Hotel are marked Converted; JJ Grand Hotel is Under Renovation. A historical citywide time series can legitimately include hotels while they operated, even if now converted or closed. Matching the existing roster does not establish that every hotel currently operates or reports performance data. Record the export's reporting coverage and treatment of openings/closures.

No source workbook, roster, regression, or figure was changed by this audit.
