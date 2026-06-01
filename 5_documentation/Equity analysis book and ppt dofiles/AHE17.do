log using AHE17, replace

*******************************************************************************************************************
*	ANALYZING HEALTH EQUITY USING HOUSEHOLD SURVEY DATA: A GUIDE TO TECHNIQUES AND THEIR IMPLEMENTATION		*
*	OWEN O'DONNELL, EDDY VAN DOORSLAER, ADAM WAGSTAFF AND MAGNUS LINDELOW							*
*	WASHINGTON DC, WORLD BANK, 2007													*
*	www.worldbank.org/analyzinghealthequity 												*
*******************************************************************************************************************


*************************	CHAPTER 17	REDISTRIBUTIIVE EFFECT OF HEALTH FINANCE	*******************************



*****************************			PRELIMINARIES		*************************************************
version 9.2
clear
set more off
set matsize 800 			
set mem 100m

*******************************************************************************************************************


****************************		DATA PREPARATION		*******************************************************
* These commands are specific to the dataset used. 
* After renaming variables to be consistent with those used below, the remainder of the file should run with any dataset.


use EIHS_extract, clear	

rename exp y				/* ability to pay variable */
rename hhw wt				/* sample weight */

label variable y		"equivalent household prepayment expenditure (actual expenditure + eqdir + eqsoc)"
label variable wt		"household frequency sampling weights"
label variable soc	"equivalent household social insurance contributions"
label variable dir	"equivalant household direct taxes (not earmarked)"
label variable ind	"equivalent household indirect taxes (not earmarked)"

gen tax=(dir+ind)*0.025245 	// scale total tax payments made by the hhold by the proportion of them that, on average, go to fund the health sector  

/* In Egypt (1997), which is used here as an example, tax funded exp. is 56.1% of total public exp. on health (WHO World Health Report 2001).
	Public exp. on health is 4.5% of general govt. exp.
	So, the % of household tax payments going to health sector is: 2.5245% */

global X "tax soc"			

quietly regr y $X [pw=wt]
drop if e(sample)~=1


***********************************************************************************************************


**** Generate weighted fractional rank

egen 	rank1 = rank(y), unique 		
sort rank1
qui sum wt
gen wi=wt/r(sum)
gen cusum=sum(wi)
gen wj=cusum[_n-1]
replace wj=0 if wj==.
gen r=wj+0.5*wi

sum r [aw=wt]
sca v_rank=r(Var)


**** Estimate the pre-payment Gini

qui sum y [aw=wt]
sca m_y=r(mean)
qui cor r y [aw=wt], c
sca gini=2*r(cov_12)/m_y


**** Generate post-payment income for each payment, estimate respective gini and redistributive effect

foreach x of global X {
	qui { 
		gen ypost_`x'=y-`x'
		sum ypost_`x' [aw=wt]
		sca my_`x'=r(mean)
		egen 	rank_`x' = rank(ypost_`x'), unique 		
		sort rank_`x'
		gen cusum_`x'=sum(wi)
		gen wj_`x'=cusum_`x'[_n-1]
		replace wj_`x'=0 if wj_`x'==.
		gen r_`x'=wj_`x'+0.5*wi
		corr r_`x' ypost_`x' [aw=wt], c
		sca gini_`x'=2*r(cov_12)/my_`x'
		sca re_`x'=gini-gini_`x'
	}
}
 

**** Generate categorical variable indicating income group

qui sum y
local max=r(max)
kdensity y [aw=wt], n(100) nograph
local width=r(scale)
egen ygroup=cut(y), at(0(`width')`max') icodes
recode ygroup .=99


**** Generate concentration index for post-payment income and reranking term

foreach x of global X {
	qui { 
		drop cusum_`x' wj_`x' r_`x'
		sort ygroup rank_`x'
		gen cusum_`x'=sum(wi)
		gen wj_`x'=cusum_`x'[_n-1]
		replace wj_`x'=0 if wj_`x'==.
		gen r_`x'=wj_`x'+0.5*wi
		corr r_`x' ypost_`x' [aw=wt], c
		sca ci_`x'=2*r(cov_12)/my_`x'
		sca rr_`x'=gini_`x' - ci_`x'
	}
}


**** Generate Kakwani index assuming horizontal equity by computing the between-groups concentration index for payments

gen grpsize=1
preserve
collapse (mean) y $X (sum) grpsize [aw=wt], by(ygroup)

egen 	rank1 = rank(y), unique 		
sort rank1
qui sum grpsize
gen wi=grpsize/r(sum)
gen cusum=sum(wi)
gen wj=cusum[_n-1]
replace wj=0 if wj==.
gen r=wj+0.5*wi

foreach x of global X {
	qui { 
		sum `x' [aw=grpsize]
		sca m_`x'=r(mean)
		corr r `x' [aw=grpsize], c
		sca ci2_`x'=2*r(cov_12)/m_`x'
		sca k_`x'=ci2_`x' - gini
	}
}

restore


**** Calculate health payments as a share of total income and the vertical redistribution effect

foreach x of global X {
		qui sum `x' [aw=wt]
		sca g_`x'=r(mean)/m_y
		sca v_`x'=(g_`x'/(1-g_`x'))*k_`x'
		sca v100_`x'=(v_`x'/re_`x')*100
}


* Present the full decomposition

foreach x of global X {
	di "Decomposition of redistributive effect of `x' payments"
	di "Redistributive effect:", re_`x'
	di "Vertical redistribution:", v_`x'
	di "Vertical redistribution as % total redist. effect", v100_`x'
	di "Payments as a fraction of total income, g", g_`x'
	di "Horizontal inequity", v_`x'-rr_`x'-re_`x'
	di "Reranking", rr_`x'
}



log close
