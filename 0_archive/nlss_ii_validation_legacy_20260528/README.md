# NLSS II Validation Workspace

This folder is a separate workspace for reproducing the NLSS IV catastrophic
health expenditure workflow on NLSS II data. It is meant for validation against
your boss's parallel work, without mixing raw files, cleaned data, logs, or
outputs with the NLSS IV analysis in the project root.

## Folder Layout

```text
nlss_ii_validation/
  0_master.do
  1_data/
    1_raw/        <- add original NLSS II files here
    2_clean/      <- generated analysis dataset
    3_analysis/   <- optional intermediate analysis data
    4_tmp/        <- temporary files
  2_prep/
    0_inventory_raw.do
    1_catastrophic.do
  3_analysis/
    0_validate_clean.do
  4_log/
  5_documentation/
    nlss_ii_variable_map_template.csv
  6_output/
```

## Intended Workflow

From this folder:

```stata
do 0_master.do
```

Current status:

1. `2_prep/0_inventory_raw.do` will inventory any `.dta` files added to
   `1_data/1_raw/`.
2. `2_prep/1_catastrophic.do` is a mapping scaffold. It stops deliberately
   until we inspect NLSS II raw files and fill the survey-specific variable
   map.
3. `3_analysis/0_validate_clean.do` checks that the cleaned NLSS II dataset
   matches the canonical NLSS IV-style output schema.

Once the NLSS II prep creates `1_data/2_clean/catastrophic_health_exp.dta`,
we can port the NLSS IV descriptive, regression, CHE, poverty, Pen's Parade,
and audit scripts with only cycle-specific constants changed.

## Canonical Output Contract

The prep step should produce one household-level file:

```text
1_data/2_clean/catastrophic_health_exp.dta
```

It should preserve the same core variable names used in the NLSS IV workflow:

- household identifiers and weights: `psu_number`, `hh_number`, `hhs_wt`, `ind_wt`
- welfare and poverty: `pcep`, `pcep_food`, `pcep_nonfood`, `pline`, `fpline`
- OOP scopes: `oopg`, `oop`, `oopg_ann`, `oop_ann`, `oopg_pc_ann_real`,
  `oop_pc_ann_real`, `oopg_real`, `oop_real`
- denominators: `tot_real_hh_mo`, `nf_real_hh_mo`, `totexp_real_hh_mo`,
  `ctp_real_hh_mo`
- CHE shares, flags, and overshoots for `oopg` and `oop`
- poverty variables: `pre_oopg`, `pre_oop`

Do not force NLSS II into the NLSS IV definitions if the source questionnaire
does not support them. In particular, confirm the health spending recall window,
whether annual/chronic spending exists, and whether the official welfare
aggregate includes or excludes health spending before estimating final results.
