log using AHE13, replace

*******************************************************************************************************************
*	ANALYZING HEALTH EQUITY USING HOUSEHOLD SURVEY DATA: A GUIDE TO TECHNIQUES AND THEIR IMPLEMENTATION		*
*	OWEN O'DONNELL, EDDY VAN DOORSLAER, ADAM WAGSTAFF AND MAGNUS LINDELOW							*
*	WASHINGTON DC, WORLD BANK, 2007													*
*	www.worldbank.org/analyzinghealthequity 												*
*******************************************************************************************************************


***************************	CHAPTER 13	DECOMPOSITION OF THE CONCENTRATION INDEX		*************************



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

use AHE10, clear			/* data for the example are from the 1998 Vietnam Living Standards Survey */

rename haz y 			/* variable of interest - in example is (height-for-age z-score)*-100 */
replace y=0 if y<0		/* replace negative with zero values */
rename log_con x			/* rename living standards ranking variable */

label variable y "max(0, negative height-for-age z-score)"
label variable x "(log) household consumption per capita"
label variable age "age of child in months"
label variable agesqr "age squared"
label variable male "1 if child male"
label variable water_ok "1 household has safe supply of drinking water"
label variable loo_ok "1 household has satisfactory sanitation"
label variable educyr98 "years of schooling of household head"
label variable mumdip "1 if mum has any diploma"
lab var wt "sample weight"

qui tab commune, gen(dummy)	/* generate dummies for the communities, or any other categorical variable that will enter in model */ 


global X "age agesqr male x water_ok loo_ok educyr98 mumdip" 	/* regressors */

drop if age>120				/* drop observations over 10 years old */

qui regress y $X dummy* [pw=wt]	
drop if e(sample)~=1			/* drop observations missing on any variables will use */


* ***********************************************************************************************************




***** GENERATE WEIGHTED FRACTIONAL RANK VARIABLE

egen raw_rank=rank(x), unique 		
sort raw_rank
quietly sum wt
gen wi=wt/r(sum)
gen cusum=sum(wi)
gen wj=cusum[_n-1]
replace wj=0 if wj==.
gen rank=wj+0.5*wi				
drop raw_rank wi cusum wj 


***** CONCENTRATION INDEX 

qui sum y [fw=wt]
scalar m_y=r(mean)
cor y rank [fw=wt], c
sca CI=(2/m_y)*r(cov_12)
display "concentration index", CI


*** COMPUTE ELASTICITIES, CI AND CONTRIBUTIONS OF EACH FACTOR
 
qui regr y $X dummy* [pw=wt]
foreach x of global X {
	qui {
		sca b_`x' = _b[`x']				
		corr rank `x' [fw=wt], c
		sca cov_`x' = r(cov_12)				
		sum `x' [fw=wt]
		sca elas_`x' = (b_`x'*r(mean))/m_y		
		sca CI_`x' = 2*cov_`x'/r(mean)			
		sca con_`x' = elas_`x'*CI_`x'			
		sca prcnt_`x' = con_`x'/CI		
	}
	di "`x' elasticity:", elas_`x'
	di "`x' concentration index:", CI_`x'
	di "`x' contribution:", con_`x'
	di "`x' percentage contribution:", prcnt_`x'
}


*** COMPUTE THE TOTAL CONTRIBUTION OF THE (COMMUNITY) FIXED EFFECTS

local i=1
foreach x of varlist dummy* {
	qui {
		sca b_`x' = _b[`x']				
		corr rank `x' [fw=wt], c
		sca cov_`x' = r(cov_12)				
		sum `x' [fw=wt]
		sca elas_`x' = (b_`x'*r(mean))/m_y		
		sca CI_`x' = 2*cov_`x'/r(mean)			
		sca con_`x' = elas_`x'*CI_`x'			
	}
	if `i'==1 {
		sca con_dummies=con_`x'
	}
	else	{
		sca con_dummies=con_dummies+con_`x'
	}
	local ++i
}
sca prcnt_dummies = con_dummies/CI		
di "contribution of fixed effects:", con_dummies
di "percentage contribution of fixed effects:", prcnt_dummies


*** COMPUTE THE RESIDUAL

sca residual=CI
foreach x of global X {
	sca residual=residual-con_`x'
}
sca residual=residual-con_dummies
di "residual:" residual

log close


