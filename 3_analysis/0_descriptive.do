*------------------------------------------------------------------------------*
*           Phase 2a: Descriptive Statistics for CHE Analysis                  *
/*

    Author:             Arpan 
    Date created:       21st April 2026
    Date updated:       21st April 2026
    Last updated by:    Arpan

    Notes:
        Produces weighted descriptive statistics (Table 1) for the CHE
        analysis. Shows sample characteristics overall and stratified
        by CHE status (communicable > 10% threshold).

    Dependencies:
        - catastrophic_health_exp.dta (from $data_clean)
        - Run 0_master.do before this file

    Output:
        - Descriptive table in $tab
        - Log file in $log
*/
*------------------------------------------------------------------------------*

local dofilename "0_descriptive"

cap log close
log using "$log/`dofilename'.log", replace

use "$data_clean/catastrophic_health_exp.dta", clear


*==============================================================================*
*                                                                              *
*     SECTION 1: SURVEY DESIGN SETUP                                           *
*                                                                              *
*==============================================================================*

* NOTE on weights:
*   This file uses TWO survey designs depending on the variable. The choice
*   of weight is documented in CLAUDE.md (section "Descriptive Table Weights").
*     - HH-weighted (hhs_wt): household-level facts (head characteristics,
*       household composition, household health spending, CHE outcomes,
*       household services like loans/remittances).
*     - Ind-weighted (ind_wt): population-level facts where the individual
*       is the unit of interest or where exposure is shared by everyone in
*       the household (sanitation, water, cooking fuel, poverty status,
*       caste/ethnicity, province, area type, consumption quintile).
*
* We re-svyset each time we switch between the two designs.

* Default: household weights (used in regressions and most descriptives)
svyset psu_number [pw = hhs_wt]


*==============================================================================*
*                                                                              *
*     SECTION 2: VARIABLE PREPARATION                                          *
*                                                                              *
*==============================================================================*

* Recode head education into numeric for tabulation
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


*==============================================================================*
*                                                                              *
*     SECTION 3: OVERALL WEIGHTED DESCRIPTIVE STATISTICS                       *
*     One weight per variable (see notes above and CLAUDE.md).                 *
*                                                                              *
*==============================================================================*

di _n "{hline 70}"
di "TABLE 1a: OVERALL WEIGHTED SAMPLE CHARACTERISTICS (N = 9,600)"
di "{hline 70}"

*------------------------------------------------------------------------------*
* 3.1a Continuous variables  ->  HH WEIGHTS
*      Household-level facts (head age, household size, household-level
*      health spending and total consumption).
*------------------------------------------------------------------------------*
svyset psu_number [pw = hhs_wt]

di _n "--- Continuous Variables (HH-weighted) ---"
svy: mean head_age hhsize adult_equiv dep_ratio ///
         hh_comm_total_30d hh_ncd_total_annual hh_ncd_total_monthly ///
         total_consumption
estat sd

*------------------------------------------------------------------------------*
* 3.1b Continuous variables  ->  INDIVIDUAL WEIGHTS
*      Per-capita consumption is a population-level living-standard measure,
*      so we report it weighted by individuals. pctot_consumption (simple
*      per-capita) is reported immediately before pc_cons_ae (adult-
*      equivalent-adjusted) so reviewers see both.
*------------------------------------------------------------------------------*
svyset psu_number [pw = ind_wt]

di _n "--- Continuous Variables (Individual-weighted) ---"
svy: mean pctot_consumption pc_cons_ae
estat sd

*------------------------------------------------------------------------------*
* 3.2 Binary variables  ->  HH WEIGHTS
*     Head characteristics, household composition, remittances, loans, and
*     all CHE outcomes (combined>10% / combined>20% intentionally dropped).
*------------------------------------------------------------------------------*
svyset psu_number [pw = hhs_wt]

