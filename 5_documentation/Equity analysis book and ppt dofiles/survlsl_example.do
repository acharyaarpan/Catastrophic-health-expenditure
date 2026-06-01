use warwickshire_1332, clear

capture sjlog close

sjlog using survlsl_ex1
survlsl income, thres(10) censorpct(0.30) model(lognormal)
return list
sjlog close 


capture sjlog close
sjlog using survlsl_ex2
survlsl income, thres(10) censorpct(0) model(lognormal)
sjlog close 
