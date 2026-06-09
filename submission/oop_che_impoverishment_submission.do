/*
    OOP catastrophic health expenditure and impoverishment
    NLSS IV 2022/23 - boss-facing one-file analysis

    How to run:
        1. Change only the global data path below so it points to the folder
           containing poverty.dta, total_consumption.dta, and S08.dta.
        2. Run this do-file.

    Scope:
        In this do-file, OOP means Section 8(B) communicable disease or injury
        out-of-pocket spending reported in the past 30 days.

    Main method:
        CHE denominator        = official monthly consumption excluding health + OOP
        Post-payment welfare   = official pcep
        Pre-payment welfare    = pcep + annual real per-capita OOP

    Output:
        oop_submission_results.csv is written to the current Stata working
        directory. The same core results are also displayed in the Results pane.
*/

version 17
clear all
set more off

* --------------------------- USER SETTING ----------------------------------
global data "D:/Projects/CIH-project/consumption/1_data/1_raw"
* ---------------------------------------------------------------------------

global out "."

foreach f in poverty.dta total_consumption.dta S08.dta {
    capture confirm file "$data/`f'"
    if _rc {
        display as error "Required file not found: $data/`f'"
        exit 601
    }
}


*============================================================================*
* 1. Create household OOP from Section 8(B)                                   *
*============================================================================*

use "$data/S08.dta", clear

replace q08_14_i = 0 if missing(q08_14_i)

collapse (sum) oop = q08_14_i, by(psu_number hh_number)

label variable oop "OOP: Section 8(B) communicable/injury spending, past 30 days"

tempfile oop_hh
save `oop_hh'


*============================================================================*
* 2. Bring in official consumption and poverty files                          *
*============================================================================*

use "$data/poverty.dta", clear

merge 1:1 psu_number hh_number using "$data/total_consumption.dta", ///
    keepusing(total_consumption pctot_consumption) nogen assert(3)

merge 1:1 psu_number hh_number using `oop_hh', nogen assert(3)

count
assert r(N) == 9600

assert total_consumption > 0
assert pcep > 0
assert pcep_nonfood > 0
assert paasche > 0
assert pline > 0
assert oop >= 0
assert abs(pcep - (pcep_food + pcep_nonfood)) < 1


*============================================================================*
* 3. CHE variables                                                            *
*============================================================================*

gen double total_cons_month = total_consumption / 12
gen double oop_ann = oop * 12
gen double oop_real_month = oop / paasche
gen double oop_pc_ann_real = (oop_ann / hhsize) / paasche

gen double total_cons_plus_oop = total_cons_month + oop
gen double nonfood_cons_plus_oop = (pcep_nonfood * hhsize / 12) + oop_real_month

gen double oop_share_total = oop / total_cons_plus_oop
gen double oop_share_nonfood = oop_real_month / nonfood_cons_plus_oop

* Sensitivity only: denominator excludes health but does not add OOP back.
gen double oop_share_total_noadd = oop / total_cons_month

foreach z in 10 20 25 {
    local cut = `z' / 100
    gen byte che_total_`z' = oop_share_total > `cut' if !missing(oop_share_total)
    gen byte che_total_noadd_`z' = oop_share_total_noadd > `cut' ///
        if !missing(oop_share_total_noadd)
}

foreach z in 25 40 {
    local cut = `z' / 100
    gen byte che_nonfood_`z' = oop_share_nonfood > `cut' ///
        if !missing(oop_share_nonfood)
}

label variable total_cons_month       "Official monthly household consumption excluding health"
label variable total_cons_plus_oop    "Monthly household consumption excluding health plus OOP"
label variable nonfood_cons_plus_oop  "Monthly real nonfood consumption excluding health plus real OOP"
label variable oop_share_total        "OOP / (monthly total consumption + OOP)"
label variable oop_share_nonfood      "Real OOP / (monthly nonfood consumption + real OOP)"
label variable oop_share_total_noadd  "Sensitivity: OOP / monthly total consumption excluding health"


*============================================================================*
* 4. Impoverishment variables                                                 *
*============================================================================*

gen double pre_oop_welfare = pcep + oop_pc_ann_real
gen double post_oop_welfare = pcep

gen byte poor_pre_oop = pre_oop_welfare < pline ///
    if !missing(pre_oop_welfare, pline)
gen byte poor_post_oop = post_oop_welfare < pline ///
    if !missing(post_oop_welfare, pline)

gen double poverty_gap_pre = poor_pre_oop * (pline - pre_oop_welfare)
gen double poverty_gap_post = poor_post_oop * (pline - post_oop_welfare)

gen double norm_poverty_gap_pre = poverty_gap_pre / pline
gen double norm_poverty_gap_post = poverty_gap_post / pline

gen double diff_poverty_headcount = poor_post_oop - poor_pre_oop
gen double diff_poverty_gap = poverty_gap_post - poverty_gap_pre
gen double diff_norm_poverty_gap = norm_poverty_gap_post - norm_poverty_gap_pre

gen byte pushed_below_pline = pre_oop_welfare >= pline & post_oop_welfare < pline ///
    if !missing(pre_oop_welfare, post_oop_welfare, pline)