di _n "--- Binary Variables, HH-weighted ---"
foreach v in head_female head_literate has_elderly has_under5 has_disabled_member ///
             receives_remittance remit_absentee remit_other has_loan ///
             che_comm_100 che_comm_20 {
    svy: proportion `v'
}

*------------------------------------------------------------------------------*
* 3.3 Binary variables  ->  INDIVIDUAL WEIGHTS
*     Sanitation, water, cooking fuel, and poverty status are population-level
*     exposures. CHE outcomes are reported under BOTH weights in Table 1 so
*     readers can compare the household-level prevalence ("% of households")
*     with the population-level exposure ("% of population in a CHE
*     household"); the two framings answer different questions. Regressions
*     in 1_logit_che.do remain HH-weighted because the unit of analysis is
*     the household.
*------------------------------------------------------------------------------*
svyset psu_number [pw = ind_wt]

di _n "--- Binary Variables, Individual-weighted ---"
foreach v in improved_sanitation improved_water clean_fuel poor ///
             che_comm_100 che_comm_20 {
    svy: proportion `v'
}

*------------------------------------------------------------------------------*
* 3.4 Education of HH head  ->  HH WEIGHTS
*------------------------------------------------------------------------------*
svyset psu_number [pw = hhs_wt]

di _n "--- Education of Head (HH-weighted) ---"
svy: proportion head_edu_n

*------------------------------------------------------------------------------*
* 3.5 Caste/ethnicity, province, area type, quintile  ->  INDIVIDUAL WEIGHTS
*     These describe the population distribution rather than the household
*     distribution.
*------------------------------------------------------------------------------*
svyset psu_number [pw = ind_wt]

di _n "--- Caste/Ethnicity (Individual-weighted) ---"
svy: proportion caste_ethnicity

di _n "--- Province (Individual-weighted) ---"
svy: proportion prov

di _n "--- Area Type (Individual-weighted) ---"
svy: proportion ad_4

di _n "--- Consumption Quintile (Individual-weighted) ---"
svy: proportion quintile_pcep

* Restore default HH weighting for any downstream code in this session
svyset psu_number [pw = hhs_wt]


*==============================================================================*
*                                                                              *
*     SECTION 4: TABLE 1 — CHARACTERISTICS BY CHE STATUS                       *
*     Stratified by che_comm_100 (communicable > 10% monthly consumption)      *
*                                                                              *
*==============================================================================*

di _n "{hline 70}"
di "TABLE 1b: CHARACTERISTICS BY CHE STATUS (Communicable > 10%)"
di "{hline 70}"

di _n "--- Continuous: Mean by CHE status ---"
foreach v in head_age hhsize adult_equiv dep_ratio ///
             hh_comm_total_30d total_consumption pc_cons_ae {
    svy: mean `v', over(che_comm_100)
    * Test for difference
    test _b[c.`v'@0bn.che_comm_100] = _b[c.`v'@1.che_comm_100]
}

di _n "--- Binary: Proportion by CHE status ---"
foreach v in head_female head_literate has_elderly has_under5 has_disabled_member ///
             improved_sanitation improved_water ///
             clean_fuel receives_remittance has_loan poor {
    svy: proportion `v', over(che_comm_100)
}

di _n "--- Education by CHE status ---"
svy: tab head_edu_n che_comm_100, col pearson

di _n "--- Caste by CHE status ---"
svy: tab caste_ethnicity che_comm_100, col pearson

di _n "--- Area type by CHE status ---"
svy: tab ad_4 che_comm_100, col pearson

di _n "--- Province by CHE status ---"
svy: tab prov che_comm_100, col pearson

di _n "--- Quintile by CHE status ---"
svy: tab quintile_pcep che_comm_100, col pearson


*==============================================================================*
*                                                                              *
*     SECTION 5: CHE PREVALENCE BY KEY SUBGROUPS                               *
*                                                                              *
*==============================================================================*

di _n "{hline 70}"
di "TABLE 2: CHE PREVALENCE BY SUBGROUP (weighted)"
di "{hline 70}"

di _n "--- By poverty status ---"
svy: proportion che_comm_100, over(poor)

di _n "--- By quintile ---"
svy: proportion che_comm_100, over(quintile_pcep)

di _n "--- By province ---"
svy: proportion che_comm_100, over(prov)

di _n "--- By area type ---"
svy: proportion che_comm_100, over(ad_4)

di _n "--- By caste/ethnicity ---"
svy: proportion che_comm_100, over(caste_ethnicity)

di _n "--- By education ---"
svy: proportion che_comm_100, over(head_edu_n)

di _n "--- By elderly member ---"
svy: proportion che_comm_100, over(has_elderly)

di _n "--- By disability ---"
svy: proportion che_comm_100, over(has_disabled_member)


*------------------------------------------------------------------------------*
**#                     End of do file
*------------------------------------------------------------------------------*

log close
