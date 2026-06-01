log using AHE16, replace

*******************************************************************************************************************
*	ANALYZING HEALTH EQUITY USING HOUSEHOLD SURVEY DATA: A GUIDE TO TECHNIQUES AND THEIR IMPLEMENTATION		*
*	OWEN O'DONNELL, EDDY VAN DOORSLAER, ADAM WAGSTAFF AND MAGNUS LINDELOW							*
*	WASHINGTON DC, WORLD BANK, 2007													*
*	www.worldbank.org/analyzinghealthequity 												*
*******************************************************************************************************************


******************************	CHAPTER 16	PROGRESSIVITY OF HEALTH FINANCE	*******************************



*****************************			PRELIMINARIES		*************************************************
version 9.2
clear
set more off
set matsize 800 			
set mem 100m

* This do file calls on 3 ado files that are not automatically integrated in Stata and must be installed.
* The ado files are:
* 	1) glcurve - generalised Lorenz curve
*	2) locpoly - local polynomial regression
*	3) dominance - testing dominance of concentration and Lorenz curves

* If glcurve and locpoly are not already installed they can be downloaded from the Stata website using:
* 	findit glcurve (locpoly) 
* and following the the leads 

* dominance can be downloaded from www.worldbank.org/analyzinghealthequity 

*******************************************************************************************************************


****************************		DATA PREPARATION		*******************************************************
* These commands are specific to the dataset used. 
* After renaming variables to be consistent with those used below, most of the remainder of the file will run with any dataset.
* Some variable names, chart labels and macro financing weights have to be inputed manually below.


use EIHS_extract, clear			/* Household level dataset on payments toward health care from Egyptian Integrated Household Survey, 1997 */ 

rename exp y				/* ability to pay variable */
rename hhw wt				/* sample weight */
label variable y				"equivalent household prepayment expenditure (actual expenditure + dir + soc)"
label variable wt				"household frequency sampling weights"
label variable psu			"primary sampling unit"
label variable oop			"equivalent household out-of-pocket health payments"
label variable soc			"equivalent household social insurance contributions"
label variable dir			"equivalant household direct taxes (not earmarked)"
label variable pri			"equivalent household private insurance premia"
label variable ind			"equivalent household indirect taxes (not earmarked)"
label variable cig			"equivalent household cigarette taxes (earmarked)"
label variable psu			"primary sampling unit"

global X "dir ind cig soc pri oop"	/* health payments variables */
global Z1 "ind cig soc pri oop"	/* these globals will be used to loop through pairwise dominance tests */
global Z2 "cig soc pri oop"	
global Z3 "soc pri oop"	
global Z4 "pri oop"	
global Z5 "oop"	

qui regr y $X [pw=wt], cluster(psu)
drop if e(sample)~=1			/* drop observations missing on any variable to be used in analysis */

***********************************************************************************************************



******* GENERATE WEIGHTED FRACTIONAL RANK AND SCALARS USED TO COMPUTE CONCENTRATION INDICES	***********

egen raw_rank=rank(y), unique 		
sort raw_rank
qui sum wt
gen wi=wt/r(sum)
gen cusum=sum(wi)
gen wj=cusum[_n-1]
replace wj=0 if wj==.
gen rank=wj+0.5*wi				/* weighted fractional rank */
drop raw_rank wi cusum wj 

sum rank [aw=wt]
sca v_rank=r(Var)
sum y [aw=wt]
sca m_y=r(mean)


********************	MEAN SHARE OF OOP IN PREPAYMENT INCOME BY QUINTILE	*****************************

xtile quintile=y [pw=wt], nq(5)		/* quintiles of equivalent household expenditure */	
gen oopshare=100*(oop/y)				
graph bar (mean) oopshare [pw=wt], over(quintile) 	



************************	DISTRIBUTIONS OF EACH SOURCE OF HEALTH FINANCE	***********************************

********* CONCENTRATION CURVES, DOMINANCE TESTS, CUMULATIVE QUINTILE SHARES AND PROGRESSIVITY INDICES 

