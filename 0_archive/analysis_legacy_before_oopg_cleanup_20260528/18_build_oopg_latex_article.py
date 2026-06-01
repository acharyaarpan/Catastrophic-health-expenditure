"""Build the OOPG-only LaTeX manuscript article.

Inputs:
    6_output/main_output/chapter18/oopg/*.csv
    6_output/main_output/oopg_ctp_adult_equiv/*.csv
    6_output/main_output/oopg_ae_impoverishment/*.csv
    6_output/main_output/poverty_impact.csv

Outputs:
    6_output/main_output/oopg_manuscript/oopg_che_manuscript.tex
    6_output/main_output/oopg_manuscript/references.bib
    6_output/main_output/oopg_manuscript/oopg_budget_share_curve.png
    6_output/main_output/oopg_manuscript/oopg_pc_impoverishment_pens_parade.png
    6_output/main_output/oopg_manuscript/oopg_ae_impoverishment_pens_parade.png
"""

from __future__ import annotations

from pathlib import Path
import shutil

import pandas as pd


PROJECT_ROOT = Path(__file__).resolve().parents[1]
OUT = PROJECT_ROOT / "6_output" / "main_output"
CH18 = OUT / "chapter18" / "oopg"
CTP = OUT / "oopg_ctp_adult_equiv"
AE_IMPOV = OUT / "oopg_ae_impoverishment"
MANUSCRIPT = OUT / "oopg_manuscript"
TEX = MANUSCRIPT / "oopg_che_manuscript.tex"
BIB = MANUSCRIPT / "references.bib"


def pct(x: float) -> str:
    if pd.isna(x):
        return "--"
    return f"{100 * float(x):.2f}\\%"


def num(x: float, digits: int = 4) -> str:
    if pd.isna(x):
        return "--"
    return f"{float(x):.{digits}f}"


def pct_from_pct(x: float) -> str:
    if pd.isna(x):
        return "--"
    return f"{float(x):.2f}\\%"


def pp_from_pct(x: float) -> str:
    if pd.isna(x):
        return "--"
    return f"{float(x):+.2f} pp"


def row(df: pd.DataFrame, denominator: str, threshold: int | float) -> pd.Series | None:
    hit = df[(df["denominator"] == denominator) & (abs(df["threshold"] - threshold) < 1e-9)]
    return None if hit.empty else hit.iloc[0]


def latex_table_incidence(inc: pd.DataFrame) -> str:
    thresholds = [5, 10, 15, 25, 40]
    lines = [
        r"\begin{table}[!htbp]",
        r"\centering",
        r"\begin{threeparttable}",
        r"\caption{Incidence and intensity of catastrophic OOPG payments}",
        r"\label{tab:incidence}",
        r"\small",
        r"\begin{tabular}{lccccc}",
        r"\toprule",
        r"Measure & 5\% & 10\% & 15\% & 25\% & 40\% \\",
        r"\midrule",
        r"\multicolumn{6}{l}{\textit{OOPG as a share of total expenditure}} \\",
    ]
    for label, col in [
        ("Headcount", "headcount"),
        ("Standard error", "headcount_se"),
        ("Overshoot", "overshoot"),
        ("Mean positive overshoot", "mpo"),
    ]:
        vals = []
        for z in thresholds:
            r = row(inc, "total", z)
            vals.append(pct(r[col]) if r is not None else "--")
        lines.append(f"{label} & " + " & ".join(vals) + r" \\")
    lines.append(r"\addlinespace")
    lines.append(r"\multicolumn{6}{l}{\textit{OOPG as a share of nonfood expenditure}} \\")
    for label, col in [
        ("Headcount", "headcount"),
        ("Standard error", "headcount_se"),
        ("Overshoot", "overshoot"),
        ("Mean positive overshoot", "mpo"),
    ]:
        vals = []
        for z in thresholds:
            r = row(inc, "nonfood", z)
            vals.append(pct(r[col]) if r is not None else "--")
        lines.append(f"{label} & " + " & ".join(vals) + r" \\")
    lines.extend(
        [
            r"\bottomrule",
            r"\end{tabular}",
            r"\begin{tablenotes}",
            r"\small",
            r"\item Notes: Estimates use household survey weights. OOPG is Section 8(B) communicable disease or injury out-of-pocket spending. The total-expenditure denominator is reconstructed nominal monthly consumption plus OOPG.",
            r"\end{tablenotes}",
            r"\end{threeparttable}",
            r"\end{table}",
        ]
    )
    return "\n".join(lines)


