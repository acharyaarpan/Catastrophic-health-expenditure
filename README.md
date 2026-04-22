# Catastrophic Health Expenditure — NLSS IV

Analysis of catastrophic health expenditure (CHE) using the Nepal Living Standards Survey IV (NLSS IV) data. This project examines out-of-pocket health spending relative to household consumption and identifies determinants of CHE through survey-weighted logistic regression.

## Overview

Catastrophic health expenditure occurs when a household's out-of-pocket health spending exceeds a defined threshold of its consumption. We use two thresholds (10% and 20% of monthly consumption) and two expenditure scopes (communicable disease only, and communicable + NCD combined), yielding four CHE outcome variables.

**Key findings:**
- 8.3% of households experience CHE from communicable disease spending alone (>10% threshold)
- 19.3% experience CHE when NCD costs are included
- Significant determinants include household size, presence of elderly/young children, disability status, outstanding loans, caste/ethnicity, and remittance receipt

## Directory Structure

```
consumption/
├── 0_master.do              # Master do-file (globals, package checks, run sequence)
├── 2_prep/
│   └── 1_catastrophic.do    # Data preparation: merge 8 raw datasets → analysis dataset
├── 3_analysis/
│   ├── 0_descriptive.do     # Weighted descriptive statistics (Table 1)
│   └── 1_logit_che.do       # Survey-weighted logistic regression (4 models)
├── 6_output/
│   ├── che_results.tex       # Combined LaTeX tables (descriptive + logit)
│   ├── descriptive_table.tex # Descriptive statistics (Table 1)
│   └── logit_results.tex     # Logistic regression odds ratios (Table 2)
└── README.md
```

## Data

The analysis uses NLSS IV microdata (not included in this repository). The raw data files are:

| File | Section | Description | Level |
|------|---------|-------------|-------|
| `poverty.dta` | — | Poverty indicators, province, welfare quintiles | Household (9,600) |
| `total_consumption.dta` | — | Total annual household consumption | Household (9,600) |
| `S01.dta` | Section 1 | Demographics: age, sex, caste/ethnicity | Individual (46,870) |
| `S02.dta` | Section 2 | Housing: toilet, water, cooking fuel | Household (9,600) |
| `S07.dta` | Section 7 | Education: literacy, school attendance, grade | Individual (46,870) |
| `S08.dta` | Section 8 | Health: NCDs, communicable disease, costs, disability | Individual (46,870) |
| `S13.dta` | Section 13 | Credit/savings: loans outstanding | Household (9,600) |
| `S14A.dta` | Section 14A | Absentee details: remittance receipt | Individual (8,769) |
| `S15.dta` | Section 15 | Other remittances: transfers from non-members | Household (9,600) |

The preparation script (`1_catastrophic.do`) merges these into a single household-level dataset of **9,600 households × 57 variables**.

## Methodology

### CHE Definition

- **Monthly consumption** = total annual consumption / 12
- **Combined health expenditure** = communicable (30-day) + NCD monthly estimate (annual / 12)
- **10% threshold**: Standard WHO/World Bank definition
- **20% threshold**: Stricter threshold from the literature

### Adult Equivalence Scale

Per capita consumption is adjusted using the Citro-Michael / NRC scale:

```
AE = (A + 0.5 × K)^0.75
```

where A = adults (age ≥ 15), K = children (age < 15).

### Regression Specification

Survey-weighted logistic regression (`svy: logit`) with PSU clustering and household probability weights. Covariates include:

- **Head & household**: age, household size, female head, literacy
- **Vulnerability**: elderly member, child under 5, disability
- **Living standards**: improved sanitation, improved water, clean cooking fuel
- **Economic**: remittance receipt, outstanding loan, poverty status
- **Categorical**: education (7 levels), caste/ethnicity (8 groups), area type (3), province (7)

### Key Analytical Decisions

1. Health costs aggregated from individual to household level; missing costs treated as zero
2. Head education sourced from S07.dta (own education), not S01 q01_12 (father's education)
3. Disability measured via Washington Group questions (6 functional domains)
4. Remittance combines absentee remittance (S14A q14_15) and non-member transfers (S15 q15_11)
5. No health insurance variable exists in NLSS IV (q02_34/q02_35 in S02 are firewood questions)

## Requirements

- **Stata 17+** with `estout` and `texify` packages
- Set your workspace path in `0_master.do` under the username conditionals

## How to Run

1. Place raw `.dta` files in `1_data/1_raw/`
2. Edit `0_master.do` to add your username and workspace path
3. Run `0_master.do` in Stata — it calls all scripts in sequence

## Author

Arpan Acharya

## License

This project is for academic research purposes. The NLSS IV data is property of the Central Bureau of Statistics, Nepal.
