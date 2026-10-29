# Visualization

[← Back to README](../README.md)

## Available plot types

- `auto` - smart dispatch
- `polar` - IDS vs Angle scatter with colored samples
- `mirror_density` - maternal/paternal methylation density distributions
- `beeswarm` - cohort probe methylation by sample
- `beeswarm_origin` - origin-split beeswarm (maternal/paternal probes)
- `beeswarm_chr` - chromosome-faceted beeswarm (single sample)
- `violin` - methylation distribution by sample (violin plots)
- `heatmap_by_probe` - Heatmap_by_probe (probes × samples with Illumina probe IDs)
- `heatmap_by_gene` - gene-level aggregated heatmap (genes aggregated by Closest_TSS_gene_name)
- `circular_heatmap` - circular heatmap with grouped sections (probes × samples arranged in circle by sample groups); vector PDF by default, or raster PNG (`outFile` ending in `.png`, or `format = "png"`, `res = 300`) for large cohorts
- `cor_heatmap` - sample-to-sample correlation heatmap
- `rainfall` - chromosomal rainfall plot of probe-level IDI (single sample)
- `radar` - radar plot of ICR-level deviation (single sample): one spoke per curated ICR (median IDI of its probes), in genomic order clockwise from the top, labelled chromosome_annotated parental origin_ICR
- `icr_heatmap` - per-ICR heatmap (samples × ICRs) from the per-ICR calls; needs `runImprintome(icr = TRUE)` (see [Per-ICR scores](analysis.md#per-icr-scores-and-icr-balanced-ids))

ImprintomeSet plots take `plot_type =`; MethQcSet QC plots (Step 1) take `type =`.

Plots coloured by parental origin use the probeset's `ORIGIN` annotation, which states which parental allele is methylated at the ICR; their legend is titled "Annotated parental origin". The colours are annotations, not allele-specific measurements.

## Standard workflow plots

`plot_types = "default"` runs the standard workflow set: `polar`, `beeswarm_origin`, `mirror_density`, `heatmap_by_probe`, `heatmap_by_gene`, `radar`, `beeswarm_chr`, and `rainfall`. `circular_heatmap` is available when requested explicitly, or with `plot_types = "all"`. After `runImprintome(icr = TRUE)`, both sets also include `icr_heatmap`, the per-ICR heatmap.

```r
sample_id1 <- colnames(beta(x))[2]

x <- runImprintomeVisualizations(
  x,
  plot_types = "default",
  probeset = "selected",
  sample_id = sample_id1,
  prefix = "imprintome",
  store_plots = TRUE,
  save_plots = FALSE
)

attr(x, "visualization_manifest")
names(plots(x))
```

Use `save_plots = TRUE` with `outdir = "plots"` to write plot files during generation while storing successful plot objects.

## Example plots

```r
# 1) Auto dispatch (default polar plot from results)
p_auto <- plot(
  x,
  plot_type = "auto",
  result_name = "AnalyzeImprintStatus.selected",
  outFile = "plot_auto.pdf"
)

# 2) Polar plot (IDS vs Angle scatter)
p_polar <- plot(
  x,
  plot_type = "polar",
  result_name = "AnalyzeImprintStatus.selected",
  colorColumn = "Sample_Group",
  outFile = "plot_polar.pdf"
)

# 3) Mirror density (maternal/paternal distributions)
p_mirror <- plot(
  x,
  plot_type = "mirror_density",
  probeset = "selected",
  outFile = "plot_mirror_density.pdf"
)

# 4) Beeswarm (cohort probe methylation)
p_beeswarm <- plot(
  x,
  plot_type = "beeswarm",
  probeset = "selected",
  outFile = "plot_beeswarm.pdf"
)

# 5) Beeswarm by origin (maternal/paternal probes)
p_bee_origin <- plot(
  x,
  plot_type = "beeswarm_origin",
  probeset = "selected",
  outFile = "plot_beeswarm_origin.pdf"
)

# 6) Beeswarm by chromosome (single sample)
sample_id1 <- colnames(beta(x))[1]
p_bee_chr <- plot(
  x,
  plot_type = "beeswarm_chr",
  probeset = "selected",
  sample_id = sample_id1,
  chr = "chr11",
  outFile = paste0("plot_beeswarm_chr_", sample_id1, ".pdf")
)

# 7) Violin plot (methylation distributions by sample)
p_violin <- plot(
  x,
  plot_type = "violin",
  probeset = "selected",
  outFile = "plot_violin.pdf"
)

# 8) Heatmap_by_probe (probes × samples)
p_heatmap <- plot(
  x,
  plot_type = "heatmap_by_probe",
  probeset = "selected",
  outFile = "plot_heatmap.pdf"
)

# 9) Heatmap_by_gene (genes × samples, aggregated by median)
p_heatmap_gene <- plot(
  x,
  plot_type = "heatmap_by_gene",
  probeset = "selected",
  annoColumn = "Sample_Group",
  outFile = "plot_heatmap_by_gene.pdf"
)

# 10) Circular heatmap (grouped by sample group)
p_circle <- plot(
  x,
  plot_type = "circular_heatmap",
  probeset = "selected",
  sectionColumn = "Sample_Group",
  outFile = "plot_circular_heatmap.pdf"   # or "plot_circular_heatmap.png" for a raster image
)

# 11) Correlation heatmap (sample-to-sample)
cor_mat <- plot(
  x,
  plot_type = "cor_heatmap",
  probeset = "selected",
  SAMPLEID = "Sample_Name",
  prefix = "plot"
)

# 12) Rainfall plot (chromosomal distribution, single sample)
p_rainfall <- plot(
  x,
  plot_type = "rainfall",
  sample_id = sample_id1,
  probeset = "selected",
  outFile = paste0("plot_rainfall_", sample_id1, ".pdf")
)

# 13) Radar plot (one spoke per curated ICR, single sample)
p_radar <- plot(
  x,
  plot_type = "radar",
  probeset = "selected",
  sample_id = sample_id1,
  outFile = paste0("plot_radar_", sample_id1, ".pdf")   # figure size grows with the label length
)

# 14) Per-ICR heatmap (samples × ICRs; needs the per-ICR calls from icr = TRUE)
x <- runImprintome(x, probeset = "selected", reference_group = "control", icr = TRUE)
p_icr <- plot(
  x,
  plot_type = "icr_heatmap",
  probeset = "selected",
  outFile = "plot_icr_heatmap.pdf"
)
```
