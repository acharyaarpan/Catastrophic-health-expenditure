*------------------------------------------------------------------------------*
*      OOPG catastrophic health expenditure analysis - no-addback rerun         *
/*

    Purpose:
        Produce the Shiva sir OOPG-only analysis outputs for the manuscript.
        This rerun does not add OOPG back to total/nonfood consumption
        denominators or to the CTP resource aggregate.
        This file combines the Chapter 18-style total/nonfood CHE analysis,
        the adult-equivalence capacity-to-pay module, and the OOPG poverty
        impact table.

    Input:
        1_data/2_clean/oopg_analysis_base.dta

    Outputs:
        6_output/main_output/manuscript/tables/
            oopg_incidence_intensity.csv
            oopg_distribution_sensitive.csv
            oopg_ctp_summary.csv
            oopg_ctp_equity.csv
            oopg_poverty_impact.csv
            oopg_method_parameters.csv

    Log:
        4_log/01_oopg_che_analysis.log
*/
*------------------------------------------------------------------------------*

version 17
clear all
set more off
cap log close

if "$workspace" == "" {
    if "`c(username)'" == "ACER" ///
        & fileexists("D:/Projects/CIH-project/consumption/shivasir/0_master.do") {
        global workspace "D:/Projects/CIH-project/consumption/shivasir"
    }
    else if fileexists("1_data/2_clean/oopg_analysis_base.dta") {
        global workspace "`c(pwd)'"
    }
    else if fileexists("D:/Projects/CIH-project/consumption/shivasir/0_master.do") {
        global workspace "D:/Projects/CIH-project/consumption/shivasir"
    }
    else {
        global workspace "`c(pwd)'"
    }
}

global data_clean "$workspace/1_data/2_clean"
global log        "$workspace/4_log"
global tab        "$workspace/6_output/main_output"
global manuscript "$tab/manuscript"
global tables     "$manuscript/tables"

cap mkdir "$workspace/6_output"
cap mkdir "$tab"
cap mkdir "$manuscript"
cap mkdir "$tables"
cap mkdir "$log"

local dofilename "01_oopg_che_analysis"
log using "$log/`dofilename'.log", replace

use "$data_clean/oopg_analysis_base.dta", clear

assert _N == 9600
assert abs(pcep - (pcep_food + pcep_nonfood)) < 1
assert oopg >= 0
assert adult_equiv > 0
assert hhs_wt > 0
assert ind_wt > 0
assert paasche > 0
assert pcep_mo_real > 0
assert pline_mo_real > 0
assert nominal_total_cons_month > 0
assert totexp_nom_noadd_mo > 0
assert ctp_real_noadd_hh_mo > 0
assert abs(pre_oopg - pcep_mo_real) < 1e-8 if !missing(pre_oopg, pcep_mo_real)
assert post_oopg >= 0 if !missing(post_oopg)
assert post_oopg <= pre_oopg if !missing(post_oopg, pre_oopg)

gen byte _poor_pcep_check = (pcep < pline) if !missing(pcep, pline)
svyset psu_number [pw = ind_wt]
quietly svy: mean _poor_pcep_check
assert abs(_b[_poor_pcep_check] - 0.2027) < 0.0005
drop _poor_pcep_check


*==============================================================================*
*     SECTION 1: CHAPTER 18-STYLE TOTAL AND NONFOOD CHE                        *
*==============================================================================*

local thresholds 5 10 15 25 40

foreach denom in total nonfood {
    if "`denom'" == "total" {
        local share oopg_sh_tot
        local stub tot
    }
    else {
        local share oopg_sh_nf
        local stub nf
    }

    foreach z of local thresholds {
        local zdec = `z' / 100
        cap drop ch18_oopg_`stub'`z'
        cap drop ch18_over_oopg_`stub'`z'
        gen byte ch18_oopg_`stub'`z' = (`share' > `zdec') if !missing(`share')
        gen double ch18_over_oopg_`stub'`z' = max(`share' - `zdec', 0) if !missing(`share')

        label variable ch18_oopg_`stub'`z' "OOPG CHE: `z'% `denom'"
        label variable ch18_over_oopg_`stub'`z' "OOPG overshoot: `z'% `denom'"
    }
}

