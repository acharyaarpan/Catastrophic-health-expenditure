"""
3_analysis/3_pens_parade_oop.py

Pen's Parade and out-of-pocket health payments -- Nepal NLSS IV
================================================================

Wagstaff & van Doorslaer-style figure visualising the impact of OOP health
spending on per-capita consumption, anchored to NLSS's official poverty
methodology.

Layout: single-panel parade.
    Yellow line (top, smooth):  monthly pcep (deflated per-capita consumption)
    Red line (lower, jagged):   monthly pcep net of monthly real OOP per capita
                                (downward spikes = households where OOP eats
                                 a large share of consumption)
    Blue horizontal:            monthly total poverty line
    Green horizontal:           monthly food poverty line

Conventions
-----------
- Welfare measure: monthly `pcep` (`pcep / 12`). `pcep` is the deflated
  per-capita expenditure variable NLSS uses to compute the official `poor`
  flag. Dividing both `pcep` and `pline` by 12 preserves the official
  20.3% headcount.
- OOP: nominal monthly per-capita OOP (`hh_comm_total_30d / hhsize`) is then
  divided by the household's Paasche price index (`paasche`) so the OOP is
  in the same real units as monthly `pcep`. Subtracting raw nominal OOP from
  real pcep would mix units and overstate the impoverishment slightly.
- Population frame: each person marches once, weighted by `ind_wt`.

Headline finding
----------------
Headcount poverty rises from 20.27% (official, before OOP) to 23.40% after
OOP -- an OOP-induced impoverishment of +3.13 percentage points, equivalent
to roughly 899,000 Nepalis pushed below the poverty line when the survey
month's out-of-pocket health spending is netted out.

Earlier nominal per-capita CHE poverty takeaway
-----------------------------------------------
For continuity with the earlier "try/CHE-research" figure, the script also
prints the older simple per-capita sensitivity: comparing nominal
`pctot_consumption` with the same poverty line gives 29.0% poor before OOP
and 31.6% after OOP, or +2.6 percentage points. This is retained as a
sensitivity/takeaway only; it is not the official poverty estimate because it
mixes nominal consumption with the real NLSS poverty line.

Output
------
6_output/pens_parade_oop.pdf
6_output/pens_parade_oop.png

Companion to `2_pens_parade.py` (AE-adjusted, GHE-share panel).

Author: Arpan Acharya
"""

from pathlib import Path
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.ticker import FuncFormatter

# ---------------------------------------------------------------------------
# Paths -- robust to script vs notebook run modes
# ---------------------------------------------------------------------------
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
        f"Could not locate project data file ({_DATA_REL}) by walking "
        f"upward from {Path.cwd()}. Set PROJECT_ROOT manually or "
        f"os.chdir() into D:\\Projects\\CIH-project\\consumption."
    )

try:
    PROJECT_ROOT = Path(__file__).resolve().parents[1]
except NameError:
    PROJECT_ROOT = _find_project_root()

DATA_PATH = PROJECT_ROOT / "1_data" / "2_clean" / "catastrophic_health_exp.dta"
POVERTY_PATH = PROJECT_ROOT / "1_data" / "1_raw" / "poverty.dta"
OUT_DIR = PROJECT_ROOT / "6_output"
OUT_DIR.mkdir(parents=True, exist_ok=True)

assert DATA_PATH.exists(), f"Missing data: {DATA_PATH}"
assert POVERTY_PATH.exists(), f"Missing poverty.dta: {POVERTY_PATH}"

# ---------------------------------------------------------------------------
# Load + merge pcep / paasche from poverty.dta
# ---------------------------------------------------------------------------
df = pd.read_stata(DATA_PATH, convert_categoricals=False)
pov = pd.read_stata(POVERTY_PATH, convert_categoricals=False)
df = df.merge(pov[['psu_number', 'hh_number', 'pcep', 'paasche']],
              on=['psu_number', 'hh_number'], how='left')

pcep = df["pcep"].astype(float)               # deflated per-capita consumption
paasche = df["paasche"].astype(float)          # spatial price index
pctot_consumption = df["pctot_consumption"].astype(float)  # nominal per-capita consumption
hhsize = df["hhsize"].astype(float)
ghe_30d = df["hh_comm_total_30d"].astype(float)
ind_wt = df["ind_wt"].astype(float)

pline = float(df["pline"].iloc[0])     # NPR 72,908/yr per capita (real terms)
fpline = float(df["fpline"].iloc[0])   # NPR 35,029/yr per capita (real terms)

