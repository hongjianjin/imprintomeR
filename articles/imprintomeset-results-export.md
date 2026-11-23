# ImprintomeSet Visualization Gallery

## Overview

This vignette demonstrates the full visualization and export workflow
after completing imprinting analysis with
[`runImprintome()`](https://hongjianjin.github.io/imprintomeR/reference/runImprintome.md).

Visualization in imprintomeR follows the preprocessing-first
architecture:

1.  **MethQcSet**: QC preprocessing (see *ImprintomeSet Workflow
    Quickstart*)
2.  **ImprintomeSet**: Analysis-ready container for imprinting studies
    (this vignette)
3.  **Results & Plots**: Stored in `results(x)` and `plots(x)` slots

The examples below are organized by visualization level:

- sample-level (polar), ICR-level (radar: one spoke per curated ICR) and
  single-sample probe-level (rainfall)
- probe-level (beeswarm, violin, mirror density)
- cohort-level (heatmap, cor_heatmap, circular_heatmap)
- chromosome-level (beeswarm_chr)

For object construction and QC preprocessing, see *ImprintomeSet
Workflow Quickstart*.

## 1. Start from a QC-Approved ImprintomeSet Object

Your `ImprintomeSet` object `x` should come from **either**:

**Option A: QC-preprocessed data via MethQcSet**

``` r

# Load metadata: tab-delimited with at least Sample_Name and Sample_Group.
# For QC workflow (raw IDAT files): also include Basename column (IDAT path prefixes).
# For direct analysis (QC already done): Basename is not needed.
meta <- LoadMeta("meta.tsv")

# Option A1: platform unknown — detect first
meta <- check_platform(meta)
meta_epic <- meta[meta$Platform == "EPIC", ]
qcset <- runMethQC(meta_epic)  # platform auto-resolved from meta$Platform

# Option A2: platform known — pass directly
# qcset <- runMethQC(meta, platform = "EPIC")

export(qcset, outdir = "qc_output", format = c("xlsx", "rds"))
# xlsx: two workbooks for organized reporting:
#   1. qc_table_main.xlsx — metadata (+ Platform, Final.QC), QC_matrix, Ctrl_matrix, statistics
#   2. qc_table_extra.xlsx — QC_metrics (thresholds), contamination, recall_rate, predUniqDonor_ID
# rds: Full MethQcSet object for programmatic access

# QC visualizations
p_bar  <- plot(qcset, type = "qc_bar")                          # PASS/FAIL bar
p_int  <- plot(qcset, type = "intensity",  icutoff = 11)        # intensity scatter
p_dp   <- plot(qcset, type = "detection_pval", pcutoff = 0.05)  # avg det p-val
p_cov  <- plot(qcset, type = "probe_coverage")                  # % probes detected
p_sex  <- plot(qcset, type = "predicted_sex")                   # predicted sex
p_ctrl <- plot(qcset, type = "ctrl_metrics")                    # control-probe metrics
plot(qcset, type = "ctrl_metrics_detail",                       # per-metric detail PDFs
     outFile = "qc_ctrl_matrix_detail")

# EPICv2 only: aggregate replicate probes before conversion (required step)
# as.ImprintomeSet() will error if this is skipped for EPICv2 data.
if (qcset@platform == "EPICv2") {
  qcset <- aggregate_probes(qcset)
}

# Keep only PASS samples before conversion
qcset_pass <- subsetMethQC(qcset, final_qc = "PASS")

# Convert the QC-clean MethQcSet to ImprintomeSet
probesets <- readRDS(system.file("extdata", "probesets_hg38.rds", package = "imprintomeR"))
x <- as.ImprintomeSet(
  qcset_pass,
  probeset = probesets[["selected"]],
  genome = "hg38"
)
```

**Option B: Pre-cleaned data loaded directly**

``` r

# If you already have QC-cleaned data, skip MethQcSet
# Note: Basename column is not needed since QC step is skipped.
meta <- LoadMeta("meta.tsv")  # Only needs Sample_Name and Sample_Group
beta <- LoadBeta("cleaned_beta.tsv")

x <- ImprintomeSet(
  beta = beta,
  meta = meta,
  probeset = probesets[["selected"]],
  genome = "hg38",
  assay = "EPICv1"
)
```

Then run analysis on your analysis-ready `ImprintomeSet`:

``` r

library(imprintomeR)
#> 
#> Attaching package: 'imprintomeR'
#> The following object is masked from 'package:base':
#> 
#>     beta

# The bundled example: beta values of the selected panel for 28 samples of GEO GSE52576
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

# Run analysis on one or more probesets
x <- runImprintome(x, probeset = "selected", ids_cutoff = 0.2)
#> 
#>  [meta dim: 28 x 5 ]
#>  [beta dim: 782 x 29 ]
#>  [meta dim: 28 x 5 ]
#>  [beta dim: 782 x 28 ]
#>  [SubsetBeta] subset by probeset [query: 782; matched probes: 782 ]
x <- runImprintome(x, probeset = "NanoImprint", ids_cutoff = 0.2,
                   result_name = "AnalyzeImprintStatus.NanoImprint")
#> 
#>  [meta dim: 28 x 5 ]
#>  [beta dim: 782 x 29 ]
#>  [meta dim: 28 x 5 ]
#>  [beta dim: 782 x 28 ]
#>  [SubsetBeta] subset by probeset [query: 325; matched probes: 325 ]

names(results(x))
#> [1] "AnalyzeImprintStatus.selected"    "AnalyzeImprintStatus.NanoImprint"
```

Extract slots once for plotting convenience:

``` r

beta_x <- beta(x)
meta_x <- meta(x)
res_x <- results(x)[["AnalyzeImprintStatus.selected"]]
```

## 2. Generic S4 Plot Method

Each plotting call below draws the figure and returns it (a ggplot
object for most plot types); add `outFile = "name.pdf"` (or `.png`) to
save it to a file.

The S4 [`plot()`](https://rdrr.io/r/graphics/plot.default.html) method
supports explicit backend dispatch via `plot_type`.

Available `plot_type` values are:

- `auto`
- `polar`
- `mirror_density`
- `beeswarm`
- `beeswarm_origin`
- `beeswarm_chr`
- `violin`
- `heatmap_by_probe`
- `circular_heatmap`
- `cor_heatmap`
- `rainfall`
- `radar`

### 2.1 Auto Dispatch

`auto` first returns the latest stored plot from `plots(x)` when
present; otherwise, it falls back to polar plotting from IDS/Angle
results.

``` r

p_auto <- plot(
  x,
  plot_type = "auto",
  result_name = "AnalyzeImprintStatus.selected",
  colorColumn = "Sample_Group"
)
p_auto
```

![Polar plot chosen automatically from the stored
results](imprintomeset-results-export_files/figure-html/unnamed-chunk-5-1.png)

### 2.2 Explicit Dispatch

``` r

p_polar_s4 <- plot(
  x,
  plot_type = "polar",
  result_name = "AnalyzeImprintStatus.selected",
  colorColumn = "Sample_Group",
  title = "Selected Probeset Polar",
  palette = "default",
  alpha = 0.5
)
p_polar_s4
```

![Polar plot of IDS and Angle for each
sample](imprintomeset-results-export_files/figure-html/unnamed-chunk-6-1.png)

### 2.3 Compact Workflow Plot Demo

Use
[`runImprintomeVisualizations()`](https://hongjianjin.github.io/imprintomeR/reference/runImprintomeVisualizations.md)
when you want a compact plot workflow. `plot_types = "default"` stores
the standard workflow plots in `plots(x)` and records skipped plots in
`attr(x, "visualization_manifest")`. The default set is `polar`,
`beeswarm_origin`, `mirror_density`, `heatmap_by_probe`,
`heatmap_by_gene`, `radar`, `beeswarm_chr`, and `rainfall`; request
`circular_heatmap` explicitly or use `plot_types = "all"` when needed.

``` r

sample_id1 <- colnames(beta(x))[2]

x <- runImprintomeVisualizations(
  x,
  plot_types = "default",
  probeset = "selected",
  sample_id = sample_id1,
  prefix = "demo",
  save_plots = FALSE,
  store_plots = TRUE
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

## 3. Sample-Level Visualizations

### 3.1 Polar Plot

``` r

p_polar <- plot(
  x,
  plot_type = "polar",
  result_name = "AnalyzeImprintStatus.selected",
  colorColumn = "Sample_Group",
  title = "ImprintomeSet Polar",
  palette = "default",
  alpha = 0.5
)
p_polar
```

![Polar plot of IDS (radius) and Angle for each sample, coloured by
sample
group](imprintomeset-results-export_files/figure-html/unnamed-chunk-8-1.png)

### 3.2 Mirror Density

``` r

p_mirror <- plot(
  x,
  plot_type = "mirror_density",
  probeset = "selected",
  SAMPLEID = "Sample_Name"
)
#> 
#>  [SubsetBeta] subset by probeset [query: 782; matched probes: 782 ]
p_mirror
```

![Mirror density plot of paternal and maternal probe
deviations](imprintomeset-results-export_files/figure-html/unnamed-chunk-9-1.png)

### 3.3 Radar Plot

One spoke per curated ICR (median IDI of its probes), in genomic order
clockwise from the top, labelled chromosome_annotated parental
origin_ICR. The saved figure grows with the label length so that no
label is clipped.

``` r

sample_id1 <- colnames(beta(x))[2]
p_radar <- plot(
  x,
  plot_type = "radar",
  probeset = "selected",
  sample_id = sample_id1,
  title = "ImprintomeSet Radar"
)
# Size (inches) that keeps the panel at 12 in with room for the labels; ggsave() uses it too
radar_size <- attr(p_radar, "imprintomeR_figure_size")
radar_size
#> [1] 16.77778
```

``` r

p_radar
```

![Radar plot of the median imprinting deviation index per ICR for one
sample](imprintomeset-results-export_files/figure-html/unnamed-chunk-11-1.png)

## 4. Probe-Level Visualizations

### 4.1 Violin Plot

``` r

p_vln <- plot(
  x,
  plot_type = "violin",
  probeset = "selected",
  SAMPLEID = "Sample_Name"
)
#> 
#>  generate violin plot ...
p_vln
#> Warning: Removed 2378 rows containing missing values or values outside the scale range
#> (`geom_violin()`).
```

![Violin plots of beta values per
sample](imprintomeset-results-export_files/figure-html/unnamed-chunk-12-1.png)

### 4.2 Beeswarm Plot

``` r

p_bee <- plot(
  x,
  plot_type = "beeswarm",
  probeset = "selected",
  SAMPLEID = "Sample_Name"
)
#> 
#>  generate dotplot ...
p_bee
#> Warning: Removed 16 rows containing missing values or values outside the scale range
#> (`position_quasirandom()`).
```

![Beeswarm plot of beta values per
sample](imprintomeset-results-export_files/figure-html/unnamed-chunk-13-1.png)

### 4.3 Single-Chromosome Beeswarm

``` r

p_bee_chr11 <- imprintomeR:::BetaBeePlot_single_chr(
  beta = beta_x,
  meta = meta_x,
  SAMPLEID = "Sample_Name",
  chr = "chr11",
  probeset = "selected"
)
#> 
#>  generate dotplot ...
p_bee_chr11
#> Warning: Removed 2 rows containing missing values or values outside the scale range
#> (`position_quasirandom()`).
```

![Beeswarm plot of chromosome 11 probes per sample, coloured by parental
origin](imprintomeset-results-export_files/figure-html/unnamed-chunk-14-1.png)

### 4.4 Origin-Split Beeswarm

Use the ImprintomeSet dispatcher (`plot_type = "beeswarm_origin"`) for
cohort-wide origin split plots.

``` r

p_bee_origin <- plot(
  x,
  plot_type = "beeswarm_origin",
  probeset = "selected",
  SAMPLEID = "Sample_Name",
  title = "Beeswarm Origin (Cohort)"
)
p_bee_origin
```

![Beeswarm plot of beta values per sample, split by annotated parental
origin](imprintomeset-results-export_files/figure-html/unnamed-chunk-15-1.png)

### 4.5 Single-Sample Beeswarm Faceted by Chromosome

``` r

sample_id1 <- colnames(beta(x))[2]
p_bee_chr <- plot(
  x,
  plot_type = "beeswarm_chr",
  probeset = "selected",
  sample_id = sample_id1,
  chr = "chr11",
  title = "Beeswarm by Chromosome (Origin Split)"
)
p_bee_chr
```

![Beeswarm plot of one sample's beta values, faceted by
chromosome](imprintomeset-results-export_files/figure-html/unnamed-chunk-16-1.png)

The subtitle reports the selected sample, probeset, and chromosome
scope. Within each chromosome panel, maternal/paternal points are
separated and median summary markers are overlaid.

## 5. Cohort-Level Visualizations

### 5.1 Correlation Heatmap

``` r

plot(
  x,
  plot_type = "cor_heatmap",
  probeset = "selected",
  SAMPLEID = "Sample_Name",
  prefix = "cohort"
)
#> 
#> Info: cohort_detail.pdf[saved]
#> Info: cohort_simple.pdf[saved]
#> Info: cohort_auto.simple.pdf[saved]
#>            GSM1270013 GSM1270014 GSM1270015 GSM1270016 GSM1270017  GSM1270018
#> GSM1270013 1.00000000 0.80661194 0.62769850 0.49987050 0.71630028  0.05766659
#> GSM1270014 0.80661194 1.00000000 0.73407451 0.51381024 0.73397467  0.06559533
#> GSM1270015 0.62769850 0.73407451 1.00000000 0.53871992 0.67609016  0.15970360
#> GSM1270016 0.49987050 0.51381024 0.53871992 1.00000000 0.56615944  0.04788016
#> GSM1270017 0.71630028 0.73397467 0.67609016 0.56615944 1.00000000  0.08036917
#> GSM1270018 0.05766659 0.06559533 0.15970360 0.04788016 0.08036917  1.00000000
#> GSM1270019 0.09550240 0.07888783 0.16015269 0.04882061 0.07692664  0.94174875
#> GSM1270020 0.12607797 0.11765324 0.19185782 0.08561024 0.12308043  0.94473891
#> GSM1270021 0.15188515 0.14748508 0.20330633 0.09984091 0.15343405  0.88496400
#> GSM1270022 0.37163942 0.40364000 0.43336410 0.28810485 0.38949132  0.41249281
#> GSM1270023 0.40983932 0.44137127 0.44633838 0.29064169 0.40124560  0.43381361
#> GSM1270024 0.39713459 0.40571530 0.42359206 0.26652937 0.39533413  0.41031334
#> GSM1270025 0.39197543 0.42375499 0.48819786 0.33988966 0.44819509  0.43859590
#> GSM1270026 0.07032468 0.06935021 0.13161368 0.08591575 0.07463614  0.36870117
#> GSM1270027 0.27946107 0.28775354 0.34223793 0.20664259 0.30262731  0.29616464
#> GSM1270028 0.36535609 0.36970153 0.39037890 0.25326904 0.44188141  0.09299163
#> GSM1270029 0.34476491 0.44853916 0.43785565 0.28182838 0.48514152  0.12644448
#> GSM1270030 0.47141412 0.46883848 0.38714624 0.29543654 0.51490802  0.11360480
#> GSM1270031 0.48766660 0.40287848 0.34560224 0.26813878 0.46840332  0.08483410
#> GSM1270032 0.15820030 0.18020740 0.16928264 0.12230802 0.29999142 -0.40425675
#> GSM1270033 0.16625264 0.13084670 0.09803759 0.06997710 0.26915733 -0.43251182
#> GSM1270034 0.19059163 0.20214313 0.18910443 0.16899635 0.34923765 -0.34221873
#> GSM1270035 0.09972642 0.14473413 0.13821227 0.09050229 0.27858247 -0.37503730
#> GSM1270036 0.23757649 0.24259311 0.23047959 0.13923187 0.28751864  0.55540149
#> GSM1270037 0.38488568 0.40899042 0.38679381 0.25525232 0.49058080  0.49812141
#> GSM1270038 0.25282957 0.21355951 0.19380546 0.11044919 0.27470088  0.58720223
#> GSM1270039 0.20603055 0.17679222 0.18355126 0.13642891 0.25512195  0.58574875
#> GSM1270040 0.34270105 0.24118283 0.25008611 0.24339112 0.31982548 -0.35270317
#>             GSM1270019  GSM1270020  GSM1270021  GSM1270022   GSM1270023
#> GSM1270013  0.09550240  0.12607797  0.15188515  0.37163942  0.409839316
#> GSM1270014  0.07888783  0.11765324  0.14748508  0.40364000  0.441371265
#> GSM1270015  0.16015269  0.19185782  0.20330633  0.43336410  0.446338376
#> GSM1270016  0.04882061  0.08561024  0.09984091  0.28810485  0.290641692
#> GSM1270017  0.07692664  0.12308043  0.15343405  0.38949132  0.401245599
#> GSM1270018  0.94174875  0.94473891  0.88496400  0.41249281  0.433813607
#> GSM1270019  1.00000000  0.95610624  0.93997849  0.39478714  0.420689059
#> GSM1270020  0.95610624  1.00000000  0.93125889  0.46208688  0.478107737
#> GSM1270021  0.93997849  0.93125889  1.00000000  0.35791958  0.382699286
#> GSM1270022  0.39478714  0.46208688  0.35791958  1.00000000  0.948376294
#> GSM1270023  0.42068906  0.47810774  0.38269929  0.94837629  1.000000000
#> GSM1270024  0.38893097  0.46307116  0.34960573  0.94093283  0.948678222
#> GSM1270025  0.40726810  0.46528926  0.36796195  0.93053984  0.935041552
#> GSM1270026  0.44499484  0.43559587  0.50250785 -0.01797943 -0.003050516
#> GSM1270027  0.34673159  0.36948406  0.44623646  0.15223349  0.193559484
#> GSM1270028  0.13457122  0.10588420  0.14715552  0.06828010  0.102223616
#> GSM1270029  0.08284802  0.13065573  0.11315359  0.17746547  0.174505720
#> GSM1270030  0.16125385  0.12418161  0.20032009  0.13155655  0.159305261
#> GSM1270031  0.17303690  0.10141336  0.19868289  0.07718749  0.093615685
#> GSM1270032 -0.38778583 -0.43043904 -0.32687021 -0.05077794 -0.067223920
#> GSM1270033 -0.41303697 -0.45910329 -0.36297178 -0.09308199 -0.117824823
#> GSM1270034 -0.35279763 -0.38020670 -0.32563367  0.11578779  0.089567259
#> GSM1270035 -0.37204525 -0.41236878 -0.34560102  0.05068901  0.022724786
#> GSM1270036  0.64480485  0.62968520  0.73433513  0.06646897  0.098339514
#> GSM1270037  0.56342590  0.57806297  0.68065770  0.17544961  0.208068094
#> GSM1270038  0.68844464  0.66623623  0.76420812  0.07508950  0.106109310
#> GSM1270039  0.68432074  0.66112012  0.75648199  0.05793297  0.070420134
#> GSM1270040 -0.42293073 -0.37055989 -0.47144299  0.34901256  0.321266674
#>              GSM1270024  GSM1270025    GSM1270026 GSM1270027   GSM1270028
#> GSM1270013  0.397134593  0.39197543  0.0703246840  0.2794611 0.3653560888
#> GSM1270014  0.405715299  0.42375499  0.0693502066  0.2877535 0.3697015315
#> GSM1270015  0.423592059  0.48819786  0.1316136811  0.3422379 0.3903788959
#> GSM1270016  0.266529374  0.33988966  0.0859157458  0.2066426 0.2532690362
#> GSM1270017  0.395334126  0.44819509  0.0746361419  0.3026273 0.4418814054
#> GSM1270018  0.410313339  0.43859590  0.3687011689  0.2961646 0.0929916303
#> GSM1270019  0.388930968  0.40726810  0.4449948355  0.3467316 0.1345712228
#> GSM1270020  0.463071165  0.46528926  0.4355958741  0.3694841 0.1058841980
#> GSM1270021  0.349605728  0.36796195  0.5025078543  0.4462365 0.1471555167
#> GSM1270022  0.940932825  0.93053984 -0.0179794309  0.1522335 0.0682800981
#> GSM1270023  0.948678222  0.93504155 -0.0030505158  0.1935595 0.1022236156
#> GSM1270024  1.000000000  0.92719782 -0.0030776183  0.1938754 0.1088075475
#> GSM1270025  0.927197817  1.00000000  0.0115268374  0.2030220 0.1423889094
#> GSM1270026 -0.003077618  0.01152684  1.0000000000  0.7845888 0.0005461929
#> GSM1270027  0.193875377  0.20302203  0.7845887937  1.0000000 0.1081055936
#> GSM1270028  0.108807547  0.14238891  0.0005461929  0.1081056 1.0000000000
#> GSM1270029  0.209511599  0.21912731  0.0231126780  0.1611979 0.7004605545
#> GSM1270030  0.165372369  0.20195548  0.0943162111  0.2311653 0.7335654716
#> GSM1270031  0.101341720  0.13215948  0.1461398840  0.2401581 0.6622141347
#> GSM1270032 -0.058244734 -0.02468417 -0.2677769628 -0.1480804 0.3607268677
#> GSM1270033 -0.105530548 -0.08460175 -0.2209934649 -0.1382705 0.2117589260
#> GSM1270034  0.105892253  0.13844723 -0.2748185241 -0.1062838 0.2849019732
#> GSM1270035  0.038328788  0.07093504 -0.2552712567 -0.1433023 0.2287316409
#> GSM1270036  0.064694144  0.09982736  0.5140856578  0.5171994 0.2515183744
#> GSM1270037  0.180952715  0.21196580  0.4469197561  0.5617280 0.3103645992
#> GSM1270038  0.076986609  0.10288662  0.5038687643  0.4699714 0.2510277490
#> GSM1270039  0.047872910  0.08378781  0.5166036299  0.4473242 0.3017106361
#> GSM1270040  0.357485941  0.35503274 -0.3796930241 -0.1986131 0.0635727336
#>            GSM1270029 GSM1270030 GSM1270031  GSM1270032  GSM1270033  GSM1270034
#> GSM1270013 0.34476491 0.47141412 0.48766660  0.15820030  0.16625264  0.19059163
#> GSM1270014 0.44853916 0.46883848 0.40287848  0.18020740  0.13084670  0.20214313
#> GSM1270015 0.43785565 0.38714624 0.34560224  0.16928264  0.09803759  0.18910443
#> GSM1270016 0.28182838 0.29543654 0.26813878  0.12230802  0.06997710  0.16899635
#> GSM1270017 0.48514152 0.51490802 0.46840332  0.29999142  0.26915733  0.34923765
#> GSM1270018 0.12644448 0.11360480 0.08483410 -0.40425675 -0.43251182 -0.34221873
#> GSM1270019 0.08284802 0.16125385 0.17303690 -0.38778583 -0.41303697 -0.35279763
#> GSM1270020 0.13065573 0.12418161 0.10141336 -0.43043904 -0.45910329 -0.38020670
#> GSM1270021 0.11315359 0.20032009 0.19868289 -0.32687021 -0.36297178 -0.32563367
#> GSM1270022 0.17746547 0.13155655 0.07718749 -0.05077794 -0.09308199  0.11578779
#> GSM1270023 0.17450572 0.15930526 0.09361569 -0.06722392 -0.11782482  0.08956726
#> GSM1270024 0.20951160 0.16537237 0.10134172 -0.05824473 -0.10553055  0.10589225
#> GSM1270025 0.21912731 0.20195548 0.13215948 -0.02468417 -0.08460175  0.13844723
#> GSM1270026 0.02311268 0.09431621 0.14613988 -0.26777696 -0.22099346 -0.27481852
#> GSM1270027 0.16119790 0.23116530 0.24015809 -0.14808045 -0.13827047 -0.10628383
#> GSM1270028 0.70046055 0.73356547 0.66221413  0.36072687  0.21175893  0.28490197
#> GSM1270029 1.00000000 0.72056731 0.51952136  0.26717786  0.19627289  0.23761138
#> GSM1270030 0.72056731 1.00000000 0.86400996  0.31760965  0.26802583  0.31392373
#> GSM1270031 0.51952136 0.86400996 1.00000000  0.37533428  0.34974739  0.36917630
#> GSM1270032 0.26717786 0.31760965 0.37533428  1.00000000  0.89244246  0.87942482
#> GSM1270033 0.19627289 0.26802583 0.34974739  0.89244246  1.00000000  0.87230450
#> GSM1270034 0.23761138 0.31392373 0.36917630  0.87942482  0.87230450  1.00000000
#> GSM1270035 0.19377972 0.24030175 0.32215140  0.91214422  0.90380864  0.94565481
#> GSM1270036 0.17580106 0.34148704 0.34027197 -0.18698989 -0.21954128 -0.26150436
#> GSM1270037 0.30839479 0.39438077 0.38382132 -0.11348823 -0.15495690 -0.17471231
#> GSM1270038 0.16882714 0.33187632 0.35931613 -0.19809286 -0.22452384 -0.26390693
#> GSM1270039 0.21164796 0.38603817 0.39945675 -0.16498234 -0.20203404 -0.24939945
#> GSM1270040 0.14477256 0.08472620 0.11703202  0.40303893  0.44624505  0.57221452
#>             GSM1270035  GSM1270036 GSM1270037  GSM1270038  GSM1270039
#> GSM1270013  0.09972642  0.23757649  0.3848857  0.25282957  0.20603055
#> GSM1270014  0.14473413  0.24259311  0.4089904  0.21355951  0.17679222
#> GSM1270015  0.13821227  0.23047959  0.3867938  0.19380546  0.18355126
#> GSM1270016  0.09050229  0.13923187  0.2552523  0.11044919  0.13642891
#> GSM1270017  0.27858247  0.28751864  0.4905808  0.27470088  0.25512195
#> GSM1270018 -0.37503730  0.55540149  0.4981214  0.58720223  0.58574875
#> GSM1270019 -0.37204525  0.64480485  0.5634259  0.68844464  0.68432074
#> GSM1270020 -0.41236878  0.62968520  0.5780630  0.66623623  0.66112012
#> GSM1270021 -0.34560102  0.73433513  0.6806577  0.76420812  0.75648199
#> GSM1270022  0.05068901  0.06646897  0.1754496  0.07508950  0.05793297
#> GSM1270023  0.02272479  0.09833951  0.2080681  0.10610931  0.07042013
#> GSM1270024  0.03832879  0.06469414  0.1809527  0.07698661  0.04787291
#> GSM1270025  0.07093504  0.09982736  0.2119658  0.10288662  0.08378781
#> GSM1270026 -0.25527126  0.51408566  0.4469198  0.50386876  0.51660363
#> GSM1270027 -0.14330235  0.51719940  0.5617280  0.46997140  0.44732421
#> GSM1270028  0.22873164  0.25151837  0.3103646  0.25102775  0.30171064
#> GSM1270029  0.19377972  0.17580106  0.3083948  0.16882714  0.21164796
#> GSM1270030  0.24030175  0.34148704  0.3943808  0.33187632  0.38603817
#> GSM1270031  0.32215140  0.34027197  0.3838213  0.35931613  0.39945675
#> GSM1270032  0.91214422 -0.18698989 -0.1134882 -0.19809286 -0.16498234
#> GSM1270033  0.90380864 -0.21954128 -0.1549569 -0.22452384 -0.20203404
#> GSM1270034  0.94565481 -0.26150436 -0.1747123 -0.26390693 -0.24939945
#> GSM1270035  1.00000000 -0.27393707 -0.2027357 -0.28111684 -0.25347097
#> GSM1270036 -0.27393707  1.00000000  0.8813702  0.95240014  0.93124978
#> GSM1270037 -0.20273566  0.88137022  1.0000000  0.87603834  0.82433020
#> GSM1270038 -0.28111684  0.95240014  0.8760383  1.00000000  0.93076295
#> GSM1270039 -0.25347097  0.93124978  0.8243302  0.93076295  1.00000000
#> GSM1270040  0.49680008 -0.55694250 -0.3962835 -0.53798533 -0.51282199
#>             GSM1270040
#> GSM1270013  0.34270105
#> GSM1270014  0.24118283
#> GSM1270015  0.25008611
#> GSM1270016  0.24339112
#> GSM1270017  0.31982548
#> GSM1270018 -0.35270317
#> GSM1270019 -0.42293073
#> GSM1270020 -0.37055989
#> GSM1270021 -0.47144299
#> GSM1270022  0.34901256
#> GSM1270023  0.32126667
#> GSM1270024  0.35748594
#> GSM1270025  0.35503274
#> GSM1270026 -0.37969302
#> GSM1270027 -0.19861306
#> GSM1270028  0.06357273
#> GSM1270029  0.14477256
#> GSM1270030  0.08472620
#> GSM1270031  0.11703202
#> GSM1270032  0.40303893
#> GSM1270033  0.44624505
#> GSM1270034  0.57221452
#> GSM1270035  0.49680008
#> GSM1270036 -0.55694250
#> GSM1270037 -0.39628350
#> GSM1270038 -0.53798533
#> GSM1270039 -0.51282199
#> GSM1270040  1.00000000
list.files(pattern = "^cohort_")   # the correlation heatmap is written to PDF files
#> [1] "cohort_auto.simple.pdf" "cohort_detail.pdf"      "cohort_simple.pdf"
```

### 5.2 Heatmap_by_probe (Probe-Level Heatmap)

Displays individual Illumina probe IDs (e.g., cg00000029) as rows and
samples as columns with their methylation values color-coded.

``` r

plot(
  x,
  plot_type = "heatmap_by_probe",
  probeset = "selected",
  SAMPLEID = "Sample_Name"
)
```

![Heatmap of beta values of the panel probes, probes by
samples](imprintomeset-results-export_files/figure-html/unnamed-chunk-18-1.png)

### 5.3 Circular Heatmap

Circular heatmap displays methylation values arranged in a circular
layout. Each chromosome forms a radial sector, with probes arranged
clockwise. Sample groups are rendered as separate “pie slices” around
the center white circle, allowing visual comparison of methylation
patterns across grouped samples and chromosomes simultaneously.

**Parameters:**

- `sectionColumn`: metadata column for grouping samples (default
  `"Sample_Group"`). If the column is missing, samples are grouped by
  `Sample_Name` (one section per sample). If both are missing, all
  samples appear in one section.
- `probeset`: probeset name (default `"selected"`)
- `SAMPLEID`: metadata column for sample labeling

**Features:**

- Shows probes × samples with chromosome organization
- Color scale: blue (unmethylated, β ≈ 0) → white (hemimethylated, β ≈
  0.5) → red (methylated, β ≈ 1)
- Automatic adaptive sizing: larger canvas (12×10 inches) accommodates
  4+ sample groups
- Section labels positioned in the inner white circle for clarity

The layout has room for a few sections only, so this example keeps three
of the 11 sample groups:

``` r

keep <- meta_x$Sample_Group %in% c("Hydatidiform mole", "parthenogenetic activated oocytes",
                                   "Term placenta- fetal side")
x_sub <- ImprintomeSet(beta = beta_x[, keep], meta = meta_x[keep, ],
                       probeset = probesets[["selected"]], genome = "hg38", assay = "450K")
plot(
  x_sub,
  plot_type = "circular_heatmap",
  SAMPLEID = "Sample_Name",
  sectionColumn = "Sample_Group",
  probeset = "selected"
)
#> 
#> INFO:  number of annotated probes is  777 
#> [1] "Hydatidiform mole"                 "Term placenta- fetal side"        
#> [3] "parthenogenetic activated oocytes"
#> 
#> INFO: process section # 1 Hydatidiform mole
#> Note: 1 point is out of plotting region in sector 'chr22', track '5'.
#> Note: 17 points are out of plotting region in sector 'chr22', track
#> '5'.
#> 
#> INFO: process section # 2 Term placenta- fetal side
#> Note: 1 point is out of plotting region in sector 'chr22', track '6'.
#> Note: 25 points are out of plotting region in sector 'chr22', track
#> '6'.
#> 
#> INFO: process section # 3 parthenogenetic activated oocytes
#> Note: 1 point is out of plotting region in sector 'chr22', track '7'.
#> Note: 33 points are out of plotting region in sector 'chr22', track
#> '7'.
```

![Circular heatmap of beta values by chromosome for three sample
groups](imprintomeset-results-export_files/figure-html/unnamed-chunk-19-1.png)

### 5.4 Heatmap Aggregated by Gene Symbol

This visualization aggregates probe-level beta values to gene-level
summaries by grouping probes with the same `Closest_TSS_gene_name` from
the selected probeset. Within each gene, probes are aggregated per
sample using the **median** function.

**Features:**

- Shows gene symbols as rows and samples as columns
- Robust aggregation: reduces ~865k probes (EPICv2) → ~50-200 unique
  genes per probeset
- Clustered by default: genes clustered via Euclidean distance (Ward
  linkage)
- Top annotation: sample groups with automatic color assignment
- Color scale: blue (unmethylated) → white (hemimethylated) → red
  (methylated)

**Parameters:**

- `probeset`: probeset name (default `"selected"`)
- `SAMPLEID`: metadata column for sample labels
- `annoColumn`: annotation column for top heatmap header (default
  `"Sample_Group"`)
- `clusterRows`: hierarchical cluster genes? (default `TRUE`)
- `clusterColumns`: hierarchical cluster samples? (default `TRUE`)
- `outFile`: optional output file (PDF, or PNG with a `.png` extension)

``` r

plot(
  x,
  plot_type = "heatmap_by_gene",
  probeset = "selected",
  SAMPLEID = "Sample_Name",
  annoColumn = "Sample_Group",
  clusterRows = TRUE,
  clusterColumns = TRUE
)
```

![Heatmap of median beta values per gene label, genes by
samples](imprintomeset-results-export_files/figure-html/unnamed-chunk-20-1.png)

## 6. Chromosome and Genome Visualizations

### 6.1 Chromosome Beeswarm Panels

Chromosome beeswarm plots show only chromosomes with at least five
usable (finite) probe values for the selected sample. A
single-chromosome request with fewer than five usable probes returns an
informative error.

``` r

p_bee_chr_all <- plot(
  x,
  plot_type = "beeswarm_chr",
  probeset = "selected",
  sample_id = sample_id1,
  chr = NULL,
  title = "Beeswarm by Chromosome (All Chromosomes)"
)
p_bee_chr_all
```

![Beeswarm panels of beta values for each
chromosome](imprintomeset-results-export_files/figure-html/unnamed-chunk-21-1.png)

### 6.2 Rainfall Plot

``` r

sample_id1 <- colnames(beta(x))[2]

p_rain <- plot(
  x,
  plot_type = "rainfall",
  sample_id = sample_id1,
  probeset = "selected"
)
p_rain
#> Warning: Removed 1 row containing missing values or values outside the scale range
#> (`geom_point()`).
```

![Rainfall plot of probe-level imprinting deviation along the genome for
one
sample](imprintomeset-results-export_files/figure-html/unnamed-chunk-22-1.png)

### 6.3 Chromosome vs Others Beeswarm

``` r

probesets <- readRDS(system.file("extdata", "probesets_hg38.rds", package = "imprintomeR"))
ps <- probesets[["selected"]]
common_probes <- intersect(ps$NAME, rownames(beta_x))

dat_chr <- as.data.frame(beta_x[common_probes, , drop = FALSE])
idx <- match(common_probes, ps$NAME)
dat_chr$chr <- ifelse(ps$CHR[idx] %in% c("chr11", "11"), "chr11", "others")
dat_chr$CATEGORY <- ps$ORIGIN[idx]

# One plot per sample; the first two are shown here (pass outFile = "name.pdf" to write all to one PDF)

imprintomeR:::Beeplot_chr_vs_other(
  dat = dat_chr,
  meta = meta_x[1:2, ],
  group.by = "chr",
  color.by = "CATEGORY"
)
#> Warning in fortify(data, ...): Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Warning: Removed 2 rows containing missing values or values outside the scale range
#> (`position_quasirandom()`).
```

![Beeswarm plots comparing chromosome 11 probes with all other probes,
one per
sample](imprintomeset-results-export_files/figure-html/unnamed-chunk-23-1.png)

    #> Warning in fortify(data, ...): Arguments in `...` must be used.
    #> ✖ Problematic argument:
    #> • alpha = 1
    #> ℹ Did you misspell an argument name?
    #> Warning: Removed 1 row containing missing values or values outside the scale range
    #> (`position_quasirandom()`).

![Beeswarm plots comparing chromosome 11 probes with all other probes,
one per
sample](imprintomeset-results-export_files/figure-html/unnamed-chunk-23-2.png)

### 6.4 Batch Chromosome vs Others Convenience Wrapper

``` r

imprintomeR:::Beeplot_chr_vs_other_single(
  input = list(beta = beta_x, meta = meta_x),
  chrs = "chr1,chr11,chr20",
  prefix = "chr_vs_other_batch",
  probeset = "selected"
)
#> 
#>   chr1
#> Warning in fortify(data, ...): Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Warning: Removed 2 rows containing missing values or values outside the scale range
#> (`position_quasirandom()`).
#> Warning in fortify(data, ...): Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Warning: Removed 1 row containing missing values or values outside the scale range
#> (`position_quasirandom()`).
#> Warning in fortify(data, ...): Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Warning: Removed 1 row containing missing values or values outside the scale range
#> (`position_quasirandom()`).
#> Warning in fortify(data, ...): Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Warning: Removed 1 row containing missing values or values outside the scale range
#> (`position_quasirandom()`).
#> Warning in fortify(data, ...): Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Warning: Removed 1 row containing missing values or values outside the scale range
#> (`position_quasirandom()`).
#> Warning in fortify(data, ...): Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Warning: Removed 1 row containing missing values or values outside the scale range
#> (`position_quasirandom()`).
#> Warning in fortify(data, ...): Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Warning: Removed 1 row containing missing values or values outside the scale range
#> (`position_quasirandom()`).
#> Warning in fortify(data, ...): Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Warning: Removed 1 row containing missing values or values outside the scale range
#> (`position_quasirandom()`).
#> Warning in fortify(data, ...): Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Warning: Removed 3 rows containing missing values or values outside the scale range
#> (`position_quasirandom()`).
#> Warning in fortify(data, ...): Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Warning: Removed 1 row containing missing values or values outside the scale range
#> (`position_quasirandom()`).
#> Warning in fortify(data, ...): Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Warning: Removed 1 row containing missing values or values outside the scale range
#> (`position_quasirandom()`).
#> Warning in fortify(data, ...): Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Warning: Removed 1 row containing missing values or values outside the scale range
#> (`position_quasirandom()`).
#> Warning in fortify(data, ...): Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Warning: Removed 1 row containing missing values or values outside the scale range
#> (`position_quasirandom()`).
#> Warning in fortify(data, ...): Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> 
#>   chr_vs_other_batch_beeplot_chr1.pdf [saved]
#>   chr11
#> Warning in fortify(data, ...): Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Warning: Removed 2 rows containing missing values or values outside the scale range
#> (`position_quasirandom()`).
#> Warning in fortify(data, ...): Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Warning: Removed 1 row containing missing values or values outside the scale range
#> (`position_quasirandom()`).
#> Warning in fortify(data, ...): Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Warning: Removed 1 row containing missing values or values outside the scale range
#> (`position_quasirandom()`).
#> Warning in fortify(data, ...): Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Warning: Removed 1 row containing missing values or values outside the scale range
#> (`position_quasirandom()`).
#> Warning in fortify(data, ...): Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Warning: Removed 1 row containing missing values or values outside the scale range
#> (`position_quasirandom()`).
#> Warning in fortify(data, ...): Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Warning: Removed 1 row containing missing values or values outside the scale range
#> (`position_quasirandom()`).
#> Warning in fortify(data, ...): Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Warning: Removed 1 row containing missing values or values outside the scale range
#> (`position_quasirandom()`).
#> Warning in fortify(data, ...): Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Warning: Removed 1 row containing missing values or values outside the scale range
#> (`position_quasirandom()`).
#> Warning in fortify(data, ...): Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Warning: Removed 3 rows containing missing values or values outside the scale range
#> (`position_quasirandom()`).
#> Warning in fortify(data, ...): Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Warning: Removed 1 row containing missing values or values outside the scale range
#> (`position_quasirandom()`).
#> Warning in fortify(data, ...): Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Warning: Removed 1 row containing missing values or values outside the scale range
#> (`position_quasirandom()`).
#> Warning in fortify(data, ...): Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Warning: Removed 1 row containing missing values or values outside the scale range
#> (`position_quasirandom()`).
#> Warning in fortify(data, ...): Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Warning: Removed 1 row containing missing values or values outside the scale range
#> (`position_quasirandom()`).
#> Warning in fortify(data, ...): Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> 
#>   chr_vs_other_batch_beeplot_chr11.pdf [saved]
#>   chr20
#> Warning in fortify(data, ...): Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Warning: Removed 2 rows containing missing values or values outside the scale range
#> (`position_quasirandom()`).
#> Warning in fortify(data, ...): Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Warning: Removed 1 row containing missing values or values outside the scale range
#> (`position_quasirandom()`).
#> Warning in fortify(data, ...): Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Warning: Removed 1 row containing missing values or values outside the scale range
#> (`position_quasirandom()`).
#> Warning in fortify(data, ...): Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Warning: Removed 1 row containing missing values or values outside the scale range
#> (`position_quasirandom()`).
#> Warning in fortify(data, ...): Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Warning: Removed 1 row containing missing values or values outside the scale range
#> (`position_quasirandom()`).
#> Warning in fortify(data, ...): Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Warning: Removed 1 row containing missing values or values outside the scale range
#> (`position_quasirandom()`).
#> Warning in fortify(data, ...): Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Warning: Removed 1 row containing missing values or values outside the scale range
#> (`position_quasirandom()`).
#> Warning in fortify(data, ...): Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Warning: Removed 1 row containing missing values or values outside the scale range
#> (`position_quasirandom()`).
#> Warning in fortify(data, ...): Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Warning: Removed 3 rows containing missing values or values outside the scale range
#> (`position_quasirandom()`).
#> Warning in fortify(data, ...): Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Warning: Removed 1 row containing missing values or values outside the scale range
#> (`position_quasirandom()`).
#> Warning in fortify(data, ...): Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Warning: Removed 1 row containing missing values or values outside the scale range
#> (`position_quasirandom()`).
#> Warning in fortify(data, ...): Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Warning: Removed 1 row containing missing values or values outside the scale range
#> (`position_quasirandom()`).
#> Warning in fortify(data, ...): Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Warning: Removed 1 row containing missing values or values outside the scale range
#> (`position_quasirandom()`).
#> Warning in fortify(data, ...): Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> Arguments in `...` must be used.
#> ✖ Problematic argument:
#> • alpha = 1
#> ℹ Did you misspell an argument name?
#> 
#>   chr_vs_other_batch_beeplot_chr20.pdf [saved]
```

## 7. Persist Plot Objects Inside ImprintomeSet

[`runImprintomeVisualizations()`](https://hongjianjin.github.io/imprintomeR/reference/runImprintomeVisualizations.md)
stores successful plots in `plots(x)` when `store_plots = TRUE`, so the
object can be exported later with `export(x, save_plots = TRUE)`.
`plot_types = "default"` excludes `circular_heatmap`; add it explicitly
when you want that direct-draw plot stored too.

``` r

x <- runImprintomeVisualizations(
  x,
  plot_types = "default",
  probeset = "selected",
  sample_id = colnames(beta(x))[2],
  prefix = "imprintomeset_results_export",
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

names(plots(x))
#> [1] "polar.selected"                   "beeswarm_origin.selected"        
#> [3] "mirror_density.selected"          "heatmap.selected"                
#> [5] "heatmap_by_gene.selected"         "radar.selected.GSM1270014"       
#> [7] "beeswarm_chr.selected.GSM1270014" "rainfall.selected.GSM1270014"

# Access stored plot objects
plots(x)[["polar.selected"]]
```

![Stored polar and beeswarm
plots](imprintomeset-results-export_files/figure-html/unnamed-chunk-25-1.png)

``` r

plots(x)[["beeswarm_origin.selected"]]
```

![Stored polar and beeswarm
plots](imprintomeset-results-export_files/figure-html/unnamed-chunk-25-2.png)

``` r


# Store circular heatmap explicitly when needed (three sample groups, see section 5.3)
x_sub <- runImprintomeVisualizations(
  x_sub,
  plot_types = "circular_heatmap",
  probeset = "selected",
  sample_id = colnames(beta(x_sub))[2],
  prefix = "imprintomeset_results_export_circular",
  store_plots = TRUE,
  save_plots = FALSE
)
#> Generating circular_heatmap ...Note: 1 point is out of plotting region in sector 'chr22', track '5'.
#> Note: 17 points are out of plotting region in sector 'chr22', track
#> '5'.
#> Note: 1 point is out of plotting region in sector 'chr22', track '6'.
#> Note: 25 points are out of plotting region in sector 'chr22', track
#> '6'.
#> Note: 1 point is out of plotting region in sector 'chr22', track '7'.
#> Note: 33 points are out of plotting region in sector 'chr22', track
#> '7'.
#>  stored_file
names(plots(x_sub))   # the circular heatmap is stored as a rendered PDF
#> [1] "circular.selected"
```

## 8. Summarize and Export

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
s$qc
#> NULL
s$plots
#>                                                              name
#> beeswarm_chr.selected.GSM1270014 beeswarm_chr.selected.GSM1270014
#> beeswarm_origin.selected                 beeswarm_origin.selected
#> heatmap_by_gene.selected                 heatmap_by_gene.selected
#> heatmap.selected                                 heatmap.selected
#> mirror_density.selected                   mirror_density.selected
#> polar.selected                                     polar.selected
#> radar.selected.GSM1270014               radar.selected.GSM1270014
#> rainfall.selected.GSM1270014         rainfall.selected.GSM1270014
#>                                            class
#> beeswarm_chr.selected.GSM1270014 ggplot2::ggplot
#> beeswarm_origin.selected         ggplot2::ggplot
#> heatmap_by_gene.selected                 Heatmap
#> heatmap.selected                         Heatmap
#> mirror_density.selected          ggplot2::ggplot
#> polar.selected                   ggplot2::ggplot
#> radar.selected.GSM1270014        ggplot2::ggplot
#> rainfall.selected.GSM1270014     ggplot2::ggplot

manifest <- export(
  x,
  outdir = "imprintome_export",
  prefix = "imprintomeset_results_export",
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
#>                                                                                          file
#> 1                            imprintome_export/imprintomeset_results_export_imprintomeSet.rds
#> 2 imprintome_export/imprintomeset_results_export_results_AnalyzeImprintStatus.NanoImprint.tsv
#> 3    imprintome_export/imprintomeset_results_export_results_AnalyzeImprintStatus.selected.tsv
#> 4    imprintome_export/imprintomeset_results_export_plot_beeswarm_chr.selected.GSM1270014.pdf
#> 5            imprintome_export/imprintomeset_results_export_plot_beeswarm_origin.selected.pdf
#> 6            imprintome_export/imprintomeset_results_export_plot_heatmap_by_gene.selected.pdf
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
stored object can be rendered as a plot file. Unknown plot object types
fall back to RDS. QC tables remain available through `qc(x)` and
`summarize(x)$qc`.

**For MethQcSet export**, the output includes a `summary.txt` file with
an automatically-generated “Notes” section:

``` r

export(qcset, outdir = "qc_output", format = c("xlsx", "rds"))

# Inspect the summary.txt file to see which sheets were created:
readLines("qc_output/methqcset_summary.txt")
```

The Notes section documents any optional sheets that were not created
due to missing underlying data (e.g., missing `ctrl_metrics`,
`contamination`, etc.). This provides transparency about data
availability during export.

## 9. Notes

- Several plotting functions write side-effect files and also return
  plot objects.
- For large cohorts, disable per-sample side folders where optional
  (`pdfFolder = NULL`).
- Keep `Sample_Name` alignment between `beta(x)` and `meta(x)`.
- Advanced, non-dispatch plots can still be called directly when needed.

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
#> [1] imprintomeR_1.6.0
#> 
#> loaded via a namespace (and not attached):
#>  [1] gtable_0.3.6          beeswarm_0.4.0        circlize_0.4.18      
#>  [4] shape_1.4.6.1         rjson_0.2.23          xfun_0.62            
#>  [7] bslib_0.12.0          ggplot2_4.0.4         GlobalOptions_0.1.4  
#> [10] ggrepel_0.9.8         vctrs_0.7.3           tools_4.6.2          
#> [13] generics_0.1.4        stats4_4.6.2          parallel_4.6.2       
#> [16] tibble_3.3.1          cluster_2.1.8.3       pkgconfig_2.0.3      
#> [19] pheatmap_1.0.13       data.table_1.18.6.1   RColorBrewer_1.1-3   
#> [22] S7_1.0.0              desc_1.4.3            S4Vectors_0.50.3     
#> [25] lifecycle_1.0.5       compiler_4.6.2        farver_2.1.2         
#> [28] stringr_1.6.0         textshaping_1.1.0     codetools_0.2-20     
#> [31] ComplexHeatmap_2.28.0 clue_0.3-68           vipor_0.4.7          
#> [34] htmltools_0.5.9       sass_0.5.0            yaml_2.3.12          
#> [37] pillar_1.11.1         pkgdown_2.2.1         crayon_1.5.3         
#> [40] jquerylib_0.1.4       tidyr_1.3.2           cachem_1.1.0         
#> [43] iterators_1.0.14      foreach_1.5.2         tidyselect_1.2.1     
#> [46] zip_3.0.2             digest_0.6.39         stringi_1.8.9        
#> [49] dplyr_1.2.1           reshape2_1.4.5        purrr_1.2.2          
#> [52] labeling_0.4.3        cowplot_1.2.0         fastmap_1.2.0        
#> [55] grid_4.6.2            colorspace_2.1-4      cli_3.6.6            
#> [58] magrittr_2.0.5        patchwork_1.3.2       withr_3.0.3          
#> [61] scales_1.4.0          ggbeeswarm_0.7.3      rmarkdown_2.32       
#> [64] matrixStats_1.5.0     otel_0.3.0            ragg_1.5.2           
#> [67] png_0.1-9             GetoptLong_1.1.1      openxlsx_4.2.9       
#> [70] evaluate_1.0.5        knitr_1.52            IRanges_2.46.0       
#> [73] doParallel_1.0.17     rlang_1.3.0           Rcpp_1.1.2           
#> [76] gridBase_0.4-7        glue_1.8.1            BiocGenerics_0.58.1  
#> [79] jsonlite_2.0.0        R6_2.6.1              plyr_1.8.9           
#> [82] systemfonts_1.3.4     fs_2.1.0
```
