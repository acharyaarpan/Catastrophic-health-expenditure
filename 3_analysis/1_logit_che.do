*------------------------------------------------------------------------------*
*           Phase 2b: Logistic Regression — Determinants of CHE               *
/*

    Author:             Arpan 
    Date created:       21st April 2026
    Date updated:       21st April 2026
    Last updated by:    Arpan

    Notes:
        Survey-weighted logistic regression models estimating determinants
        of catastrophic health expenditure (CHE) using NLSS IV data.

        Four models:
          Model 1: Communicable exp > 10% monthly consumption (primary)
          Model 2: Communicable + NCD > 10% monthly consumption
          Model 3: Communicable exp > 20% monthly consumption
          Model 4: Communicable + NCD > 20% monthly consumption

        Uses svyset with PSU clustering and household weights.

    Dependencies:
        - catastrophic_health_exp.dta (from $data_clean)
        - Run 0_master.do before this file

    Output:
        - Regression tables in $tab (via esttab)
        - Log file in $log
*/
*------------------------------------------------------------------------------*

local dofilename "1_logit_che"

cap log close
log using "$log/`dofilename'.log", replace

use "$data_clean/catastrophic_health_exp.dta", clear


*==============================================================================*
*                                                                              *
*     SECTION 1: SURVEY DESIGN & VARIABLE PREPARATION                         *
*                                                                              *
*==============================================================================*

* --- 1a: Set survey design ---
* PSU clustering with household probability weights
svyset psu_number [pw = hhs_wt]

* --- 1b: Recode head education into ordered numeric for i. prefix ---
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
    4 "Secondary (9-SLC)" 5 "Higher secondary" 6 "Bachelor and above"
label values head_edu_n edu_lbl
label variable head_edu_n "Education of HH head (ordered)"

* --- 1c: Quick check of outcome distributions ---
di _n "{hline 60}"
di "CHE OUTCOME DISTRIBUTIONS (unweighted)"
di "{hline 60}"
foreach v in che_comm_100 che_combined_100 che_comm_20 che_combined_20 {
    count if `v' == 1
    di "`v': " r(N) " HHs (" %5.2f r(N)/9600*100 "%)"
}


*==============================================================================*
*                                                                              *
*     SECTION 2: MODEL 1 — COMMUNICABLE > 10% (PRIMARY MODEL)                 *
*     This is the main model of interest                                       *
*                                                                              *
*==============================================================================*

di _n "{hline 60}"
di "MODEL 1: Communicable > 10% monthly consumption (svy: logit)"
di "{hline 60}"

svy: logit che_comm_100 ///
    head_age hhsize head_female head_literate              /// Head & household
    has_elderly has_under5 has_disabled_member            /// Vulnerability
    improved_sanitation improved_water clean_fuel         /// Living standards
    receives_remittance has_loan poor                     /// Economic
    i.head_edu_n                                          /// Education (ref: No education)
    ib2.caste_ethnicity                                   /// Caste (ref: Hill Caste = 2)
    ib2.ad_4                                              /// Area type (ref: Rural = 2)
    ib2.prov                                              /// Province (ref: Bagmati = 2)
    , or

estimates store m1_comm10

* Goodness of fit note: estat gof not available after svy
* Report pseudo-R² from the log-likelihood
di "Log pseudolikelihood: " e(ll)


*==============================================================================*
*                                                                              *
*     SECTION 3: MODEL 2 — COMBINED > 10%                                     *
*                                                                              *
*==============================================================================*

di _n "{hline 60}"
di "MODEL 2: Combined (communicable + NCD) > 10% monthly consumption"
di "{hline 60}"

svy: logit che_combined_100 ///
    head_age hhsize head_female                          ///
    has_elderly has_under5 has_disabled_member            ///
    has_health_insurance                                  ///
    improved_sanitation improved_water clean_fuel         ///
    receives_remittance has_loan poor                     ///
    i.head_edu_n                                          ///
    ib2.caste_ethnicity                                   ///
    ib2.ad_4                                              ///
    ib2.prov                                              ///
    , or

estimates store m2_comb10


*==============================================================================*
*                                                                              *
*     SECTION 4: MODEL 3 — COMMUNICABLE > 20%                                 *
*                                                                              *
*==============================================================================*

di _n "{hline 60}"
di "MODEL 3: Communicable > 20% monthly consumption"
di "{hline 60}"

