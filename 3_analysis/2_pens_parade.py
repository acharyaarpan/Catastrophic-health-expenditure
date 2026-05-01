"""
3_analysis/2_pens_parade.py

Pen's Parade for Nepal NLSS IV (2022/23)
========================================

Two-panel figure:
    Top    : Pen's Parade of monthly per-AE consumption, with CHE-affected households
             marked and the AE-equivalent national poverty line.
    Bottom : General Health Expenditure (GHE) as a share of monthly consumption,
             smoothed by population percentile so the regressivity of OOP
             health spending is visible.

Conventions
-----------
- Welfare measure: monthly per-AE consumption (`pc_cons_ae / 12`), in line
  with WB and Wagstaff/van Doorslaer convention for CHE work.
- Population frame: each household contributes weight `ind_wt`. The x-axis is
  the cumulative individual-weighted share so each *person* (not each
  household) marches once.
- GHE: communicable-disease/injury OOP from the past 30 days
  (`hh_comm_total_30d`). Monthly share = GHE / (total_consumption / 12).
- Poverty line: NLSS IV reports a per-capita line of NPR 72,908/yr. For a
  monthly per-AE parade we convert by `pline * hhsize / adult_equiv / 12`
  and take the population-weighted mean.

Output
------
6_output/pens_parade.pdf
6_output/pens_parade.png

Author: Arpan Acharya
"""

from pathlib import Path
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.ticker import FuncFormatter, PercentFormatter

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
# Resolve the project root in both script and notebook/IPython modes.
# `__file__` is only defined when run as a script; in a notebook/IPython cell
# it's missing, so we fall back to searching from the current working directory.
_DATA_REL = Path("1_data") / "2_clean" / "catastrophic_health_exp.dta"

def _find_project_root() -> Path:
    cand = Path.cwd().resolve()
    # Walk up to 5 levels; at each level also peek inside a 'consumption' child
    # so the script works whether cwd is the project root, its parent, or any
    # subfolder inside the project.
    for _ in range(6):
        if (cand / _DATA_REL).exists():
            return cand
        if (cand / "consumption" / _DATA_REL).exists():
            return cand / "consumption"
        if cand == cand.parent:  # filesystem root
            break
        cand = cand.parent
    raise FileNotFoundError(
        f"Could not locate project data file ({_DATA_REL}) by walking "
        f"upward from {Path.cwd()}. Set PROJECT_ROOT manually or "
        f"os.chdir() into D:\\Projects\\CIH-project\\consumption."
    )

try:
    PROJECT_ROOT = Path(__file__).resolve().parents[1]
except NameError:
    PROJECT_ROOT = _find_project_root()

DATA_PATH = PROJECT_ROOT / "1_data" / "2_clean" / "catastrophic_health_exp.dta"
OUT_DIR = PROJECT_ROOT / "6_output"
OUT_DIR.mkdir(parents=True, exist_ok=True)

assert DATA_PATH.exists(), (
    f"Could not find data file at {DATA_PATH}. "
    f"Run this from the project root (D:\\Projects\\CIH-project\\consumption) "
    f"or set PROJECT_ROOT manually."
)

# ---------------------------------------------------------------------------
# Load
# ---------------------------------------------------------------------------
df = pd.read_stata(DATA_PATH, convert_categoricals=False)

welfare_annual = df["pc_cons_ae"].astype(float)
hhsize = df["hhsize"].astype(float)
ae = df["adult_equiv"].astype(float)
ghe_30d = df["hh_comm_total_30d"].astype(float)
total_cons = df["total_consumption"].astype(float)
pline = df["pline"].astype(float)
ind_wt = df["ind_wt"].astype(float)
che10 = df["che_comm_100"].astype(float)
che20 = df["che_comm_20"].astype(float)

# Monthly variables. Keep the annual source variables intact and create
# monthly equivalents for display and CHE-share calculations.
welfare_month = welfare_annual / 12.0
monthly_cons = total_cons / 12.0
pline_month = pline / 12.0

# GHE share of monthly consumption (this is what the CHE flags threshold)
# Cap absurd outliers at 100% for plotting only (a few cases exceed 100% due
# to OOP > monthly consumption; these are the same medical-impoverishment cases).
ghe_share = np.where(monthly_cons > 0, ghe_30d / monthly_cons, np.nan)
ghe_share_plot = np.minimum(ghe_share, 1.0)  # cap at 100% for the lower panel