assert pre_oop_welfare >= post_oop_welfare if !missing(pre_oop_welfare, post_oop_welfare)

label variable pre_oop_welfare       "Pre-OOP welfare: pcep plus annual real per-capita OOP"
label variable post_oop_welfare      "Post-OOP welfare: official pcep"
label variable pushed_below_pline    "Pre-OOP nonpoor and post-OOP poor"


*============================================================================*
* 5. Survey estimates and export                                              *
*============================================================================*

tempfile results
tempname res

postfile `res' str20 section str80 metric double estimate se using `results', replace

post `res' ("Data check") ("Households in analysis sample") (_N) (.)

svyset psu_number [pw = hhs_wt]

foreach v in che_total_10 che_total_20 che_total_25 ///
    che_nonfood_25 che_nonfood_40 ///
    che_total_noadd_10 che_total_noadd_20 che_total_noadd_25 {

    quietly svy: mean `v'
    post `res' ("CHE") ("`v'") (_b[`v']) (_se[`v'])
}

quietly svy: mean oop_share_total oop_share_nonfood oop_share_total_noadd
post `res' ("CHE") ("Mean OOP share: total consumption plus OOP") ///
    (_b[oop_share_total]) (_se[oop_share_total])
post `res' ("CHE") ("Mean OOP share: nonfood consumption plus OOP") ///
    (_b[oop_share_nonfood]) (_se[oop_share_nonfood])
post `res' ("CHE") ("Mean OOP share sensitivity: total consumption no addback") ///
    (_b[oop_share_total_noadd]) (_se[oop_share_total_noadd])

svyset psu_number [pw = ind_wt]

quietly svy: mean poor_pre_oop poor_post_oop diff_poverty_headcount ///
    poverty_gap_pre poverty_gap_post diff_poverty_gap ///
    norm_poverty_gap_pre norm_poverty_gap_post diff_norm_poverty_gap

post `res' ("Poverty") ("Pre-OOP poverty headcount") ///
    (_b[poor_pre_oop]) (_se[poor_pre_oop])
post `res' ("Poverty") ("Post-OOP poverty headcount") ///
    (_b[poor_post_oop]) (_se[poor_post_oop])
post `res' ("Poverty") ("OOP-associated impoverishment headcount") ///
    (_b[diff_poverty_headcount]) (_se[diff_poverty_headcount])
post `res' ("Poverty") ("Pre-OOP poverty gap annual NPR") ///
    (_b[poverty_gap_pre]) (_se[poverty_gap_pre])
post `res' ("Poverty") ("Post-OOP poverty gap annual NPR") ///
    (_b[poverty_gap_post]) (_se[poverty_gap_post])
post `res' ("Poverty") ("OOP-associated poverty gap increase annual NPR") ///
    (_b[diff_poverty_gap]) (_se[diff_poverty_gap])
post `res' ("Poverty") ("Pre-OOP normalized poverty gap") ///
    (_b[norm_poverty_gap_pre]) (_se[norm_poverty_gap_pre])
post `res' ("Poverty") ("Post-OOP normalized poverty gap") ///
    (_b[norm_poverty_gap_post]) (_se[norm_poverty_gap_post])
post `res' ("Poverty") ("OOP-associated normalized poverty gap increase") ///
    (_b[diff_norm_poverty_gap]) (_se[diff_norm_poverty_gap])

quietly summarize ind_wt if pushed_below_pline == 1, meanonly
local people_pushed = r(sum)

quietly summarize hhs_wt if pushed_below_pline == 1, meanonly
local households_pushed_weighted = r(sum)

quietly count if pushed_below_pline == 1
local households_pushed_sample = r(N)

post `res' ("Poverty") ("People pushed below poverty line") (`people_pushed') (.)
post `res' ("Poverty") ("Weighted households pushed below poverty line") ///
    (`households_pushed_weighted') (.)
post `res' ("Poverty") ("Sample households pushed below poverty line") ///
    (`households_pushed_sample') (.)

quietly summarize pcep [aw = ind_wt], meanonly
post `res' ("Descriptive") ("Mean annual pcep") (r(mean)) (.)

quietly summarize total_cons_month [aw = hhs_wt], meanonly
post `res' ("Descriptive") ("Mean monthly household consumption excluding health") ///
    (r(mean)) (.)

quietly summarize oop [aw = hhs_wt], meanonly
post `res' ("Descriptive") ("Mean monthly household OOP") (r(mean)) (.)

postclose `res'

preserve
    use `results', clear
    export delimited using "$out/oop_submission_results.csv", replace
    format estimate se %12.6f
    list, abbreviate(32) noobs sepby(section)
restore


*============================================================================*
* 6. Key interpretation lines                                                 *
*============================================================================*

display as text ""
display as text "Key interpretation"
display as text "------------------"
display as text "OOP in this file means Section 8(B) communicable disease/injury spending."
display as text "NLSS IV pcep excludes health spending, so official pcep is post-OOP welfare."
display as text "Pre-OOP welfare is reconstructed as pcep plus annual real per-capita OOP."
display as text "The poverty effect is therefore: pre-OOP poverty -> official pcep poverty."
display as text ""
display as result "Results exported to: $out/oop_submission_results.csv"
