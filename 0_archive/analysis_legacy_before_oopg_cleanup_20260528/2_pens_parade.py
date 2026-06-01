"""
3_analysis/2_pens_parade.py

Pen's Parade for Nepal NLSS IV (2022/23)
========================================

Two-panel figure:
    Top    : Pen's Parade of monthly per-AE consumption, with oopg/OOP CHE
             households marked.
    Bottom : oopg and OOP as shares of monthly total household consumption,
             smoothed by population percentile.

Conventions
-----------
- Welfare measure: monthly per-AE consumption (`pc_cons_ae / 12`).
- Population frame: cumulative x-axis uses `ind_wt`.
- oopg: Section 8B communicable disease/injury OOP, monthly household amount.
- OOP: oopg plus monthly NCD OOP.
- CHE markers use the 10% total-consumption threshold.

Outputs
-------
6_output/main_output/pens_parade.pdf
6_output/main_output/pens_parade.png
"""

from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from matplotlib.ticker import FuncFormatter, PercentFormatter


_DATA_REL = Path("1_data") / "2_clean" / "catastrophic_health_exp.dta"


def _find_project_root() -> Path:
    cand = Path.cwd().resolve()
    for _ in range(6):
        if (cand / _DATA_REL).exists():
            return cand
        if (cand / "consumption" / _DATA_REL).exists():
            return cand / "consumption"
        if cand == cand.parent:
            break
        cand = cand.parent
    raise FileNotFoundError(
        f"Could not locate project data file ({_DATA_REL}) from {Path.cwd()}."
    )


try:
    PROJECT_ROOT = Path(__file__).resolve().parents[1]
except NameError:
    PROJECT_ROOT = _find_project_root()

DATA_PATH = PROJECT_ROOT / "1_data" / "2_clean" / "catastrophic_health_exp.dta"
OUT_DIR = PROJECT_ROOT / "6_output" / "main_output"
OUT_DIR.mkdir(parents=True, exist_ok=True)

assert DATA_PATH.exists(), f"Missing data: {DATA_PATH}"


df = pd.read_stata(DATA_PATH, convert_categoricals=False)

assert len(df) == 9600, f"Expected 9,600 households, found {len(df):,}"
assert (df["oop"].astype(float) + 1e-9 >= df["oopg"].astype(float)).all()

welfare_month = df["pc_cons_ae"].astype(float) / 12.0
hhsize = df["hhsize"].astype(float)
ae = df["adult_equiv"].astype(float)
pline_month = df["pline"].astype(float) / 12.0
ind_wt = df["ind_wt"].astype(float)

# This visualization retains the original Pen's Parade budget-share convention:
# health payments over NLSS monthly consumption excluding health.
oopg_share = df["oopg_sh_tot_nlss"].astype(float)
oop_share = df["oop_sh_tot_nlss"].astype(float)
oopg_share_plot = np.minimum(oopg_share.to_numpy(), 1.0)
oop_share_plot = np.minimum(oop_share.to_numpy(), 1.0)

che_oopg10 = df["che_oopg_tot10_nlss"].astype(float)
che_oop10 = df["che_oop_tot10_nlss"].astype(float)

ae_pline_month_per_hh = pline_month * hhsize / ae
ae_pline_month = np.average(ae_pline_month_per_hh, weights=ind_wt)

mask = (
    welfare_month.notna()
    & ind_wt.notna()
    & oopg_share.notna()
    & oop_share.notna()
    & (ind_wt > 0)
).to_numpy()

welfare = welfare_month.to_numpy()[mask]
w = ind_wt.to_numpy()[mask]
oopg_s_raw = oopg_share.to_numpy()[mask]
oop_s_raw = oop_share.to_numpy()[mask]
oopg_s_plot = oopg_share_plot[mask]
oop_s_plot = oop_share_plot[mask]
che_oopg = che_oopg10.to_numpy()[mask]
che_oop = che_oop10.to_numpy()[mask]

