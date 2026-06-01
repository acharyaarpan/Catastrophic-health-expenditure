*------------------------------------------------------------------------------*
*                 Inventory NLSS II Raw Stata Files                            *
/*

    Purpose:
        Create a lightweight inventory of raw NLSS II .dta files and variables.
        This is the first step after adding data to 1_data/1_raw/.

    Outputs:
        5_documentation/raw_file_inventory.csv
        5_documentation/raw_variable_inventory.csv

*/
*------------------------------------------------------------------------------*

local dofilename "0_inventory_raw"

cap log close
log using "$log/`dofilename'.log", replace

local files : dir "$data_raw" files "*.dta"

if `"`files'"' == "" {
    di as error "No .dta files found in $data_raw"
    di as text  "Add original NLSS II files to 1_data/1_raw/, then rerun do 0_master.do."
    log close
    exit 601
}

tempname filepost varpost
tempfile filemeta varmeta

postfile `filepost' str160 file long n_obs int n_vars str160 sorted_by ///
    using `filemeta', replace

postfile `varpost' str160 file str32 variable str80 variable_label ///
    str24 storage_type str80 value_label using `varmeta', replace

foreach f of local files {
    quietly use "$data_raw/`f'", clear

    ds
    local vars `r(varlist)'
    local nvars : word count `vars'
    local nobs = _N
    local sortby : sortedby

    post `filepost' (`"`f'"') (`nobs') (`nvars') (`"`sortby'"')

    foreach v of varlist _all {
        local lab : variable label `v'
        local typ : type `v'
        local vallab : value label `v'

        post `varpost' (`"`f'"') (`"`v'"') (`"`lab'"') (`"`typ'"') (`"`vallab'"')
    }
}

postclose `filepost'
postclose `varpost'

preserve
    use `filemeta', clear
    export delimited using "$doc/raw_file_inventory.csv", replace
restore

preserve
    use `varmeta', clear
    export delimited using "$doc/raw_variable_inventory.csv", replace
restore

di as result "Saved raw file inventory to $doc/raw_file_inventory.csv"
di as result "Saved raw variable inventory to $doc/raw_variable_inventory.csv"

log close
