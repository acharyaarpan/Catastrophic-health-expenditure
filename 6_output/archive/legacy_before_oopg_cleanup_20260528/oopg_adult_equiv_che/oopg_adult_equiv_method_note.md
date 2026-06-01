# OOPG CHE on an Adult-Equivalent Basis

This is a separate OOPG-only branch and does not overwrite the main household analysis.

Adult equivalents use the existing project scale: `(n_adults + 0.5 * n_children)^0.75`, where adults are age 15+ and children are below age 15.

The total-expenditure CHE share is `(oopg / adult_equiv) / ((nominal_total_cons_month + oopg) / adult_equiv)`. This simplifies exactly to the household share `oopg / (nominal_total_cons_month + oopg)`.

The nonfood CHE share is analogous: `(oopg_real / adult_equiv) / ((nf_real_hh_mo + oopg_real) / adult_equiv)`.

Therefore, adult-equivalent scaling changes the units of the amounts, but it does not change the CHE percentage, headcount, overshoot, or household classification when both numerator and denominator are scaled consistently.

Main result file: `oopg_adult_equiv_che_summary.csv`.
