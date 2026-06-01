use e1690_data, clear

qui replace failcens = 0 if failcens == 1
qui replace failcens = 1 if failcens == 2

capture sjlog close
sjlog using survgini_ex1
survgini failtime failcens trt, noperm
return list
sjlog close


capture sjlog close
sjlog using survgini_ex2
set seed 20171121
survgini failtime failcens trt, nolin noas
return list
sjlog close

