"""
3_analysis/3_pens_parade_oop.py

Pen's Parade and health-payment impoverishment - Nepal NLSS IV
==============================================================

Wagstaff / O'Donnell / van Doorslaer-style pre/post-payment figure,
anchored to the official NLSS IV poverty welfare measure.

Important methodological point
------------------------------
NLSS IV excludes health spending from its welfare aggregate. Therefore `pcep`
is already post-payment welfare. Pre-payment welfare is reconstructed by adding
real per-capita health payments back to pcep:

    post-payment welfare = pcep
    pre-oopg welfare      = pcep + real per-capita oopg
    pre-OOP welfare      = pcep + real per-capita OOP

OOP is emphasized because it matches the full-health-payment framing in the
equity analysis book. oopg is shown as the project-specific Section 8B scope.

Outputs
-------
6_output/main_output/pens_parade_oop.pdf
6_output/main_output/pens_parade_oop.png
6_output/main_output/pens_parade_data.xlsx
"""

from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from matplotlib.ticker import FuncFormatter


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
POVERTY_PATH = PROJECT_ROOT / "1_data" / "1_raw" / "poverty.dta"
OUT_DIR = PROJECT_ROOT / "6_output" / "main_output"
OUT_DIR.mkdir(parents=True, exist_ok=True)

assert DATA_PATH.exists(), f"Missing data: {DATA_PATH}"


df = pd.read_stata(DATA_PATH, convert_categoricals=False)

assert len(df) == 9600, f"Expected 9,600 households, found {len(df):,}"
assert abs(df["pcep"].astype(float) - (df["pcep_food"].astype(float) + df["pcep_nonfood"].astype(float))).max() < 1
assert (df["oop"].astype(float) + 1e-9 >= df["oopg"].astype(float)).all()

if "pcep" not in df.columns or "paasche" not in df.columns:
    pov = pd.read_stata(POVERTY_PATH, convert_categoricals=False)
    df = df.merge(
        pov[["psu_number", "hh_number", "pcep", "paasche"]],
        on=["psu_number", "hh_number"],
        how="left",
    )

pcep = df["pcep"].astype(float)
ind_wt = df["ind_wt"].astype(float)
oopg_pc_ann_real = df["oopg_pc_ann_real"].astype(float)
oop_pc_ann_real = df["oop_pc_ann_real"].astype(float)

pline = float(df["pline"].iloc[0])
fpline = float(df["fpline"].iloc[0])

post_annual = pcep
pre_oopg_annual = pcep + oopg_pc_ann_real
pre_oop_annual = pcep + oop_pc_ann_real

post_month = post_annual / 12.0
pre_oopg_month = pre_oopg_annual / 12.0
pre_oop_month = pre_oop_annual / 12.0
oopg_pc_month_real = oopg_pc_ann_real / 12.0
oop_pc_month_real = oop_pc_ann_real / 12.0
pline_month = pline / 12.0
fpline_month = fpline / 12.0

mask = (
    post_month.notna()
    & pre_oopg_month.notna()
    & pre_oop_month.notna()
    & ind_wt.notna()
    & (ind_wt > 0)
).to_numpy()

post = post_month.to_numpy()[mask]
pre_oopg = pre_oopg_month.to_numpy()[mask]
pre_oop = pre_oop_month.to_numpy()[mask]
oopg_amt = oopg_pc_month_real.to_numpy()[mask]
oop_amt = oop_pc_month_real.to_numpy()[mask]
w = ind_wt.to_numpy()[mask]

assert (post > 0).all(), "log-scale plot requires strictly positive pcep"
assert (pre_oopg + 1e-9 >= post).all(), "pre-oopg welfare is below post welfare"
assert (pre_oop + 1e-9 >= post).all(), "pre-OOP welfare is below post welfare"
assert (pre_oop + 1e-9 >= pre_oopg).all(), "OOP should be at least as large as oopg"

order = np.argsort(pre_oop)
post_s = post[order]
pre_oopg_s = pre_oopg[order]
pre_oop_s = pre_oop[order]
oopg_amt_s = oopg_amt[order]
oop_amt_s = oop_amt[order]
w_s = w[order]

cum_share = np.cumsum(w_s) / w_s.sum() * 100.0


def wmean(flag: np.ndarray, weights: np.ndarray) -> float:
    return float(np.sum(weights * flag) / np.sum(weights))


poor_post = wmean((post_s < pline_month).astype(float), w_s) * 100
poor_pre_oopg = wmean((pre_oopg_s < pline_month).astype(float), w_s) * 100
poor_pre_oop = wmean((pre_oop_s < pline_month).astype(float), w_s) * 100
impov_oopg = poor_post - poor_pre_oopg
impov_oop = poor_post - poor_pre_oop

