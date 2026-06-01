"""
Create Chapter 18-style OOPG budget-share figure and audit outputs.

Inputs:
    6_output/main_output/chapter18/oopg/oopg_box18_1_incidence_intensity.csv
    6_output/main_output/chapter18/oopg/oopg_box18_2_distribution_sensitive.csv
    1_data/2_clean/catastrophic_health_exp.dta

Outputs:
    6_output/main_output/chapter18/oopg/oopg_budget_share_curve.png/.pdf
    6_output/main_output/chapter18/oopg/oopg_chapter18_results.xlsx
    6_output/main_output/chapter18/oopg/oopg_chapter18_results.md
"""

from __future__ import annotations

from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from matplotlib.ticker import FormatStrFormatter


PROJECT_ROOT = Path(__file__).resolve().parents[1]
OUT = PROJECT_ROOT / "6_output" / "main_output" / "chapter18" / "oopg"
DATA_PATH = PROJECT_ROOT / "1_data" / "2_clean" / "catastrophic_health_exp.dta"
BOX1_CSV = OUT / "oopg_box18_1_incidence_intensity.csv"
BOX2_CSV = OUT / "oopg_box18_2_distribution_sensitive.csv"

THRESHOLDS = [5, 10, 15, 25, 40]
BG = "#ffffff"
LINE = "#3b4b37"
LIGHT_LINE = "#819477"
HEADER = "#243321"


def pct(x: float, digits: int = 2) -> str:
    if pd.isna(x):
        return "—"
    return f"{x * 100:.{digits}f}%"


def num(x: float, digits: int = 4) -> str:
    if pd.isna(x):
        return "—"
    return f"{x:.{digits}f}"


def get_row(df: pd.DataFrame, denominator: str, threshold: int) -> pd.Series | None:
    hit = df[(df["denominator"] == denominator) & (df["threshold"] == threshold)]
    if hit.empty:
        return None
    return hit.iloc[0]


def box1_table_data(box1: pd.DataFrame) -> list[list[str]]:
    rows: list[list[str]] = []
    rows.append(["OOPG as share of total expenditure", "", "", "", "", ""])
    for metric, col in [
        ("Head count (H)", "headcount"),
        ("standard error", "headcount_se"),
        ("Overshoot (O)", "overshoot"),
        ("standard error", "overshoot_se"),
        ("Mean positive overshoot (MPO)", "mpo"),
    ]:
        row = [metric]
        for z in THRESHOLDS:
            r = get_row(box1, "total", z)
            row.append(pct(float(r[col])) if r is not None else "—")
        rows.append(row)

    rows.append(["As share of capacity-to-pay expenditure", "", "", "", "", ""])
    for metric, col in [
        ("Head count (H)", "headcount"),
        ("standard error", "headcount_se"),
        ("Overshoot (O)", "overshoot"),
        ("standard error", "overshoot_se"),
        ("Mean positive overshoot (MPO)", "mpo"),
    ]:
        row = [metric]
        for z in THRESHOLDS:
            r = get_row(box1, "nonfood", z)
            row.append(pct(float(r[col])) if r is not None else "—")
        rows.append(row)
    return rows


def box2_table_data(box2: pd.DataFrame) -> list[list[str]]:
    rows: list[list[str]] = []
    rows.append(["OOPG as share of total expenditure", "", "", "", "", ""])
    for metric, col, is_pct in [
        ("Concentration index, C^H", "concentration_headcount", False),
        ("Rank-weighted head count, H^W", "rank_weighted_headcount", True),
        ("Concentration index, C^O", "concentration_overshoot", False),
        ("Rank-weighted overshoot, O^W", "rank_weighted_overshoot", True),
    ]:
        row = [metric]
        for z in THRESHOLDS:
            r = get_row(box2, "total", z)
            row.append(pct(float(r[col])) if is_pct and r is not None else (num(float(r[col])) if r is not None else "—"))
        rows.append(row)

    rows.append(["As share of capacity-to-pay expenditure", "", "", "", "", ""])
    for metric, col, is_pct in [
        ("Concentration index, C^H", "concentration_headcount", False),
        ("Rank-weighted head count, H^W", "rank_weighted_headcount", True),
        ("Concentration index, C^O", "concentration_overshoot", False),
        ("Rank-weighted overshoot, O^W", "rank_weighted_overshoot", True),
    ]:
        row = [metric]
        for z in THRESHOLDS:
            r = get_row(box2, "nonfood", z)
            row.append(pct(float(r[col])) if is_pct and r is not None else (num(float(r[col])) if r is not None else "—"))
        rows.append(row)
    return rows


