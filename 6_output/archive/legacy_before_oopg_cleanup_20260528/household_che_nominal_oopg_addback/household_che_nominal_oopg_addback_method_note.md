# Household CHE: Reconstructed Nominal Total Consumption + OOPG Addback

This branch mirrors the main household total-expenditure denominator as a compact threshold check.

The denominator is reconstructed monthly nominal household total consumption plus general health/OOPG only: `nominal_total_cons_month + oopg`.

The numerators are monthly household OOPG (`oopg`) and combined monthly household OOP (`oop`).

Estimates use Stata survey commands with `svyset psu_number [pw = hhs_wt]`.

For the OOP numerator, the denominator does not add back NCD spending, so OOP shares are expected to be larger than under the full-OOP addback convention.
