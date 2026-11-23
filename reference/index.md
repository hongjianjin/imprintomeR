# Package index

## Example data and setup

- [`imprintome_example()`](https://hongjianjin.github.io/imprintomeR/reference/imprintome_example.md)
  : Example data: GSE52576 beta values and metadata
- [`setup_imprintome_data()`](https://hongjianjin.github.io/imprintomeR/reference/setup_imprintome_data.md)
  : Setup imprintomeR Data Files
- [`imprintomeR`](https://hongjianjin.github.io/imprintomeR/reference/imprintomeR-package.md)
  [`imprintomeR-package`](https://hongjianjin.github.io/imprintomeR/reference/imprintomeR-package.md)
  : imprintomeR: Imprinting Analysis of DNA Methylation Arrays

## Quality control (MethQcSet)

Read IDAT files, run QC and preprocessing for one array platform.

- [`check_platform()`](https://hongjianjin.github.io/imprintomeR/reference/check_platform.md)
  : Detect Array Platform from IDAT Files and Annotate Metadata
- [`runMethQC()`](https://hongjianjin.github.io/imprintomeR/reference/runMethQC.md)
  : Load IDAT Files, Run Quality Control, and Create a MethQcSet
- [`MethQcSet()`](https://hongjianjin.github.io/imprintomeR/reference/MethQcSet.md)
  : Construct a MethQcSet Object
- [`MethQcSet-class`](https://hongjianjin.github.io/imprintomeR/reference/MethQcSet-class.md)
  : MethQcSet S4 Class
- [`MethQcSet-io`](https://hongjianjin.github.io/imprintomeR/reference/MethQcSet-io.md)
  : Platform Detection and QC Factory for MethQcSet
- [`meta()`](https://hongjianjin.github.io/imprintomeR/reference/MethQcSet-accessors.md)
  [`` `meta<-`() ``](https://hongjianjin.github.io/imprintomeR/reference/MethQcSet-accessors.md)
  [`platform()`](https://hongjianjin.github.io/imprintomeR/reference/MethQcSet-accessors.md)
  [`` `platform<-`() ``](https://hongjianjin.github.io/imprintomeR/reference/MethQcSet-accessors.md)
  [`beta()`](https://hongjianjin.github.io/imprintomeR/reference/MethQcSet-accessors.md)
  [`` `beta<-`() ``](https://hongjianjin.github.io/imprintomeR/reference/MethQcSet-accessors.md)
  [`detection_pval()`](https://hongjianjin.github.io/imprintomeR/reference/MethQcSet-accessors.md)
  [`` `detection_pval<-`() ``](https://hongjianjin.github.io/imprintomeR/reference/MethQcSet-accessors.md)
  [`qc_tables()`](https://hongjianjin.github.io/imprintomeR/reference/MethQcSet-accessors.md)
  [`` `qc_tables<-`() ``](https://hongjianjin.github.io/imprintomeR/reference/MethQcSet-accessors.md)
  [`aggregation_status()`](https://hongjianjin.github.io/imprintomeR/reference/MethQcSet-accessors.md)
  [`` `aggregation_status<-`() ``](https://hongjianjin.github.io/imprintomeR/reference/MethQcSet-accessors.md)
  [`qc_params()`](https://hongjianjin.github.io/imprintomeR/reference/MethQcSet-accessors.md)
  [`` `qc_params<-`() ``](https://hongjianjin.github.io/imprintomeR/reference/MethQcSet-accessors.md)
  [`statistics()`](https://hongjianjin.github.io/imprintomeR/reference/MethQcSet-accessors.md)
  [`` `statistics<-`() ``](https://hongjianjin.github.io/imprintomeR/reference/MethQcSet-accessors.md)
  : Accessors for MethQcSet
- [`MethQcSet-methods`](https://hongjianjin.github.io/imprintomeR/reference/MethQcSet-methods.md)
  : QC Computation and Aggregation Methods for MethQcSet
- [`subsetMethQC()`](https://hongjianjin.github.io/imprintomeR/reference/subsetMethQC.md)
  : Subset a MethQcSet by QC Status or Sample Names
- [`merge(`*`<MethQcSet>`*`,`*`<ANY>`*`)`](https://hongjianjin.github.io/imprintomeR/reference/merge-MethQcSet-ANY-method.md)
  : Merge Multiple MethQcSet Objects
- [`MethQcSet-merge`](https://hongjianjin.github.io/imprintomeR/reference/MethQcSet-merge.md)
  : Merge and Intersection Methods for MethQcSet
- [`find_intersection()`](https://hongjianjin.github.io/imprintomeR/reference/find_intersection.md)
  : Find Common Samples or Probes Between MethQcSet Objects
- [`qc_summarize()`](https://hongjianjin.github.io/imprintomeR/reference/qc_summarize.md)
  : Summarize a MethQcSet Object
- [`Meth_QC()`](https://hongjianjin.github.io/imprintomeR/reference/Meth_QC.md)
  : Summarize Core Methylation Array QC Metrics
- [`plot(`*`<MethQcSet>`*`,`*`<missing>`*`)`](https://hongjianjin.github.io/imprintomeR/reference/plot-MethQcSet-missing-method.md)
  : Plot QC Metrics from MethQcSet
- [`MethQcSet-viz`](https://hongjianjin.github.io/imprintomeR/reference/MethQcSet-viz.md)
  : Visualization, Export, and Summary Methods for MethQcSet
- [`export(`*`<MethQcSet>`*`)`](https://hongjianjin.github.io/imprintomeR/reference/export-MethQcSet-method.md)
  : Export MethQcSet Data

## Conversion and probe aggregation

From a MethQcSet to an ImprintomeSet; EPICv2 replicate probes.

- [`as.ImprintomeSet(`*`<MethQcSet>`*`)`](https://hongjianjin.github.io/imprintomeR/reference/as.ImprintomeSet-MethQcSet-method.md)
  : Convert MethQcSet to ImprintomeSet
- [`MethQcSet-convert`](https://hongjianjin.github.io/imprintomeR/reference/MethQcSet-convert.md)
  : Conversion Methods for MethQcSet
- [`aggregate_probes(`*`<MethQcSet>`*`)`](https://hongjianjin.github.io/imprintomeR/reference/aggregate_probes-MethQcSet-method.md)
  : Aggregate Platform-Specific Probes
- [`aggregate_beta_epicv2()`](https://hongjianjin.github.io/imprintomeR/reference/aggregate_beta_epicv2.md)
  : Aggregate EPICv2 Probes to Base Probe IDs

## Imprinting analysis (ImprintomeSet)

Build the analysis object and score each sample.

- [`ImprintomeSet()`](https://hongjianjin.github.io/imprintomeR/reference/ImprintomeSet.md)
  : Construct an ImprintomeSet Object
- [`ImprintomeSet-class`](https://hongjianjin.github.io/imprintomeR/reference/ImprintomeSet-class.md)
  : ImprintomeSet S4 Class
- [`beta(`*`<ImprintomeSet>`*`)`](https://hongjianjin.github.io/imprintomeR/reference/ImprintomeSet-accessors.md)
  [`` `beta<-`( ``*`<ImprintomeSet>`*`)`](https://hongjianjin.github.io/imprintomeR/reference/ImprintomeSet-accessors.md)
  [`meta(`*`<ImprintomeSet>`*`)`](https://hongjianjin.github.io/imprintomeR/reference/ImprintomeSet-accessors.md)
  [`` `meta<-`( ``*`<ImprintomeSet>`*`)`](https://hongjianjin.github.io/imprintomeR/reference/ImprintomeSet-accessors.md)
  [`probeset()`](https://hongjianjin.github.io/imprintomeR/reference/ImprintomeSet-accessors.md)
  [`` `probeset<-`() ``](https://hongjianjin.github.io/imprintomeR/reference/ImprintomeSet-accessors.md)
  [`genome()`](https://hongjianjin.github.io/imprintomeR/reference/ImprintomeSet-accessors.md)
  [`` `genome<-`() ``](https://hongjianjin.github.io/imprintomeR/reference/ImprintomeSet-accessors.md)
  [`assay()`](https://hongjianjin.github.io/imprintomeR/reference/ImprintomeSet-accessors.md)
  [`` `assay<-`() ``](https://hongjianjin.github.io/imprintomeR/reference/ImprintomeSet-accessors.md)
  [`results()`](https://hongjianjin.github.io/imprintomeR/reference/ImprintomeSet-accessors.md)
  [`` `results<-`() ``](https://hongjianjin.github.io/imprintomeR/reference/ImprintomeSet-accessors.md)
  [`plots()`](https://hongjianjin.github.io/imprintomeR/reference/ImprintomeSet-accessors.md)
  [`` `plots<-`() ``](https://hongjianjin.github.io/imprintomeR/reference/ImprintomeSet-accessors.md)
  : Accessors for ImprintomeSet
- [`runImprintome(`*`<ImprintomeSet>`*`)`](https://hongjianjin.github.io/imprintomeR/reference/runImprintome.md)
  : Run Core Imprintome Analysis
- [`summarize(`*`<ANY>`*`)`](https://hongjianjin.github.io/imprintomeR/reference/summarize.md)
  [`summarize(`*`<ImprintomeSet>`*`)`](https://hongjianjin.github.io/imprintomeR/reference/summarize.md)
  : Summarize ImprintomeSet Contents
- [`validate_meta_tier()`](https://hongjianjin.github.io/imprintomeR/reference/validate_meta_tier.md)
  : Validate Metadata Against Tier Requirements

## Scores and references

Sample-level scores (IDS, Angle, Mechanism), control references,
uncertainty and calibration.

- [`AnalyzeImprintStatus()`](https://hongjianjin.github.io/imprintomeR/reference/AnalyzeImprintStatus.md)
  : Comprehensive Imprinting Analysis for a Sample Cohort
- [`compute_ids()`](https://hongjianjin.github.io/imprintomeR/reference/compute_ids.md)
  : Compute Imprinting Deviation Score (IDS)
- [`compute_angle()`](https://hongjianjin.github.io/imprintomeR/reference/compute_angle.md)
  : Compute Mechanism Angle from Maternal/Paternal Medians
- [`classify_mechanism()`](https://hongjianjin.github.io/imprintomeR/reference/classify_mechanism.md)
  : Classify Imprinting Mechanism from Angle
- [`BuildReferenceProfile()`](https://hongjianjin.github.io/imprintomeR/reference/BuildReferenceProfile.md)
  : Build a Reusable Control Reference Profile
- [`CalibrateIDS()`](https://hongjianjin.github.io/imprintomeR/reference/CalibrateIDS.md)
  : Calibrate the IDS Cutoff on Control Samples
- [`compute_consistency()`](https://hongjianjin.github.io/imprintomeR/reference/compute_consistency.md)
  : Compute Allelic Consistency Metrics Per Sample
- [`DetectMosaicism()`](https://hongjianjin.github.io/imprintomeR/reference/DetectMosaicism.md)
  : Flag Possible Mosaic Imprinting Disturbances

## Per-ICR calls

Each imprinting control region scored on its own, and the multi-locus
summary.

- [`AnalyzeICRStatus()`](https://hongjianjin.github.io/imprintomeR/reference/AnalyzeICRStatus.md)
  : Per-ICR Imprinting Deviations
- [`SummarizeICRStatus()`](https://hongjianjin.github.io/imprintomeR/reference/SummarizeICRStatus.md)
  : Multi-Locus Summary of Per-ICR Deviations
- [`AggregateByLocus()`](https://hongjianjin.github.io/imprintomeR/reference/AggregateByLocus.md)
  : Aggregate Beta Matrix by Imprinting Locus
- [`Calculate_impvar()`](https://hongjianjin.github.io/imprintomeR/reference/Calculate_impvar.md)
  : Per-ICR Methylation Variance per Sample
- [`Survey_Global_Imprinting()`](https://hongjianjin.github.io/imprintomeR/reference/Survey_Global_Imprinting.md)
  : Per-Chromosome Imprinting Survey of One Sample
- [`Survey_Global_Imprinting_Batch()`](https://hongjianjin.github.io/imprintomeR/reference/Survey_Global_Imprinting_Batch.md)
  : Per-Chromosome Imprinting Survey of a Cohort

## Plots

- [`plot(`*`<ImprintomeSet>`*`,`*`<missing>`*`)`](https://hongjianjin.github.io/imprintomeR/reference/ImprintomeSet-plot.md)
  : Plot ImprintomeSet Results
- [`runImprintomeVisualizations()`](https://hongjianjin.github.io/imprintomeR/reference/runImprintomeVisualizations.md)
  : Run Standard ImprintomeSet Visualizations
- [`PlotPolar()`](https://hongjianjin.github.io/imprintomeR/reference/PlotPolar.md)
  : Plot Imprintome Polar Coordinates
- [`PlotICRHeatmap()`](https://hongjianjin.github.io/imprintomeR/reference/PlotICRHeatmap.md)
  : Heatmap of Per-ICR Deviations
- [`PlotRainfall()`](https://hongjianjin.github.io/imprintomeR/reference/PlotRainfall.md)
  : Rainfall Plot of Probe-Level Imprinting Deviation
- [`BetaHeatmapByGene()`](https://hongjianjin.github.io/imprintomeR/reference/BetaHeatmapByGene.md)
  : Heatmap of Beta Values Aggregated by Gene Symbol
- [`BetaCircularHeatmap()`](https://hongjianjin.github.io/imprintomeR/reference/BetaCircularHeatmap.md)
  : Circular Heatmap of Beta Values
- [`BetaVlnPlot()`](https://hongjianjin.github.io/imprintomeR/reference/BetaVlnPlot.md)
  : Violin Plot of Methylation Distributions by Sample
- [`BetaBeePlot()`](https://hongjianjin.github.io/imprintomeR/reference/BetaBeePlot.md)
  : Beeswarm Plot of Methylation by Sample
- [`BetaBeePlot_orgin()`](https://hongjianjin.github.io/imprintomeR/reference/BetaBeePlot_orgin.md)
  : Beeswarm Plot Split by Probe Category/Origin
- [`BetaBeePlot_orgin2()`](https://hongjianjin.github.io/imprintomeR/reference/BetaBeePlot_orgin2.md)
  : Multi-Panel Beeswarm Plot by Category/Origin
- [`BetaBeePlot_single_chr()`](https://hongjianjin.github.io/imprintomeR/reference/BetaBeePlot_single_chr.md)
  : Beeswarm Plot for a Single Chromosome by Origin
- [`Beeplot_chr_vs_other()`](https://hongjianjin.github.io/imprintomeR/reference/Beeplot_chr_vs_other.md)
  : Beeswarm Plot by Chromosome vs Others for Each Sample
- [`Beeplot_chr_vs_other_single()`](https://hongjianjin.github.io/imprintomeR/reference/Beeplot_chr_vs_other_single.md)
  : Generate Chromosome-vs-Others Beeswarm PDFs
- [`Plot_ICR_var_med()`](https://hongjianjin.github.io/imprintomeR/reference/Plot_ICR_var_med.md)
  : Plot ICR-Level Variance and Median Drift
- [`plot_imp_consistency()`](https://hongjianjin.github.io/imprintomeR/reference/plot_imp_consistency.md)
  : Plot Imprinting Deviation against Tumor Purity
- [`GetColors()`](https://hongjianjin.github.io/imprintomeR/reference/GetColors.md)
  : Colour Palettes
- [`Check_Meta_Color()`](https://hongjianjin.github.io/imprintomeR/reference/Check_Meta_Color.md)
  : Assign or Validate Group Colours in Metadata

## Export

- [`export(`*`<ImprintomeSet>`*`)`](https://hongjianjin.github.io/imprintomeR/reference/export.md)
  : Export ImprintomeSet Outputs to Disk
- [`SaveTable()`](https://hongjianjin.github.io/imprintomeR/reference/SaveTable.md)
  : Save a Table to an Excel Workbook
- [`SaveTableStyle()`](https://hongjianjin.github.io/imprintomeR/reference/SaveTableStyle.md)
  : Save a Table to Excel with Conditional Formatting
- [`QC_final_Cutoffs`](https://hongjianjin.github.io/imprintomeR/reference/QC_final_Cutoffs.md)
  : QC Final Cutoffs for Conditional Formatting
- [`ctrlMatCutoffs`](https://hongjianjin.github.io/imprintomeR/reference/ctrlMatCutoffs.md)
  : Control Metrics Cutoffs for Conditional Formatting

## Input, probesets and annotation

Read beta and metadata tables; subset and annotate probes.

- [`LoadBeta()`](https://hongjianjin.github.io/imprintomeR/reference/LoadBeta.md)
  : Load and Standardize Beta Matrix
- [`LoadMeta()`](https://hongjianjin.github.io/imprintomeR/reference/LoadMeta.md)
  : Load and Standardize Metadata Table
- [`LoadMetaBeta()`](https://hongjianjin.github.io/imprintomeR/reference/LoadMetaBeta.md)
  : Load Matched Metadata and Beta Matrix
- [`LoadTable()`](https://hongjianjin.github.io/imprintomeR/reference/LoadTable.md)
  : Load a Table from XLSX or Tab-Delimited Text
- [`SubsetBeta_By_Probeset()`](https://hongjianjin.github.io/imprintomeR/reference/SubsetBeta_By_Probeset.md)
  : Subset a Beta Matrix to a Probeset
- [`AnnotateProbe2Gene()`](https://hongjianjin.github.io/imprintomeR/reference/AnnotateProbe2Gene.md)
  : Annotate Probes with Genomic Position and Gene
- [`ExtractProbesByBeds()`](https://hongjianjin.github.io/imprintomeR/reference/ExtractProbesByBeds.md)
  : Extract Probes Overlapping Input BED Region(s)
- [`ExtractProbesByGenelist()`](https://hongjianjin.github.io/imprintomeR/reference/ExtractProbesByGenelist.md)
  : Extract Probes Annotated to Genes
- [`Bed2Granges()`](https://hongjianjin.github.io/imprintomeR/reference/Bed2Granges.md)
  : Import BED as Genomic Ranges
- [`ParseBedFile()`](https://hongjianjin.github.io/imprintomeR/reference/ParseBedFile.md)
  : Parse, Sort, and Normalize BED File
- [`ParseBedFile2()`](https://hongjianjin.github.io/imprintomeR/reference/ParseBedFile2.md)
  : Parse BED File with Optional Annotation Columns

## Utilities

- [`Between()`](https://hongjianjin.github.io/imprintomeR/reference/Between.md)
  : Test Whether Values Lie in an Interval
- [`CalcAvgByGrp()`](https://hongjianjin.github.io/imprintomeR/reference/CalcAvgByGrp.md)
  : Calculate Row-Wise Group Means
- [`CheckHeader()`](https://hongjianjin.github.io/imprintomeR/reference/CheckHeader.md)
  : Detect Presence of Header in Probe List File
- [`CheckProbeIDs()`](https://hongjianjin.github.io/imprintomeR/reference/CheckProbeIDs.md)
  : Check Probe ID Format
- [`CheckSentrixID()`](https://hongjianjin.github.io/imprintomeR/reference/CheckSentrixID.md)
  : Validate Illumina Sentrix IDs
- [`CheckSheetName()`](https://hongjianjin.github.io/imprintomeR/reference/CheckSheetName.md)
  : Check Whether an Excel Sheet Exists
- [`idx_matching_column()`](https://hongjianjin.github.io/imprintomeR/reference/idx_matching_column.md)
  : Find Matching Column Index/Indices
- [`.imprint_origin_colors()`](https://hongjianjin.github.io/imprintomeR/reference/dot-imprint_origin_colors.md)
  : Internal Color Mapping for Allelic Origin
- [`.imprint_save_plot()`](https://hongjianjin.github.io/imprintomeR/reference/dot-imprint_save_plot.md)
  : Save Plot Conditionally and Return Plot Object
