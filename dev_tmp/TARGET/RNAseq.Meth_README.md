# RNA-seq and methylation integration

This note records the working commands for generating imprintomeR methylation outputs, matching methylation metadata to RNA-seq metadata, and plotting paired RNA-seq/methylation relationships.

## 1. Run imprintomeR on methylation beta values

Use the matched methylation metadata file as input and generate selected-probeset imprintomeR outputs.

```bash
Rscript /home/hjin/projects/imprintomeR1/dev_tmp/TARGET/run_imprintomeR.R \
  -p TARGET_450K \
  -b platform_450k_beta.txt \
  -m platform_450k_meta_TARGET_matched.txt \
  -o TARGET_450K \
  --probeset selected \
  -v
```

`beeswarm_origin` plots are capped at the first 100 matched samples by default to keep large TARGET cohorts responsive. Override with `--beeswarm-origin-max-samples Inf` to plot all samples or another positive number to set a different cap.

The heatmap-by-gene beta matrix used for RNA-seq integration should be exported as:

```text
TARGET_450K_heatmap_by_gene.selected_beta.txt
```

## 2. Match methylation and RNA-seq metadata

Use `parse_TARGET_meta.R` to append RNA-seq sample IDs and group labels to methylation metadata. For TCGA-style barcodes, `--numElements 3,4` first attempts sample-level matching with 4 hyphen-delimited elements, then falls back to patient-level matching with 3 elements for still-unmatched rows.

For TARGET 450K metadata, use the default TARGET-style 4-element match:

```bash
Rscript parse_TARGET_meta.R \
  --platform-meta platform_450k_meta.txt \
  --target-meta Target_meta_hjin.txt \
  --prefix platform_450k_meta_TARGET \
  --numElements 4
```

For TCGA-style metadata, use staged 4-element then 3-element matching:

```bash
Rscript /home/hjin/projects/imprintomeR1/dev_tmp/TARGET/parse_TARGET_meta.R \
  --platform-meta TCGA_methylation_450K_sample2idat_clean_Id.txt \
  --target-meta TCGA_RNAseq_sample_meta_10406.txt \
  --outdir ./ \
  --prefix TCGA_matched \
  --numElements 3,4
```

Main outputs:

```text
TCGA_matched_merged.txt
TCGA_matched_matched.txt
TCGA_matched_unmatched.txt
```

## 3. Plot RNA-seq expression versus methylation

Use the matched metadata, TPM matrix, and heatmap-by-gene beta matrix to generate scatter plots, gene-ICR correlation summaries, and heatmap/dotplot PDFs.

```bash
Rscript plot_RNAseq_vs_methylation.R \
  --prefix TARGET_450K_selected \
  --meta platform_450k_meta_TARGET_matched.txt \
  --TPM TARGET_all_RSEM_gene_TPM.txt \
  --beta_by_gene TARGET_WT_450K_heatmap_by_gene.selected_beta.txt \
  -o TARGET_450K
```

Main outputs:

```text
TARGET_450K_selected_TPM_subset.txt
TARGET_450K_selected_RNAseq_vs_meth_pairs.txt
TARGET_450K_selected_RNAseq_vs_meth_scatter.pdf
TARGET_450K_selected_gene_ICR_expression_methylation_matrix.txt
TARGET_450K_selected_gene_ICR_correlation_summary.txt
TARGET_450K_selected_gene_ICR_expression_methylation_heatmap.pdf
TARGET_450K_selected_gene_ICR_correlation_dotplot.pdf
```

