use warwickshire_1332, clear

capture sjlog close
sjlog using survbound_ex1
survbound income, thres(10) censorpct(0.30)
return list
sjlog close 


capture sjlog close
sjlog using survbound_ex2
survbound income, thres(10) censorpct(0.30) grid(10)
return list
sjlog close 
