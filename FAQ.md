# imprintomeR FAQ: choosing cutoffs and interpreting results

Written for imprintomeR 1.5.3.

## Contents

- [The scores](#the-scores)
  - [What do IDS, Angle and Mechanism mean?](#what-do-ids-angle-and-mechanism-mean)
  - [What does IDS mean with a control reference?](#what-does-ids-mean-with-a-control-reference)
  - [Which panel should I use?](#which-panel-should-i-use)
- [Choosing a cutoff](#choosing-a-cutoff)
  - [Is IDS 0.2 the right cutoff?](#is-ids-02-the-right-cutoff)
  - [How many controls do I need?](#how-many-controls-do-i-need)
  - [What if some controls look abnormal?](#what-if-some-controls-look-abnormal)
  - [Is there a natural break in the data I can use?](#is-there-a-natural-break-in-the-data-i-can-use)
- [Uncertainty](#uncertainty)
  - [How do I get confidence intervals?](#how-do-i-get-confidence-intervals)
  - [How should I call individual samples?](#how-should-i-call-individual-samples)
  - [Why are my selected-panel intervals so wide?](#why-are-my-selected-panel-intervals-so-wide)
  - [Can I use Mechanism_support as a cutoff instead of IDS?](#can-i-use-mechanism_support-as-a-cutoff-instead-of-ids)
  - [What about the origin-permutation p-value?](#what-about-the-origin-permutation-p-value)
  - [Should I use the Confidence column?](#should-i-use-the-confidence-column)
- [Per-ICR results](#per-icr-results)
  - [How is an ICR called altered?](#how-is-an-icr-called-altered)
  - [How should I read IC1/IC2 calls on chr11p15?](#how-should-i-read-ic1ic2-calls-on-chr11p15)
  - [What does the multi-locus (MLID) flag mean?](#what-does-the-multi-locus-mlid-flag-mean)
  - [Do sample-level IDS calls agree with the per-ICR calls?](#do-sample-level-ids-calls-agree-with-the-per-icr-calls)
- [Practical questions](#practical-questions)
  - [My beta file is too large to load](#my-beta-file-is-too-large-to-load)
  - [How do I make a readable per-ICR heatmap for hundreds of samples?](#how-do-i-make-a-readable-per-icr-heatmap-for-hundreds-of-samples)
  - [A reference group with a space in its name is not found](#a-reference-group-with-a-space-in-its-name-is-not-found)
  - [The command-line run ends with a differing number of rows error](#the-command-line-run-ends-with-a-differing-number-of-rows-error)
- [Reporting checklist](#reporting-checklist)

---

## The scores

### What do IDS, Angle and Mechanism mean?

For each sample, imprintomeR takes the median methylation of the paternally and maternally
methylated probes of a panel and subtracts the reference (0.5, or each probe's median in the
controls), giving a paternal deviation *x* and a maternal deviation *y*.

- **IDS** (Imprinting Deviation Score) = √(x² + y²): how far the sample is from the reference. Magnitude only.
- **Angle** = atan2(y, x), 0–360°: the direction of the shift.
- **Mechanism**: the 45° sector the Angle falls in (Pat-Gain, Pat-Gain+Mat-Loss, Mat-Loss, …), or
  **ROI** (retention of imprinting) when IDS is below the cutoff.

These describe bulk methylation along the annotated paternal and maternal axes. They are not
parent-of-origin calls.

### What does IDS mean with a control reference?

With the fixed 0.5 reference, IDS is the distance from perfect hemimethylation. With
`reference_group` (in-cohort controls) or `reference_beta` (external controls), it is the distance
from the controls: a related but different quantity. Use a control reference whenever
tissue-matched controls exist; normal tissue rarely sits exactly at 0.5.

### Which panel should I use?

| Question | Panel |
|---|---|
| 11p15 (IC1/IC2) disturbance, e.g. BWS, SRS, Wilms tumor | **chr11p15**: its paternal axis is IC1 (H19/IGF2), its maternal axis IC2 (KCNQ1OT1) |
| GNAS (20q13) | **chr20q13** |
| Genome-wide imprinting, UPD, androgenetic/parthenogenetic samples | **selected** (gametic ICRs by default) |
| Which ICRs are altered, multi-locus pattern | **selected** with per-ICR scores (`icr = TRUE`, CLI `--icr`) |

Caution for the selected panel: its paternal gametic axis has only two ICRs (H19/IGF2 with about
43 probes on EPIC, and IGF2 alt-TSS with one), so the sample-level paternal axis is essentially an
11p15 readout, and ICR-level resampling of that axis is unstable (see
[Why are my selected-panel intervals so wide?](#why-are-my-selected-panel-intervals-so-wide)).

---

## Choosing a cutoff

### Is IDS 0.2 the right cutoff?

0.2 is the package default and an **exploratory** screening convention, not a calibrated
diagnostic threshold. Whether it suits your data depends on where your controls lie.

1. **Look at the controls first.** Plot or list the control IDS values. If nearly all controls lie
   below 0.2 with some margin, 0.2 is a reasonable starting point; if several controls approach or
   exceed it, it is too low for that tissue and panel.
2. **Derive control-based cutoffs** with `CalibrateIDS()`:
   ```r
   cal <- CalibrateIDS(results, controls = "control", method = "quantile", probs = 0.99)
   # adds IDS_z (robust z), IDS_control_percentile and Status_calibrated
   ```
   `method = "max"` uses the highest control; `method = "youden"` needs labelled cases.
3. **Report a sensitivity range**, not one number: the number of cases above the cutoff for the
   range of control-based cutoffs (for example the 95th percentile, the maximum, and the maximum
   without outlier controls), alongside the count at 0.2.
4. **If you have molecular labels** (MS-MLPA, copy number/LOH, methylation-specific PCR) for some
   samples, choose the cutoff with `method = "youden", cases = …`; that is the only way to
   calibrate it against truth.

### How many controls do I need?

- At least **5** tissue-matched controls for a control reference (with fewer than 3, the fixed 0.5
  is used with a warning).
- At least **10** for stable per-ICR z-scores (the package warns below 10).
- With fewer than about 20, a "99th percentile" of controls is effectively the maximum and moves
  with every control added or removed; prefer the sensitivity range above.

### What if some controls look abnormal?

Every control is scored leave-one-out, but each one still enters the reference for all other
samples. List controls with IDS ≥ cutoff or a multi-locus flag, check them (adjacency to or
contamination by tumor, batch, array plate, QC), and rerun with them excluded from the reference.
A "normal" tissue sample that shows the same per-ICR pattern as the cases deserves particular
scrutiny.

### Is there a natural break in the data I can use?

Rarely. Case IDS values are usually continuous, often with several peaks but no gap near the
cutoff. Do not pick a cutoff by eye from a histogram of cases.

---

## Uncertainty

### How do I get confidence intervals?

From R (the command-line script has no bootstrap options in 1.5.3):

```r
x <- readRDS("<prefix>_<genome>_imprintomeSet.rds")
x <- runImprintome(x, probeset = "chr11p15", reference_group = "control",
                   n_boot = 2000, resample_reference = TRUE, seed = 1,
                   result_name = "AnalyzeImprintStatus.chr11p15.boot")
res <- results(x)[["AnalyzeImprintStatus.chr11p15.boot"]]
```

This adds `IDS_lower`, `IDS_upper`, `Angle_lower`, `Angle_upper` and `Mechanism_support`; IDS and
Mechanism themselves do not change. Use `resample_reference = TRUE` whenever controls are used, so
the interval includes the uncertainty of the reference. A few thousand replicates of several
hundred samples take seconds.

### How should I call individual samples?

Use the interval, not just the point estimate:

| Interval | Call |
|---|---|
| `IDS_lower ≥ cutoff` | above cutoff |
| `IDS_upper < cutoff` | below cutoff |
| spans the cutoff | **borderline** |

Report the number of borderline samples; near the cutoff it is often large.

### Why are my selected-panel intervals so wide?

The default resampling (`resample = "icr"`) draws ICRs, then probes within them. With very few
ICRs in a parental class (the selected panel's paternal axis: two ICRs, one with a single probe),
some replicates rest on one probe, which widens the interval considerably. Probe resampling
(`resample = "probe"`) is too narrow, because it treats correlated probes as independent; the truth
lies in between. Use the chr11p15 panel for 11p15 conclusions and report selected-panel intervals
descriptively.

### Can I use Mechanism_support as a cutoff instead of IDS?

No. `Mechanism_support` is the fraction of bootstrap replicates that keep the sample's sector. It
measures how stable the **direction label** is, not how abnormal the sample is:

- normal samples have the highest support, because their ROI label is stable;
- support is lowest just above the IDS cutoff, because ROI is itself defined by the cutoff;
- strongly abnormal samples whose Angle lies near a sector boundary have low support, although
  their IDS interval is far above the cutoff.

Use it as a second step: decide "abnormal or not" with IDS (preferably `IDS_lower`), then report the
Mechanism only when `Mechanism_support ≥ 0.8`; otherwise describe the sample as "between sectors"
(for example "Pat-Gain / Pat-Gain+Mat-Loss").

### What about the origin-permutation p-value?

`n_perm` tests whether a sample's deviation depends on the annotated parental origin (a shift
shared by both axes is not significant). It is exploratory: probe-level permutation is
anti-conservative (p ≤ 0.05 in 34% of 122 benchmark controls), ICR-level permutation is the
default (0% of the same controls), and with few ICRs the smallest attainable p is large. It needs
a control reference.

### Should I use the Confidence column?

No. `Confidence` relabels IDS with fixed bands (< 0.1 "High (Normal)", 0.1–0.2 "Low (Normal)",
0.2–0.4 "Moderate (Alteration)", ≥ 0.4 "High (Alteration)"). It ignores the number of probes, the
controls, the tissue and resampling, and its bands do not follow `ids_cutoff`. Bootstrap intervals
of samples labelled "High" often extend into the neighbouring band. Use the interval-based call
above or `CalibrateIDS()` instead.

---

## Per-ICR results

### How is an ICR called altered?

Each ICR with at least 3 probes is scored: deviation d = median(beta − reference) over its probes,
z = (d − median of control d) / max(SD of control d, 0.02), with controls scored leave-one-out. An
ICR is altered when **|d| ≥ 0.175 and |z| ≥ 2**, in either direction. These defaults were selected
under a prespecified protocol in version 1.5.3; earlier versions used 0.075 and 3, so check the
package version that produced your tables.

### How should I read IC1/IC2 calls on chr11p15?

| Pattern | Usual reading (confirm with copy number or allelic data) |
|---|---|
| IC1 gain + IC2 loss | paternal UPD11 / 11p15 LOH |
| IC1 gain only | H19/IGF2 hypermethylation (IGF2 loss of imprinting) |
| IC2 loss only | KCNQ1OT1 loss of methylation |
| neither | no 11p15 methylation defect detected at these thresholds |

### What does the multi-locus (MLID) flag mean?

A sample is flagged when altered ICRs lie on **at least two chromosomes** (VTRNA2-1, polymorphic,
is excluded). It is an algorithmic summary, not a diagnosis.

- In **blood** with same-study controls it tracked array-defined MLID (benchmark GSE78773: 16/21
  MLID, 2/16 single-locus, 0/39 controls flagged).
- In **tumor tissue** it mostly reflects somatic methylation change and can be set in most tumors,
  and in some normal tissue samples too. Always report the flag rate in the controls next to it,
  and confirm constitutional MLID in blood or germline DNA.
- With **controls from another study**, batch offsets produce spurious multi-locus calls; use
  same-study, same-processing controls.

### Do sample-level IDS calls agree with the per-ICR calls?

On chr11p15, compare "IDS ≥ cutoff" with "has an IC1 or IC2 call" across a range of cutoffs: lower
cutoffs flag samples without a per-ICR call, higher cutoffs miss samples that have one. Both use the
same probes, so agreement shows consistency, not validation. For locus-level conclusions, prefer the
per-ICR calls.

---

## Practical questions

### My beta file is too large to load

The panels use few probes (chr11p15: 82, selected: 782; fewer are present on a given array).
Extract those rows first, with probe IDs from `probesets_hg38.rds`, then run on the subset; the
scores are identical:

```r
ps <- readRDS(system.file("extdata", "probesets_hg38.rds", package = "imprintomeR"))
writeLines(as.character(as.data.frame(ps[["chr11p15"]])$NAME), "chr11p15_probes.txt")
```

```bash
{ head -1 beta.txt; grep -F -w -f chr11p15_probes.txt beta.txt; } > beta_chr11p15.txt
```

A multi-gigabyte beta matrix then runs in seconds and in little memory.

### How do I make a readable per-ICR heatmap for hundreds of samples?

```r
p <- PlotICRHeatmap(icr_table, title = "Per-ICR deviation")
ggplot2::ggsave("icr_heatmap_large.jpg", p, width = 8,
                height = max(10, 0.12 * length(unique(icr_table$Sample_Name)) + 4),
                dpi = 200, limitsize = FALSE)
```

`limitsize = FALSE` allows images taller than 50 in. For the selected panel use a width of about
0.3 in per ICR + 4 in.

### A reference group with a space in its name is not found

When the command is stored in a shell variable, run it with `eval "$cmd"` (or `bsub … "$cmd"`);
a bare `$cmd` splits a value such as `"Normal Kidney"` into two words.

### The command-line run ends with a differing number of rows error

In 1.5.3, `run_imprintomeR.R` without `--icr` can end with
`arguments imply differing number of rows: 2, 3, 1` after all results have been written. The
results are complete; add `--icr` to avoid the message.

---

## Reporting checklist

- [ ] Package version, panel, genome, reference (which controls, how many, any excluded).
- [ ] Cutoff, why it was chosen, and the counts across a sensitivity range.
- [ ] Bootstrap settings (`n_boot`, `resample`, `resample_reference`, seed) and the number of borderline samples.
- [ ] Mechanism reported only with adequate `Mechanism_support`, or as "between sectors".
- [ ] Per-ICR thresholds; IC1/IC2 patterns described as methylation-based.
- [ ] Multi-locus flag described as exploratory, with the flag rate in the controls.
- [ ] Not used: the `Confidence` column, or the 0.1/0.2/0.4 bands as certainty levels.