assert ch18_oopg_tot10 == che_oopg_tot10
assert ch18_oopg_nf25 == che_oopg_nf25
assert ch18_oopg_nf40 == che_oopg_nf40

tempname inc
tempfile incdata
postfile `inc' str7 scope str12 denominator int threshold ///
    str24 headcount_var str30 overshoot_var ///
    double headcount headcount_se overshoot overshoot_se mpo ///
    using `incdata', replace

svyset psu_number [pw = hhs_wt]

foreach denom in total nonfood {
    local stub = cond("`denom'" == "total", "tot", "nf")

    foreach z of local thresholds {
        if "`denom'" == "nonfood" & inlist(`z', 5, 10) continue

        local h ch18_oopg_`stub'`z'
        local o ch18_over_oopg_`stub'`z'

        quietly svy: mean `h' `o'
        local head = _b[`h']
        local head_se = _se[`h']
        local over = _b[`o']
        local over_se = _se[`o']
        local mpo = cond(`head' > 0, `over' / `head', .)

        post `inc' ("oopg") ("`denom'") (`z') ("`h'") ("`o'") ///
            (`head') (`head_se') (`over') (`over_se') (`mpo')
    }
}

postclose `inc'

preserve
    use `incdata', clear
    export delimited using "$tables/oopg_incidence_intensity.csv", replace
restore


*==============================================================================*
*     SECTION 2: ADULT-EQUIVALENCE CAPACITY TO PAY                             *
*==============================================================================*

cap drop food_nom_mo x_cons_mo food_share_cons food_equiv_mo food_mid_4555
cap drop subsistence_line_ae subsistence_hh_ae_mo ctp_ae_mo ctp_rule_subsistence
cap drop oopg_sh_ctp_ae che_oopg_ctp10_ae che_oopg_ctp25_ae che_oopg_ctp40_ae
cap drop over_oopg_ctp10_ae over_oopg_ctp25_ae over_oopg_ctp40_ae

gen double food_nom_mo = pcep_food * paasche * hhsize / 12
gen double x_cons_mo = nominal_total_cons_month
gen double food_share_cons = food_nom_mo / x_cons_mo
gen double food_equiv_mo = food_nom_mo / adult_equiv

label variable food_nom_mo      "Nominal monthly household food consumption (NPR)"
label variable x_cons_mo        "Monthly reconstructed nominal consumption, no OOPG addback (NPR)"
label variable food_share_cons  "Food share of reconstructed nominal consumption, no OOPG addback"
label variable food_equiv_mo    "Monthly food consumption per adult equivalent (NPR)"

assert food_nom_mo > 0
assert x_cons_mo > 0
assert inrange(food_share_cons, 0, 1) if !missing(food_share_cons)

_pctile food_share_cons [aw = hhs_wt], p(45 55)
local p45 = r(r1)
local p55 = r(r2)

gen byte food_mid_4555 = food_share_cons >= `p45' & food_share_cons <= `p55' ///
    if !missing(food_share_cons)
label variable food_mid_4555 "Food-share households in weighted 45th-55th percentile band"

count if food_mid_4555 == 1
assert r(N) > 0
local n_mid = r(N)

quietly summarize food_equiv_mo [aw = hhs_wt] if food_mid_4555 == 1, meanonly
scalar subsistence_line_ae_mo = r(mean)
assert subsistence_line_ae_mo > 0

gen double subsistence_line_ae = subsistence_line_ae_mo
gen double subsistence_hh_ae_mo = subsistence_line_ae_mo * adult_equiv
gen double ctp_ae_mo = .
replace ctp_ae_mo = x_cons_mo - subsistence_hh_ae_mo ///
    if food_nom_mo >= subsistence_hh_ae_mo
replace ctp_ae_mo = x_cons_mo - food_nom_mo ///
    if food_nom_mo < subsistence_hh_ae_mo

gen byte ctp_rule_subsistence = food_nom_mo >= subsistence_hh_ae_mo ///
    if !missing(food_nom_mo, subsistence_hh_ae_mo)
gen double oopg_sh_ctp_ae = oopg / ctp_ae_mo

label variable subsistence_line_ae "Monthly subsistence line per adult equivalent (NPR)"
label variable subsistence_hh_ae_mo "Monthly household subsistence expenditure, AE adjusted (NPR)"
label variable ctp_ae_mo "Monthly adult-equivalence capacity to pay (NPR)"
label variable ctp_rule_subsistence "CTP rule: subtract AE subsistence instead of actual food"
label variable oopg_sh_ctp_ae "OOPG share of adult-equivalence capacity to pay"

assert subsistence_hh_ae_mo > 0
assert ctp_ae_mo > 0
assert oopg_sh_ctp_ae >= 0 if !missing(oopg_sh_ctp_ae)

foreach z in 10 25 40 {
    local cut = `z' / 100
    gen byte che_oopg_ctp`z'_ae = oopg_sh_ctp_ae > `cut' if !missing(oopg_sh_ctp_ae)
    gen double over_oopg_ctp`z'_ae = max(oopg_sh_ctp_ae - `cut', 0) if !missing(oopg_sh_ctp_ae)

    label variable che_oopg_ctp`z'_ae "CHE: OOPG > `z'% adult-equivalence CTP"
    label variable over_oopg_ctp`z'_ae "Overshoot: OOPG above `z'% adult-equivalence CTP"

    assert (over_oopg_ctp`z'_ae == 0) == (che_oopg_ctp`z'_ae == 0) ///
        if !missing(over_oopg_ctp`z'_ae, che_oopg_ctp`z'_ae)
}

assert che_oopg_ctp40_ae <= che_oopg_ctp25_ae if !missing(che_oopg_ctp40_ae, che_oopg_ctp25_ae)

tempname ctp
tempfile ctpdata
postfile `ctp' str10 weight str5 scope str12 denominator double threshold ///
    str24 che_variable str24 overshoot_variable ///
    double headcount headcount_se overshoot overshoot_se mpo ///
    using `ctpdata', replace

foreach wt in hhs_wt ind_wt {
    svyset psu_number [pw = `wt']
    foreach z in 10 25 40 {
        quietly svy: mean che_oopg_ctp`z'_ae over_oopg_ctp`z'_ae
        local h = _b[che_oopg_ctp`z'_ae]
        local hse = _se[che_oopg_ctp`z'_ae]
        local o = _b[over_oopg_ctp`z'_ae]
        local ose = _se[over_oopg_ctp`z'_ae]
        local mpo = cond(`h' > 0, `o' / `h', .)

        post `ctp' ("`wt'") ("oopg") ("ctp_ae") (`z' / 100) ///
            ("che_oopg_ctp`z'_ae") ("over_oopg_ctp`z'_ae") ///
            (`h') (`hse') (`o') (`ose') (`mpo')
    }
}

postclose `ctp'

preserve
    use `ctpdata', clear
    export delimited using "$tables/oopg_ctp_summary.csv", replace
restore


*==============================================================================*
*     SECTION 3: DISTRIBUTION-SENSITIVE MEASURES                               *
*==============================================================================*

tempname eq
tempfile eqdata
postfile `eq' str7 scope str12 denominator int threshold ///
    str24 headcount_var str30 overshoot_var ///
    double headcount concentration_headcount rank_weighted_headcount ///
    double overshoot concentration_overshoot rank_weighted_overshoot ///
    using `eqdata', replace

preserve
    keep if !missing(pre_oopg, hhs_wt) & hhs_wt > 0
    sort pre_oopg psu_number hh_number
    quietly summarize hhs_wt, meanonly
    gen double _rank_w = hhs_wt / r(sum)
    gen double _rank_cum = sum(_rank_w)
    gen double _frac_rank = _rank_cum - 0.5 * _rank_w

    quietly summarize _frac_rank [aw = hhs_wt], meanonly
    local mean_rank = r(mean)

    foreach denom in total nonfood {
        local stub = cond("`denom'" == "total", "tot", "nf")

        foreach z of local thresholds {
            if "`denom'" == "nonfood" & inlist(`z', 5, 10) continue

            local h ch18_oopg_`stub'`z'
            local o ch18_over_oopg_`stub'`z'

            quietly summarize `h' [aw = hhs_wt], meanonly
            local head = r(mean)

            tempvar h_rank
            gen double `h_rank' = `h' * _frac_rank
            quietly summarize `h_rank' [aw = hhs_wt], meanonly
            local mean_hr = r(mean)
            local ci_h = cond(`head' > 0, (2 / `head') * (`mean_hr' - `head' * `mean_rank'), .)
            local rw_h = cond(`head' > 0, `head' * (1 - `ci_h'), .)
            drop `h_rank'

            quietly summarize `o' [aw = hhs_wt], meanonly
            local over = r(mean)

            tempvar o_rank
            gen double `o_rank' = `o' * _frac_rank
            quietly summarize `o_rank' [aw = hhs_wt], meanonly
            local mean_or = r(mean)
            local ci_o = cond(`over' > 0, (2 / `over') * (`mean_or' - `over' * `mean_rank'), .)
            local rw_o = cond(`over' > 0, `over' * (1 - `ci_o'), .)
            drop `o_rank'

            post `eq' ("oopg") ("`denom'") (`z') ("`h'") ("`o'") ///
                (`head') (`ci_h') (`rw_h') (`over') (`ci_o') (`rw_o')
        }
    }
restore

postclose `eq'

preserve
    use `eqdata', clear
    export delimited using "$tables/oopg_distribution_sensitive.csv", replace
restore

tempname ctpeq
tempfile ctpeqdata
postfile `ctpeq' str10 weight str5 scope str12 denominator double threshold ///
    str12 measure str24 variable double mean concentration_index ///
    double rank_weighted using `ctpeqdata', replace

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

                post `ctpeq' ("`wt'") ("oopg") ("ctp_ae") (`z' / 100) ///
                    ("`measure'") ("`v'") (`mu') (`ci') (`rw')
            }
        }
    restore
}

