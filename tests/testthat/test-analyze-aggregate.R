testthat::local_edition(1)

# HPC compatibility: some testthat/waldo stacks fail while loading waldo due to
# compare_proxy registration mismatches. Patch testthat comparator to a minimal
# base fallback for this file.
.needs_testthat_waldo_patch <- function() {
  force_patch <- identical(Sys.getenv("IMPRINTOMER_FORCE_WALDO_PATCH", unset = "0"), "1")
  if (force_patch) {
    return(TRUE)
  }

  cmp <- NULL
  ok <- FALSE
  try({
    cmp <- getFromNamespace("waldo_compare", "testthat")
    ok <- TRUE
  }, silent = TRUE)
  if (!ok || is.null(cmp)) {
    return(TRUE)
  }

  needs_patch <- FALSE
  tryCatch(
    {
      cmp(TRUE, TRUE, x_arg = "x", y_arg = "y")
      needs_patch <- FALSE
    },
    error = function(e) {
      msg <- conditionMessage(e)
      needs_patch <<- grepl("compare_proxy", msg, fixed = TRUE)
    }
  )
  needs_patch
}

.patch_testthat_waldo <- function() {
  if (!requireNamespace("testthat", quietly = TRUE)) {
    return(invisible(FALSE))
  }

  if (!.needs_testthat_waldo_patch()) {
    return(invisible(FALSE))
  }

  fallback <- function(x, y, x_arg = "x", y_arg = "y", ...) {
    if (isTRUE(all.equal(x, y, check.attributes = FALSE))) {
      character(0)
    } else {
      c("Objects differ (base all.equal fallback).")
    }
  }

  ok <- FALSE
  try({
    assignInNamespace("waldo_compare", fallback, ns = "testthat")
    ok <- TRUE
  }, silent = TRUE)
  invisible(ok)
}

.patch_testthat_waldo()

