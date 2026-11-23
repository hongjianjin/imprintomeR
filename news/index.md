# Changelog

## imprintomeR 1.6.0

This release focuses on installation, reproducibility and documentation.
Sample-level scores (IDS, Angle, Mechanism, Status) and per-ICR calls
with default settings are unchanged from 1.5.3.

### Installation

- `DESCRIPTION` has `biocViews`, so `BiocManager::install()`, `remotes`
  and `pak` resolve the Bioconductor dependencies (minfi,
  ComplexHeatmap). The README installs with BiocManager and lists the
  system libraries Linux needs (curl, OpenSSL and libxml2 headers).
- Fewer required packages: pheatmap, Rtsne and cowplot moved to
  `Suggests`, and the functions that use them say so when one is
  missing. ewastools and Vennerable are no longer used.
- Control-probe and SNP quality control in
  [`runMethQC()`](https://hongjianjin.github.io/imprintomeR/reference/runMethQC.md)
  (control metrics, genotype calls, sample-swap check, predicted donors)
  is now native code that follows ewastools 1.8.2 (Heiss and Just 2018)
  and gives identical values on 450K, EPICv1 and EPICv2 IDATs, so
  ewastools no longer needs to be installed. `contamination` is now one
  long table (`donor1`, `sample1`, `donor2`, `sample2`, `agreement`,
  `group`). `run_meth_QC.R --skip-ewastools` is kept as a deprecated,
  ignored flag.
- The data-file note at startup moved from `.onLoad()` to `.onAttach()`.

### Example data and documentation

- New example data: beta values of the 782 `selected` panel probes for
  the 28 samples of GEO GSE52576 (450K), with their metadata, read with
  [`imprintome_example()`](https://hongjianjin.github.io/imprintomeR/reference/imprintome_example.md).
  The README Quick start runs as pasted, on this example and on the
  `minfiData` IDATs.
- Website: <https://hongjianjin.github.io/imprintomeR/>, with the
  function reference grouped by task, the vignettes, the guides (QC,
  analysis, plots, probesets, command line, FAQ) and the worked GEO
  examples.
- The README documents the input files of both entry points (IDAT files
  for
  [`runMethQC()`](https://hongjianjin.github.io/imprintomeR/reference/runMethQC.md),
  a beta matrix for
  [`ImprintomeSet()`](https://hongjianjin.github.io/imprintomeR/reference/ImprintomeSet.md)).
- The three vignettes now run on the example data when the package is
  built.
- New FAQ on choosing cutoffs and interpreting results.
- `supplementary/Supplementary_Code.R` runs every workflow example of
  the Application Note’s Supplementary on public data.
- `benchmark/download_heldout.R` downloads the held-out benchmark files
  from GEO and checks their size and SHA-256.
- Repository: the notebooks moved to `tutorials/` (`GSE52567.ipynb`
  renamed `GSE52576.ipynb`) and the guides to `vignettes/articles/`. The
  MCP server and agent skill moved to their own repository,
  <https://github.com/hongjianjin/imprintomeR-agent>, and an unused
  legacy file was removed.

### New features

- With `n_boot > 0`,
  [`AnalyzeImprintStatus()`](https://hongjianjin.github.io/imprintomeR/reference/AnalyzeImprintStatus.md)
  and
  [`runImprintome()`](https://hongjianjin.github.io/imprintomeR/reference/runImprintome.md)
  add `Status_interval`: whether the IDS interval lies above, below or
  across the cutoff. `Confidence` (exploratory 0.1/0.2/0.4 IDS bands) is
  kept.
- `run_imprintomeR.R` has the uncertainty options `--n-boot`,
  `--resample`, `--resample-reference`, `--n-perm`, `--permute`,
  `--conf-level` and `--seed`; a seed is drawn and logged when none is
  given, and the log records the package version and the arguments. Beta
  files are streamed and only panel probes are kept (`--all-probes` to
  load all), so genome-wide files no longer need to fit in memory.
- [`PlotPolar()`](https://hongjianjin.github.io/imprintomeR/reference/PlotPolar.md)
  is exported. Polar colours are stable (sorted group names, control or
  normal groups grey and drawn on top), labels wrap, and the radial axis
  extends when IDS exceeds 0.8 (such samples were dropped before).
- [`PlotICRHeatmap()`](https://hongjianjin.github.io/imprintomeR/reference/PlotICRHeatmap.md)
  sizes itself to the numbers of ICRs and samples and hides sample names
  above 300 samples;
  [`export()`](https://hongjianjin.github.io/imprintomeR/reference/export.md)
  uses the stored size. `beeswarm_origin` and `mirror_density` take
  samples from each group in turn and state how many are shown.
- [`ImprintomeSet()`](https://hongjianjin.github.io/imprintomeR/reference/ImprintomeSet.md)
  stops with an explanation when beta values lie outside 0 to 1
  (percentages or M-values), which previously called every sample
  altered.

### Changed behaviour

- Mechanism `ROI` and `Mechanism_support` follow `ids_cutoff` instead of
  a fixed 0.2, so `Status` and `Mechanism` agree for any cutoff. Results
  with the default cutoff (0.2) are unchanged.

### Bug fixes

- [`runMethQC()`](https://hongjianjin.github.io/imprintomeR/reference/runMethQC.md):
  `predictedSex` was `NA` whenever `Sample_Name` differed from the IDAT
  name.
- [`runMethQC()`](https://hongjianjin.github.io/imprintomeR/reference/runMethQC.md):
  Bisulfite Conversion I Green was misreported on 450K arrays (minfi’s
  manifest misnames two of its probes), and the contamination table
  repeated rows or failed, losing `predictedDonorID`, when donor groups
  differed in size.
- [`check_platform()`](https://hongjianjin.github.io/imprintomeR/reference/check_platform.md)
  returned minfi’s `"450k"` instead of the documented `"450K"`.
- Probe-level plots (violin, beeswarm and others) failed when the
  metadata’s row names were not the sample IDs, and several plot helpers
  mishandled a beta matrix (as stored in an `ImprintomeSet`).
- The correlation heatmap failed on missing beta values and left a PDF
  device open, so later heatmaps were drawn into it;
  [`BetaHeatmapByGene()`](https://hongjianjin.github.io/imprintomeR/reference/BetaHeatmapByGene.md)
  returned its heatmap invisibly, so it was not drawn;
  [`Beeplot_chr_vs_other()`](https://hongjianjin.github.io/imprintomeR/reference/Beeplot_chr_vs_other.md)
  needed `outFile`.
- `export(save_plots = TRUE)` failed on the per-ICR heatmap.
- Excel export failed when two metadata columns differed only by letter
  case (for example a sample sheet’s `status` and the `Status` added by
  [`check_platform()`](https://hongjianjin.github.io/imprintomeR/reference/check_platform.md));
  the later one is renamed with a suffix.
- PNG output
  ([`BetaCircularHeatmap()`](https://hongjianjin.github.io/imprintomeR/reference/BetaCircularHeatmap.md),
  `export(plot_device = "png")`) uses ragg when installed, so it works
  without X11 or cairo (for example on macOS without XQuartz).
- The origin permutation falls back from whole ICRs to probes, with a
  warning, on panels with one ICR per parental class (such as
  `chr11p15`) also through
  [`runImprintome()`](https://hongjianjin.github.io/imprintomeR/reference/runImprintome.md)
  and the command line, as documented; these stopped with an error.
- `run_imprintomeR.R` without `--icr` no longer ends with a “differing
  number of rows” error.
- The many [`type.convert()`](https://rdrr.io/r/utils/type.convert.html)
  warnings from
  [`minfi::qcReport()`](https://rdrr.io/pkg/minfi/man/qcReport.html) are
  silenced.

### Testing

- GitHub Actions run `R CMD check` (with the vignettes) on Linux, macOS
  and Windows, and a clean install as the README says, followed by the
  Quick start and the Supplementary companion script, on every change
  and weekly.

## imprintomeR 1.5.3 and earlier

See the release notes on GitHub:
<https://github.com/hongjianjin/imprintomeR/releases>