postclose `ctpeq'

preserve
    use `ctpeqdata', clear
    export delimited using "$tables/oopg_ctp_equity.csv", replace
restore


*==============================================================================*
*     SECTION 4: OOPG POVERTY IMPACT                                           *
*==============================================================================*

cap drop pre_welfare post_welfare poverty_line_mo poor_post gap_post ngap_post poor_pre_oopg gap_pre_oopg
cap drop ngap_pre_oopg diff_h_oopg diff_gap_oopg diff_ngap_oopg pushed_oopg

gen double pre_welfare = pre_oopg
gen double post_welfare = post_oopg
gen double poverty_line_mo = pline_mo_real
label variable pre_welfare "Pre-OOPG monthly welfare under no-addback assumption (pcep/12)"
label variable post_welfare "Post-OOPG monthly welfare under no-addback assumption (pcep/12 minus monthly OOPG, zero floor)"
label variable poverty_line_mo "Official monthly per-capita poverty line"

gen byte poor_post = (post_welfare < poverty_line_mo) ///
    if !missing(post_welfare, poverty_line_mo)
gen double gap_post = poor_post * (poverty_line_mo - post_welfare)
gen double ngap_post = gap_post / poverty_line_mo

gen byte poor_pre_oopg = (pre_welfare < poverty_line_mo) ///
    if !missing(pre_welfare, poverty_line_mo)
