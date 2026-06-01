*------------------------------------------------------------------------------*
*           Phase 1: Data Preparation for Catastrophic Health Expenditure     *
/*

    Author:             Arpan 
    Date created:       20th April 2026
    Date updated:       21st April 2026
    Last updated by:    Arpan

    Notes:
        This do file builds the master analysis dataset for catastrophic
        health expenditure (CHE) from NLSS IV. It merges data from multiple
        survey sections and creates analysis-ready variables.

    Dependencies:
        - poverty.dta, total_consumption.dta
        - S01.dta (demographics), S02.dta (housing)
        - S08.dta (health), S14.dta (remittance), S15.dta (borrowing)
        - Run 0_master.do before this file

    Output:
        - oopg_analysis_base.dta (in $data_clean)
          9,600 households, analysis-ready OOPG variables
*/
*------------------------------------------------------------------------------*

local dofilename "1_catastrophic"


*==============================================================================*
*                                                                              *
*     SECTION 1: CONSUMPTION & POVERTY                                         *
*     Sources: poverty.dta, total_consumption.dta                              *
*                                                                              *
*==============================================================================*

use "$data_raw/poverty.dta", clear

* Merge total consumption
merge 1:1 psu_number hh_number using "$data_raw/total_consumption.dta", ///
    keepusing(cons_quintile total_consumption pctot_consumption)

tab _merge
assert _merge == 3
drop _merge

count
assert r(N) == 9600

* Label variables
label variable psu_number          "Primary sampling unit number"
label variable hh_number           "Household number within PSU"
label variable prov                "Province"
label variable domain              "Survey domain (province x urban/rural)"
label variable hhsize              "Household size"
label variable hhs_wt              "Household survey weight"
label variable ind_wt              "Individual survey weight"
label variable ad_4                "Area type (Kathmandu/Other urban/Rural hills/Rural terai)"
label variable pline               "Total poverty line (NPR)"
label variable fpline              "Food poverty line (NPR)"
label variable nfpline             "Non-food poverty line (NPR)"
label variable poor                "Poverty status (1=poor, 0=non-poor)"
label variable quintile_pcep       "Per capita expenditure quintile (1=poorest to 5=richest)"
label variable cons_quintile       "Consumption quintile"
label variable total_consumption   "Total annual household consumption (NPR)"
label variable pctot_consumption   "Per capita total consumption, simple (NPR)"
label variable pcep                "Official real per-capita consumption (NPR/year, excludes health)"
label variable pcep_food           "Real per-capita food consumption (NPR/year)"
label variable pcep_nonfood        "Real per-capita nonfood consumption (NPR/year)"
label variable paasche             "Household Paasche price index"

