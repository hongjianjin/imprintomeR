#' imprintomeR: Imprinting Analysis of DNA Methylation Arrays
#'
#' Quality control, curated imprinting-control-region probesets, sample- and ICR-level imprinting
#' scores and visualizations for Illumina 450K, EPIC and EPICv2 methylation arrays.
#'
#' @keywords internal
#' @importFrom ggplot2 .data aes after_stat annotate coord_flip coord_polar element_blank element_line
#'   element_rect element_text facet_wrap geom_abline geom_boxplot geom_density geom_hline geom_jitter
#'   geom_path geom_point geom_segment geom_text geom_violin geom_vline ggplot ggsave ggtitle guide_legend
#'   guides labs margin scale_color_identity scale_color_manual scale_color_viridis_c scale_fill_manual
#'   scale_shape_manual scale_x_continuous scale_x_discrete scale_y_continuous stat_summary theme theme_bw
#'   theme_classic theme_minimal unit xlim ylim
#' @importFrom ggbeeswarm geom_quasirandom
#' @importFrom ggrepel geom_text_repel
#' @importFrom dplyr %>% any_of arrange case_when filter group_by group_modify if_else inner_join left_join
#'   mutate n pull row_number select slice_max summarise ungroup where
#' @importFrom tidyr pivot_longer
#' @importFrom stringr str_order str_sort
#' @importFrom data.table fread
#' @importFrom reshape2 melt
#' @importFrom pheatmap pheatmap
#' @importFrom ComplexHeatmap draw Heatmap HeatmapAnnotation
#' @importFrom circlize CELL_META circos.clear circos.heatmap circos.heatmap.initialize circos.labels circos.par
#'   circos.segments circos.text circos.track colorRamp2 convert_x get.cell.meta.data get.current.track.index
#' @importFrom Rtsne Rtsne
#' @importFrom openxlsx addWorksheet createStyle createWorkbook getSheetNames loadWorkbook modifyBaseFont
#'   openxlsx_getOp read.xlsx removeWorksheet saveWorkbook setColWidths writeData writeDataTable
#' @importFrom grid gpar grid.draw grid.newpage pushViewport upViewport viewport
#' @importFrom grDevices col2rgb colorRampPalette dev.flush dev.hold dev.interactive dev.off hcl pdf
#' @importFrom graphics abline legend lines matplot mtext pairs par plot.new points polygon rect strheight
#'   strwidth text title
#' @importFrom stats IQR cor density dist hclust mad median na.omit pchisq prcomp predict qchisq reorder sd
#'   setNames var
#' @importFrom utils head read.table write.table
#' @importFrom methods as is
"_PACKAGE"

# Column names used in non-standard evaluation (ggplot2 aesthetics, dplyr verbs).
utils::globalVariables(c(
  ".", "angle", "Angle", "angle_final", "Beta", "beta_val", "CATEGORY", "CHR", "Chromosome", "CpG_Count",
  "CTL_GRP", "CtrlMetrics.QC", "Drift_Distance", "Final.QC", "final_report", "Fit_Score", "Freq", "GROUP",
  "hjust", "ICR", "icr_name", "ID", "IDI", "ids", "IDS", "idx", "ImpVar_Score", "INFO", "label_color",
  "log_pval", "MAPINFO", "mat_cons", "mat_dev", "maternal_median", "Mechanism", "mechanism_idx", "Median_Beta",
  "metric", "mMed.Intensity", "n_mat", "n_pat", "NAME", "Observed_Dev", "ORIGIN", "origin_group", "pat_cons",
  "pat_dev", "paternal_median", "pctDetectedCpG_dP0.05", "predictedSex", "Probe", "Purity", "QC", "raw_mech",
  "Sample", "Sample_Group", "SAMPLE_GROUP", "Sample_Name", "SampleID", "Status", "TargetID", "uMed.Intensity",
  "v", "value", "value_scaled", "variable", "x", "X", "y", "Y", "y_end", "y_start"
))
