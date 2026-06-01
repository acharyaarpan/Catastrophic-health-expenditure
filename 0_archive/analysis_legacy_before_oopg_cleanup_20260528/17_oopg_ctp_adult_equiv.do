*------------------------------------------------------------------------------*
*        OOPG CHE: Adult-Equivalent Capacity-to-Pay Module                      *
/*

    Author:             Arpan / Codex
    Date created:       28th May 2026

    Purpose:
        Add a separate OOPG-only WHO/Xu-style capacity-to-pay analysis using the
        project's adult-equivalence scale:

            E = (A + 0.5K)^0.75

        This module does not overwrite the main household pipeline. It reads the
        cleaned household dataset and writes a separate output folder.

    Outputs:
        - 6_output/main_output/oopg_ctp_adult_equiv/
          oopg_ctp_adult_equiv_households.dta
          oopg_ctp_adult_equiv_summary.csv
          oopg_ctp_adult_equiv_equity.csv
          oopg_ctp_adult_equiv_trace.csv
          oopg_ctp_adult_equiv_method_note.md
        - 4_log/17_oopg_ctp_adult_equiv.log
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

global data_clean       "$workspace/1_data/2_clean"
global log              "$workspace/4_log"
global tab              "$workspace/6_output/main_output"
global out_ctp          "$tab/oopg_ctp_adult_equiv"

cap mkdir "$tab"
cap mkdir "$out_ctp"

local dofilename "17_oopg_ctp_adult_equiv"
log using "$log/`dofilename'.log", replace


*==============================================================================*
*     SECTION 1: SETUP AND VALIDATION                                          *
*==============================================================================*

use "$data_clean/catastrophic_health_exp.dta", clear

assert _N == 9600
assert abs(pcep - (pcep_food + pcep_nonfood)) < 1
assert oopg >= 0
assert adult_equiv > 0
assert hhs_wt > 0
assert ind_wt > 0
assert paasche > 0
assert nominal_total_cons_month > 0
assert pre_oopg >= pcep if !missing(pre_oopg, pcep)

gen byte poor_check = (pcep < pline) if !missing(pcep, pline)
svyset psu_number [pw = ind_wt]
quietly svy: mean poor_check
assert abs(_b[poor_check] - 0.2027) < 0.0005
drop poor_check


*==============================================================================*
*     SECTION 2: ADULT-EQUIVALENT CAPACITY TO PAY                              *
*==============================================================================*

gen double food_nom_mo = pcep_food * paasche * hhsize / 12
gen double x_oopg_mo = nominal_total_cons_month + oopg
gen double food_share_oopg = food_nom_mo / x_oopg_mo
gen double food_equiv_mo = food_nom_mo / adult_equiv

label variable food_nom_mo      "Nominal monthly household food consumption (NPR)"
label variable x_oopg_mo        "Monthly reconstructed nominal consumption plus OOPG (NPR)"
label variable food_share_oopg  "Food share of reconstructed nominal consumption plus OOPG"
label variable food_equiv_mo    "Monthly food consumption per adult equivalent (NPR)"

assert food_nom_mo > 0
assert x_oopg_mo > 0
assert inrange(food_share_oopg, 0, 1) if !missing(food_share_oopg)

_pctile food_share_oopg [aw = hhs_wt], p(45 55)
local p45 = r(r1)
local p55 = r(r2)

gen byte food_mid_4555 = food_share_oopg >= `p45' & food_share_oopg <= `p55' ///
    if !missing(food_share_oopg)
label variable food_mid_4555 "Food-share households in weighted 45th-55th percentile band"

count if food_mid_4555 == 1
assert r(N) > 0

quietly summarize food_equiv_mo [aw = hhs_wt] if food_mid_4555 == 1, meanonly
scalar subsistence_line_ae_mo = r(mean)
assert subsistence_line_ae_mo > 0

gen double subsistence_line_ae = subsistence_line_ae_mo
gen double subsistence_hh_ae_mo = subsistence_line_ae_mo * adult_equiv
gen double ctp_ae_mo = .
replace ctp_ae_mo = x_oopg_mo - subsistence_hh_ae_mo ///
    if food_nom_mo >= subsistence_hh_ae_mo
replace ctp_ae_mo = x_oopg_mo - food_nom_mo ///
    if food_nom_mo < subsistence_hh_ae_mo

gen byte ctp_rule_subsistence = food_nom_mo >= subsistence_hh_ae_mo ///
    if !missing(food_nom_mo, subsistence_hh_ae_mo)
gen double oopg_sh_ctp_ae = oopg / ctp_ae_mo

label variable subsistence_line_ae "Monthly subsistence line per adult equivalent (NPR)"
label variable subsistence_hh_ae_mo "Monthly household subsistence expenditure, AE adjusted (NPR)"
label variable ctp_ae_mo "Monthly adult-equivalent capacity to pay (NPR)"
label variable ctp_rule_subsistence "CTP rule: subtract AE subsistence instead of actual food"
label variable oopg_sh_ctp_ae "OOPG share of adult-equivalent capacity to pay"

assert subsistence_hh_ae_mo > 0
assert ctp_ae_mo > 0
assert oopg_sh_ctp_ae >= 0 if !missing(oopg_sh_ctp_ae)

foreach z in 10 25 40 {
    local cut = `z' / 100
    gen byte che_oopg_ctp`z'_ae = oopg_sh_ctp_ae > `cut' ///
        if !missing(oopg_sh_ctp_ae)
    gen double over_oopg_ctp`z'_ae = max(oopg_sh_ctp_ae - `cut', 0) ///
        if !missing(oopg_sh_ctp_ae)

    label variable che_oopg_ctp`z'_ae "CHE: OOPG > `z'% adult-equivalent CTP"
    label variable over_oopg_ctp`z'_ae "Overshoot: OOPG above `z'% adult-equivalent CTP"

    assert (over_oopg_ctp`z'_ae == 0) == (che_oopg_ctp`z'_ae == 0) ///
        if !missing(over_oopg_ctp`z'_ae, che_oopg_ctp`z'_ae)
}

assert che_oopg_ctp25_ae <= che_oopg_ctp10_ae ///
    if !missing(che_oopg_ctp25_ae, che_oopg_ctp10_ae)
assert che_oopg_ctp40_ae <= che_oopg_ctp25_ae ///
    if !missing(che_oopg_ctp40_ae, che_oopg_ctp25_ae)


*==============================================================================*
*     SECTION 3: OVERALL SUMMARY                                               *
*==============================================================================*

tempname summ
tempfile summdata
postfile `summ' str10 weight str5 scope str12 denominator double threshold ///
    str24 che_variable str24 overshoot_variable ///
    double headcount headcount_se overshoot overshoot_se mpo ///
    using `summdata', replace

foreach wt in hhs_wt ind_wt {
    svyset psu_number [pw = `wt']
    foreach z in 10 25 40 {
        quietly svy: mean che_oopg_ctp`z'_ae over_oopg_ctp`z'_ae
        local h = _b[che_oopg_ctp`z'_ae]
        local hse = _se[che_oopg_ctp`z'_ae]
        local o = _b[over_oopg_ctp`z'_ae]
        local ose = _se[over_oopg_ctp`z'_ae]
        local mpo = cond(`h' > 0, `o' / `h', .)

        post `summ' ("`wt'") ("oopg") ("ctp_ae") (`z' / 100) ///
            ("che_oopg_ctp`z'_ae") ("over_oopg_ctp`z'_ae") ///
            (`h') (`hse') (`o') (`ose') (`mpo')
    }
}

postclose `summ'

preserve
    use `summdata', clear
    export delimited using "$out_ctp/oopg_ctp_adult_equiv_summary.csv", replace
restore


*==============================================================================*
*     SECTION 4: DISTRIBUTION-SENSITIVE MEASURES                               *
*==============================================================================*

tempname eq
tempfile eqdata
postfile `eq' str10 weight str5 scope str12 denominator double threshold ///
    str12 measure str24 variable double mean concentration_index ///
    double rank_weighted using `eqdata', replace

foreach wt in hhs_wt ind_wt {
    preserve
        keep if !missing(pre_oopg, `wt') & `wt' > 0
        sort pre_oopg psu_number hh_number
        quietly summarize `wt', meanonly
        gen double _rank_w = `wt' / r(sum)
        gen double _rank_cum = sum(_rank_w)
        gen double _frac_rank = _rank_cum - 0.5 * _rank_w

        quietly summarize _frac_rank [aw = `wt'], meanonly
        local mean_rank = r(mean)

        foreach z in 10 25 40 {
            foreach measure in headcount overshoot {
                if "`measure'" == "headcount" local v che_oopg_ctp`z'_ae
                if "`measure'" == "overshoot" local v over_oopg_ctp`z'_ae

                quietly summarize `v' [aw = `wt'], meanonly
                local mu = r(mean)

                if `mu' > 0 {
                    tempvar vrank
                    gen double `vrank' = `v' * _frac_rank
                    quietly summarize `vrank' [aw = `wt'], meanonly
                    local mean_vr = r(mean)
                    local ci = (2 / `mu') * (`mean_vr' - `mu' * `mean_rank')
                    local rw = `mu' * (1 - `ci')
                    drop `vrank'
                }
                else {
                    local ci = .
                    local rw = .
                }

                post `eq' ("`wt'") ("oopg") ("ctp_ae") (`z' / 100) ///
                    ("`measure'") ("`v'") (`mu') (`ci') (`rw')
            }
        }
    restore
}

postclose `eq'

preserve
    use `eqdata', clear
    export delimited using "$out_ctp/oopg_ctp_adult_equiv_equity.csv", replace
restore


*==============================================================================*
*     SECTION 5: TRACE DATA, SAVE, AND METHOD NOTE                             *
*==============================================================================*

preserve
    keep psu_number hh_number hhsize n_adults n_children adult_equiv ///
        paasche pcep_food pcep_nonfood nominal_total_cons_month oopg ///
        food_nom_mo x_oopg_mo food_share_oopg food_equiv_mo food_mid_4555 ///
        subsistence_line_ae subsistence_hh_ae_mo ctp_rule_subsistence ///
        ctp_ae_mo oopg_sh_ctp_ae che_oopg_ctp10_ae che_oopg_ctp25_ae ///
        che_oopg_ctp40_ae over_oopg_ctp10_ae over_oopg_ctp25_ae ///
        over_oopg_ctp40_ae hhs_wt ind_wt
    export delimited using "$out_ctp/oopg_ctp_adult_equiv_trace.csv", replace
restore

compress
save "$out_ctp/oopg_ctp_adult_equiv_households.dta", replace

file open note using "$out_ctp/oopg_ctp_adult_equiv_method_note.md", write replace
file write note "# OOPG adult-equivalent capacity-to-pay module" _n _n
file write note "This module follows the WHO/Xu capacity-to-pay logic for OOPG only." _n _n
file write note "Adult equivalence uses the project scale: E = (A + 0.5K)^0.75." _n _n
file write note "Weighted food-share cut points: p45 = " %9.6f (`p45') ", p55 = " %9.6f (`p55') "." _n
file write note "Monthly subsistence line per adult equivalent: " %12.4f (subsistence_line_ae_mo) " NPR." _n _n
file write note "Reported CTP thresholds: 10%, 25%, and 40%." _n _n
file write note "The OOPG numerator remains household-level. Adult equivalence enters through the subsistence requirement and capacity-to-pay denominator." _n
file close note

di as result "Saved OOPG CTP adult-equivalent outputs to $out_ctp"

log close