tempfile master
save `master'


*==============================================================================*
*                                                                              *
*     SECTION 2: HOUSEHOLD HEAD CHARACTERISTICS                                *
*     Source: S01.dta (Section 1: Demographics)                                *
*                                                                              *
*==============================================================================*

use "$data_raw/S01.dta", clear

* Keep actual household members only (exclude absentees abroad)
keep if member_cat == 1  // "Household Member"

* --- 2a: Head characteristics (from S01 + S07) ---
* Extract basic head info from S01
preserve
    keep if q01_04 == 1  // HEAD

    rename q01_02 head_sex
    rename q01_03 head_age
    rename q01_05 head_marital
    rename q01_07 caste_ethnicity

    * Female-headed household dummy (q01_02: 1=Male, 2=Female)
    gen head_female = (head_sex == 2) if !missing(head_sex)

    keep psu_number hh_number idcode head_sex head_age head_female ///
         head_marital caste_ethnicity

    * --- Merge head's OWN education from S07 ---
    * NOTE: q01_12 in S01 is father's education, NOT the individual's.
    *       Head's own education comes from S07:
    *         q07_02: Can read? (1=YES, 2=NO)
    *         q07_04: Attendance (1=NEVER ATTENDED, 2=SCHOOL ATTENDED IN PAST, 3=CURRENT)
    *         q07_06: Highest grade completed (0-17, for q07_04==2)
    *         q07_12: Grade currently in (0-14, for q07_04==3)
    merge 1:1 psu_number hh_number idcode using "$data_raw/S07.dta", ///
        keepusing(q07_02 q07_04 q07_06 q07_12) nogen keep(master matched)

    * Combine q07_06 (past) and q07_12 (current) into single highest grade
    gen highest_grade = .
    replace highest_grade = q07_06 if q07_04 == 2  // School attended in past
    replace highest_grade = q07_12 if q07_04 == 3  // Currently schooling

    * Recode into ordered education levels
    * q07_06 / q07_12 labels:
    *   0=Pre-school, 1=Class1, ..., 5=Class5, 6=Class6, ..., 8=Class8,
    *   9=Class9, 10=Class10, 11=SEE/SLC, 12=Intermediate/Class12,
    *   13=Bachelor, 14=Master+, 15=Professional, 16=Literate(levelless), 17=Illiterate

    gen head_edu_level = ""

    * Never attended school: classify by literacy
    replace head_edu_level = "No education"      if q07_04 == 1 & q07_02 == 2  // Never attended, illiterate
    replace head_edu_level = "Informal/literate"  if q07_04 == 1 & q07_02 == 1  // Never attended, but literate

    * Attended school (past or current): classify by highest grade
    replace head_edu_level = "Primary (1-5)"          if inrange(highest_grade, 0, 5) & head_edu_level == ""
    replace head_edu_level = "Lower secondary (6-8)"  if inrange(highest_grade, 6, 8) & head_edu_level == ""
    replace head_edu_level = "Secondary (9-SLC)"      if inrange(highest_grade, 9, 11) & head_edu_level == ""
    replace head_edu_level = "Higher secondary"       if highest_grade == 12 & head_edu_level == ""
    replace head_edu_level = "Bachelor and above"     if inrange(highest_grade, 13, 15) & head_edu_level == ""
    replace head_edu_level = "Informal/literate"      if highest_grade == 16 & head_edu_level == ""  // Literate (levelless)
    replace head_edu_level = "No education"           if head_edu_level == ""  // Remaining (Illiterate=17, missing)
	

    * Keep original grade as head_education
    rename highest_grade head_education

    * Literacy dummy (from q07_02: 1=YES, 2=NO)
    gen head_literate = (q07_02 == 1) if !missing(q07_02)
    replace head_literate = 0 if missing(head_literate)

    drop idcode q07_02 q07_04 q07_06 q07_12

    keep psu_number hh_number head_sex head_age head_female head_marital ///
         head_education head_edu_level head_literate caste_ethnicity

    label variable head_sex        "Sex of household head"
    label variable head_age        "Age of household head"
    label variable head_female     "Female-headed household (1=yes)"
    label variable head_marital    "Marital status of household head"
    label variable head_education  "Highest grade completed by HH head (from S07)"
    label variable head_edu_level  "Education of HH head, recoded (from S07)"
    label variable head_literate   "Household head is literate (1=yes, from S07 q07_02)"
    label variable caste_ethnicity "Caste/ethnicity of household head"

    tempfile head_chars
    save `head_chars'
restore


* --- 2b: Household composition ---
gen is_child   = (q01_03 < 15)
gen is_adult   = (q01_03 >= 15)
gen is_elderly = (q01_03 >= 65)
gen is_under5  = (q01_03 < 5)
gen is_working = (q01_03 >= 15 & q01_03 < 65)

collapse ///
    (sum) n_adults      = is_adult   ///
          n_children    = is_child   ///
          n_elderly     = is_elderly ///
          n_under5      = is_under5  ///
          n_working_age = is_working ///
    (count) n_hh_members = idcode    ///
    , by(psu_number hh_number)

* Adult equivalents: Citro-Michael scale (p=0.5, theta=0.75)
gen adult_equiv = (n_adults + 0.5 * n_children) ^ 0.75

* Dependency ratio
gen dep_ratio = (n_children + n_elderly) / n_working_age if n_working_age > 0

* Useful dummies
gen has_elderly = (n_elderly > 0)
gen has_under5  = (n_under5 > 0)

label variable n_adults       "Number of adults (age >= 15) in household"
label variable n_children     "Number of children (age < 15) in household"
label variable n_hh_members   "Number of household members (excl. absentees abroad)"
label variable adult_equiv    "Adult equivalents (Citro-Michael: p=0.5, theta=0.75)"
label variable n_elderly      "Number of elderly members (age >= 65)"
label variable n_under5       "Number of children under 5"
label variable n_working_age  "Number of working-age members (15-64)"
label variable dep_ratio      "Dependency ratio ((children + elderly) / working-age)"
label variable has_elderly    "Has elderly member aged 65+ (1=yes)"
label variable has_under5     "Has child under 5 (1=yes)"

