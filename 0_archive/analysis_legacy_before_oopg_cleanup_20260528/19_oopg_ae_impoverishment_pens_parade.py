"""
3_analysis/19_oopg_ae_impoverishment_pens_parade.py

OOPG adult-equivalent Pen's Parade and impoverishment - Nepal NLSS IV
=====================================================================

This figure displays OOPG pre/post-payment welfare as a multiple of the
official poverty line while retaining the official NLSS per-capita poverty
classification.

The household-specific AE poverty threshold is only a visual transformation
of the official per-capita line:

    AE welfare             = per-capita welfare * hhsize / adult_equiv
    AE poverty threshold   = pline * hhsize / adult_equiv

Therefore poverty and OOPG-impoverishment status are exactly the same as the
official per-capita definitions:

    poor_post      = pcep < pline
    poor_pre_oopg  = pre_oopg < pline
    impoverished   = pre_oopg >= pline and pcep < pline

When the display is normalized so the poverty line equals 1, the
adult-equivalent factor cancels out of the y-axis:

    AE welfare / AE poverty threshold = per-capita welfare / pline

Outputs
-------
6_output/main_output/oopg_ae_impoverishment/
    oopg_ae_impoverishment_pens_parade.pdf
    oopg_ae_impoverishment_pens_parade.png
    oopg_pc_impoverishment_pens_parade.pdf
    oopg_pc_impoverishment_pens_parade.png
    oopg_ae_impoverishment_summary.csv
    oopg_ae_impoverishment_data.xlsx
    oopg_ae_impoverishment_method_note.md
"""

from pathlib import Path
from textwrap import dedent

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd


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


def wmean(values: np.ndarray, weights: np.ndarray) -> float:
    return float(np.sum(values * weights) / np.sum(weights))


try:
    PROJECT_ROOT = Path(__file__).resolve().parents[1]
except NameError:
    PROJECT_ROOT = _find_project_root()

DATA_PATH = PROJECT_ROOT / "1_data" / "2_clean" / "catastrophic_health_exp.dta"
POVERTY_IMPACT_PATH = PROJECT_ROOT / "6_output" / "main_output" / "poverty_impact.csv"
OUT_DIR = PROJECT_ROOT / "6_output" / "main_output" / "oopg_ae_impoverishment"
OUT_DIR.mkdir(parents=True, exist_ok=True)

assert DATA_PATH.exists(), f"Missing data: {DATA_PATH}"
assert POVERTY_IMPACT_PATH.exists(), (
    "Missing poverty impact output. Run 0_master.do first so "
    f"{POVERTY_IMPACT_PATH} is available for reconciliation."
)


df = pd.read_stata(DATA_PATH, convert_categoricals=False)

required = [
    "psu_number",
    "hh_number",
    "hhsize",
    "adult_equiv",
    "ind_wt",
    "pcep",
    "pcep_food",
    "pcep_nonfood",
    "pline",
    "pre_oopg",
    "oopg",
    "oopg_pc_ann_real",
]
missing = [col for col in required if col not in df.columns]
assert not missing, f"Missing required columns: {missing}"

assert len(df) == 9600, f"Expected 9,600 households, found {len(df):,}"
assert (df["adult_equiv"].astype(float) > 0).all()
assert (df["hhsize"].astype(float) > 0).all()
assert (df["ind_wt"].astype(float) > 0).all()
assert (
    df["pcep"].astype(float)
    - (df["pcep_food"].astype(float) + df["pcep_nonfood"].astype(float))
).abs().max() < 1
assert (df["pre_oopg"].astype(float) + 1e-9 >= df["pcep"].astype(float)).all()

pcep = df["pcep"].astype(float)
pre_oopg = df["pre_oopg"].astype(float)
hhsize = df["hhsize"].astype(float)
adult_equiv = df["adult_equiv"].astype(float)
ind_wt = df["ind_wt"].astype(float)
pline = df["pline"].astype(float)
oopg_pc_ann_real = df["oopg_pc_ann_real"].astype(float)

