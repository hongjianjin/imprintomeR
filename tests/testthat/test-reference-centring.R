testthat::local_edition(1)

# Reference-based centring (in-cohort and external controls, 0.5 fallback) and
# Infinium I/II-aware scoring in AnalyzeImprintStatus() and runImprintome().

.with_reference_panel <- function(probeset_df, code) {
  old_wd <- getwd()
  tmp_wd <- tempfile("imprintome_ref_")
  dir.create(file.path(tmp_wd, "inst", "extdata"), recursive = TRUE)
  for (g in c("hg19", "hg38")) {
    saveRDS(list(selected = probeset_df), file.path(tmp_wd, "inst", "extdata", paste0("probesets_", g, ".rds")))
  }
  setwd(tmp_wd)
  on.exit(setwd(old_wd), add = TRUE)
  force(code)
}

# Six maternal and six paternal probes, alternating Infinium type I/II. Each probe
# has its own tissue baseline away from 0.5; five controls scatter around it and
# case X1 gains paternal methylation (+0.3).
.make_reference_fixture <- function() {
  probes <- c(sprintf("cgM%02d", 1:6), sprintf("cgP%02d", 1:6))
  baseline <- c(0.62, 0.58, 0.66, 0.60, 0.64, 0.57, 0.63, 0.59, 0.65, 0.61, 0.60, 0.67)
  offsets <- c(C1 = -0.02, C2 = -0.01, C3 = 0, C4 = 0.01, C5 = 0.02)
  beta <- sapply(offsets, function(o) baseline + o + seq(-0.006, 0.006, length.out = 12))
  beta <- cbind(beta, X1 = baseline + c(rep(0, 6), rep(0.3, 6)), X2 = baseline)
  rownames(beta) <- probes
  meta <- data.frame(
    Sample_Name = colnames(beta),
    Sample_Group = c(rep("control", 5), "case", "case"),
    stringsAsFactors = FALSE
  )
  probeset <- data.frame(
    NAME = probes,
    CHR = "chr11",
    MAPINFO = seq_along(probes),
    ORIGIN = rep(c("maternal", "paternal"), each = 6),
    INFINIUM_DESIGN_TYPE = rep(c("I", "II"), 6),
    stringsAsFactors = FALSE
  )
  list(beta = data.frame(TargetID = probes, beta, check.names = FALSE), matrix = beta, meta = meta, probeset = probeset)
}

.score <- function(d, ...) {
  out <- NULL
  invisible(utils::capture.output(out <- AnalyzeImprintStatus(d$beta, d$meta, probeset = "selected", ...)))
  rownames(out) <- out$Sample_Name
  out
}

test_that("default scoring uses the fixed 0.5 reference when no controls are given", {
  d <- .make_reference_fixture()
  .with_reference_panel(d$probeset, {
    res <- .score(d)
    expect_equal(unique(res$reference), "fixed (0.5)")
    expect_equal(unique(res$n_reference_samples), 0)
    expect_equal(unique(res$infinium_type), "all")
    expect_equal(res$paternal_deviation, round(res$paternal_median - 0.5, 3), tolerance = 1e-3)
    expect_equal(res$IDS, round(compute_ids(res$paternal_median, res$maternal_median), 3), tolerance = 2e-3)
    expect_identical(res, .score(d, reference = "fixed"))
  })
})

test_that("controls at 0.5 reproduce the fixed reference", {
  d <- .make_reference_fixture()
  d$beta[, paste0("C", 1:5)] <- 0.5
  .with_reference_panel(d$probeset, {
    fixed <- .score(d)
    controls <- .score(d, reference_group = "control")
    expect_equal(controls$IDS, fixed$IDS)
    expect_equal(controls$Angle, fixed$Angle)
    expect_equal(unique(controls$reference), "in-cohort controls, n=5")
  })
})

test_that("in-cohort controls remove a tissue baseline shift", {
  d <- .make_reference_fixture()
  .with_reference_panel(d$probeset, {
    fixed <- .score(d)
    controls <- .score(d, reference_group = "control")
    # The fixed reference flags normal tissue; the control reference does not.
    expect_true(all(fixed[paste0("C", 1:5), "IDS"] > 0.1))
    expect_true(all(controls[c(paste0("C", 1:5), "X2"), "IDS"] < 0.05))
    expect_equal(controls["X1", "Mechanism"], "Pat-Gain")
    expect_equal(controls["X1", "paternal_deviation"], 0.3, tolerance = 0.02)
    expect_equal(controls["X1", "maternal_deviation"], 0, tolerance = 0.02)
    expect_true(all(controls[paste0("C", 1:5), "consistency"] >= 0) &&
                all(controls[paste0("C", 1:5), "consistency"] <= 1))
  })
})

test_that("each control is scored against the other controls (leave-one-out)", {
  d <- .make_reference_fixture()
  .with_reference_panel(d$probeset, {
    res <- .score(d, reference_samples = paste0("C", 1:5))
    expect_equal(res[paste0("C", 1:5), "n_reference_samples"], rep(4, 5))
    expect_equal(res[c("X1", "X2"), "n_reference_samples"], c(5, 5))
    m <- d$matrix
    loo <- apply(m[, paste0("C", 2:5)], 1, median)
    mat <- grep("^cgM", rownames(m))
    expect_equal(res["C1", "maternal_deviation"], round(median(m[mat, "C1"] - loo[mat]), 3))
  })
})

