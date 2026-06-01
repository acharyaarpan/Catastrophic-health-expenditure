log using AHE5, replace

*******************************************************************************************************************
*	ANALYZING HEALTH EQUITY USING HOUSEHOLD SURVEY DATA: A GUIDE TO TECHNIQUES AND THEIR IMPLEMENTATION		*
*	OWEN O'DONNELL, EDDY VAN DOORSLAER, ADAM WAGSTAFF AND MAGNUS LINDELOW							*
*	WASHINGTON DC, WORLD BANK, 2007													*
*	www.worldbank.org/analyzinghealthequity 												*											*
*******************************************************************************************************************

******************************	CHAPTER 5	HEALTH OUTOME #3: ADULTS HEALTH	*******************************


******************************************	 PRELIMINARIES		*******************************************

version 9.2
clear
set more off
set matsize 800 			
set mem 100m


*******************************************************************************************************************

***************************************	PREPARE THE DATA	*******************************************************
* These commands are specific to the dataset used. 
* After renaming variables to be consistent with those used below and defining globals, the remainder of the file should run with any dataset.

use jslc.dta, clear						/* In example, data are from the Jamaican Living Standards Survey 1989 */

*** LABEL VARIABLES 

label variable sah "self assessed health (5 categories)"
label variable exp "equivalent household expenditure"
label variable hhsize "household size"
label variable insured "have health insurance cover"
label variable dvgood "1 if sah is very good"
label variable dgood "1 if sah is good"
label variable dfair "1 if sah is fair"
label variable dpoor "1 if sah is poor"
label variable illness "1 if report illness"
label variable injury "1 if report injury"
label variable dacute "1 if report acute illness (< 4 weeks in duration)"
label variable dchron "1 if report chronic illness (> 4 weeks in duration)"
label variable doutp "1 if report visit to outpatient clinic"
label variable dprim "1 if report visit to primary care"
label variable dhosp "1 if report visit to hospital"
label variable dfl1 "1 if report functional limitation type 1"
label variable dfl2 "1 if report functional limitation type 2"
label variable dfl3 "1 if report functional limitation type 3"
label variable dfl4 "1 if report functional limitation type 4"
label variable dfl5 "1 if report functional limitation type 5"
label variable dfl6 "1 if report functional limitation type 6"
label variable illdays "reported days of illness"
label variable indays "reported days of injury"
label variable dprevis "1 if any visit to dr., nurse or health practitioner for preventive care"
label variable previs "number of visits to dr., nurse or health practitioner for preventive care"
label variable mage2 "1 if male and age group 2"
label variable mage3 "1 if male and age group 3"
label variable mage4 "1 if male and age group 4"
label variable mage5 "1 if male and age group 5"
label variable fage1 "1 if female and age group 1"
label variable fage2 "1 if female and age group 2"
label variable fage3 "1 if female and age group 3"
label variable fage4 "1 if female and age group 4"
label variable fage5 "1 if female and age group 5"


*** ASSIGN CATEGORY SPECIFIC MEDIAN VALUES OF THE HEALTH UTILITY INDEX (FROM CANADIAN DATA) 
*** TO THE CORRESPONDING SELF-ASSESSED HEALTH CATEGORIES IN THE JLCS
 
gen hui = .945 if sah==1
replace hui = .923 if sah==2
replace hui = .876 if sah==3
replace hui = .758 if sah==4
replace hui = .557 if sah==5

*** DEFINE LOWER AND UPPER THRESHOLDS OF HUI TO BE USED IN INTERVAL REGRESSION (PART OF DECOMPOSITION)

gen sahl = .947 		if sah==1
replace sahl = .897	if sah==2	
replace sahl = .77	if sah==3
replace sahl = .428	if sah==4
replace sahl = 0		if sah==5
gen sahu = 1 		if sah==1
replace sahu = .947 	if sah==2	
replace sahu = .897 	if sah==3
replace sahu = .77 	if sah==4
replace sahu = .428 	if sah==5


***	RENAME VARIABLES AND DEFINE GLOBALS TO BE CONSISTENT WITH THOSE USED IN PROGRAM BELOW

rename hui y 										/* variable of interest */
rename exp x										/* living standards ranking variable */

global agesex "mage2 mage3 mage4 mage5 fage1 fage2 fage3 fage4 fage5"	/* standardising variables - age-sex dummies */
gen lnx=ln(x)
global Z "lnx hhsize insured" 							/* control variables */	
global var "lnx $agesex"								/* living standards and standardising vbls to use in decomposition */


quietly regress y x $ageseX $Z	
drop if e(sample)~=1									/* drop observations missing on any variables will use */

**************************************************************************************************************


