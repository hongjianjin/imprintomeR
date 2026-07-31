testthat::local_edition(1)

# Allow running this file via testthat::test_file() when package is not preloaded.
.find_imprintomer_root_plot <- function() {
  required_rel <- c(
    file.path("R", "module_io.R"),
    file.path("R", "module_utilities.R"),
    file.path("R", "module_probeset.R"),
    file.path("R", "module_scoring.R"),
    file.path("R", "module_plotting.R"),
    file.path("R", "module_aggregation.R"),
    file.path("R", "ImprintomeSet-class.R"),
    file.path("R", "ImprintomeSet-accessors.R"),
    file.path("R", "ImprintomeSet-run.R"),
    file.path("R", "ImprintomeSet-plot.R"),
    file.path("R", "ImprintomeSet-visualizations.R")
  )

  has_required <- function(root) {
    if (is.null(root) || !nzchar(root)) return(FALSE)
    all(vapply(required_rel, function(p) file.exists(file.path(root, p)), logical(1)))
  }

  env_root <- Sys.getenv("TESTTHAT_PKG", unset = "")
  if (has_required(env_root)) {
    return(normalizePath(env_root, winslash = "/", mustWork = TRUE))
  }

  cur <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
  repeat {
    if (has_required(cur)) return(cur)
    parent <- dirname(cur)
    if (identical(parent, cur)) break
    cur <- parent
  }

  ""
}

.load_local_imprintomer_plot_code <- function() {
  .source_r_file_safely <- function(path) {
    txt <- readLines(path, warn = FALSE, encoding = "UTF-8")
    if (length(txt) > 0L) {
      txt[1] <- sub("^\ufeff", "", txt[1])
    }
    expr <- parse(text = txt, keep.source = FALSE)
    eval(expr, envir = .GlobalEnv)
    invisible(TRUE)
  }

  if (exists("ImprintomeSet", mode = "function", inherits = TRUE) &&
      exists("runImprintome", mode = "function", inherits = TRUE) &&
      exists("plot", mode = "function", inherits = TRUE)) {
    return(invisible(TRUE))
  }

  pkg_root <- .find_imprintomer_root_plot()
  if (!nzchar(pkg_root)) {
    stop("Could not locate package root containing required R/ source files.")
  }

  r_files <- c(
    file.path(pkg_root, "R", "module_io.R"),
    file.path(pkg_root, "R", "module_utilities.R"),
    file.path(pkg_root, "R", "module_probeset.R"),
    file.path(pkg_root, "R", "module_scoring.R"),
    file.path(pkg_root, "R", "module_aggregation.R"),
    file.path(pkg_root, "R", "module_plotting.R"),
    file.path(pkg_root, "R", "ImprintomeSet-class.R"),
    file.path(pkg_root, "R", "ImprintomeSet-accessors.R"),
    file.path(pkg_root, "R", "ImprintomeSet-run.R"),
    file.path(pkg_root, "R", "ImprintomeSet-plot.R"),
    file.path(pkg_root, "R", "ImprintomeSet-visualizations.R")
  )

  for (f in r_files) {
    .source_r_file_safely(f)
  }
  invisible(TRUE)
}

.load_local_imprintomer_plot_code()

.make_plot_fixture <- function() {
  probes <- c("cg00000001", "cg00000002", "cg00000003", "cg00000004", "cg00000005")

  beta <- data.frame(
    NAME = probes,
    S1 = c(0.30, 0.35, 0.70, 0.68, 0.55),
    S2 = c(0.40, 0.45, 0.62, 0.60, 0.50),
    S3 = c(0.52, 0.49, 0.51, 0.48, 0.53),
    stringsAsFactors = FALSE
  )
  rownames(beta) <- beta$NAME

  meta <- data.frame(
    Sample_Name = c("S1", "S2", "S3"),
    Sample_Group = c("case", "case", "control"),
    stringsAsFactors = FALSE
  )
  rownames(meta) <- meta$Sample_Name

  probeset <- data.frame(
    NAME = probes,
    CHR = rep("chr11", 5),
    MAPINFO = 10001:10005,
    ORIGIN = c("maternal", "maternal", "paternal", "paternal", NA),
    Closest_TSS_gene_name = rep("GENE1", 5),
    stringsAsFactors = FALSE
  )
  rownames(probeset) <- probeset$NAME

  list(beta = beta, meta = meta, probeset = probeset)
}

