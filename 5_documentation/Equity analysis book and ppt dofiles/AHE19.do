log using AHE19, replace

*******************************************************************************************************************
*	ANALYZING HEALTH EQUITY USING HOUSEHOLD SURVEY DATA: A GUIDE TO TECHNIQUES AND THEIR IMPLEMENTATION		*
*	OWEN O'DONNELL, EDDY VAN DOORSLAER, ADAM WAGSTAFF AND MAGNUS LINDELOW							*
*	WASHINGTON DC, WORLD BANK, 2007													*
*	www.worldbank.org/analyzinghealthequity 												*
*******************************************************************************************************************


******************************	CHAPTER 19	HEALTH CARE	PAYMENTS AND POVERTY	*******************************


*****************************			PRELIMINARIES		*************************************************
version 9.2
clear
set more off
set matsize 800 			
set mem 100m

* This do file calls on the ado file sepov s that is not automatically integrated in Stata and must be installed.
* findit sepov		/* follow leads to download the ado file */
*******************************************************************************************************************


****************************		DATA PREPARATION		*******************************************************
* These commands are specific to the dataset used. 
* After renaming variables to be consistent with those used below, the remainder of the file should run with any dataset.
* There are some axes labels for charts that are specific to the example. These should be obvious and can be changed at the appropriate points.

use VLSS_OOP.dta, clear		/* health payments data from 1997/8 Vietnam living standards survey */

rename commune psu
rename reg10o strata

gen pcoop=oop/hhsize		/* Per capita OOP health payments. Note: in the results reported in the Book Chapter, pcoop=(hhexp121*mcpinf*rcpinf)/hhsize) */
gen x=exp/hhsize			/* Living standards variable against which poverty is conventionally assessed. Note: in the results in Book, x=rlpcex2 from HHEXP98N */

gen wt=hhw*hhsize			/* scale sample weights by household size in order to estimate number of individuals in poverty from hhold level data */

label variable pcoop	"household out-of-pocket health payments per capita"
label variable x		"total household expenditure per capita"
label variable wt		"household frequency sampling weights - scaled by hhold size"
label variable psu 	"primary sampling unit in cluster sampling"
label variable strata 	"stratification identifier"


quietly regr x pcoop [pw=wt]
drop if e(sample)~=1					/* drop observations missing on any variable used in analysis */


svyset psu [pw=wt], strata(strata) || _n		/* set sample design parameters */


*** DEFINE THE POVERTY LINES 

gen PL1 = 941.77296			/* This is the Vietnamese Dong ('000) equivalent to $1.08 at PPP per day.  */
gen PL2 = 1883.5459			/* Vietnamese Dong equivalent to $2.15 at PPP per day */

***********************************************************************************************************


*** CREATE HOUSEHOLD LEVEL INDICATOR OF GROSS OF PAYMENT POVERTY AND POVERTY GAP AT DIFFERENT POVERTY LINES

gen gross_h1 = (x < PL1)			
gen gross_g1 = gross_h1*(PL1 - x)		
gen gross_ng1 = gross_g1/PL1			


*****************************************************************************************************
**************************************** EXERCISE 1 *************************************************

* Generate household level poverty indicator, gap and normalised gap for the $2 poverty line.

gen gross_h2 = (x < PL2)
gen gross_g2 = gross_h2*(PL2 - x)
gen gross_ng2 = gross_g2/PL2			

*****************************************************************************************************


*** CREATE HOUSEHOLD LEVEL INDICATOR OF POST-PAYMENT POVERTY AND POVERTY GAP AT DIFFERENT POVERTY LINES

gen net_x = x - pcoop		/* per capita household expenditure net of OOP payments */

gen net_h1 = (net_x < PL1)
gen net_g1 = net_h1*(PL1 - net_x)
gen net_ng1 = net_g1/PL1


*** GENERATE HOUSEHOLD LEVEL CHANGES IN POVERTY VARIABLES 

gen diff_h1 = net_h1 - gross_h1
gen diff_g1 = net_g1 - gross_g1
gen diff_ng1 = net_ng1 - gross_ng1

*** COMPUTE POPULATION ESTIMATES OF POVERTY HEADCOUNTS, GAPS AND POVERTY DIFFERENCES 

* RESULTS AT $1.08 PER DAY POVERTY LINE

svy: mean gross_h1 net_h1 diff_h1 gross_g1 net_g1 diff_g1 gross_ng1 net_ng1 diff_ng1 


********************************************************************************************
************************* EXERCISE 2 *******************************************************

* Compute poverty headcount, mean gap and mean normalised gap for the $2 poverty line

gen net_h2 = (net_x < PL2)
gen net_g2 = net_h2*(PL2 - net_x)
gen net_ng2 = net_g2/PL2

gen diff_h2 = net_h2 - gross_h2
gen diff_g2 = net_g2 - gross_g2
gen diff_ng2 = net_ng2 - gross_ng2


* RESULTS AT $2.15 PER DAY POVERTY LINE

svy: mean gross_h2 net_h2 diff_h2 gross_g2 net_g2 diff_g2 gross_ng2 net_ng2 diff_ng2 


********************************************************************************************


*** COMPUTE THE MEAN POSITIVE POVERTY GAP ie MEAN POVERTY GAP ACROSS THE POOR

svy, subpop(gross_h1): mean gross_g1 gross_ng1 		
svy, subpop(net_h1): mean net_g1 net_ng1 		

svy, subpop(gross_h2): mean gross_g2 gross_ng2 		
svy, subpop(net_h2): mean net_g2 net_ng2 		



*************************************************************************************************
*************************************************************************************************

*** THE ado FILE sepov CAN COMPUTE THE POVERTY HEADCOUNT AND NORMALISED GAP (PLUS OTHER POVERTY INDICES) AND THEIR STANDARD ERRORS.


sepov x [pw=wt], p(PL1) strata(strata) psu(psu) 

* P0 is the headcount and P1 the normalised gap (P2 is the square of the latter).

****************************************************************************************************

*****************************************************************************************************
************************************** EXERCISE 3 ***************************************************

* USE sepov TO COMPUTE POVERTY STATISTICS ON THE BASIS OF POST-OOP PAYMENT HOUSEHOLD EXPENDITURE.

******************************************************************************************************

log close