def style_table(table, header_rows: set[int]) -> None:
    for (row, col), cell in table.get_celld().items():
        cell.set_edgecolor("#6d7a63")
        cell.set_linewidth(0.55)
        cell.set_facecolor(BG)
        cell.PAD = 0.035
        text = cell.get_text()
        text.set_fontsize(8.8)
        text.set_color("#111111")
        if row == 0:
            cell.set_facecolor("#e8eee4")
            text.set_fontweight("bold")
        if row in header_rows:
            text.set_fontstyle("italic")
            text.set_fontweight("normal")
            cell.set_facecolor("#f4f7f2")
            if col > 0:
                text.set_text("")
        if col == 0:
            text.set_ha("left")
        else:
            text.set_ha("right")


def weighted_curve(df: pd.DataFrame, share_col: str) -> tuple[np.ndarray, np.ndarray]:
    sub = df[[share_col, "hhs_wt"]].dropna().copy()
    sub = sub[sub["hhs_wt"] > 0]
    sub = sub.sort_values(share_col, ascending=False)
    w = sub["hhs_wt"].to_numpy(dtype=float)
    y = sub[share_col].to_numpy(dtype=float)
    x = np.cumsum(w) / w.sum()
    return np.r_[0, x], np.r_[y[0], y]


def make_budget_share_curve(df: pd.DataFrame) -> None:
    fig, ax = plt.subplots(figsize=(7.0, 4.8), facecolor=BG)
    ax.set_facecolor(BG)

    x_tot, y_tot = weighted_curve(df, "oopg_sh_tot")
    x_nf, y_nf = weighted_curve(df, "oopg_sh_nf")
    curve_data = pd.DataFrame(
        {
            "cum_hh_total": pd.Series(x_tot),
            "oopg_share_total": pd.Series(y_tot),
            "cum_hh_ctp": pd.Series(x_nf),
            "oopg_share_ctp": pd.Series(y_nf),
        }
    )
    curve_data.to_csv(OUT / "oopg_budget_share_curve_data.csv", index=False)

    ax.plot(x_nf, y_nf, color=LINE, lw=1.35)
    ax.plot(x_tot, y_tot, color=LIGHT_LINE, lw=1.05)
    ax.set_xlim(0, 1)
    ax.set_ylim(0, 1.0)
    ax.set_xlabel("cumulative proportion of households ranked by decreasing\nhealth payments budget share", fontsize=9)
    ax.set_ylabel("OOPG budget share", fontsize=9)
    ax.xaxis.set_major_formatter(FormatStrFormatter("%.1f"))
    ax.yaxis.set_major_formatter(FormatStrFormatter("%.1f"))
    ax.tick_params(labelsize=8.5)
    ax.spines[["top", "right"]].set_visible(False)
    ax.spines[["bottom", "left"]].set_color("#394535")
    ax.grid(False)
    ax.text(0.19, 0.30, "OOPG/nonfood exp.", fontsize=9.2, color="#222222")
    ax.text(0.05, 0.05, "OOPG/total exp.", fontsize=9.2, color="#222222")
    ax.set_title(
        "OOPG Total and Nonfood Budget Share against Cumulative Percentage\n"
        "of Households Ranked by Decreasing Budget Share, Nepal NLSS IV 2022/23",
        fontsize=9.5,
        fontstyle="italic",
        loc="left",
        pad=12,
    )

    fig.savefig(OUT / "oopg_budget_share_curve.png", dpi=240, bbox_inches="tight", facecolor=BG)
    fig.savefig(OUT / "oopg_budget_share_curve.pdf", bbox_inches="tight", facecolor=BG)
    plt.close(fig)