ae_factor = hhsize / adult_equiv
post_ae_annual = pcep * ae_factor
pre_oopg_ae_annual = pre_oopg * ae_factor
pline_ae_annual = pline * ae_factor
oopg_ae_annual = oopg_pc_ann_real * ae_factor

post_ae_month = post_ae_annual / 12.0
pre_oopg_ae_month = pre_oopg_ae_annual / 12.0
pline_ae_month = pline_ae_annual / 12.0
oopg_ae_month = oopg_ae_annual / 12.0

poor_post = pcep < pline
poor_pre_oopg = pre_oopg < pline
oopg_impoverished = (pre_oopg >= pline) & poor_post

post_ae_poor = post_ae_annual < pline_ae_annual
pre_oopg_ae_poor = pre_oopg_ae_annual < pline_ae_annual
assert np.array_equal(post_ae_poor.to_numpy(), poor_post.to_numpy()), (
    "AE-transformed post-payment poverty does not match official pcep < pline."
)
assert np.array_equal(pre_oopg_ae_poor.to_numpy(), poor_pre_oopg.to_numpy()), (
    "AE-transformed pre-OOPG poverty does not match official pre_oopg < pline."
)

mask = (
    post_ae_month.notna()
    & pre_oopg_ae_month.notna()
    & pline_ae_month.notna()
    & ind_wt.notna()
    & (ind_wt > 0)
).to_numpy()

post_ae = post_ae_month.to_numpy()[mask]
pre_oopg_ae = pre_oopg_ae_month.to_numpy()[mask]
pline_ae = pline_ae_month.to_numpy()[mask]
oopg_ae = oopg_ae_month.to_numpy()[mask]
w = ind_wt.to_numpy()[mask]
poor_post_m = poor_post.to_numpy()[mask]
poor_pre_oopg_m = poor_pre_oopg.to_numpy()[mask]
oopg_impoverished_m = oopg_impoverished.to_numpy()[mask]

assert (post_ae > 0).all(), "log-scale plot requires strictly positive welfare"
assert (pre_oopg_ae + 1e-9 >= post_ae).all()
assert (pline_ae > 0).all()

order = np.argsort(pre_oopg_ae)
post_ae_s = post_ae[order]
pre_oopg_ae_s = pre_oopg_ae[order]
pline_ae_s = pline_ae[order]
oopg_ae_s = oopg_ae[order]
w_s = w[order]
poor_post_s = poor_post_m[order]
poor_pre_oopg_s = poor_pre_oopg_m[order]
oopg_impoverished_s = oopg_impoverished_m[order]

cum_share = np.cumsum(w_s) / w_s.sum() * 100.0

OFFICIAL_HEADCOUNT_PCT = 20.27
poor_post_pct = wmean(poor_post_s.astype(float), w_s) * 100
poor_pre_oopg_pct = wmean(poor_pre_oopg_s.astype(float), w_s) * 100
impov_oopg_pp = poor_post_pct - poor_pre_oopg_pct
people_oopg = float(np.sum(w_s[oopg_impoverished_s]))
households_oopg = int(np.sum(oopg_impoverished_s))

assert abs(poor_post_pct - OFFICIAL_HEADCOUNT_PCT) < 0.05, (
    f"post-payment headcount {poor_post_pct:.2f}% does not reproduce "
    f"the official {OFFICIAL_HEADCOUNT_PCT:.2f}% within 0.05 pp"
)

