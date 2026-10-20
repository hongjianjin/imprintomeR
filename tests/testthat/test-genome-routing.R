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
