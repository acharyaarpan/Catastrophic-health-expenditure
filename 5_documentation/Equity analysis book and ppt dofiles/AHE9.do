* log using AHE8, replace

*******************************************************************************************************************
*	ANALYZING HEALTH EQUITY USING HOUSEHOLD SURVEY DATA: A GUIDE TO TECHNIQUES AND THEIR IMPLEMENTATION		*
*	OWEN O'DONNELL, EDDY VAN DOORSLAER, ADAM WAGSTAFF AND MAGNUS LINDELOW							*
*	WASHINGTON DC, WORLD BANK, 2007													*
*	www.worldbank.org/analyzinghealthequity 												*

*******************************************************************************************************************

*****	CHAPTER 9	EXTENSIONS TO THE CONCENTRATION INDEX: INEQUALITY AVERSION AND THE ACHIEVEMENT INDEX     ********


***************************************		 PRELIMINARIES		*******************************************
version 9.2
clear
set more off
set matsize 800 			
set mem 100m

* This do file calls on the ado file glcurve that is not automatically integrated in Stata and must be installed from the Stata website.
* Use <<findit glcurve>> and following the the leads 

********************************************************************************************************************


************************************************	PREPARE THE DATA	********************************************

use vlss_haz_93_98, clear		/* load dataset. Example: Individual level dataset height-for-age z-scores Vietnam Living Standards Survey, 1993 & 1998 */ 

rename neghaz y		/* rename variable of interest. In example is negative of height-for-age z-score*/
rename lnpcexp x		/* rename living standards ranking variable (log of per capital household consumption) */
* ren weight wt		/* rename sample weight vbl to label used below - wt */

drop if year==0		/* keeping only 1998 observations */
qui regr y x [pw=wt]	
drop if e(sample)!=1	/* drop observations missing on any variables used in analysis */

*******************************************************************************************************************


************	CONCENTRATION INDEX COMPUTED BY CONVENIENT COVARIANCE AND REGRESSION METHODS		*************


***** GENERATE WEIGHTED FRACTIONAL RANK VARIABLE

egen raw_rank=rank(x), unique 		
sort raw_rank
quietly sum wt
gen wi=wt/r(sum)
gen cusum=sum(wi)
gen wj=cusum[_n-1]
replace wj=0 if wj==.
gen rank=wj+0.5*wi				/* weighted fractional rank */
drop raw_rank wi cusum wj 


***** REGULAR CONCENTRATION INDEX BY CONVENIENT COVARIANCE METHOD
sca drop _all
qui sum y [fw=wt]
scalar mean=r(mean)
qui cor y rank [fw=wt], c
sca CI1=(2/mean)*r(cov_12)
display "regular concentration index", CI1


***** EXTENDED CONCENTRATION INDEX 

* COVARIANCE METHOD

forval i = 1/5 {
	ge adjrnk`i'=(1-rank)^(`i'-1)
	qui corr y adjrnk`i' [fw=wt], covar
	sca ci`i' = -`i'*r(cov_12)/mean 
}
sca li _all
sca drop ci1 ci2 ci3 ci4 ci5

* CONVENEIENT REGRESSION METHOD

forval i = 1/5 {
	sum adjrnk`i' [fw=wt]
	ge lhs`i' = -`i'*r(Var)*y/mean
	qui reg lhs`i' adjrnk`i' [pw=wt]
	sca ci`i' =_b[adjrnk`i']
}
sca li _all
drop adj* lhs*


******  ACHIEVEMENT INDEX

forval i = 1/5 {
	sca achiev`i' = mean*(1-ci`i') 
	di `i' _col(5) %5.3f ci`i' _col(20) %5.3f achiev`i' _col(30) 
}

log close