poverty_impact = pd.read_csv(POVERTY_IMPACT_PATH)
oopg_poverty_row = poverty_impact[
    (poverty_impact["scope"] == "oopg")
    & (poverty_impact["metric"] == "poverty_headcount")
]
assert len(oopg_poverty_row) == 1, "Expected one OOPG poverty_headcount row."
ref = oopg_poverty_row.iloc[0]
assert abs(float(ref["pre_estimate"]) * 100 - poor_pre_oopg_pct) < 0.01
assert abs(float(ref["post_estimate"]) * 100 - poor_post_pct) < 0.01
assert abs(float(ref["difference"]) * 100 - impov_oopg_pp) < 0.01
assert abs(float(ref["people_pushed"]) - people_oopg) < 1.0
assert int(ref["households_pushed"]) == households_oopg

mean_post_ae = float(np.average(post_ae_s, weights=w_s))
mean_pre_oopg_ae = float(np.average(pre_oopg_ae_s, weights=w_s))
mean_oopg_ae = float(np.average(oopg_ae_s, weights=w_s))
median_ae_threshold = float(np.average(pline_ae_s, weights=w_s))

post_pc_month = (pcep / 12.0).to_numpy()[mask]
pre_oopg_pc_month = (pre_oopg / 12.0).to_numpy()[mask]
pline_pc_month = float(pline.iloc[0] / 12.0)
order_pc = np.argsort(pre_oopg_pc_month)
post_pc_s = post_pc_month[order_pc]
pre_oopg_pc_s = pre_oopg_pc_month[order_pc]
w_pc_s = w[order_pc]
poor_post_pc_s = poor_post_m[order_pc]
poor_pre_oopg_pc_s = poor_pre_oopg_m[order_pc]
oopg_impoverished_pc_s = oopg_impoverished_m[order_pc]
cum_share_pc = np.cumsum(w_pc_s) / w_pc_s.sum() * 100.0
mean_post_pc = float(np.average(post_pc_s, weights=w_pc_s))
mean_pre_oopg_pc = float(np.average(pre_oopg_pc_s, weights=w_pc_s))

post_ae_multiple = post_ae_annual.to_numpy()[mask] / pline_ae_annual.to_numpy()[mask]
pre_oopg_ae_multiple = (
    pre_oopg_ae_annual.to_numpy()[mask] / pline_ae_annual.to_numpy()[mask]
)
post_pc_multiple = pcep.to_numpy()[mask] / pline.to_numpy()[mask]
pre_oopg_pc_multiple = pre_oopg.to_numpy()[mask] / pline.to_numpy()[mask]

assert np.allclose(post_ae_multiple, post_pc_multiple)
assert np.allclose(pre_oopg_ae_multiple, pre_oopg_pc_multiple)

order_ae_multiple = np.argsort(pre_oopg_ae_multiple)
pre_oopg_ae_multiple_s = pre_oopg_ae_multiple[order_ae_multiple]
post_ae_multiple_s = post_ae_multiple[order_ae_multiple]
w_ae_multiple_s = w[order_ae_multiple]
cum_share_ae_multiple = np.cumsum(w_ae_multiple_s) / w_ae_multiple_s.sum() * 100.0

order_pc_multiple = np.argsort(pre_oopg_pc_multiple)
pre_oopg_pc_multiple_s = pre_oopg_pc_multiple[order_pc_multiple]
post_pc_multiple_s = post_pc_multiple[order_pc_multiple]
w_pc_multiple_s = w[order_pc_multiple]
cum_share_pc_multiple = np.cumsum(w_pc_multiple_s) / w_pc_multiple_s.sum() * 100.0