new_oopg = (pre_oopg_s >= pline_month) & (post_s < pline_month)
new_oop = (pre_oop_s >= pline_month) & (post_s < pline_month)
people_oopg = float(np.sum(w_s[new_oopg]))
people_oop = float(np.sum(w_s[new_oop]))
hh_oopg = int(new_oopg.sum())
hh_oop = int(new_oop.sum())

OFFICIAL_HEADCOUNT_PCT = 20.27
assert abs(poor_post - OFFICIAL_HEADCOUNT_PCT) < 0.05, (
    f"post-payment headcount {poor_post:.2f}% does not reproduce the official "
    f"{OFFICIAL_HEADCOUNT_PCT:.2f}% within 0.05 pp"
)

mean_post = float(np.average(post_s, weights=w_s))
mean_pre_oopg = float(np.average(pre_oopg_s, weights=w_s))
mean_pre_oop = float(np.average(pre_oop_s, weights=w_s))


plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 10})

fig, ax = plt.subplots(figsize=(11, 6.8))

ax.plot(
    cum_share,
    pre_oop_s,
    color="#f7b500",
    lw=2.1,
    label="Pre-OOP per-capita consumption (pcep + real OOP)",
)
ax.plot(
    cum_share,
    pre_oopg_s,
    color="#b26b00",
    lw=1.3,
    ls="--",
    alpha=0.95,
    label="Pre-oopg per-capita consumption (pcep + real oopg)",
)
ax.plot(
    cum_share,
    post_s,
    color="#cc1010",
    lw=0.95,
    alpha=0.92,
    label="Post-payment per-capita consumption (official NLSS pcep)",
)

ax.axhline(
    pline_month,
    color="#1f5fbe",
    ls="-",
    lw=1.4,
    alpha=0.85,
    label=f"Total poverty line ({pline_month:,.0f} NPR/month)",
)
ax.axhline(
    fpline_month,
    color="#2ca25f",
    ls="-",
    lw=1.3,
    alpha=0.85,
    label=f"Food poverty line ({fpline_month:,.0f} NPR/month)",
)

ax.axhline(mean_pre_oop, color="#222222", ls=":", lw=0.9, alpha=0.55)
ax.text(
    0.5,
    mean_pre_oop * 1.06,
    f"Mean pre-OOP consumption, {mean_pre_oop:,.0f} NPR/month",
    color="#222222",
    fontsize=8.5,
    va="bottom",
)

ax.set_yscale("log")
ax.yaxis.set_major_formatter(FuncFormatter(lambda y, _: f"{int(y):,}"))
ax.set_xlim(0, 100)
ax.set_ylim(bottom=max(1, post_s.min() * 0.7), top=max(pre_oop_s.max(), mean_pre_oop) * 1.15)
ax.set_xlabel("Cumulative population share (%) - sorted by pre-OOP per-capita consumption")
ax.set_ylabel("Per-capita real consumption, monthly NPR (log scale)")
ax.set_title(
    "Pen's Parade and health-payment impoverishment - Nepal NLSS IV (2022/23)",
    fontsize=12,
    pad=10,
)
ax.grid(True, which="major", alpha=0.30, lw=0.6)
ax.grid(True, which="minor", alpha=0.15, lw=0.4)
ax.legend(loc="upper left", fontsize=8.7, framealpha=0.95)

