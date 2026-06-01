clear matrix
set matsize 10000

local obs "20 50 100 300"

foreach i of local obs {

display `i'

forvalues j = 1/1000 {

display `j'

quiet {

clear
set obs `i'

local mu     = 2 
local sigma  = 0.5
local K      = 6

scalar gini = 2*normal(`sigma'/(sqrt(2)))-1

tempvar prob 
gen `prob' = runiform()
gen Y = exp(`mu'+`sigma'*invnorm(`prob'))

qui gen income = max(Y, `K')
qui gen censor = (Y == income) 

count if censor == 0
display r(N)/_N
local pct = r(N)/_N

drop if income <= `K'

survlsl income, thres(`K') censorpct(`pct') model(lognormal)
return list

mat CI = r(conf_interval)
scalar CI1_lower = CI[1,1]
scalar CI1_upper = CI[1,2]
scalar CI2_lower = CI[2,1]
scalar CI2_upper = CI[2,2]

scalar true1 = (gini > CI1_lower & gini < CI1_upper)
scalar true2 = (gini > CI2_lower & gini < CI2_upper)
scalar len1  = CI1_upper - CI1_lower
scalar len2  = CI2_upper - CI2_lower

matrix true_`i'obs_1 = (nullmat(true_`i'obs_1) \ true1, true2)
matrix len_`i'obs_1  = (nullmat(len_`i'obs_1) \ len1, len2)

}

}

}

local obs "20 50 100 300"

foreach i of local obs {

display `i'

forvalues j = 1/1000 {

display `j'

quiet {

clear
set obs `i'

local mu     = 2 
local sigma  = 1
local K      = 5

scalar gini = 2*normal(`sigma'/(sqrt(2)))-1

tempvar prob 
gen `prob' = runiform()
gen Y = exp(`mu'+`sigma'*invnorm(`prob'))

qui gen income = max(Y, `K')
qui gen censor = (Y == income) 

count if censor == 0
display r(N)/_N
local pct = r(N)/_N

drop if income <= `K'

survlsl income, thres(`K') censorpct(`pct') model(lognormal)
return list

mat CI = r(conf_interval)
scalar CI1_lower = CI[1,1]
scalar CI1_upper = CI[1,2]
scalar CI2_lower = CI[2,1]
scalar CI2_upper = CI[2,2]

scalar true1 = (gini > CI1_lower & gini < CI1_upper)
scalar true2 = (gini > CI2_lower & gini < CI2_upper)
scalar len1  = CI1_upper - CI1_lower
scalar len2  = CI2_upper - CI2_lower

matrix true_`i'obs_2 = (nullmat(true_`i'obs_2) \ true1, true2)
matrix len_`i'obs_2 = (nullmat(len_`i'obs_2) \ len1, len2)

}

}

}


local obs "20 50 100 300"

foreach i of local obs {

display `i'

forvalues j = 1/1000 {

display `j'

quiet {

clear
set obs `i'

local mu     = 2 
local sigma  = 1.5
local K      = 3.5

scalar gini = 2*normal(`sigma'/(sqrt(2)))-1

tempvar prob 
gen `prob' = runiform()
gen Y = exp(`mu'+`sigma'*invnorm(`prob'))

qui gen income = max(Y, `K')
qui gen censor = (Y == income) 

count if censor == 0
display r(N)/_N
local pct = r(N)/_N

drop if income <= `K'

survlsl income, thres(`K') censorpct(`pct') model(lognormal)
return list

mat CI = r(conf_interval)
scalar CI1_lower = CI[1,1]
scalar CI1_upper = CI[1,2]
scalar CI2_lower = CI[2,1]
scalar CI2_upper = CI[2,2]

scalar true1 = (gini > CI1_lower & gini < CI1_upper)
scalar true2 = (gini > CI2_lower & gini < CI2_upper)
scalar len1  = CI1_upper - CI1_lower
scalar len2  = CI2_upper - CI2_lower

matrix true_`i'obs_3 = (nullmat(true_`i'obs_3) \ true1, true2)
matrix len_`i'obs_3  = (nullmat(len_`i'obs_3) \ len1, len2)

}

}

}


capture log close
log using table6, replace

local obs "20 50 100 300"

foreach i of local obs {

forvalues j = 1/3 {

quiet {

mata : st_matrix("pct_`i'_`j'", colsum(st_matrix("true_`i'obs_`j'")))
mat pct_`i'_`j' = pct_`i'_`j'/1000

mata : st_matrix("len_`i'_`j'", colsum(st_matrix("len_`i'obs_`j'")))
mat len_`i'_`j' = len_`i'_`j'/1000


}

mat list pct_`i'_`j'
mat list len_`i'_`j'

}

}


log close