count
assert r(N) == 9600

tempfile demog
save `demog'


*==============================================================================*
*                                                                              *
*     SECTION 3: HEALTH EXPENDITURE & DISABILITY                               *
*     Source: S08.dta (Section 8: Health)                                       *
*                                                                              *
*==============================================================================*

use "$data_raw/S08.dta", clear

* --- 3a: Health expenditure ---
* Replace missing costs with 0 before aggregation
replace q08_14_i = 0 if missing(q08_14_i)  // Communicable (30-day)
replace q08_06_i = 0 if missing(q08_06_i)  // NCD (annual)

* Indicators for disease presence
gen has_ncd = (q08_02 == 1) if !missing(q08_02)
replace has_ncd = 0 if missing(has_ncd)

gen has_communicable = (q08_10 == 1) if !missing(q08_10)
replace has_communicable = 0 if missing(has_communicable)

* --- 3b: Disability (Washington Group-style) ---
* q08_16-q08_21: 6 functional domains
* "Yes - a lot of difficulty" or "Cannot, at all" = functional disability
gen any_disability = 0
foreach v of varlist q08_16 q08_17 q08_18 q08_19 q08_20 q08_21 {
    replace any_disability = 1 if inlist(`v', 3, 4) // a lot of difficulty, cannot at all
}

* --- 3c: Collapse to household level ---
collapse ///
    (sum) hh_comm_total_30d    = q08_14_i        ///
          hh_ncd_total_annual  = q08_06_i        ///
          n_with_ncd           = has_ncd         ///
          n_with_communicable  = has_communicable ///
          n_disabled           = any_disability  ///
    (count) n_members_in_s08   = idcode          ///
    , by(psu_number hh_number)

* Monthly NCD estimate
gen hh_ncd_total_monthly = hh_ncd_total_annual / 12

* Disability dummy
gen has_disabled_member = (n_disabled > 0)

label variable hh_comm_total_30d      "HH total communicable disease/injury expenditure (past 30 days, NPR)"
label variable hh_ncd_total_annual    "HH total NCD expenditure (past year, NPR)"
label variable hh_ncd_total_monthly   "HH total NCD expenditure, monthly estimate (NPR)"
label variable n_with_ncd             "Number of HH members reporting an NCD"
label variable n_with_communicable    "Number of HH members reporting communicable disease/injury"
label variable n_members_in_s08       "Number of HH members enumerated in Section 8"
label variable n_disabled             "Number of HH members with functional disability"
label variable has_disabled_member    "Has member with functional disability (1=yes)"

count
assert r(N) == 9600

tempfile health
save `health'


*==============================================================================*
*                                                                              *
*     SECTION 4: HOUSING & SANITATION                                          *
*     Source: S02.dta (Section 2: Housing)                                      *
*     Note: No insurance variable exists in NLSS IV S02                        *
*                                                                              *
*==============================================================================*

use "$data_raw/S02.dta", clear

* --- 4a: Sanitation ---
* Improved sanitation = flush toilet (1=sewer, 2=septic tank)
gen improved_sanitation = inlist(q02_27, 1, 2)

* --- 4b: Improved water source ---
* 1=piped inside dwelling, 2=piped outside dwelling, 4=covered well, 8=jar/bottled water
gen improved_water = inlist(q02_19, 1, 2, 4, 8)

* --- 4c: Clean cooking fuel ---
* 2=LP gas, 6=biogas, 3=electricity
gen clean_fuel = inlist(q02_32, 2, 6, 3)

rename q02_27 toilet_type
rename q02_19 water_source
rename q02_32 cooking_fuel

keep psu_number hh_number ///
     improved_sanitation improved_water clean_fuel ///
     toilet_type water_source cooking_fuel

label variable improved_sanitation  "Has improved sanitation/flush toilet (1=yes)"
label variable improved_water       "Has improved drinking water source (1=yes)"
label variable clean_fuel           "Uses clean cooking fuel: LPG/biogas/electricity (1=yes)"
label variable toilet_type          "Type of toilet facility"
label variable water_source         "Main drinking water source"
label variable cooking_fuel         "Main cooking fuel"

tempfile housing
save `housing'


