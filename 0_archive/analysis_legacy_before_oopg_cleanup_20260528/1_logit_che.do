*------------------------------------------------------------------------------*
*           Phase 2b: Logistic Regression - Determinants of CHE                *
/*

    Author:             Arpan
    Date created:       21st April 2026
    Date updated:       20th May 2026
    Last updated by:    Codex

    Notes:
        Survey-weighted logistic regression models estimating determinants
        of catastrophic oopg and OOP using NLSS IV data.

        Main models:
          Model 1: oopg > 10% nominal total monthly consumption plus OOPG
          Model 2: OOP > 10% nominal total monthly consumption plus OOPG

        Supplementary models:
          Model 3: oopg > 40% real nonfood consumption plus OOPG
          Model 4: OOP > 40% real nonfood consumption plus OOPG

    Dependencies:
        - catastrophic_health_exp.dta (from $data_clean)
        - Run 0_master.do before this file

    Output:
        - logit_oopg_oop_svy_results.rtf
        - logit_oopg_oop_supplementary.rtf if supplementary models converge
        - marginal_effects_oopg_oop.rtf
        - marginal_effects_oopg_oop_supplementary.rtf if supplementary models converge
        - regression_model_status.csv
        - Log file in $log
*/
*------------------------------------------------------------------------------*

local dofilename "1_logit_che"

cap log close
log using "$log/`dofilename'.log", replace

use "$data_clean/catastrophic_health_exp.dta", clear


*==============================================================================*
*                                                                              *
*     SECTION 1: SURVEY DESIGN & VARIABLE PREPARATION                          *
*                                                                              *
*==============================================================================*

svyset psu_number [pw = hhs_wt]

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
label variable head_edu_n "Education of HH head (ordered)"

local covars ///
    head_age hhsize head_female head_literate              ///
    has_elderly has_under5 has_disabled_member             ///
    improved_sanitation improved_water clean_fuel          ///
    receives_remittance has_loan poor                      ///
    i.head_edu_n                                           ///
    ib21.caste_ethnicity                                   ///
    ib3.ad_4                                               ///
    ib3.prov

di _n "{hline 70}"
di "CHE OUTCOME DISTRIBUTIONS (UNWEIGHTED)"
di "{hline 70}"
foreach v in che_oopg_tot10 che_oop_tot10 che_oopg_tot20 che_oop_tot20 ///
             che_oopg_nf25 che_oop_nf25 che_oopg_nf40 che_oop_nf40 {
    count if `v' == 1
    di "`v': " r(N) " HHs (" %5.2f r(N)/9600*100 "%)"
}


*==============================================================================*
*                                                                              *
*     SECTION 2: SURVEY-WEIGHTED LOGIT MODELS                                  *
*                                                                              *
*==============================================================================*

di _n "{hline 70}"
di "MODEL 1: oopg > 10% total monthly consumption"
di "{hline 70}"
svy: logit che_oopg_tot10 `covars', or
estimates store m1_oopg_tot10

di _n "{hline 70}"
di "MODEL 2: OOP > 10% total monthly consumption"
di "{hline 70}"
svy: logit che_oop_tot10 `covars', or
estimates store m2_oop_tot10

tempname status
tempfile statusdata
postfile `status' str24 model str24 outcome str14 role int rc str80 note ///
    using `statusdata', replace
post `status' ("m1_oopg_tot10") ("che_oopg_tot10") ("main") (0) ("converged")
post `status' ("m2_oop_tot10") ("che_oop_tot10") ("main") (0) ("converged")

di _n "{hline 70}"
di "MODEL 3: oopg > 40% real nonfood consumption plus OOPG"
di "{hline 70}"
capture noisily svy: logit che_oopg_nf40 `covars', or iterate(30)
local rc_oopg_nf40 = _rc
local supp_models
if `rc_oopg_nf40' == 0 {
    capture local conv_oopg_nf40 = e(converged)
    if _rc local conv_oopg_nf40 = 1

    if `conv_oopg_nf40' == 1 {
        estimates store m3_oopg_nf40
        local supp_models `supp_models' m3_oopg_nf40
        post `status' ("m3_oopg_nf40") ("che_oopg_nf40") ("supplement") (0) ("converged")
    }
    else {
        post `status' ("m3_oopg_nf40") ("che_oopg_nf40") ("supplement") (430) ///
            ("estimated but convergence not achieved; excluded")
    }
}
else {
    post `status' ("m3_oopg_nf40") ("che_oopg_nf40") ("supplement") (`rc_oopg_nf40') ///
        ("svy logit did not converge; see log")
}

di _n "{hline 70}"
di "MODEL 4: OOP > 40% real nonfood consumption plus OOPG"
di "{hline 70}"
capture noisily svy: logit che_oop_nf40 `covars', or iterate(30)
local rc_oop_nf40 = _rc
if `rc_oop_nf40' == 0 {
    capture local conv_oop_nf40 = e(converged)
    if _rc local conv_oop_nf40 = 1

    if `conv_oop_nf40' == 1 {
        estimates store m4_oop_nf40
        local supp_models `supp_models' m4_oop_nf40
        post `status' ("m4_oop_nf40") ("che_oop_nf40") ("supplement") (0) ("converged")
    }
    else {
        post `status' ("m4_oop_nf40") ("che_oop_nf40") ("supplement") (430) ///
            ("estimated but convergence not achieved; excluded")
    }
}
else {
    post `status' ("m4_oop_nf40") ("che_oop_nf40") ("supplement") (`rc_oop_nf40') ///
        ("svy logit did not converge; see log")
}

