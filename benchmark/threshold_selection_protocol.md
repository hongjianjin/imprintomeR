# Prespecified threshold-selection protocol for imprintomeR

- **Protocol version:** 1.0
- **Registered:** 2026-10-22, before any threshold tuning.
- **Package state when the protocol was written:** commit `2ecca82`.

This protocol fixes how the exploratory thresholds of imprintomeR are evaluated and, where justified, replaced, before any tuning is done. The thresholds in scope are:
- the per-ICR altered call (|deviation| ≥ 0.15 and |z| ≥ 3);
- the sample-level IDS cutoff (0.2) and its confidence tiers (0.1 / 0.2 / 0.4).

The protocol and its analysis script (`run_threshold_selection.R`) are committed to the public repository before they are run, so that the commit history records the order. Every analysis outside this protocol is reported as exploratory.

## 1. Disclosure of prior exposure

The current defaults were set a priori:
- 0.15 / z ≥ 3 were proposed in the analysis plan of 2026-10-21, before any per-ICR result was seen;
- 0.2 and 0.1 / 0.2 / 0.4 come from the submitted version.

All development cohorts listed in section 3 have, however, already been scored with these defaults during the revision. They are therefore not independent of the defaults. The protocol compensates in two ways:
- it evaluates the selection by leave-one-cohort-out cross-validation;
- it requires a separate held-out validation on cohorts not analysed before this registration (section 6).

## 2. What is fixed and what is tuned

**Fixed (not tuned)**

| Item | Setting |
|---|---|
| Panel | `selected`, hg38 annotation; per-ICR scores use every annotated ICR |
| Probes per ICR | at least 3 (`min_probes = 3`) |
| ICR not counted | VTRNA2-1:DMR (polymorphic imprinting) |
| Multi-locus flag | altered ICRs on at least 2 chromosomes |
| Control spread for z | standard deviation floored at 0.02 |
| Data | the beta matrices listed in the manifest, as distributed (no re-normalization) |

**Reference rule**
- in-cohort controls when the cohort has at least 3 of them, each control scored leave-one-out;
- otherwise platform- and tissue-matched external controls (450K blood: the GSE78773 and GSE104451 controls), added to the cohort as a labelled group and scored leave-one-out;
- cohorts with neither are not used.

**Tuned (per-ICR call)**
- `delta_cutoff` ∈ {0.050, 0.075, …, 0.300} (step 0.025);
- `z_cutoff` ∈ {off, 2, 2.5, 3, 3.5, 4}.

**Tuned (sample-level IDS cutoff)**
- cutoff ∈ {0.05, 0.06, …, 0.40}.

## 3. Development cohorts and truth labels

Cohorts, files and labels are listed in `manifest_development.tsv` and `labels_development.tsv`. The SHA-256 of every input file is written to the run log before any score is computed.

| Cohort | Platform | Controls (reference) | Labelled groups used |
|---|---|---|---|
| GSE104451 | 450K blood | 16 in-cohort | 11p15 LOM (20), mUPD7 (10), pUPD7 (1) |
| GSE166531 | 450K blood | external | BWS with paternal UPD11 (30), mUPD7 (4) |
| GSE64244 | 450K blood | external | chromosome-level maternal/paternal UPD of autosomes (`mUPD_chrN`, `pUPD_chrN`) |
| GSE78773 | 450K blood | 47 in-cohort | MLID (22), SLID (26); controls |
| GSE237503 | EPIC blood | 4 in-cohort | controls; BWS/SRS without subtype (secondary endpoint only) |
| GSE195873 | EPIC blood | 12 in-cohort | controls; BWS without subtype (secondary endpoint only) |

**Excluded from tuning:**
- genome-wide UPD (complete moles, ovarian teratomas): trivially detected, and they would inflate sensitivity;
- UPD of unknown parental origin, 45,X, and clinical diagnoses without a molecular subtype;
- GSE52576: no matched controls, mixed tissues.

## 4. Endpoints

### E1 (primary): per-ICR altered call

The unit is one ICR in one sample.

**Positive units:** the ICRs that a molecular label implicates, in the expected direction.

