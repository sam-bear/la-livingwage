# Airport figures: previous and updated

[Seven-page comparison PDF](airport-figures-before-after.pdf), with previous
versions on the left and updated/latest available versions on the right.
`manifest.csv` identifies each source PDF. The comparison embeds existing PDFs
without changing their data or axes.

Includes two passenger figures, three fare figures, and two employment figures.
Passenger and fare updates run through June 2026. Fare updates also incorporate
the previously documented journey-selection correction starting July 2025;
these are not date-only changes. Employment coverage remains December 2025,
so those pages show unchanged coverage rather than a new EDD extension.

During preparation, passenger YoY was changed to the previously discussed
continuous January 2025–June 2026 timeline. Its values are unchanged. The
comparison uses that version. No other analyses were rerun for this packet.

All seven pages rendered successfully and were visually reviewed. Rebuild:

```sh
python3 script/flight-analysis/compare-airport-figures.py
```