# Monthly variables. Keep the annual source variables intact and create
# monthly equivalents for the parade.
pcep_month = pcep / 12.0
pctot_consumption_month = pctot_consumption / 12.0
pline_month = pline / 12.0
fpline_month = fpline / 12.0

# Per-capita monthly OOP: nominal first, then deflate to match pcep units
oop_per_capita_nominal_month = ghe_30d / hhsize
oop_per_capita_real_month = oop_per_capita_nominal_month / paasche

# Net real monthly per-capita consumption (post-OOP)
pcep_net_month = pcep_month - oop_per_capita_real_month

# ---------------------------------------------------------------------------
# Drop missing, sort by gross pcep, compute cumulative population share
# ---------------------------------------------------------------------------
mask = (pcep_month.notna() & ind_wt.notna() & paasche.notna() & pcep_net_month.notna()).to_numpy()
pcep_a = pcep_month.to_numpy()[mask]
pcep_net_a = pcep_net_month.to_numpy()[mask]
w = ind_wt.to_numpy()[mask]

order = np.argsort(pcep_a)
pcep_s = pcep_a[order]
pcep_net_s = pcep_net_a[order]
w_s = w[order]

cum_share = np.cumsum(w_s) / w_s.sum() * 100.0
mean_pcep = np.average(pcep_s, weights=w_s)

# Floor net at a small positive value for log-axis display only
log_floor = 100
neg_count = int((pcep_net_s <= 0).sum())
pcep_net_plot = np.where(pcep_net_s < log_floor, log_floor, pcep_net_s)

# ---------------------------------------------------------------------------
# Headcount poverty (gross vs net of OOP) -- key statistic for caption
# ---------------------------------------------------------------------------
def wmean(flag, weights):
    return float(np.sum(weights * flag) / np.sum(weights))

poor_gross_pop = wmean((pcep_s < pline_month).astype(float), w_s) * 100
poor_net_pop = wmean((pcep_net_s < pline_month).astype(float), w_s) * 100
impov_pop = poor_net_pop - poor_gross_pop
newly_poor_mask = (pcep_s >= pline_month) & (pcep_net_s < pline_month)
abs_pushed = float(np.sum(w_s[newly_poor_mask]))
n_hh_pushed = int(newly_poor_mask.sum())

# Previous-try nominal per-capita poverty takeaway.
# This reproduces the older figure note as a sensitivity only: pctot_consumption
# is nominal, while pline is the official real per-capita line.
pctot_a = pctot_consumption_month.to_numpy()[mask][order]
oop_per_capita_nominal_s = oop_per_capita_nominal_month.to_numpy()[mask][order]
pctot_net_s = pctot_a - oop_per_capita_nominal_s
poor_gross_nominal = wmean((pctot_a < pline_month).astype(float), w_s) * 100
poor_net_nominal = wmean((pctot_net_s < pline_month).astype(float), w_s) * 100
impov_nominal = poor_net_nominal - poor_gross_nominal

# ---------------------------------------------------------------------------
# Plot
# ---------------------------------------------------------------------------
plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 10})

fig, ax = plt.subplots(figsize=(11, 6.5))

# Net consumption (red, thin -- spikes downward where OOP is large)
ax.plot(cum_share, pcep_net_plot,
        color="#cc1010", lw=0.5, alpha=0.85,
        label="Monthly per-capita consumption (real) net of OOP")

# Gross consumption (yellow/gold, thicker -- the parade)
ax.plot(cum_share, pcep_s,
        color="#f7b500", lw=2.0,
        label="Monthly per-capita consumption (real, gross = pcep / 12)")

# Poverty lines
ax.axhline(pline_month, color="#1f5fbe", ls="-", lw=1.4, alpha=0.85,
           label=f"Total poverty line ({pline_month:,.0f} NPR/month)")
ax.axhline(fpline_month, color="#2ca25f", ls="-", lw=1.4, alpha=0.85,
           label=f"Food poverty line ({fpline_month:,.0f} NPR/month)")

# Mean consumption (dotted reference)
ax.axhline(mean_pcep, color="#222222", ls=":", lw=0.9, alpha=0.55)
ax.text(0.5, mean_pcep * 1.06,
        f"Mean per-capita consumption (real), {mean_pcep:,.0f} NPR/month",
        color="#222222", fontsize=8.5, va="bottom")