# Monthly AE-equivalent poverty line
ae_pline_month_per_hh = pline_month * hhsize / ae
ae_pline_month = np.average(ae_pline_month_per_hh, weights=ind_wt)

# ---------------------------------------------------------------------------
# Drop missing welfare or weight, sort by gross welfare
# ---------------------------------------------------------------------------
# Convert the boolean mask to a numpy array so we can apply it uniformly to
# both pandas Series (welfare, ind_wt, che10) and to numpy arrays (ghe_share,
# ghe_share_plot were produced by np.where() and don't have a .values attr).
mask_arr = (welfare_month.notna() & ind_wt.notna() & np.isfinite(ghe_share)).to_numpy()
welfare = welfare_month.to_numpy()[mask_arr]
ghe_share = ghe_share[mask_arr]
ghe_share_plot = ghe_share_plot[mask_arr]
w = ind_wt.to_numpy()[mask_arr]
che10 = che10.to_numpy()[mask_arr]

order = np.argsort(welfare)
welfare_s = welfare[order]
ghe_share_s = ghe_share_plot[order]
w_s = w[order]
che10_s = che10[order]

cum_share = np.cumsum(w_s) / w_s.sum() * 100.0  # 0..100
mean_welfare_month = np.average(welfare_s, weights=w_s)


def weighted_running_mean(x, weights, cum_x_pct, window_pct=2.0):
    """
    Weighted moving average of x along an already-sorted axis whose cumulative
    weight share (in percent) is `cum_x_pct`. For each point i, average x over
    all points whose cumulative share is within +/- window_pct/2 of cum_x_pct[i].

    O(n) using a sliding window over the sorted cumulative-share axis.
    """
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
        # advance left
        while left < n and cum_x_pct[left] < lo:
            sum_xw -= x[left] * weights[left]
            sum_w -= weights[left]
            left += 1
        # advance right
        while right < n and cum_x_pct[right] <= hi:
            sum_xw += x[right] * weights[right]
            sum_w += weights[right]
            right += 1
        out[i] = sum_xw / sum_w if sum_w > 0 else np.nan
    return out


# Smooth GHE share across percentiles (window = 2 percentage points wide)
ghe_share_smooth = weighted_running_mean(
    ghe_share_s, w_s, cum_share, window_pct=2.0
)

# ---------------------------------------------------------------------------
# Plot
# ---------------------------------------------------------------------------
plt.rcParams.update({
    "font.family": "DejaVu Sans",
    "font.size": 10,
})

fig, (ax1, ax2) = plt.subplots(
    nrows=2, ncols=1, figsize=(10, 8.5),
    gridspec_kw={"height_ratios": [2.0, 1.0], "hspace": 0.18},
)

# =============================== TOP PANEL ===============================
# Pen's Parade: gross monthly per-AE consumption
ax1.plot(cum_share, welfare_s, color="#1f5fbe", lw=1.8,
         label="Monthly per-AE consumption")

# Mark CHE-affected households
che_mask = che10_s == 1
ax1.scatter(cum_share[che_mask], welfare_s[che_mask],
            s=10, color="#fb9a29", alpha=0.55, edgecolor="none",
            label=f"CHE household, GHE > 10% (n = {int(che_mask.sum()):,})",
            zorder=3)

# Reference lines
ax1.axhline(ae_pline_month, color="#444444", ls="--", lw=1.0, alpha=0.85)
ax1.text(0.5, ae_pline_month * 1.06,
         f"Poverty line (AE-equiv.), {ae_pline_month:,.0f} NPR/month",
         color="#444444", fontsize=8.5, va="bottom")

ax1.axhline(mean_welfare_month, color="#222222", ls=":", lw=0.9, alpha=0.55)
ax1.text(0.5, mean_welfare_month * 1.06,
         f"Mean per-AE consumption, {mean_welfare_month:,.0f} NPR/month",
         color="#222222", fontsize=8.5, va="bottom")