def draw_pen_parade(
    *,
    path_base: Path,
    cum_pct: np.ndarray,
    pre: np.ndarray,
    post: np.ndarray,
    title: str,
    ylabel: str,
    xlabel: str,
    pre_label: str,
    post_label: str,
    y_cap: float = 10.0,
) -> None:
    fig, ax = plt.subplots(figsize=(11.0, 6.4))
    ax.vlines(
        cum_pct,
        post,
        pre,
        color="#E69F00",
        lw=0.55,
        alpha=0.45,
        label="OOPG payment drop",
        zorder=1,
    )
    ax.plot(
        cum_pct,
        pre,
        color="#0072B2",
        lw=1.2,
        label=pre_label,
        zorder=3,
    )
    ax.plot(
        cum_pct,
        post,
        color="#D55E00",
        lw=0.95,
        alpha=0.96,
        label=post_label,
        zorder=2,
    )
    ax.axhline(
        1.0,
        color="#222222",
        ls="--",
        lw=1.25,
        alpha=0.90,
        label="Poverty line = 1",
    )

    ax.set_xlim(0, 100)
    ax.set_ylim(0, y_cap)
    ax.set_xlabel(xlabel)
    ax.set_ylabel(ylabel)
    ax.set_title(title, fontsize=12, pad=10)
    ax.grid(True, which="major", alpha=0.30, lw=0.6)
    ax.legend(loc="upper left", fontsize=8.7, framealpha=0.95)
    plt.tight_layout()
    fig.savefig(path_base.with_suffix(".pdf"), bbox_inches="tight")
    fig.savefig(path_base.with_suffix(".png"), bbox_inches="tight", dpi=200)
    plt.close(fig)


plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 10})

pdf_path = OUT_DIR / "oopg_ae_impoverishment_pens_parade.pdf"
png_path = OUT_DIR / "oopg_ae_impoverishment_pens_parade.png"
pc_pdf_path = OUT_DIR / "oopg_pc_impoverishment_pens_parade.pdf"
pc_png_path = OUT_DIR / "oopg_pc_impoverishment_pens_parade.png"
summary_path = OUT_DIR / "oopg_ae_impoverishment_summary.csv"
xlsx_path = OUT_DIR / "oopg_ae_impoverishment_data.xlsx"
note_path = OUT_DIR / "oopg_ae_impoverishment_method_note.md"

draw_pen_parade(
    path_base=OUT_DIR / "oopg_ae_impoverishment_pens_parade",
    cum_pct=cum_share_ae_multiple,
    pre=pre_oopg_ae_multiple_s,
    post=post_ae_multiple_s,
    title=(
        "OOPG Adult-Equivalent Pen's Parade - "
        "Nepal NLSS IV (2022/23)"
    ),
    ylabel="Welfare as a multiple of the official poverty line",
    xlabel=(
        "Cumulative population share (%) - sorted by pre-OOPG "
        "poverty-line multiple"
    ),
    pre_label="Pre-OOPG welfare",
    post_label="Post-payment welfare",
)

draw_pen_parade(
    path_base=OUT_DIR / "oopg_pc_impoverishment_pens_parade",
    cum_pct=cum_share_pc_multiple,
    pre=pre_oopg_pc_multiple_s,
    post=post_pc_multiple_s,
    title=(
        "OOPG Per-Capita Pen's Parade - "
        "Nepal NLSS IV (2022/23)"
    ),
    ylabel="Welfare as a multiple of the official poverty line",
    xlabel=(
        "Cumulative population share (%) - sorted by pre-OOPG "
        "poverty-line multiple"
    ),
    pre_label="Pre-OOPG welfare",
    post_label="Post-payment welfare",
)

summary = pd.DataFrame(
    [
        {
            "scope": "oopg",
            "welfare_display": "adult_equivalent",
            "poverty_classification": "official_per_capita",
            "pre_poverty_pct": poor_pre_oopg_pct,
            "post_poverty_pct": poor_post_pct,
            "impoverishment_pp": impov_oopg_pp,
            "people_pushed": people_oopg,
            "households_pushed": households_oopg,
            "mean_pre_oopg_ae_month": mean_pre_oopg_ae,
            "mean_post_ae_month": mean_post_ae,
            "mean_oopg_ae_month": mean_oopg_ae,
            "weighted_mean_ae_poverty_threshold_month": median_ae_threshold,
            "mean_pre_oopg_pc_month": mean_pre_oopg_pc,
            "mean_post_pc_month": mean_post_pc,
            "official_poverty_line_pc_month": pline_pc_month,
        }
    ]
)
summary.to_csv(summary_path, index=False)

