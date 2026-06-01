use warwickshire_1332, clear

gen log_income = log(income)
hist log_income, bin(15) ///
	addplot(function y=normalden(x,3,1), range(0 7) lpattern(solid) || function y=normalden(x,3.4,0.67), range(0 7) lpattern(dash)) ///
	xscale(range(0 7)) xlabel(0(1)7) xtitle("")  ///
	legend(label(1 "Log income histogram") label(2 "Normal distribution under censoring assumption") label(3 "Normal distribution under truncation assumption")) /// 
	scheme(sj)

graph export "figure4.eps", as(eps) preview(off) replace
