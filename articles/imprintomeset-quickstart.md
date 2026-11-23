# ImprintomeSet Workflow Quickstart

## Overview

This vignette presents a Bioconductor-style, object-first workflow using
imprintomeR’s preprocessing-first architecture:

1.  **MethQcSet**: Quality control for single-platform raw data
2.  **ImprintomeSet**: Analysis container for imprinting studies

You will learn how to:

- create a `MethQcSet` for preprocessing
- run platform-specific QC
- convert to `ImprintomeSet` for analysis
- compute imprinting metrics with
  [`runImprintome()`](https://hongjianjin.github.io/imprintomeR/reference/runImprintome.md)
- summarize, visualize, and export results

Core definitions used by imprintomeR:

- IDS: `sqrt((paternal_median - 0.5)^2 + (maternal_median - 0.5)^2)`
- Angle: derived from paternal/maternal deviations around `0.5`
- IDI: `(beta - 0.5) * 2`

## Package Startup

``` r

library(imprintomeR)
#> 
#> Attaching package: 'imprintomeR'
#> The following object is masked from 'package:base':
#> 
#>     beta
```

## 1. QC Preprocessing (Optional if Data Already Cleaned)

**If you have RAW data:**

Load metadata. `meta.tsv` must be a tab-delimited file with at least
`Sample_Name` and `Sample_Group` columns.

**For QC workflow (raw IDAT files):** also include `Basename` column
(IDAT file path prefixes,
e.g. `/path/to/idats/SentrixID_SentrixPosition`).

**For direct analysis (QC already done):** `Basename` is not needed.

``` r

meta <- LoadMeta("meta.tsv")
```

If the platform is **unknown or mixed**, detect it first:

``` r

# Reads one IDAT per sample, infers platform from probe count
# Appends Platform, Array_Size, Manifest, Status columns to meta
meta <- check_platform(meta)
table(meta$Platform)  # inspect; split if multiple platforms present

# Run QC for one platform at a time
meta_epic <- meta[meta$Platform == "EPIC", ]
qcset <- runMethQC(meta_epic)  # platform auto-resolved from meta$Platform
```

If the platform is **already known**, pass it directly:

``` r

# runMethQC() loads IDAT files, extracts beta + detection p-values, and runs QC
qcset <- runMethQC(meta, platform = "EPIC")
```

Inspect QC results:

``` r

qc_summary <- qc_summarize(qcset)
qc_summary$platform
qc_summary$n_samples
qc_summary$n_probes
qc_summary$aggregation_status
```

Visualize QC metrics:

``` r

# PASS / FAIL sample count bar chart (default)
p_bar <- plot(qcset, type = "qc_bar")

# Methylated vs unmethylated intensity scatter, cutoff line at log2 = 11
p_int <- plot(qcset, type = "intensity", icutoff = 11,
              outFile = "qc_intensity.pdf")

# Average detection p-value per sample, cutoff line at 0.05
p_dp  <- plot(qcset, type = "detection_pval", pcutoff = 0.05)

# % probes detected per sample, reference line at 95%
p_cov <- plot(qcset, type = "probe_coverage")

# Predicted sex distribution
p_sex <- plot(qcset, type = "predicted_sex")

# control probe metrics — summary (NULL if these metrics could not be computed)
p_ctrl <- plot(qcset, type = "ctrl_metrics")

# Per-metric detail plots (Bisulfite Conversion, Specificity, Non-polymorphic)
# outFile is used as a path prefix; one PDF is saved per control metric
plot(qcset, type = "ctrl_metrics_detail",
     outFile = "qc_ctrl_matrix_detail")
```

Export cleaned data:

``` r

dir.create("qc_output", showWarnings = FALSE)

exported_files <- export(
  qcset,
  outdir = "qc_output",
  format = c("xlsx", "rds")
)
# Creates two Excel workbooks:
#   qc_table_main.xlsx: metadata, QC_matrix, Ctrl_matrix (control probes), statistics
#   qc_table_extra.xlsx: QC_metrics (thresholds), recall_rate (if available),
#                         contamination and predUniqDonor_ID (SNP probes)
# Plus: qcset.rds (full MethQcSet object)
# Plus: qcset_summary.txt (summary report with Notes section documenting missing sheets)
```

**If you already have QC-cleaned data:**

Skip MethQcSet and load pre-cleaned beta values. Note: `Basename` column
is not needed since QC is already done.

``` r

meta <- LoadMeta("meta.tsv")  # Only needs Sample_Name and Sample_Group
beta <- LoadBeta("cleaned_beta.tsv")  # Already QC-approved

# Proceed to Section 2: Create ImprintomeSet
```

Optional: Merge multiple QC-approved single-platform datasets:

``` r

# Two separate MethQcSet objects (same platform)
qcset1 <- MethQcSet(meta1, beta1, platform = "EPICv1")
qcset2 <- MethQcSet(meta2, beta2, platform = "EPICv1")

# Synchronized merge (common samples/probes)
merged <- merge(qcset1, qcset2, how = "inner")

# Find common elements across objects
common_samples <- find_intersection(qcset1, qcset2, by = "samples")
common_probes <- find_intersection(qcset1, qcset2, by = "probes")
```

## 2. Create ImprintomeSet from QC-Approved Data

Once your data passes QC, convert to analysis container:

``` r

# Load probeset annotations
probesets <- readRDS(
  system.file("extdata", "probesets_hg38.rds", package = "imprintomeR")
)

# EPICv2 only: aggregate replicate probes before conversion (required)
# Reduces ~937k probes to ~865k unique base probes (cg... IDs)
# as.ImprintomeSet() will error if this step is skipped for EPICv2.
if (qcset@platform == "EPICv2") {
  qcset <- aggregate_probes(qcset)   # idempotent — safe to call again
}

# Keep PASS samples before conversion
qcset_pass <- subsetMethQC(qcset, final_qc = "PASS")

# Convert MethQcSet to ImprintomeSet
x <- as.ImprintomeSet(
  qcset_pass,
  probeset = probesets[["selected"]],
  genome = "hg38"
)
```

Alternatively, construct `ImprintomeSet` directly from a beta matrix if
QC was done elsewhere. The rest of this vignette runs on the bundled
example, beta values of the `selected` panel probes for 28 samples of
GEO GSE52576 (450K):

``` r

beta <- imprintome_example("beta")   # 782 probes x 28 samples, GEO GSE52576 (450K)
meta <- imprintome_example("meta")   # Sample_Name, Sample_Group, title, health_state, gender
probesets <- readRDS(system.file("extdata", "probesets_hg38.rds", package = "imprintomeR"))
x <- ImprintomeSet(
  beta = beta,
  meta = meta,
  probeset = probesets[["selected"]],
  genome = "hg38",
  assay = "450K"
)
```

Constructor validation includes:

- overlapping sample IDs between `meta$Sample_Name` and beta columns
- required metadata columns (`Sample_Name`, `Sample_Group`)
- non-empty beta/probeset objects

The object keeps derived outputs in separate slots:

- `results(x)` for imprinting analysis tables
- `plots(x)` for stored plot objects

## 3. Run Core Analysis with runImprintome()

[`runImprintome()`](https://hongjianjin.github.io/imprintomeR/reference/runImprintome.md)
stores the analysis table inside `results(x)`.

``` r

x <- runImprintome(
  x,
  probeset = "selected",
  ids_cutoff = 0.2
)
#> 
#>  [meta dim: 28 x 5 ]
#>  [beta dim: 782 x 29 ]
#>  [meta dim: 28 x 5 ]
#>  [beta dim: 782 x 28 ]
#>  [SubsetBeta] subset by probeset [query: 782; matched probes: 782 ]
```

You can run additional probesets and keep all outputs in the same
object.

``` r

x <- runImprintome(
  x,
  probeset = "NanoImprint",
  ids_cutoff = 0.2,
  result_name = "AnalyzeImprintStatus.NanoImprint"
)
#> 
#>  [meta dim: 28 x 5 ]
#>  [beta dim: 782 x 29 ]
#>  [meta dim: 28 x 5 ]
#>  [beta dim: 782 x 28 ]
#>  [SubsetBeta] subset by probeset [query: 325; matched probes: 325 ]
```

## 4. Inspect Results

``` r

result_names <- names(results(x))
result_names
#> [1] "AnalyzeImprintStatus.selected"    "AnalyzeImprintStatus.NanoImprint"

res <- results(x)[["AnalyzeImprintStatus.selected"]]
head(res)
#>            Sample_Name      Sample_Group probeset dmr_type infinium_type
#> GSM1270013  GSM1270013       Adult Brain selected  gametic           all
#> GSM1270014  GSM1270014       Fetal Brain selected  gametic           all
#> GSM1270015  GSM1270015            Muscle selected  gametic           all
#> GSM1270016  GSM1270016          Pancreas selected  gametic           all
#> GSM1270017  GSM1270017             Liver selected  gametic           all
#> GSM1270018  GSM1270018 Hydatidiform mole selected  gametic           all
#>              reference n_reference_samples n_paternal_probes n_maternal_probes
#> GSM1270013 fixed (0.5)                   0                48               499
#> GSM1270014 fixed (0.5)                   0                48               499
#> GSM1270015 fixed (0.5)                   0                48               499
#> GSM1270016 fixed (0.5)                   0                48               499
#> GSM1270017 fixed (0.5)                   0                48               499
#> GSM1270018 fixed (0.5)                   0                48               499
#>            balance paternal_median maternal_median paternal_deviation
#> GSM1270013   probe           0.553           0.538              0.053
#> GSM1270014   probe           0.547           0.546              0.047
#> GSM1270015   probe           0.566           0.537              0.066
#> GSM1270016   probe           0.571           0.532              0.071
#> GSM1270017   probe           0.537           0.522              0.037
#> GSM1270018   probe           0.874           0.138              0.374
#>            maternal_deviation  pat_cons  mat_cons consistency   IDS Angle
#> GSM1270013              0.038 0.8125000 0.6813627   0.7469314 0.065  35.4
#> GSM1270014              0.046 0.8125000 0.7334669   0.7729835 0.066  44.7
#> GSM1270015              0.037 0.8125000 0.6833667   0.7479334 0.075  29.6
#> GSM1270016              0.032 0.7500000 0.5931864   0.6715932 0.078  24.7
#> GSM1270017              0.022 0.7500000 0.5991984   0.6745992 0.043  31.0
#> GSM1270018             -0.362 0.9166667 0.7515030   0.8340848 0.521 316.0
#>                    Mechanism                Status        Confidence
#> GSM1270013               ROI                Normal     High (Normal)
#> GSM1270014               ROI                Normal     High (Normal)
#> GSM1270015               ROI                Normal     High (Normal)
#> GSM1270016               ROI                Normal     High (Normal)
#> GSM1270017               ROI                Normal     High (Normal)
#> GSM1270018 Pat-Gain+Mat-Loss Imprinting Alteration High (Alteration)
```

Expected columns include:

- `paternal_median`
- `maternal_median`
- `IDS`
- `Angle`
- `Mechanism`
- `Status`
- `Confidence` (exploratory IDS bands 0.1/0.2/0.4)
- with `n_boot > 0`: `IDS_lower`, `IDS_upper`, `Mechanism_support` and
  `Status_interval`

## 5. Summarize Object State

``` r

s <- summarize(x)
s$object
#>   assay genome beta_nrow beta_ncol meta_nrow meta_ncol probeset_type
#> 1  450K   hg38       782        28        28         5    data.frame
#>   probeset_nrow probeset_ncol               probeset_info
#> 1           782            10 NAME column present (n=782)
s$results
#>                                                              name      class
#> AnalyzeImprintStatus.NanoImprint AnalyzeImprintStatus.NanoImprint data.frame
#> AnalyzeImprintStatus.selected       AnalyzeImprintStatus.selected data.frame
#>                                  nrow ncol
#> AnalyzeImprintStatus.NanoImprint   28   22
#> AnalyzeImprintStatus.selected      28   22
s$plots
#> [1] name  class
#> <0 rows> (or 0-length row.names)
```

## 6. Access and Update Slots

``` r

# Accessors
head(beta(x)[, 1:4])
#>            GSM1270013 GSM1270014 GSM1270015 GSM1270016
#> cg00000924 0.49144030  0.4761606  0.4982834  0.5648559
#> cg00059930 0.51882000  0.5490270  0.5157581  0.3198318
#> cg00098799 0.65042240  0.6890512  0.6478977  0.8961490
#> cg00124993 0.03777816  0.4882108  0.5059993  0.4703763
#> cg00155882 0.51528480  0.4997351  0.4918928  0.5056440
#> cg00229754 0.25714440  0.2994055  0.2098593  0.1327489
head(meta(x))
#>   Sample_Name      Sample_Group                            title
#> 1  GSM1270013       Adult Brain                          Brain 2
#> 2  GSM1270014       Fetal Brain                          Brain 1
#> 3  GSM1270015            Muscle                           Muscle
#> 4  GSM1270016          Pancreas                         Pancreas
#> 5  GSM1270017             Liver                            Liver
#> 6  GSM1270018 Hydatidiform mole Androgenetic hydatidiform mole 1
#>            health_state gender
#> 1         Health tissue female
#> 2         Health tissue female
#> 3         Health tissue female
#> 4         Health tissue   male
#> 5         Health tissue   male
#> 6 Hydropic molar tissue female
assay(x)
#> [1] "450K"
genome(x)
#> [1] "hg38"

# Replacement examples
assay(x) <- "450K"
genome(x) <- "hg38"
```

## 7. Plot with ImprintomeSet Dispatcher

Use
[`runImprintomeVisualizations()`](https://hongjianjin.github.io/imprintomeR/reference/runImprintomeVisualizations.md)
to generate workflow plots, store successful plot objects in `plots(x)`,
and optionally save files. The helper uses the same object-first
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) dispatcher
underneath, so individual plot calls remain available when you need a
custom figure.

Supported workflow plot sets:

- `plot_types = "default"`: polar, beeswarm by origin, mirror density,
  probe/gene heatmaps, radar, chromosome beeswarm, and rainfall.
  `circular_heatmap` is not included in default.
- `plot_types = "all"`: all supported non-auto plot backends, including
  violin, circular heatmap, and correlation heatmap
- `plot_types = c(...)`: any explicit subset of supported plot types

``` r

sample_id1 <- colnames(beta(x))[2]

x <- runImprintomeVisualizations(
  x,
  plot_types = "default",
  probeset = "selected",
  sample_id = sample_id1,
  prefix = "imprintomeset_quickstart",
  store_plots = TRUE,
  save_plots = FALSE
)
#> Generating polar ... stored
#> Generating beeswarm_origin ... stored
#> Generating mirror_density ...
#> 
#>  [SubsetBeta] subset by probeset [query: 782; matched probes: 782 ]
#>  stored
#> Generating heatmap_by_probe ... stored
#> Generating heatmap_by_gene ... stored
#> Generating radar ... stored
#> Generating beeswarm_chr ... stored
#> Generating rainfall ... stored

attr(x, "visualization_manifest")
#>          plot_type                             name status file message
#> 1            polar                   polar.selected stored             
#> 2  beeswarm_origin         beeswarm_origin.selected stored             
#> 3   mirror_density          mirror_density.selected stored             
#> 4 heatmap_by_probe                 heatmap.selected stored             
#> 5  heatmap_by_gene         heatmap_by_gene.selected stored             
#> 6            radar        radar.selected.GSM1270014 stored             
#> 7     beeswarm_chr beeswarm_chr.selected.GSM1270014 stored             
#> 8         rainfall     rainfall.selected.GSM1270014 stored
names(plots(x))
#> [1] "polar.selected"                   "beeswarm_origin.selected"        
#> [3] "mirror_density.selected"          "heatmap.selected"                
#> [5] "heatmap_by_gene.selected"         "radar.selected.GSM1270014"       
#> [7] "beeswarm_chr.selected.GSM1270014" "rainfall.selected.GSM1270014"
```

### 7.1 Access Stored Plot Objects

``` r

p_from_object <- plots(x)[["beeswarm_origin.selected"]]
p_from_object
```

![Stored beeswarm plot of beta values by annotated parental
origin](imprintomeset-quickstart_files/figure-html/unnamed-chunk-18-1.png)

``` r


p_chr_from_object <- plots(x)[[grep("^beeswarm_chr\\.", names(plots(x)), value = TRUE)[1]]]
p_chr_from_object
```

![Stored chromosome beeswarm plot for one
sample](imprintomeset-quickstart_files/figure-html/unnamed-chunk-18-2.png)

### 7.2 Store Circular Heatmap Explicitly

The circular layout has room for a few sample groups only; with the 11
groups of the example it is skipped with a warning, so this chunk is not
run here
([`vignette("imprintomeset-results-export")`](https://hongjianjin.github.io/imprintomeR/articles/imprintomeset-results-export.md)
draws it for three groups).

``` r

x <- runImprintomeVisualizations(
  x,
  plot_types = "circular_heatmap",
  probeset = "selected",
  sample_id = sample_id1,
  prefix = "imprintomeset_quickstart_circular",
  store_plots = TRUE,
  save_plots = FALSE
)
plots(x)[["circular.selected"]]
```

### 7.3 Save Plot Files During Generation

``` r

x <- runImprintomeVisualizations(
  x,
  plot_types = "default",
  probeset = "selected",
  sample_id = sample_id1,
  prefix = "imprintomeset_quickstart",
  outdir = "imprintome_results/plots",
  save_plots = TRUE,
  store_plots = TRUE
)
#> Generating polar ...
#> 
#>   imprintomeset_quickstart_polar.selected.pdf [saved]
#>  saved
#> Generating beeswarm_origin ... saved
#> Generating mirror_density ...
#> 
#>  [SubsetBeta] subset by probeset [query: 782; matched probes: 782 ]
#> 
#>   imprintomeset_quickstart_mirror_density.selected.pdf [saved]
#>  saved
#> Generating heatmap_by_probe ...
#> 
#>   imprintomeset_quickstart_heatmap.selected.pdf [saved]
#>  saved
#> Generating heatmap_by_gene ...
#> 
#>   imprintomeset_quickstart_heatmap_by_gene.selected.pdf [saved]
#>  saved
#> Generating radar ... saved
#> Generating beeswarm_chr ... saved
#> Generating rainfall ...
#> Warning: Removed 1 row containing missing values or values outside the scale range
#> (`geom_point()`).
#> 
#>   imprintomeset_quickstart_rainfall.selected.GSM1270014.pdf [saved]
#>  saved
```

## 8. Export Results

``` r

manifest <- export(
  x,
  outdir = "imprintome_results",
  prefix = "imprintomeset_quickstart",
  save_plots = TRUE,
  plot_device = "pdf",
  overwrite = TRUE
)
#> Warning: Removed 1 row containing missing values or values outside the scale range
#> (`geom_point()`).

head(manifest)
#>   category                             name
#> 1   object                    ImprintomeSet
#> 2  results AnalyzeImprintStatus.NanoImprint
#> 3  results    AnalyzeImprintStatus.selected
#> 4    plots beeswarm_chr.selected.GSM1270014
#> 5    plots         beeswarm_origin.selected
#> 6    plots         heatmap_by_gene.selected
#>                                                                                       file
#> 1                            imprintome_results/imprintomeset_quickstart_imprintomeSet.rds
#> 2 imprintome_results/imprintomeset_quickstart_results_AnalyzeImprintStatus.NanoImprint.tsv
#> 3    imprintome_results/imprintomeset_quickstart_results_AnalyzeImprintStatus.selected.tsv
#> 4    imprintome_results/imprintomeset_quickstart_plot_beeswarm_chr.selected.GSM1270014.pdf
#> 5            imprintome_results/imprintomeset_quickstart_plot_beeswarm_origin.selected.pdf
#> 6            imprintome_results/imprintomeset_quickstart_plot_heatmap_by_gene.selected.pdf
#>    status
#> 1 written
#> 2 written
#> 3 written
#> 4 written
#> 5 written
#> 6 written
```

[`export()`](https://hongjianjin.github.io/imprintomeR/reference/export.md)
writes the full `ImprintomeSet` object as `<prefix>_imprintomeSet.rds`,
result tables, and stored plot objects. Plot files are prefixed as
`<prefix>_plot_<plot_name>.pdf` when `plot_device = "pdf"` and the
stored object can be rendered as a plot file; unknown plot object types
fall back to RDS.

**For QC preprocessing (MethQcSet)**, the export includes `summary.txt`
with a “Notes” section documenting any optional sheets not created due
to missing underlying data. Check it to understand data availability:

``` r

# View what sheets were and were not created
readLines("qc_output/methqcset_summary.txt")
```

## 9. Reproducibility Notes

- Keep beta columns aligned with `meta$Sample_Name`.
- Preserve maternal/paternal origin labels in probeset annotations.
- Keep metric definitions unchanged unless method contracts are
  explicitly updated.
- For reproducible QC workflows, save MethQcSet summaries with
  [`qc_summarize()`](https://hongjianjin.github.io/imprintomeR/reference/qc_summarize.md).
- Document platform and array type for reference.

## Session Info

``` r

sessionInfo()
#> R version 4.6.2 (2026-10-29)
#> Platform: x86_64-pc-linux-gnu
#> Running under: Ubuntu 26.04.1 LTS
#> 
#> Matrix products: default
#> BLAS:   /usr/lib/x86_64-linux-gnu/openblas-pthread/libblas.so.3 
#> LAPACK: /usr/lib/x86_64-linux-gnu/openblas-pthread/libopenblasp-r0.3.32.so;  LAPACK version 3.12.0
#> 
#> locale:
#>  [1] LC_CTYPE=C.UTF-8       LC_NUMERIC=C           LC_TIME=C.UTF-8       
#>  [4] LC_COLLATE=C.UTF-8     LC_MONETARY=C.UTF-8    LC_MESSAGES=C.UTF-8   
#>  [7] LC_PAPER=C.UTF-8       LC_NAME=C              LC_ADDRESS=C          
#> [10] LC_TELEPHONE=C         LC_MEASUREMENT=C.UTF-8 LC_IDENTIFICATION=C   
#> 
#> time zone: UTC
#> tzcode source: system (glibc)
#> 
#> attached base packages:
#> [1] stats     graphics  grDevices utils     datasets  methods   base     
#> 
#> other attached packages:
#> [1] imprintomeR_1.5.3
#> 
#> loaded via a namespace (and not attached):
#>  [1] gtable_0.3.6          beeswarm_0.4.0        circlize_0.4.18      
#>  [4] shape_1.4.6.1         rjson_0.2.23          xfun_0.62            
#>  [7] bslib_0.12.0          ggplot2_4.0.4         GlobalOptions_0.1.4  
#> [10] ggrepel_0.9.8         vctrs_0.7.3           tools_4.6.2          
#> [13] generics_0.1.4        stats4_4.6.2          parallel_4.6.2       
#> [16] tibble_3.3.1          cluster_2.1.8.3       pkgconfig_2.0.3      
#> [19] data.table_1.18.6.1   RColorBrewer_1.1-3    S7_1.0.0             
#> [22] desc_1.4.3            S4Vectors_0.50.3      lifecycle_1.0.5      
#> [25] compiler_4.6.2        farver_2.1.2          stringr_1.6.0        
#> [28] textshaping_1.1.0     codetools_0.2-20      ComplexHeatmap_2.28.0
#> [31] clue_0.3-68           vipor_0.4.7           htmltools_0.5.9      
#> [34] sass_0.5.0            yaml_2.3.12           pillar_1.11.1        
#> [37] pkgdown_2.2.1         crayon_1.5.3          jquerylib_0.1.4      
#> [40] tidyr_1.3.2           cachem_1.1.0          iterators_1.0.14     
#> [43] foreach_1.5.2         tidyselect_1.2.1      zip_3.0.2            
#> [46] digest_0.6.39         stringi_1.8.9         dplyr_1.2.1          
#> [49] reshape2_1.4.5        purrr_1.2.2           labeling_0.4.3       
#> [52] fastmap_1.2.0         grid_4.6.2            colorspace_2.1-4     
#> [55] cli_3.6.6             magrittr_2.0.5        withr_3.0.3          
#> [58] scales_1.4.0          ggbeeswarm_0.7.3      rmarkdown_2.32       
#> [61] matrixStats_1.5.0     otel_0.3.0            ragg_1.5.2           
#> [64] png_0.1-9             GetoptLong_1.1.1      openxlsx_4.2.9       
#> [67] evaluate_1.0.5        knitr_1.52            IRanges_2.46.0       
#> [70] doParallel_1.0.17     rlang_1.3.0           Rcpp_1.1.2           
#> [73] glue_1.8.1            BiocGenerics_0.58.1   jsonlite_2.0.0       
#> [76] R6_2.6.1              plyr_1.8.9            systemfonts_1.3.4    
#> [79] fs_2.1.0
```
