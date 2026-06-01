use warwickshire_1332, clear

capture log close
log using table7, replace

survlsl income, thres(10) censorpct(0.30) model(lognormal)
survlsl income, thres(10) censorpct(0.20) model(lognormal)
survlsl income, thres(10) censorpct(0.10) model(lognormal)
survlsl income, thres(10) censorpct(0.0525) model(lognormal)

log close
