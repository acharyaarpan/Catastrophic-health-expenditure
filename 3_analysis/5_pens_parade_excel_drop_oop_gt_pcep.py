"""
3_analysis/5_pens_parade_excel_drop_oop_gt_pcep.py

Excel-based Pen's Parade after excluding households where monthly real
per-capita OOP exceeds monthly real pcep.

This is a visual sensitivity check only. It deliberately drops the 42 extreme
medical-impoverishment households so we can see how much of the red-line
pattern remains among households with OOP <= monthly pcep.
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
constants = pd.read_excel(XLSX_PATH, sheet_name="Constants")
const_map = dict(zip(constants["Parameter"], constants["Value"]))
pline_month = float(const_map["Total poverty line (annual NPR/cap)"]) / 12.0
fpline_month = float(const_map["Food poverty line (annual NPR/cap)"]) / 12.0

required = [
    "ind_wt",
    "pcep_monthly_real",
    "oop_per_capita_monthly_real",
    "pcep_net_monthly_real",
]
missing = [c for c in required if c not in df.columns]
if missing:
    raise KeyError(f"Missing required Excel columns: {missing}")

for col in required:
    df[col] = df[col].astype(float)

base_mask = (
    df["ind_wt"].notna()
    & df["pcep_monthly_real"].notna()
    & df["oop_per_capita_monthly_real"].notna()
    & df["pcep_net_monthly_real"].notna()
    & (df["ind_wt"] > 0)
)
df = df.loc[base_mask].copy()

drop_mask = df["oop_per_capita_monthly_real"] > df["pcep_monthly_real"]
n_dropped = int(drop_mask.sum())
df_keep = df.loc[~drop_mask].copy()

order = np.argsort(df_keep["pcep_monthly_real"].to_numpy())
w_s = df_keep["ind_wt"].to_numpy()[order]
pcep_s = df_keep["pcep_monthly_real"].to_numpy()[order]
oop_s = df_keep["oop_per_capita_monthly_real"].to_numpy()[order]
pcep_net_s = df_keep["pcep_net_monthly_real"].to_numpy()[order]
cum_share = np.cumsum(w_s) / w_s.sum() * 100.0
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
    pcep_net_s,
    color="#b2182b",
    lw=0.55,
    alpha=0.78,
    label="Monthly pcep net of monthly real OOP",
)
ax.axhline(
    pline_month,
    color="#1f5fbe",
    lw=1.4,
    alpha=0.85,
    label=f"Total poverty line ({pline_month:,.0f} NPR/month)",
)
ax.axhline(
    fpline_month,
    color="#2ca25f",
    lw=1.4,
    alpha=0.85,
    label=f"Food poverty line ({fpline_month:,.0f} NPR/month)",
)

ax.set_yscale("log")
ax.yaxis.set_major_formatter(FuncFormatter(lambda y, _: f"{int(y):,}"))
ax.set_xlim(0, 100)
ax.set_xlabel("Cumulative population share (%) -- sorted by monthly pcep")
ax.set_ylabel("Monthly real NPR per capita (log scale)")
ax.set_title("Pen's Parade from Excel data -- excluding OOP > monthly pcep households")
ax.grid(True, which="major", alpha=0.30, lw=0.6)
ax.grid(True, which="minor", alpha=0.15, lw=0.4)
ax.legend(loc="upper left", fontsize=8.8, framealpha=0.95)

caption = (
    f"Notes: Built directly from 6_output/pens_parade_data.xlsx after dropping "
    f"{n_dropped:,} households where monthly real per-capita OOP exceeded "
    "monthly real pcep. Poverty lines are the official annual NLSS IV lines "
    "divided by 12. This is a visual sensitivity check, not the preferred "
    "impoverishment specification, because those extreme cases are valid "
    "medical-spending observations financed outside current consumption."
)
fig.text(0.02, -0.005, caption, fontsize=7.6, wrap=True, ha="left", va="top", style="italic")
fig.subplots_adjust(left=0.08, right=0.98, top=0.91, bottom=0.16)

png_path = OUT_DIR / "pens_parade_from_excel_drop_oop_gt_pcep.png"
pdf_path = OUT_DIR / "pens_parade_from_excel_drop_oop_gt_pcep.pdf"
fig.savefig(png_path, bbox_inches="tight", dpi=200)
fig.savefig(pdf_path, bbox_inches="tight")
plt.close(fig)

print(f"Saved: {png_path}")
print(f"Saved: {pdf_path}\n")
print("Excel-based parade sensitivity:")
print(f"  Original households                         : {len(df):,}")
print(f"  Dropped OOP > monthly pcep households       : {n_dropped:,}")
print(f"  Remaining households                        : {len(df_keep):,}")
print(f"  Monthly total poverty line                  : {pline_month:,.0f} NPR/month")
print(f"  Monthly food poverty line                   : {fpline_month:,.0f} NPR/month")
print(f"  Remaining households with positive OOP      : {int((oop_s > 0).sum()):,}")
print(f"  Max OOP share among remaining households    : {np.nanmax(oop_share) * 100:.2f}%")
print(f"  95th percentile OOP share, remaining        : {np.nanpercentile(oop_share, 95) * 100:.2f}%")
print(f"  99th percentile OOP share, remaining        : {np.nanpercentile(oop_share, 99) * 100:.2f}%")
