*------------------------------------------------------------------------------*
*           Chapter 18 OOP: Catastrophic Payments at Book Thresholds            *
/*

    Purpose:
        Produce Chapter 18-style incidence/intensity and distribution-sensitive
        catastrophic payment measures for OOP only.

    Outputs:
        6_output/main_output/chapter18/oop/oop_box18_1_incidence_intensity.csv
        6_output/main_output/chapter18/oop/oop_box18_2_distribution_sensitive.csv

    Notes:
        - OOP is OOPG plus NCD OOP converted to monthly terms.
        - Primary shares use the current project denominators:
            total:   nominal monthly total consumption + OOPG
            nonfood: real monthly nonfood consumption + OOPG
        - Estimates here are household-weighted to match the Chapter 18
          household catastrophic-payment presentation.
        - Distribution-sensitive measures rank by pre_oop.
*/
*------------------------------------------------------------------------------*

version 17
clear all
set more off

local root "D:/Projects/CIH-project/consumption"
global data_clean "`root'/1_data/2_clean"
global out "`root'/6_output/main_output/chapter18/oop"

cap mkdir "`root'/6_output/main_output/chapter18"
cap mkdir "$out"

cap log close
log using "$out/chapter18_oop.log", replace

use "$data_clean/catastrophic_health_exp.dta", clear

assert _N == 9600
assert oop >= oopg
assert ctp_real_hh_mo > 0
assert totexp_real_hh_mo > 0
assert totexp_nom_oopgadd_mo > 0
assert ctp_real_oopgadd_hh_mo > 0
assert pre_oop >= pcep if !missing(pre_oop, pcep)

svyset psu_number [pw = hhs_wt]

local thresholds 5 10 15 25 40


*==============================================================================*
*     SECTION 1: CREATE BOOK-STYLE THRESHOLD VARIABLES                         *
*==============================================================================*

foreach denom in total nonfood {
    if "`denom'" == "total" {
        local share oop_sh_tot
        local stub tot
    }
    else {
        local share oop_sh_nf
        local stub nf
    }

    foreach z of local thresholds {
        local zdec = `z' / 100
        gen byte ch18_oop_`stub'`z' = (`share' > `zdec') if !missing(`share')
        gen double ch18_over_oop_`stub'`z' = max(`share' - `zdec', 0) if !missing(`share')

        label variable ch18_oop_`stub'`z' "Chapter 18 OOP CHE: `z'% `denom'"
        label variable ch18_over_oop_`stub'`z' "Chapter 18 OOP overshoot: `z'% `denom'"
    }
}

assert ch18_oop_tot10 == che_oop_tot10
assert ch18_oop_nf25 == che_oop_nf25
assert ch18_oop_nf40 == che_oop_nf40


*==============================================================================*
*     SECTION 2: INCIDENCE AND INTENSITY                                       *
*==============================================================================*

tempname box1
tempfile box1data
postfile `box1' str7 scope str12 denominator int threshold ///
    str24 headcount_var str30 overshoot_var ///
    double headcount headcount_se overshoot overshoot_se mpo ///
    using `box1data', replace

foreach denom in total nonfood {
    if "`denom'" == "total" {
        local stub tot
    }
    else {
        local stub nf
    }

    foreach z of local thresholds {
        if "`denom'" == "nonfood" & inlist(`z', 5, 10) continue

        local h ch18_oop_`stub'`z'
        local o ch18_over_oop_`stub'`z'

        quietly svy: mean `h' `o'
        local head = _b[`h']
        local head_se = _se[`h']
        local over = _b[`o']
        local over_se = _se[`o']
        local mpo = cond(`head' > 0, `over' / `head', .)

        post `box1' ("oop") ("`denom'") (`z') ("`h'") ("`o'") ///
            (`head') (`head_se') (`over') (`over_se') (`mpo')
    }
}

postclose `box1'

preserve
    use `box1data', clear
    export delimited using "$out/oop_box18_1_incidence_intensity.csv", replace
restore


*==============================================================================*
*     SECTION 3: DISTRIBUTION-SENSITIVE MEASURES                               *
*==============================================================================*

tempname box2
tempfile box2data
postfile `box2' str7 scope str12 denominator int threshold ///
    str24 headcount_var str30 overshoot_var ///
    double headcount concentration_headcount rank_weighted_headcount ///
    double overshoot concentration_overshoot rank_weighted_overshoot ///
    using `box2data', replace

preserve
    keep if !missing(pre_oop, hhs_wt) & hhs_wt > 0

    sort pre_oop psu_number hh_number
    quietly summarize hhs_wt, meanonly
    gen double _rank_w = hhs_wt / r(sum)
    gen double _rank_cum = sum(_rank_w)
    gen double _frac_rank = _rank_cum - 0.5 * _rank_w

    quietly summarize _frac_rank [aw = hhs_wt], meanonly
    local mean_rank = r(mean)

    foreach denom in total nonfood {
        if "`denom'" == "total" {
            local stub tot
        }
        else {
            local stub nf
        }

        foreach z of local thresholds {
            if "`denom'" == "nonfood" & inlist(`z', 5, 10) continue

            local h ch18_oop_`stub'`z'
            local o ch18_over_oop_`stub'`z'

            quietly summarize `h' [aw = hhs_wt], meanonly
            local head = r(mean)

            tempvar h_rank
            gen double `h_rank' = `h' * _frac_rank
            quietly summarize `h_rank' [aw = hhs_wt], meanonly
            local mean_hr = r(mean)
            local ci_h = cond(`head' > 0, (2 / `head') * (`mean_hr' - `head' * `mean_rank'), .)
            local rw_h = cond(`head' > 0, `head' * (1 - `ci_h'), .)
            drop `h_rank'

            quietly summarize `o' [aw = hhs_wt], meanonly
            local over = r(mean)

            tempvar o_rank
            gen double `o_rank' = `o' * _frac_rank
            quietly summarize `o_rank' [aw = hhs_wt], meanonly
            local mean_or = r(mean)
            local ci_o = cond(`over' > 0, (2 / `over') * (`mean_or' - `over' * `mean_rank'), .)
            local rw_o = cond(`over' > 0, `over' * (1 - `ci_o'), .)
            drop `o_rank'

            post `box2' ("oop") ("`denom'") (`z') ("`h'") ("`o'") ///
                (`head') (`ci_h') (`rw_h') (`over') (`ci_o') (`rw_o')
        }
    }
restore

postclose `box2'

preserve
    use `box2data', clear
    export delimited using "$out/oop_box18_2_distribution_sensitive.csv", replace
restore


*------------------------------------------------------------------------------*
**#                     End of do file
*------------------------------------------------------------------------------*

log close
