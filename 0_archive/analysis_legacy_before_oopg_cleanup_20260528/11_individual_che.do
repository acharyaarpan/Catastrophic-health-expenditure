*------------------------------------------------------------------------------*
*           Exploratory Individual-Level Catastrophic Health Expenditure        *
/*

    Author:             Arpan / Codex
    Date created:       26th May 2026

    Purpose:
        Build a separate, non-overwriting individual-level CHE branch. Health
        payments are retained at the person level and divided by official
        per-capita consumption from poverty.dta.

    Important:
        This is exploratory and does not replace the household CHE pipeline.
        At the person-record level, each official household member is weighted
        by the household expansion weight hhs_wt. Do not use ind_wt here,
        because ind_wt = hhs_wt * hhsize is intended for household-level files.

    Outputs:
        - 1_data/2_clean/catastrophic_health_exp_individual.dta
        - 6_output/main_output/individual_che/individual_che_summary.csv
        - 6_output/main_output/individual_che/individual_che_method_note.md
        - 4_log/11_individual_che.log
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
global data_raw         "$data/1_raw"
global data_clean       "$data/2_clean"
global analysis         "$workspace/3_analysis"
global log              "$workspace/4_log"
global tab              "$workspace/6_output"
global out_ind          "$tab/main_output/individual_che"

cap mkdir "$tab/main_output"
cap mkdir "$out_ind"

local dofilename "11_individual_che"
log using "$log/`dofilename'.log", replace


*==============================================================================*
*     SECTION 1: PERSON-LEVEL HEALTH SPENDING                                  *
*==============================================================================*

use "$data_raw/S08.dta", clear

merge 1:1 psu_number hh_number idcode using "$data_raw/S01.dta", ///
    keepusing(q01_02 q01_03 q01_09 member_cat) keep(match) nogen

* Keep official household members only. S08/S01 also include absentees and
* other listed persons, while poverty.dta hhsize counts q01_09 == 1 members.
keep if q01_09 == 1
count
assert r(N) == 38101

replace q08_14_i = 0 if missing(q08_14_i)
replace q08_06_i = 0 if missing(q08_06_i)

gen double oopg_i = q08_14_i
gen double ncd_i_annual = q08_06_i
gen double ncd_i_monthly = ncd_i_annual / 12
gen double oop_i = oopg_i + ncd_i_monthly

label variable oopg_i        "Individual communicable/injury OOP, past 30 days (NPR)"
label variable ncd_i_annual  "Individual NCD OOP, past year (NPR)"
label variable ncd_i_monthly "Individual NCD OOP, monthly equivalent (NPR)"
label variable oop_i         "Individual OOPG plus monthly NCD OOP (NPR)"


*==============================================================================*
*     SECTION 2: MERGE OFFICIAL WELFARE AGGREGATE                              *
*==============================================================================*

merge m:1 psu_number hh_number using "$data_raw/poverty.dta", ///
    keepusing(prov domain ad_4 hhsize hhs_wt ind_wt paasche pcep pcep_food ///
              pcep_nonfood pline fpline nfpline poor quintile_pcep) ///
    keep(match) nogen

bysort psu_number hh_number: gen int _n_official_members = _N
assert _n_official_members == hhsize
drop _n_official_members

assert !missing(hhs_wt, paasche, pcep, pcep_nonfood)
assert hhs_wt > 0
assert paasche > 0
assert pcep > 0
assert pcep_nonfood > 0

gen double person_wt = hhs_wt
label variable person_wt "Person-level expansion weight for individual records (= hhs_wt)"


*==============================================================================*
*     SECTION 3: INDIVIDUAL CHE DENOMINATORS AND FLAGS                         *
*==============================================================================*

gen double oopg_i_real = oopg_i / paasche
gen double oop_i_real  = oop_i  / paasche

gen double pc_total_mo_real = pcep / 12
gen double pc_nonfood_mo_real = pcep_nonfood / 12

* Primary health-including denominators, person-level analogue of the household
* Wagstaff/EQUITAP construction.
gen double pc_totexp_mo_real = pc_total_mo_real + oop_i_real
gen double pc_nfexp_mo_real  = pc_nonfood_mo_real + oop_i_real

gen double oopg_i_sh_tot = oopg_i_real / pc_totexp_mo_real
gen double oop_i_sh_tot  = oop_i_real  / pc_totexp_mo_real
gen double oopg_i_sh_nf  = oopg_i_real / pc_nfexp_mo_real
gen double oop_i_sh_nf   = oop_i_real  / pc_nfexp_mo_real

* Sensitivity: NLSS welfare denominator without adding OOP back.
gen double oopg_i_sh_tot_nlss = oopg_i_real / pc_total_mo_real
gen double oop_i_sh_tot_nlss  = oop_i_real  / pc_total_mo_real
gen double oopg_i_sh_nf_nlss  = oopg_i_real / pc_nonfood_mo_real
gen double oop_i_sh_nf_nlss   = oop_i_real  / pc_nonfood_mo_real

label variable oopg_i_real          "Individual OOPG, real monthly NPR"
label variable oop_i_real           "Individual OOP, real monthly NPR"
label variable pc_total_mo_real     "Official real per-capita total consumption, monthly, excludes health"
label variable pc_nonfood_mo_real   "Official real per-capita nonfood consumption, monthly, excludes health"
label variable pc_totexp_mo_real    "Individual real total expenditure denominator, includes OOP"
label variable pc_nfexp_mo_real     "Individual real nonfood denominator, includes OOP"
label variable oopg_i_sh_tot        "Individual OOPG share of per-capita total expenditure incl. OOP"
label variable oop_i_sh_tot         "Individual OOP share of per-capita total expenditure incl. OOP"
label variable oopg_i_sh_nf         "Individual OOPG share of per-capita nonfood expenditure incl. OOP"
label variable oop_i_sh_nf          "Individual OOP share of per-capita nonfood expenditure incl. OOP"
label variable oopg_i_sh_tot_nlss   "Individual OOPG share of official per-capita total consumption excl. health"
label variable oop_i_sh_tot_nlss    "Individual OOP share of official per-capita total consumption excl. health"
label variable oopg_i_sh_nf_nlss    "Individual OOPG share of official per-capita nonfood consumption excl. health"
label variable oop_i_sh_nf_nlss     "Individual OOP share of official per-capita nonfood consumption excl. health"

assert oop_i >= oopg_i
assert oop_i_real >= oopg_i_real
assert pc_totexp_mo_real > 0
assert pc_nfexp_mo_real > 0

foreach scope in oopg oop {
    foreach denom in tot nf {
        foreach z in 5 10 15 20 25 40 {
            local cut = `z' / 100
            gen byte iche_`scope'_`denom'`z' = `scope'_i_sh_`denom' > `cut' ///
                if !missing(`scope'_i_sh_`denom')
            gen double iover_`scope'_`denom'`z' = max(`scope'_i_sh_`denom' - `cut', 0) ///
                if !missing(`scope'_i_sh_`denom')

            gen byte iche_`scope'_`denom'`z'_nlss = `scope'_i_sh_`denom'_nlss > `cut' ///
                if !missing(`scope'_i_sh_`denom'_nlss)
            gen double iover_`scope'_`denom'`z'_nlss = max(`scope'_i_sh_`denom'_nlss - `cut', 0) ///
                if !missing(`scope'_i_sh_`denom'_nlss)
        }
    }
}

foreach z in 5 10 15 20 25 40 {
    assert iche_oop_tot`z' >= iche_oopg_tot`z' if !missing(iche_oop_tot`z', iche_oopg_tot`z')
    assert iche_oop_nf`z'  >= iche_oopg_nf`z'  if !missing(iche_oop_nf`z',  iche_oopg_nf`z')
}

save "$data_clean/catastrophic_health_exp_individual.dta", replace


*==============================================================================*
*     SECTION 4: PERSON-LEVEL PREVALENCE, OVERSHOOT, MPO                       *
*==============================================================================*

svyset psu_number [pw = person_wt]

tempname summ
tempfile summdata
postfile `summ' str8 unit str12 weight str5 scope str8 denominator ///
    double threshold str10 convention str32 che_variable str32 overshoot_variable ///
    double prevalence prevalence_se overshoot overshoot_se mpo ///
    using `summdata', replace

foreach convention in primary nlss {
    local vsuf ""
    if "`convention'" == "nlss" local vsuf "_nlss"

    foreach scope in oopg oop {
        foreach denom in total nonfood {
            local ds "tot"
            if "`denom'" == "nonfood" local ds "nf"

            foreach z in 5 10 15 20 25 40 {
                local che "iche_`scope'_`ds'`z'`vsuf'"
                local over "iover_`scope'_`ds'`z'`vsuf'"

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

                post `summ' ("person") ("person_wt") ("`scope'") ("`denom'") ///
                    (`z' / 100) ("`convention'") ("`che'") ("`over'") ///
                    (`prev') (`prev_se') (`overshoot') (`overshoot_se') (`mpo')
            }
        }
    }
}

postclose `summ'
use `summdata', clear
export delimited using "$out_ind/individual_che_summary.csv", replace


*==============================================================================*
*     SECTION 5: SHORT METHOD NOTE                                             *
*==============================================================================*

file open note using "$out_ind/individual_che_method_note.md", write replace
file write note "# Individual-Level CHE Exploratory Branch" _n _n
file write note "This branch does not overwrite the household-level CHE pipeline." _n _n
file write note "Health spending comes from person records in S08.dta. S08 is merged to S01.dta, and only official household members are retained (`q01_09 == 1`). This gives 38,101 individual records, matching the sum of `hhsize` in poverty.dta." _n _n
file write note "The numerator is individual health spending: `oopg_i = q08_14_i` and `oop_i = q08_14_i + q08_06_i / 12`. Amounts are deflated using the household Paasche index." _n _n
file write note "The denominator is official per-capita consumption: `pcep / 12` for total consumption and `pcep_nonfood / 12` for nonfood consumption. The primary denominator adds individual real OOP back, matching the health-including logic used in the household analysis." _n _n
file write note "Each individual record is weighted by `person_wt = hhs_wt`. Do not use `ind_wt` on person-level records because `ind_wt = hhs_wt * hhsize` is for household-level files." _n
file close note

log close

di as result "Saved individual-level CHE dataset and outputs."
