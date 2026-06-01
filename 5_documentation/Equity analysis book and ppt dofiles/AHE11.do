log using AHE11, replace

*******************************************************************************************************************
*	ANALYZING HEALTH EQUITY USING HOUSEHOLD SURVEY DATA: A GUIDE TO TECHNIQUES AND THEIR IMPLEMENTATION		*
*	OWEN O'DONNELL, EDDY VAN DOORSLAER, ADAM WAGSTAFF AND MAGNUS LINDELOW							*
*	WASHINGTON DC, WORLD BANK, 2007													*
*	www.worldbank.org/analyzinghealthequity 												*
*******************************************************************************************************************


****************		CHAPTER 11	NONLINEAR MODELS FOR HEALTH AND MEDICAL EXPENDITURE DATA	*******************


*****************************			PRELIMINARIES		*************************************************
version 9.2
clear
set more off
set matsize 800 			
set mem 100m

* This do file calls on 2 ado files that are not automatically integrated in Stata and must be installed.
* The ado files are:
* 	1) trnpois0 - truncated Poisson regression
*	2) trnbin0 - truncated negative binomial regression
* If the ado files are not already installed they can be downloaded from the Stata website using:
* 	findit trnpois0 (/trnbin0) 
* and following the the leads 

*******************************************************************************************************************


****************************		DATA PREPARATION		*******************************************************
*
* These commands are specific to the dataset used. 
* After renaming variables to be consistent with those used below, the remainder of the file should run with any dataset.

use AHE11, clear				/* data for the example are from the 1998 Vietnam Living Standards Survey */


* Variables used in binary response example

gen d=(neg_haz>2 & neg_haz!=.)	/* binary dependent variable to use on binary response models. In example is indicator of whether child is stunted (haz<-2). */
 
global X1 "agem agemsqr log_con educyr98" 		/* continuous regressors for binary reponse example */
global D1 "male water_ok loo_ok mumdip" 		/* dummy regressors for binary reponse example */

rename child group		/* dummy variable that identifies the group of interest. In first example is children <10 years. 
					   If analysis is to be done on full sample, replace with "gen group=1" */


* Variables used in limited dependent variable example

rename d_oop d1			/* dummy that indicates positive values of the limited dependent variable, which is medical expenditure in the example */
rename oop y			/* limited dependent variable of interest - OOP medical expenditure in example */
rename log_oop lny		/* log of positive values of limited dependent variable */
#delimit ;
global X2 "age agesqr agecub male bmi bmisqr ln_rent loo_ok house school1 school2 diphoh educyr98 hoh hhsize hhsizesq 
		region1 region2 region3 region4 region5 region6 region7 region8 region9";
#delimit cr



* Variables used in count data example

rename pharvis c			/* dependent variable for count data models. In example is number of visits to pharmacist */
rename d_phar d2			/* dummy indicating positive value of count dependent variable */
global X3 "log_con school1 school2 bmi bmisqr loo_ok house hoh hhsize age agesqr agecub male region1-region9"


rename reg10o strata		/* categorical variable that identifies strata */
rename commune psu		/* variable that identifies the primary sampling units */
* rename weight wt		/* sample weight */

*******************************************************************************************************************


* ************************ BINARY REPSONSE MODELS ***************************************

* ************ Linear Probability Model 

regr d $X1 $D1 if group==1, cluster(psu)	// Adjust SEs for clustering but not for stratification and do not apply weights on basis that assume stratification is exogenous

svyset psu [pw=wt], strata(strata)		// Compare with full sample design adjustment
svy, subpop(group): reg d $X1 $D1


* *********** Logit 

logit d $X1 $D1 if group==1, cluster(psu)

mfx compute, at(median) // Partial effects at sample medians 


* Calculate individual specific partial effects
qui logit d $X1 $D1 if group==1, cluster(psu)
predict xb if e(sample)==1, xb 
predict p if e(sample)==1, p
gen t_var=p*(1-p)

foreach c of global X1 {
	gen pe_`c'=t_var*_b[`c']
}
foreach d of global D1 {
	gen pe_`d'=p-(exp(xb-_b[`d'])/(1+exp(xb-_b[`d'])))
	replace pe_`d'=(exp(xb+_b[`d'])/(1+exp(xb+_b[`d'])))-p if `d'==0
}
summ pe_* [fw=wt], detail
drop p xb t_var pe_*


* ***************** Probit 

probit d $X1 $D1 if group==1, cluster(psu)

* Calculate individual specific partial effects
predict xb if e(sample)==1, xb 
predict p if e(sample)==1, p
gen t_var=normden(xb)

foreach c of global X1 {
	gen pe_`c'=t_var*_b[`c']
}
foreach d of global D1 {
	gen pe_`d'=p-norm(xb-_b[`d'])
	replace pe_`d'=norm(xb+_b[`d'])-p if `d'==0		
}
summ pe_* [fw=wt], detail
drop p xb t_var pe_*


* Recalculate partial effects at sample means / median

dprobit d $X1 $D1 if group==1, cluster(psu) 		// at means

* Define matrix of median values 
local i=1
local vars "$X1 $D1"
foreach x of local vars {
	qui sum `x' [aw=wt] if group==1, d
	sca `x'_md=r(p50)
	if `i'==1 {
		matrix medians=(`x'_md)
	}
	else {
		matrix medians=(medians,`x'_md)
	}
	local ++i
}
dprobit d $X1 $D1 if group==1, cluster(psu) at(medians)



* ************************ LIMITED DEPENDENT VARIABLE MODELS ***************************************

********************* Two-Part Model (2PM)
******* Probit 
probit d1 $X2, cluster(psu) 
predict p if e(sample), p 		// predicted probability of positive value
gen sample=e(sample)

* ***** OLS
regr lny $X2 if d1==1, cluster(psu) 
predict xb if e(sample), xb				// predicted positive value

* ******************* Sample Selection Model 
******* 2 step 
heckman lny $X2, sel(d1=$X2) twostep mills(imr) 
predict xbsel if d1==1, xbsel 
twoway (scatter xbsel imr if d1==1)
drop xbsel imr

******* MLE
heckman lny $X2, sel(d1=$X2) mills(imr) cluster(psu)
predict xbsel if d1==1, xbsel 
twoway (scatter xbsel imr if d1==1)
drop xbsel imr


* ****************** Compare Tobit with 2PM in linear (not log) form 

* ********** 2nd part OLS 
regr y $X2 if d1==1, cluster(psu) 
qui sum d1
matrix define b=e(b)
matrix define t_b=b/r(mean)		// OLS coefficients scaled by the proportion of positive values
matrix list t_b
matrix drop b

* ************ Tobit 
tobit y $X2, ll(0) 



* ***************************		COUNT DATA MODELS		***********************************************

* Estimate first without cluster adjustment TO STANDARD ERRORS in order to choose estimator on basis of LR tests (since with cluster is Pseudo ML)

* ************** Poison 
poisson c $X3

* ************** NegBin I (dispersion is proportionate to mean)   
nbreg c $X3, dispersion(constant) 

* ************** NegBin II (dispersion is quadratic function of mean) 
nbreg c $X3 

* Poisson rejected against both NegBin I and II. 
* All it says otherwise in the book chapter, with these data the Log-likelihood is greater for NegBin I suggesting this favoured.

nbreg c $X3, cluster(psu) 


* ****************** Two part model 
probit d2 $X3, cluster(psu)
trnbin0 c $X3 if d2==1, cluster(psu)


* ****************** Conditional fixed effects Poisson
tsset, clear
xtpois c $X3, fe i(psu) 




log close 





