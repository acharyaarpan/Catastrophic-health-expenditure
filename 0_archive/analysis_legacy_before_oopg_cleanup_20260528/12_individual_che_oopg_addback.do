*------------------------------------------------------------------------------*
*    Exploratory Individual-Level CHE: OOPG-Only Health Addback Denominator     *
/*

    Author:             Arpan / Codex
    Date created:       26th May 2026

    Purpose:
        Run a separate individual-level sensitivity where the reconstructed
        total/nonfood denominator adds back only OOPG/general health spending,
        not combined OOP. This does not overwrite the main household pipeline
        or the earlier individual-level branch.

    Interpretation:
        Numerators remain OOPG and OOP. The denominator is:
            pcep / 12 + oopg_i_real
            pcep_nonfood / 12 + oopg_i_real

        This is exploratory. For the OOP numerator, the denominator does not add
        back NCD spending, so OOP shares will be larger than under the full OOP
        addback convention.

    Outputs:
        - 1_data/2_clean/catastrophic_health_exp_individual_oopg_addback.dta
        - 6_output/main_output/individual_che_oopg_addback/individual_che_oopg_addback_summary.csv
        - 6_output/main_output/individual_che_oopg_addback/individual_che_oopg_addback_method_note.md
        - 4_log/12_individual_che_oopg_addback.log
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
global log              "$workspace/4_log"
global tab              "$workspace/6_output"
global out_ind          "$tab/main_output/individual_che_oopg_addback"

cap mkdir "$tab/main_output"
cap mkdir "$out_ind"

local dofilename "12_individual_che_oopg_addback"
log using "$log/`dofilename'.log", replace


*==============================================================================*
*     SECTION 1: PERSON-LEVEL HEALTH SPENDING                                  *
*==============================================================================*

use "$data_raw/S08.dta", clear

merge 1:1 psu_number hh_number idcode using "$data_raw/S01.dta", ///
    keepusing(q01_02 q01_03 q01_09 member_cat) keep(match) nogen

keep if q01_09 == 1
count
assert r(N) == 38101

replace q08_14_i = 0 if missing(q08_14_i)
replace q08_06_i = 0 if missing(q08_06_i)

gen double oopg_i = q08_14_i
gen double ncd_i_annual = q08_06_i
gen double ncd_i_monthly = ncd_i_annual / 12
gen double oop_i = oopg_i + ncd_i_monthly

label variable oopg_i        "Individual general/OOPG spending, past 30 days (NPR)"
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
*     SECTION 3: INDIVIDUAL CHE WITH OOPG-ONLY DENOMINATOR ADDBACK             *
*==============================================================================*

gen double oopg_i_real = oopg_i / paasche
gen double oop_i_real  = oop_i  / paasche

gen double pc_total_mo_real = pcep / 12
gen double pc_nonfood_mo_real = pcep_nonfood / 12

* OOPG/general-health-only addback denominator.
gen double pc_totexp_oopgadd_mo_real = pc_total_mo_real + oopg_i_real
gen double pc_nfexp_oopgadd_mo_real  = pc_nonfood_mo_real + oopg_i_real

gen double oopg_i_sh_tot_oopgadd = oopg_i_real / pc_totexp_oopgadd_mo_real
gen double oop_i_sh_tot_oopgadd  = oop_i_real  / pc_totexp_oopgadd_mo_real
gen double oopg_i_sh_nf_oopgadd  = oopg_i_real / pc_nfexp_oopgadd_mo_real
gen double oop_i_sh_nf_oopgadd   = oop_i_real  / pc_nfexp_oopgadd_mo_real

label variable pc_totexp_oopgadd_mo_real "Individual total denominator, pcep/12 plus OOPG only"
label variable pc_nfexp_oopgadd_mo_real  "Individual nonfood denominator, pcep_nonfood/12 plus OOPG only"
label variable oopg_i_sh_tot_oopgadd     "Individual OOPG share of total denominator plus OOPG only"
label variable oop_i_sh_tot_oopgadd      "Individual OOP share of total denominator plus OOPG only"
label variable oopg_i_sh_nf_oopgadd      "Individual OOPG share of nonfood denominator plus OOPG only"
label variable oop_i_sh_nf_oopgadd       "Individual OOP share of nonfood denominator plus OOPG only"

assert oop_i >= oopg_i
assert oop_i_real >= oopg_i_real
assert pc_totexp_oopgadd_mo_real > 0
assert pc_nfexp_oopgadd_mo_real > 0

foreach scope in oopg oop {
    foreach denom in tot nf {
        foreach z in 5 10 15 20 25 40 {
            local cut = `z' / 100
            gen byte iche_`scope'_`denom'`z'_oopgadd = `scope'_i_sh_`denom'_oopgadd > `cut' ///
                if !missing(`scope'_i_sh_`denom'_oopgadd)
            gen double iover_`scope'_`denom'`z'_oopgadd = max(`scope'_i_sh_`denom'_oopgadd - `cut', 0) ///
                if !missing(`scope'_i_sh_`denom'_oopgadd)
        }
    }
}

foreach z in 5 10 15 20 25 40 {
    assert iche_oop_tot`z'_oopgadd >= iche_oopg_tot`z'_oopgadd if !missing(iche_oop_tot`z'_oopgadd, iche_oopg_tot`z'_oopgadd)
    assert iche_oop_nf`z'_oopgadd  >= iche_oopg_nf`z'_oopgadd  if !missing(iche_oop_nf`z'_oopgadd,  iche_oopg_nf`z'_oopgadd)
}

save "$data_clean/catastrophic_health_exp_individual_oopg_addback.dta", replace


*==============================================================================*
*     SECTION 4: PERSON-LEVEL PREVALENCE, OVERSHOOT, MPO                       *
*==============================================================================*

svyset psu_number [pw = person_wt]

tempname summ
tempfile summdata
postfile `summ' str8 unit str12 weight str5 scope str8 denominator ///
    double threshold str16 convention str36 che_variable str36 overshoot_variable ///
    double prevalence prevalence_se overshoot overshoot_se mpo ///
    using `summdata', replace

foreach scope in oopg oop {
    foreach denom in total nonfood {
        local ds "tot"
        if "`denom'" == "nonfood" local ds "nf"

        foreach z in 5 10 15 20 25 40 {
            local che "iche_`scope'_`ds'`z'_oopgadd"
            local over "iover_`scope'_`ds'`z'_oopgadd"

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
                (`z' / 100) ("oopg_addback") ("`che'") ("`over'") ///
                (`prev') (`prev_se') (`overshoot') (`overshoot_se') (`mpo')
        }
    }
}

postclose `summ'
use `summdata', clear
export delimited using "$out_ind/individual_che_oopg_addback_summary.csv", replace


*==============================================================================*
*     SECTION 5: SHORT METHOD NOTE                                             *
*==============================================================================*

file open note using "$out_ind/individual_che_oopg_addback_method_note.md", write replace
file write note "# Individual-Level CHE: OOPG-Only Addback Sensitivity" _n _n
file write note "This branch does not overwrite the household-level CHE pipeline or the earlier individual-level full-OOP addback branch." _n _n
file write note "Health spending comes from person records in S08.dta. S08 is merged to S01.dta, and only official household members are retained (`q01_09 == 1`). This gives 38,101 individual records." _n _n
file write note "The numerator is individual health spending: `oopg_i = q08_14_i` and `oop_i = q08_14_i + q08_06_i / 12`." _n _n
file write note "The denominator adds back only individual OOPG/general health spending: `pcep / 12 + oopg_i_real` for total consumption and `pcep_nonfood / 12 + oopg_i_real` for nonfood consumption." _n _n
file write note "Each individual record is weighted by `person_wt = hhs_wt`. The OOP numerator uses a denominator that does not add back NCD spending, so OOP shares are expected to be larger than in the full-OOP addback branch." _n
file close note

log close

di as result "Saved individual-level OOPG-addback sensitivity outputs."