audit = df.loc[
    mask,
    [
        "psu_number",
        "hh_number",
        "hhsize",
        "adult_equiv",
        "ind_wt",
        "pcep",
        "pre_oopg",
        "pline",
        "oopg",
        "oopg_pc_ann_real",
    ],
].copy()
audit["ae_factor"] = ae_factor.loc[mask].to_numpy()
audit["post_ae_annual"] = post_ae_annual.loc[mask].to_numpy()
audit["pre_oopg_ae_annual"] = pre_oopg_ae_annual.loc[mask].to_numpy()
audit["pline_ae_annual"] = pline_ae_annual.loc[mask].to_numpy()
audit["oopg_ae_annual"] = oopg_ae_annual.loc[mask].to_numpy()
audit["post_ae_month"] = post_ae_month.loc[mask].to_numpy()
audit["pre_oopg_ae_month"] = pre_oopg_ae_month.loc[mask].to_numpy()
audit["pline_ae_month"] = pline_ae_month.loc[mask].to_numpy()
audit["oopg_ae_month"] = oopg_ae_month.loc[mask].to_numpy()
audit["post_pc_month"] = post_pc_month
audit["pre_oopg_pc_month"] = pre_oopg_pc_month
audit["pline_pc_month"] = pline_pc_month
audit["post_pc_poverty_multiple"] = post_pc_multiple
audit["pre_oopg_pc_poverty_multiple"] = pre_oopg_pc_multiple
audit["post_ae_poverty_multiple"] = post_ae_multiple
audit["pre_oopg_ae_poverty_multiple"] = pre_oopg_ae_multiple
audit["poor_post_official"] = poor_post.loc[mask].astype(int).to_numpy()
audit["poor_pre_oopg_official"] = poor_pre_oopg.loc[mask].astype(int).to_numpy()
audit["oopg_impoverished"] = oopg_impoverished.loc[mask].astype(int).to_numpy()
audit["sort_rank_pre_oopg_ae"] = np.empty(len(audit), dtype=float)
audit.iloc[order, audit.columns.get_loc("sort_rank_pre_oopg_ae")] = (
    np.arange(1, len(audit) + 1)
)
audit["cum_population_share_sorted"] = np.nan
audit.iloc[order, audit.columns.get_loc("cum_population_share_sorted")] = cum_share
audit["sort_rank_pre_oopg_pc"] = np.empty(len(audit), dtype=float)
audit.iloc[order_pc, audit.columns.get_loc("sort_rank_pre_oopg_pc")] = (
    np.arange(1, len(audit) + 1)
)
audit["cum_population_share_pc_sorted"] = np.nan
audit.iloc[order_pc, audit.columns.get_loc("cum_population_share_pc_sorted")] = (
    cum_share_pc
)
audit["sort_rank_pre_oopg_ae_multiple"] = np.empty(len(audit), dtype=float)
audit.iloc[
    order_ae_multiple, audit.columns.get_loc("sort_rank_pre_oopg_ae_multiple")
] = np.arange(1, len(audit) + 1)
audit["cum_population_share_ae_multiple_sorted"] = np.nan
audit.iloc[
    order_ae_multiple,
    audit.columns.get_loc("cum_population_share_ae_multiple_sorted"),
] = cum_share_ae_multiple
audit["sort_rank_pre_oopg_pc_multiple"] = np.empty(len(audit), dtype=float)
audit.iloc[
    order_pc_multiple, audit.columns.get_loc("sort_rank_pre_oopg_pc_multiple")
] = np.arange(1, len(audit) + 1)
audit["cum_population_share_pc_multiple_sorted"] = np.nan
audit.iloc[
    order_pc_multiple,
    audit.columns.get_loc("cum_population_share_pc_multiple_sorted"),
] = cum_share_pc_multiple