*==============================================================================*
*                                                                              *
*     SECTION 5: REMITTANCE & BORROWING                                        *
*     Sources: S14A.dta (Absentee remittance), S15.dta (Other transfers),      *
*              S13.dta (Loans/credit)                                           *
*                                                                              *
*==============================================================================*

* --- 5a: Remittance from absentees ---
* S14A is individual-level (one row per absentee). q14_15 == 1 means
* HH received money/goods from that absentee in the past 12 months.
* Collapse to HH level: 1 if any absentee sent remittance.
use "$data_raw/S14A.dta", clear
gen byte remit_absentee = (q14_15 == 1) if !missing(q14_15)
collapse (max) remit_absentee, by(psu_number hh_number)
tempfile remit_abs
save `remit_abs'

* --- 5b: Transfers received from non-household members ---
* S15 q15_11: received money/gifts from non-members (not absentees)
use "$data_raw/S15.dta", clear
gen byte remit_other = (q15_11 == 1) if !missing(q15_11)
keep psu_number hh_number remit_other
tempfile remit_oth
save `remit_oth'

* --- 5c: Combine remittance sources ---
* Start from the full HH universe (S15 has all 9,600 HHs)
use `remit_oth', clear
merge 1:1 psu_number hh_number using `remit_abs', nogen keep(master matched)
replace remit_absentee = 0 if missing(remit_absentee) // HHs with no absentees
gen receives_remittance = (remit_absentee == 1 | remit_other == 1)
label variable receives_remittance "Receives remittance/transfer (from absentees or others, 1=yes)"
label variable remit_absentee      "Received remittance from absentee (S14A q14_15, 1=yes)"
label variable remit_other         "Received transfer from non-member (S15 q15_11, 1=yes)"
keep psu_number hh_number receives_remittance remit_absentee remit_other
tempfile remit
save `remit'

* --- 5d: Borrowing ---
* S13 q13_01: "Do you or any member of your household have loans outstanding?"
use "$data_raw/S13.dta", clear
gen has_loan = (q13_01 == 1) if !missing(q13_01)
label variable has_loan "Has outstanding loan (S13 q13_01, 1=yes)"
keep psu_number hh_number has_loan
tempfile borrow
save `borrow'


*==============================================================================*
*                                                                              *
*     SECTION 6: MERGE ALL & DERIVED VARIABLES                                 *
*                                                                              *
*==============================================================================*

* Start with consumption/poverty base
use `master', clear

* Merge head characteristics + caste/ethnicity
merge 1:1 psu_number hh_number using `head_chars'
assert _merge == 3
drop _merge

* Merge household composition + adult equivalents
merge 1:1 psu_number hh_number using `demog'
assert _merge == 3
drop _merge

* Merge health expenditure + disability
merge 1:1 psu_number hh_number using `health'
assert _merge == 3
drop _merge

* Merge housing & sanitation
merge 1:1 psu_number hh_number using `housing'
assert _merge == 3
drop _merge

* Merge remittance
merge 1:1 psu_number hh_number using `remit'
assert _merge == 3
drop _merge