caption = (
    "Notes: Official NLSS pcep is post-payment welfare because health spending "
    "is excluded from the welfare aggregate. Pre-payment welfare is reconstructed "
    "by adding real per-capita oopg or OOP back to pcep. OOP equals annualized "
    "oopg plus annual NCD OOP, divided by household size and deflated by the "
    "Paasche price index. Poverty headcount is "
    f"{poor_pre_oop:.2f}% pre-OOP and {poor_post:.2f}% post-payment, implying "
    f"{impov_oop:+.2f} pp OOP-associated impoverishment (~{people_oop:,.0f} "
    f"people; {hh_oop} households). OOPG-associated impoverishment is "
    f"{impov_oopg:+.2f} pp (~{people_oopg:,.0f} people; {hh_oopg} households). "
    "Source: NLSS IV; individual sampling weights."
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

plt.tight_layout(rect=(0, 0.04, 1, 1))

pdf_path = OUT_DIR / "pens_parade_oop.pdf"
png_path = OUT_DIR / "pens_parade_oop.png"
xlsx_path = OUT_DIR / "pens_parade_data.xlsx"
fig.savefig(pdf_path, bbox_inches="tight")
fig.savefig(png_path, bbox_inches="tight", dpi=200)
plt.close(fig)

audit = df.loc[
    mask,
    [
        "psu_number",
        "hh_number",
        "hhsize",
        "ind_wt",
        "oopg",
        "oop",
        "hh_comm_total_30d",
        "hh_ncd_total_annual",
    ],
].copy()
audit["pcep_annual_real"] = post_annual.loc[mask].to_numpy()
audit["oopg_per_capita_annual_real"] = oopg_pc_ann_real.loc[mask].to_numpy()
audit["oop_per_capita_annual_real"] = oop_pc_ann_real.loc[mask].to_numpy()
audit["pre_oopg_annual_real"] = pre_oopg_annual.loc[mask].to_numpy()
audit["pre_oop_annual_real"] = pre_oop_annual.loc[mask].to_numpy()
audit["post_payment_annual_real"] = post_annual.loc[mask].to_numpy()
audit["oopg_per_capita_monthly_real"] = oopg_pc_month_real.loc[mask].to_numpy()
audit["oop_per_capita_monthly_real"] = oop_pc_month_real.loc[mask].to_numpy()
audit["pre_oopg_monthly_real"] = pre_oopg_month.loc[mask].to_numpy()
audit["pre_oop_monthly_real"] = pre_oop_month.loc[mask].to_numpy()
audit["post_payment_monthly_real"] = post_month.loc[mask].to_numpy()
audit["post_oop_monthly_real"] = audit["post_payment_monthly_real"]
audit["post_oop_annual_real"] = audit["post_payment_annual_real"]
audit["pcep_monthly_real"] = audit["post_payment_monthly_real"]
audit["pline_annual"] = pline
audit["fpline_annual"] = fpline
audit["poor_pre_oopg"] = (audit["pre_oopg_annual_real"] < pline).astype(int)
audit["poor_pre_oop"] = (audit["pre_oop_annual_real"] < pline).astype(int)
audit["poor_post_payment"] = (audit["post_payment_annual_real"] < pline).astype(int)
audit["oopg_impoverished"] = (
    (audit["pre_oopg_annual_real"] >= pline)
    & (audit["post_payment_annual_real"] < pline)
).astype(int)
audit["oop_impoverished"] = (
    (audit["pre_oop_annual_real"] >= pline)
    & (audit["post_payment_annual_real"] < pline)
).astype(int)

constants = pd.DataFrame(
    {
        "Parameter": [
            "Total poverty line (annual NPR/cap)",
            "Food poverty line (annual NPR/cap)",
            "Official post-payment poverty headcount (%)",
            "Pre-oopg poverty headcount (%)",
            "Pre-OOP poverty headcount (%)",
            "Post-payment poverty headcount (%)",
            "oopg-associated impoverishment (pp)",
            "OOP-associated impoverishment (pp)",
            "People pushed below poverty line by oopg",
            "People pushed below poverty line by OOP",
            "Households crossing poverty line by oopg",
            "Households crossing poverty line by OOP",
            "oopg scope",
            "OOP scope",
        ],
        "Value": [
            pline,
            fpline,
            OFFICIAL_HEADCOUNT_PCT,
            poor_pre_oopg,
            poor_pre_oop,
            poor_post,
            impov_oopg,
            impov_oop,
            people_oopg,
            people_oop,
            hh_oopg,
            hh_oop,
            "hh_comm_total_30d * 12",
            "hh_comm_total_30d * 12 + hh_ncd_total_annual",
        ],
    }
)

with pd.ExcelWriter(xlsx_path, engine="openpyxl") as writer:
    audit.to_excel(writer, sheet_name="Data", index=False)
    constants.to_excel(writer, sheet_name="Constants", index=False)

print(f"Saved: {pdf_path}")
print(f"Saved: {png_path}")
print(f"Saved: {xlsx_path}\n")
print("Summary (monthly real values):")
print(f"  N households                                : {len(pre_oop_s):,}")
print(f"  Mean pre-oopg consumption                    : {mean_pre_oopg:,.0f} NPR/month")
print(f"  Mean pre-OOP consumption                    : {mean_pre_oop:,.0f} NPR/month")
print(f"  Mean post-payment consumption               : {mean_post:,.0f} NPR/month")
print(f"  Total poverty line                          : {pline_month:,.0f} NPR/month")
print(f"  Headcount poor pre-oopg                      : {poor_pre_oopg:.2f}%")
print(f"  Headcount poor pre-OOP                      : {poor_pre_oop:.2f}%")
print(f"  Headcount poor post-payment (official)      : {poor_post:.2f}%")
print(f"  OOPG-associated impoverishment               : {impov_oopg:+.2f} pp")
print(f"  OOP-associated impoverishment               : {impov_oop:+.2f} pp")
print(f"  People pushed below poverty line by OOPG     : {people_oopg:,.0f}")
print(f"  People pushed below poverty line by OOP     : {people_oop:,.0f}")
