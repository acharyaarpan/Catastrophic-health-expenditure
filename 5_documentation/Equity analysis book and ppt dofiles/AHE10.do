log using AHE10, replace

*******************************************************************************************************************
*	ANALYZING HEALTH EQUITY USING HOUSEHOLD SURVEY DATA: A GUIDE TO TECHNIQUES AND THEIR IMPLEMENTATION		*
*	OWEN O'DONNELL, EDDY VAN DOORSLAER, ADAM WAGSTAFF AND MAGNUS LINDELOW							*
*	WASHINGTON DC, WORLD BANK, 2007													*
*	www.worldbank.org/analyzinghealthequity 												*
*******************************************************************************************************************


*********************	CHAPTER 10	MULTIVARIATE ANALYSIS OF HEALTH SURVEY DATA	*******************************


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

rename haz y 			/* variable of interest - in example height-for-age z-score */
 
global X "age agesqr male log_con water_ok loo_ok educyr98 mumdip region4-region10" 	/* regressors */
global Z "age agesqr male log_con water_ok loo_ok educyr98 mumdip"				/* regressors w/o region dummies to use in commune fixed effects estimator */
global K "med9 fac1 fac2 fac3 fac6 s22q9 dr"								/* community level regressors */

rename child group				/* dummy variable that identifies the group of interest - in example is children <10 years */
gen subpop=(group==1 & commune>36 & med9~=. & fac1~=. & fac2~=. & fac3~=. & fac6~=. & s22q9~=. & dr~=.)		/* sub-sample of rural communes for which commune level regressors are available and non-missing */

rename reg10o strata		/* categorical variable that identifies strata */
rename commune psu		/* variable that identifies the primary sampling units */
* rename weight wt		/* sample weight */

*******************************************************************************************************************


**********************************	 	STRATIFICATION 		*************************************************

* Simple regression with no adjustment for sample design and no commune effects but region effects

regr y $X if group==1 


* Adjust standard errors (SE) for stratification only

svyset _n, strata(strata) 
svy, subpop(group): reg y $X 


* With robust SE but no stratification adjustment

regr y $X if group==1, robust


* With cluster/robust correction to SE

svyset psu, clear
svy, subpop(group): reg y $X 


* With cluster/robust and stratification correction to SE

svyset psu, strata(strata)  
svy, subpop(group): reg y $X 


***********************************		 CLUSTER SAMPLES 		**************************************************

******************  With cluster/robust correction to SE (but w/o region dummies)

svyset psu, clear
svy, subpop(group): reg y $Z 

******************	RANDOM EFFECTS
*** Without robust SEs

keep if group==1
tsset, clear
xtreg y $Z, re i(psu) 
xttest0

scalar define sigma_e=e(sigma_e)^2		/* Save estimates of variances of error components to use later */
scalar define sigma_u=e(sigma_u)^2
scalar list sigma_e sigma_u

/* Alternatively, could get estimates of the variance error components as follows:
qui xtreg y $Z, fe i(psu) 
scalar define sigma_e=e(sigma_e)^2 							/* variance of idiosyncratic error */
qui xtreg haz $Z, be i(psu) 
scalar define sigma_u=max(0,((e(rmse)^2)-(sigma_e/e(Tbar))))		/* variance of commune level error */
*/


*** With robust SEs 

* calculate theta - the transformation variable (not constant since not fixed group sizes here)
sort psu
by psu: gen T=_N 
gen theta=1-sqrt(sigma_e/(sigma_e +(T*sigma_u)))
sort psu

foreach x in y $Z {
	by psu: egen m_`x'=mean(`x')
	gen t_`x'=`x'-theta*m_`x'
}

gen intercept=1-theta

regr t_* intercept, noconstant robust		/* The point estimates are slightly different from those obtained from Stata pre-programmed routine. Not sure why. */
drop t_* intercept theta m_* T

*********************		FIXED EFFECTS
*** Without robust SE 

xtreg y $Z, fe i(psu) 
est store fixed
qui xtreg y $Z, re i(psu)
hausman fixed .

*** With robust SE

areg y $Z, absorb(psu) robust 



********************** 		ESTIMATORS WITH COMMUNITY LEVEL REGRESSORS	************************************************

********************** OLS With cluster/robust correction

svyset psu
svy, subpop(subpop): reg y $Z $K 

keep if subpop==1		/* keep only observations with community level regressors */


******************	RANDOM EFFECTS
*** Without robust SEs
xtreg y $Z $K, re i(psu) 
xttest0

scalar define sigma_e=e(sigma_e)^2		/* Save estimates of variances of error components to use later */
scalar define sigma_u=e(sigma_u)^2
scalar list sigma_e sigma_u

*** With robust SEs

* calculate theta - the transformation variable (not constant since not fixed group sizes here)
sort psu
by psu: gen T=_N 
gen theta=1-sqrt(sigma_e/(sigma_e +(T*sigma_u)))
sort psu

foreach x in y $Z {
	by psu: egen m_`x'=mean(`x')
	gen t_`x'=`x'-theta*m_`x'
      }

foreach k of global K  {
	gen t_`k'=`k'-theta*`k'
      }

gen intercept=1-theta

regr t_* intercept, noconstant robust

* Note: The point estimates are slightly different from those obtained from Stata pre-programmed routine. Not sure why!


*********************  FIXED EFFECTS


*** With robust SE

areg y $Z if subpop==1, absorb(psu) robust


*** Without robust SE but saving FE to regress on commune level characteristics

xtreg y $Z if subpop==1, fe i(psu) 
predict ce, u


* regress estimated commune effects on commune CMHC variables

xtreg ce $K, be


log close 





