*------------------------------------------------------------------------------*
*           Phase 2a: Descriptive Statistics for oopg/OOP Analysis              *
/*

    Author:             Arpan
    Date created:       21st April 2026
    Date updated:       20th May 2026
    Last updated by:    Codex

    Notes:
        Produces weighted descriptive statistics for the parallel oopg/OOP
        analysis. oopg is communicable disease/injury OOP from NLSS Section 8B.
        OOP is oopg plus NCD spending converted to a monthly household amount.

    Dependencies:
        - catastrophic_health_exp.dta (from $data_clean)
        - Run 0_master.do before this file

    Output:
        - descriptive_means.csv in $tab
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

* Household-level facts use hhs_wt. Population exposures and welfare
* distributions use ind_wt. Regressions remain household-weighted.
svyset psu_number [pw = hhs_wt]


*==============================================================================*
*                                                                              *
*     SECTION 2: VARIABLE PREPARATION                                          *
*                                                                              *
*==============================================================================*

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


*==============================================================================*
*                                                                              *
*     SECTION 3: OVERALL DESCRIPTIVE STATISTICS                                *
*                                                                              *
*==============================================================================*

tempname desc
tempfile descdata
postfile `desc' str18 statistic str32 variable str80 variable_label ///
    str10 weight double estimate se using `descdata', replace

svyset psu_number [pw = hhs_wt]
local hh_cont head_age hhsize adult_equiv dep_ratio oopg oop ///
    hh_ncd_total_annual total_consumption total_cons_mo

di _n "{hline 70}"
di "TABLE 1a: HH-WEIGHTED CONTINUOUS CHARACTERISTICS"
di "{hline 70}"
svy: mean `hh_cont'

foreach v of local hh_cont {
    local lab : variable label `v'
    if `"`lab'"' == "" local lab "`v'"
    post `desc' ("mean") ("`v'") ("`lab'") ("hhs_wt") (_b[`v']) (_se[`v'])
}

svyset psu_number [pw = ind_wt]
local ind_cont pctot_consumption pc_cons_ae pcep pcep_food pcep_nonfood

di _n "{hline 70}"
di "TABLE 1b: INDIVIDUAL-WEIGHTED WELFARE CHARACTERISTICS"
di "{hline 70}"
svy: mean `ind_cont'

foreach v of local ind_cont {
    local lab : variable label `v'
    if `"`lab'"' == "" local lab "`v'"
    post `desc' ("mean") ("`v'") ("`lab'") ("ind_wt") (_b[`v']) (_se[`v'])
}

svyset psu_number [pw = hhs_wt]
local hh_bin head_female head_literate has_elderly has_under5 ///
    has_disabled_member receives_remittance remit_absentee remit_other ///
    has_loan che_oopg_tot10 che_oop_tot10 che_oopg_tot20 che_oop_tot20 ///
    che_oopg_nf25 che_oop_nf25 che_oopg_nf40 che_oop_nf40

di _n "{hline 70}"
di "TABLE 1c: HH-WEIGHTED BINARY CHARACTERISTICS"
di "{hline 70}"
foreach v of local hh_bin {
    svy: mean `v'
    local lab : variable label `v'
    if `"`lab'"' == "" local lab "`v'"
    post `desc' ("proportion") ("`v'") ("`lab'") ("hhs_wt") (_b[`v']) (_se[`v'])
}

svyset psu_number [pw = ind_wt]
local ind_bin improved_sanitation improved_water clean_fuel poor ///
    che_oopg_tot10 che_oop_tot10 che_oopg_tot20 che_oop_tot20 ///
    che_oopg_nf25 che_oop_nf25 che_oopg_nf40 che_oop_nf40

di _n "{hline 70}"
di "TABLE 1d: INDIVIDUAL-WEIGHTED BINARY CHARACTERISTICS"
di "{hline 70}"
foreach v of local ind_bin {
    svy: mean `v'
    local lab : variable label `v'
    if `"`lab'"' == "" local lab "`v'"
    post `desc' ("proportion") ("`v'") ("`lab'") ("ind_wt") (_b[`v']) (_se[`v'])
}

postclose `desc'

preserve
    use `descdata', clear
    export delimited using "$tab/descriptive_means.csv", replace
restore


*==============================================================================*
*                                                                              *
*     SECTION 4: CATEGORICAL DISTRIBUTIONS                                     *
*                                                                              *
*==============================================================================*

svyset psu_number [pw = hhs_wt]

di _n "{hline 70}"
di "EDUCATION OF HOUSEHOLD HEAD (HH-WEIGHTED)"
di "{hline 70}"
svy: proportion head_edu_n

svyset psu_number [pw = ind_wt]

di _n "{hline 70}"
di "POPULATION DISTRIBUTIONS (INDIVIDUAL-WEIGHTED)"
di "{hline 70}"
svy: proportion caste_ethnicity
svy: proportion prov
svy: proportion ad_4
svy: proportion quintile_pcep


*==============================================================================*
*                                                                              *
*     SECTION 5: CHARACTERISTICS BY MAIN CHE STATUS                            *
*                                                                              *
*==============================================================================*

svyset psu_number [pw = hhs_wt]

foreach outcome in che_oopg_tot10 che_oop_tot10 {
    di _n "{hline 70}"
    di "CHARACTERISTICS BY `outcome'"
    di "{hline 70}"

    foreach v in head_age hhsize adult_equiv dep_ratio oopg oop ///
                 total_consumption pc_cons_ae {
        svy: mean `v', over(`outcome')
        test _b[c.`v'@0bn.`outcome'] = _b[c.`v'@1.`outcome']
    }

    foreach v in head_female head_literate has_elderly has_under5 ///
                 has_disabled_member improved_sanitation improved_water ///
                 clean_fuel receives_remittance has_loan poor {
        svy: proportion `v', over(`outcome')
    }

    svy: tab head_edu_n `outcome', col pearson
    svy: tab caste_ethnicity `outcome', col pearson
    svy: tab ad_4 `outcome', col pearson
    svy: tab prov `outcome', col pearson
    svy: tab quintile_pcep `outcome', col pearson
}


*------------------------------------------------------------------------------*
**#                     End of do file
*------------------------------------------------------------------------------*

log close