*************************** TABLE 5.1: UNSTANDARDISED QUINTILE SPECIFIC MEANS		*************************

xtile quintile = x, nq(5)			/* apply weights if exist */
tabstat y, by(quintile) stats(mean)


****	UNSTANDARDISED CONCENTRATION INDEX (not reported in book)

sort x
egen temp=rank(x), unique		/* rank by living standards variable. Note: no weights */
gen rank=temp/_N

qui sum y
sca mean=r(mean)
qui sum rank 
sca var_r=r(Var)		
gen lhs = 2*var_r*y/mean		
qui regr lhs rank
sca CIu=_b[rank]
sca tCIu=CIu/_se[rank]
di "Unstandardised concentration index: " CIu	tCIu
drop temp 

****************************************************************************************


******************************* EXERCISE 1 *********************************************

* Compute unstandardised quintile means and the concentration index for number of illness days (tilldays).

*****************************************************************************************



***********************	TABLE 5.2: DIRECT AND INDIRECT STANDARDISATION OF QUINTILES MEANS AND CONCENTRATION INDICES	**************


********** INDIRECT STANDARDISATION 


*** WITHOUT CONTROLLING FOR OTHER VARIABLES (Z) IN ESTIMATION OF THE AGE-SEX EFFECTS

qui reg y $agesex				
predict yhat1				
gen yis1 = y-yhat1 + mean			/* standardised value */

gen lhs1 = 2*var_r*yis1/mean
qui regr lhs1 rank 		
sca CIis1 = _b[rank]				/* standardised concentration index by 2 step method */ 
sca tCIis1 = _b[rank]/_se[rank]

regr lhs rank $agesex				/* one step method of obtaining standardised concentration index */
sca CI1step=_b[rank]
drop lhs lhs1

sca list CIis1 CI1step


*** CONTROLLING FOR OTHER VARIABLES (Z) IN ESTIMATION OF THE AGE-SEX EFFECTS

qui regr y $agesex $Z

foreach z of global Z {
	egen m_`z' = mean(`z')
	gen copy_`z' = `z' 				 
	replace `z' = m_`z'
}

predict yhat2 				/* this yhat only varies with age-sex not $Z */
gen yis2 = y - yhat2 + mean		
		
foreach z of global Z {		
	replace `z' = copy_`z'
}

gen lhs = 2*var_r*yis2/mean
regr lhs rank 	 
sca CIis2 = _b[rank]
sca tCIis2 = _b[rank]/_se[rank]
drop lhs


*** UNSTANDARDISED AND INDIRECT STANDARDISED QUINTILE MEANS W/O AND WITH CONTROL FOR OTHER VARIABLES IN ESTIMATION OF AGE-SEX EFFECTS

tabstat y yis1 yis2, by(quintile) stats(mean)

graph bar (mean) y yis1 yis2, over(quintile)		/* graph results */


*** UNSTANDARDISED AND INDIRECT STANDARDISED CONCENTRATION INDICES AND t-RATIOS W/O AND WITH CONTROL FOR OTHER VARIABLES 

display "unstandardised CI:", CIu, "t-ratio:", tCIu 
di "standardised CI (w/o control for exp):", CIis1, "t-ratio:", tCIis1 
di "standardised CI (with control for exp):", CIis2, "t-ratio:", tCIis2

drop yhat* 

**************************************************************************************************************


***************************** 	DIRECT STANDARDISATION 		********************************************


*** NO CONTROL FOR OTHER VARIABLES
 

foreach x of global agesex {						/* Generate population means of age-sex variables and make copies */
	egen m_`x' = mean(`x')
	gen copy_`x' = `x' 				 
}

gen yds1=.
forvalues i= 1 2 to 5 {
	qui regr y $agesex if quintile==`i'				/* generate quintile specific age-sex coefficients */
	foreach x of global agesex {
		qui replace `x' = m_`x' if quintile==`i'		/* replace age-sex with population means */
	}
	qui predict yds_`i' if e(sample)				/* predicted health from quintile specific effects and population age-sex means */
	qui replace yds1 = yds_`i' if quintile==`i'		/* collapse standardised health into one variable */
	drop yds_`i'
}

foreach x of global agesex {						/* restore values of age-sex variables */
	replace `x' = copy_`x'			 
}


* COMPUTE CONCENTRATION INDEX 

egen m_yds1 = mean(yds1)
gen lhs = 2*var_r*yds1/m_yds1

qui regr lhs rank, cluster (quintile)		/* allow for clustering at quintile level since no variation in yds1 within quintile */
sca CIds1 = _b[rank]					/* direct standardised concentration index */ 
sca tCIds1 = _b[rank]/_se[rank]
drop lhs


