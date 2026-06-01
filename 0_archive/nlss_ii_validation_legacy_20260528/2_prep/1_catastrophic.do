*------------------------------------------------------------------------------*
*           Phase 1: NLSS II Catastrophic Health Expenditure Prep              *
/*

    Purpose:
        Build the NLSS II household-level analysis dataset for the validation
        exercise, using the same canonical output names as the NLSS IV workflow.

    Output target:
        1_data/2_clean/catastrophic_health_exp.dta

    Status:
        Scaffold only. After NLSS II raw files are added, use the raw inventory
        and the variable map template to implement the survey-specific merges
        and transformations.

*/
*------------------------------------------------------------------------------*

local dofilename "1_catastrophic"

cap log close
log using "$log/`dofilename'.log", replace

local files : dir "$data_raw" files "*.dta"

if `"`files'"' == "" {
    di as error "No .dta files found in $data_raw"
    di as text  "Add original NLSS II files to 1_data/1_raw/ before running prep."
    log close
    exit 601
}

capture confirm file "$doc/raw_variable_inventory.csv"
if _rc {
    di as text "Raw variable inventory not found; running inventory first."
    do "$prep/0_inventory_raw.do"
}

di as text "{hline 78}"
di as text "NLSS II prep scaffold"
di as text "{hline 78}"
di as text "Next implementation step:"
di as text "  1. Review $doc/raw_file_inventory.csv and $doc/raw_variable_inventory.csv"
di as text "  2. Fill $doc/nlss_ii_variable_map_template.csv"
di as text "  3. Implement the sections below using NLSS II source fields"
di as text "{hline 78}"


*==============================================================================*
* SECTION 1: CONSUMPTION, POVERTY, WEIGHTS, AND GEOGRAPHY
*==============================================================================*

/*
Required canonical variables:
    psu_number hh_number prov domain hhsize hhs_wt ind_wt ad_4
    pline fpline pcep pcep_food pcep_nonfood paasche

Confirm:
    - household identifier fields
    - household and individual/person weights
    - official welfare aggregate and poverty line variables
    - whether pcep includes or excludes health spending in NLSS II
    - area/province/domain coding available in NLSS II
*/


*==============================================================================*
* SECTION 2: HOUSEHOLD HEAD AND COMPOSITION
*==============================================================================*

/*
Required canonical variables:
    head_sex head_age head_female head_marital caste_ethnicity
    head_education head_edu_level head_literate
    n_adults n_children n_elderly n_under5 n_working_age n_hh_members
    adult_equiv dep_ratio has_elderly has_under5

Confirm:
    - household member filter
    - head relationship code
    - head's own education source
    - caste/ethnicity code comparability with NLSS IV
*/


*==============================================================================*
* SECTION 3: HEALTH EXPENDITURE AND HEALTH NEED
*==============================================================================*

/*
Required canonical variables:
    oopg oopg_ann oopg_pc_ann_real oopg_real
    oop oop_ann oop_pc_ann_real oop_real
    hh_comm_total_30d hh_ncd_total_annual has_disabled_member

Confirm:
    - health spending recall window
    - which fields are comparable to NLSS IV Section 8(B) communicable/injury OOP
    - whether NLSS II has annual/chronic/NCD spending that can support `oop`
    - whether disability or chronic illness indicators are available
*/


*==============================================================================*
* SECTION 4: DENOMINATORS, CHE FLAGS, AND POVERTY VARIABLES
*==============================================================================*

/*
Required canonical variables:
    tot_real_hh_mo nf_real_hh_mo totexp_real_hh_mo ctp_real_hh_mo
    oopg_sh_tot oop_sh_tot oopg_sh_nf oop_sh_nf
    oopg_sh_tot_nlss oop_sh_tot_nlss oopg_sh_nf_nlss oop_sh_nf_nlss
    che_oopg_tot10 che_oop_tot10 che_oopg_tot20 che_oop_tot20
    che_oopg_nf25 che_oop_nf25 che_oopg_nf40 che_oop_nf40
    same CHE names with suffix _nlss
    matching over_oopg_* and over_oop_* variables
    pre_oopg pre_oop

Use the NLSS IV convention only after confirming NLSS II welfare construction:
    - health-including total denominator = pcep * hhsize / 12 + oop_real
    - capacity to pay = pcep_nonfood * hhsize / 12 + oop_real
    - post-payment welfare = pcep only if official pcep is health-excluding
    - pre-OOP welfare = pcep + real per-capita OOP only under that convention
*/


di as error "NLSS II prep mapping is not implemented yet."
di as error "This deliberate stop prevents accidental use of NLSS IV field names on NLSS II data."

log close
exit 459