.with_plot_fixture_files <- function(code) {
  old_wd <- getwd()
  tmp_wd <- file.path(tempdir(), paste0("imprintome_plot_test_", as.integer(Sys.time()), "_", sample.int(100000, 1)))
  dir.create(file.path(tmp_wd, "inst", "extdata"), recursive = TRUE, showWarnings = FALSE)

  d <- .make_plot_fixture()
  saveRDS(list(selected = d$probeset, NanoImprint = d$probeset),
          file.path(tmp_wd, "inst", "extdata", "probesets_hg19.rds"))

  setwd(tmp_wd)
  on.exit(setwd(old_wd), add = TRUE)
  force(code)
}

.make_imprintomeset <- function() {
  d <- .make_plot_fixture()
  ImprintomeSet(
    beta = d$beta,
    meta = d$meta,
    probeset = d$probeset,
    genome = "hg19",
    assay = "EPICv1"
  )
}

testthat::test_that("plot(auto) prefers stored plots", {
  testthat::skip_if_not_installed("ggplot2")
  .with_plot_fixture_files({
    x <- .make_imprintomeset()
    p0 <- ggplot2::ggplot(data.frame(x = 1, y = 1), ggplot2::aes(x, y)) + ggplot2::geom_point()
    p_list <- plots(x)
    p_list[["stored.plot"]] <- p0
    plots(x) <- p_list

    p <- plot(x, plot_type = "auto")
    testthat::expect_s3_class(p, "ggplot")
  })
})

testthat::test_that("plot(auto) falls back to polar from IDS/Angle results", {
  testthat::skip_if_not_installed("ggplot2")
  .with_plot_fixture_files({
    x <- .make_imprintomeset()
    x <- runImprintome(x, probeset = "selected", ids_cutoff = 0.2)

    p <- plot(x, plot_type = "auto", result_name = "AnalyzeImprintStatus.selected")
    testthat::expect_s3_class(p, "ggplot")
  })
})

testthat::test_that("plot supports explicit plot_type dispatch", {
  testthat::skip_if_not_installed("ggplot2")
  .with_plot_fixture_files({
    x <- .make_imprintomeset()
    x <- runImprintome(x, probeset = "selected", ids_cutoff = 0.2)

    p_polar <- plot(x, plot_type = "polar", result_name = "AnalyzeImprintStatus.selected")
    testthat::expect_s3_class(p_polar, "ggplot")

    p_violin <- plot(x, plot_type = "violin", SAMPLEID = "Sample_Name")
    testthat::expect_s3_class(p_violin, "ggplot")

    p_origin <- plot(x, plot_type = "beeswarm_origin", probeset = "selected", SAMPLEID = "Sample_Name")
    testthat::expect_s3_class(p_origin, "ggplot")
    testthat::expect_equal(p_origin$scales$get_scales("colour")$name, "Allelic origin")

    sid <- setdiff(colnames(beta(x)), "NAME")[1]
    p_chr <- plot(x, plot_type = "beeswarm_chr", probeset = "selected", sample_id = sid, chr = "chr11")
    testthat::expect_s3_class(p_chr, "ggplot")
    testthat::expect_true(grepl(paste0("Sample: ", sid), p_chr$labels$subtitle, fixed = TRUE))
    testthat::expect_true(grepl("Chromosome: chr11", p_chr$labels$subtitle, fixed = TRUE))
    testthat::expect_s3_class(p_chr$facet, "FacetWrap")
    testthat::expect_equal(p_chr$labels$x, "Chromosome")
    testthat::expect_false(inherits(p_chr$theme$panel.border, "element_blank"))
    testthat::expect_equal(p_chr$theme$legend.position, "right")
    testthat::expect_equal(length(p_chr$layers), 3L)

    p_rain <- plot(x, plot_type = "rainfall", sample_id = sid)
    testthat::expect_s3_class(p_rain, "ggplot")
    testthat::expect_true(grepl(paste0("Sample: ", sid), p_rain$labels$subtitle, fixed = TRUE))
    testthat::expect_true(grepl("IDI", p_rain$labels$y, fixed = TRUE))
    testthat::expect_equal(p_rain$scales$get_scales("y")$limits, c(-1, 1))
    testthat::expect_equal(p_rain$scales$get_scales("colour")$name, "Allelic origin")

    p_radar <- testthat::expect_warning(
      plot(x, plot_type = "radar", sample_id = sid, probeset = "selected"),
      NA
    )
    testthat::expect_s3_class(p_radar, "ggplot")
    testthat::expect_true(grepl(paste0("Sample: ", sid), p_radar$labels$subtitle, fixed = TRUE))
    testthat::expect_equal(p_radar$scales$get_scales("colour")$name, "Allelic origin")
  })
})