def latex_table_ctp(ctp: pd.DataFrame) -> str:
    h = ctp[ctp["weight"] == "hhs_wt"].copy()
    lines = [
        r"\begin{table}[!htbp]",
        r"\centering",
        r"\begin{threeparttable}",
        r"\caption{Adult-equivalence capacity-to-pay catastrophic OOPG payments}",
        r"\label{tab:ctp}",
        r"\small",
        r"\begin{tabular}{lccc}",
        r"\toprule",
        r"Measure & 10\% CTP & 25\% CTP & 40\% CTP \\",
        r"\midrule",
    ]
    for label, col in [
        ("Headcount", "headcount"),
        ("Standard error", "headcount_se"),
        ("Overshoot", "overshoot"),
        ("Mean positive overshoot", "mpo"),
    ]:
        vals = []
        for z in [0.10, 0.25, 0.40]:
            r = row(h, "ctp_ae", z)
            vals.append(pct(r[col]) if r is not None else "--")
        lines.append(f"{label} & " + " & ".join(vals) + r" \\")
    lines.extend(
        [
            r"\bottomrule",
            r"\end{tabular}",
            r"\begin{tablenotes}",
            r"\small",
            r"\item Notes: Capacity to pay is total reconstructed nominal consumption plus OOPG less adult-equivalence-adjusted subsistence expenditure, except when observed food expenditure is below subsistence, in which case observed food expenditure is subtracted. Estimates use household survey weights.",
            r"\end{tablenotes}",
            r"\end{threeparttable}",
            r"\end{table}",
        ]
    )
    return "\n".join(lines)


def latex_table_distribution(eq: pd.DataFrame, ctp_eq: pd.DataFrame) -> str:
    thresholds = [5, 10, 15, 25, 40]
    lines = [
        r"\begin{table}[!htbp]",
        r"\centering",
        r"\begin{threeparttable}",
        r"\caption{Distribution-sensitive OOPG catastrophic-payment measures}",
        r"\label{tab:distribution}",
        r"\small",
        r"\begin{tabular}{lccccc}",
        r"\toprule",
        r"Measure & 5\% & 10\% & 15\% & 25\% & 40\% \\",
        r"\midrule",
        r"\multicolumn{6}{l}{\textit{OOPG as a share of total expenditure}} \\",
    ]
    for label, col, is_pct in [
        (r"Concentration index, $C^H$", "concentration_headcount", False),
        (r"Rank-weighted headcount, $H^W$", "rank_weighted_headcount", True),
        (r"Concentration index, $C^O$", "concentration_overshoot", False),
        (r"Rank-weighted overshoot, $O^W$", "rank_weighted_overshoot", True),
    ]:
        vals = []
        for z in thresholds:
            r = row(eq, "total", z)
            vals.append(pct(r[col]) if is_pct and r is not None else (num(r[col]) if r is not None else "--"))
        lines.append(f"{label} & " + " & ".join(vals) + r" \\")
    lines.append(r"\addlinespace")
    lines.append(r"\multicolumn{6}{l}{\textit{OOPG as a share of nonfood expenditure}} \\")
    for label, col, is_pct in [
        (r"Concentration index, $C^H$", "concentration_headcount", False),
        (r"Rank-weighted headcount, $H^W$", "rank_weighted_headcount", True),
        (r"Concentration index, $C^O$", "concentration_overshoot", False),
        (r"Rank-weighted overshoot, $O^W$", "rank_weighted_overshoot", True),
    ]:
        vals = []
        for z in thresholds:
            r = row(eq, "nonfood", z)
            vals.append(pct(r[col]) if is_pct and r is not None else (num(r[col]) if r is not None else "--"))
        lines.append(f"{label} & " + " & ".join(vals) + r" \\")
    lines.append(r"\addlinespace")
    lines.append(r"\multicolumn{6}{l}{\textit{OOPG as a share of adult-equivalence capacity to pay}} \\")
    h = ctp_eq[(ctp_eq["weight"] == "hhs_wt") & (ctp_eq["measure"] == "headcount")].copy()
    o = ctp_eq[(ctp_eq["weight"] == "hhs_wt") & (ctp_eq["measure"] == "overshoot")].copy()
    for label, data, col, is_pct in [
        (r"Concentration index, $C^H$", h, "concentration_index", False),
        (r"Rank-weighted headcount, $H^W$", h, "rank_weighted", True),
        (r"Concentration index, $C^O$", o, "concentration_index", False),
        (r"Rank-weighted overshoot, $O^W$", o, "rank_weighted", True),
    ]:
        vals = []
        for z in thresholds:
            if z not in [10, 25, 40]:
                vals.append("--")
                continue
            r = row(data, "ctp_ae", z / 100)
            vals.append(pct(r[col]) if is_pct and r is not None else (num(r[col]) if r is not None else "--"))
        lines.append(f"{label} & " + " & ".join(vals) + r" \\")
    lines.extend(
        [
            r"\bottomrule",
            r"\end{tabular}",
            r"\begin{tablenotes}",
            r"\small",
            r"\item Notes: Concentration indices and rank-weighted measures rank households by pre-OOPG welfare. Estimates use household survey weights.",
            r"\end{tablenotes}",
            r"\end{threeparttable}",
            r"\end{table}",
        ]
    )
    return "\n".join(lines)