tabstat y yds1, by(quintile) stats(mean)		/* unstandardised and direct standardised quintile means w/o controls */		

display "unstandardised CI:", CIu, "t-ratio:", tCIu 
di "direct standardised CI (without controls):", CIds1,"t-ratio:", tCIds1



*** CONTROL FOR OTHER VARIABLES IN AGE-SEX STANDARDISATION

gen yds2=.
forvalues i=1/5 {
	qui regr y $agesex $Z if quintile==`i'
	foreach x of global agesex {
		replace `x' = m_`x'
	}
	foreach z of global Z {
		qui sum `z' if quintile==`i'
		gen `z'_mean = r(mean)
		gen `z'_copy = `z'
		replace `z' = `z'_mean
	}
	predict ydsq`i' if e(sample)
	replace yds2=ydsq`i' if quintile==`i'
	foreach z of global Z {
		replace `z'=`z'_copy
		drop `z'_mean `z'_copy
	}
	foreach x of global agesex {
		replace `x'=copy_`x'
	}
}

egen m_yds2 = mean(yds2)
gen lhs = 2*var_r*yds2/m_yds2

qui regr lhs rank, cluster (quintile)		/* allow for clustering at quintile level since no variation in yds1 within quintile */
sca CIds2 = _b[rank]					/* direct standardised concentration index */ 
sca tCIds2 = _b[rank]/_se[rank]
drop lhs


*** TABLE 5.2: ACTUAL, INDIRECT AND DIRECT STANDARDISED MEANS BY QUINTILE AND ASSOCIATED CONCENTRATION INDICES

tabstat y yis1 yis2 yds1 yds2, by(quintile) stats(mean)


display "unstandardised CI:", CIu, "t-ratio:", tCIu 					/* concentration indices are not given in book chapter */
di "standardised CI (w/o controls):", CIis1, "t-ratio:", tCIis1 
di "standardised CI (with controls):", CIis2, "t-ratio:", tCIis2
di "direct standardised CI (without controls):", CIds1,"t-ratio:", tCIds1
di "direct standardised CI (with controls):", CIds2,"t-ratio:", tCIds2


**********************************************************************************************************

************************************ DECOMPOSITION BY FACTORS ********************************************

******** THIS IS NOT IN CHAPTER 5 OF BOOK (SEE CHAPTER 13) 

*** RUN INTERVAL REGRESSION, COMPUTED FITTED VALUE AND ITS MEAN

qui intreg sahl sahu $var 
predict yhat
egen m_yhat = mean(yhat)


*** COMPUTE CONCENTRATION INDEX FOR PREDICTED HEALTH 

corr rank yhat, c
sca cov_yhat = r(cov_12)			
sca CI_yhat = 2*cov_yhat/m_yhat	  
di "Concentration index for predicted health:", CI_yhat


*** COMPUTE ELASTICITIES, CI AND CONTRIBUTIONS OF EACH FACTOR
 
foreach x of global var {
	qui {
		sca b_`x' = _b[`x']				/* beta coeff. of x on sah */
		corr rank `x', c
		sca cov_`x' = r(cov_12)				/* covariance b/w x and expenditure rank */
		sum `x' 
		sca m_`x' = r(mean)				/* mean of x */
		sca elas_`x' = (b_`x'*m_`x')/m_yhat		/* elasticity of health with respect to x */
		sca CI_`x' = 2*cov_`x'/m_`x'			/* concentration index for x in relation to expenditure */  
		sca con_`x' = elas_`x'*CI_`x'			/* contribution of x to CI for health in relation to household expenditure */
		sca prcnt_`x' = con_`x'/CI_yhat		/* percentage of CI for predicted health accounted for by x */
	}
	di "`x' elasticity:", elas_`x'
	di "`x' concentration index:", CI_`x'
	di "`x' contribution:", con_`x'
	di "`x' percentage contribution:", prcnt_`x'
}

*** COMPUTE "UNAVOIDABLE" AND "AVOIDABLE" INEQUALITY 

sca C_unav = con_mage2+con_mage3+con_mage4+con_mage5+con_fage1+con_fage2+con_fage3+con_fage4+con_fage5  
di "Inequality due to age and sex:", C_unav

sca I = CI_yhat - C_unav	
di "Avoidable inequality:", I


****************************************************************************************************************
************************************ EXERCISE 2 ****************************************************************

* Repeat the decomposition of inequality in HUI but including household size (hhsize) and insurance status (insure),
* in the regression. 

* Decide whether hhsize and insure should be treated as contributing to avoidable or unavoidable inequality and 
* compute the concentration index for avoidable inequality (I).

*****************************************************************************************************************


log close


