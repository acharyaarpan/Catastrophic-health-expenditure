capture log close
log using table3, replace

set matsize 2000

*****************************************************************************
***							Analytical Bounds 							  ***
*****************************************************************************

clear matrix
forvalues s = 1/1000 {

* display `s' 

clear
qui set obs 10000

local mu     = 2 
local sigma  = 0.5

tempvar prob 
gen `prob' = runiform()
qui gen income = exp(`mu'+`sigma'*invnorm(`prob'))

_pctile income, p(10, 20, 30, 40, 50, 60)

scalar k_10  = r(r1)
scalar k_20 = r(r2)
scalar k_30 = r(r3)
scalar k_40 = r(r4)
scalar k_50 = r(r5)
scalar k_60 = r(r6)

local threshold "10 20 30 40 50 60"
foreach i of local threshold {

qui drop if income < k_`i'

local thres = k_`i'
local pct   = `i'/100

qui survbound income, thres(`thres') censorpct(`pct')

scalar lower_`i'  = round(r(lower_a), 0.0001)
scalar upper_`i'  = round(r(upper_a), 0.0001)
scalar length_`i' = upper_`i' - lower_`i'

}

matrix lower  = (nullmat(lower) \ lower_10, lower_20, lower_30, lower_40, lower_50, lower_60)
matrix upper  = (nullmat(upper) \ upper_10, upper_20, upper_30, upper_40, upper_50, upper_60)
matrix length = (nullmat(length) \ length_10, length_20, length_30, length_40, length_50, length_60)

}

mata : st_matrix("avg_lower", colsum(st_matrix("lower")))
mata : st_matrix("avg_upper", colsum(st_matrix("upper")))
mata : st_matrix("avg_length", colsum(st_matrix("length")))
mat avg_lower = avg_lower/1000
mat avg_upper = avg_upper/1000
mat avg_length = avg_length/1000

mat table = avg_lower \ avg_upper \ avg_length
mat table = table'
matrix rownames table = 0.10 0.20 0.30 0.40 0.50 0.60
matrix colnames table = Lower Upper Length
matlist table


*****************************************************************************
***							Grid-Search Bounds 							  ***
*****************************************************************************

clear matrix
forvalues s = 1/1000 {

display `s' 

clear
qui set obs 10000

local mu     = 2 
local sigma  = 0.5

tempvar prob 
gen `prob' = runiform()
qui gen income = exp(`mu'+`sigma'*invnorm(`prob'))

_pctile income, p(10, 20, 30, 40, 50, 60)

scalar k_10  = r(r1)
scalar k_20 = r(r2)
scalar k_30 = r(r3)
scalar k_40 = r(r4)
scalar k_50 = r(r5)
scalar k_60 = r(r6)

local threshold "10 20 30 40 50 60"
foreach i of local threshold {

qui drop if income < k_`i'

local thres = k_`i'
local pct   = `i'/100

qui survbound income, thres(`thres') censorpct(`pct') grid(10)

scalar lower_`i'  = round(r(lower_a), 0.0001)
scalar upper_`i'  = round(r(upper_g), 0.0001)
scalar length_`i' = upper_`i' - lower_`i'

}

matrix lower  = (nullmat(lower) \ lower_10, lower_20, lower_30, lower_40, lower_50, lower_60)
matrix upper  = (nullmat(upper) \ upper_10, upper_20, upper_30, upper_40, upper_50, upper_60)
matrix length = (nullmat(length) \ length_10, length_20, length_30, length_40, length_50, length_60)

}

mata : st_matrix("avg_lower", colsum(st_matrix("lower")))
mata : st_matrix("avg_upper", colsum(st_matrix("upper")))
mata : st_matrix("avg_length", colsum(st_matrix("length")))
mat avg_lower = avg_lower/1000
mat avg_upper = avg_upper/1000
mat avg_length = avg_length/1000

mat table = avg_lower \ avg_upper \ avg_length
mat table = table'
matrix rownames table = 0.10 0.20 0.30 0.40 0.50 0.60
matrix colnames table = Lower Upper Length
matlist table




log close
