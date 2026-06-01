# Individual-Level CHE Exploratory Branch

This branch does not overwrite the household-level CHE pipeline.

Health spending comes from person records in S08.dta. S08 is merged to S01.dta, and only official household members are retained (`q01_09 == 1`). This gives 38,101 individual records, matching the sum of `hhsize` in poverty.dta.

The numerator is individual health spending: `oopg_i = q08_14_i` and `oop_i = q08_14_i + q08_06_i / 12`. Amounts are deflated using the household Paasche index.

The denominator is official per-capita consumption: `pcep / 12` for total consumption and `pcep_nonfood / 12` for nonfood consumption. The primary denominator adds individual real OOP back, matching the health-including logic used in the household analysis.

Each individual record is weighted by `person_wt = hhs_wt`. Do not use `ind_wt` on person-level records because `ind_wt = hhs_wt * hhsize` is for household-level files.
