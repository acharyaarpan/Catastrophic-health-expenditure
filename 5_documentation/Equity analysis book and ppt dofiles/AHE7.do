log using AHE7, replace

*******************************************************************************************************************
*	ANALYZING HEALTH EQUITY USING HOUSEHOLD SURVEY DATA: A GUIDE TO TECHNIQUES AND THEIR IMPLEMENTATION		*
*	OWEN O'DONNELL, EDDY VAN DOORSLAER, ADAM WAGSTAFF AND MAGNUS LINDELOW							*
*	WASHINGTON DC, WORLD BANK, 2007													*
*	www.worldbank.org/analyzinghealthequity 												*
*******************************************************************************************************************


******************************	CHAPTER 7	CONCENTRATION CURVES		*************************************



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
* After renaming variables to be consistent with those used below, the remainder of the file should run with any dataset.
* There are some axes labels for charts that are specific to the example. These should be obvious and can be changed at the appropriate points.

use vlss_haz_93_98, clear	/* load data set */

rename neghaz y			/* rename the variable of interest (here the negative of height-for-age z-score) to the name used in program below - y */
gen x=exp(lnpcexp)		/* generating the living standards (per capita hhold consumption) variable from its log and giving name used below - x */
* ren weight wt			/* rename sample weight variable to that used below - wt (already named wt in the example dataset */
ren year z				/* if concentration curves are to be drawn for different years (as in example), countries, etc, then rename the variable to be used to split analysis - z */

qui regr y x z [pw=wt]		
drop if e(sample)!=1		/* drop observations with missings on any variable to be used in analysis */

******************************************************************************************************************


*******************************************************************************************************************
******************************* 	GRAPHING CONCENTRATION CURVES		 ******************************************

*************	FIGURE 7.2: CONCENTRATION CURVES FOR CHILD MALNUTRITION IN VIETNAM 1992/3 & 1997/8	*************

**** WITHOUT APPLICATION OF SAMPLE WEIGHTS (as in book)

** PRELIMINARY CONCENTRATION CURVES WITHOUT LABELLING AND COLOUR

glcurve y, glvar(yord) pvar(rank) sortvar(x) replace by(z) split lorenz


/* THE CO-ORDINATES OF THE CONCENTRATION CURVES COULD ALTERNATIVELY BE GENERATED WITHOUT USING THE ADO glcurve BY THE FOLLOWING SERIES OF COMMANDS:

sort z x 
qui tab z, gen(temp)
forval i = 0/1 {				
	sum y if temp2==`i'
	scalar nobs`i' = r(N)
}
gen rank=.
egen tmp = rank(x) if temp2==0
replace rank=tmp/nobs0 if temp2==0
drop tmp
egen tmp = rank(x) if temp2==1
replace rank=tmp/nobs1 if temp2==1

forval i = 0/1 {
	sum y if temp2==`i'
	scalar s_malnut`i' = r(sum)
}
gen yord_0 = sum(y)/s_malnut0 if temp2==0
gen yord_1 = sum(y)/s_malnut1 if temp2==1
drop temp1 temp2 tmp
*/


** GRAPHING THE CONCENTRATION CURVES USING THE FULL RANGE OF OPTIONS AVAILABLE WITH TWOWAY

ge rank2=rank
label variable yord_0 "conc curve 92/93"			/* change these labels to suit application */
lab var yord_1 "conc curve 97/98"
lab var rank "cumul share of children (poorest first)"
lab var rank2 "line of equality"

twoway (line yord_0 rank , sort clwidth(medthin) clpat(solid) clcolor(orange)) ///
	(line yord_1 rank, sort clwidth(medthin) clpat(longdash) clcolor("153 204 0")) ///
	(line rank2 rank , sort clwidth(medthin) clcolor(gray)) ///
	, ytitle(cumulative share of malnutrition, size(medsmall)) ///
	yscale(titlegap(5))  xtitle(, size(medsmall)) legend(rows(5)) xscale(titlegap(5)) ///
	legend(region(lwidth(none))) plotregion(margin(zero)) ysize(5.75) xsize(5) plotregion(lcolor(none))
	graph export "cc curves 1992 and 1997.emf" , replace
drop rank2



**** 	NOW WITH APPLICATION OF SAMPLE WEIGHTS

glcurve y [aw=wt], glvar(yord) pvar(rank) sortvar(x) replace by(z) split lorenz nograph

