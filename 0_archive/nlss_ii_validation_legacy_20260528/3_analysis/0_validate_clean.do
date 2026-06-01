*------------------------------------------------------------------------------*
*              Validate NLSS II Cleaned CHE Dataset Contract                   *
/*

    Purpose:
        Check that the NLSS II prep output has the canonical variables needed
        by the NLSS IV-style analysis scripts.

    Input:
        1_data/2_clean/catastrophic_health_exp.dta

    Output:
        6_output/clean_dataset_validation.csv

*/
*------------------------------------------------------------------------------*

local dofilename "0_validate_clean"

cap log close
log using "$log/`dofilename'.log", replace

capture confirm file "$data_clean/catastrophic_health_exp.dta"
if _rc {
    di as error "Missing cleaned dataset: $data_clean/catastrophic_health_exp.dta"
    log close
    exit 601
}

use "$data_clean/catastrophic_health_exp.dta", clear

tempname checks
tempfile checkdata
postfile `checks' str80 check str8 status str160 detail using `checkdata', replace

local core_vars ///
    psu_number hh_number prov domain hhsize hhs_wt ind_wt ad_4 ///
    pline fpline pcep pcep_food pcep_nonfood paasche ///
    oopg oopg_ann oopg_pc_ann_real oopg_real ///
    oop oop_ann oop_pc_ann_real oop_real ///
    tot_real_hh_mo nf_real_hh_mo totexp_real_hh_mo ctp_real_hh_mo ///
    oopg_sh_tot oop_sh_tot oopg_sh_nf oop_sh_nf ///
    oopg_sh_tot_nlss oop_sh_tot_nlss oopg_sh_nf_nlss oop_sh_nf_nlss ///
    che_oopg_tot10 che_oop_tot10 che_oopg_tot20 che_oop_tot20 ///
    che_oopg_nf25 che_oop_nf25 che_oopg_nf40 che_oop_nf40 ///
    che_oopg_tot10_nlss che_oop_tot10_nlss ///
    che_oopg_tot20_nlss che_oop_tot20_nlss ///
    che_oopg_nf25_nlss che_oop_nf25_nlss ///
    che_oopg_nf40_nlss che_oop_nf40_nlss ///
    over_oopg_tot10 over_oop_tot10 over_oopg_tot20 over_oop_tot20 ///
    over_oopg_nf25 over_oop_nf25 over_oopg_nf40 over_oop_nf40 ///
    pre_oopg pre_oop

local missing_vars ""
foreach v of local core_vars {
    capture confirm variable `v'
    if _rc local missing_vars "`missing_vars' `v'"
}

if trim("`missing_vars'") == "" {
    post `checks' ("canonical variables present") ("PASS") ("all required variables found")
}
else {
    post `checks' ("canonical variables present") ("FAIL") (`"`=trim("`missing_vars'")'"')
}

if "${expected_households}" != "" {
    local expected = real("${expected_households}")
    post `checks' ("expected household count") ///
        (cond(_N == `expected', "PASS", "FAIL")) ///
        (`"N=`=_N', expected=`expected'"')
}
else {
    post `checks' ("expected household count") ("PENDING") (`"N=`=_N'; set global expected_households after confirming NLSS II sample"')
}

capture assert abs(pcep - (pcep_food + pcep_nonfood)) < 1
post `checks' ("pcep food plus nonfood identity") ///
    (cond(_rc == 0, "PASS", "FAIL")) ("max difference should be below 1 NPR")

capture assert oop >= oopg if !missing(oop, oopg)
post `checks' ("oop >= oopg") (cond(_rc == 0, "PASS", "FAIL")) ("checked where both are nonmissing")

capture assert ctp_real_hh_mo > 0 if !missing(ctp_real_hh_mo)
post `checks' ("ctp_real_hh_mo positive") (cond(_rc == 0, "PASS", "FAIL")) ("checked nonmissing values")

capture assert totexp_real_hh_mo > 0 if !missing(totexp_real_hh_mo)
post `checks' ("totexp_real_hh_mo positive") (cond(_rc == 0, "PASS", "FAIL")) ("checked nonmissing values")

capture assert pre_oop >= pcep if !missing(pre_oop, pcep)
post `checks' ("pre_oop >= pcep") (cond(_rc == 0, "PASS", "FAIL")) ("depends on confirmed welfare convention")

capture assert che_oop_tot10 >= che_oopg_tot10 if !missing(che_oop_tot10, che_oopg_tot10)
post `checks' ("OOP tot10 CHE dominates OOPG") (cond(_rc == 0, "PASS", "FAIL")) ("checked nonmissing values")

capture assert che_oop_tot20 >= che_oopg_tot20 if !missing(che_oop_tot20, che_oopg_tot20)
post `checks' ("OOP tot20 CHE dominates OOPG") (cond(_rc == 0, "PASS", "FAIL")) ("checked nonmissing values")

capture assert che_oop_nf25 >= che_oopg_nf25 if !missing(che_oop_nf25, che_oopg_nf25)
post `checks' ("OOP nf25 CHE dominates OOPG") (cond(_rc == 0, "PASS", "FAIL")) ("checked nonmissing values")

capture assert che_oop_nf40 >= che_oopg_nf40 if !missing(che_oop_nf40, che_oopg_nf40)
post `checks' ("OOP nf40 CHE dominates OOPG") (cond(_rc == 0, "PASS", "FAIL")) ("checked nonmissing values")

if "${official_poverty_rate}" != "" {
    svyset psu_number [pw = ind_wt]
    gen _poor_validate = (pcep < pline) if !missing(pcep, pline)
    quietly svy: mean _poor_validate
    local observed = 100 * _b[_poor_validate]
    local target = real("${official_poverty_rate}")
    local observed_fmt : display %6.3f `observed'
    local target_fmt : display %6.3f `target'
    post `checks' ("official poverty headcount") ///
        (cond(abs(`observed' - `target') <= 0.05, "PASS", "FAIL")) ///
        (`"observed=`observed_fmt'%, target=`target_fmt'%"')
}
else {
    post `checks' ("official poverty headcount") ("PENDING") ("set global official_poverty_rate after confirming NLSS II benchmark")
}

postclose `checks'

preserve
    use `checkdata', clear
    export delimited using "$tab/clean_dataset_validation.csv", replace
restore

di as result "Saved validation checks to $tab/clean_dataset_validation.csv"

log close