| Label | Positive units |
|---|---|
| 11p15 LOM (H19 LOM) | H19/IGF2:IG-DMR loss |
| IC1 GOM | H19/IGF2:IG-DMR gain |
| IC2 LOM | KCNQ1OT1:TSS-DMR loss |
| Paternal UPD11 (BWS) | KCNQ1OT1:TSS-DMR loss and H19/IGF2:IG-DMR gain |
| Maternal UPD of chromosome N (mUPD7 included) | every scored ICR on chromosome N: maternal ICRs gain, paternal ICRs loss |
| Paternal UPD of chromosome N | the reverse |

**Negative units:** every scored ICR in every control sample. External controls added as a reference are counted only in their own cohort.

**Not used:** ICRs that the label does not implicate in cases, whose status is unknown.

**Calling and metrics**
- A positive unit is detected when it is called altered in the expected direction.
- A negative unit is a false positive when it is called altered in either direction.
- Sensitivity = detected positives / positives; specificity = 1 − false positives / negatives.

**Selection rule**
1. Choose the (`delta_cutoff`, `z_cutoff`) pair with the highest sensitivity among pairs with specificity ≥ 0.995.
2. Break ties by the larger `delta_cutoff`, then the larger `z_cutoff` (`off` counts as smallest).
3. If no pair reaches 0.995, choose the pair with the highest Youden index (sensitivity + specificity − 1), with the same tie-breaks.

### E2: multi-locus flag (evaluated, not tuned)

With the E1 thresholds, report:
- the flag rate in GSE78773 MLID cases (sensitivity);
- the flag rate in SLID cases and in controls (1 − specificity, each separately).

### E3: sample-level IDS cutoff and tiers

The sample-level IDS uses the fixed 0.5 reference, as published.

**Panel per label**
- `chr11p15` for 11p15 labels (11p15 LOM, IC1 GOM, IC2 LOM, paternal UPD11);
- `selected` (gametic default) for chromosome-level UPD.

**Comparison:** cases against the controls of their own cohort. For external-reference cohorts, cases against the external controls.

**Analysis**
- The cutoff maximizes the Youden index; ties go to the cutoff closest to 0.2.
- Report the AUC per label, and sensitivity and specificity at 0.1, 0.2, 0.4 and at the selected cutoff.

### Secondary endpoint (report only)

For clinical BWS and SRS without a molecular subtype (GSE237503, GSE195873), report the proportion of cases with an expected-locus call at the E1 thresholds:
- BWS: IC2 loss or IC1 gain;
- SRS: IC1 loss or gain at maternal chr7 ICRs.

## 5. Internal validation: leave-one-cohort-out cross-validation

For each development cohort with at least one positive or negative unit:
1. Select the thresholds on the other cohorts with the rule above.
2. Apply them to the held-out cohort.

Pooled out-of-cohort predictions give the cross-validated sensitivity and specificity (E1) and the cross-validated E3 metrics.

**Confidence intervals:** 95% intervals from a cluster bootstrap that resamples samples within cohorts, keeping all of a sample's ICR units together (2,000 replicates, seed 20261022).

**Final thresholds:** selected once on all development cohorts. The apparent (resubstitution) metrics are reported alongside the cross-validated ones, and only the cross-validated ones are used as performance estimates.

## 6. Held-out validation

The final thresholds are frozen in `selected_thresholds.tsv` and evaluated, without any further tuning, on held-out cohorts that meet all of the following:
- not analysed in this revision before this registration;
- with molecular diagnoses (MS-MLPA or equivalent) at the subtype level;
- with in-cohort controls or matched external controls.

Before any held-out cohort is scored:
- its accession, inclusion reason, file checksums and label table are added to this file as an amendment;
- the amendment is committed.

Held-out results are reported whatever they show. If no eligible cohort is available at submission, the manuscript states that the thresholds are validated by cross-validation only.

## 7. Reporting

**Report all of the following:**
- the full threshold grid (sensitivity and specificity per pair);
- the selected thresholds;
- cross-validated and apparent metrics with 95% CIs;
- per-label and per-cohort breakdowns;
- the input checksums.

**If the selection differs from the current defaults:**
- adopt the selected values as the new package defaults;
- keep the old defaults documented.

**If it does not differ:** report the defaults as confirmed.

## 8. Amendments

Any change to this protocol after registration is appended below, with the date, the reason, and whether results had been seen.

| Date | Change | Results seen? |
|---|---|---|
| 2026-10-22 | Protocol registered (version 1.0). | No (thresholds not tuned) |