test_that("an external control matrix or profile centres a cohort without controls", {
  d <- .make_reference_fixture()
  controls <- d$matrix[, paste0("C", 1:5)]
  cases <- d
  cases$beta <- d$beta[, c("TargetID", "X1", "X2")]
  cases$meta <- d$meta[d$meta$Sample_Group == "case", ]
  .with_reference_panel(d$probeset, {
    in_cohort <- .score(d, reference_group = "control")
    external <- .score(cases, reference_beta = controls)
    expect_equal(unique(external$reference), "external controls, n=5")
    expect_equal(external[c("X1", "X2"), "IDS"], in_cohort[c("X1", "X2"), "IDS"])

    profile <- NULL
    invisible(utils::capture.output(profile <- BuildReferenceProfile(controls, probeset = "selected")))
    expect_equal(attr(profile, "n_samples"), 5)
    expect_equal(length(profile), 12)
    expect_identical(.score(cases, reference_beta = profile), external)

    path <- tempfile(fileext = ".rds")
    saveRDS(profile, path)
    expect_identical(.score(cases, reference_beta = path), external)

    expect_message(
      partial <- .score(cases, reference_beta = controls[-12, ]),
      "1 probe\\(s\\) absent from reference_beta were dropped"
    )
    expect_equal(unique(partial$n_paternal_probes), 5)
  })
})

test_that("too few controls fall back to 0.5 under 'auto' and fail under 'controls'", {
  d <- .make_reference_fixture()
  .with_reference_panel(d$probeset, {
    expect_warning(res <- .score(d, reference_samples = c("C1", "C2")), "falling back to the fixed 0.5")
    expect_equal(unique(res$reference), "fixed (0.5)")
    expect_identical(res, .score(d))
    expect_warning(.score(d, reference_group = "normal"), "falling back to the fixed 0.5")
    expect_error(.score(d, reference = "controls", reference_samples = c("C1", "C2")), "at least 3")
    expect_error(.score(d, reference = "controls"), "requires reference_group")
    expect_warning(.score(d, reference_samples = paste0("C", 1:4)), "at least 5 tissue-matched controls")
  })
})

test_that("reference arguments are validated", {
  d <- .make_reference_fixture()
  .with_reference_panel(d$probeset, {
    expect_error(.score(d, reference_samples = c("C1", "C2", "nope")), "not found among scored samples")
    expect_error(.score(d, reference_group = "control", reference_samples = "C1"), "not both")
    expect_error(.score(d, reference_group = "control", reference_beta = d$matrix), "not both")
    expect_warning(res <- .score(d, reference = "fixed", reference_group = "control"), "supplied controls are ignored")
    expect_equal(unique(res$reference), "fixed (0.5)")
    expect_error(.score(d, reference = "median"))
    expect_error(.score(d, infinium_type = "III"))
  })
})

test_that("infinium_type filters probes or balances type I and II", {
  d <- .make_reference_fixture()
  .with_reference_panel(d$probeset, {
    type_i <- .score(d, infinium_type = "I")
    type_ii <- .score(d, infinium_type = "II")
    expect_equal(unique(type_i$n_maternal_probes), 3)
    expect_equal(unique(type_ii$n_paternal_probes), 3)
    expect_equal(unique(type_i$infinium_type), "I")

    balanced <- .score(d, infinium_type = "balanced")
    expect_equal(unique(balanced$n_maternal_probes), 6)
    m <- d$matrix
    mat <- rownames(m)[1:6]
    type <- d$probeset$INFINIUM_DESIGN_TYPE[1:6]
    expected <- mean(c(median(m[mat[type == "I"], "X1"]), median(m[mat[type == "II"], "X1"]))) - 0.5
    expect_equal(balanced["X1", "maternal_deviation"], round(expected, 3))

    no_type <- d$probeset[, setdiff(colnames(d$probeset), "INFINIUM_DESIGN_TYPE")]
    .with_reference_panel(no_type, {
      expect_error(.score(d, infinium_type = "balanced"), "has no INFINIUM_DESIGN_TYPE column")
      expect_equal(unique(.score(d)$infinium_type), "all")
    })
  })
})

test_that("runImprintome passes reference options and names non-default results", {
  d <- .make_reference_fixture()
  .with_reference_panel(d$probeset, {
    x <- ImprintomeSet(beta = d$matrix, meta = d$meta, probeset = d$probeset, genome = "hg38", assay = "EPICv1")
    invisible(utils::capture.output({
      x <- runImprintome(x, probeset = "selected")
      x <- runImprintome(x, probeset = "selected", reference_group = "control", infinium_type = "balanced")
    }))
    expect_true(all(c("AnalyzeImprintStatus.selected", "AnalyzeImprintStatus.selected.ref-controls.typebalanced")
                    %in% names(results(x))))
    res <- results(x)[["AnalyzeImprintStatus.selected.ref-controls.typebalanced"]]
    expect_equal(unique(res$reference), "in-cohort controls, n=5")
    expect_equal(unique(results(x)[["AnalyzeImprintStatus.selected"]]$reference), "fixed (0.5)")
  })
})

test_that("the CLI exposes the reference and Infinium options", {
  script <- system.file("scripts", "run_imprintomeR.R", package = "imprintomeR")
  if (!nzchar(script)) script <- file.path("..", "..", "inst", "scripts", "run_imprintomeR.R")
  skip_if_not(file.exists(script), "CLI script not available")
  text <- readLines(script, warn = FALSE)
  for (flag in c("--reference-group", "--reference-file", "--infinium-type")) {
    expect_true(any(grepl(flag, text, fixed = TRUE)), info = flag)
  }
  expect_true(any(grepl('make_option(c("--infinium-type"), type = "character", default = "all"', text, fixed = TRUE)))
})
