---
name: code-style-r
description: >
  Sam's R coding style and structural conventions for academic research code.
  Use whenever writing, editing, refactoring, or reviewing R code (.R files) —
  including analysis scripts, helper functions, regression/modeling code, and
  plots. Covers clarity-over-cleverness rules, when to write a function (and
  when not to), base R vs ggplot, tidyverse vs data.table/duckdb, and named
  anti-patterns that LLM-generated R tends to fall into.
---

# R style for academic research code

**The ultimate goal is replicability by other researchers.** Every style choice
below serves that end. The test to apply constantly: could an outside researcher
with the data clone this repo, run it top to bottom, and get the same numbers and
figures — without asking Sam anything?

That makes the governing question: **can a reader (including future Sam, a
referee, or a coauthor) follow what this does without reverse-engineering it?**
Research code is read far more often than it is run, and its job is to be
auditable. Optimize for that.

## Replicability requirements

- **Scripts must run top to bottom** in a fresh R session, in the documented
  order, with no manual intervention and no reliance on objects left in the
  environment from earlier exploration.
- **Never depend on saved session state.** Do not rely on `.RData` or a warm
  workspace to supply an object. If a script needs something, it loads or
  computes it explicitly. (`.RData` / `.Rhistory` in the repo are a hazard here —
  code that works only because a stale global is lying around will fail for
  anyone else.)
- **Set seeds explicitly** wherever anything is sampled or randomized.
- **No absolute paths outside `config.R`**; no paths that only exist on Sam's
  machine embedded in analysis scripts.
- **Document data provenance** — where each input came from, and which script
  produced each intermediate file.
- **Prefer a slow script that anyone can run** over a fast one that depends on a
  local cache, a mounted server, or a hand-run step.

## Core principles

1. **Clarity over elegance.** Never make code shorter or cleverer at the cost of
   making it harder to follow. A clever one-liner that takes two minutes to
   parse is worse than five obvious lines.

2. **Long and easy to follow beats efficient and opaque.** This is research
   code, not production. Explicit, repetitive, sequential code that a reader can
   step through is correct even when a tighter version exists. Only optimize
   when something is actually too slow to work with.

3. **Don't write functions for one-off tasks.** If a thing is done once or
   twice, write it inline. Functions are for genuine repetition. Premature
   abstraction hides the analysis inside indirection.

4. **Minimize nesting of functions inside functions.** Deeply nested definitions
   are hard to follow and hard to debug. Prefer flat, top-level, named
   functions. See anti-patterns below.

## Plotting

- **Base R by default.** Use `plot`, `lines`, `polygon`, `axis`, `mtext`, etc.
- **`ggplot2` only when base R would be substantially less convenient** —
  e.g. faceting across many panels, or complex legend/grouping logic that would
  be genuinely painful in base.
- Do not reach for ggplot reflexively because it is the common idiom. The
  default here is base.

### Axes: always draw them separately

Suppress axes in the initial call with `axes = FALSE`, then add each axis
explicitly with `axis()`. This keeps tick placement, labels, and orientation
visible and editable instead of buried in defaults.

```r
  plot(x, y, type = "n", axes = FALSE, xlab = "", ylab = "")
      axis(1)
      axis(2, las = 1)
      mtext("temperature (°C)", side = 1, line = 2.5)
      mtext("% change in u5mr", side = 2, line = 2.5)
```

Do not rely on the default axes from `plot()`. Never leave `axes = FALSE` without
the corresponding `axis()` calls.

## Compute tooling

- **`tidyverse` for small computational tasks** — light reshaping, joins on
  modest data, quick exploration. Readability wins at small scale.
- **`data.table` or `duckdb` for computationally intensive tasks** — large
  panels, heavy aggregations, anything memory-bound or slow in dplyr.
- Choose based on the size of the job, not habit.

## Anti-patterns — do not generate these

These are drawn from LLM-written code in this repo that did not meet the bar.
Recognize and avoid them.

- **Function factories / returned closures.** Do not write a function whose
  purpose is to return another function, with `force()` calls to capture
  arguments. Pass the arguments directly to a flat function instead.
  Bad: `make_X_fun_spline_multi()` in `helpers/statistical.R`.

- **Helper functions defined inside other functions**, especially ones that
  mutate the enclosing scope with `<<-`. Bad: the `add_norm()` closure inside
  `X_from_base_cum_multi()`. Use an explicit loop with a plain local variable,
  or a flat top-level helper.

- **Constructing variable/coefficient names with `sprintf()` or `paste0()` and
  matching them by regex.** This fails silently when the constructed name does
  not match reality — the exact cause of the interaction-term bug in NOTES.md
  §8. If names must be matched, match against actual `names(coef(model))` and
  **assert** the match found what you expected:
  ```r
  stopifnot(length(keep) > 0)
  stopifnot(identical(names(b), rownames(V)))
  ```

- **Dot-prefixed pseudo-private helpers** (`.normalize_names`). Not a convention
  here; just name it plainly.

- **Long runs of blank lines** (10+) left between functions from editing. One or
  two blank lines.

- **Defensive `tryCatch` / `if (!is.null(...))` scaffolding** around things that
  should simply fail loudly. Prefer failing fast — see below.

## Conventions observed in this repo

*(Inferred from Sam's own code — confirm or strike these.)*

- **Assignment** with `<-` for objects. (`=` appears in older helpers; `<-`
  preferred for new code.)
- **`snake_case`** for variables and functions.
- **All paths defined in `script/config.R`**, never hardcoded in analysis
  scripts. Add a new path there and reference the variable.
- **Fail fast on missing inputs**, at the top, with a clear message:
  ```r
  if (!dir.exists(big_data_path)) stop("big_data_path does not exist")
  ```
- **Comment-then-indent layout**: a comment sits at the outer level and the code
  it describes is indented beneath it, as a visual block.
  ```r
    #define paths
        big_data_path <- "~/BurkeLab Dropbox/projects/tmp-child-mortality/data/"
        local_data_path <- "data/"
  ```
- **Section banners** in long files: `# Spatial ------------------------------`
- **Packages loaded centrally** in `helpers/load_packages.R`, grouped by purpose
  with section banners. Add new packages to the right group there rather than
  calling `library()` mid-script.
- **Model spec parameters centralized** in `helpers/define_main_spec_parameters.R`
  so alternative specs can always be compared against the main one.
- **Numbered pipeline scripts** (`0.1_`, `0.15_`, `0.2_`, `0.3_`) run in order,
  orchestrated by `RunScripts.R`; reusable code lives in `helpers/`.

## Comments

- Comment **why**, and what a block is for — not a restatement of the syntax.
- A short comment introducing each block is expected and good.
- Keep notes about known problems next to the code, as in the "Unverified —
  uncomment as each is verified" block in `config.R`.