* Merge borrowing
merge 1:1 psu_number hh_number using `borrow'
assert _merge == 3
drop _merge

* --- Derived variables ---

* Per capita consumption (adult-equivalent adjusted)
gen pc_cons_ae = total_consumption / adult_equiv
label variable pc_cons_ae "Per capita consumption, adult-equivalent adjusted (NPR)"


*==============================================================================*
*                                                                              *
*     SECTION 7: OOPG EXPENDITURE, SHARES, CHE FLAGS, OVERSHOOT                *
*                                                                              *
*==============================================================================*
/*
    Canonical scope:
        oopg = Section 8B communicable/injury OOP, past 30 days; treated
               as monthly for CHE

    Shiva sir rerun:
    Primary CHE total-expenditure denominators use reconstructed nominal
    monthly household total consumption without adding OOPG back:
        nominal_total_cons_month

    The nonfood denominator uses real monthly nonfood consumption without
    adding real OOPG back:
        pcep_nonfood * hhsize / 12

    NLSS-style health-excluding shares are retained with suffix _nlss for
    comparability.
*/

gen double oopg = hh_comm_total_30d
gen double oopg_ann = oopg * 12

gen double oopg_pc_ann_real = (oopg_ann / hhsize) / paasche
gen double oopg_pc_mo_real = (oopg / hhsize) / paasche
gen double pcep_mo_real = pcep / 12
gen double pline_mo_real = pline / 12

gen double total_cons_mo = total_consumption / 12
gen double nf_cons_mo_real = pcep_nonfood * hhsize / 12

gen double nonfood_spatial_index = .
replace nonfood_spatial_index = 1.03 if domain == 11
replace nonfood_spatial_index = 0.61 if domain == 12
replace nonfood_spatial_index = 0.60 if domain == 21
replace nonfood_spatial_index = 0.52 if domain == 22
replace nonfood_spatial_index = 2.32 if domain == 30
replace nonfood_spatial_index = 1.15 if domain == 31
replace nonfood_spatial_index = 0.72 if domain == 32
replace nonfood_spatial_index = 1.32 if domain == 41
replace nonfood_spatial_index = 0.66 if domain == 42
replace nonfood_spatial_index = 1.08 if domain == 51
replace nonfood_spatial_index = 0.74 if domain == 52
replace nonfood_spatial_index = 0.78 if domain == 61
replace nonfood_spatial_index = 0.60 if domain == 62
replace nonfood_spatial_index = 0.97 if domain == 71
replace nonfood_spatial_index = 0.68 if domain == 72

gen double nominal_pcexp_annual = (pcep_food * paasche) + ///
    (pcep_nonfood * nonfood_spatial_index)
gen double nominal_pcexp_month = nominal_pcexp_annual / 12
gen double nominal_total_cons_annual = nominal_pcexp_annual * hhsize
gen double nominal_total_cons_month = nominal_total_cons_annual / 12

gen double oopg_real = oopg / paasche

gen double tot_real_hh_mo = pcep * hhsize / 12
gen double nf_real_hh_mo  = pcep_nonfood * hhsize / 12

gen double totexp_nom_noadd_mo = nominal_total_cons_month
gen double ctp_real_noadd_hh_mo = nf_real_hh_mo

gen double oopg_sh_tot = oopg / totexp_nom_noadd_mo
gen double oopg_sh_nf  = oopg_real / ctp_real_noadd_hh_mo

gen double oopg_sh_tot_nlss = oopg_real / tot_real_hh_mo
gen double oopg_sh_nf_nlss  = oopg_real / nf_real_hh_mo

gen byte che_oopg_tot10 = oopg_sh_tot > 0.10 if !missing(oopg_sh_tot)
gen byte che_oopg_tot20 = oopg_sh_tot > 0.20 if !missing(oopg_sh_tot)
gen byte che_oopg_nf25  = oopg_sh_nf  > 0.25 if !missing(oopg_sh_nf)
gen byte che_oopg_nf40  = oopg_sh_nf  > 0.40 if !missing(oopg_sh_nf)

gen byte che_oopg_tot10_nlss = oopg_sh_tot_nlss > 0.10 if !missing(oopg_sh_tot_nlss)
gen byte che_oopg_tot20_nlss = oopg_sh_tot_nlss > 0.20 if !missing(oopg_sh_tot_nlss)
gen byte che_oopg_nf25_nlss  = oopg_sh_nf_nlss  > 0.25 if !missing(oopg_sh_nf_nlss)
gen byte che_oopg_nf40_nlss  = oopg_sh_nf_nlss  > 0.40 if !missing(oopg_sh_nf_nlss)

gen double over_oopg_tot10 = max(oopg_sh_tot - 0.10, 0)
gen double over_oopg_tot20 = max(oopg_sh_tot - 0.20, 0)
gen double over_oopg_nf25  = max(oopg_sh_nf  - 0.25, 0)
gen double over_oopg_nf40  = max(oopg_sh_nf  - 0.40, 0)

gen double pre_oopg = pcep_mo_real
gen double post_oopg = pcep_mo_real - oopg_pc_mo_real
gen byte post_oopg_zero_floor = post_oopg < 0 if !missing(post_oopg)
replace post_oopg = 0 if post_oopg < 0 & !missing(post_oopg)

label variable oopg                  "OOPG: communicable/injury OOP, monthly HH amount (NPR)"
label variable oopg_ann              "OOPG: annualized HH amount (NPR)"
label variable oopg_pc_ann_real      "OOPG: real annual per-capita amount (NPR)"
label variable oopg_pc_mo_real       "OOPG: real monthly per-capita amount (NPR)"
label variable pcep_mo_real          "Official real monthly per-capita consumption (NPR/month)"
label variable pline_mo_real         "Official monthly per-capita poverty line (NPR/month)"
label variable total_cons_mo         "Official total monthly household consumption, nominal (NPR)"
label variable nf_cons_mo_real       "Nonfood monthly household consumption, real (NPR)"
label variable nonfood_spatial_index "Domain nonfood spatial price index"
label variable nominal_pcexp_annual  "Reconstructed nominal annual per-capita consumption (NPR)"
label variable nominal_pcexp_month   "Reconstructed nominal monthly per-capita consumption (NPR)"
label variable nominal_total_cons_annual "Reconstructed nominal annual household consumption (NPR)"
label variable nominal_total_cons_month "Reconstructed nominal monthly household consumption (NPR)"
label variable oopg_real             "OOPG: real monthly household amount (NPR)"
label variable tot_real_hh_mo        "Real monthly household total consumption, excludes health (NPR)"
label variable nf_real_hh_mo         "Real monthly household nonfood consumption, excludes health (NPR)"
label variable totexp_nom_noadd_mo   "Primary total denominator: reconstructed nominal monthly consumption, no OOPG addback (NPR)"
label variable ctp_real_noadd_hh_mo  "Primary nonfood denominator: real monthly nonfood consumption, no OOPG addback (NPR)"
label variable oopg_sh_tot           "OOPG share of reconstructed nominal total consumption, no OOPG addback"
label variable oopg_sh_nf            "OOPG share of real nonfood consumption, no OOPG addback"
label variable oopg_sh_tot_nlss      "OOPG share of NLSS total consumption excl. health"
label variable oopg_sh_nf_nlss       "OOPG share of NLSS nonfood consumption excl. health"
label variable che_oopg_tot10        "CHE: OOPG > 10% reconstructed nominal total consumption, no OOPG addback"
label variable che_oopg_tot20        "CHE: OOPG > 20% reconstructed nominal total consumption, no OOPG addback"
label variable che_oopg_nf25         "CHE: OOPG > 25% real nonfood consumption, no OOPG addback"
label variable che_oopg_nf40         "CHE: OOPG > 40% real nonfood consumption, no OOPG addback"
label variable che_oopg_tot10_nlss   "Sensitivity CHE: OOPG > 10% NLSS total consumption"
label variable che_oopg_tot20_nlss   "Sensitivity CHE: OOPG > 20% NLSS total consumption"
label variable che_oopg_nf25_nlss    "Sensitivity CHE: OOPG > 25% NLSS nonfood consumption"
label variable che_oopg_nf40_nlss    "Sensitivity CHE: OOPG > 40% NLSS nonfood consumption"
label variable over_oopg_tot10       "Overshoot: OOPG above 10% reconstructed nominal total consumption, no OOPG addback"
label variable over_oopg_tot20       "Overshoot: OOPG above 20% reconstructed nominal total consumption, no OOPG addback"
label variable over_oopg_nf25        "Overshoot: OOPG above 25% real nonfood consumption, no OOPG addback"
label variable over_oopg_nf40        "Overshoot: OOPG above 40% real nonfood consumption, no OOPG addback"
label variable pre_oopg              "Pre-OOPG real monthly per-capita consumption, no-addback assumption (NPR/month)"
label variable post_oopg             "Post-OOPG real monthly per-capita consumption, pcep/12 minus monthly OOPG with zero floor (NPR/month)"
label variable post_oopg_zero_floor  "Raw post-OOPG welfare was below zero and floored at zero"

* Validation checks for the analysis dataset.
assert _N == 9600
assert total_consumption > 0
assert abs(pcep - (pcep_food + pcep_nonfood)) < 1
assert pcep_nonfood > 0
assert paasche > 0
assert nonfood_spatial_index < .
assert nominal_total_cons_month > 0
assert totexp_nom_noadd_mo > 0
assert ctp_real_noadd_hh_mo > 0
gen byte _poor_pcep_check = (pcep < pline) if !missing(pcep, pline)
svyset psu_number [pw = ind_wt]
quietly svy: mean _poor_pcep_check
assert abs(_b[_poor_pcep_check] - 0.2027) < 0.0005
drop _poor_pcep_check
assert che_oopg_tot20 <= che_oopg_tot10 if !missing(che_oopg_tot20, che_oopg_tot10)
assert che_oopg_nf40  <= che_oopg_nf25  if !missing(che_oopg_nf40,  che_oopg_nf25)
foreach spec in oopg_tot10 oopg_tot20 oopg_nf25 oopg_nf40 {
    assert (over_`spec' == 0) == (che_`spec' == 0) ///
        if !missing(over_`spec', che_`spec')
}
assert abs(pre_oopg - pcep_mo_real) < 1e-8 if !missing(pre_oopg, pcep_mo_real)
assert post_oopg >= 0 if !missing(post_oopg)
assert post_oopg <= pre_oopg if !missing(post_oopg, pre_oopg)


