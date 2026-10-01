# Hotel figures: previous and updated versions

[Open the 26-page comparison PDF](hotel-figures-before-after.pdf).

Every changed hotel PDF currently in `figures/raw` is included once, including
employment figures and maps. Airport figures are excluded. Previous versions
come from `archive:pre-Sep2026-costar-rerun:/figures/raw`. Updated versions come
from `figures/raw`. `manifest.csv` records the exact pair on each page.

Previous versions are on the left; updated versions are on the right. Source
PDFs are embedded directly, preserving vector text and graphics. No source
figures, axes, data, or annotations were altered. Original axes can differ
between versions, as noted on every page.

All 26 pages rendered successfully and were inspected in a contact sheet; the
pooled-estimate comparison was also inspected at larger scale. The PDF build
had no overflow warnings. Coverage was checked against the changed raw figures.

## Review before sharing

This packet is a comparison, not a finding that all results are unchanged.
The pooled estimates move, some time windows and axis ranges differ markedly,
and the location maps show visibly different hotel-marker/boundary layers.
In particular, inspect the downtown, westside, and LAX map comparisons before
using them to support a claim of little change. These differences are present
in the source figures, not introduced by the comparison layout.

## Rebuild

From the repository root:

```sh
python3 script/hotel-analysis/compare-archived-figures.py
```

Requires `pdfinfo` and `pdflatex`. Page ordering and titles are explicit in the
script. The generated `.tex` file is retained for layout edits.

## Time-series correction

The comparison was rebuilt after extending the focused hotel price chart through
August 2026 and correcting the full YoY window, indexed-chart shading, and
clipped indexed values. See [coverage and plotting notes](../hotel-time-series/README.md).
The separate citywide background chart still awaits its source workbook's sync
and coverage check; its updated panel is the earlier rerun, not a newly verified
extension through August.

The hotel-performance event-study page was subsequently corrected too: a stale
January 2026 estimation cutoff was removed, and the updated panel now includes
all post-policy months through August 2026. The pooled-estimate panel had already
included those months and was not changed by this correction.
