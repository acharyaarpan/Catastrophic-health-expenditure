"""
Build a textbook-style LaTeX report for Chapter 18 OOPG and OOP results.

The report uses native LaTeX tables populated from the Chapter 18 CSV outputs.
Python-generated budget-share curves are included as figures.
"""

from __future__ import annotations

from pathlib import Path

import pandas as pd


PROJECT_ROOT = Path(__file__).resolve().parents[1]
CH18 = PROJECT_ROOT / "6_output" / "main_output" / "chapter18"
TEX = CH18 / "chapter18_oopg_oop_latex_report.tex"

THRESHOLDS = [5, 10, 15, 25, 40]
BOOK_TOTAL_THRESHOLDS = {5, 10, 15, 25}
BOOK_NONFOOD_THRESHOLDS = {15, 25, 40}


def pct(x: float) -> str:
    if pd.isna(x):
        return "---"
    return f"{x * 100:.2f}\\%"


def num(x: float) -> str:
    if pd.isna(x):
        return "---"
    return f"{x:.4f}"


def row(df: pd.DataFrame, denominator: str, threshold: int) -> pd.Series | None:
    hit = df[(df["denominator"] == denominator) & (df["threshold"] == threshold)]
    return None if hit.empty else hit.iloc[0]


def value(df: pd.DataFrame, denominator: str, threshold: int, column: str) -> float:
    r = row(df, denominator, threshold)
    if r is None:
        raise ValueError(f"Missing {denominator} {threshold} {column}")
    return float(r[column])


def incidence_table(scope: str, box1: pd.DataFrame) -> str:
    lines = [
        "\\begin{table}[H]",
        "\\centering",
        "\\small",
        "\\begin{tabular}{>{\\raggedright\\arraybackslash}p{0.40\\textwidth}rrrrr}",
        "\\toprule",
        "\\textbf{Catastrophic payment measure} & \\textbf{5\\%} & \\textbf{10\\%} & \\textbf{15\\%} & \\textbf{25\\%} & \\textbf{40\\%} \\\\",
        "\\midrule",
        f"\\multicolumn{{6}}{{l}}{{\\emph{{{scope.upper()} as share of total expenditure}}}} \\\\",
    ]
    for label, col in [
        ("Head count (H)", "headcount"),
        ("standard error", "headcount_se"),
        ("Overshoot (O)", "overshoot"),
        ("standard error", "overshoot_se"),
        ("Mean positive overshoot (MPO)", "mpo"),
    ]:
        vals = []
        for z in THRESHOLDS:
            if z not in BOOK_TOTAL_THRESHOLDS:
                vals.append("---")
            else:
                r = row(box1, "total", z)
                vals.append(pct(float(r[col])) if r is not None else "---")
        lines.append(label + " & " + " & ".join(vals) + " \\\\")
    lines.append("\\addlinespace")
    lines.append("\\multicolumn{6}{l}{\\emph{As share of nonfood expenditure}} \\\\")
    for label, col in [
        ("Head count (H)", "headcount"),
        ("standard error", "headcount_se"),
        ("Overshoot (O)", "overshoot"),
        ("standard error", "overshoot_se"),
        ("Mean positive overshoot (MPO)", "mpo"),
    ]:
        vals = []
        for z in THRESHOLDS:
            if z not in BOOK_NONFOOD_THRESHOLDS:
                vals.append("---")
            else:
                r = row(box1, "nonfood", z)
                vals.append(pct(float(r[col])) if r is not None else "---")
        lines.append(label + " & " + " & ".join(vals) + " \\\\")
    lines.extend(
        [
            "\\bottomrule",
            "\\end{tabular}",
            f"\\caption{{Incidence and intensity of catastrophic {scope.upper()} payments.}}",
            "\\end{table}",
        ]
    )
    return "\n".join(lines)


