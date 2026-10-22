testthat::local_edition(1)

# Genome-aware routing in as.ImprintomeSet(), data-file setup, and removal of
# session-terminating q("no") calls.

.make_methqcset_for_conversion <- function() {
  probes <- readRDS(system.file("extdata", "probesets_hg38.rds", package = "imprintomeR"))[["selected"]]$NAME[1:10]
  meta <- data.frame(Sample_Name = c("S1", "S2"), Sample_Group = c("case", "control"), stringsAsFactors = FALSE)
  beta <- matrix(seq(0.1, 0.9, length.out = 20), nrow = 10, dimnames = list(probes, meta$Sample_Name))
  MethQcSet(meta = meta, platform = "EPIC", beta = beta)
}

test_that("as.ImprintomeSet() defaults to hg38 and loads the hg38 panels", {
  qcset <- .make_methqcset_for_conversion()
  x <- as.ImprintomeSet(qcset)
  expect_equal(x@genome, "hg38")
  expected <- readRDS(system.file("extdata", "probesets_hg38.rds", package = "imprintomeR"))
  expect_equal(names(x@probeset), names(expected))
  expect_identical(x@probeset[["selected"]], expected[["selected"]])
})

test_that("as.ImprintomeSet() loads the hg19 panels when genome = 'hg19'", {
  qcset <- .make_methqcset_for_conversion()
  x <- as.ImprintomeSet(qcset, genome = "HG19")
  expect_equal(x@genome, "hg19")
  expected <- readRDS(system.file("extdata", "probesets_hg19.rds", package = "imprintomeR"))
  expect_identical(x@probeset[["chr11p15"]], expected[["chr11p15"]])
})

test_that("as.ImprintomeSet() keeps a supplied probeset and rejects unknown genomes", {
  qcset <- .make_methqcset_for_conversion()
  custom <- data.frame(NAME = rownames(qcset@beta), ORIGIN = "maternal", stringsAsFactors = FALSE)
  x <- as.ImprintomeSet(qcset, probeset = custom, genome = "hg19")
  expect_identical(x@probeset, custom)
  expect_error(as.ImprintomeSet(qcset, genome = "hg18"))
  expect_error(as.ImprintomeSet(qcset, genome = NA_character_), "genome must be a single character value")
})

test_that("hg38 is the default genome for scoring, subsetting, aggregation and loading", {
  expect_equal(formals(AnalyzeImprintStatus)$genome, "hg38")
  expect_equal(formals(SubsetBeta_By_Probeset)$genome, "hg38")
  expect_equal(formals(AggregateByLocus)$genome, "hg38")
  expect_equal(formals(.load_probesets)$genome, "hg38")
})

test_that("default and hg19 calls read the matching build's probeset file", {
  # Build-specific fixture panels that differ only in CHR, so the result shows
  # which file was read.
  probes <- c("cg1", "cg2", "cg3", "cg4")
  panel_for <- function(chr) data.frame(
    NAME = probes, CHR = chr, MAPINFO = 1:4,
    ORIGIN = c("maternal", "maternal", "paternal", "paternal"),
    Closest_TSS_gene_name = "G1", stringsAsFactors = FALSE
  )
  tmp_wd <- tempfile("imprintome_genome_routing_")
  dir.create(file.path(tmp_wd, "inst", "extdata"), recursive = TRUE)
  saveRDS(list(selected = panel_for("chr1")), file.path(tmp_wd, "inst", "extdata", "probesets_hg19.rds"))
  saveRDS(list(selected = panel_for("chr2")), file.path(tmp_wd, "inst", "extdata", "probesets_hg38.rds"))
  old_wd <- setwd(tmp_wd)
  on.exit(setwd(old_wd), add = TRUE)

  beta <- data.frame(S1 = c(0.1, 0.2, 0.8, 0.9), S2 = c(0.4, 0.5, 0.5, 0.6), row.names = probes)
  expect_true(all(grepl("^chr2_", rownames(AggregateByLocus(beta, probeset = "selected")))))
  expect_true(all(grepl("^chr1_", rownames(AggregateByLocus(beta, probeset = "selected", genome = "hg19")))))

  sub38 <- suppressMessages(capture.output(r38 <- SubsetBeta_By_Probeset(beta, probeset = "selected")))
  sub19 <- suppressMessages(capture.output(r19 <- SubsetBeta_By_Probeset(beta, probeset = "selected", genome = "hg19")))
  expect_equal(unique(r38$probesets$CHR), "chr2")
  expect_equal(unique(r19$probesets$CHR), "chr1")
  expect_error(AggregateByLocus(beta, probeset = "selected", genome = "hg18"))
})