def make_box1(box1: pd.DataFrame, df: pd.DataFrame) -> None:
    fig = plt.figure(figsize=(7.8, 10.2), facecolor=BG)
    gs = fig.add_gridspec(nrows=2, ncols=1, height_ratios=[1.12, 1.0], hspace=0.16)

    ax_table = fig.add_subplot(gs[0])
    ax_table.set_facecolor(BG)
    ax_table.axis("off")
    ax_table.text(
        0.0,
        1.04,
        "Box 18.1-style OOPG Results",
        transform=ax_table.transAxes,
        fontsize=11.5,
        fontweight="bold",
        color=HEADER,
    )
    ax_table.text(
        0.0,
        0.995,
        "Incidence and Intensity of Catastrophic OOPG Payments, Nepal NLSS IV 2022/23\n"
        "Defined with Respect to Total and Capacity-to-Pay Expenditure, Various Thresholds",
        transform=ax_table.transAxes,
        fontsize=9.4,
        fontstyle="italic",
        color="#1a1a1a",
        va="top",
    )

    headers = ["Catastrophic payment measure", "5%", "10%", "15%", "25%", "40%"]
    table = ax_table.table(
        cellText=box1_table_data(box1),
        colLabels=headers,
        loc="upper left",
        cellLoc="right",
        bbox=[0, 0.04, 1.0, 0.78],
        colWidths=[0.45, 0.11, 0.11, 0.11, 0.11, 0.11],
    )
    table.auto_set_font_size(False)
    style_table(table, header_rows={1, 7})

    ax = fig.add_subplot(gs[1])
    ax.set_facecolor(BG)
    x_tot, y_tot = weighted_curve(df, "oopg_sh_tot")
    x_nf, y_nf = weighted_curve(df, "oopg_sh_nf")
    curve_data = pd.DataFrame(
        {
            "cum_hh_total": pd.Series(x_tot),
            "oopg_share_total": pd.Series(y_tot),
            "cum_hh_ctp": pd.Series(x_nf),
            "oopg_share_ctp": pd.Series(y_nf),
        }
    )
    curve_data.to_csv(OUT / "oopg_budget_share_curve_data.csv", index=False)

    ax.plot(x_nf, y_nf, color=LINE, lw=1.35)
    ax.plot(x_tot, y_tot, color=LIGHT_LINE, lw=1.05)
    ax.set_xlim(0, 1)
    ax.set_ylim(0, 1.0)
    ax.set_xlabel("cumulative proportion of households ranked by decreasing\nhealth payments budget share", fontsize=9)
    ax.set_ylabel("OOPG budget share", fontsize=9)
    ax.xaxis.set_major_formatter(FormatStrFormatter("%.1f"))
    ax.yaxis.set_major_formatter(FormatStrFormatter("%.1f"))
    ax.tick_params(labelsize=8.5)
    ax.spines[["top", "right"]].set_visible(False)
    ax.spines[["bottom", "left"]].set_color("#394535")
    ax.grid(False)
    ax.text(0.19, 0.30, "OOPG/capacity-to-pay exp.", fontsize=9.2, color="#222222")
    ax.text(0.05, 0.05, "OOPG/total exp.", fontsize=9.2, color="#222222")
    ax.set_title(
        "OOPG Total and Capacity-to-Pay Budget Share against Cumulative Percentage\n"
        "of Households Ranked by Decreasing Budget Share, Nepal NLSS IV 2022/23",
        fontsize=9.5,
        fontstyle="italic",
        loc="left",
        pad=12,
    )

    fig.savefig(OUT / "oopg_box18_1_incidence_intensity_white.png", dpi=240, bbox_inches="tight", facecolor=BG)
    fig.savefig(OUT / "oopg_box18_1_incidence_intensity_white.pdf", bbox_inches="tight", facecolor=BG)
    plt.close(fig)