gen double gap_pre_oopg = poor_pre_oopg * (poverty_line_mo - pre_welfare)
gen double ngap_pre_oopg = gap_pre_oopg / poverty_line_mo
gen double diff_h_oopg = poor_post - poor_pre_oopg
gen double diff_gap_oopg = gap_post - gap_pre_oopg
gen double diff_ngap_oopg = ngap_post - ngap_pre_oopg
gen byte pushed_oopg = (pre_welfare >= poverty_line_mo & post_welfare < poverty_line_mo) ///
    if !missing(pre_welfare, post_welfare, poverty_line_mo)

svyset psu_number [pw = ind_wt]
quietly svy: mean poor_pre_oopg poor_post diff_h_oopg ///
    gap_pre_oopg gap_post diff_gap_oopg ///
    ngap_pre_oopg ngap_post diff_ngap_oopg

local hpre = _b[poor_pre_oopg]
local hpost = _b[poor_post]
local hdiff = _b[diff_h_oopg]

local gpre = _b[gap_pre_oopg]
local gpost = _b[gap_post]
local gdiff = _b[diff_gap_oopg]

local ngpre = _b[ngap_pre_oopg]
local ngpost = _b[ngap_post]
local ngdiff = _b[diff_ngap_oopg]

local mpgpre = cond(`hpre' > 0, `gpre' / `hpre', .)
local mpgpost = cond(`hpost' > 0, `gpost' / `hpost', .)
local mpgdiff = `mpgpost' - `mpgpre'