def distribution_table(scope: str, box2: pd.DataFrame) -> str:
    lines = [
        "\\begin{table}[H]",
        "\\centering",
        "\\small",
        "\\begin{tabular}{>{\\raggedright\\arraybackslash}p{0.43\\textwidth}rrrrr}",
        "\\toprule",
        "\\textbf{Distribution-sensitive measure} & \\textbf{5\\%} & \\textbf{10\\%} & \\textbf{15\\%} & \\textbf{25\\%} & \\textbf{40\\%} \\\\",
        "\\midrule",
        f"\\multicolumn{{6}}{{l}}{{\\emph{{{scope.upper()} as share of total expenditure}}}} \\\\",
    ]
    for label, col, is_pct in [
        ("Concentration index, $C^{H}$", "concentration_headcount", False),
        ("Rank-weighted head count, $H^{W}$", "rank_weighted_headcount", True),
        ("Concentration index, $C^{O}$", "concentration_overshoot", False),
        ("Rank-weighted overshoot, $O^{W}$", "rank_weighted_overshoot", True),
    ]:
        vals = []
        for z in THRESHOLDS:
            if z not in BOOK_TOTAL_THRESHOLDS:
                vals.append("---")
            else:
                r = row(box2, "total", z)
                vals.append(pct(float(r[col])) if is_pct and r is not None else (num(float(r[col])) if r is not None else "---"))
        lines.append(label + " & " + " & ".join(vals) + " \\\\")
    lines.append("\\addlinespace")
    lines.append("\\multicolumn{6}{l}{\\emph{As share of nonfood expenditure}} \\\\")
    for label, col, is_pct in [
        ("Concentration index, $C^{H}$", "concentration_headcount", False),
        ("Rank-weighted head count, $H^{W}$", "rank_weighted_headcount", True),
        ("Concentration index, $C^{O}$", "concentration_overshoot", False),
        ("Rank-weighted overshoot, $O^{W}$", "rank_weighted_overshoot", True),
    ]:
        vals = []
        for z in THRESHOLDS:
            if z not in BOOK_NONFOOD_THRESHOLDS:
                vals.append("---")
            else:
                r = row(box2, "nonfood", z)
                vals.append(pct(float(r[col])) if is_pct and r is not None else (num(float(r[col])) if r is not None else "---"))
        lines.append(label + " & " + " & ".join(vals) + " \\\\")
    lines.extend(
        [
            "\\bottomrule",
            "\\end{tabular}",
            "\\caption{Distribution-sensitive catastrophic payment measures. Households are ranked by pre-OOP welfare.}",
            "\\end{table}",
        ]
    )
    return "\n".join(lines)


def scope_section(scope: str) -> str:
    lower = scope.lower()
    box1 = pd.read_csv(CH18 / lower / f"{lower}_box18_1_incidence_intensity.csv")
    box2 = pd.read_csv(CH18 / lower / f"{lower}_box18_2_distribution_sensitive.csv")
    curve = f"{lower}/{lower}_budget_share_curve"

    if scope == "OOPG":
        scope_text = "OOPG refers to out-of-pocket spending on communicable disease or injury from NLSS Section 8(B)."
        narrow_text = (
            "It is the narrower health-payment concept in this report, so it captures an acute "
            "communicable/injury-related burden rather than the full household health-payment burden."
        )
        h10_compare = ""
    else:
        scope_text = "OOP combines OOPG with NCD spending converted from annual to monthly terms."
        narrow_text = (
            "It is the broader health-payment concept in this report and therefore captures more of the "
            "household financial burden created by health care."
        )
        h10_compare = (
            " This is much larger than the corresponding OOPG estimate, showing how strongly NCD "
            "spending changes the picture."
        )

    h10 = pct(value(box1, "total", 10, "headcount"))
    o10 = pct(value(box1, "total", 10, "overshoot"))
    mpo10 = pct(value(box1, "total", 10, "mpo"))
    h_nf40 = pct(value(box1, "nonfood", 40, "headcount"))
    h_total15 = pct(value(box1, "total", 15, "headcount"))
    h_nf15 = pct(value(box1, "nonfood", 15, "headcount"))
    ci5 = num(value(box2, "total", 5, "concentration_headcount"))
    ci25 = num(value(box2, "total", 25, "concentration_headcount"))
    rw10 = pct(value(box2, "total", 10, "rank_weighted_headcount"))
    ci_nf15 = num(value(box2, "nonfood", 15, "concentration_headcount"))

    return rf"""
\clearpage
\section*{{{scope}: Catastrophic Payment Results}}

{scope_text} {narrow_text} The purpose of this section is to read the Chapter 18
measures in sequence: first whether households cross the catastrophic threshold,
then how far they cross it, and finally where that burden falls in the welfare
distribution.

\subsection*{{Incidence and intensity}}

Table 1 for {scope} answers two linked questions. The head count, $H$, asks how
many households cross each threshold. The overshoot, $O$, asks how far the
population lies above the threshold on average. The mean positive overshoot,
MPO, then focuses only on households that crossed the threshold.

{incidence_table(lower, box1)}

At the 10\% total-expenditure threshold, {h10} of households experience
catastrophic {scope} spending.{h10_compare} At the stricter 40\%
capacity-to-pay threshold, the head count is {h_nf40}. The 10\% total-
expenditure overshoot is {o10}, while the MPO is {mpo10}. This means that among
households crossing the 10\% threshold, average spending is not just slightly
above the threshold; it exceeds the threshold by the MPO amount.

The nonfood denominator gives a stricter view of financial burden because it is
based on nonfood expenditure with health payments added back. For
{scope}, the 15\% total-expenditure head count is {h_total15}, while the 15\%
nonfood-expenditure head count is {h_nf15}. The same health payment therefore
appears more burdensome when measured against the household's nonfood capacity.

\subsection*{{Budget-share curve}}

The budget-share curve is the visual counterpart to the incidence table.
Households are ranked from left to right by decreasing health-payment budget
share. The vertical axis shows the health-payment share. The upper curve uses
nonfood expenditure as the denominator, and the lower curve uses total
expenditure.

\begin{{figure}}[H]
\centering
\includegraphics[width=0.88\textwidth,height=0.54\textheight,keepaspectratio]{{{curve}.png}}
\caption{{{scope} budget-share curve. Households are ranked by decreasing health-payment budget share.}}
\end{{figure}}

The steep left-hand side of the curve shows that the highest budget shares are
concentrated among a relatively small group of households. The nonfood curve
lies above the total-expenditure curve because food spending is excluded from
the nonfood denominator. This is why the nonfood head counts in the table are
higher at comparable thresholds.

\subsection*{{Distribution-sensitive measures}}

Chapter 18 then asks whether catastrophic payments are concentrated among poorer
or better-off households. The concentration index is the key statistic here. A
negative value means the burden is concentrated among poorer households, a
positive value means it is concentrated among better-off households, and a value
near zero means the burden is more evenly spread.

{distribution_table(lower, box2)}

For {scope}, the concentration index for the 5\% total-expenditure head count is
{ci5}, which is close to zero. At the 25\% total-expenditure threshold, it rises
to {ci25}. This pattern means that higher-threshold catastrophic payments are
more concentrated among better-off households. This should not be interpreted as
poor households being protected. It may instead reflect lower ability among poor
households to obtain and pay for expensive treatment.

The rank-weighted head count adjusts the ordinary head count for this
distributional pattern. At the 10\% total-expenditure threshold, the rank-
weighted head count is {rw10}. Under the nonfood denominator, the
15\% concentration index is {ci_nf15}, showing how the equity interpretation can
change when the denominator focuses on nonfood capacity rather than total
expenditure.
"""


