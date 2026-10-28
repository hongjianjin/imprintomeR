# Per-ICR deviations (AnalyzeICRStatus), the multi-locus summary (SummarizeICRStatus), the
# ICR-balanced sample-level IDS (AnalyzeImprintStatus(balance = "icr")) and runImprintome(icr = TRUE).

.with_icr_panel <- function(probeset_df, code) {
  old_wd <- getwd()
  tmp_wd <- tempfile("imprintome_icr_")
  dir.create(file.path(tmp_wd, "inst", "extdata"), recursive = TRUE)
  for (g in c("hg19", "hg38")) {
    saveRDS(list(selected = probeset_df), file.path(tmp_wd, "inst", "extdata", paste0("probesets_", g, ".rds")))
  }
  setwd(tmp_wd)
  on.exit(setwd(old_wd), add = TRUE)
  force(code)
}

# Maternal ICRs: matA (chr1, 5 probes), matB (chr2, 3 probes), matC (chr3, 2 probes, below
# min_probes); paternal ICR patP (chr11, 4 probes); one maternal probe outside any ICR.
# Five controls near 0.5; X1 loses methylation at matA, X2 loses at matA and gains at matB
# (two chromosomes), X3 gains at patP.
.make_icr_fixture <- function() {
  icr <- c(rep("matA", 5), rep("matB", 3), rep("matC", 2), rep("patP", 4), NA)
  probeset <- data.frame(
    NAME = sprintf("cg%08d", seq_along(icr)),
    CHR = c(rep("chr1", 5), rep("chr2", 3), rep("chr3", 2), rep("chr11", 4), "chr4"),
    MAPINFO = seq_along(icr) * 100,
    ORIGIN = c(rep("maternal", 10), rep("paternal", 4), "maternal"),
    ICR_name = icr,
    DMR_type = c(rep("gametic", 14), "uncurated"),
    stringsAsFactors = FALSE
  )
  set.seed(11)
  base <- matrix(0.5 + rnorm(length(icr) * 8, 0, 0.01), nrow = length(icr),
                 dimnames = list(probeset$NAME, c(paste0("C", 1:5), "X1", "X2", "X3")))
  base[icr %in% "matA", c("X1", "X2")] <- base[icr %in% "matA", c("X1", "X2")] - 0.3
  base[icr %in% "matB", "X2"] <- base[icr %in% "matB", "X2"] + 0.3
  base[icr %in% "patP", "X3"] <- base[icr %in% "patP", "X3"] + 0.35
  meta <- data.frame(Sample_Name = colnames(base), Sample_Group = c(rep("control", 5), "case", "case", "case"),
                     stringsAsFactors = FALSE)
  list(beta = data.frame(TargetID = rownames(base), base, check.names = FALSE), matrix = base, meta = meta, probeset = probeset)
}

.quiet <- function(expr) { out <- NULL; invisible(utils::capture.output(out <- expr)); out }

test_that("AnalyzeICRStatus scores each ICR with enough probes", {
  d <- .make_icr_fixture()
  .with_icr_panel(d$probeset, {
    res <- .quiet(AnalyzeICRStatus(d$beta, d$meta, probeset = "selected", reference = "fixed"))
    expect_setequal(unique(res$ICR_name), c("matA", "matB", "patP"))   # matC has 2 probes
    expect_equal(nrow(res), 8 * 3)
    r <- res[res$Sample_Name == "X1" & res$ICR_name == "matA", ]
    expect_equal(r$deviation, round(median(d$matrix[d$probeset$ICR_name %in% "matA", "X1"]) - 0.5, 3))
    expect_equal(r$n_probes, 5)
    expect_equal(r$direction, "loss")
    expect_equal(r$ORIGIN, "maternal")
    expect_true(all(is.na(res$z)))                                  # no controls given
    expect_equal(sort(unique(res$Sample_Name[res$altered])), c("X1", "X2", "X3"))
    expect_equal(attr(res, "icr_settings")$delta_cutoff, 0.075)
    expect_equal(attr(res, "icr_settings")$z_cutoff, 3)
    expect_equal(nrow(.quiet(AnalyzeICRStatus(d$beta, d$meta, probeset = "selected", min_probes = 2))) / 8, 4)
  })
})

test_that("control z-scores gate altered calls", {
  d <- .make_icr_fixture()
  d$matrix[d$probeset$ICR_name %in% "matB", "X1"] <- d$matrix[d$probeset$ICR_name %in% "matB", "X1"] + 0.2
  d$beta <- data.frame(TargetID = rownames(d$matrix), d$matrix, check.names = FALSE)
  .with_icr_panel(d$probeset, {
    res <- .quiet(suppressWarnings(AnalyzeICRStatus(d$beta, d$meta, probeset = "selected", reference_group = "control")))
    expect_false(anyNA(res$z))
    expect_true(all(!res$altered[res$Sample_Group == "control"]))
    x1b <- res[res$Sample_Name == "X1" & res$ICR_name == "matB", ]
    expect_true(x1b$abs_deviation >= 0.075 && abs(x1b$z) >= 3 && x1b$altered)
    no_z <- .quiet(suppressWarnings(AnalyzeICRStatus(d$beta, d$meta, probeset = "selected", reference_group = "control",
                                                    z_cutoff = NULL)))
    expect_true(all(no_z$altered[res$altered]))
    expect_true(is.na(attr(no_z, "icr_settings")$z_cutoff))
    strict <- .quiet(suppressWarnings(AnalyzeICRStatus(d$beta, d$meta, probeset = "selected", reference_group = "control",
                                                      z_cutoff = 1e6)))
    expect_false(any(strict$altered))
    expect_equal(attr(res, "icr_settings")$n_controls, 5)
  })
})

