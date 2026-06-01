log using AHE15, replace

*******************************************************************************************************************
*	ANALYZING HEALTH EQUITY USING HOUSEHOLD SURVEY DATA: A GUIDE TO TECHNIQUES AND THEIR IMPLEMENTATION		*
*	OWEN O'DONNELL, EDDY VAN DOORSLAER, ADAM WAGSTAFF AND MAGNUS LINDELOW							*
*	WASHINGTON DC, WORLD BANK, 2007													*
*	www.worldbank.org/analyzinghealthequity 												*
*******************************************************************************************************************


***************	CHAPTER 15	MEASURING AND EXPLAINING INEQUITY IN HEALTH SERVICE DELIVERY	*******************



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

use jslc.dta, clear

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


rename dprevis y 		/* variable of interest - dummy indicating any visit for preventive health care */
gen x = ln(exp)		/* living standards ranking variable - log of hhold expenditure per equivalent adult */	

*** DEFINE NEED STANDARDISATION VARIABLES
global X "mage2 mage3 mage4 mage5 fage1 fage2 fage3 fage4 fage5 dvgood dgood dfair dpoor dfl1 dfl2 dfl3 dfl4 dfl5 dfl6"
global agesex "mage2 mage3 mage4 mage5 fage1 fage2 fage3 fage4 fage5"
global health "dvgood dgood dfair dpoor"
global functions "dfl1 dfl2 dfl3 dfl4 dfl5 dfl6"

*** NON-NEED CONTROL VARIABLES
global Z "x insured" 

quietly regress y $X $Z		
drop if e(sample)~=1			/* drop observations missing on any variables used */

* Note that there are no weights in the dataset being used for the example. Code nees to be adapted to include weights where exist.

********************************************************************************************************


*********************************************************************************************************
*******	DISTRIBUTIONS OF ACTUAL, NEED-PREDICTED AND NEED-STANDARDISED UTILISATION		*********

xtile quintile = x, nq(5)	// quintiles of living standards variable	
egen m_y = mean(y)		// mean of variable of interest	


****************** UNSTANDARDISED CONCENTRATION INDEX	

sort x, stable
gen rj=(_n-1)/_N
gen r=rj+0.5/_N				/* fractional rank for case with no weights */
quietly sum r 
sca var_r = r(Var)			

egen rank = rank(x), unique		
tsset rank
newey y r, lag(1)
nlcom 2*var_r*(_b[r]/(_b[_cons]+0.5*_b[r]))			
mat coef=r(b)
mat var=r(V)
sca CI1=coef[1,1]			
sca se1=sqrt(var[1,1])
sca t1=CI1/se1



**********************	INDIRECT STANDARDISATION USING OLS		

*** WITHOUT CONTROLLING FOR NON-NEED FACTORS IN ESTIMATION OF THE "NEED" EFFECTS

qui reg y $X				
predict yhat_1				
gen yst1 = y-yhat_1 + m_y		

newey yst1 r, lag(1)
nlcom 2*var_r*(_b[r]/(_b[_cons]+0.5*_b[r]))			
mat coef=r(b)
mat var=r(V)
sca CI2=coef[1,1]			
sca se2=sqrt(var[1,1])
sca t2=CI2/se2

gen ydiff1 = y - yhat_1
di "Quintle means of actual, need-predicted, actual-predicted and standardised utilisation"
tabstat y yhat_1 ydiff1 yst1, by(quintile) stats(mean)
graph bar (mean) y yhat_1 yst1, over(quintile) legend(on order(1 "actual" 2 "predicted" 3 "standardised"))

display "unstandardised CI:", CI1, "stand. error", se1, "t-ratio:", t1 
di "standardised CI (w/o control for non-need factors):", CI2, "stand. error", se2 "t-ratio:", t2 


*** CONTROLLING FOR NON-NEED FACTORS IN ESTIMATION OF THE AGE-SEX, HEALTH EFFECTS

qui reg y $X $Z					
foreach z of global Z {
	egen m_`z' = mean(`z')
	gen copy_`z' = `z' 				 
	replace `z' = m_`z'
}
predict yhat_2 					
foreach z of global Z {		
	replace `z' = copy_`z'
}

gen yst2 = y - yhat_2 + m_y			
newey yst2 r, lag(1)
nlcom 2*var_r*(_b[r]/(_b[_cons]+0.5*_b[r]))			
mat coef=r(b)
mat var=r(V)
sca CI3=coef[1,1]			
sca se3=sqrt(var[1,1])
sca t3=CI3/se3

gen ydiff2 = y - yhat_2
di "Quintle means of actual, need-predicted, actual-predicted and standardised utilisation"
tabstat y yhat_2 ydiff2 yst2, by(quintile) stats(mean)
graph bar (mean) y yhat_2 yst2, over(quintile) legend(on order(1 "actual" 2 "predicted" 3 "standardised"))
display "unstandardised CI:", CI1, "t-ratio:", t1 
di "standardised CI (with control for non-need factors):", CI3, "stand. error", se3 "t-ration:", t3 


