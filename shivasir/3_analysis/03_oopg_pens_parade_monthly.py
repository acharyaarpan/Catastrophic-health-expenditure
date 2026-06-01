"""Build no-addback monthly OOPG Pen's Parade data and figure.

This is scoped to the Shiva sir rerun. Impoverishment uses monthly
per-capita welfare:

    pre-OOPG welfare  = pcep / 12
    OOPG              = (monthly household oopg / hhsize) / paasche
    raw post-OOPG     = pre-OOPG welfare - OOPG
    post-OOPG welfare = max(raw post-OOPG, 0)

Outputs are written under:
    6_output/main_output/manuscript/pictures/
    6_output/main_output/manuscript/tables/
"""

from __future__ import annotations

import json
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DATA_PATH = PROJECT_ROOT / "1_data" / "2_clean" / "oopg_analysis_base.dta"
OUT = PROJECT_ROOT / "6_output" / "main_output" / "manuscript"
TABLES = OUT / "tables"
PICTURES = OUT / "pictures"

FIG_PNG = PICTURES / "oopg_pens_parade_noadd_monthly.png"
FIG_PDF = PICTURES / "oopg_pens_parade_noadd_monthly.pdf"
DATA_CSV = TABLES / "oopg_pens_parade_monthly_data.csv"
EXCEL_JSON = TABLES / "oopg_pens_parade_monthly_workbook_data.json"
SUMMARY_JSON = TABLES / "oopg_pens_parade_monthly_summary.json"


def wmean(values: pd.Series | np.ndarray, weights: pd.Series | np.ndarray) -> float:
    v = np.asarray(values, dtype=float)
    w = np.asarray(weights, dtype=float)
    return float(np.sum(v * w) / np.sum(w))