ax1.set_yscale("log")
ax1.yaxis.set_major_formatter(FuncFormatter(lambda y, _: f"{int(y):,}"))
ax1.set_xlim(0, 100)
ax1.set_ylabel("Per-AE consumption, monthly NPR (log scale)")
ax1.set_title(
    "Pen's Parade — Nepal NLSS IV (2022/23)\n"
    "Monthly per-AE consumption and the share absorbed by General Health Expenditure",
    fontsize=12, pad=10,
)
ax1.grid(True, which="major", alpha=0.30, lw=0.6)
ax1.grid(True, which="minor", alpha=0.15, lw=0.4)
ax1.legend(loc="upper left", fontsize=8.5, framealpha=0.95)
ax1.tick_params(axis="x", labelbottom=False)  # share x-axis with bottom panel

# =============================== BOTTOM PANEL ===========================
# Smoothed GHE share of monthly consumption across the parade
ax2.fill_between(cum_share, 0, ghe_share_smooth,
                 color="#f4a582", alpha=0.55, lw=0,
                 label="GHE / monthly consumption (smoothed, 2pp window)")

ax2.plot(cum_share, ghe_share_smooth, color="#b2182b", lw=1.4)

# Reference: 10% and 20% CHE thresholds
ax2.axhline(0.10, color="#444444", ls="--", lw=1.0, alpha=0.7)
ax2.text(99, 0.103, "10% threshold", color="#444444",
         fontsize=8, ha="right", va="bottom")
ax2.axhline(0.20, color="#444444", ls=":", lw=1.0, alpha=0.7)
ax2.text(99, 0.205, "20% threshold", color="#444444",
         fontsize=8, ha="right", va="bottom")

ax2.yaxis.set_major_formatter(PercentFormatter(xmax=1.0, decimals=0))
ax2.set_xlim(0, 100)
ax2.set_ylim(0, max(0.25, ghe_share_smooth.max() * 1.2))
ax2.set_xlabel("Cumulative population share (%) — sorted by monthly per-AE consumption")
ax2.set_ylabel("Avg GHE share of\nmonthly consumption")
ax2.grid(True, which="major", alpha=0.30, lw=0.6)
ax2.legend(loc="upper right", fontsize=8.5, framealpha=0.95)

# Caption
caption = (
    "Notes: Each point on the x-axis represents a percentile of the population "
    "ordered by household monthly per-AE consumption (Citro--Michael adult equivalence; "
    "p=0.5, theta=0.75). Top panel: Pen's Parade. Markers identify households "
    "where General Health Expenditure (GHE = communicable OOP, past 30 days) "
    "exceeds 10% of monthly consumption. The poverty line shown is the "
    "monthly AE-equivalent of the official NLSS IV per-capita line "
    "(NPR 72,908/yr, divided by 12 for this figure). "
    "Bottom panel: GHE as a share of monthly household consumption, "
    "smoothed with a 2-percentage-point sliding window across the parade. "
    "Source: NLSS IV; individual sampling weights."
)
fig.text(0.02, -0.005, caption, fontsize=7.5, wrap=True,
         ha="left", va="top", style="italic", color="#444")

fig.subplots_adjust(left=0.08, right=0.98, top=0.90, bottom=0.18, hspace=0.20)

# ---------------------------------------------------------------------------
# Save
# ---------------------------------------------------------------------------
pdf_path = OUT_DIR / "pens_parade.pdf"
png_path = OUT_DIR / "pens_parade.png"
fig.savefig(pdf_path, bbox_inches="tight")
fig.savefig(png_path, bbox_inches="tight", dpi=200)
plt.close(fig)

# ---------------------------------------------------------------------------
# Diagnostics
# ---------------------------------------------------------------------------
print(f"Saved: {pdf_path}")
print(f"Saved: {png_path}\n")
print("Summary:")
print(f"  N households                          : {len(welfare_s):,}")
print(f"  Mean per-AE consumption (ind-wt)      : {mean_welfare_month:,.0f} NPR/month")
print(f"  AE-equiv. poverty line (ind-wt)       : {ae_pline_month:,.0f} NPR/month")
print(f"  CHE > 10% prevalence (ind-wt)         : "
      f"{np.average(che10_s, weights=w_s)*100:.1f}%")
print(f"  Mean GHE share, bottom 10% (ind-wt)   : "
      f"{ghe_share_smooth[cum_share <= 10].mean()*100:.2f}%")
print(f"  Mean GHE share, top 10%   (ind-wt)    : "
      f"{ghe_share_smooth[cum_share >= 90].mean()*100:.2f}%")
