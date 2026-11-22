# Native control-probe / SNP QC functions against ewastools 1.8.2 outputs on the same IDATs
# (fixtures/qc_controls_reference.rds, built by fixtures/make_qc_controls_reference.R).

.qc_ref <- function() readRDS(test_path("fixtures", "qc_controls_reference.rds"))

.expect_metrics_equal <- function(native, ew) {
  expect_identical(names(native), names(ew))
  for (k in names(ew)) {
    expect_equal(native[[k]], as.numeric(ew[[k]]), tolerance = 1e-12, ignore_attr = TRUE, label = k)
    expect_identical(attr(native[[k]], "threshold"), attr(ew[[k]], "threshold"), label = k)
  }
}

.same_partition <- function(a, b) identical(as.integer(factor(a, unique(a))), as.integer(factor(b, unique(b))))

test_that("control-probe metrics match ewastools on 450K and EPICv1 IDATs", {
  ref <- .qc_ref()
  for (r in list(ref$k450, ref$epic)) {
    .expect_metrics_equal(imprintomeR:::.qc_control_metrics(r$raw), r$ewastools$control_metrics)
  }
  # the EPICv1 set includes probes read from zero beads, which are NA in both
  expect_true(anyNA(ref$epic$raw$ctrlG))
})

test_that("CtrlMetrics.QC is the same from native and ewastools metrics", {
  r <- .qc_ref()$epic
  expect_identical(imprintomeR:::.ctrl_metrics_qc(imprintomeR:::.qc_control_metrics(r$raw)),
                   imprintomeR:::.ctrl_metrics_qc(r$ewastools$control_metrics))
})

test_that("SNP beta values and genotype probabilities match ewastools", {
  ref <- .qc_ref()
  for (r in list(ref$k450, ref$epic)) {
    expect_equal(r$snp, r$ewastools$snp, tolerance = 1e-12)
    gt <- imprintomeR:::.qc_call_genotypes(r$snp)
    expect_equal(gt$outliers, r$ewastools$outliers, tolerance = 1e-12)
    for (k in 1:3) expect_equal(gt$gamma[[k]], r$ewastools$gamma[[k]], tolerance = 1e-12)
  }
  expect_true(anyNA(ref$epic$snp))
})

test_that("predicted donors and sample-swap conflicts match ewastools", {
  r <- .qc_ref()$epic
  gt <- imprintomeR:::.qc_call_genotypes(r$snp)
  expect_true(.same_partition(imprintomeR:::.qc_enumerate_donors(gt), r$ewastools$donors))
  for (lab in names(r$ewastools$labels)) {
    ew <- r$ewastools$conflicts[[lab]]
    nat <- imprintomeR:::.qc_snp_conflicts(gt, r$ewastools$labels[[lab]], r$samples)
    expect_false(is.null(ew), label = lab)
    pair <- function(x) paste(pmin(x$sample1, x$sample2), pmax(x$sample1, x$sample2))
    m <- match(pair(ew), pair(nat))
    expect_false(anyNA(m), label = lab)
    expect_identical(nrow(nat), nrow(ew), label = lab)
    expect_equal(nat$agreement[m], ew$agreement, tolerance = 1e-12, label = lab)
    expect_identical(nat$donor1[m], ew$donor1, label = lab)
    expect_true(.same_partition(nat$group[m], ew$group), label = lab)
  }
})

test_that(".qc_snp_conflicts returns NULL without conflicts and one long table otherwise", {
  # three samples: S1 and S2 genotype-identical, S3 different
  snp <- matrix(c(0.05, 0.5, 0.95, 0.05, 0.5, 0.95, 0.95, 0.05, 0.5), nrow = 3,
                dimnames = list(paste0("rs", 1:3), paste0("S", 1:3)))
  snp <- snp[rep(1:3, 10), ]
  gt <- imprintomeR:::.qc_call_genotypes(snp)
  expect_identical(imprintomeR:::.qc_enumerate_donors(gt), c(1L, 1L, 2L))
  expect_null(imprintomeR:::.qc_snp_conflicts(gt, c("A", "A", "B"), colnames(snp)))
  # labelling all three as different donors flags S1/S2; groups of unequal size stay one table
  x <- imprintomeR:::.qc_snp_conflicts(gt, c("A", "B", "B"), colnames(snp))
  expect_s3_class(x, "data.frame")
  expect_identical(colnames(x), c("donor1", "sample1", "donor2", "sample2", "agreement", "group"))
  expect_setequal(paste(x$sample1, x$sample2), c("S1 S2", "S2 S3"))
})

test_that(".qc_components finds connected components numbered by first appearance", {
  expect_identical(imprintomeR:::.qc_components(c(4, 1), c(5, 2), 5), c(1L, 1L, 2L, 3L, 3L))
  expect_identical(imprintomeR:::.qc_components(integer(), integer(), 3), 1:3)
})