*** COMPARE UNSTANDARDISED, STANDARDISED MEANS W/O AND WITH CONTROLS 
tabstat y yst1 yst2, by(quintile) stats(mean)



***************************	INDIRECT STANDARDISATION USING PROBIT	

drop yhat_* ydiff*


*** WITHOUT CONTROLLING FOR NON-NEED FACTORS

qui probit y $X				
predict yhat			
egen m_yh = mean(yhat)
gen ystp = y-yhat + m_yh	

qui newey yhat r, lag(1)
nlcom 2*var_r*(_b[r]/(_b[_cons]+0.5*_b[r]))			
mat coef=r(b)
mat var=r(V)
sca CI4=coef[1,1]				/* concentration index for need-predicted use */	
sca se4=sqrt(var[1,1])
sca t4=CI4/se4

qui newey ystp r, lag(1)
nlcom 2*var_r*(_b[r]/(_b[_cons]+0.5*_b[r]))			
mat coef=r(b)
mat var=r(V)
sca CI5=coef[1,1]				/* concentration index for need-standardised use */	
sca se5=sqrt(var[1,1])
sca t5=CI5/se5

gen ydiff = y - yhat
di "Quintle means of actual, need-predicted, actual-predicted and standardised utilisation"
tabstat y yhat ydiff ystp, by(quintile) stats(mean)
graph bar (mean) y yhat ystp, over(quintile) legend(on order(1 "actual" 2 "predicted" 3 "standardised"))

display "unstandardised CI:", CI1, "stand. error", se1, "t-ratio:", t1 
di "need predicted CI:", CI4, "stand. error", se4 "t-ratio:", t4 
di "need standardised CI:", CI5, "stand. error", se5 "t-ratio:", t5 


*** COMPARE UNSTANDARDISED AND STANDARDISED MEANS by OLS AND PROBIT  
tabstat y yst1 ystp, by(quintile) stats(mean)


*** WITH CONTROL FOR NON-NEED FACTORS

qui probit y $X $Z
foreach z of global Z {
	replace `z' = m_`z'
}
predict yhat_2 					
foreach z of global Z {		
	replace `z' = copy_`z'
}

egen m_yh2 = mean(yhat_2)
gen ystp2 = y-yhat_2 + m_yh2	

qui newey yhat_2 r, lag(1)
nlcom 2*var_r*(_b[r]/(_b[_cons]+0.5*_b[r]))			
mat coef=r(b)
mat var=r(V)
sca CI6=coef[1,1]				/* concentration index for need-predicted use */	
sca se6=sqrt(var[1,1])
sca t6=CI6/se6

qui newey ystp2 r, lag(1)
nlcom 2*var_r*(_b[r]/(_b[_cons]+0.5*_b[r]))			
mat coef=r(b)
mat var=r(V)
sca CI7=coef[1,1]				/* concentration index for need-standardised use */	
sca se7=sqrt(var[1,1])
sca t7=CI7/se7


gen ydiff2 = y - yhat_2

di "Quintle means of actual, need-predicted, actual-predicted and standardised utilisation"
tabstat y yhat_2 ydiff2 ystp2, by(quintile) stats(mean)
graph bar (mean) y yhat_2 ystp2, over(quintile) legend(on order(1 "actual" 2 "predicted" 3 "standardised"))

display "unstandardised CI:", CI1, "stand. error", se1, "t-ratio:", t1 
di "need predicted CI:", CI6, "stand. error", se6 "t-ratio:", t6 
di "need standardised CI:", CI7, "stand. error", se7 "t-ratio:", t7 


*** COMPARE UNSTANDARDISED AND STANDARDISED MEANS by OLS AND PROBIT  

tabstat y yst2 ystp2, by(quintile) stats(mean)



*********************************************************************************************************************

********************************	DECOMPOSITION OF INEQUALITY IN UTILISATION 	*********************************


********* DECOMPOSITION USING OLS 

qui regr y $X $Z 

* CONTRIBUTIONS OF NEED FACTORS

sca need=0
foreach x of global X {
	qui {
		sca b_`x' = _b[`x']				/* beta coeff. of x  */
		corr r `x', c
		sca cov_`x' = r(cov_12)				/* covariance b/w x and expenditure rank */
		sum `x' 
		sca m_`x' = r(mean)				/* mean of x */
		sca elas_`x' = (b_`x'*m_`x')/m_y		/* elasticity of y with respect to x */
		sca CI_`x' = 2*cov_`x'/m_`x'			/* concentration index for x in relation to expenditure */  
		sca con_`x' = elas_`x'*CI_`x'			/* contribution of x to CI for y in relation to household expenditure */
		sca prcnt_`x' = con_`x'/CI1			/* percentage of CI for y accounted for by x */
		sca need=need+con_`x'				/* contribution of all need factors */
	}
	di "`x' elasticity:", elas_`x'
	di "`x' concentration index:", CI_`x'
	di "`x' contribution:", con_`x'
	di "`x' percentage contribution:", prcnt_`x'
}

* SPLIT NEED CONTRIBUTION INTO AGE/SEX AND HEALTH 

sca agesex=0
foreach x of global agesex {
	sca agesex=agesex+con_`x'
}
di "age-sex contribution:"	agesex
di "percentage contribution of age-sex factors", agesex/CI1

