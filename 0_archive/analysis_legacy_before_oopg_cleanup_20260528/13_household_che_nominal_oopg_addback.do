*------------------------------------------------------------------------------*
*   Household CHE Sensitivity: Nominal Total Consumption + OOPG Addback         *
/*

    Author:             Arpan / Codex
    Date created:       26th May 2026

    Purpose:
        Run a separate household-level check using reconstructed nominal
        household consumption. The denominator is monthly reconstructed nominal
        total consumption plus general health/OOPG spending only:

            nominal_total_cons_month + oopg

        Numerators are household OOPG and household OOP. Estimates use the
        household survey weight hhs_wt.

    Important:
        This branch mirrors the current main household total-expenditure
        denominator and remains useful as a compact threshold check.

    Outputs:
        - 6_output/main_output/household_che_nominal_oopg_addback/
          household_che_nominal_oopg_addback_summary.csv
        - 6_output/main_output/household_che_nominal_oopg_addback/
          household_che_nominal_oopg_addback_method_note.md
        - 4_log/13_household_che_nominal_oopg_addback.log
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
global tab              "$workspace/6_output"
global out_hh           "$tab/main_output/household_che_nominal_oopg_addback"

cap mkdir "$tab/main_output"
cap mkdir "$out_hh"

local dofilename "13_household_che_nominal_oopg_addback"
log using "$log/`dofilename'.log", replace


*==============================================================================*
*     SECTION 1: SETUP                                                         *
*==============================================================================*

use "$data_clean/catastrophic_health_exp.dta", clear

assert _N == 9600
assert nominal_total_cons_month > 0
assert hhs_wt > 0
assert oop >= oopg

gen double nom_total_cons_mo = nominal_total_cons_month
gen double nom_totexp_oopgadd_mo = nom_total_cons_mo + oopg

label variable nom_total_cons_mo     "Reconstructed nominal monthly household total consumption (NPR)"
label variable nom_totexp_oopgadd_mo "Reconstructed nominal monthly total consumption plus OOPG only (NPR)"

assert nom_totexp_oopgadd_mo > 0

gen double hh_oopg_sh_tot_nom_oopgadd = oopg / nom_totexp_oopgadd_mo
gen double hh_oop_sh_tot_nom_oopgadd  = oop  / nom_totexp_oopgadd_mo

label variable hh_oopg_sh_tot_nom_oopgadd "OOPG share of reconstructed nominal total consumption plus OOPG"
label variable hh_oop_sh_tot_nom_oopgadd  "OOP share of reconstructed nominal total consumption plus OOPG"

foreach scope in oopg oop {
    foreach z in 5 10 15 20 25 40 {
        local cut = `z' / 100
        gen byte hche_`scope'_tot`z'_nom_oopgadd = ///
            hh_`scope'_sh_tot_nom_oopgadd > `cut' ///
            if !missing(hh_`scope'_sh_tot_nom_oopgadd)
        gen double hover_`scope'_tot`z'_nom_oopgadd = ///
            max(hh_`scope'_sh_tot_nom_oopgadd - `cut', 0) ///
            if !missing(hh_`scope'_sh_tot_nom_oopgadd)
    }
}

foreach z in 5 10 15 20 25 40 {
    assert hche_oop_tot`z'_nom_oopgadd >= hche_oopg_tot`z'_nom_oopgadd ///
        if !missing(hche_oop_tot`z'_nom_oopgadd, hche_oopg_tot`z'_nom_oopgadd)
}


*==============================================================================*
*     SECTION 2: HOUSEHOLD-WEIGHTED SUMMARY                                    *
*==============================================================================*

svyset psu_number [pw = hhs_wt]

tempname summ
tempfile summdata
postfile `summ' str10 unit str8 weight str5 scope str8 denominator ///
    double threshold str18 convention str40 che_variable str40 overshoot_variable ///
    double prevalence prevalence_se overshoot overshoot_se mpo ///
    using `summdata', replace

foreach scope in oopg oop {
    foreach z in 5 10 15 20 25 40 {
        local che "hche_`scope'_tot`z'_nom_oopgadd"
        local over "hover_`scope'_tot`z'_nom_oopgadd"

        quietly svy: mean `che'
        matrix M = r(table)
        local prev = M[1,1]
        local prev_se = M[2,1]

        quietly svy: mean `over'
        matrix O = r(table)
        local overshoot = O[1,1]
        local overshoot_se = O[2,1]

        local mpo = .
        if `prev' > 0 local mpo = `overshoot' / `prev'

        post `summ' ("household") ("hhs_wt") ("`scope'") ("total") ///
            (`z' / 100) ("nom_oopg_addback") ("`che'") ("`over'") ///
            (`prev') (`prev_se') (`overshoot') (`overshoot_se') (`mpo')
    }
}

postclose `summ'
use `summdata', clear
export delimited using "$out_hh/household_che_nominal_oopg_addback_summary.csv", replace


*==============================================================================*
*     SECTION 3: METHOD NOTE                                                   *
*==============================================================================*

file open note using "$out_hh/household_che_nominal_oopg_addback_method_note.md", write replace
file write note "# Household CHE: Reconstructed Nominal Total Consumption + OOPG Addback" _n _n
file write note "This branch mirrors the main household total-expenditure denominator as a compact threshold check." _n _n
file write note "The denominator is reconstructed monthly nominal household total consumption plus general health/OOPG only: `nominal_total_cons_month + oopg`." _n _n
file write note "The numerators are monthly household OOPG (`oopg`) and combined monthly household OOP (`oop`)." _n _n
file write note "Estimates use Stata survey commands with `svyset psu_number [pw = hhs_wt]`." _n _n
file write note "For the OOP numerator, the denominator does not add back NCD spending, so OOP shares are expected to be larger than under the full-OOP addback convention." _n
file close note

log close

di as result "Saved household reconstructed nominal OOPG-addback outputs."