local nmpgpre = cond(`hpre' > 0, `ngpre' / `hpre', .)
local nmpgpost = cond(`hpost' > 0, `ngpost' / `hpost', .)
local nmpgdiff = `nmpgpost' - `nmpgpre'

quietly summarize ind_wt if pushed_oopg == 1, meanonly
local people = r(sum)
quietly count if pushed_oopg == 1
local hhs = r(N)

tempname pov
tempfile povdata
postfile `pov' str5 scope str32 metric double pre_estimate post_estimate difference ///
    double relative_change people_pushed households_pushed using `povdata', replace

post `pov' ("oopg") ("poverty_headcount") ///
    (`hpre') (`hpost') (`hdiff') ///
    (cond(`hpre' > 0, `hdiff' / `hpre', .)) (`people') (`hhs')
post `pov' ("oopg") ("poverty_gap_monthly_npr") ///
    (`gpre') (`gpost') (`gdiff') ///
    (cond(`gpre' > 0, `gdiff' / `gpre', .)) (`people') (`hhs')
post `pov' ("oopg") ("normalized_poverty_gap") ///
    (`ngpre') (`ngpost') (`ngdiff') ///
    (cond(`ngpre' > 0, `ngdiff' / `ngpre', .)) (`people') (`hhs')
post `pov' ("oopg") ("mean_positive_gap_monthly_npr") ///
    (`mpgpre') (`mpgpost') (`mpgdiff') ///
    (cond(`mpgpre' > 0, `mpgdiff' / `mpgpre', .)) (`people') (`hhs')
post `pov' ("oopg") ("mean_positive_normalized_gap") ///
    (`nmpgpre') (`nmpgpost') (`nmpgdiff') ///
    (cond(`nmpgpre' > 0, `nmpgdiff' / `nmpgpre', .)) (`people') (`hhs')
postclose `pov'

preserve
    use `povdata', clear
    export delimited using "$tables/oopg_poverty_impact.csv", replace
restore


*==============================================================================*
*     SECTION 5: METHOD PARAMETERS                                             *
*==============================================================================*

tempname params
tempfile paramsdata
postfile `params' str40 parameter double value str80 note using `paramsdata', replace
post `params' ("food_share_p45") (`p45') ("weighted 45th percentile of no-addback food share")
post `params' ("food_share_p55") (`p55') ("weighted 55th percentile of no-addback food share")
post `params' ("middle_band_households") (`n_mid') ("unweighted count in weighted 45th-55th band")
post `params' ("subsistence_line_ae_mo") (subsistence_line_ae_mo) ("monthly NPR per adult equivalent")
quietly count if post_oopg_zero_floor == 1
post `params' ("post_oopg_zero_floor_households") (r(N)) ("households with pcep/12 minus monthly OOPG below zero, floored at zero")
postclose `params'

preserve
    use `paramsdata', clear
    export delimited using "$tables/oopg_method_parameters.csv", replace
restore

di as result "Saved Shiva sir no-addback OOPG manuscript tables to $tables"

log close

*------------------------------------------------------------------------------*
* End of file
*------------------------------------------------------------------------------*