ge rank2=rank
lab var yord_0 "conc curve 92/93"
lab var yord_1 "conc curve 97/98"
lab var rank "cumul share of children (poorest first)"
lab var rank2 "line of equality"
twoway (line yord_0 rank , sort clwidth(medthin) clpat(solid) clcolor(orange)) ///
	(line yord_1 rank, sort clwidth(medthin) clpat(longdash) clcolor("153 204 0")) ///
	(line rank2 rank , sort clwidth(medthin) clcolor(gray)) ///
	, ytitle(cumulative share of malnutrition, size(medsmall)) ///
	yscale(titlegap(5))  xtitle(, size(medsmall)) legend(rows(5)) xscale(titlegap(5)) ///
	legend(region(lwidth(none))) plotregion(margin(zero)) ysize(5.75) xsize(5) plotregion(lcolor(none))
	graph export "cc curves 1992 and 1997.emf" , replace


**************************************************************************************************************************************


**************************************************************************************************************************************
/* ***************************** 			EXERCISE 1 			**************************************************************

* GRAPH THE Lorenz CURVE (ie, HOUSEHOLD CONSUMPTION/EXP/INCOME SHARES AGAINST POPULATION RANKED BY CONSUMPTION/EXP/INCOME) IN EACH YEAR

glcurve x [aw=wt], glvar(Lorenz) replace lorenz by(z) split
lab var Lorenz_0 "Lorenz 92/93"
lab var Lorenz_1 "Lorenz 97/98"			   
twoway (line Lorenz_0 rank , sort clwidth(medthin) clpat(solid) clcolor(orange)) ///
	(line Lorenz_1 rank, sort clwidth(medthin) clpat(longdash) clcolor("153 204 0")) ///
	(line rank2 rank , sort clwidth(medthin) clcolor(gray)) ///
	, ytitle(cumulative share of per capita consumption, size(medsmall)) ///
	yscale(titlegap(5))  xtitle(, size(medsmall)) legend(rows(5)) xscale(titlegap(5)) ///
	legend(region(lwidth(none))) plotregion(margin(zero)) ysize(5.75) xsize(5) plotregion(lcolor(none))
	graph export "Lorenz curves 1992 and 1997.emf" , replace


* FOR 1997/98, GRAPH THE Lorenz CURVE AND THE CONCENTRATION CURVE FOR MALNUTRITION ON THE SAME GRAPH

twoway (line yord_0 rank , sort clwidth(medthin) clpat(solid) clcolor(orange)) ///
	(line Lorenz_1 rank, sort clwidth(medthin) clpat(longdash) clcolor("153 204 0")) ///
	(line rank2 rank , sort clwidth(medthin) clcolor(gray)) ///
	, ytitle(cumulative share of consumption/malnutrition, size(medsmall)) ///
	yscale(titlegap(5))  xtitle(, size(medsmall)) legend(rows(5)) xscale(titlegap(5)) ///
	legend(region(lwidth(none))) plotregion(margin(zero)) ysize(5.75) xsize(5) plotregion(lcolor(none))
	graph export "Lorenz & conc curves 1997.emf" , replace
*/

***************************************************************************************************************


***************	QUINTILE TABLE AND BAR GRAPHS OF MEAN OF VARIABLE OF INTEREST	***************************
**** 					[NOTE: THIS IS NOT IN THE CHAPTER]					

xtile quintile = x [pw=wt], nq(5)				/* (weighted) quintile groups by living standards measure */
tabstat y [aw=wt], by(quintile) stats(mean)		/* mean of variable of interest by quintile */
graph bar (mean) y [aw=wt], over(quintile)	


/*
*********************************** EXERCISE 2 *************************************************************** 

* COMPUTE TABLE OF MEANS OF VARIABLE OF INTEREST BY DECILES OF LIVING STANDARDS MEASURE AND GRAPH THESE

xtile decile = x [pw=wt], nq(10)
tabstat y [aw=wt], by(decile) stats(mean)
graph bar (mean) y [aw=wt], over(decile)	
*/

****************************************************************************************************************


****************************************************************************************************************
***********************************		DOMINANCE TESTING 	**********************************************

* FOR DOMINANCE TETSING WE USE THE ADO dominance (download from website given above) 

