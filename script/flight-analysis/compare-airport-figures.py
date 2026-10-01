"""Build a vector PDF comparing archived and updated airport figures.
Run from the repository root. Inputs and page order are recorded in manifest.csv.
"""
import csv
from pathlib import Path
import subprocess

out = Path('output/airport-figure-comparison')
archive = Path('archive:pre-Sep2026-costar-rerun:')
out.mkdir(parents=True, exist_ok=True)
figures = [
 ('FigX1-yoy-passengers-lax', 'LAX passenger volume: year-over-year change'),
 ('FigX1-levels-passengers-lax', 'LAX passenger volume: monthly levels'),
 ('Flight-Prices-lax', 'LAX fares: quarterly levels'),
 ('Flight-Prices-lax-yoy', 'LAX fares: year-over-year changes'),
 ('Flight-Prices-lax-yoy-2025', 'LAX fares: recent year-over-year changes'),
 ('EDD-LAX-PUMA-airport-employment', 'LAX-area employment: unchanged through December 2025'),
 ('EDD-LAX-vs-Burbank-PUMA-airport-employment', 'Airport-area employment: LAX and Burbank'),
]

manifest = []
tex = [r'''\documentclass{article}
\usepackage[paperwidth=20in,paperheight=12in,margin=0.45in]{geometry}
\usepackage{graphicx}
\usepackage[T1]{fontenc}
\usepackage{helvet}
\renewcommand{\familydefault}{\sfdefault}
\pagestyle{empty}
\setlength{\parindent}{0pt}
\begin{document}
''']
for page, (stem, title) in enumerate(figures, 1):
    current = Path('figures/raw') / (stem + '.pdf')
    previous = archive / current
    note = "Passenger series extends through June 2026; original axes retained."
    if stem.startswith("Flight-Prices"):
        name = stem.replace("yoy-2025", "yoy-2025-onward") + ".pdf"
        current = Path("output/airport-fare-audit/extended-public") / name
        note = "Fares: extension through Q2 2026 plus corrected journey selection from July 2025; original axes retained."
    if stem.startswith("EDD-"):
        note = "Employment coverage is unchanged: January 2023-December 2025. No newer EDD period is available in this analysis."
    assert current.is_file() and previous.is_file(), stem
    for p in (current, previous):
        info = subprocess.check_output(['pdfinfo', str(p)], text=True)
        assert any(line.split() == ['Pages:', '1'] for line in info.splitlines()), p
    manifest.append(dict(page=page, title=title, previous=str(previous), updated=str(current)))
    if page > 1:
        tex.append(r'\newpage')
    tex.append(r'{\fontsize{23}{27}\selectfont\bfseries ' + title + r'}\par\vspace{0.12in}')
    tex.append(r'\begin{tabular}{@{}p{9.4in}@{\hspace{0.3in}}p{9.4in}@{}}')
    tex.append(r'{\fontsize{17}{20}\selectfont Previous version} & {\fontsize{17}{20}\selectfont Updated / latest available} \\[0.07in]')
    tex.append(r'\includegraphics[width=9.4in,height=9.5in,keepaspectratio]{\detokenize{' + str(previous) + r'}} & ' +
               r'\includegraphics[width=9.4in,height=9.5in,keepaspectratio]{\detokenize{' + str(current) + r'}} \\')
    tex.append(r'\end{tabular}\par\vfill')
    tex.append(r'{\fontsize{11}{14}\selectfont ' + note + r'\hfill ' + str(page) + ' / ' + str(len(figures)) + r'}')
tex.append(r'\end{document}')
(out / 'airport-figures-before-after.tex').write_text('\n'.join(tex))
with (out / 'manifest.csv').open('w') as f:
    writer = csv.DictWriter(f, fieldnames=manifest[0].keys())
    writer.writeheader()
    writer.writerows(manifest)
subprocess.run(['pdflatex', '-interaction=nonstopmode', '-halt-on-error',
                '-output-directory=' + str(out), str(out / 'airport-figures-before-after.tex')],
               check=True, stdout=subprocess.DEVNULL)
print(f'Created {len(figures)} comparisons: {out / "airport-figures-before-after.pdf"}')
