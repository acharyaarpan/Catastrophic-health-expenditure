* log using AHE8, replace

*******************************************************************************************************************
*	ANALYZING HEALTH EQUITY USING HOUSEHOLD SURVEY DATA: A GUIDE TO TECHNIQUES AND THEIR IMPLEMENTATION		*
*	OWEN O'DONNELL, EDDY VAN DOORSLAER, ADAM WAGSTAFF AND MAGNUS LINDELOW							*
*	WASHINGTON DC, WORLD BANK, 2007													*
*	www.worldbank.org/analyzinghealthequity 												*

*******************************************************************************************************************

******************************	CHAPTER 8	THE CONCENTRATION INDEX		*************************************


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

use vlss_subsidy_98, clear	/* load dataset. Example: Individual level dataset on public health subsidy from Vietnam Living Standards Survey, 1997/98 */ 

rename opsub y		/* rename variable of interest (outpatient subsidy in example) to label used below - y */
rename hhexp_eq x		/* rename living standards ranking variable (total household consumption per equivalent adult in example) to label used below - x */
* ren weight wt		/* rename sample weight vbl to label used below - wt */

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

glcurve x [aw=wt],pvar(rank1) nograph	/* alternative method of generating weighted fractional rank */

corr rank rank1					/* alternative methods give perfectly correlated rank variables */
sum rank rank1 [aw=wt]				/* but only first method gives rank with mean of precisely 0.5 */
drop rank1


***** CONCENTRATION INDEX BY CONVENIENT COVARIANCE METHOD

qui sum y [fw=wt]
scalar mean=r(mean)
cor y rank [fw=wt], c
sca CI1=(2/mean)*r(cov_12)
display "concentration index by convenient covariance method", CI1


***** CONCENTRATION INDEX BY CONVENIENT REGRESSION METHOD

qui sum rank [fw=wt]
sca var_rank=r(Var)
gen lhs=2*var_rank*(y/mean)
regr lhs rank [pw=wt]
sca CI2=_b[rank]
display "concentration index by convenient regression method", CI2

*********************************************************************************************
/* ***************************** EXERCISE 1 ****************************************************

* Multiply the variable of interest (y) by 2 and recompute the concentration index for this scaled variable.

gen y2=2*y
qui sum y2 [fw=wt]
scalar meany2=r(mean)
quietly cor y2 rank [fw=wt], c
sca CI3=(2/meany2)*r(cov_12)
display "concentration index for scaled variable", CI3
drop y2 

* What does the result imply about the sensitivity of the CI to scale?


* Add 1 to the variable of interest and recompute the concentration index for the transformed variable.

gen y1=y+1
qui sum y1 [fw=wt]
scalar meany1=r(mean)
quietly cor y1 rank [fw=wt], c
sca CI4=(2/meany1)*r(cov_12)
display "concentration index for linear transformation of variable", CI4
drop y1

* What does this imply about the sensitivity of the CI to a linear transformation?

**********************************************************************************************

*********************************************************************************************
***************************** EXERCISE 2 ****************************************************

* Compute the Gini index of income inequality.

qui sum x [fw=wt]
scalar meanx=r(mean)
qui cor rank x [fw=wt], c
sca Gini = (2/meanx)*r(cov_12) 		
display "Gini index", Gini
*/

***********************************************************************************************

************************	STANDARD ERROR OF CONCENTRATION INDEX 	**********************

********* WITHOUT SAMPLE WEIGHTS 

*** Calculation of standard errors according to Kakwani et al (1997) J. of Econometrics

glcurve y, sortvar(x) pvar(ranku) glvar(ccurve) lorenz nograph

qui sum ranku 
sca var_ranku=r(Var)
qui sum y
sca meanu=r(mean)
gen lhsu=2*var_ranku*(y/meanu)
regr lhsu ranku					/* convenient regression */
sca conindu=_b[ranku]				/* the concentration index */

sort ranku
gen cclag = ccurve[_n - 1]
replace cclag=0 if cclag==.
gen asqr=((y/meanu)*(2*ranku-1-conindu)+2-cclag-ccurve)^2
qui sum asqr
sca var=(r(mean)-(1+conindu)^2)/r(N)
sca se=sqrt(var)
sca list conindu se				/* CI with standard error */

*** Delta method SEs from convenient regression
regr y ranku
nlcom ((2/12)/(_b[_cons]+0.5*_b[ranku]))*_b[ranku]

drop ranku lhsu cclag ccurve asqr 


********* WITH SAMPLE WEIGHTS

regr lhs rank [pw=wt]			/* Standard errors reported here do not take account of sampling variability of mean used in transformation */

* Taking account of sampling variability of mean
qui regr y rank [pw=wt]
nlcom ((2/12)/(_b[_cons]+0.5*_b[rank]))*_b[rank]



**** TAKING ACCOUNT OF CLUSTER SAMPLING AND AUTOCORRELATION INDUCED BY RANK INDEPENDENT VARIABLE

* Correcting standard errors for within cluster correlation
regr lhs rank [pw=wt], cluster(cluster)

qui regr y rank [pw=wt], cluster(cluster)
nlcom ((2/12)/(_b[_cons]+0.5*_b[rank]))*_b[rank]


* Correcting standard errors for autocorrelation (and heteroscedasticity)
egen 	ranki=rank(x), unique 			
tsset ranki
newey lhs rank [aw=wt], lag(1)

qui newey y rank [aw=wt], lag(1)
nlcom ((2/12)/(_b[_cons]+0.5*_b[rank]))*_b[rank]

log close
