# TOT extension, October 1, 2026

Input: TOT/INC0959940 - Monthly TOT Revenue by Council District for CY 2023-2026 As Of 20260928.xlsx. Script: script/4-process-TOT.R.

Uses Grand Total (including interest, penalties, fees and overpayments), consistent with the previous script; sums all 15 council districts. All four sheet totals reconcile to their reported annual totals within one cent. No duplicate district-months or gaps; all 45 months have 15 districts.

Figure: figures/raw/TOT-raw.pdf, January 2023–August 2026 levels and January 2024–August 2026 year-over-year changes. Levels now use continuous dates so 2026 post-policy months follow 2025. September 2026 is retained in monthly-tot.csv but excluded from the figure because the extract is dated September 28, before month-end. These are reported tax receipts, not a direct measure of stays or a causal policy estimate.

Historical-revisions.csv compares the new extract with the original rounded-dollar hotel_TOT_2023_2025.csv. Differences are rounding-sized: maximum absolute monthly percentage difference about 0.0000103% ($2.58 in June 2025).

August 2026 receipts: $27,079,503, about 12.0% above August 2025. July: $26,967,064, about 12.7% above July 2025.

Approved prior figure retained under archive:pre-Sep2026-costar-rerun:/figures/raw/TOT-raw.pdf. Added to the hotel before/after comparison, page 7. Existing manually cleaned figures are unchanged.
