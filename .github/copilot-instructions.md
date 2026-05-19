# Copilot Instructions for imprintomeR

This repository is an R package for genomic imprinting analysis from EPIC methylation arrays.

## Priorities
1. Preserve scientific correctness.
2. Do not change formulas silently.
3. Prefer small composable functions.
4. Add roxygen2 docs to exported functions.
5. Add testthat tests for scoring logic.
6. Keep plotting functions separate from scoring functions.
7. Preserve maternal vs paternal origin-aware analysis.

## Core definitions
- IDS = sqrt((paternal_median - 0.5)^2 + (maternal_median - 0.5)^2)
- IDI = (beta - 0.5) * 2
- Angle is computed from paternal and maternal deviations relative to 0.5
- Use median aggregation by default for ICR summaries

## Meth_QC Workflow

### Purpose & Scope
`Meth_QC()` preprocesses raw methylation array data into a QC-clean MethQcSet object. It:
- Loads IDAT files by platform (single platform only)
- Extracts beta values and detection p-values
- Computes QC metrics (intensity, detection stats, predicted sex)
- Validates samples against thresholds
- Returns MethQcSet with aligned beta/meta/detection_pval + populated qc_tables

**Critical:** Process one platform at a time. Use `check_platform()` first if needed.

### Key Parameters
- `pcutoff = 0.05` (detection p-value threshold; updated from 0.03)
- `icutoff = 11` (log2 intensity threshold, mMed/uMed must exceed)
- `cov_cutoff = 0.95` (probe coverage: % CpG sites with detection p-val < pcutoff)
- `platform = NULL` (auto-resolved from meta$Platform if present; else must specify)

### QC Table Structure (qc_tables slot)
Populated by `runMethQC()`, accessed via `qc_tables(qcset)`:

- **QC_matrix**: Per-sample QC metrics
  - Sample_Name, Basename, Platform (from meta)
  - mMed, uMed, aveMed (median M/U intensities, merged into single row)
  - pctDetectedCpG_dP0.05 (% probes with detection p-val < pcutoff)
  - predictedSex (from methylation signal at sex-specific probes)
  - Final.QC (PASS if all thresholds met, else FAIL)

- **recall_rate**: Per-probe detection statistics
  - probe_id, pct_detected_all, pct_detected_pass, pct_detected_fail
  - Used to identify poorly-detected probes across cohort

- **cutoffs**: Applied QC thresholds
  - Intensity thresholds (icutoff), detection p-val cutoff (pcutoff), coverage cutoff (cov_cutoff)

- **ctrl_metrics** (optional, if ewastools available):
  - Bisulfite conversion efficiency, specificity, non-polymorphic controls
  - CtrlMetrics.QC (PASS/FAIL based on control signal)

- **contamination** (optional, if ewastools available):
  - SNP agreement matrix for detecting sample swaps

- **predUniqDonor_ID** (optional, if ewastools available):
  - Predicted unique donors per Sample_Group

### Aggregation Logic
- Uses **median** aggregation for intensity summaries (mMed, uMed, aveMed merged into single metric per sample)
- Detection p-values: stored per-probe × per-sample matrix
- Final.QC: logical AND of all thresholds (intensity AND detection AND coverage)

### EPICv2 Handling
- Replicate probes (e.g., cg_XXXXX_TC11, cg_XXXXX_TC12) must be aggregated **before** ImprintomeSet conversion
- Use `aggregate_probes(qcset)` after `runMethQC()` if platform == "EPICv2"
- Reduces ~937k → ~865k unique base probes

### Common Mistakes (Avoid!)
1. **Mixed platforms in one call**: MethQcSet enforces single-platform constraint. Use `check_platform()` + subset first.
2. **Missing Basename column**: Must point to valid IDAT file prefixes (path without _Red.idat/_Grn.idat).
3. **Missing Platform column**: Run `check_platform()` if not present, or specify `platform` parameter explicitly.
4. **EPICv2 without aggregation**: Calling `as.ImprintomeSet()` on EPICv2 qcset without `aggregate_probes()` will error.
5. **Ignoring Final.QC**: Check `qc_matrix$Final.QC` before downstream analysis; FAIL samples should be reviewed/excluded.

### Metadata Column Names (Canonical Form)
Required columns in input metadata:
- **Sample_Name**: Unique sample identifier (case-insensitive input, normalized to Sample_Name)
- **Basename**: IDAT file path prefix (case-sensitive, required for platform detection)
- Additional columns (Sample_Group, SEX, etc.) are preserved and available for plotting/analysis

## Coding style
- Write idiomatic R
- Use roxygen2
- Prefer explicit return values
- Avoid deeply nested code
- Do not introduce new dependencies without justification

## Package structure
- R/: exported and internal functions
- tests/testthat/: unit tests
- man/: generated docs
- vignettes/: workflow docs

## When editing code
- preserve backward compatibility where practical
- refactor giant functions into helpers
- add or update tests when changing scoring logic