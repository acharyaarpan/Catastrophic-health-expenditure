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

* Set survey design: PSU clustering + household weights
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
*                                                                              *
*==============================================================================*

di _n "{hline 70}"
di "TABLE 1a: OVERALL WEIGHTED SAMPLE CHARACTERISTICS (N = 9,600)"
di "{hline 70}"

di _n "--- Continuous Variables (weighted) ---"
svy: mean head_age hhsize adult_equiv dep_ratio ///
         hh_comm_total_30d hh_ncd_total_annual hh_ncd_total_monthly ///
         total_consumption pc_cons_ae pctot_consumption
estat sd

di _n "--- Categorical / Binary Variables (weighted proportions) ---"
foreach v in head_female head_literate has_elderly has_under5 has_disabled_member ///
             improved_sanitation improved_water clean_fuel ///
             receives_remittance remit_absentee remit_other has_loan poor ///
             che_comm_100 che_combined_100 che_comm_20 che_combined_20 {
    svy: proportion `v'
}

di _n "--- Education of Head (weighted) ---"
svy: proportion head_edu_n

di _n "--- Caste/Ethnicity (weighted) ---"
svy: proportion caste_ethnicity

di _n "--- Area Type (weighted) ---"
svy: proportion ad_4

di _n "--- Province (weighted) ---"
svy: proportion prov

di _n "--- Consumption Quintile (weighted) ---"
svy: proportion quintile_pcep


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
    test [`v']0 = [`v']1
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