* Syntax: varlist [if] [in] [fw aw] [using filename, SOrtvar(svar) [Points(integer 19) Level(integer 5) Rule(string) SHares(string) LABels(string)]


********************** DOMINANCE OF CONCENTRATION CURVE AGAINST 45 DEGREE LINE (AND LORENZ CURVE - NOT RELEVANT IN THIS EXAMPLE)

dominance y [aw=wt], sortvar(x) 

********************** DOMINANCE BETWEEN TWO INDEPENDENT CONCENTRATION CURVES	
**** EXAMPLE: DOMINANCE BETWEEN 1993 AND 1998 CONCENTRATION CURVES FOR HAZ SCORES OF KIDS IN VIETNAM

qui tab z, gen(temp)
preserve
keep if temp2==1
save data2, replace
restore
keep if temp2==0
dominance y using data2, sortvar(x) labels(1993 1997) rule(both)
drop temp1 temp2

****************************************************************************************************************

****************************************************************************************************************
*******************************	MORE EXAMPLES OF DOMINANCE TESTING		**********************************

****************************		DATA PREPARATION		*******************************************************

use IndiaNSS95, clear		/* load data set */

rename totsub y			/* rename the variable of interest (here public health care subsidy) to the name used in program below - y */
ren ipsub y1			/* rename second vbl of interest (here public subsidy for inpatient care) to y1 */
ren nonhsub y2			/* rename third vbl of interest (here public subsidy for non-hospital care) to y2 */
ren hhexp_eq x			/* rename living standards variable (hhold consumption per equivalent adult) to name used below - x */
* ren weight wt			/* rename sample weight variable to that used below - wt (already named wt in the example dataset) */

qui regr y x [pw=wt]		
drop if e(sample)!=1		/* drop observations with missings on any variable to be used in analysis */

tempfile India
save `India'

use vlss_subsidy_98, clear	/* load 2nd data set */
rename totsub y			
ren hhexp_eq x			
qui regr y x [pw=wt]		
drop if e(sample)!=1		
tempfile vnm
save `vnm'

* some chart labels below need changing
********************************************************************************************************************


************************* TEST DOMINANCE OF CONCENTRATION CURVE AGAINST LORENZ CURVE AND 45 DEGREE LINE

***** EXAMPLE: DOMINANCE OF CONCENTRATION CURVE OF TOTAL PUBLIC HEALTH SUBSIDY IN INDIA AGAINST THE LORENZ CURVE AND THE 45 DEGREE LINE
use `India', clear

dominance y [aw=wt], sortvar(x) 


/* To produce cummulative quintile (decile) shares of the variable of interest and the ranking variable,
	test difference of each from population shares and test difference b/w them: */

dominance y [aw=wt], sortvar(x) shares(quintiles)

 
/* The default compares ordinates of curves at 19 evenly spaced quantiles and rejects the null if there is at least one significant difference
	in one direction and no significant difference in the other with critical values corrected for multiple comparisons. 
	Default significance level is 5%.

	Options allow you to change: 1) the decision rule 2) the number of comparison points 3) the level of significance

	The default decision rule is consistent with the "multiple comparison approach" (mca). 
	You can change the decision rule to one requiring significant difference at all chosen quantiles, 
	which is consistent with the "intersection union principle" (iup).
	The required option is rule(iup)*/

dominance y [aw=wt], sortvar(x) rule(iup)


* To change the number of quantile points at which comparisons are made - 20 is the maximum

dominance y [aw=wt], sortvar(x) points(9)


* To change the level of significance to 1% (the only alternative)

dominance y [aw=wt], sortvar(x) level(1)


***************************	TEST DOMINANCE BETWEEN TWO INTERDEPENDENT CONCENTRATION CURVES	

************	EXAMPLE: DOMINANCE OF CONCENTRATION CURVE FOR SUBSIDY TO NON-HOSPITAL CARE AGAINST THAT FOR SUBSIDY TO INPATIENT CARE IN INDIA

glcurve y2 [aw=wt], sortvar(x) lorenz pvar(rank) glvar(y2ord) replace nograph
glcurve y1 [aw=wt], sortvar(x) lorenz plot(line y2ord rank, legend(label(2 "non-hospital")) || /// 
	line rank rank, legend(label(3 "45 degree"))) legend(label(1 "inpatient")) l1(Cumulative subsidy proportion)

dominance y2 y1 [aw=wt], sortvar(x)


**********************	 TEST DOMINANCE BETWEEN TWO INDEPENDENT CONCENTRATION CURVES	

*********** 	EXAMPLE: DOMINANCE OF CONCENTRATION CURVES OF PUBLIC HEALTH SUBSIDY IN INDIA AND VIETNAM

dominance y [aw=wt] using `vnm', sortvar(x) labels(India Vietnam)
 

log close