order = np.argsort(welfare)
welfare_s = welfare[order]
w_s = w[order]
oopg_s_raw = oopg_s_raw[order]
oop_s_raw = oop_s_raw[order]
oopg_s_plot = oopg_s_plot[order]
oop_s_plot = oop_s_plot[order]
che_oopg_s = che_oopg[order]
che_oop_s = che_oop[order]

cum_share = np.cumsum(w_s) / w_s.sum() * 100.0
mean_welfare_month = np.average(welfare_s, weights=w_s)


def weighted_running_mean(x, weights, cum_x_pct, window_pct=2.0):
    n = len(x)
    out = np.empty(n)
    half = window_pct / 2.0
    left = 0
    right = 0
    sum_xw = 0.0
    sum_w = 0.0
    for i in range(n):
        lo = cum_x_pct[i] - half
        hi = cum_x_pct[i] + half
        while left < n and cum_x_pct[left] < lo:
            sum_xw -= x[left] * weights[left]
            sum_w -= weights[left]
            left += 1
        while right < n and cum_x_pct[right] <= hi:
            sum_xw += x[right] * weights[right]
            sum_w += weights[right]
            right += 1
        out[i] = sum_xw / sum_w if sum_w > 0 else np.nan
    return out


oopg_smooth = weighted_running_mean(oopg_s_plot, w_s, cum_share, window_pct=2.0)
oop_smooth = weighted_running_mean(oop_s_plot, w_s, cum_share, window_pct=2.0)


plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 10})

fig, (ax1, ax2) = plt.subplots(
    nrows=2,
    ncols=1,
    figsize=(10.5, 8.5),
    gridspec_kw={"height_ratios": [2.0, 1.0], "hspace": 0.18},
)

ax1.plot(
    cum_share,
    welfare_s,
    color="#1f5fbe",
    lw=1.8,
    label="Monthly per-AE consumption",
)

oop_mask = che_oop_s == 1
oopg_mask = che_oopg_s == 1
ax1.scatter(
    cum_share[oop_mask],
    welfare_s[oop_mask],
    s=11,
    color="#cc1010",
    alpha=0.45,
    edgecolor="none",
    label=f"OOP CHE >10% (n = {int(oop_mask.sum()):,})",
    zorder=3,
)
ax1.scatter(
    cum_share[oopg_mask],
    welfare_s[oopg_mask],
    s=13,
    color="#f7b500",
    alpha=0.65,
    edgecolor="none",
    label=f"OOPG CHE >10% (n = {int(oopg_mask.sum()):,})",
    zorder=4,
)

ax1.axhline(ae_pline_month, color="#444444", ls="--", lw=1.0, alpha=0.85)
ax1.text(
    0.5,
    ae_pline_month * 1.06,
    f"Poverty line (AE-equiv.), {ae_pline_month:,.0f} NPR/month",
    color="#444444",
    fontsize=8.5,
    va="bottom",
)

ax1.axhline(mean_welfare_month, color="#222222", ls=":", lw=0.9, alpha=0.55)
ax1.text(
    0.5,
    mean_welfare_month * 1.06,
    f"Mean per-AE consumption, {mean_welfare_month:,.0f} NPR/month",
    color="#222222",
    fontsize=8.5,
    va="bottom",
)

ax1.set_yscale("log")
ax1.yaxis.set_major_formatter(FuncFormatter(lambda y, _: f"{int(y):,}"))
ax1.set_xlim(0, 100)
ax1.set_ylabel("Per-AE consumption, monthly NPR (log scale)")
ax1.set_title(
    "Pen's Parade - Nepal NLSS IV (2022/23)\n"
    "Monthly per-AE consumption and oopg/OOP budget shares",
    fontsize=12,
    pad=10,
)
ax1.grid(True, which="major", alpha=0.30, lw=0.6)
ax1.grid(True, which="minor", alpha=0.15, lw=0.4)
ax1.legend(loc="upper left", fontsize=8.5, framealpha=0.95)
ax1.tick_params(axis="x", labelbottom=False)