foreach x of global X {
	dominance `x' [aw=wt], sortvar(y) shares(quintiles)	
	qui regr `x' rank [pw=wt], cluster(psu)
	di "Concentration index for `x' "
	nlcom (2*v_rank)*(_b[rank]/(_b[_cons]+0.5*_b[rank]))
	qui sum `x' [aw=wt]
	sca m_`x'=r(mean)
	gen lhs=2*v_rank*(`x'/m_`x'-y/m_y)
	qui regr lhs rank [pw=wt], cluster(psu)
	drop lhs
	matrix coefs=get(_b)	
	matrix error=get(VCE)			
	gen k_`x'=coefs[1,1]			/* Kakwani index */
	gen sek_`x'=error[1,1]^0.5		/* robust SE of kakwani */
	if "`x'"=="dir" {
			matrix k=coefs[1,1]		
		}
		if "`x'"~="dir" {
			matrix k=(k, coefs[1,1]) 	/* vector with kakwani indices by source */
		}
	glcurve `x' [aw=wt], sortvar(y) glvar(`x'_cc) lorenz nograph replace
}

di "Kakwani indices by source"
local kakwani "k se"
foreach k of local kakwani {
	tabstat `k'* 	
}			


di "Gini index"
qui regr y rank [pw=wt], cluster(psu)
nlcom (2*v_rank)*(_b[rank]/(_b[_cons]+0.5*_b[rank]))


* The user must select and label the curves to be plotted here

glcurve y [aw=wt], lorenz plot(line dir_cc rank, legend(label(2 "direct tax")) || ///
				line ind_cc rank, legend(label(3 "indirect tax")) || ///
				line cig_cc rank, legend(label(4 "cigarette tax")) || ///
				line rank rank, legend(label(5 "45 degree line"))) ///
				l1(Cumulative proportion of payments / expenditure)
graph export Figure1.emf, replace

glcurve y [aw=wt], lorenz plot(line soc_cc rank, legend(label(2 "social insurance")) || ///
				line pri_cc rank, legend(label(3 "private insurance")) || ///
				line oop_cc rank, legend(label(4 "out-of-pocket")) || ///
				line rank rank, legend(label(5 "45 degree line"))) ///
				l1(Cumulative proportion of payments / expenditure)
graph export Figure2.emf, replace



*********************************************************************************************
************************* EXERCISE 1 ********************************************************


* Does any tax concentration curve dominate the Lorenz curve?
* What, if anything, do you conclude about the progressivity of these taxes?

* Does the OOP, social or private insurance concentration curve dominate the Lorenz curve?
* What, if anything, do you conclude about the progressivity of these payments? 

* Which sources of payment are significantly progressive or regressive?


**********************************************************************************************

******************** TESTS OF DOMINANCE BETWEEN FINANCE SOURCES ********************
local i=1
foreach x of global X {
	foreach z of global Z`i' {
		dominance `x' `z' [aw=wt], sortvar(y) 
	}
	local ++i
}



****************************************************************************************
**********	PROGRESSIVITY OF HEALTH FINANCING SYSTEM IN AGGREGATE	**********


matrix maw=(0.0469, 0.2829, 0.0300, 0.0667, 0.0557, 0.5177)		/* get macroweights from NHA */
matrix colnames maw = dir ind cig soc pri oop				/* give names. This has to be done manually. Do not change order. */
matrix k1=maw*k'
matrix list maw									/* financing mix */
matrix list k1									/* Kakwani index for health finance system in total */


**********************************************************************************************
***************************** EXERCISE 2 *****************************************************

* Consider the revised set of macro weights :
* Direct tax = 0.0108
* Indirect tax = 0.0649
* Cigarette tax = 0.0425
* Social insurance = 0.0919
* Private insurance = 0.0768
* OOP = 0.7132

* Recompute the Kakwani for total health finance using these revised weights.


matrix maw=(0.0108, 0.0649, 0.0425, 0.0919, 0.0768, 0.7132)		/* macroweights (Case 3) */
matrix colnames maw = dir ind cig soc pri oop				/* give names - do not change order ! */
matrix k1=maw*k'
matrix list maw									/* show financing mix */
matrix list k1									/* show overall kakwani */


************************************************************************************************

log close
