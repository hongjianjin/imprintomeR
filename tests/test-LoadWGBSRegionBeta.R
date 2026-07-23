test_that("LoadWGBSRegionBeta loads wgbstools beta_to_table output", {
  probesets <- readRDS(test_path("..", "inst", "extdata", "probesets_hg19.rds"))
  reg <- probesets[["Rosenski_region"]]
  tab <- data.frame(
    chr = reg$CHR[1:3],
    start = reg$start[1:3],
    end = reg$end[1:3],
    startCpG = c(101, 201, 301),
    endCpG = c(110, 210, 310),
    sample_A = c(0.45, 0.52, 0.61),
    sample_B = c(0.40, 0.50, 0.65),
    check.names = FALSE
  )

  beta <- LoadWGBSRegionBeta(tab, probeset = reg, verbose = FALSE)

  expect_true(is.matrix(beta))
  expect_equal(dim(beta), c(3L, 2L))
  expect_equal(rownames(beta), reg$NAME[1:3])
  expect_equal(colnames(beta), c("sample_A", "sample_B"))
  expect_equal(unname(beta[1, 1]), 0.45)
  expect_equal(attr(beta, "regions")$NAME, reg$NAME[1:3])
  expect_equal(attr(beta, "probeset_name"), "custom")
})

test_that("LoadWGBSRegionBeta can keep all regions without probeset alignment", {
  tab <- data.frame(
    chr = c("chr1", "chr2"),
    start = c(10L, 20L),
    end = c(15L, 25L),
    startCpG = c(1L, 2L),
    endCpG = c(2L, 3L),
    S1 = c(0.1, 0.2),
    check.names = FALSE
  )

  beta <- LoadWGBSRegionBeta(tab, probeset = NULL, verbose = FALSE)

  expect_equal(rownames(beta), c("chr1:10-15", "chr2:20-25"))
  expect_equal(dim(beta), c(2L, 1L))
  expect_null(attr(beta, "probeset_name"))
})
test_that("LoadWGBSRegionBeta can align named hg38 Rosenski_region", {
  probesets <- readRDS(test_path("..", "inst", "extdata", "probesets_hg38.rds"))
  reg <- probesets[["Rosenski_region"]]
  tab <- data.frame(
    chr = reg$CHR[1:2],
    start = reg$start[1:2],
    end = reg$end[1:2],
    sample_A = c(0.48, 0.55),
    check.names = FALSE
  )

  beta <- LoadWGBSRegionBeta(tab, probeset = "Rosenski_region", genome = "hg38", verbose = FALSE)

  expect_equal(dim(beta), c(2L, 1L))
  expect_equal(rownames(beta), reg$NAME[1:2])
  expect_equal(attr(beta, "probeset_name"), "Rosenski_region")
  expect_equal(attr(beta, "genome"), "hg38")
})

test_that("hg38 chr11p15_region is a chr11 subset excluding OSBPL5", {
  probesets <- readRDS(test_path("..", "inst", "extdata", "probesets_hg38.rds"))
  expect_true("chr11p15_region" %in% names(probesets))

  reg <- probesets[["chr11p15_region"]]
  expect_equal(nrow(reg), 8)
  expect_true(all(reg$CHR == "chr11"))
  expect_false(any(reg$Closest_TSS_gene_name == "OSBPL5", na.rm = TRUE))
  expect_true(all(reg$NAME %in% probesets[["Rosenski_region"]]$NAME))

  tab <- data.frame(
    chr = reg$CHR[1:2],
    start = reg$start[1:2],
    end = reg$end[1:2],
    sample_A = c(0.48, 0.55),
    check.names = FALSE
  )
  beta <- LoadWGBSRegionBeta(tab, probeset = "chr11p15_region", genome = "hg38", verbose = FALSE)
  expect_equal(dim(beta), c(2L, 1L))
  expect_equal(rownames(beta), reg$NAME[1:2])
  expect_equal(attr(beta, "probeset_name"), "chr11p15_region")
})
test_that("hg19 chr11p15_region is a chr11 subset excluding OSBPL5", {
  probesets <- readRDS(test_path("..", "inst", "extdata", "probesets_hg19.rds"))
  expect_true("chr11p15_region" %in% names(probesets))

  reg <- probesets[["chr11p15_region"]]
  expect_equal(nrow(reg), 8)
  expect_true(all(reg$CHR == "chr11"))
  expect_false(any(reg$Closest_TSS_gene_name == "OSBPL5", na.rm = TRUE))
  expect_true(all(reg$NAME %in% probesets[["Rosenski_region"]]$NAME))

  tab <- data.frame(
    chr = reg$CHR[1:2],
    start = reg$start[1:2],
    end = reg$end[1:2],
    sample_A = c(0.48, 0.55),
    check.names = FALSE
  )
  beta <- LoadWGBSRegionBeta(tab, probeset = "chr11p15_region", genome = "hg19", verbose = FALSE)
  expect_equal(dim(beta), c(2L, 1L))
  expect_equal(rownames(beta), reg$NAME[1:2])
  expect_equal(attr(beta, "probeset_name"), "chr11p15_region")
})