def latex_table_poverty(pov: pd.DataFrame) -> str:
    r = pov[(pov["scope"] == "oopg") & (pov["metric"] == "poverty_headcount")].iloc[0]
    return "\n".join(
        [
            r"\begin{table}[!htbp]",
            r"\centering",
            r"\begin{threeparttable}",
            r"\caption{OOPG-associated impoverishment}",
            r"\label{tab:poverty}",
            r"\small",
            r"\begin{tabular}{lcccc}",
            r"\toprule",
            r"Measure & Pre-OOPG & Post-payment & Change & People pushed \\",
            r"\midrule",
            f"Poverty headcount & {pct(r['pre_estimate'])} & {pct(r['post_estimate'])} & {pp_from_pct(100 * r['difference'])} & {float(r['people_pushed']):,.0f} \\\\",
            r"\bottomrule",
            r"\end{tabular}",
            r"\begin{tablenotes}",
            r"\small",
            r"\item Notes: Estimates use individual weights. Post-payment welfare is official NLSS $pcep$; pre-OOPG welfare is $pcep + oopg\_pc\_ann\_real$.",
            r"\end{tablenotes}",
            r"\end{threeparttable}",
            r"\end{table}",
        ]
    )


def write_bib() -> None:
    BIB.write_text(
        r"""@book{odonnell2008,
  author    = {O'Donnell, Owen and van Doorslaer, Eddy and Wagstaff, Adam and Lindelow, Magnus},
  title     = {Analyzing Health Equity Using Household Survey Data: A Guide to Techniques and Their Implementation},
  publisher = {World Bank},
  address   = {Washington, DC},
  year      = {2008}
}

@article{wagstaff2003,
  author  = {Wagstaff, Adam and van Doorslaer, Eddy},
  title   = {Catastrophe and impoverishment in paying for health care: with applications to Vietnam 1993--1998},
  journal = {Health Economics},
  volume  = {12},
  number  = {11},
  pages   = {921--934},
  year    = {2003},
  doi     = {10.1002/hec.776}
}

@article{xu2003,
  author  = {Xu, Ke and Evans, David B. and Kawabata, Kei and Zeramdini, Riadh and Klavus, Jan and Murray, Christopher J. L.},
  title   = {Household catastrophic health expenditure: a multicountry analysis},
  journal = {The Lancet},
  volume  = {362},
  number  = {9378},
  pages   = {111--117},
  year    = {2003},
  doi     = {10.1016/S0140-6736(03)13861-5}
}

@techreport{xu2005,
  author      = {Xu, Ke},
  title       = {Distribution of Health Payments and Catastrophic Expenditures: Methodology},
  institution = {World Health Organization},
  address     = {Geneva},
  year        = {2005}
}

@misc{who2026sdg382,
  author       = {{World Health Organization}},
  title        = {Global Health Observatory indicator metadata: population with household expenditures on health greater than 10\% of total household expenditure or income (SDG 3.8.2)},
  year         = {2026},
  howpublished = {\url{https://www.who.int/data/gho/data/indicators/indicator-details/GHO/total-population-with-household-expenditures-on-health-greater-than-10-of-total-household-expenditure-or-income-%28sdg-3-8-2%29-%28-%29}},
  note         = {Accessed 28 May 2026}
}

@article{koch2018,
  author  = {Koch, Steven F.},
  title   = {Catastrophic health payments: does the equivalence scale matter?},
  journal = {Health Policy and Planning},
  volume  = {33},
  number  = {8},
  pages   = {966--973},
  year    = {2018},
  doi     = {10.1093/heapol/czy072}
}
""",
        encoding="utf-8",
    )