*==============================================================================*
*                                                                              *
*     SECTION 8: SUMMARY & SAVE                                                *
*                                                                              *
*==============================================================================*

di _n "{hline 60}"
di "MASTER DATASET: Catastrophic Health Expenditure (NLSS IV)"
di "{hline 60}"

count
di "Total households: " r(N)

di _n "--- Head Characteristics ---"
tab head_sex
tab head_edu_level
su head_age, detail

di _n "--- Household Composition ---"
su adult_equiv dep_ratio
tab has_elderly
tab has_under5

di _n "--- Health ---"
su oopg hh_comm_total_30d, detail
tab has_disabled_member

di _n "--- Housing & Sanitation ---"
tab improved_sanitation
tab improved_water
tab clean_fuel

di _n "--- Economic ---"
tab receives_remittance
tab has_loan
tab poor

di _n "--- CHE Dummies: Total Consumption Denominator ---"
foreach v in che_oopg_tot10 che_oopg_tot20 {
    count if `v' == 1
    di "`v': " r(N) " HHs (" %5.2f r(N)/9600*100 "%)"
}

di _n "--- CHE Dummies: Nonfood Denominator ---"
foreach v in che_oopg_nf25 che_oopg_nf40 {
    count if `v' == 1
    di "`v': " r(N) " HHs (" %5.2f r(N)/9600*100 "%)"
}

