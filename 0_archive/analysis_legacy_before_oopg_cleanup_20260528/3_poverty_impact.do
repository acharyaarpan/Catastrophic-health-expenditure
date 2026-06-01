*------------------------------------------------------------------------------*
*           Phase 2d: Health Payments and Poverty                              *
/*

    Author:             Arpan
    Date created:       20th May 2026
    Last updated by:    Codex

    Notes:
        Implements Chapter 19-style poverty impact analysis for oopg and OOP.
        NLSS IV excludes health spending from the official welfare aggregate,
        so pcep is post-payment welfare. Pre-payment welfare is reconstructed
        by adding real per-capita health payments back to pcep.

    Dependencies:
        - catastrophic_health_exp.dta (from $data_clean)
        - Run 0_master.do before this file

    Output:
        - poverty_impact.csv
        - Log file in $log
*/
*------------------------------------------------------------------------------*

local dofilename "3_poverty_impact"

cap log close
log using "$log/`dofilename'.log", replace

use "$data_clean/catastrophic_health_exp.dta", clear

svyset psu_number [pw = ind_wt]

assert _N == 9600
assert abs(pcep - (pcep_food + pcep_nonfood)) < 1
assert oop >= oopg


*==============================================================================*
*                                                                              *
*     SECTION 1: PRE/POST PAYMENT WELFARE                                      *
*                                                                              *
*==============================================================================*

foreach v in post_welfare pre_oopg pre_oop poor_post gap_post ngap_post {
    capture drop `v'
}
gen post_welfare = pcep
gen pre_oopg = pcep + oopg_pc_ann_real
gen pre_oop = pcep + oop_pc_ann_real

assert pre_oopg >= post_welfare if !missing(pre_oopg, post_welfare)
assert pre_oop >= post_welfare if !missing(pre_oop, post_welfare)
assert pre_oop >= pre_oopg if !missing(pre_oop, pre_oopg)
assert pre_oop >= pcep if !missing(pre_oop, pcep)

gen poor_post = (post_welfare < pline) if !missing(post_welfare, pline)
gen gap_post = poor_post * (pline - post_welfare)
gen ngap_post = gap_post / pline

quietly svy: mean poor_post
local official = _b[poor_post]
assert abs(`official' - 0.2027) < 0.0005


*==============================================================================*
*                                                                              *
*     SECTION 2: POVERTY MEASURES                                              *
*                                                                              *
*==============================================================================*

tempname pov
tempfile povdata
postfile `pov' str4 scope str32 metric double pre_estimate post_estimate difference ///
    double relative_change people_pushed households_pushed using `povdata', replace

foreach scope in oopg oop {
    gen poor_pre_`scope' = (pre_`scope' < pline) if !missing(pre_`scope', pline)
    gen gap_pre_`scope' = poor_pre_`scope' * (pline - pre_`scope')
    gen ngap_pre_`scope' = gap_pre_`scope' / pline

    gen diff_h_`scope' = poor_post - poor_pre_`scope'
    gen diff_gap_`scope' = gap_post - gap_pre_`scope'
    gen diff_ngap_`scope' = ngap_post - ngap_pre_`scope'
    gen pushed_`scope' = (pre_`scope' >= pline & post_welfare < pline) ///
        if !missing(pre_`scope', post_welfare, pline)

    quietly svy: mean poor_pre_`scope' poor_post diff_h_`scope' ///
        gap_pre_`scope' gap_post diff_gap_`scope' ///
        ngap_pre_`scope' ngap_post diff_ngap_`scope'

    local hpre = _b[poor_pre_`scope']
    local hpost = _b[poor_post]
    local hdiff = _b[diff_h_`scope']

    local gpre = _b[gap_pre_`scope']
    local gpost = _b[gap_post]
    local gdiff = _b[diff_gap_`scope']

    local ngpre = _b[ngap_pre_`scope']
    local ngpost = _b[ngap_post]
    local ngdiff = _b[diff_ngap_`scope']

    local mpgpre = cond(`hpre' > 0, `gpre' / `hpre', .)
    local mpgpost = cond(`hpost' > 0, `gpost' / `hpost', .)
    local mpgdiff = `mpgpost' - `mpgpre'

    local nmpgpre = cond(`hpre' > 0, `ngpre' / `hpre', .)
    local nmpgpost = cond(`hpost' > 0, `ngpost' / `hpost', .)
    local nmpgdiff = `nmpgpost' - `nmpgpre'

    quietly summarize ind_wt if pushed_`scope' == 1, meanonly
    local people = r(sum)
    quietly count if pushed_`scope' == 1
    local hhs = r(N)

    post `pov' ("`scope'") ("poverty_headcount") ///
        (`hpre') (`hpost') (`hdiff') ///
        (cond(`hpre' > 0, `hdiff' / `hpre', .)) (`people') (`hhs')

    post `pov' ("`scope'") ("poverty_gap_annual_npr") ///
        (`gpre') (`gpost') (`gdiff') ///
        (cond(`gpre' > 0, `gdiff' / `gpre', .)) (`people') (`hhs')

    post `pov' ("`scope'") ("normalized_poverty_gap") ///
        (`ngpre') (`ngpost') (`ngdiff') ///
        (cond(`ngpre' > 0, `ngdiff' / `ngpre', .)) (`people') (`hhs')

    post `pov' ("`scope'") ("mean_positive_gap_annual_npr") ///
        (`mpgpre') (`mpgpost') (`mpgdiff') ///
        (cond(`mpgpre' > 0, `mpgdiff' / `mpgpre', .)) (`people') (`hhs')

    post `pov' ("`scope'") ("mean_positive_normalized_gap") ///
        (`nmpgpre') (`nmpgpost') (`nmpgdiff') ///
        (cond(`nmpgpre' > 0, `nmpgdiff' / `nmpgpre', .)) (`people') (`hhs')
}

postclose `pov'

preserve
    use `povdata', clear
    export delimited using "$tab/poverty_impact.csv", replace
restore


*------------------------------------------------------------------------------*
**#                     End of do file
*------------------------------------------------------------------------------*

log close