def build_tex() -> None:
    inc = pd.read_csv(CH18 / "oopg_box18_1_incidence_intensity.csv")
    eq = pd.read_csv(CH18 / "oopg_box18_2_distribution_sensitive.csv")
    ctp = pd.read_csv(CTP / "oopg_ctp_adult_equiv_summary.csv")
    ctp_eq = pd.read_csv(CTP / "oopg_ctp_adult_equiv_equity.csv")
    ae_impov = pd.read_csv(AE_IMPOV / "oopg_ae_impoverishment_summary.csv").iloc[0]
    pov = pd.read_csv(OUT / "poverty_impact.csv")

    h10 = row(inc, "total", 10)
    nf40 = row(inc, "nonfood", 40)
    ctp40 = row(ctp[ctp["weight"] == "hhs_wt"], "ctp_ae", 0.40)
    ctp25 = row(ctp[ctp["weight"] == "hhs_wt"], "ctp_ae", 0.25)
    ctp10 = row(ctp[ctp["weight"] == "hhs_wt"], "ctp_ae", 0.10)
    dist_total10 = row(eq, "total", 10)
    dist_nf40 = row(eq, "nonfood", 40)
    dist_ctp10 = row(
        ctp_eq[
            (ctp_eq["weight"] == "hhs_wt")
            & (ctp_eq["measure"] == "headcount")
        ],
        "ctp_ae",
        0.10,
    )
    dist_ctp40 = row(
        ctp_eq[
            (ctp_eq["weight"] == "hhs_wt")
            & (ctp_eq["measure"] == "headcount")
        ],
        "ctp_ae",
        0.40,
    )
    povrow = pov[(pov["scope"] == "oopg") & (pov["metric"] == "poverty_headcount")].iloc[0]

    tex = rf"""\documentclass[11pt]{{article}}

\usepackage[margin=1in]{{geometry}}
\usepackage{{amsmath}}
\usepackage{{booktabs}}
\usepackage{{caption}}
\usepackage{{float}}
\usepackage{{graphicx}}
\usepackage{{threeparttable}}
\usepackage[round]{{natbib}}
\usepackage{{xurl}}
\usepackage[colorlinks=true,linkcolor=black,citecolor=black,urlcolor=blue]{{hyperref}}

\setlength{{\parindent}}{{0pt}}
\setlength{{\parskip}}{{6pt}}
\captionsetup{{font=small,labelfont=bf}}

\title{{Catastrophic General Health Out-of-Pocket Expenditure in Nepal: An OOPG-Focused Analysis}}
\author{{Authors' calculations from Nepal Living Standards Survey IV}}
\date{{}}

\begin{{document}}
\maketitle

\begin{{abstract}}
This draft examines catastrophic out-of-pocket spending for general health events in Nepal using NLSS IV. The analysis focuses on OOPG, defined as communicable disease or injury spending reported in Section 8(B). We present three complementary denominators: total household expenditure, nonfood expenditure, and adult-equivalence-adjusted capacity to pay. The purpose of the layered design is to distinguish an intuitive budget-share measure from progressively more welfare-sensitive specifications.
\end{{abstract}}

\section{{Introduction}}

Financial protection is a central objective of health systems because health payments can force households to sacrifice other consumption, borrow, sell assets, or fall into poverty. Catastrophic health expenditure (CHE) measures this burden by comparing out-of-pocket payments with household resources. This paper focuses on OOPG, a measure of general health out-of-pocket spending related to communicable disease or injury. This scope is useful because it is directly observed over a recent 30-day recall period in NLSS IV and allows a focused assessment of acute health-payment burden.

The analysis follows the catastrophic-payment tradition in \citet{{odonnell2008}} and \citet{{wagstaff2003}}, while also drawing on the WHO/Xu capacity-to-pay approach \citep{{xu2003,xu2005}}. The total-expenditure measure is retained because it is transparent and comparable with the SDG 3.8.2 convention, which monitors health spending above 10\% or 25\% of household consumption or income \citep{{who2026sdg382}}. The capacity-to-pay extension is added because total expenditure may not represent discretionary resources equally across households with different subsistence needs.

\section{{Data and OOPG Measure}}

The data are from Nepal Living Standards Survey IV. OOPG is constructed by summing individual Section 8(B) payments for communicable disease or injury to the household level. The household is the analytical unit because catastrophic expenditure is a budget event: the payment may originate with one member, but the financial burden is absorbed by the household.

NLSS welfare aggregates exclude health spending by construction. For total-expenditure CHE, nominal household consumption is therefore reconstructed from official food and nonfood welfare components and OOPG is added back to the denominator. This avoids comparing a health-payment numerator with a denominator that omits the same category of spending.

\section{{Methods}}

\subsection{{Total-expenditure CHE}}

Let $T_i$ denote household OOPG and $x_i$ denote reconstructed monthly nominal household consumption inclusive of OOPG. The total-expenditure share is
\begin{{equation}}
s_i^T = \frac{{T_i}}{{x_i}}, \qquad x_i = \text{{nominal consumption}}_i + T_i.
\end{{equation}}
A household is catastrophic at threshold $z$ if $s_i^T > z$. We report multiple thresholds, with the 10\% threshold emphasized for interpretation and comparability.

\subsection{{Nonfood CHE}}

The second specification uses nonfood expenditure as a practical ability-to-pay proxy, following the Chapter 18 framework in \citet{{odonnell2008}}. Let $c_i^{{NF}}$ denote real monthly nonfood consumption plus real OOPG. The nonfood share is
\begin{{equation}}
s_i^{{NF}} = \frac{{T_i^r}}{{c_i^{{NF}}}},
\end{{equation}}
where $T_i^r$ is real monthly OOPG. This denominator is narrower than total expenditure and therefore gives a stricter view of financial stress.

\subsection{{Adult-equivalence capacity to pay}}

The third specification follows the logic of the WHO/Xu capacity-to-pay method \citep{{xu2003,xu2005}}. Adult equivalence is used only here because it is a way of estimating household subsistence needs, not a way of rescaling the health bill. If both OOPG and total consumption were divided by the same equivalence scale, the scale would cancel: $(T_i/E_i)/(x_i/E_i)=T_i/x_i$. Comparing household OOPG with consumption per adult equivalent would mix units by placing a household-level payment over a one-adult-equivalent denominator.

Adult equivalence therefore enters through subsistence expenditure. We use the project scale
\begin{{equation}}
E_i = (A_i + 0.5K_i)^{{0.75}},
\end{{equation}}
where $A_i$ is the number of adults aged 15 years or older and $K_i$ is the number of children below age 15. Food expenditure per adult equivalent is computed as
\begin{{equation}}
f_i^e = \frac{{f_i}}{{E_i}}.
\end{{equation}}
The subsistence line is the household-weighted mean of $f_i^e$ among households in the 45th--55th percentiles of the food-share distribution. Household subsistence expenditure is this line multiplied by $E_i$. Capacity to pay is then
\begin{{equation}}
C_i =
\begin{{cases}}
x_i - subs_i, & \text{{if }} f_i \ge subs_i, \\
x_i - f_i, & \text{{if }} f_i < subs_i.
\end{{cases}}
\end{{equation}}
The CTP catastrophic share is $T_i/C_i$. This approach follows the role of equivalence scales described by \citet{{koch2018}}: equivalence affects the poverty line, subsistence expenditure, and capacity to pay, not the OOP numerator itself.

\subsection{{Equity and impoverishment measures}}

For each denominator, we report headcount, overshoot, and mean positive overshoot. Distribution-sensitive measures use concentration indices and rank-weighted headcounts/overshoots. Because this manuscript is OOPG-only, households are ranked by pre-OOPG welfare, defined as official real per-capita consumption plus annual real per-capita OOPG. Impoverishment is calculated by comparing official post-payment welfare, $pcep$, with pre-OOPG welfare constructed by adding annual real per-capita OOPG back to $pcep$.

\section{{Results}}

{latex_table_incidence(inc)}

At the 10\% total-expenditure threshold, {pct(h10["headcount"])} of households incurred catastrophic OOPG spending. The associated mean positive overshoot was {pct(h10["mpo"])}, indicating that households crossing the threshold were not merely marginally above it. Under the 40\% nonfood threshold, the headcount was {pct(nf40["headcount"])}, reflecting a stricter ability-to-pay interpretation.

{latex_table_ctp(ctp)}

Table~\ref{{tab:ctp}} applies the adult-equivalence capacity-to-pay denominator. At the 10\% threshold, {pct(ctp10["headcount"])} of households crossed the CTP line; this should be read as a lower-threshold financial-stress indicator, because even one-tenth of capacity to pay can be consequential once subsistence needs are protected. The 25\% and 40\% thresholds are stricter: {pct(ctp25["headcount"])} and {pct(ctp40["headcount"])} of households crossed them, respectively. These estimates should be read alongside, not instead of, the total-expenditure estimate. They ask a different welfare question: how large is OOPG after protecting basic subsistence needs?

\begin{{figure}}[!htbp]
\centering
\includegraphics[width=0.86\textwidth]{{oopg_budget_share_curve.png}}
\caption{{OOPG budget-share curve}}
\label{{fig:budgetshare}}
\end{{figure}}

Figure~\ref{{fig:budgetshare}} shows the distribution of OOPG budget shares. The left tail identifies households for which OOPG absorbs a particularly large share of resources, while the flatter portion of the curve shows that most households have relatively low OOPG shares.

{latex_table_distribution(eq, ctp_eq)}

Table~\ref{{tab:distribution}} shows how the interpretation changes when incidence is read alongside welfare rank. Positive concentration indices indicate that the relevant catastrophic measure is more concentrated among better-off households, while negative values indicate concentration among poorer households. For the 10\% total-expenditure headcount, the concentration index is {num(dist_total10["concentration_headcount"])}, and the rank-weighted headcount is {pct(dist_total10["rank_weighted_headcount"])}. For the 40\% nonfood headcount, the concentration index is {num(dist_nf40["concentration_headcount"])}, with a rank-weighted headcount of {pct(dist_nf40["rank_weighted_headcount"])}. Under the CTP approach, the 10\% headcount concentration index is {num(dist_ctp10["concentration_index"])}, and the 40\% CTP concentration index is {num(dist_ctp40["concentration_index"])}. This pattern should be interpreted carefully: lower observed catastrophic spending among poorer households may reflect lower service use or lower ability to pay, not necessarily protection from need.

{latex_table_poverty(pov)}

Table~\ref{{tab:poverty}} reports the official poverty-impact calculation. Post-payment welfare is official NLSS $pcep$, while pre-OOPG welfare adds real per-capita OOPG back to $pcep$. The table indicates that OOPG raises the poverty headcount from {pct(povrow["pre_estimate"])} to {pct(povrow["post_estimate"])}, a change of {pp_from_pct(100 * povrow["difference"])}, corresponding to approximately {float(povrow["people_pushed"]):,.0f} people pushed below the poverty line. Because NLSS excludes health from official welfare, the pre-payment counterfactual is constructed by adding OOPG back to $pcep$ rather than subtracting it.

\begin{{figure}}[!htbp]
\centering
\includegraphics[width=0.92\textwidth]{{oopg_pc_impoverishment_pens_parade.png}}
\caption{{Per-capita Pen's Parade for OOPG-associated impoverishment}}
\label{{fig:pcimpov}}
\end{{figure}}

Figure~\ref{{fig:pcimpov}} presents the official per-capita impoverishment calculation as a conventional Pen's Parade. Households are ordered by the weighted pre-OOPG welfare multiple, and both pre- and post-payment welfare are divided by the official poverty line so that the poverty threshold is exactly 1. The vertical segments show the household-level welfare drop associated with OOPG payments; pushed-poverty counts are reported in Table~\ref{{tab:poverty}} rather than marked separately in the figure. The y-axis is capped at 10 poverty-line multiples to keep the poverty region visible, but all poverty estimates use uncapped household values.

\begin{{figure}}[!htbp]
\centering
\includegraphics[width=0.92\textwidth]{{oopg_ae_impoverishment_pens_parade.png}}
\caption{{Adult-equivalent Pen's Parade for OOPG-associated impoverishment}}
\label{{fig:aeimpov}}
\end{{figure}}

Figure~\ref{{fig:aeimpov}} applies the same poverty-line normalization to the adult-equivalent display. Adult-equivalent welfare is $w_i^e=w_i\times hhsize_i/E_i$, and the transformed official threshold is $pline_i^e=pline\times hhsize_i/E_i$. Dividing one by the other gives $w_i^e/pline_i^e=w_i/pline$, so setting the poverty line equal to 1 makes the AE and per-capita Pen's Parades algebraically equivalent for poverty status. The AE figure is therefore not a new poverty estimate; it preserves the official result---pre-OOPG poverty {pct_from_pct(ae_impov["pre_poverty_pct"])}, post-payment poverty {pct_from_pct(ae_impov["post_poverty_pct"])}, and OOPG-associated impoverishment of {pp_from_pct(ae_impov["impoverishment_pp"])}, or approximately {float(ae_impov["people_pushed"]):,.0f} people.

\section{{Discussion}}

The three denominators answer related but distinct questions. The total-expenditure measure provides an intuitive budget-share headline. The nonfood measure narrows the denominator to resources outside food consumption and therefore moves closer to an ability-to-pay interpretation. The adult-equivalence CTP measure is the most welfare-sensitive because it explicitly protects a household-specific subsistence requirement before evaluating health-payment burden.

The adult-equivalence adjustment is not used in the simple total-expenditure ratio because it would either cancel algebraically or create an inconsistent comparison of household payments with per-equivalent-adult consumption. Its appropriate role is in the construction of capacity to pay, where household composition affects the estimated resources needed for basic living.

\bibliographystyle{{apalike}}
\bibliography{{references}}

\end{{document}}
"""
    TEX.write_text(tex, encoding="utf-8")


def main() -> None:
    MANUSCRIPT.mkdir(parents=True, exist_ok=True)
    for src, dst_name in [
        (CH18 / "oopg_budget_share_curve.png", "oopg_budget_share_curve.png"),
        (
            AE_IMPOV / "oopg_pc_impoverishment_pens_parade.png",
            "oopg_pc_impoverishment_pens_parade.png",
        ),
        (
            AE_IMPOV / "oopg_ae_impoverishment_pens_parade.png",
            "oopg_ae_impoverishment_pens_parade.png",
        ),
    ]:
        if src.exists():
            shutil.copy2(src, MANUSCRIPT / dst_name)
    write_bib()
    build_tex()
    print(f"Saved: {TEX}")
    print(f"Saved: {BIB}")


if __name__ == "__main__":
    main()
