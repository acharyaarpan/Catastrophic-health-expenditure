log using AHE18, replace

*******************************************************************************************************************
*	ANALYZING HEALTH EQUITY USING HOUSEHOLD SURVEY DATA: A GUIDE TO TECHNIQUES AND THEIR IMPLEMENTATION		*
*	OWEN O'DONNELL, EDDY VAN DOORSLAER, ADAM WAGSTAFF AND MAGNUS LINDELOW							*
*	WASHINGTON DC, WORLD BANK, 2007													*
*	www.worldbank.org/analyzinghealthequity 												*
*******************************************************************************************************************


******************************	CHAPTER 18	CATASTROPHIC PAYMENTS FOR HEALTH CARE	*************************




*****************************			PRELIMINARIES		*************************************************
version 9.2
clear
set more off
set matsize 800 			
set mem 100m

* This do file calls an ado files - glcuve - that is not automatically integrated in Stata and must be installed.
* Use "findit glcurve" and follow the instructions.


*******************************************************************************************************************


****************************		DATA PREPARATION		*******************************************************
* These commands are specific to the dataset used. 
* After renaming variables to be consistent with those used below, the remainder of the file should run with any dataset.

use VLSS_OOP.dta, clear		/* health payments data from 1997/8 Vietnam living standards survey */

rename exp x
rename nonfood1 xnf
rename hhw wt
rename commune psu
rename reg10o strata
gen oopshare=oop/x


label variable oop	"total household out-of-pocket health payments"
label variable x		"total household expenditure"
label variable oopshare "oop health payments as share of total hhold expenditure"
label variable wt		"household frequency sampling weights"
label variable xnf	"total household non-food expenditure"
label variable psu 	"primary sampling unit in cluster sampling"
label variable strata 	"stratification identifier"


quietly regr x oop xnf [pw=wt]
drop if e(sample)~=1					/* drop observations missing on any variable used in analysis */

svyset psu [pw=wt], strata(strata) || _n		/* set sample design parameters */


***********************************************************************************************************

*** CREATE HOUSEHOLD LEVEL INDICATOR OF CATASTROPHIC PAYMENTS AND OVERSHOOT AT VARIOUS THRESHOLDS

forvalues i = 5 10 to 25 {
		gen count`i'=(oopshare>(`i'/100))
		gen over`i'=count`i'*(oopshare-(`i'/100))
}


*** COMPUTE POPULATION ESTIMATES OF HEADCOUNT PROPORTION AND MEAN OVERSHOOT AT VARIIOUS THRESHOLDS 

svy: mean count* over*


*** COMPUTE THE MEAN POSITIVE OVERSHOOT AT VARIOUS THRESHOLDS

forvalues i = 5 10 to 25 {
		svy, subpop(count`i'): mean over`i'
}

****************************************************************************************
******************************* EXERCISE 1 *********************************************

* Compute headcounts, mean overshoot and mean positive overshoot for catastrophic OOP
* payments defined in relation to household non-food expenditure.

gen oopshare1=oop/xnf


*** CREATE HOUSEHOLD LEVEL INDICATOR OF CATASTROPHIC PAYMENTS AND OVERSHOOT AT VARIOUS THRESHOLDS

forvalues i = 5 10 to 40 {
		gen cnt`i'=(oopshare1>(`i'/100))
		gen ovr`i'=cnt`i'*(oopshare1-(`i'/100))
}


*** COMPUTE POPULATION ESTIMATES OF HEADCOUNT PROPORTION AND MEAN OVERSHOOT AT VARIIOUS THRESHOLDS 

svy: mean cnt* ovr*


*** COMPUTE THE MEAN POSITIVE OVERSHOOT AT VARIOUS THRESHOLDS

