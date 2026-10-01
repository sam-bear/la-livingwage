"""Build a vector PDF comparing archived and updated hotel figures.
Run from the repository root. Inputs and page order are recorded in manifest.csv.
"""
import csv
from pathlib import Path
import subprocess

out = Path('output/hotel-figure-comparison')
archive = Path('archive:pre-Sep2026-costar-rerun:')
out.mkdir(parents=True, exist_ok=True)
figures = [
 ('fig4-ts-revpar-adr', 'Hotel performance: ADR and RevPAR time series'),
 ('fig4-pooled-est', 'Hotel performance: pooled policy estimates'),
 ('fig5-impact-hetero', 'Hotel performance: differences across groups'),
 ('figX_ADRRevPAR_yoy_full_plot', 'Hotel performance: year-over-year changes'),
 ('ADR_yoy_sep25mar26_plot', 'Hotel room prices: year-over-year changes'),
 ('fig1_IndusryBackgroundTS_plot', 'Hotel industry background'),
 ('TOT-raw', 'Hotel tax revenue: citywide TOT'),
 ('fig2-barplot-summary', 'Hotel sample: pre-policy comparison'),
 ('figAX-4group-pooled-est', 'Sensitivity: four-group pooled estimates'),
 ('figAX-eventStudyReg', 'Hotel performance: event-study estimates'),
 ('figAX-pooled-est-byControls', 'Sensitivity: alternative controls'),
 ('figAX-pooled-est-byTreatControls', 'Sensitivity: treatment and control groups'),
 ('FigAX-differentOutcomes', 'Sensitivity: alternative hotel outcomes'),
 ('EDD-hotel-employment-index', 'Hotel employment: index'),
 ('EDD-hotel-quarterly-outcomes-index', 'Hotel employment: quarterly outcomes'),
 ('EDD-hotel-regression-coefficients', 'Hotel employment: regression estimates'),
 ('EDD-hotel-employment-event-study', 'Hotel employment: event study'),
 ('EDD-LA-city-hotel-employment-allocated', 'Los Angeles hotel employment: allocated series'),
 ('Map_LA_treatedVSuntreated_raw', 'Hotel locations: treated and comparison hotels'),
 ('Map_LA_treatedVSuntreated_analysisSample_raw', 'Hotel locations: analysis sample'),
 ('Map_LA_treatedVSuntreated_downtown_raw', 'Hotel locations: downtown'),
 ('Map_LA_treatedVSuntreated_westside_raw', 'Hotel locations: westside'),
 ('Map_LA_treatedVSuntreated_lax_raw', 'Hotel locations: LAX area'),
 ('PUMA-LA-city-border-CoStar-reference', 'Employment geography: city boundary and hotels'),
 ('PUMA-countywide-hotel-treatment', 'Employment geography: countywide treatment'),
 ('PUMA-hotel-room-treatment', 'Employment geography: hotel room treatment'),
 ('PUMA-hotel-room-treatment-histograms', 'Employment geography: treatment distributions'),
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
    assert current.is_file() and previous.is_file(), stem
    for p in (current, previous):
        info = subprocess.check_output(['pdfinfo', str(p)], text=True)
        assert any(line.split() == ['Pages:', '1'] for line in info.splitlines()), p
    manifest.append(dict(page=page, title=title, previous=str(previous), updated=str(current)))
    if page > 1:
        tex.append(r'\newpage')
    tex.append(r'{\fontsize{23}{27}\selectfont\bfseries ' + title + r'}\par\vspace{0.12in}')
    tex.append(r'\begin{tabular}{@{}p{9.4in}@{\hspace{0.3in}}p{9.4in}@{}}')
    tex.append(r'{\fontsize{17}{20}\selectfont Previous version} & {\fontsize{17}{20}\selectfont Updated version} \\[0.07in]')
    tex.append(r'\includegraphics[width=9.4in,height=9.5in,keepaspectratio]{\detokenize{' + str(previous) + r'}} & ' +
               r'\includegraphics[width=9.4in,height=9.5in,keepaspectratio]{\detokenize{' + str(current) + r'}} \\')
    tex.append(r'\end{tabular}\par\vfill')
    tex.append(r'{\fontsize{11}{14}\selectfont Original axes retained; scales may differ between versions.\hfill ' + str(page) + ' / ' + str(len(figures)) + r'}')
tex.append(r'\end{document}')
(out / 'hotel-figures-before-after.tex').write_text('\n'.join(tex))
with (out / 'manifest.csv').open('w') as f:
    writer = csv.DictWriter(f, fieldnames=manifest[0].keys())
    writer.writeheader()
    writer.writerows(manifest)
subprocess.run(['pdflatex', '-interaction=nonstopmode', '-halt-on-error',
                '-output-directory=' + str(out), str(out / 'hotel-figures-before-after.tex')],
               check=True, stdout=subprocess.DEVNULL)
print(f'Created {len(figures)} comparisons: {out / "hotel-figures-before-after.pdf"}')