def main() -> None:
    tex = rf"""\documentclass[11pt]{{article}}

\usepackage[margin=0.78in]{{geometry}}
\usepackage{{array}}
\usepackage{{booktabs}}
\usepackage{{graphicx}}
\usepackage{{float}}

\renewcommand{{\arraystretch}}{{1.18}}
\setlength{{\parindent}}{{0pt}}
\setlength{{\parskip}}{{6pt}}

\title{{\textbf{{Chapter 18 Catastrophic Payment Results}}\\
\large OOPG and OOP, Nepal NLSS IV 2022/23}}
\author{{Arpan's calculations from NLSS IV}}
\date{{}}

\begin{{document}}
\maketitle

\section*{{Purpose of This Chapter 18 Output}}

This report follows Chapter 18 of \emph{{Analyzing Health Equity Using Household
Survey Data}}. The chapter studies catastrophic health payments by combining
three ideas: incidence, intensity, and distribution. Incidence asks whether a
household crosses a catastrophic threshold. Intensity asks how far beyond the
threshold the household goes. Distribution-sensitive measures ask whether the
burden is concentrated among poorer or better-off households.

The report applies these ideas to two household out-of-pocket payment scopes.
\textbf{{OOPG}} is out-of-pocket spending on communicable disease or injury from
NLSS Section 8(B). \textbf{{OOP}} adds NCD out-of-pocket spending to OOPG after
converting the NCD amount from annual to monthly terms. The two scopes are shown
side by side because OOPG captures a narrower acute burden, while OOP captures a
broader household health-payment burden.

The estimates use household survey weights. The primary total-expenditure
denominator is reconstructed monthly nominal household consumption with
OOPG/general health spending added back. The primary nonfood denominator is real
monthly household nonfood consumption with OOPG added back.
Distribution-sensitive measures rank households by pre-OOP welfare.

{scope_section("OOPG")}

{scope_section("OOP")}

\clearpage
\section*{{Overall Lesson}}

The central lesson is that catastrophic health spending is visible under both
definitions, but the burden is much larger when NCD spending is included. OOPG
identifies the communicable/injury-related part of the problem. OOP shows the
broader financing burden faced by households. For the paper, OOP should carry
the main headline result, while OOPG should be used as a narrower comparison
that helps show how much of the burden is added when NCD payments are included.

The equity interpretation also requires care. Positive concentration indices at
higher thresholds show that the most extreme measured payments are more common
among better-off households. In a health-financing setting, this can reflect
greater ability to seek and pay for care, not necessarily lower need among poor
households. This point connects naturally to the next step, Chapter 19, where we
study whether health payments are associated with impoverishment.

\end{{document}}
"""
    TEX.write_text(tex, encoding="utf-8")
    print(f"Saved: {TEX}")


if __name__ == "__main__":
    main()