test_that("SummarizeICRStatus counts altered ICRs and flags multi-locus disturbance", {
  d <- .make_icr_fixture()
  .with_icr_panel(d$probeset, {
    res <- .quiet(AnalyzeICRStatus(d$beta, d$meta, probeset = "selected", reference = "fixed"))
    s <- SummarizeICRStatus(res)
    rownames(s) <- s$Sample_Name
    expect_equal(s["X1", "n_altered"], 1)
    expect_equal(s["X2", "n_altered"], 2)
    expect_equal(s["X2", c("n_gain", "n_loss")], data.frame(n_gain = 1L, n_loss = 1L, row.names = "X2"))
    expect_equal(s$MLID, c(rep(FALSE, 5), FALSE, TRUE, FALSE))
    expect_match(s["X2", "altered_icrs"], "matA \\(-")
    expect_false(SummarizeICRStatus(res, min_chromosomes = 3)["X2" == s$Sample_Name, "MLID"])
    expect_error(SummarizeICRStatus(data.frame(a = 1)), "output of AnalyzeICRStatus")
  })
})

test_that("ICR-balanced IDS weights each ICR once", {
  d <- .make_icr_fixture()
  .with_icr_panel(d$probeset, {
    probe <- .quiet(AnalyzeImprintStatus(d$beta, d$meta, probeset = "selected", reference = "fixed"))
    icr <- .quiet(AnalyzeImprintStatus(d$beta, d$meta, probeset = "selected", reference = "fixed", balance = "icr"))
    rownames(icr) <- icr$Sample_Name
    rownames(probe) <- probe$Sample_Name
    expect_equal(unique(icr$balance), "icr")
    expect_equal(unique(icr$n_maternal_icrs), 2)   # matA, matB (matC below min_probes, NA probe ignored)
    expect_equal(unique(icr$n_paternal_icrs), 1)
    expect_false(any(c("n_paternal_icrs", "n_maternal_icrs") %in% colnames(probe)))   # probe pooling: no ICR counts
    m <- d$matrix
    devA <- median(m[d$probeset$ICR_name %in% "matA", "X1"]) - 0.5
    devB <- median(m[d$probeset$ICR_name %in% "matB", "X1"]) - 0.5
    expect_equal(icr["X1", "maternal_deviation"], round(median(c(devA, devB)), 3))
    expect_false(isTRUE(all.equal(icr["X1", "maternal_deviation"], probe["X1", "maternal_deviation"])))
    expect_error(.quiet(AnalyzeImprintStatus(d$beta, d$meta, probeset = "selected", balance = "icr", infinium_type = "balanced")),
                 "cannot be combined")
    expect_error(.quiet(AnalyzeImprintStatus(d$beta, d$meta, probeset = "selected", balance = "icr", min_probes = 10)),
                 "no maternal or no paternal ICR")
  })
})

test_that("per-ICR scoring needs ICR annotation", {
  d <- .make_icr_fixture()
  .with_icr_panel(d$probeset[, setdiff(colnames(d$probeset), "ICR_name")], {
    expect_error(.quiet(AnalyzeICRStatus(d$beta, d$meta, probeset = "selected")), "no ICR_name column")
    expect_error(.quiet(AnalyzeImprintStatus(d$beta, d$meta, probeset = "selected", balance = "icr", dmr_type = "all")),
                 "no ICR_name column")
  })
})

test_that("runImprintome stores per-ICR tables and ICR-balanced results", {
  d <- .make_icr_fixture()
  .with_icr_panel(d$probeset, {
    x <- ImprintomeSet(beta = d$matrix, meta = d$meta, probeset = d$probeset, genome = "hg38", assay = "EPICv1")
    x <- .quiet(suppressWarnings(runImprintome(x, probeset = "selected", balance = "icr", icr = TRUE)))
    expect_true(all(c("AnalyzeImprintStatus.selected.icr", "ICRStatus.selected", "ICRSummary.selected") %in% names(results(x))))
    expect_equal(nrow(results(x)[["ICRSummary.selected"]]), 8)
    p <- PlotICRHeatmap(results(x)[["ICRStatus.selected"]])
    expect_true(inherits(p, "ggplot"))
  })
})

