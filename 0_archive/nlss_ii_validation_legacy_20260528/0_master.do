*------------------------------------------------------------------------------*
*                 NLSS II Validation Master Do File                            *
/*

    Purpose:
        Run the NLSS II validation workflow in this subfolder. This workspace
        mirrors the NLSS IV catastrophic health expenditure workflow while
        keeping NLSS II data and outputs separate.

    Run from:
        D:/Projects/CIH-project/consumption/nlss_ii_validation

*/
*------------------------------------------------------------------------------*

local dofilename "0_master"
version 17
clear all
macro drop _all
cap log close
set rmsg on
set more off
cap clear frames


*------------------------------------------------------------------------------*
**# Folder macros
*------------------------------------------------------------------------------*

if "`c(username)'" == "ACER" {
    global workspace "D:/Projects/CIH-project/consumption/nlss_ii_validation"
}

if "$workspace" == "" & fileexists("D:/Projects/CIH-project/consumption/nlss_ii_validation/0_master.do") {
    global workspace "D:/Projects/CIH-project/consumption/nlss_ii_validation"
}

if "$workspace" == "" {
    di as error "Please set the NLSS II validation workspace directory in 0_master.do"
    exit 601
}

global data             "$workspace/1_data"
    global data_raw     "$data/1_raw"
    global data_clean   "$data/2_clean"
    global data_analysis "$data/3_analysis"
    global data_tmp     "$data/4_tmp"
global prep             "$workspace/2_prep"
global analysis         "$workspace/3_analysis"
global log              "$workspace/4_log"
global doc              "$workspace/5_documentation"
global tab              "$workspace/6_output"

cap mkdir "$data"
cap mkdir "$data_raw"
cap mkdir "$data_clean"
cap mkdir "$data_analysis"
cap mkdir "$data_tmp"
cap mkdir "$prep"
cap mkdir "$analysis"
cap mkdir "$log"
cap mkdir "$doc"
cap mkdir "$tab"

cd "$workspace"


*------------------------------------------------------------------------------*
**# Survey constants to confirm after NLSS II raw files are added
*------------------------------------------------------------------------------*

global survey_cycle "NLSS II"
global survey_year "2003/04"

* Leave blank until verified from raw data/documentation.
global expected_households ""
global official_poverty_rate ""


*------------------------------------------------------------------------------*
**# Later analysis package notes
*------------------------------------------------------------------------------*

adopath + "${prep}/ado"
adopath + "${analysis}/ado"

foreach package in estout texify {
    cap which `package'
    if _rc {
        di as text "Note: `package' is not installed. Later table output scripts will need it."
    }
}


*------------------------------------------------------------------------------*
**# Workflow
*------------------------------------------------------------------------------*

do "$prep/0_inventory_raw.do"
do "$prep/1_catastrophic.do"

capture confirm file "$data_clean/catastrophic_health_exp.dta"
if _rc {
    di as error "Missing cleaned dataset: $data_clean/catastrophic_health_exp.dta"
    exit 601
}

do "$analysis/0_validate_clean.do"

/*
After the NLSS II prep script is implemented and validation passes, port the
NLSS IV analysis layer into this folder:

    3_analysis/0_descriptive.do
    3_analysis/1_logit_che.do
    3_analysis/2_catastrophic_measures.do
    3_analysis/3_poverty_impact.do

Python outputs can then be adapted to this workspace:

    python 3_analysis\2_pens_parade.py
    python 3_analysis\3_pens_parade_oop.py
    python 3_analysis\4_audit_workbook.py
*/


*------------------------------------------------------------------------------*
**# End
*------------------------------------------------------------------------------*
exit
