*------------------------------------------------------------------------------*
*        OOPG CHE Sensitivity: Adult-Equivalent Basis, Separate Output          *
/*

    Author:             Arpan / Codex
    Date created:       27th May 2026

    Purpose:
        Run a separate OOPG-only catastrophic health expenditure analysis using
        adult-equivalent scaled OOPG and adult-equivalent scaled consumption.

        This does not overwrite the main household CHE pipeline. Because both
        the numerator and denominator are divided by the same adult-equivalence
        scale, the resulting budget share is mathematically identical to the
        household-level OOPG share. The script reports that check explicitly.

    Output:
        - 6_output/main_output/oopg_adult_equiv_che/
          oopg_adult_equiv_che_summary.csv
        - 6_output/main_output/oopg_adult_equiv_che/
          oopg_adult_equiv_equivalence_check.csv
        - 6_output/main_output/oopg_adult_equiv_che/
          oopg_adult_equiv_method_note.md
        - 4_log/14_oopg_adult_equiv_che.log
*/
*------------------------------------------------------------------------------*

version 17
clear all
macro drop _all
cap log close
set more off

if "`c(username)'" == "Arpan Acharya" {
    global workspace "C:/Users/Arpan Acharya/OneDrive - HERD/Documents/Personal/CIH-project"
}

if "`c(username)'" == "ACER" {
    global workspace "D:/Projects/CIH-project/consumption"
}

if "`c(username)'" == "Kapil Pokhrel" {
    global workspace "C:/Users/iprad/OneDrive/Documents/GitHub/NLSSiv_consumption"
}

if "$workspace" == "" & fileexists("D:/Projects/CIH-project/consumption/0_master.do") {
    global workspace "D:/Projects/CIH-project/consumption"
}

global data             "$workspace/1_data"
global data_clean       "$data/2_clean"
global log              "$workspace/4_log"
global tab              "$workspace/6_output/main_output"
global out_ae           "$tab/oopg_adult_equiv_che"

cap mkdir "$tab"
cap mkdir "$out_ae"

local dofilename "14_oopg_adult_equiv_che"
log using "$log/`dofilename'.log", replace


*==============================================================================*
*     SECTION 1: SETUP                                                         *
*==============================================================================*

use "$data_clean/catastrophic_health_exp.dta", clear

assert _N == 9600
assert adult_equiv > 0
assert oop >= oopg
assert nominal_total_cons_month > 0
assert ctp_real_oopgadd_hh_mo > 0

gen double ae_oopg_mo = oopg / adult_equiv
gen double ae_oopg_real_mo = oopg_real / adult_equiv
gen double ae_nominal_cons_mo = nominal_total_cons_month / adult_equiv
gen double ae_nf_real_mo = nf_real_hh_mo / adult_equiv

gen double ae_totexp_oopgadd_mo = ae_nominal_cons_mo + ae_oopg_mo
gen double ae_ctp_oopgadd_mo = ae_nf_real_mo + ae_oopg_real_mo

gen double ae_oopg_sh_tot = ae_oopg_mo / ae_totexp_oopgadd_mo
gen double ae_oopg_sh_nf = ae_oopg_real_mo / ae_ctp_oopgadd_mo

label variable ae_oopg_mo          "OOPG per adult equivalent, monthly nominal NPR"
label variable ae_oopg_real_mo     "OOPG per adult equivalent, monthly real NPR"
label variable ae_nominal_cons_mo  "Reconstructed nominal consumption per adult equivalent, monthly NPR"
label variable ae_nf_real_mo       "Real nonfood consumption per adult equivalent, monthly NPR"
label variable ae_totexp_oopgadd_mo "AE total denominator: nominal consumption plus OOPG"
label variable ae_ctp_oopgadd_mo   "AE nonfood denominator: real nonfood plus OOPG"
label variable ae_oopg_sh_tot      "OOPG AE share of reconstructed nominal total consumption plus OOPG"
label variable ae_oopg_sh_nf       "OOPG AE share of real nonfood consumption plus OOPG"

gen double diff_tot_share = ae_oopg_sh_tot - oopg_sh_tot
gen double diff_nf_share = ae_oopg_sh_nf - oopg_sh_nf

summ diff_tot_share, meanonly
local max_abs_tot = max(abs(r(min)), abs(r(max)))
summ diff_nf_share, meanonly
local max_abs_nf = max(abs(r(min)), abs(r(max)))

assert abs(diff_tot_share) < 1e-10 if !missing(diff_tot_share)
assert abs(diff_nf_share) < 1e-10 if !missing(diff_nf_share)

foreach z in 5 10 15 20 25 40 {
    local cut = `z' / 100
    gen byte ae_che_oopg_tot`z' = ae_oopg_sh_tot > `cut' ///
        if !missing(ae_oopg_sh_tot)
    gen double ae_over_oopg_tot`z' = max(ae_oopg_sh_tot - `cut', 0) ///
        if !missing(ae_oopg_sh_tot)
}

