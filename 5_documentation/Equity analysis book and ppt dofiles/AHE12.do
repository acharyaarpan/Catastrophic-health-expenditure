log using AHE12, replace

*******************************************************************************************************************
*	ANALYZING HEALTH EQUITY USING HOUSEHOLD SURVEY DATA: A GUIDE TO TECHNIQUES AND THEIR IMPLEMENTATION		*
*	OWEN O'DONNELL, EDDY VAN DOORSLAER, ADAM WAGSTAFF AND MAGNUS LINDELOW							*
*	WASHINGTON DC, WORLD BANK, 2007													*
*	www.worldbank.org/analyzinghealthequity 												*
*******************************************************************************************************************


*****************	CHAPTER 12	EXPLAINING DIFFERENCES BETWEEN GROUPS: OAXACA DECOMPOSITION		*******************



*****************************			PRELIMINARIES		*************************************************
version 9.2
clear
set more off
set matsize 800 			
set mem 100m

* This program calls on the ado "oaxaca" which does not come preinstalled in Stata.
* To install, use "findit oaxaca" and follow the leads.
* Note, in the AHE book we referred to a previous version of this ado "decompose" also written by Ben Jann of Zurich University.
* The main advantage of oaxaca.ado over decompose.ado is that the former computes standard errors for the contributions to the decomposition.
*******************************************************************************************************************


****************************		DATA PREPARATION		*******************************************************
* These commands are specific to the dataset used. 
* After renaming variables to be consistent with those used below, the remainder of the file should run with any dataset.

use AHE10, clear			/* data for the example are from the 1998 Vietnam Living Standards Survey */
drop if age>120				/* drop observations over 10 years old */

gen y=-haz/100 			/* variable of interest - in example is (height-for-age z-score) */
rename log_con x			/* rename living standards ranking variable */
gen exp=exp(x)
gen group=(exp<1790) 		/* dummy variable that identifies the groups to be compared. In example, is poverty status */

label variable y "height-for-age z-score)"
label variable x "(log) household consumption per capita"
label variable group "1 if poor"
label variable age "age of child in months"
label variable male "1 if child male"
label variable water_ok "1 household has safe supply of drinking water"
label variable loo_ok "1 household has satisfactory sanitation"
label variable educyr98 "years of schooling of household head"
label variable mumdip "1 if mum has any diploma"
lab var wt "sample weight"

global X "age male x water_ok loo_ok educyr98 mumdip" 	/* regressors */
global Z "i.group|age i.group|male i.group|x i.group|water_ok i.group|loo_ok i.group|educyr98 i.group|mumdip" 	/* interactions with group indicator to use in testing */


qui regress y $X group [pw=wt]	
drop if e(sample)~=1			/* drop observations missing on any variables will use */


* ***********************************************************************************************************


************************* TEST FOR DIFFERENCES IN REGRESSION COEFFICIENTS BETWEEN GROUPS ********************

xi: regr y group $Z [pw=wt]
testparm group _I*

********************	3-FOLD DECOMPOSITION - ENDOWMENTS, COEFFICIENTS & INTERACTIONS (Table 12.1 in book) ***********
regr y $X if group==0 [pw=wt]
estimates store group0
regr y $X if group==1 [pw=wt]
estimates store group1
oaxaca group0 group1 

* Alternatively can use this:
oaxaca2 y $X [pw=wt], by(group)

*******************	2-FOLD DECOMPOSITION WITH ALTERNATIVE WEIGHTING SCHEMES (Table 12.2 in book)	**************
qui sum group 
local fp=1-r(mean)
oaxaca group0 group1, weight(0 1 0.5 `fp' omega)

*******************	DETAILED DECOMPOSITION RESULTS FOR INDV REGRESSORS (Table 12.3 in book)	**************
oaxaca group0 group1, weight(0 1 0.5 `fp' omega) detail



log close