ax2.fill_between(
    cum_share,
    0,
    oop_smooth,
    color="#f4a582",
    alpha=0.35,
    lw=0,
    label="OOP / monthly consumption (smoothed)",
)
ax2.plot(cum_share, oop_smooth, color="#cc1010", lw=1.5)
ax2.plot(
    cum_share,
    oopg_smooth,
    color="#b26b00",
    lw=1.5,
    label="oopg / monthly consumption (smoothed)",
)

ax2.axhline(0.10, color="#444444", ls="--", lw=1.0, alpha=0.7)
ax2.text(99, 0.103, "10% threshold", color="#444444", fontsize=8, ha="right", va="bottom")
ax2.axhline(0.20, color="#444444", ls=":", lw=1.0, alpha=0.7)
ax2.text(99, 0.205, "20% threshold", color="#444444", fontsize=8, ha="right", va="bottom")

ax2.yaxis.set_major_formatter(PercentFormatter(xmax=1.0, decimals=0))
ax2.set_xlim(0, 100)
ax2.set_ylim(0, max(0.25, np.nanmax(oop_smooth) * 1.2))
ax2.set_xlabel("Cumulative population share (%) - sorted by monthly per-AE consumption")
ax2.set_ylabel("Avg share of monthly\nconsumption")
ax2.grid(True, which="major", alpha=0.30, lw=0.6)
ax2.legend(loc="upper right", fontsize=8.5, framealpha=0.95)

caption = (
    "Notes: The x-axis orders the population by household monthly per-AE "
    "consumption. oopg is Section 8B communicable disease/injury OOP. OOP is "
    "oopg plus NCD OOP converted to a monthly household amount. The lower panel "
    "uses a 2-percentage-point sliding window; shares are capped at 100% for "
    "display only. Source: NLSS IV; individual sampling weights."
)
fig.text(
    0.02,
    -0.005,
    caption,
    fontsize=7.5,
    wrap=True,
    ha="left",
    va="top",
    style="italic",
    color="#444",
)

fig.subplots_adjust(left=0.08, right=0.98, top=0.90, bottom=0.18, hspace=0.20)

pdf_path = OUT_DIR / "pens_parade.pdf"
png_path = OUT_DIR / "pens_parade.png"
fig.savefig(pdf_path, bbox_inches="tight")
fig.savefig(png_path, bbox_inches="tight", dpi=200)
plt.close(fig)

print(f"Saved: {pdf_path}")
print(f"Saved: {png_path}\n")
print("Summary:")
print(f"  N households                          : {len(welfare_s):,}")
print(f"  Mean per-AE consumption (ind-wt)      : {mean_welfare_month:,.0f} NPR/month")
print(f"  AE-equiv. poverty line (ind-wt)       : {ae_pline_month:,.0f} NPR/month")
print(f"  oopg CHE >10% prevalence (ind-wt)      : {np.average(che_oopg_s, weights=w_s)*100:.2f}%")
print(f"  OOP CHE >10% prevalence (ind-wt)      : {np.average(che_oop_s, weights=w_s)*100:.2f}%")
print(f"  Mean OOPG share, bottom 10% (ind-wt)   : {np.nanmean(oopg_smooth[cum_share <= 10])*100:.2f}%")
print(f"  Mean OOPG share, top 10% (ind-wt)      : {np.nanmean(oopg_smooth[cum_share >= 90])*100:.2f}%")
print(f"  Mean OOP share, bottom 10% (ind-wt)   : {np.nanmean(oop_smooth[cum_share <= 10])*100:.2f}%")
print(f"  Mean OOP share, top 10% (ind-wt)      : {np.nanmean(oop_smooth[cum_share >= 90])*100:.2f}%")
