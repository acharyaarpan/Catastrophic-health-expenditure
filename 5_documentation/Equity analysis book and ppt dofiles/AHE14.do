* log using AHE14, replace

*******************************************************************************************************************
*	ANALYZING HEALTH EQUITY USING HOUSEHOLD SURVEY DATA: A GUIDE TO TECHNIQUES AND THEIR IMPLEMENTATION		*
*	OWEN O'DONNELL, EDDY VAN DOORSLAER, ADAM WAGSTAFF AND MAGNUS LINDELOW							*
*	WASHINGTON DC, WORLD BANK, 2007													*
*	www.worldbank.org/analyzinghealthequity 												*

*******************************************************************************************************************

******************************	CHAPTER 14	BENEFIT INCIDENCE ANALYSIS	*************************************


***************************************		 PRELIMINARIES		*******************************************
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

********************************************************************************************************************


************************************************	PREPARE THE DATA	********************************************
* These commands are specific to the dataset used. 
* After renaming variables to be consistent with those used below, the remainder of the file should run with any dataset.

use vlss_subsidy_98, clear	/* load dataset. Example: Individual level dataset on public health subsidy from Vietnam Living Standards Survey, 1997/98 */ 

rename hhexp_eq y		/* rename living standards ranking variable (total household consumption per equivalent adult in example) to label used below */

rename s3q12 cmhc
rename s3q16 poly
gen other=oth_pub-poly
gen othersub_1=othsub_1+homesub
renam cluster psu

* define globals for the variables representing each type of health service utilisation and the respective subsidies
global use "inpatient outpatient cmhc poly other"
global subsidy "ipsub_1 opsub_1 cmhcsub_1 polysub_1 othersub_1 totsub_1 totsub"

qui regr y $use $subsidy [pw=wt], cluster(psu)
drop if e(sample)!=1

***************************************************************************************************************************


*********** Generate weighted fractional rank

egen 	rank1 = rank(y), unique 		
sort rank1
qui sum wt
gen wi=wt/r(sum)
gen cusum=sum(wi)
gen wj=cusum[_n-1]
replace wj=0 if wj==.
gen r=wj+0.5*wi

qui sum r [aw=wt]
sca v_rank=r(Var)
qui sum y [aw=wt]
sca m_y=r(mean)


*********** UTILISATION ANALYSIS

* Run dominance tests and compute quintile shares and concentration indices for utilization

foreach x of global use {
	dominance `x' [aw=wt], sortvar(y) shares(quintiles)	
	qui regr `x' r [pw=wt], cluster(psu)
	di "Concentration index for `x' "
	nlcom (2*v_rank)*(_b[r]/(_b[_cons]+0.5*_b[r]))
}


*********** SUSBDIY ANALYSIS

* Does everything done for utilisation plus produces the Kakwani index and the co-ordinates of the concentration curves for plotting below

foreach x of global subsidy {
	dominance `x' [aw=wt], sortvar(y) shares(quintiles)	
	qui regr `x' r [pw=wt], cluster(psu)
	di "Concenration index for `x' "
	nlcom (2*v_rank)*(_b[r]/(_b[_cons]+0.5*_b[r]))
	di "Kakwani index for `x' "
	qui sum `x' [aw=wt]
	sca m_`x'=r(mean)
	gen lhs=2*v_rank*(`x'/m_`x'-y/m_y)
	regr lhs r [pw=wt], cluster(psu)
	drop lhs
	glcurve `x' [aw=wt], sortvar(y) glvar(`x'cc) pvar(rank) lorenz nograph replace
}


di "Gini index"
qui regr y r [pw=wt], cluster(psu)
nlcom (2*v_rank)*(_b[r]/(_b[_cons]+0.5*_b[r]))



* Plot the subsidy concentration curves against the Lorenz curve
* The user must choose the curves that are to be plotted and change the labels below accordingly

glcurve y [aw=wt], lorenz plot(line ipsub_1cc rank, legend(label(2 "inpatient")) || ///
				line opsub_1cc rank, legend(label(3 "outpatient")) || ///
				line cmhcsub_1cc rank, legend(label(4 "health centre")) || ///
				line totsub_1cc rank, legend(label(5 "total subsidy")) || ///
				line rank rank, legend(label(6 "45 degree line"))) ///
				l1(Cumulative proportion of subsidy / consumption)
graph export Figure.emf, replace

log close