test_that("probeset helpers and plotting helpers read the requested build", {
  probes <- c("cg1", "cg2", "cg3", "cg4")
  panel_for <- function(chr) data.frame(
    NAME = probes, CHR = chr, MAPINFO = 1:4,
    ORIGIN = c("maternal", "maternal", "paternal", "paternal"),
    Closest_TSS_gene_name = "G1", stringsAsFactors = FALSE
  )
  tmp_wd <- tempfile("imprintome_plot_routing_")
  dir.create(file.path(tmp_wd, "inst", "extdata"), recursive = TRUE)
  saveRDS(list(selected = panel_for("chr1")), file.path(tmp_wd, "inst", "extdata", "probesets_hg19.rds"))
  saveRDS(list(selected = panel_for("chr2")), file.path(tmp_wd, "inst", "extdata", "probesets_hg38.rds"))
  old_wd <- setwd(tmp_wd)
  on.exit(setwd(old_wd), add = TRUE)

  expect_equal(unique(.get_probeset("selected")$CHR), "chr2")
  expect_equal(unique(.get_probeset("selected", "hg19")$CHR), "chr1")
  expect_error(.get_probeset("Jima", "hg38"), "Unavailable probeset 'Jima' for genome 'hg38'")

  expect_equal(unique(.imprint_get_probeset_df("selected", "test")$CHR), "chr2")
  expect_equal(unique(.imprint_get_probeset_df("selected", "test", genome = "hg19")$CHR), "chr1")
  beta <- data.frame(S1 = c(0.1, 0.2, 0.8, 0.9), S2 = c(0.4, 0.5, 0.5, 0.6), row.names = probes)
  expect_equal(rownames(.imprint_subset_beta_by_probeset(beta, "selected", "test", genome = "hg19")), probes)
})

test_that("plotting and survey helpers default to hg38 and no code reads the hg19 file directly", {
  for (f in list(BetaHeatmapByGene, BetaCircularHeatmap, PlotRainfall, Survey_Global_Imprinting,
                 Survey_Global_Imprinting_Batch, BetaBeePlot_single_chr, BetaBeePlot_orgin,
                 Beeplot_chr_vs_other_single, .imprint_subset_beta_by_probeset, .imprint_get_probeset_df)) {
    expect_equal(formals(f)$genome, "hg38")
  }
  expect_equal(eval(formals(Calculate_impvar)$genome)[1], "hg38")

  r_dir <- system.file("R", package = "imprintomeR")
  if (!nzchar(r_dir) || !dir.exists(r_dir)) {
    r_dir <- file.path(testthat::test_path("..", ".."), "R")
  }
  skip_if_not(dir.exists(r_dir), "R/ source directory not available")
  hits <- character(0)
  # zzz.R only lists the data files; module_legacy_migrated.R holds unexported, unused legacy code.
  skip_files <- file.path(r_dir, c("zzz.R", "module_legacy_migrated.R"))
  for (f in setdiff(list.files(r_dir, pattern = "[.]R$", full.names = TRUE), skip_files)) {
    code <- sub("#.*$", "", readLines(f, warn = FALSE))
    i <- grep("probesets_hg19[.]rds", code)
    if (length(i)) hits <- c(hits, paste0(basename(f), ":", i))
  }
  expect_equal(hits, character(0))
})

test_that("CLI --genome defaults to hg38", {
  cli <- system.file("scripts", "run_imprintomeR.R", package = "imprintomeR")
  skip_if_not(nzchar(cli) && file.exists(cli), "CLI script not available")
  src <- readLines(cli, warn = FALSE)
  opt <- grep('make_option\\(c\\("--genome"\\)', src, value = TRUE)
  expect_length(opt, 1L)
  expect_true(grepl('default = "hg38"', opt, fixed = TRUE))
})

test_that("setup_imprintome_data() covers both builds and skips files already present", {
  body_text <- paste(deparse(body(setup_imprintome_data)), collapse = "\n")
  expect_true(grepl("raw.githubusercontent.com/hongjianjin/imprintomeR/main/inst/extdata/", body_text, fixed = TRUE))
  for (f in c("anno.uniq_harmonized.liftover.rds", "probesets_hg19.rds", "probesets_hg38.rds")) {
    expect_true(grepl(f, body_text, fixed = TRUE))
    expect_true(nzchar(system.file("extdata", f, package = "imprintomeR")))
  }
  # All files exist, so nothing is downloaded.
  expect_true(suppressMessages(setup_imprintome_data(force = FALSE, verbose = FALSE)))
})

test_that("package code contains no session-terminating q('no') calls", {
  r_dir <- system.file("R", package = "imprintomeR")
  if (!nzchar(r_dir) || !dir.exists(r_dir)) {
    r_dir <- file.path(testthat::test_path("..", ".."), "R")
  }
  skip_if_not(dir.exists(r_dir), "R/ source directory not available")
  hits <- character(0)
  for (f in list.files(r_dir, pattern = "[.]R$", full.names = TRUE)) {
    code <- readLines(f, warn = FALSE)
    code <- sub("#.*$", "", code)
    i <- grep("(^|[^[:alnum:]_.])q\\(\\s*['\"]no['\"]\\s*\\)", code)
    if (length(i)) hits <- c(hits, paste0(basename(f), ":", i))
  }
  expect_equal(hits, character(0))
})

test_that("former q('no') paths now raise catchable errors", {
  probes_all <- data.frame(NAME = "cg00000001", UCSC_REFGENE_GROUP = "TSS200", stringsAsFactors = FALSE)
  expect_error(ExtractProbesByGenelist(genes = NULL, probes.all = probes_all), "must provide a gene list")
})
