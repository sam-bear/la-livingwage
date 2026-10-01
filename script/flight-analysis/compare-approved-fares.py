"""Recover plotted values from the original R PDF and compare to the audit CSV.

Uses the PDF's vector paths and tick locations, not image digitization. Values
are approximate because R rounded PDF coordinates to two decimal places.
Run from the repository root after audit-original-fares.R.
"""
import csv
from pathlib import Path
import re
import zlib

audit = Path("output/airport-fare-audit")
with (audit / "reconstructed-quarterly-fares.csv").open() as f:
    reconstructed = {(r["route"], int(r["YEAR"]), int(r["QUARTER"])): float(r["fare"])
                     for r in csv.DictReader(f)}
number = r"[0-9.]+"
figures = [
    ("Flight-Prices-lax.pdf", 12, 2023, "fare"),
    ("Flight-Prices-lax-yoy.pdf", 8, 2024, "yoy_percent"),
    ("Flight-Prices-lax-yoy-2025.pdf", 4, 2025, "yoy_percent"),
]
results = []
stream_checks = []
for filename, n_points, start_year, outcome in figures:
    streams = []
    source = Path("figures/raw") / filename
    for match in re.finditer(rb"stream\r?\n(.*?)endstream", source.read_bytes(), re.S):
        try:
            streams.append(zlib.decompress(match.group(1)).decode("latin1"))
        except zlib.error:
            continue
    content = next(s for s in streams if "(LAX-LAS)" in s)
    rebuilt_streams = []
    for match in re.finditer(rb"stream\r?\n(.*?)endstream", (audit / filename).read_bytes(), re.S):
        try:
            rebuilt_streams.append(zlib.decompress(match.group(1)).decode("latin1"))
        except zlib.error:
            continue
    stream_checks.append(dict(figure=filename, identical_graphics_streams=streams == rebuilt_streams))
    path_pattern = rf"({number} {number} m\n(?:{number} {number} l\n){{{n_points-1}}})S"
    paths = list(re.finditer(path_pattern, content))
    assert len(paths) == 4, "Expected four route line paths"
    for index, (route, path) in enumerate(zip(["LAS", "SEA", "SFO", "SLC"], paths)):
        block_end = paths[index + 1].start() if index < 3 else len(content)
        block = content[path.end():block_end]
        points = [(float(x), float(y)) for x, y in
                  re.findall(rf"({number}) ({number}) [ml]", path.group(1))]
        ticks = []
        for x1, y1, x2, y2 in re.findall(
                rf"({number}) ({number}) m ({number}) ({number}) l\s+S", block):
            x1, y1, x2, y2 = map(float, (x1, y1, x2, y2))
            if y1 == y2 and x2 < x1 < points[0][0]:
                ticks.append(y1)
        labels = [float(v) for v in re.findall(r"Tm \((-?[0-9]+)%?\) Tj", block)]
        expected = list(range(100, 221, 20)) if outcome == "fare" else list(range(-10, 41, 10))
        assert len(ticks) == len(expected) and labels[:len(expected)] == expected
        slope = (expected[-1] - expected[0]) / (ticks[-1] - ticks[0])
        for quarter_index, (_, y) in enumerate(points):
            year, quarter = start_year + quarter_index // 4, quarter_index % 4 + 1
            plotted = expected[0] + (y - ticks[0]) * slope
            rebuilt = reconstructed[(route, year, quarter)]
            if outcome == "yoy_percent":
                rebuilt = 100 * (rebuilt / reconstructed[(route, year - 1, quarter)] - 1)
            results.append(dict(figure=filename, outcome=outcome, route=route, year=year,
                                quarter=quarter, approved_pdf_value_approx=plotted,
                                reconstructed_value=rebuilt, difference=rebuilt-plotted))
with (audit / "approved-pdf-comparison.csv").open("w") as f:
    writer = csv.DictWriter(f, fieldnames=results[0].keys())
    writer.writeheader()
    writer.writerows(results)
with (audit / "approved-pdf-stream-checks.csv").open("w") as f:
    writer = csv.DictWriter(f, fieldnames=stream_checks[0].keys())
    writer.writeheader()
    writer.writerows(stream_checks)
for check in stream_checks:
    print(check)
for filename, _, _, outcome in figures:
    print(filename, outcome, "maximum absolute difference:",
          max(abs(r["difference"]) for r in results if r["figure"] == filename))
for r in results:
    if abs(r["difference"]) > 0.03:
        print(r)
assert all(check["identical_graphics_streams"] for check in stream_checks), \
    "Reconstructed graphics differ from at least one approved raw PDF"