def main() -> None:
    TABLES.mkdir(parents=True, exist_ok=True)
    PICTURES.mkdir(parents=True, exist_ok=True)
    assert DATA_PATH.exists(), f"Missing analysis dataset: {DATA_PATH}"

    df = pd.read_stata(DATA_PATH, convert_categoricals=False)
    required = [
        "psu_number",
        "hh_number",
        "prov",
        "domain",
        "ad_4",
        "hhsize",
        "hhs_wt",
        "ind_wt",
        "pcep",
        "pcep_mo_real",
        "pline",
        "pline_mo_real",
        "paasche",
        "oopg",
        "oopg_pc_mo_real",
        "pre_oopg",
        "post_oopg",
        "post_oopg_zero_floor",
    ]
    missing = [col for col in required if col not in df.columns]
    assert not missing, f"Missing required columns in {DATA_PATH}: {missing}"
    assert len(df) == 9600, f"Expected 9,600 households, found {len(df):,}"

    work = df[required].copy()
    numeric = [
        "hhsize",
        "hhs_wt",
        "ind_wt",
        "pcep",
        "pcep_mo_real",
        "pline",
        "pline_mo_real",
        "paasche",
        "oopg",
        "oopg_pc_mo_real",
        "pre_oopg",
        "post_oopg",
        "post_oopg_zero_floor",
    ]
    for col in numeric:
        work[col] = work[col].astype(float)

    work["raw_post_oopg_mo_real"] = work["pcep_mo_real"] - work["oopg_pc_mo_real"]
    work["negative_raw_post_oopg"] = work["raw_post_oopg_mo_real"] < 0
    work["post_oopg_mo_real_floored"] = work["raw_post_oopg_mo_real"].clip(lower=0)

    assert np.allclose(work["pre_oopg"], work["pcep_mo_real"])
    assert np.allclose(work["post_oopg"], work["post_oopg_mo_real_floored"])

    work["pre_poverty_multiple"] = work["pre_oopg"] / work["pline_mo_real"]
    work["post_poverty_multiple"] = work["post_oopg"] / work["pline_mo_real"]
    work["poor_pre_oopg"] = work["pre_oopg"] < work["pline_mo_real"]
    work["poor_post_oopg"] = work["post_oopg"] < work["pline_mo_real"]
    work["pushed_below_poverty_oopg"] = (
        (work["pre_oopg"] >= work["pline_mo_real"])
        & (work["post_oopg"] < work["pline_mo_real"])
    )

    sort_cols = ["pre_oopg", "psu_number", "hh_number"]
    sorted_work = work.sort_values(sort_cols).reset_index(drop=True)
    sorted_work["rank_pre_oopg"] = np.arange(1, len(sorted_work) + 1)
    sorted_work["cum_population_share"] = (
        sorted_work["ind_wt"].cumsum() / sorted_work["ind_wt"].sum() * 100
    )

    pre_poverty = 100 * wmean(sorted_work["poor_pre_oopg"], sorted_work["ind_wt"])
    post_poverty = 100 * wmean(sorted_work["poor_post_oopg"], sorted_work["ind_wt"])
    change_pp = post_poverty - pre_poverty
    people_pushed = float(
        sorted_work.loc[sorted_work["pushed_below_poverty_oopg"], "ind_wt"].sum()
    )
    households_pushed = int(sorted_work["pushed_below_poverty_oopg"].sum())
    negative_raw_count = int(sorted_work["negative_raw_post_oopg"].sum())

    summary = {
        "households": int(len(sorted_work)),
        "pre_oopg_poverty_pct": pre_poverty,
        "post_oopg_poverty_pct": post_poverty,
        "poverty_change_pp": change_pp,
        "people_pushed": people_pushed,
        "households_pushed": households_pushed,
        "negative_raw_post_oopg_households": negative_raw_count,
        "mean_pre_oopg_mo_real": wmean(sorted_work["pre_oopg"], sorted_work["ind_wt"]),
        "mean_oopg_pc_mo_real": wmean(
            sorted_work["oopg_pc_mo_real"], sorted_work["ind_wt"]
        ),
        "mean_post_oopg_mo_real_floored": wmean(
            sorted_work["post_oopg"], sorted_work["ind_wt"]
        ),
        "mean_pline_mo_real": wmean(sorted_work["pline_mo_real"], sorted_work["ind_wt"]),
    }

    # Keep audit columns plain and filter-friendly for Excel.
    audit_cols = [
        "psu_number",
        "hh_number",
        "prov",
        "domain",
        "ad_4",
        "hhsize",
        "hhs_wt",
        "ind_wt",
        "pcep_mo_real",
        "pline_mo_real",
        "oopg",
        "oopg_pc_mo_real",
        "raw_post_oopg_mo_real",
        "post_oopg_mo_real_floored",
        "negative_raw_post_oopg",
        "pre_poverty_multiple",
        "post_poverty_multiple",
        "poor_pre_oopg",
        "poor_post_oopg",
        "pushed_below_poverty_oopg",
        "rank_pre_oopg",
        "cum_population_share",
        "paasche",
        "pcep",
        "pline",
    ]
    audit = sorted_work[audit_cols].copy()
    audit.to_csv(DATA_CSV, index=False)

    payload = {
        "summary": summary,
        "data": audit.to_dict(orient="records"),
        "negative_rows": audit[audit["negative_raw_post_oopg"]].to_dict(
            orient="records"
        ),
        "fields": audit_cols,
        "notes": [
            "All welfare values used for impoverishment are monthly, real, per capita.",
            "pre_oopg = pcep_mo_real = pcep / 12.",
            "oopg_pc_mo_real = (oopg / hhsize) / paasche.",
            "raw_post_oopg_mo_real = pcep_mo_real - oopg_pc_mo_real.",
            "post_oopg_mo_real_floored = max(raw_post_oopg_mo_real, 0).",
            "Use negative_raw_post_oopg to filter households where raw post-OOPG welfare is negative.",
        ],
    }
    SUMMARY_JSON.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    EXCEL_JSON.write_text(json.dumps(payload), encoding="utf-8")

    x = sorted_work["cum_population_share"].to_numpy()
    pre = sorted_work["pre_poverty_multiple"].to_numpy()
    post = sorted_work["post_poverty_multiple"].to_numpy()
    pushed = sorted_work["pushed_below_poverty_oopg"].to_numpy(dtype=bool)

    y_cap = max(2.0, min(5.0, float(np.nanpercentile(pre, 97.5))))
    plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 10})
    fig, ax = plt.subplots(figsize=(11.2, 6.5), facecolor="white")
    ax.set_facecolor("white")
    ax.vlines(x, post, pre, color="#b8b8b8", alpha=0.38, lw=0.55, zorder=1)
    ax.vlines(
        x[pushed],
        post[pushed],
        pre[pushed],
        color="#c0392b",
        alpha=0.72,
        lw=0.75,
        zorder=2,
        label="Households pushed below poverty line",
    )
    ax.plot(x, pre, color="#1f77b4", lw=1.45, label="Pre-OOPG welfare", zorder=3)
    ax.plot(
        x,
        post,
        color="#d95f02",
        lw=1.05,
        label="Post-OOPG welfare, zero floor",
        zorder=4,
    )
    ax.axhline(1, color="#222222", lw=1.2, ls="--", label="Poverty line = 1")
    ax.set_xlim(0, 100)
    ax.set_ylim(0, y_cap)
    ax.set_xlabel("Cumulative population share (%) sorted by pre-OOPG welfare")
    ax.set_ylabel("Monthly per-capita welfare as a multiple of monthly poverty line")
    ax.set_title(
        "OOPG Pen's Parade, No-Addback Monthly Per-Capita Scenario\n"
        "Nepal NLSS IV 2022/23",
        loc="left",
        fontsize=12,
        pad=10,
    )
    ax.grid(True, axis="y", alpha=0.25, lw=0.6)
    ax.grid(False, axis="x")
    ax.spines[["top", "right"]].set_visible(False)
    ax.legend(loc="upper left", frameon=True, framealpha=0.95, fontsize=8.6)
    note = (
        f"Pre poverty: {pre_poverty:.2f}%; post poverty: {post_poverty:.2f}%; "
        f"change: {change_pp:+.2f} pp. "
        f"People pushed: {people_pushed:,.0f}; households pushed: {households_pushed}. "
        f"{negative_raw_count} households have raw post-OOPG welfare below zero. "
        f"Y-axis capped at {y_cap:.1f} poverty-line multiples for readability."
    )
    fig.text(0.02, 0.01, note, ha="left", va="bottom", fontsize=8.2, color="#444444")
    fig.tight_layout(rect=(0, 0.05, 1, 1))
    fig.savefig(FIG_PNG, dpi=220, bbox_inches="tight", facecolor="white")
    fig.savefig(FIG_PDF, bbox_inches="tight", facecolor="white")
    plt.close(fig)

    print(f"Saved: {FIG_PNG}")
    print(f"Saved: {FIG_PDF}")
    print(f"Saved: {DATA_CSV}")
    print(f"Saved: {EXCEL_JSON}")
    print(f"Saved: {SUMMARY_JSON}")
    print(
        "Summary: "
        f"pre={pre_poverty:.2f}%, post={post_poverty:.2f}%, "
        f"change={change_pp:+.2f} pp, negative raw post={negative_raw_count}"
    )


if __name__ == "__main__":
    main()