# Axes
ax.set_yscale("log")
ax.yaxis.set_major_formatter(FuncFormatter(lambda y, _: f"{int(y):,}"))
ax.set_xlim(0, 100)
ax.set_ylim(bottom=log_floor)
ax.set_xlabel("Cumulative population share (%) -- sorted by monthly per-capita real consumption (pcep / 12)")
ax.set_ylabel("Per-capita real consumption, monthly NPR (log scale)")
ax.set_title(
    "Pen's Parade and out-of-pocket health payments -- Nepal NLSS IV (2022/23)",
    fontsize=12, pad=10,
)
ax.grid(True, which="major", alpha=0.30, lw=0.6)
ax.grid(True, which="minor", alpha=0.15, lw=0.4)
ax.legend(loc="upper left", fontsize=9, framealpha=0.95)

# Caption
caption = (
    "Notes: Each point on the x-axis is a percentile of the population ordered "
    "by household monthly per-capita real consumption (`pcep / 12`, where pcep is the deflated consumption "
    "variable used in NLSS's official poverty calculation; `pcep < pline` "
    "reproduces the official 20.3% headcount exactly). Yellow line = monthly gross pcep; "
    "red line subtracts monthly per-capita OOP, deflated by the household's "
    "Paasche price index so the units match. Headcount poverty: "
    f"{poor_gross_pop:.2f}% before OOP, {poor_net_pop:.2f}% after OOP -- an "
    f"OOP-induced impoverishment of {impov_pop:+.2f} percentage points, "
    f"equivalent to ~{abs_pushed:,.0f} Nepalis pushed below the poverty line "
    f"when the survey month's OOP is netted out ({n_hh_pushed} households "
    "crossed the threshold). Reference "
    f"lines: monthly official NLSS IV per-capita poverty line "
    f"(NPR {pline_month:,.0f}/month) and food poverty line "
    f"(NPR {fpline_month:,.0f}/month). {neg_count} households have "
    f"net monthly pcep <= 0 after OOP and are floored at NPR {log_floor:,}/month for log "
    "display; these are typically lumpy medical events financed outside the "
    "consumption aggregate (loans, asset sales). Earlier nominal per-capita "
    f"takeaway: {poor_gross_nominal:.1f}% before OOP, {poor_net_nominal:.1f}% "
    f"after OOP, or {impov_nominal:+.1f} pp; shown as sensitivity because "
    "nominal pctot_consumption is not the official poverty welfare measure. "
    "Source: NLSS IV; individual sampling weights."
)
fig.text(0.02, -0.005, caption, fontsize=7.5, wrap=True,
         ha="left", va="top", style="italic", color="#444")

plt.tight_layout(rect=(0, 0.03, 1, 1))

# ---------------------------------------------------------------------------
# Save
# ---------------------------------------------------------------------------
pdf_path = OUT_DIR / "pens_parade_oop.pdf"
png_path = OUT_DIR / "pens_parade_oop.png"
fig.savefig(pdf_path, bbox_inches="tight")
fig.savefig(png_path, bbox_inches="tight", dpi=200)
plt.close(fig)

# ---------------------------------------------------------------------------
# Diagnostics
# ---------------------------------------------------------------------------
print(f"Saved: {pdf_path}")
print(f"Saved: {png_path}\n")
print("Summary (monthly basis, real values):")
print(f"  N households                                : {len(pcep_s):,}")
print(f"  Mean pcep (ind-wt)                          : {mean_pcep:,.0f} NPR/month")
print(f"  Total poverty line (per-capita)             : {pline_month:,.0f} NPR/month")
print(f"  Food poverty line  (per-capita)             : {fpline_month:,.0f} NPR/month")
print(f"  Headcount poor BEFORE OOP (official)        : {poor_gross_pop:.2f}%")
print(f"  Headcount poor AFTER  OOP                   : {poor_net_pop:.2f}%")
print(f"  OOP-induced impoverishment                  : {impov_pop:+.2f} pp")
print(f"  People pushed below poverty line by OOP     : {abs_pushed:,.0f}")
print(f"  Households crossing the threshold           : {n_hh_pushed:,}")
print(f"  Households with net pcep <= 0 after OOP     : {neg_count}")
print("\nPrevious-try nominal per-capita takeaway (sensitivity only):")
print(f"  Headcount poor BEFORE OOP (pctot < pline)   : {poor_gross_nominal:.1f}%")
print(f"  Headcount poor AFTER  OOP (nominal net)     : {poor_net_nominal:.1f}%")
print(f"  OOP-induced impoverishment                  : {impov_nominal:+.1f} pp")