svy: logit che_comm_20 ///
    head_age hhsize head_female                          ///
    has_elderly has_under5 has_disabled_member            ///
    has_health_insurance                                  ///
    improved_sanitation improved_water clean_fuel         ///
    receives_remittance has_loan poor                     ///
    i.head_edu_n                                          ///
    ib2.caste_ethnicity                                   ///
    ib2.ad_4                                              ///
    ib2.prov                                              ///
    , or

estimates store m3_comm20


*==============================================================================*
*                                                                              *
*     SECTION 5: MODEL 4 — COMBINED > 20%                                     *
*                                                                              *
*==============================================================================*

di _n "{hline 60}"
di "MODEL 4: Combined (communicable + NCD) > 20% monthly consumption"
di "{hline 60}"

svy: logit che_combined_20 ///
    head_age hhsize head_female                          ///
    has_elderly has_under5 has_disabled_member            ///
    has_health_insurance                                  ///
    improved_sanitation improved_water clean_fuel         ///
    receives_remittance has_loan poor                     ///
    i.head_edu_n                                          ///
    ib2.caste_ethnicity                                   ///
    ib2.ad_4                                              ///
    ib2.prov                                              ///
    , or

estimates store m4_comb20


*==============================================================================*
*                                                                              *
*     SECTION 6: COMPARISON TABLE — ALL FOUR MODELS                            *
*                                                                              *
*==============================================================================*

* Display all four models side-by-side as odds ratios
esttab m1_comm10 m2_comb10 m3_comm20 m4_comb20, ///
    eform                                          /// Odds ratios
    cells(b(star fmt(3)) ci(par fmt(3)))           /// OR with CI
    stats(N ll aic bic, fmt(0 1 1 1)               ///
        labels("N" "Log pseudolikelihood" "AIC" "BIC")) ///
    mtitles("Comm>10%" "Comb>10%" "Comm>20%" "Comb>20%") ///
    title("Determinants of Catastrophic Health Expenditure — Survey-Weighted Odds Ratios") ///
    star(* 0.05 ** 0.01 *** 0.001)                 ///
    note("Survey-weighted logistic regression. PSU clustering with household weights." ///
         "Reference: Education=No education, Caste=Hill Caste, Area=Rural, Province=Bagmati.") ///
    label varwidth(35)

* Export to RTF
cap mkdir "$tab"
esttab m1_comm10 m2_comb10 m3_comm20 m4_comb20 ///
    using "$tab/logit_che_svy_results.rtf", replace ///
    eform                                        ///
    cells(b(star fmt(3)) ci(par fmt(3)))         ///
    stats(N ll aic bic, fmt(0 1 1 1)             ///
        labels("N" "Log pseudolikelihood" "AIC" "BIC")) ///
    mtitles("Comm>10%" "Comb>10%" "Comm>20%" "Comb>20%") ///
    title("Determinants of Catastrophic Health Expenditure — Survey-Weighted Odds Ratios") ///
    star(* 0.05 ** 0.01 *** 0.001)               ///
    note("Survey-weighted logistic regression. PSU clustering with household weights." ///
         "Reference: Education=No education, Caste=Hill Caste, Area=Rural, Province=Bagmati.") ///
    label varwidth(35)

di _n "{hline 60}"
di "Results exported to: $tab/logit_che_svy_results.rtf"
di "{hline 60}"


*==============================================================================*
*                                                                              *
*     SECTION 7: AVERAGE MARGINAL EFFECTS (Model 1 — Primary)                 *
*                                                                              *
*==============================================================================*

di _n "{hline 60}"
di "AVERAGE MARGINAL EFFECTS — Model 1 (Communicable > 10%)"
di "{hline 60}"

* Restore primary model and compute AMEs
estimates restore m1_comm10
margins, dydx(*) post

estimates store m1_margins

esttab m1_margins, ///
    cells(b(star fmt(4)) se(par fmt(4))) ///
    stats(N, fmt(0) labels("N"))         ///
    title("Average Marginal Effects — CHE (Communicable > 10%)") ///
    star(* 0.05 ** 0.01 *** 0.001)       ///
    note("Survey-weighted average marginal effects from svy: logit.") ///
    label varwidth(35)

esttab m1_margins ///
    using "$tab/marginal_effects_m1.rtf", replace ///
    cells(b(star fmt(4)) se(par fmt(4))) ///
    stats(N, fmt(0) labels("N"))         ///
    title("Average Marginal Effects — CHE (Communicable > 10%)") ///
    star(* 0.05 ** 0.01 *** 0.001)       ///
    note("Survey-weighted average marginal effects from svy: logit.") ///
    label varwidth(35)


*------------------------------------------------------------------------------*
**#                     End of do file
*------------------------------------------------------------------------------*

log close
