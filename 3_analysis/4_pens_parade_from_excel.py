"""
3_analysis/4_pens_parade_from_excel.py

Pen's Parade audit figure from 6_output/pens_parade_data.xlsx.

This script uses the exported Excel audit data directly, rather than rebuilding
variables from the raw Stata files. It is meant to make the OOP/net-consumption
logic transparent when reviewing the workbook columns.
"""

from pathlib import Path
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.ticker import FuncFormatter

PROJECT_ROOT = Path(__file__).resolve().parents[1]
XLSX_PATH = PROJECT_ROOT / "6_output" / "pens_parade_data.xlsx"
OUT_DIR = PROJECT_ROOT / "6_output"

assert XLSX_PATH.exists(), f"Missing workbook: {XLSX_PATH}"

df = pd.read_excel(XLSX_PATH, sheet_name="Data", skiprows=[1])

required = [
    "ind_wt",
    "pcep_monthly_real",
    "oop_per_capita_monthly_real",
    "pcep_net_monthly_real",
]
missing = [c for c in required if c not in df.columns]
if missing:
    raise KeyError(f"Missing required Excel columns: {missing}")

w = df["ind_wt"].astype(float)
pcep_month = df["pcep_monthly_real"].astype(float)
oop_month_real = df["oop_per_capita_monthly_real"].astype(float)
pcep_net_month = df["pcep_net_monthly_real"].astype(float)

mask = (
    w.notna()
    & pcep_month.notna()
    & oop_month_real.notna()
    & pcep_net_month.notna()
    & (w > 0)
)
w = w[mask].to_numpy()
pcep_month = pcep_month[mask].to_numpy()
oop_month_real = oop_month_real[mask].to_numpy()
pcep_net_month = pcep_net_month[mask].to_numpy()

order = np.argsort(pcep_month)
w_s = w[order]
pcep_s = pcep_month[order]
oop_s = oop_month_real[order]
pcep_net_s = pcep_net_month[order]
cum_share = np.cumsum(w_s) / w_s.sum() * 100.0

oop_positive = oop_s > 0
oop_gt_consumption = oop_s > pcep_s
log_floor = 100
pcep_net_plot = np.where(pcep_net_s < log_floor, log_floor, pcep_net_s)
oop_share = np.where(pcep_s > 0, oop_s / pcep_s, np.nan)

plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 10})
fig, ax = plt.subplots(figsize=(11, 6.5))

ax.plot(
    cum_share,
    pcep_s,
    color="#f2a900",
    lw=2.0,
    label="Monthly pcep, real",
)
ax.plot(
    cum_share,
    pcep_net_plot,
    color="#b2182b",
    lw=0.55,
    alpha=0.78,
    label="Monthly pcep net of monthly real OOP",
)

ax.scatter(
    cum_share[oop_gt_consumption],
    np.full(oop_gt_consumption.sum(), log_floor),
    s=16,
    color="#111111",
    alpha=0.8,
    label=f"OOP > monthly pcep (n = {oop_gt_consumption.sum():,})",
    zorder=4,
)

ax.set_yscale("log")
ax.yaxis.set_major_formatter(FuncFormatter(lambda y, _: f"{int(y):,}"))
ax.set_xlim(0, 100)
ax.set_ylim(bottom=log_floor)
ax.set_xlabel("Cumulative population share (%) -- sorted by monthly pcep")
ax.set_ylabel("Monthly real NPR per capita (log scale)")
ax.set_title("Pen's Parade audit from Excel data -- monthly pcep and OOP")
ax.grid(True, which="major", alpha=0.30, lw=0.6)
ax.grid(True, which="minor", alpha=0.15, lw=0.4)
ax.legend(loc="upper left", fontsize=8.8, framealpha=0.95)

caption = (
    "Notes: Built directly from 6_output/pens_parade_data.xlsx. The red line is "
    "not a marker only for households where OOP exceeds consumption; it is "
    "pcep minus OOP for every household. Therefore every positive OOP case "
    "creates a downward gap. Only the black markers identify cases where monthly "
    "real per-capita OOP is greater than monthly real pcep. Net values below "
    f"NPR {log_floor:,}/month are floored for log-axis display only."
)
fig.text(0.02, -0.005, caption, fontsize=7.6, wrap=True, ha="left", va="top", style="italic")
fig.subplots_adjust(left=0.08, right=0.98, top=0.91, bottom=0.16)

png_path = OUT_DIR / "pens_parade_from_excel.png"
pdf_path = OUT_DIR / "pens_parade_from_excel.pdf"
fig.savefig(png_path, bbox_inches="tight", dpi=200)
fig.savefig(pdf_path, bbox_inches="tight")
plt.close(fig)

print(f"Saved: {png_path}")
print(f"Saved: {pdf_path}\n")
print("Excel-based parade audit:")
print(f"  Households in workbook                         : {len(pcep_s):,}")
print(f"  Households with positive OOP                   : {int(oop_positive.sum()):,}")
print(f"  Households where monthly real OOP > pcep       : {int(oop_gt_consumption.sum()):,}")
print(f"  Households where net monthly pcep <= 0         : {int((pcep_net_s <= 0).sum()):,}")
print(f"  Median OOP share of monthly pcep               : {np.nanmedian(oop_share) * 100:.2f}%")
print(f"  95th percentile OOP share of monthly pcep      : {np.nanpercentile(oop_share, 95) * 100:.2f}%")
print(f"  99th percentile OOP share of monthly pcep      : {np.nanpercentile(oop_share, 99) * 100:.2f}%")
