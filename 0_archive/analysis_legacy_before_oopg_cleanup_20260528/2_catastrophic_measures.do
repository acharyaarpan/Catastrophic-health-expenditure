*------------------------------------------------------------------------------*
*           Phase 2c: Catastrophic OOPG/OOP Measures and Equity Indices         *
/*

    Author:             Arpan
    Date created:       20th May 2026
    Last updated by:    Codex

    Notes:
        Implements Chapter 18-style catastrophic payment measures for OOPG
        and OOP: headcount, overshoot, mean positive overshoot, sensitivity
        checks, subgroup prevalence, concentration indices, and rank-weighted
        measures.

        Primary CHE total-expenditure estimates use reconstructed nominal
        monthly household consumption plus OOPG/general health spending only.
        Primary nonfood estimates use real monthly nonfood consumption plus
        OOPG only. NLSS-style health-excluding denominators are reported as
        sensitivity outputs with suffix _nlss.

        Concentration indices rank households by pre-OOP living standard
        (pre_oop). A pcep-ranked sensitivity estimate is reported alongside it.

    Dependencies:
        - catastrophic_health_exp.dta (from $data_clean)
        - Run 0_master.do before this file

    Output:
        - che_summary.csv
        - che_sensitivity.csv
        - che_prevalence_all.csv
        - che_subgroups.csv
        - che_equity_indices.csv
        - Log file in $log
*/
*------------------------------------------------------------------------------*

local dofilename "2_catastrophic_measures"

cap log close
log using "$log/`dofilename'.log", replace

use "$data_clean/catastrophic_health_exp.dta", clear


*==============================================================================*
*                                                                              *
*     SECTION 1: SETUP AND VALIDATION                                          *
*                                                                              *
*==============================================================================*

assert _N == 9600
assert oop >= oopg
assert pre_oop >= pcep if !missing(pre_oop, pcep)
assert ctp_real_hh_mo > 0
assert totexp_real_hh_mo > 0
assert totexp_nom_oopgadd_mo > 0
assert ctp_real_oopgadd_hh_mo > 0

cap drop head_edu_n
gen head_edu_n = .
replace head_edu_n = 0 if head_edu_level == "No education" | head_edu_level == ""
replace head_edu_n = 1 if head_edu_level == "Informal/literate"
replace head_edu_n = 2 if head_edu_level == "Primary (1-5)"
replace head_edu_n = 3 if head_edu_level == "Lower secondary (6-8)"
replace head_edu_n = 4 if head_edu_level == "Secondary (9-SLC)"
replace head_edu_n = 5 if head_edu_level == "Higher secondary"
replace head_edu_n = 6 if head_edu_level == "Bachelor and above"

label define edu_lbl 0 "No education" 1 "Informal/literate" ///
    2 "Primary (1-5)" 3 "Lower secondary (6-8)" ///
    4 "Secondary (9-SLC)" 5 "Higher secondary" 6 "Bachelor and above", replace
label values head_edu_n edu_lbl

local specs oopg_tot10 oop_tot10 oopg_tot20 oop_tot20 ///
    oopg_nf25 oop_nf25 oopg_nf40 oop_nf40

local nlss_specs oopg_tot10_nlss oop_tot10_nlss oopg_tot20_nlss oop_tot20_nlss ///
    oopg_nf25_nlss oop_nf25_nlss oopg_nf40_nlss oop_nf40_nlss

assert che_oop_tot10 >= che_oopg_tot10 if !missing(che_oop_tot10, che_oopg_tot10)
assert che_oop_tot20 >= che_oopg_tot20 if !missing(che_oop_tot20, che_oopg_tot20)
assert che_oop_nf25  >= che_oopg_nf25  if !missing(che_oop_nf25,  che_oopg_nf25)
assert che_oop_nf40  >= che_oopg_nf40  if !missing(che_oop_nf40,  che_oopg_nf40)
assert che_oop_tot10_nlss >= che_oopg_tot10_nlss if !missing(che_oop_tot10_nlss, che_oopg_tot10_nlss)
assert che_oop_tot20_nlss >= che_oopg_tot20_nlss if !missing(che_oop_tot20_nlss, che_oopg_tot20_nlss)
assert che_oop_nf25_nlss  >= che_oopg_nf25_nlss  if !missing(che_oop_nf25_nlss,  che_oopg_nf25_nlss)
assert che_oop_nf40_nlss  >= che_oopg_nf40_nlss  if !missing(che_oop_nf40_nlss,  che_oopg_nf40_nlss)


*==============================================================================*
*                                                                              *
*     SECTION 2: OVERALL HEADCOUNT, OVERSHOOT, MPO                             *
*                                                                              *
*==============================================================================*

