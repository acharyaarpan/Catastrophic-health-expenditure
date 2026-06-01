# Individual-Level CHE: OOPG-Only Addback Sensitivity

This branch does not overwrite the household-level CHE pipeline or the earlier individual-level full-OOP addback branch.

Health spending comes from person records in S08.dta. S08 is merged to S01.dta, and only official household members are retained (`q01_09 == 1`). This gives 38,101 individual records.

The numerator is individual health spending: `oopg_i = q08_14_i` and `oop_i = q08_14_i + q08_06_i / 12`.

The denominator adds back only individual OOPG/general health spending: `pcep / 12 + oopg_i_real` for total consumption and `pcep_nonfood / 12 + oopg_i_real` for nonfood consumption.

Each individual record is weighted by `person_wt = hhs_wt`. The OOP numerator uses a denominator that does not add back NCD spending, so OOP shares are expected to be larger than in the full-OOP addback branch.