testthat::test_that("plot errors on unsupported plot_type", {
  .with_plot_fixture_files({
    x <- .make_imprintomeset()
    testthat::expect_error(plot(x, plot_type = "not_a_plot"), "Unsupported plot_type")
  })
})

testthat::test_that("beeswarm_chr retains chromosomes with at least five usable probes", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("ggbeeswarm")

  probes <- sprintf("cg%08d", seq_len(9))
  beta_x <- data.frame(S1 = seq(0.1, 0.9, length.out = 9), row.names = probes)
  meta_x <- data.frame(Sample_Name = "S1", row.names = "S1")
  probeset <- data.frame(
    NAME = probes,
    CHR = c(rep("chr1", 4), rep("chr2", 5)),
    ORIGIN = rep(c("maternal", "paternal"), length.out = 9),
    stringsAsFactors = FALSE
  )

  old_get_probeset <- .imprint_get_probeset_df
  assign(".imprint_get_probeset_df", function(...) probeset, envir = .GlobalEnv)
  on.exit(assign(".imprint_get_probeset_df", old_get_probeset, envir = .GlobalEnv), add = TRUE)

  p <- .imprint_beeswarm_chr(
    beta_x, meta_x, SAMPLEID = "Sample_Name", probeset_name = "threshold", sample_id = "S1"
  )
  testthat::expect_equal(levels(p$data$Chromosome), "chr2")
  testthat::expect_equal(nrow(p$data), 5L)

  testthat::expect_error(
    .imprint_beeswarm_chr(
      beta_x, meta_x, SAMPLEID = "Sample_Name", probeset_name = "threshold",
      sample_id = "S1", chr = "chr1"
    ),
    "requires at least 5 usable probes per chromosome"
  )
})

testthat::test_that("runImprintomeVisualizations stores successful plots", {
  testthat::skip_if_not_installed("ggplot2")
  .with_plot_fixture_files({
    x <- .make_imprintomeset()
    x <- runImprintome(x, probeset = "selected", ids_cutoff = 0.2)

    x <- runImprintomeVisualizations(
      x,
      plot_types = c("polar"),
      probeset = "selected",
      prefix = "demo",
      verbose = FALSE
    )

    testthat::expect_s4_class(x, "ImprintomeSet")
    testthat::expect_true("polar.selected" %in% names(plots(x)))
    testthat::expect_s3_class(plots(x)[["polar.selected"]], "ggplot")

    manifest <- attr(x, "visualization_manifest")
    testthat::expect_true(is.data.frame(manifest))
    testthat::expect_equal(manifest$status[1], "stored")
  })
})

testthat::test_that("runImprintomeVisualizations retains old-style plot filenames", {
  testthat::skip_if_not_installed("ggplot2")
  .with_plot_fixture_files({
    x <- .make_imprintomeset()
    x <- runImprintome(x, probeset = "selected", ids_cutoff = 0.2)
    outdir <- tempfile("imprintome-plots-")
    dir.create(outdir)

    x <- runImprintomeVisualizations(
      x,
      plot_types = "polar",
      probeset = "selected",
      prefix = "GSE237503_hg19",
      outdir = outdir,
      save_plots = TRUE,
      store_plots = FALSE,
      verbose = FALSE
    )

    manifest <- attr(x, "visualization_manifest")
    testthat::expect_equal(
      basename(manifest$file[1]), "GSE237503_hg19_polar.selected.pdf"
    )
    testthat::expect_true(file.exists(manifest$file[1]))
  })
})

testthat::test_that("beeswarm_chr filename includes probeset and sample", {
  testthat::skip_if_not_installed("ggplot2")
  .with_plot_fixture_files({
    x <- .make_imprintomeset()
    x <- runImprintome(x, probeset = "selected", ids_cutoff = 0.2)
    outdir <- tempfile("imprintome-beeswarm-chr-")
    dir.create(outdir)
    on.exit(unlink(outdir, recursive = TRUE, force = TRUE), add = TRUE)
    sid <- colnames(beta(x))[1]

    x <- runImprintomeVisualizations(
      x,
      plot_types = "beeswarm_chr",
      probeset = "selected",
      sample_id = sid,
      prefix = "GSE166531_hg19",
      outdir = outdir,
      save_plots = TRUE,
      store_plots = FALSE,
      verbose = FALSE
    )

    manifest <- attr(x, "visualization_manifest")
    testthat::expect_equal(manifest$status[1], "saved")
    testthat::expect_equal(
      basename(manifest$file[1]),
      paste0("GSE166531_hg19_beeswarm_chr.selected.", sid, ".pdf")
    )
    testthat::expect_true(file.exists(manifest$file[1]))
  })
})