tempname summ
tempfile summdata
postfile `summ' str10 weight str4 scope str8 denominator double threshold ///
    str24 che_variable str24 overshoot_variable ///
    double headcount headcount_se overshoot overshoot_se mpo ///
    using `summdata', replace

foreach wt in hhs_wt ind_wt {
    svyset psu_number [pw = `wt']

    foreach spec of local specs {
        local scope "oop"
        if substr("`spec'", 1, 4) == "oopg" local scope "oopg"

        local denominator "total"
        if strpos("`spec'", "_nf") local denominator "nonfood"

        local threshold = 0.10
        if strpos("`spec'", "20") local threshold = 0.20
        if strpos("`spec'", "25") local threshold = 0.25
        if strpos("`spec'", "40") local threshold = 0.40

        local che che_`spec'
        local over over_`spec'

        quietly svy: mean `che' `over'
        local h = _b[`che']
        local hse = _se[`che']
        local o = _b[`over']
        local ose = _se[`over']
        local mpo = cond(`h' > 0, `o' / `h', .)

        post `summ' ("`wt'") ("`scope'") ("`denominator'") (`threshold') ///
            ("`che'") ("`over'") (`h') (`hse') (`o') (`ose') (`mpo')
    }
}

postclose `summ'

preserve
    use `summdata', clear
    export delimited using "$tab/che_summary.csv", replace
restore


*==============================================================================*
*                                                                              *
*     SECTION 3: DENOMINATOR SENSITIVITY TABLE                                 *
*                                                                              *
*==============================================================================*

tempname sens prevall
tempfile sensdata prevalldata
postfile `sens' str10 weight str4 scope str8 denominator double threshold ///
    str24 primary_variable str29 nlss_variable ///
    double primary_prev primary_se nlss_prev nlss_se difference ///
    using `sensdata', replace

postfile `prevall' str10 weight str4 scope str8 denominator double threshold ///
    str8 convention str29 variable double prevalence se ci_low ci_high ///
    using `prevalldata', replace

foreach wt in hhs_wt ind_wt {
    svyset psu_number [pw = `wt']

    foreach spec of local specs {
        local scope "oop"
        if substr("`spec'", 1, 4) == "oopg" local scope "oopg"

        local denominator "total"
        if strpos("`spec'", "_nf") local denominator "nonfood"

        local threshold = 0.10
        if strpos("`spec'", "20") local threshold = 0.20
        if strpos("`spec'", "25") local threshold = 0.25
        if strpos("`spec'", "40") local threshold = 0.40

        local primary che_`spec'
        local nlss che_`spec'_nlss

        quietly svy: mean `primary'
        local p = _b[`primary']
        local pse = _se[`primary']
        local plo = `p' - invnormal(0.975) * `pse'
        local phi = `p' + invnormal(0.975) * `pse'
        post `prevall' ("`wt'") ("`scope'") ("`denominator'") (`threshold') ///
            ("primary") ("`primary'") (`p') (`pse') (`plo') (`phi')

        quietly svy: mean `nlss'
        local n = _b[`nlss']
        local nse = _se[`nlss']
        local nlo = `n' - invnormal(0.975) * `nse'
        local nhi = `n' + invnormal(0.975) * `nse'
        post `prevall' ("`wt'") ("`scope'") ("`denominator'") (`threshold') ///
            ("nlss") ("`nlss'") (`n') (`nse') (`nlo') (`nhi')

        post `sens' ("`wt'") ("`scope'") ("`denominator'") (`threshold') ///
            ("`primary'") ("`nlss'") (`p') (`pse') (`n') (`nse') (`p' - `n')
    }
}

postclose `sens'
postclose `prevall'

preserve
    use `sensdata', clear
    export delimited using "$tab/che_sensitivity.csv", replace
restore

preserve
    use `prevalldata', clear
    export delimited using "$tab/che_prevalence_all.csv", replace
restore


*==============================================================================*
*                                                                              *
*     SECTION 4: SUBGROUP PREVALENCE                                           *
*                                                                              *
*==============================================================================*

tempname subg
tempfile subgdata
postfile `subg' str10 weight str4 scope str8 denominator double threshold ///
    str24 che_variable str24 subgroup str80 subgroup_label double subgroup_value ///
    double prevalence prevalence_se using `subgdata', replace

local groups poor quintile_pcep prov ad_4 caste_ethnicity head_edu_n ///
    has_elderly has_disabled_member

foreach wt in hhs_wt ind_wt {
    svyset psu_number [pw = `wt']

    foreach spec of local specs {
        local scope "oop"
        if substr("`spec'", 1, 4) == "oopg" local scope "oopg"

        local denominator "total"
        if strpos("`spec'", "_nf") local denominator "nonfood"

        local threshold = 0.10
        if strpos("`spec'", "20") local threshold = 0.20
        if strpos("`spec'", "25") local threshold = 0.25
        if strpos("`spec'", "40") local threshold = 0.40

        local che che_`spec'

        foreach group of local groups {
            levelsof `group' if !missing(`group'), local(levels)
            local vl : value label `group'

            foreach level of local levels {
                tempvar subpop
                gen byte `subpop' = (`group' == `level') if !missing(`group')
                quietly count if `subpop' == 1
                if r(N) > 0 {
                    quietly svy, subpop(`subpop'): mean `che'
                    local prev = _b[`che']
                    local prevse = _se[`che']
                    if "`vl'" != "" {
                        local glab : label `vl' `level'
                    }
                    else {
                        local glab "`level'"
                    }

                    post `subg' ("`wt'") ("`scope'") ("`denominator'") (`threshold') ///
                        ("`che'") ("`group'") ("`glab'") (`level') ///
                        (`prev') (`prevse')
                }
                drop `subpop'
            }
        }
    }
}

postclose `subg'

preserve
    use `subgdata', clear
    export delimited using "$tab/che_subgroups.csv", replace
restore


*==============================================================================*
*                                                                              *
*     SECTION 5: CONCENTRATION AND RANK-WEIGHTED MEASURES                      *
*                                                                              *
*==============================================================================*

tempname eq
tempfile eqdata
postfile `eq' str10 weight str4 scope str8 denominator double threshold ///
    str12 measure str24 variable double mean ci_pre_oop ci_pcep ci_delta ///
    double rank_weighted_pre_oop using `eqdata', replace

foreach wt in hhs_wt ind_wt {
    preserve
        keep if !missing(pre_oop, pcep, `wt') & `wt' > 0

        sort pre_oop psu_number hh_number
        quietly summarize `wt', meanonly
        gen double _rank_w_pre = `wt' / r(sum)
        gen double _rank_cum_pre = sum(_rank_w_pre)
        gen double _frac_rank_pre = _rank_cum_pre - 0.5 * _rank_w_pre

        sort pcep psu_number hh_number
        quietly summarize `wt', meanonly
        gen double _rank_w_pcep = `wt' / r(sum)
        gen double _rank_cum_pcep = sum(_rank_w_pcep)
        gen double _frac_rank_pcep = _rank_cum_pcep - 0.5 * _rank_w_pcep

        foreach spec of local specs {
            local scope "oop"
            if substr("`spec'", 1, 4) == "oopg" local scope "oopg"

            local denominator "total"
            if strpos("`spec'", "_nf") local denominator "nonfood"

            local threshold = 0.10
            if strpos("`spec'", "20") local threshold = 0.20
            if strpos("`spec'", "25") local threshold = 0.25
            if strpos("`spec'", "40") local threshold = 0.40

            foreach measure in headcount overshoot {
                if "`measure'" == "headcount" local v che_`spec'
                if "`measure'" == "overshoot" local v over_`spec'

                quietly summarize `v' [aw = `wt'], meanonly
                local mu = r(mean)

                if `mu' > 0 {
                    tempvar yr_pre yr_pcep
                    gen double `yr_pre' = `v' * _frac_rank_pre
                    gen double `yr_pcep' = `v' * _frac_rank_pcep

                    quietly summarize `yr_pre' [aw = `wt'], meanonly
                    local mean_yr_pre = r(mean)
                    quietly summarize _frac_rank_pre [aw = `wt'], meanonly
                    local mean_r_pre = r(mean)
                    local ci_pre = (2 / `mu') * (`mean_yr_pre' - `mu' * `mean_r_pre')

                    quietly summarize `yr_pcep' [aw = `wt'], meanonly
                    local mean_yr_pcep = r(mean)
                    quietly summarize _frac_rank_pcep [aw = `wt'], meanonly
                    local mean_r_pcep = r(mean)
                    local ci_p = (2 / `mu') * (`mean_yr_pcep' - `mu' * `mean_r_pcep')

                    local rw_pre = `mu' * (1 - `ci_pre')
                    drop `yr_pre' `yr_pcep'
                }
                else {
                    local ci_pre = .
                    local ci_p = .
                    local rw_pre = .
                }

                post `eq' ("`wt'") ("`scope'") ("`denominator'") (`threshold') ///
                    ("`measure'") ("`v'") (`mu') (`ci_pre') (`ci_p') ///
                    (`ci_pre' - `ci_p') (`rw_pre')
            }
        }
    restore
}

postclose `eq'

preserve
    use `eqdata', clear
    export delimited using "$tab/che_equity_indices.csv", replace
restore


*------------------------------------------------------------------------------*
**#                     End of do file
*------------------------------------------------------------------------------*

log close