sca health=0
foreach x of global health {
	sca health=health+con_`x'
}
di "self-assessed health contribution:"	health
di "percentage contribution of self assessed health", health/CI1

sca functions=0
foreach x of global functions {
	sca functions=functions+con_`x'
}
di "functional limitations contribution:"	functions
di "percentage contribution of functional limitations", functions/CI1


* CONTRIBUTIONS OF NON-NEED FACTORS

sca nonneed=0
foreach x of global Z {
	qui {
		sca b_`x' = _b[`x']				/* beta coeff. of x  */
		corr r `x', c
		sca cov_`x' = r(cov_12)				/* covariance b/w x and expenditure rank */
		sum `x' 
		sca m_`x' = r(mean)				/* mean of x */
		sca elas_`x' = (b_`x'*m_`x')/m_y		/* elasticity of y with respect to x */
		sca CI_`x' = 2*cov_`x'/m_`x'			/* concentration index for x in relation to expenditure */  
		sca con_`x' = elas_`x'*CI_`x'			/* contribution of x to CI for y in relation to household expenditure */
		sca prcnt_`x' = con_`x'/CI1			/* percentage of CI for y accounted for by x */
		sca nonneed=nonneed+con_`x'
	}
	di "`x' elasticity:", elas_`x'
	di "`x' concentration index:", CI_`x'
	di "`x' contribution:", con_`x'
	di "`x' percentage contribution:", prcnt_`x'
}

di "Inequality due to need factors:", need 
di "Inequality due to non-need factors:", nonneed
sca HI = CI1 - need
di "Horizontal Inequity Index:", HI




************* DECOMPOSITION USING PROBIT 

qui dprobit y $X $Z 
mat dfdx=e(dfdx)

* CONTRIBUTIONS OF NEED FACTORS

sca need=0
foreach x of global X {
	qui {
		mat b_`x' = dfdx[1,"`x'"]			/* partial effect of x */
		sca b_`x' = b_`x'[1,1]
		corr r `x', c
		sca cov_`x' = r(cov_12)				/* covariance b/w x and expenditure rank */
		sum `x' 
		sca m_`x' = r(mean)				/* mean of x */
		sca elas_`x' = (b_`x'*m_`x')/m_y		/* elasticity of y with respect to x */
		sca CI_`x' = 2*cov_`x'/m_`x'			/* concentration index for x in relation to expenditure */  
		sca con_`x' = elas_`x'*CI_`x'			/* contribution of x to CI for y in relation to household expenditure */
		sca prcnt_`x' = con_`x'/CI1			/* percentage of CI for y accounted for by x */
		sca need=need+con_`x'				/* contribution of all need factors */
	}
	di "`x' elasticity:", elas_`x'
	di "`x' concentration index:", CI_`x'
	di "`x' contribution:", con_`x'
	di "`x' percentage contribution:", prcnt_`x'
}


* SPLIT NEED CONTRIBUTION INTO AGE/SEX AND HEALTH 

sca agesex=0
foreach x of global agesex {
	sca agesex=agesex+con_`x'
}
di "age-sex contribution:"	agesex
di "percentage contribution of age-sex factors", agesex/CI1

sca health=0
foreach x of global health {
	sca health=health+con_`x'
}
di "self-assessed health contribution:"	health
di "percentage contribution of self assessed health", health/CI1

sca functions=0
foreach x of global functions {
	sca functions=functions+con_`x'
}
di "functional limitations contribution:"	functions
di "percentage contribution of functional limitations", functions/CI1


* CONTRIBUTIONS OF NON-NEED FACTORS

sca nonneed=0
foreach x of global Z {
	qui {
		mat b_`x' = dfdx[1,"`x'"]
		sca b_`x' = b_`x'[1,1]	
		corr r `x', c
		sca cov_`x' = r(cov_12)				
		sum `x' 
		sca m_`x' = r(mean)				
		sca elas_`x' = (b_`x'*m_`x')/m_y
		sca CI_`x' = 2*cov_`x'/m_`x'			  
		sca con_`x' = elas_`x'*CI_`x'			
		sca prcnt_`x' = con_`x'/CI1			
		sca nonneed=nonneed+con_`x'
	}
	di "`x' elasticity:", elas_`x'
	di "`x' concentration index:", CI_`x'
	di "`x' contribution:", con_`x'
	di "`x' percentage contribution:", prcnt_`x'
}

di "Inequality due to need factors:", need 
di "Inequality due to non-need factors:", nonneed
sca HI = CI1 - need
di "Horizontal Inequity Index:", HI




log close