.run_imprintome_cli_script <- file.path(.find_imprintomer_root_plot(), "inst", "scripts", "run_imprintomeR.R")

.load_run_imprintome_cli_function <- function(function_name) {
  script <- .run_imprintome_cli_script
  exprs <- parse(file = script, keep.source = FALSE)
  matches <- vapply(exprs, function(expr) {
    is.call(expr) && identical(as.character(expr[[1]]), "<-") &&
      identical(as.character(expr[[2]]), function_name)
  }, logical(1))
  testthat::expect_equal(sum(matches), 1L)
  eval(exprs[[which(matches)]], envir = .GlobalEnv)
  get(function_name, envir = .GlobalEnv, inherits = FALSE)
}

testthat::test_that("radar-all writes one multipage PDF", {
  testthat::skip_if_not_installed("ggplot2")
  .with_plot_fixture_files({
    x <- .make_imprintomeset()
    x <- runImprintome(x, probeset = "selected", ids_cutoff = 0.2)
    radar_all <- .load_run_imprintome_cli_function(".generate_all_radar_plots")
    outdir <- tempfile("imprintome-radar-all-")
    dir.create(outdir)
    on.exit(unlink(outdir, recursive = TRUE, force = TRUE), add = TRUE)

    manifest <- radar_all(
      x, probeset = "selected", outdir = outdir, prefix = "GSE237503_hg19"
    )

    testthat::expect_equal(nrow(manifest), ncol(beta(x)))
    testthat::expect_true(all(manifest$status == "saved"))
    testthat::expect_length(unique(manifest$file), 1L)
    testthat::expect_equal(
      basename(unique(manifest$file)),
      "GSE237503_hg19_radar.selected.all.pdf"
    )
    testthat::expect_true(file.exists(unique(manifest$file)))
  })
})

testthat::test_that("radar-all removes the ordinary single-sample radar", {
  without_radar <- .load_run_imprintome_cli_function(".plot_types_without_single_radar")
  testthat::expect_false("radar" %in% without_radar("default"))
  testthat::expect_false("radar" %in% without_radar("all"))
  testthat::expect_equal(without_radar(c("polar", "radar")), "polar")
})

testthat::test_that("beeswarm-chr-all writes one multipage PDF", {
  testthat::skip_if_not_installed("ggplot2")
  .with_plot_fixture_files({
    x <- .make_imprintomeset()
    x <- runImprintome(x, probeset = "selected", ids_cutoff = 0.2)
    beeswarm_all <- .load_run_imprintome_cli_function(".generate_all_beeswarm_chr_plots")
    outdir <- tempfile("imprintome-beeswarm-chr-all-")
    dir.create(outdir)
    on.exit(unlink(outdir, recursive = TRUE, force = TRUE), add = TRUE)

    manifest <- beeswarm_all(
      x,
      probeset = "selected",
      outdir = outdir,
      prefix = "GSE166531_hg19"
    )

    testthat::expect_equal(nrow(manifest), ncol(beta(x)))
    testthat::expect_true(all(manifest$status == "saved"))
    testthat::expect_length(unique(manifest$file), 1L)
    testthat::expect_equal(
      basename(unique(manifest$file)),
      "GSE166531_hg19_beeswarm_chr.selected.all.pdf"
    )
    testthat::expect_true(file.exists(unique(manifest$file)))
  })
})

testthat::test_that("beeswarm-chr-all removes the ordinary single-sample plot", {
  without_beeswarm <- .load_run_imprintome_cli_function(".plot_types_without_single_beeswarm_chr")
  testthat::expect_false("beeswarm_chr" %in% without_beeswarm("default"))
  testthat::expect_false("beeswarm_chr" %in% without_beeswarm("all"))
  testthat::expect_equal(without_beeswarm(c("polar", "beeswarm_chr")), "polar")
})
