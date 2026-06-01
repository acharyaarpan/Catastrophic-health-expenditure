use warwickshire_1332, clear

gen log_income = log(income)
local k = log(10)
hist log_income, bin(15) normal addplot(pci 0 `k' .75 `k') ///
	legend(off) xscale(range(1 7)) xlabel(1(1)7) xtitle(Income (log)) scheme(sj)

graph export "figure3.eps", as(eps) preview(off) replace