test_that("SummarizeICRStatus leaves polymorphic VTRNA2-1 out of the counts by default", {
  tab <- data.frame(Sample_Name = "S1", Sample_Group = "case", ICR_name = c("VTRNA2-1:DMR", "matA"), CHR = c("chr5", "chr1"),
                    deviation = c(-0.4, -0.3), altered = TRUE, DMR_type = "gametic", stringsAsFactors = FALSE)
  expect_equal(SummarizeICRStatus(tab)$n_altered, 1)
  expect_false(SummarizeICRStatus(tab)$MLID)
  expect_true(SummarizeICRStatus(tab, exclude_icrs = NULL)$MLID)
})

test_that("dmr_type restricts per-ICR scores and the multi-locus summary", {
  d <- .make_icr_fixture()
  d$probeset$DMR_type[d$probeset$ICR_name %in% "matB"] <- "secondary"
  .with_icr_panel(d$probeset, {
    all_icrs <- .quiet(AnalyzeICRStatus(d$beta, d$meta, probeset = "selected", reference = "fixed"))
    expect_setequal(unique(all_icrs$ICR_name), c("matA", "matB", "patP"))   # default scores every ICR
    expect_equal(unique(all_icrs$DMR_type[all_icrs$ICR_name == "matB"]), "secondary")
    expect_equal(.quiet(AnalyzeICRStatus(d$beta, d$meta, probeset = "selected", reference = "fixed", dmr_type = "all")),
                 all_icrs)

    gametic <- .quiet(AnalyzeICRStatus(d$beta, d$meta, probeset = "selected", reference = "fixed", dmr_type = "gametic"))
    expect_setequal(unique(gametic$ICR_name), c("matA", "patP"))
    expect_true(all(gametic$DMR_type == "gametic"))
    key <- c("Sample_Name", "ICR_name", "deviation", "altered")
    expect_equal(gametic[, key], all_icrs[all_icrs$ICR_name != "matB", key], ignore_attr = TRUE)  # each ICR scored on its own

    # X2 is altered at matA (chr1) and secondary matB (chr2): multi-locus only when matB is counted.
    s_all <- SummarizeICRStatus(all_icrs)
    s_gam <- SummarizeICRStatus(all_icrs, dmr_type = "gametic")
    expect_equal(s_all$n_altered[s_all$Sample_Name == "X2"], 2)
    expect_true(s_all$MLID[s_all$Sample_Name == "X2"])
    expect_equal(s_gam$n_altered[s_gam$Sample_Name == "X2"], 1)
    expect_false(s_gam$MLID[s_gam$Sample_Name == "X2"])
    expect_equal(SummarizeICRStatus(gametic)[, c("n_altered", "MLID")], s_gam[, c("n_altered", "MLID")], ignore_attr = TRUE)
  })
  no_type <- d$probeset[, setdiff(colnames(d$probeset), "DMR_type")]
  .with_icr_panel(no_type, {
    expect_error(.quiet(AnalyzeICRStatus(d$beta, d$meta, probeset = "selected", dmr_type = "gametic")),
                 "no DMR_type column")
  })
})

test_that("icr_heatmap plot type draws the stored per-ICR table", {
  d <- .make_icr_fixture()
  .with_icr_panel(d$probeset, {
    x0 <- ImprintomeSet(beta = d$matrix, meta = d$meta, probeset = d$probeset, genome = "hg38", assay = "EPICv1")
    expect_error(plot(x0, plot_type = "icr_heatmap"), "icr = TRUE")
    x <- .quiet(suppressWarnings(runImprintome(x0, probeset = "selected", icr = TRUE)))

    p <- plot(x, plot_type = "icr_heatmap")
    expect_true(inherits(p, "ggplot"))
    expect_equal(p$labels$title, "Per-ICR deviation")
    # Colour bar of annotated parental origin, with its own legend
    expect_equal(p$scales$get_scales("colour")$name, "Annotated parental origin")
    bar <- ggplot2::layer_data(p, 3)
    expect_setequal(unique(bar$fill), unname(imprintomeR:::.imprint_origin_colors()[c("maternal", "paternal")]))
    expect_setequal(unique(as.character(p$data$ICR_name)), unique(results(x)[["ICRStatus.selected"]]$ICR_name))
    f <- tempfile(fileext = ".pdf")
    plot(x, plot_type = "icr_heatmap", outFile = f, title = "ICRs")
    expect_true(file.exists(f) && file.info(f)$size > 0)

    v <- runImprintomeVisualizations(x, plot_types = "icr_heatmap", verbose = FALSE)
    expect_true(inherits(plots(v)[["icr_heatmap.selected"]], "ggplot"))
    expect_equal(attr(v, "visualization_manifest")$status, "stored")

    # Included in the default set only when the per-ICR table is present.
    with_icr <- suppressWarnings(runImprintomeVisualizations(x, store_plots = FALSE, verbose = FALSE))
    without <- suppressWarnings(runImprintomeVisualizations(x0, store_plots = FALSE, verbose = FALSE))
    expect_true("icr_heatmap" %in% attr(with_icr, "visualization_manifest")$plot_type)
    expect_false("icr_heatmap" %in% attr(without, "visualization_manifest")$plot_type)
  })
})
