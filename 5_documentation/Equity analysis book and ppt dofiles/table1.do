clear matrix
set matsize 10000

local observation "50 100 300 500 1000" 

capture log close
log using table1, replace

foreach obs of local observation {

display "`obs'"

quiet {

forval i = 1/1000 {

clear
set obs `obs'

local mu    = 3 
local sigma = 2
local K     = 10

scalar gini = 2*normal(`sigma'/(sqrt(2)))-1

tempvar prob 
gen `prob' = runiform()
gen Y = exp(`mu'+`sigma'*invnorm(`prob'))

qui gen income = max(Y, `K')
qui gen censor = (Y == income) 

qui count if censor == 0
local pct = r(N)/_N
drop if censor == 0

qui survlsl income, thres(`K') censorpct(`pct') model(lognormal)
scalar alpha1 = r(alpha)
scalar beta1  = r(beta)

qui survlsl income, thres(`K') censorpct(0) model(lognormal)
scalar alpha2 = r(alpha)
scalar beta2  = r(beta)

matrix theta_`obs' = (nullmat(theta_`obs') \ alpha1, beta1, alpha2, beta2)

}


clear
svmat double theta_`obs'
qui sum theta_`obs'1 
scalar mean_mu1_`obs' = r(mean)
scalar sd_mu1_`obs'   = r(sd)
qui sum theta_`obs'2
scalar mean_sigma1_`obs' = r(mean)
scalar sd_sigma1_`obs'   = r(sd)
qui sum theta_`obs'3 
scalar mean_mu2_`obs' = r(mean)
scalar sd_mu2_`obs'   = r(sd)
qui sum theta_`obs'4
scalar mean_sigma2_`obs' = r(mean)
scalar sd_sigma2_`obs'   = r(sd)

matrix theta = (nullmat(theta) \ mean_mu1_`obs', sd_mu1_`obs', mean_sigma1_`obs', sd_sigma1_`obs', mean_mu2_`obs', sd_mu2_`obs', mean_sigma2_`obs', sd_sigma2_`obs')

}

}

matrix rownames theta = "obs_50" "obs_100" "obs_300" "obs_500" "obs_1000"
matrix colnames theta = "mean_mu1" "sd_mu1" "mean_sigma1" "sd_sigma1" "mean_mu2" "sd_mu2" "mean_sigma2" "sd_sigma2"
matlist theta

log close