postclose `status'

preserve
    use `statusdata', clear
    export delimited using "$tab/regression_model_status.csv", replace
restore


*==============================================================================*
*                                                                              *
*     SECTION 3: ODDS RATIO TABLE                                              *
*                                                                              *
*==============================================================================*

esttab m1_oopg_tot10 m2_oop_tot10, ///
    eform                                                      ///
    cells(b(star fmt(3)) ci(par fmt(3)))                       ///
    stats(N ll, fmt(0 1) labels("N" "Log pseudolikelihood"))  ///
    mtitles("oopg>10% total" "OOP>10% total") ///
    title("Determinants of Catastrophic Health Expenditure - Survey-Weighted Odds Ratios") ///
    star(* 0.05 ** 0.01 *** 0.001)                             ///
    note("Survey-weighted logistic regression. PSU clustering with household weights." ///
         "Reference: Education=No education, Caste=Mt./Hill Janajati, Area=Rural, Province=Bagmati.") ///
    label varwidth(35)

cap mkdir "$tab"
esttab m1_oopg_tot10 m2_oop_tot10 ///
    using "$tab/logit_oopg_oop_svy_results.rtf", replace  ///
    eform                                                  ///
    cells(b(star fmt(3)) ci(par fmt(3)))                   ///
    stats(N ll, fmt(0 1) labels("N" "Log pseudolikelihood")) ///
    mtitles("oopg>10% total" "OOP>10% total") ///
    title("Determinants of Catastrophic Health Expenditure - Survey-Weighted Odds Ratios") ///
    star(* 0.05 ** 0.01 *** 0.001)                         ///
    note("Survey-weighted logistic regression. PSU clustering with household weights." ///
         "Reference: Education=No education, Caste=Mt./Hill Janajati, Area=Rural, Province=Bagmati.") ///
    label varwidth(35)

if "`supp_models'" != "" {
    esttab `supp_models' using "$tab/logit_oopg_oop_supplementary.rtf", replace ///
        eform                                                  ///
        cells(b(star fmt(3)) ci(par fmt(3)))                   ///
        stats(N ll, fmt(0 1) labels("N" "Log pseudolikelihood")) ///
        title("Supplementary Nonfood-Denominator CHE Models")   ///
        star(* 0.05 ** 0.01 *** 0.001)                         ///
        note("Supplementary survey-weighted logistic regression. Non-converged models are listed in regression_model_status.csv.") ///
        label varwidth(35)
}


*==============================================================================*
*                                                                              *
*     SECTION 4: AVERAGE MARGINAL EFFECTS                                      *
*                                                                              *
*==============================================================================*

foreach model in m1_oopg_tot10 m2_oop_tot10 {
    estimates restore `model'
    margins, dydx(*) post
    estimates store ame_`model'
}

esttab ame_m1_oopg_tot10 ame_m2_oop_tot10, ///
    cells(b(star fmt(4)) se(par fmt(4)))                       ///
    stats(N, fmt(0) labels("N"))                                ///
    mtitles("oopg>10% total" "OOP>10% total") ///
    title("Average Marginal Effects - Determinants of CHE")     ///
    star(* 0.05 ** 0.01 *** 0.001)                              ///
    note("Survey-weighted average marginal effects from svy: logit.") ///
    label varwidth(35)

esttab ame_m1_oopg_tot10 ame_m2_oop_tot10 ///
    using "$tab/marginal_effects_oopg_oop.rtf", replace       ///
    cells(b(star fmt(4)) se(par fmt(4)))                      ///
    stats(N, fmt(0) labels("N"))                               ///
    mtitles("oopg>10% total" "OOP>10% total") ///
    title("Average Marginal Effects - Determinants of CHE")    ///
    star(* 0.05 ** 0.01 *** 0.001)                             ///
    note("Survey-weighted average marginal effects from svy: logit.") ///
    label varwidth(35)

local supp_ame_models
foreach model of local supp_models {
    estimates restore `model'
    capture noisily margins, dydx(*) post
    if _rc == 0 {
        estimates store ame_`model'
        local supp_ame_models `supp_ame_models' ame_`model'
    }
}

if "`supp_ame_models'" != "" {
    esttab `supp_ame_models' using "$tab/marginal_effects_oopg_oop_supplementary.rtf", replace ///
        cells(b(star fmt(4)) se(par fmt(4)))                  ///
        stats(N, fmt(0) labels("N"))                           ///
        title("Supplementary Average Marginal Effects - Nonfood CHE") ///
        star(* 0.05 ** 0.01 *** 0.001)                         ///
        note("Survey-weighted average marginal effects from converged supplementary svy: logit models.") ///
        label varwidth(35)
}


*------------------------------------------------------------------------------*
**#                     End of do file
*------------------------------------------------------------------------------*

log close