forvalues i = 5 10 to 40 {
		svy, subpop(cnt`i'): mean ovr`i'
}

************************************************************************************************

*****************************************************************************************************
**************************** GRAPH DISTRIBUTION OF OOP SHARES **************************

gen compshare = 1-oopshare		
glcurve oopshare [aw=wt], pvar(p) sortvar(compshare) nograph 
label variable p "OOP/total exp."	
gen compshare1 = 1-oopshare1		
glcurve oopshare1 [aw=wt], pvar(p1) sortvar(compshare1) nograph 	
label variable p1 "OOP/non-food exp."
#delimit ;
twoway (connected p oopshare, sort msize(tiny)) (connected p1 oopshare1, sort msize(tiny)), 
	ytitle(health payments budget share) 
	xtitle(cumulative proportion of population ranked by decreasing health payments budget share) ;
#delimit cr
graph export Figure.emf, replace

*******************************************************************************************************


************ 	DISTRIBUTION SENSITIVE MEASURES OF CATASTROPHIC PAYMENTS		*******************

***** GENERATE WEIGHTED FRACTIONAL RANK

egen 	rank = rank(x), unique 		
sort rank
qui sum wt
gen wi=wt/r(sum)
gen cusum=sum(wi)
gen wj=cusum[_n-1]
replace wj=0 if wj==.
gen r=wj+0.5*wi


*** COMPUTE CONCENTRATION INDICES BY CONVENIENT REGRESSION 

sum r [fw=wt] 
sca v_rank=r(Var)

foreach var of varlist count* {			
	qui sum `var' [aw=wt]
	sca m_`var'=r(mean)
	gen d_`var'=(2*v_rank)*(`var'/m_`var')	
	quietly {
		regr d_`var' r 			
		matrix coefs=get(_b)			
		gen ci_`var'=coefs[1,1]			
		if "`var'"=="count5" {
			matrix ci=coefs[1,1]		
		}
		if "`var'"~="count5" {
			matrix ci=(ci, coefs[1,1]) 	
		}
	}
}

 
for any ci_: tabstat X* 					/* produce table of CIs */

quietly svy: mean count*
matrix h=e(b)						/* extract the unweighted headcounts */

matrix wh=(h[1,1]*(1-ci[1,1]),h[1,2]*(1-ci[1,2]),h[1,3]*(1-ci[1,3]),h[1,4]*(1-ci[1,4]),h[1,5]*(1-ci[1,5]))	
								/* multiply headcounts by CIs and form matrix of weighted headcounts */

*** PRINT THE UNWEIGHTED HEADCOUNTS, CIs AND WEIGHTED HEADCOUNTS
matrix list h
matrix colnames ci = ci5 ci10 ci15 ci20 ci25				
matrix list ci
matrix colnames wh = wh5 wh10 wh15 wh20 wh25				
matrix list wh



************************************************************************************************
******************************** EXERCISE 2 ****************************************************

* Compute the weighted mean catastrophic overshoots for the same thresholds.

drop d_* ci_*

foreach var of varlist over* {			
	qui sum `var' [aw=wt]
	sca m_`var'=r(mean)
	gen d_`var'=(2*v_rank)*(`var'/m_`var')	
	quietly {
		regr d_`var' r 			
		matrix coefs=get(_b)			
		gen ci_`var'=coefs[1,1]			
		if "`var'"=="over5" {
			matrix ci=coefs[1,1]		
		}
		if "`var'"~="over5" {
			matrix ci=(ci, coefs[1,1]) 	
		}
	}
}


for any ci: tabstat X* 					

quietly svy: mean over*
matrix o=e(b)						

matrix wo=(o[1,1]*(1-ci[1,1]),o[1,2]*(1-ci[1,2]),o[1,3]*(1-ci[1,3]),o[1,4]*(1-ci[1,4]),o[1,5]*(1-ci[1,5]))	
								
*** PRINT THE UNWEIGHTED OVERSHOOT, CIs AND WEIGHTED OVERSHOOT
matrix list o
matrix colnames ci = ci5 ci10 ci15 ci20 ci25				
matrix list ci
matrix colnames wo = wo5 wo10 wo15 wo20 wo25				
matrix list wo



log close