* Keep one active OOPG benchmark dataset for the current manuscript.
keep psu_number hh_number prov domain ad_4 hhsize hhs_wt ind_wt ///
    pline fpline nfpline poor quintile_pcep cons_quintile ///
    pcep pcep_food pcep_nonfood pcep_mo_real pline_mo_real paasche ///
    total_consumption pctot_consumption ///
    head_sex head_age head_female head_marital head_education ///
    head_edu_level head_literate caste_ethnicity ///
    n_adults n_children n_hh_members adult_equiv n_elderly n_under5 ///
    n_working_age dep_ratio has_elderly has_under5 ///
    hh_comm_total_30d n_with_communicable n_disabled has_disabled_member ///
    improved_sanitation improved_water clean_fuel receives_remittance has_loan ///
    total_cons_mo nf_cons_mo_real nonfood_spatial_index ///
    nominal_pcexp_annual nominal_pcexp_month ///
    nominal_total_cons_annual nominal_total_cons_month ///
    oopg oopg_ann oopg_pc_ann_real oopg_pc_mo_real oopg_real ///
    tot_real_hh_mo nf_real_hh_mo totexp_nom_noadd_mo ///
    ctp_real_noadd_hh_mo oopg_sh_tot oopg_sh_nf ///
    oopg_sh_tot_nlss oopg_sh_nf_nlss ///
    che_oopg_tot10 che_oopg_tot20 che_oopg_nf25 che_oopg_nf40 ///
    che_oopg_tot10_nlss che_oopg_tot20_nlss ///
    che_oopg_nf25_nlss che_oopg_nf40_nlss ///
    over_oopg_tot10 over_oopg_tot20 over_oopg_nf25 over_oopg_nf40 ///
    pre_oopg post_oopg post_oopg_zero_floor

order psu_number hh_number prov domain ad_4 hhsize hhs_wt ind_wt ///
    pcep pcep_mo_real pcep_food pcep_nonfood paasche ///
    pline pline_mo_real oopg oopg_real oopg_pc_mo_real ///
    nominal_total_cons_month totexp_nom_noadd_mo ctp_real_noadd_hh_mo ///
    oopg_sh_tot oopg_sh_nf adult_equiv pre_oopg post_oopg

* Save
compress
save "$data_clean/oopg_analysis_base.dta", replace

di _n "{hline 60}"
di "Saved: oopg_analysis_base.dta"
di "Observations: " _N "  |  Variables: " c(k)
di "{hline 60}"

*------------------------------------------------------------------------------*
**#                     End of do file
*------------------------------------------------------------------------------*
