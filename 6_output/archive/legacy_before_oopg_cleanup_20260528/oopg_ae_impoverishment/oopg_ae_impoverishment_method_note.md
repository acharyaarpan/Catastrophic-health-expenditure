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

- Pre-OOPG poverty: 18.80%
- Post-payment poverty: 20.27%
- Increase: +1.47 percentage points
- People pushed below poverty: 421,261
- Households pushed below poverty: 131
