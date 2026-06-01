# OOPG Catastrophic Health Expenditure in Nepal

This project prepares an OOPG-focused catastrophic health expenditure (CHE)
manuscript using Nepal Living Standards Survey IV (NLSS IV, 2022/23).

`oopg` means Section 8(B) communicable disease or injury out-of-pocket spending
reported over the past 30 days. Earlier drafts used `ghe` for this subset.
Renamed to `oopg` to avoid confusion with General Government Health Expenditure
(NHA usage).

The active project is now OOPG-only. Older combined-OOP, regression,
audit-workbook, individual-level, Word-draft, and Pen's Parade experiments are
archived and are not part of the current manuscript workflow.

## Folder Structure

```text
consumption/
|-- 0_master.do
|-- 1_data/
|   |-- 1_raw/                 raw NLSS files
|   |-- 2_clean/               active clean dataset
|   `-- archive/               older derived datasets
|-- 2_prep/
|   `-- 1_catastrophic.do      builds the OOPG base dataset
|-- 3_analysis/
|   |-- 01_oopg_che_analysis.do
|   `-- 02_build_oopg_manuscript.py
|-- 4_log/
|-- 5_documentation/
|-- 6_output/
|   |-- main_output/
|   |   `-- manuscript/
|   `-- archive/
`-- 0_archive/
```

## Active Data

Raw NLSS IV files should be placed in:

```text
1_data/1_raw/
```

The preparation script creates one active household-level benchmark dataset:

```text
1_data/2_clean/oopg_analysis_base.dta
```

This dataset keeps the OOPG variables, reconstructed consumption denominators,
adult-equivalence variables, poverty variables, weights, and basic household
covariates needed for the current manuscript.

## Active Analysis

Run the Stata pipeline from the project root:

```stata
do 0_master.do
```

This runs:

```text
2_prep/1_catastrophic.do
3_analysis/01_oopg_che_analysis.do
```

Then build the LaTeX manuscript source and figure:

```powershell
python 3_analysis\02_build_oopg_manuscript.py
```

Compile from:

```text
6_output/main_output/manuscript/code/oopg_che_manuscript.tex
```

using:

```powershell
pdflatex oopg_che_manuscript.tex
bibtex oopg_che_manuscript
pdflatex oopg_che_manuscript.tex
pdflatex oopg_che_manuscript.tex
```

## Active Outputs

```text
6_output/main_output/manuscript/
|-- oopg_che_manuscript.pdf
|-- code/
|   |-- oopg_che_manuscript.tex
|   `-- references.bib
|-- pictures/
|   `-- oopg_budget_share_curve.png
`-- tables/
    |-- oopg_incidence_intensity.csv
    |-- oopg_distribution_sensitive.csv
    |-- oopg_ctp_summary.csv
    |-- oopg_ctp_equity.csv
    |-- oopg_poverty_impact.csv
    |-- oopg_method_parameters.csv
    `-- oopg_budget_share_curve_data.csv
```

## Methods Summary

The manuscript uses three OOPG denominator approaches.

Total-expenditure CHE:

```text
oopg / (nominal_total_cons_month + oopg)
```

Nonfood CHE:

```text
oopg_real / (pcep_nonfood * hhsize / 12 + oopg_real)
```

Adult-equivalence capacity-to-pay CHE:

```text
E = (A + 0.5K)^0.75
food_nom_mo = pcep_food * paasche * hhsize / 12
x_oopg_mo = nominal_total_cons_month + oopg
food_share = food_nom_mo / x_oopg_mo
food_equiv = food_nom_mo / E
subsistence_line = weighted mean(food_equiv among 45th-55th food-share households)
subsistence_hh = subsistence_line * E
ctp_ae = x_oopg_mo - subsistence_hh if food_nom_mo >= subsistence_hh
ctp_ae = x_oopg_mo - food_nom_mo otherwise
oopg_sh_ctp_ae = oopg / ctp_ae
```

Adult equivalence is used in the capacity-to-pay approach because it adjusts
the subsistence requirement for household composition. It is not used in the
simple OOPG/total-consumption share because dividing both the numerator and
denominator by the same equivalence scale would cancel, while dividing only the
denominator would mix household-level payments with per-equivalent-adult
resources.

## Poverty Method

NLSS IV official welfare excludes health spending. The paper therefore uses:

```text
post-payment welfare = pcep
pre-OOPG welfare     = pcep + oopg_pc_ann_real
```

Official poverty is:

```text
pcep < pline
```

with individual weights. The active validation target is 20.27%. Health
payments are never subtracted from `pcep`.

## Requirements

- Stata 17 or newer
- Python packages: `pandas`, `numpy`, `matplotlib`
- MiKTeX or another LaTeX distribution with `pdflatex` and `bibtex`

## Validation Checks

The active scripts check that:

- the cleaned dataset has 9,600 households
- `pcep < pline`, individual-weighted, reproduces 20.27%
- `pcep` equals `pcep_food + pcep_nonfood` within 1 NPR
- `oopg >= 0`
- `adult_equiv > 0`
- OOPG-addback total and nonfood denominators are positive
- `pre_oopg >= pcep`
- adult-equivalence CTP threshold indicators are monotonic

## Author

Arpan Acharya
