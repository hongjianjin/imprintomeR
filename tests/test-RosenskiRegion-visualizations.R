test_that("runImprintomeVisualizations uses region-safe default plots for Rosenski_region", {
  probesets <- readRDS(test_path("..", "inst", "extdata", "probesets_hg19.rds"))
  reg <- probesets[["Rosenski_region"]]
  beta_mat <- matrix(
    c(0.45, 0.55, 0.60, 0.50, 0.52, 0.61, 0.47, 0.58, 0.62, 0.49, 0.53, 0.64),
    nrow = 4,
    dimnames = list(reg$NAME[3:6], c("S1", "S2", "S3"))
  )
  meta_df <- data.frame(
    Sample_Name = c("S1", "S2", "S3"),
    Sample_Group = "Test",
    stringsAsFactors = FALSE
  )
  x <- ImprintomeSet(
    beta = beta_mat,
    meta = meta_df,
    probeset = reg,
    genome = "hg19",
    assay = "WGBS"
  )
  x <- runImprintome(x, probeset = "Rosenski_region")

  x <- runImprintomeVisualizations(
    x,
    plot_types = "default",
    probeset = "Rosenski_region",
    result_name = "AnalyzeImprintStatus.Rosenski_region",
    save_plots = FALSE,
    store_plots = FALSE,
    verbose = FALSE
  )

  expect_equal(
    attr(x, "visualization_manifest")$plot_type,
    c("polar", "beeswarm_origin", "heatmap_by_gene", "radar")
  )
})