def make_box2(box2: pd.DataFrame) -> None:
    fig = plt.figure(figsize=(7.4, 6.3), facecolor=BG)
    ax = fig.add_subplot(111)
    ax.set_facecolor(BG)
    ax.axis("off")
    ax.text(
        0.0,
        1.03,
        "Box 18.2-style Distribution-Sensitive OOPG Measures",
        transform=ax.transAxes,
        fontsize=11.5,
        fontweight="bold",
        color=HEADER,
    )
    ax.text(
        0.0,
        0.965,
        "Distribution-sensitive catastrophic payment measures use household weights and rank households by pre-OOP welfare.",
        transform=ax.transAxes,
        fontsize=9.3,
        color="#111111",
        va="top",
        wrap=True,
    )
    headers = ["Distribution-sensitive measure", "5%", "10%", "15%", "25%", "40%"]
    table = ax.table(
        cellText=box2_table_data(box2),
        colLabels=headers,
        loc="upper left",
        cellLoc="right",
        bbox=[0, 0.08, 1.0, 0.78],
        colWidths=[0.47, 0.106, 0.106, 0.106, 0.106, 0.106],
    )
    table.auto_set_font_size(False)
    style_table(table, header_rows={1, 6})
    ax.text(0.02, 0.035, "Source: NLSS IV; authors' calculations.", transform=ax.transAxes, fontsize=8.2, fontstyle="italic")

    fig.savefig(OUT / "oopg_box18_2_distribution_sensitive_white.png", dpi=240, bbox_inches="tight", facecolor=BG)
    fig.savefig(OUT / "oopg_box18_2_distribution_sensitive_white.pdf", bbox_inches="tight", facecolor=BG)
    plt.close(fig)


def write_excel_and_summary(box1: pd.DataFrame, box2: pd.DataFrame) -> None:
    with pd.ExcelWriter(OUT / "oopg_chapter18_results.xlsx", engine="openpyxl") as writer:
        box1.to_excel(writer, sheet_name="box18_1_long", index=False)
        box2.to_excel(writer, sheet_name="box18_2_long", index=False)
        pd.DataFrame(box1_table_data(box1), columns=["measure", *[f"{z}%" for z in THRESHOLDS]]).to_excel(
            writer, sheet_name="box18_1_formatted", index=False
        )
        pd.DataFrame(box2_table_data(box2), columns=["measure", *[f"{z}%" for z in THRESHOLDS]]).to_excel(
            writer, sheet_name="box18_2_formatted", index=False
        )

    total10 = get_row(box1, "total", 10)
    nf40 = get_row(box1, "nonfood", 40)
    total10_ci = get_row(box2, "total", 10)
    nf40_ci = get_row(box2, "nonfood", 40)
    md = f"""# Chapter 18 OOPG Results

Scope: OOPG, defined as NLSS Section 8(B) communicable disease/injury out-of-pocket spending.

Weighting: household survey weights (`hhs_wt`), matching the household-level Chapter 18 presentation.

Primary denominator convention: reconstructed nominal total consumption plus OOPG for total-expenditure CHE; real nonfood consumption plus OOPG for nonfood CHE.

## Key OOPG Findings

- OOPG > 10% of total expenditure: {pct(float(total10['headcount']))}; overshoot: {pct(float(total10['overshoot']))}; MPO: {pct(float(total10['mpo']))}.
- OOPG > 40% of nonfood expenditure: {pct(float(nf40['headcount']))}; overshoot: {pct(float(nf40['overshoot']))}; MPO: {pct(float(nf40['mpo']))}.
- Concentration index for OOPG > 10% of total expenditure: {num(float(total10_ci['concentration_headcount']))}; rank-weighted headcount: {pct(float(total10_ci['rank_weighted_headcount']))}.
- Concentration index for OOPG > 40% of nonfood expenditure: {num(float(nf40_ci['concentration_headcount']))}; rank-weighted headcount: {pct(float(nf40_ci['rank_weighted_headcount']))}.

## Files

- `oopg_box18_1_incidence_intensity.csv`
- `oopg_box18_1_incidence_intensity_white.png`
- `oopg_box18_1_incidence_intensity_white.pdf`
- `oopg_box18_2_distribution_sensitive.csv`
- `oopg_box18_2_distribution_sensitive_white.png`
- `oopg_box18_2_distribution_sensitive_white.pdf`
- `oopg_budget_share_curve_data.csv`
- `oopg_chapter18_results.xlsx`
"""
    (OUT / "oopg_chapter18_results.md").write_text(md, encoding="utf-8")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    box1 = pd.read_csv(BOX1_CSV)
    box2 = pd.read_csv(BOX2_CSV)
    df = pd.read_stata(DATA_PATH, convert_categoricals=False)
    assert len(df) == 9600
    assert (df["oop"] + 1e-9 >= df["oopg"]).all()

    make_budget_share_curve(df)
    write_excel_and_summary(box1, box2)
    print(f"Saved Chapter 18 OOPG outputs to {OUT}")


if __name__ == "__main__":
    main()