.find_pkg_root_minimal <- function() {
  required_rel <- c(
    file.path("R", "module_io.R"),
    file.path("R", "module_probeset.R"),
    file.path("R", "module_scoring.R"),
    file.path("R", "module_aggregation.R")
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

.load_minimal_modules <- function() {
  if (exists("AnalyzeImprintStatus", mode = "function", inherits = TRUE) &&
      exists("AggregateByLocus", mode = "function", inherits = TRUE)) {
    return(invisible(TRUE))
  }

  pkg_root <- .find_pkg_root_minimal()
  if (!nzchar(pkg_root)) {
    stop("Could not locate package root for module loading.")
  }

  source(file.path(pkg_root, "R", "module_io.R"), local = FALSE)
  source(file.path(pkg_root, "R", "module_probeset.R"), local = FALSE)
  source(file.path(pkg_root, "R", "module_scoring.R"), local = FALSE)
  source(file.path(pkg_root, "R", "module_aggregation.R"), local = FALSE)

  invisible(TRUE)
}

.with_temp_probeset_file <- function(probeset_df, code) {
  old_wd <- getwd()
  tmp_wd <- file.path(tempdir(), paste0("imprintome_test_", as.integer(Sys.time()), "_", sample.int(100000, 1)))
  dir.create(file.path(tmp_wd, "inst", "extdata"), recursive = TRUE, showWarnings = FALSE)
  # Same synthetic panel for both builds, so default (hg38) and hg19 calls see it.
  for (g in c("hg19", "hg38")) {
    saveRDS(list(selected = probeset_df), file.path(tmp_wd, "inst", "extdata", paste0("probesets_", g, ".rds")))
  }

  setwd(tmp_wd)
  on.exit(setwd(old_wd), add = TRUE)
  force(code)
}

.make_fixture <- function() {
  probes <- c("cg00000001", "cg00000002", "cg00000003", "cg00000004")

  beta <- data.frame(
    NAME = probes,
    S1 = c(0.30, 0.35, 0.70, 0.68),
    S2 = c(0.40, 0.45, 0.62, 0.60),
    S3 = c(0.52, 0.49, 0.51, 0.48),
    stringsAsFactors = FALSE
  )
  rownames(beta) <- beta$NAME

  meta <- data.frame(
    Sample_Name = c("S1", "S2", "S3"),
    Sample_Group = c("case", "case", "control"),
    stringsAsFactors = FALSE
  )

  probeset <- data.frame(
    NAME = probes,
    CHR = c("chr11", "chr11", "chr11", "chr11"),
    MAPINFO = c(10001, 10002, 10003, 10004),
    ORIGIN = c("maternal", "maternal", "paternal", "paternal"),
    Closest_TSS_gene_name = c("GENE1", "GENE1", "GENE1", "GENE1"),
    stringsAsFactors = FALSE
  )
  rownames(probeset) <- probeset$NAME

  list(beta = beta, meta = meta, probeset = probeset)
}

.load_minimal_modules()

test_that("AnalyzeImprintStatus validates ids_cutoff and preserves output shape", {
  d <- .make_fixture()
  .with_temp_probeset_file(d$probeset, {
    expect_error(
      AnalyzeImprintStatus(d$beta, d$meta, probeset = "selected", ids_cutoff = NA_real_),
      "ids_cutoff must be a single finite numeric value"
    )

    res <- AnalyzeImprintStatus(d$beta, d$meta, probeset = "selected", ids_cutoff = 0.2)
    expect_true(is.data.frame(res))
    expect_equal(nrow(res), nrow(d$meta))
    expect_true(all(c("paternal_median", "maternal_median", "IDS", "Angle", "Mechanism", "Status", "Confidence") %in% colnames(res)))
  })
})

test_that("AnalyzeImprintStatus rejects probesets missing a parental origin", {
  d <- .make_fixture()
  p_missing_mat <- d$probeset
  p_missing_mat$ORIGIN <- "paternal"

  .with_temp_probeset_file(p_missing_mat, {
    expect_error(
      AnalyzeImprintStatus(d$beta, d$meta, probeset = "selected", ids_cutoff = 0.2),
      "must contain both maternal and paternal ORIGIN annotations"
    )
  })
})

.make_dmr_fixture <- function() {
  d <- .make_fixture()
  extra <- c("cg00000005", "cg00000006")
  beta_extra <- data.frame(
    NAME = extra,
    S1 = c(0.90, 0.10),
    S2 = c(0.90, 0.10),
    S3 = c(0.90, 0.10),
    stringsAsFactors = FALSE
  )
  rownames(beta_extra) <- extra
  d$beta <- rbind(d$beta, beta_extra)

  probeset_extra <- data.frame(
    NAME = extra,
    CHR = c("chr14", "chr20"),
    MAPINFO = c(20001, 30001),
    ORIGIN = c("maternal", "paternal"),
    Closest_TSS_gene_name = c("GENE2", "GENE3"),
    stringsAsFactors = FALSE
  )
  rownames(probeset_extra) <- extra
  d$probeset <- rbind(d$probeset, probeset_extra)
  d$probeset$DMR_type <- c("gametic", "gametic", "gametic", "gametic", "secondary", "secondary")
  d
}

test_that("AnalyzeImprintStatus scores only the requested DMR_type", {
  d <- .make_dmr_fixture()
  .with_temp_probeset_file(d$probeset, {
    res_all <- AnalyzeImprintStatus(d$beta, d$meta, probeset = "selected", ids_cutoff = 0.2, dmr_type = "all")
    res_gam <- AnalyzeImprintStatus(d$beta, d$meta, probeset = "selected", ids_cutoff = 0.2, dmr_type = "gametic")

    expect_equal(unique(res_all$dmr_type), "all")
    expect_equal(unique(res_all$n_maternal_probes), 3)
    expect_equal(unique(res_all$n_paternal_probes), 3)

    expect_equal(unique(res_gam$dmr_type), "gametic")
    expect_equal(unique(res_gam$n_maternal_probes), 2)
    expect_equal(unique(res_gam$n_paternal_probes), 2)
    expect_equal(res_gam$maternal_median[res_gam$Sample_Name == "S1"], round(median(c(0.30, 0.35)), 3))
    expect_equal(res_gam$paternal_median[res_gam$Sample_Name == "S1"], round(median(c(0.70, 0.68)), 3))
  })
})

test_that("AnalyzeImprintStatus scores the core selected panel on gametic ICRs by default", {
  expect_equal(.default_dmr_type("selected"), "gametic")
  expect_null(.default_dmr_type("chr11p15"))
  d <- .make_dmr_fixture()
  .with_temp_probeset_file(d$probeset, {
    res_default <- AnalyzeImprintStatus(d$beta, d$meta, probeset = "selected", ids_cutoff = 0.2)
    res_gam <- AnalyzeImprintStatus(d$beta, d$meta, probeset = "selected", ids_cutoff = 0.2, dmr_type = "gametic")
    expect_equal(res_default, res_gam)
    expect_equal(unique(res_default$dmr_type), "gametic")
    expect_equal(unique(res_default$n_paternal_probes), 2)
    # Chromosome subsets of selected are not the core panel and keep all probes.
    res_chr <- AnalyzeImprintStatus(d$beta, d$meta, probeset = "chr11", ids_cutoff = 0.2)
    expect_equal(unique(res_chr$dmr_type), "all")
  })
})

test_that("AnalyzeImprintStatus default scores all probes when the panel has no DMR_type", {
  d <- .make_dmr_fixture()
  p_without_type <- d$probeset[, setdiff(colnames(d$probeset), "DMR_type")]
  res_all <- .with_temp_probeset_file(d$probeset,
    AnalyzeImprintStatus(d$beta, d$meta, probeset = "selected", ids_cutoff = 0.2, dmr_type = "all"))
  res_without <- .with_temp_probeset_file(p_without_type,
    AnalyzeImprintStatus(d$beta, d$meta, probeset = "selected", ids_cutoff = 0.2))
  expect_equal(res_all, res_without)
  expect_equal(unique(res_without$dmr_type), "all")
})

test_that("AnalyzeImprintStatus dmr_type errors are informative", {
  d <- .make_dmr_fixture()
  p_without_type <- d$probeset[, setdiff(colnames(d$probeset), "DMR_type")]
  .with_temp_probeset_file(p_without_type, {
    expect_error(
      AnalyzeImprintStatus(d$beta, d$meta, probeset = "selected", dmr_type = "gametic"),
      "has no DMR_type column"
    )
  })

  p_one_origin <- d$probeset
  p_one_origin$DMR_type[p_one_origin$NAME == "cg00000006"] <- "ambiguous"
  .with_temp_probeset_file(p_one_origin, {
    expect_error(
      AnalyzeImprintStatus(d$beta, d$meta, probeset = "selected", dmr_type = "secondary"),
      "no matched probes for both maternal and paternal origins"
    )
    expect_error(
      AnalyzeImprintStatus(d$beta, d$meta, probeset = "selected", dmr_type = character(0)),
      "dmr_type must be NULL or a non-empty character vector"
    )
    expect_error(
      AnalyzeImprintStatus(d$beta, d$meta, probeset = "selected", dmr_type = c("all", "gametic")),
      "cannot be combined"
    )
  })
})

test_that("AggregateByLocus uses median aggregation by default", {
  beta <- data.frame(
    S1 = c(0.1, 0.2, 0.9, 0.8),
    S2 = c(0.2, 0.3, 0.7, 0.6),
    stringsAsFactors = FALSE
  )
  rownames(beta) <- c("cg1", "cg2", "cg3", "cg4")

  probeset <- data.frame(
    NAME = c("cg1", "cg2", "cg3", "cg4"),
    CHR = c("chr1", "chr1", "chr1", "chr2"),
    ORIGIN = c("maternal", "maternal", "maternal", "paternal"),
    Closest_TSS_gene_name = c("G1", "G1", "G1", "G2"),
    stringsAsFactors = FALSE
  )

  .with_temp_probeset_file(probeset, {
    res <- AggregateByLocus(beta, probeset = "selected")
    expect_true(is.data.frame(res))
    expect_true("chr1_maternal_G1" %in% rownames(res))
    expect_equal(as.numeric(res["chr1_maternal_G1", "S1"]), 0.2, tolerance = 1e-8)
    expect_equal(as.numeric(res["chr1_maternal_G1", "S2"]), 0.3, tolerance = 1e-8)
  })
})

test_that("AggregateByLocus returns empty typed frame when no probes overlap", {
  beta <- data.frame(S1 = c(0.1, 0.2), S2 = c(0.3, 0.4), stringsAsFactors = FALSE)
  rownames(beta) <- c("cgX", "cgY")

  probeset <- data.frame(
    NAME = c("cg1", "cg2"),
    CHR = c("chr1", "chr1"),
    ORIGIN = c("maternal", "paternal"),
    Closest_TSS_gene_name = c("G1", "G2"),
    stringsAsFactors = FALSE
  )

  .with_temp_probeset_file(probeset, {
    res <- AggregateByLocus(beta, probeset = "selected")
    expect_true(is.data.frame(res))
    expect_equal(nrow(res), 0)
    expect_equal(ncol(res), ncol(beta))
    expect_equal(colnames(res), colnames(beta))
  })
})

test_that("AggregateByLocus returns loci in genomic order", {
  beta <- data.frame(S1 = c(0.1, 0.2, 0.3, 0.4, 0.5), stringsAsFactors = FALSE)
  rownames(beta) <- c("cg1", "cg2", "cg3", "cg4", "cg5")
  probeset <- data.frame(
    NAME = c("cg1", "cg2", "cg3", "cg4", "cg5"),
    CHR = c("chr10", "chrX", "chr1", "chr1", "chr2"),
    MAPINFO = c(500, 100, 900, 200, 300),
    ORIGIN = c("maternal", "paternal", "maternal", "maternal", "paternal"),
    Closest_TSS_gene_name = c("A", "B", "AA", "ZZ", "C"),
    stringsAsFactors = FALSE
  )

  .with_temp_probeset_file(probeset, {
    res <- AggregateByLocus(beta, probeset = "selected")
    # chr1 loci by position (ZZ at 200 before AA at 900), then chr2, chr10, chrX.
    expect_equal(rownames(res), c("chr1_maternal_ZZ", "chr1_maternal_AA", "chr2_paternal_C",
                                  "chr10_maternal_A", "chrX_paternal_B"))
  })
})