foreach z in 15 25 40 {
    local cut = `z' / 100
    gen byte ae_che_oopg_nf`z' = ae_oopg_sh_nf > `cut' ///
        if !missing(ae_oopg_sh_nf)
    gen double ae_over_oopg_nf`z' = max(ae_oopg_sh_nf - `cut', 0) ///
        if !missing(ae_oopg_sh_nf)
}

foreach z in 10 20 {
    assert ae_che_oopg_tot`z' == che_oopg_tot`z' ///
        if !missing(ae_che_oopg_tot`z', che_oopg_tot`z')
}
foreach z in 25 40 {
    assert ae_che_oopg_nf`z' == che_oopg_nf`z' ///
        if !missing(ae_che_oopg_nf`z', che_oopg_nf`z')
}


*==============================================================================*
*     SECTION 2: CHE SUMMARY                                                   *
*==============================================================================*

tempname summ
tempfile summdata
postfile `summ' str10 weight str5 scope str10 denominator double threshold ///
    str26 che_variable str26 overshoot_variable double headcount ///
    double headcount_se double overshoot double overshoot_se double mpo ///
    using `summdata', replace

foreach wt in hhs_wt ind_wt {
    svyset psu_number [pw = `wt']

    foreach z in 5 10 15 20 25 40 {
        quietly svy: mean ae_che_oopg_tot`z' ae_over_oopg_tot`z'
        local h = _b[ae_che_oopg_tot`z']
        local hse = _se[ae_che_oopg_tot`z']
        local o = _b[ae_over_oopg_tot`z']
        local ose = _se[ae_over_oopg_tot`z']
        local mpo = cond(`h' > 0, `o' / `h', .)
        post `summ' ("`wt'") ("oopg") ("total_ae") (`z' / 100) ///
            ("ae_che_oopg_tot`z'") ("ae_over_oopg_tot`z'") ///
            (`h') (`hse') (`o') (`ose') (`mpo')
    }

    foreach z in 15 25 40 {
        quietly svy: mean ae_che_oopg_nf`z' ae_over_oopg_nf`z'
        local h = _b[ae_che_oopg_nf`z']
        local hse = _se[ae_che_oopg_nf`z']
        local o = _b[ae_over_oopg_nf`z']
        local ose = _se[ae_over_oopg_nf`z']
        local mpo = cond(`h' > 0, `o' / `h', .)
        post `summ' ("`wt'") ("oopg") ("nonfood_ae") (`z' / 100) ///
            ("ae_che_oopg_nf`z'") ("ae_over_oopg_nf`z'") ///
            (`h') (`hse') (`o') (`ose') (`mpo')
    }
}

postclose `summ'

preserve
    use `summdata', clear
    export delimited using "$out_ae/oopg_adult_equiv_che_summary.csv", replace
restore


*==============================================================================*
*     SECTION 3: EQUIVALENCE CHECK                                             *
*==============================================================================*

preserve
    clear
    set obs 2
    gen str28 check = ""
    gen double max_abs_difference = .
    gen str8 status = "PASS"
    replace check = "total share: AE vs household" in 1
    replace max_abs_difference = `max_abs_tot' in 1
    replace check = "nonfood share: AE vs household" in 2
    replace max_abs_difference = `max_abs_nf' in 2
    export delimited using "$out_ae/oopg_adult_equiv_equivalence_check.csv", replace
restore


*==============================================================================*
*     SECTION 4: METHOD NOTE                                                   *
*==============================================================================*

file open note using "$out_ae/oopg_adult_equiv_method_note.md", write replace
file write note "# OOPG CHE on an Adult-Equivalent Basis" _n _n
file write note "This is a separate OOPG-only branch and does not overwrite the main household analysis." _n _n
file write note "Adult equivalents use the existing project scale: `(n_adults + 0.5 * n_children)^0.75`, where adults are age 15+ and children are below age 15." _n _n
file write note "The total-expenditure CHE share is `(oopg / adult_equiv) / ((nominal_total_cons_month + oopg) / adult_equiv)`. This simplifies exactly to the household share `oopg / (nominal_total_cons_month + oopg)`." _n _n
file write note "The nonfood CHE share is analogous: `(oopg_real / adult_equiv) / ((nf_real_hh_mo + oopg_real) / adult_equiv)`." _n _n
file write note "Therefore, adult-equivalent scaling changes the units of the amounts, but it does not change the CHE percentage, headcount, overshoot, or household classification when both numerator and denominator are scaled consistently." _n _n
file write note "Main result file: `oopg_adult_equiv_che_summary.csv`." _n
file close note

log close

di as result "Saved OOPG adult-equivalent CHE outputs to $out_ae"