checks = pd.DataFrame(
    [
        {
            "check": "Dataset has 9,600 households",
            "status": "PASS",
            "value": len(df),
        },
        {
            "check": "Official post-payment poverty headcount (%)",
            "status": "PASS",
            "value": poor_post_pct,
        },
        {
            "check": "AE post poverty equals official pcep < pline",
            "status": "PASS",
            "value": int((post_ae_poor == poor_post).sum()),
        },
        {
            "check": "AE pre-OOPG poverty equals official pre_oopg < pline",
            "status": "PASS",
            "value": int((pre_oopg_ae_poor == poor_pre_oopg).sum()),
        },
        {
            "check": "Reconciles with poverty_impact.csv OOPG row",
            "status": "PASS",
            "value": str(POVERTY_IMPACT_PATH),
        },
    ]
)

with pd.ExcelWriter(xlsx_path, engine="openpyxl") as writer:
    audit.to_excel(writer, sheet_name="Data", index=False)
    summary.to_excel(writer, sheet_name="Summary", index=False)
    checks.to_excel(writer, sheet_name="Checks", index=False)

note_path.write_text(
    dedent(
        f"""\
        # OOPG Adult-Equivalent Impoverishment Pen's Parade

        This output is OOPG-only and uses adult-equivalent welfare for the
        Pen's Parade display.

        Official poverty and impoverishment classifications remain anchored to
        the NLSS IV per-capita welfare method:

        ```text
        poor_post = pcep < pline
        poor_pre_oopg = pre_oopg < pline
        oopg_impoverished = pre_oopg >= pline and pcep < pline
        ```

        The AE poverty threshold is household-specific only because it
        transforms the official line onto the AE y-axis:

        ```text
        pline_ae = pline * hhsize / adult_equiv
        ```

        This is not a new adult-equivalent poverty line. It preserves the
        official poverty status exactly.

        The Pen's Parade is plotted at the household level and ordered by the
        weighted pre-OOPG poverty-line multiple. The y-axis is normalized so
        that the official poverty line equals 1. For the AE figure, both
        welfare and the household-specific transformed threshold are multiplied
        by `hhsize / adult_equiv`, so the normalized welfare multiple is
        identical to the official per-capita poverty-line multiple:

        ```text
        (pre_oopg * hhsize / adult_equiv) / (pline * hhsize / adult_equiv)
        = pre_oopg / pline
        ```

        Therefore the AE and per-capita normalized Pen's Parades preserve the
        same poverty status and the same OOPG-associated impoverishment
        classification. No separate marker is used for pushed households in
        the figure; the manuscript text reports that result. The y-axis is
        capped at 10 poverty-line multiples for readability, while all poverty
        estimates use uncapped household values.

        Headline OOPG impoverishment:

        - Pre-OOPG poverty: {poor_pre_oopg_pct:.2f}%
        - Post-payment poverty: {poor_post_pct:.2f}%
        - Increase: {impov_oopg_pp:+.2f} percentage points
        - People pushed below poverty: {people_oopg:,.0f}
        - Households pushed below poverty: {households_oopg}
        """
    ),
    encoding="utf-8",
)

print(f"Saved: {pdf_path}")
print(f"Saved: {png_path}")
print(f"Saved: {pc_pdf_path}")
print(f"Saved: {pc_png_path}")
print(f"Saved: {summary_path}")
print(f"Saved: {xlsx_path}")
print(f"Saved: {note_path}\n")
print("Summary:")
print(f"  N households                         : {len(df):,}")
print(f"  Pre-OOPG poverty                     : {poor_pre_oopg_pct:.2f}%")
print(f"  Post-payment poverty                 : {poor_post_pct:.2f}%")
print(f"  OOPG-associated impoverishment       : {impov_oopg_pp:+.2f} pp")
print(f"  People pushed below poverty by OOPG  : {people_oopg:,.0f}")
print(f"  Households pushed below poverty      : {households_oopg:,}")
