testthat::local_edition(1)

# Data checks for the shipped probeset annotation. They read inst/extdata from the
# package source tree and the Monk et al. 2018 Table 1 TSV kept with the curation
# sources; they are skipped when either is unavailable (e.g. in an installed build).
.find_annotation_root <- function() {
  cur <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
  repeat {
    if (file.exists(file.path(cur, "inst", "extdata", "probesets_hg19.rds")) &&
        file.exists(file.path(cur, "tmp_ICR_sources", "Monk_2018", "Table1_germline_status.tsv"))) {
      return(cur)
    }
    parent <- dirname(cur)
    if (identical(parent, cur)) return("")
    cur <- parent
  }
}

.annotation_root <- .find_annotation_root()

.read_annotation <- function() {
  list(
    hg19 = readRDS(file.path(.annotation_root, "inst", "extdata", "probesets_hg19.rds")),
    hg38 = readRDS(file.path(.annotation_root, "inst", "extdata", "probesets_hg38.rds")),
    monk = read.delim(file.path(.annotation_root, "tmp_ICR_sources", "Monk_2018", "Table1_germline_status.tsv"),
                      quote = "", stringsAsFactors = FALSE)
  )
}

test_that("Monk 2018 Table 1 TSV has the expected DMR classification", {
  if (!nzchar(.annotation_root)) skip("Probeset annotation sources not available")
  monk <- .read_annotation()$monk
  expect_equal(nrow(monk), 50)
  expect_false(anyDuplicated(monk$ICR_name) > 0)
  expect_true(all(monk$ORIGIN %in% c("maternal", "paternal")))
  expect_equal(as.integer(table(factor(monk$DMR_type, levels = c("gametic", "secondary", "ambiguous")))),
               c(37L, 11L, 2L))
  expect_equal(monk$ORIGIN[monk$ICR_name == "MEG8:Int2-DMR"], "maternal")
})

test_that("selected DMR_type and ORIGIN agree with Monk 2018 Table 1", {
  if (!nzchar(.annotation_root)) skip("Probeset annotation sources not available")
  a <- .read_annotation()
  sel <- a$hg19$selected
  expect_true(all(c("ICR_name", "DMR_type", "DMR_type_source") %in% colnames(sel)))
  expect_true(all(sel$DMR_type %in% c("gametic", "secondary", "ambiguous", "unclassified", "uncurated")))

  from_monk <- sel$DMR_type_source %in% "Monk2018_Table1"
  idx <- match(sel$ICR_name[from_monk], a$monk$ICR_name)
  expect_false(anyNA(idx))
  expect_equal(sel$DMR_type[from_monk], a$monk$DMR_type[idx])
  expect_equal(sel$ORIGIN[from_monk], a$monk$ORIGIN[idx])

  gametic <- sel$DMR_type == "gametic"
  expect_equal(sum(gametic & sel$ORIGIN == "maternal"), 505)
  expect_equal(sum(gametic & sel$ORIGIN == "paternal"), 49)
})

test_that("chr11p15 is annotated as the two gametic 11p15.5 ICRs", {
  if (!nzchar(.annotation_root)) skip("Probeset annotation sources not available")
  a <- .read_annotation()
  cp <- a$hg19$chr11p15
  expect_true(all(c("ICR_name", "DMR_type", "DMR_type_source") %in% colnames(cp)))
  expect_true(all(cp$DMR_type == "gametic"))
  expect_true(all(cp$DMR_type_source == "Monk2018_Table1"))
  expect_equal(sort(unique(cp$ICR_name)), c("H19/IGF2:IG-DMR", "KCNQ1OT1:TSS-DMR"))
  expect_true(all(cp$ORIGIN[cp$ICR_name == "H19/IGF2:IG-DMR"] == "paternal"))
  expect_true(all(cp$ORIGIN[cp$ICR_name == "KCNQ1OT1:TSS-DMR"] == "maternal"))
  expect_equal(sum(cp$ICR_name == "H19/IGF2:IG-DMR"), 51)
  expect_equal(sum(cp$ICR_name == "KCNQ1OT1:TSS-DMR"), 31)
})

test_that("hg38 chr11p15_region mirrors hg19 with hg38 coordinates", {
  if (!nzchar(.annotation_root)) skip("Probeset annotation sources not available")
  a <- .read_annotation()
  c19 <- a$hg19$chr11p15_region
  c38 <- a$hg38$chr11p15_region
  expect_false(is.null(c38))
  expect_equal(colnames(c38), colnames(c19))
  expect_equal(c38$ICR_name, c19$ICR_name)
  expect_equal(c38$ICR_type, c19$ICR_type)
  expect_equal(c38$ORIGIN, c19$ORIGIN)
  expect_true(all(c38$Genome_Build == "hg38"))
  expect_equal(c38$end - c38$start, c19$end - c19$start)
  expect_false(any(c38$start == c19$start))
  # Every hg38 row is a row of hg38 Rosenski_region.
  key <- function(d) paste(d$CHR, d$start, d$end)
  expect_true(all(key(c38) %in% key(a$hg38$Rosenski_region)))
})

test_that("hg38 selected carries the hg19 selected annotation by probe NAME", {
  if (!nzchar(.annotation_root)) skip("Probeset annotation sources not available")
  a <- .read_annotation()
  s19 <- a$hg19$selected
  s38 <- a$hg38$selected
  expect_false(is.null(s38))
  expect_equal(s38$NAME, s19$NAME)
  for (cn in c("Closest_TSS_gene_name", "ORIGIN", "ICR_name", "DMR_type", "DMR_type_source")) {
    expect_equal(s38[[cn]], s19[[cn]])
  }
  expect_equal(s38$CHR, s19$CHR)
  expect_false(any(s38$MAPINFO == s19$MAPINFO))
  expect_true(all(grepl("^chr[0-9XY]+:[0-9]+-[0-9]+$", s38$region)))
  expect_equal(length(unique(s38$region)), length(unique(s19$region)))
})

test_that("MEG8:Int2-DMR probes are maternal in every panel and build", {
  if (!nzchar(.annotation_root)) skip("Probeset annotation sources not available")
  a <- .read_annotation()
  meg8 <- c("cg06804177", "cg03664700", "cg26981637")

  for (regions in list(a$hg19$Rosenski_region, a$hg38$Rosenski_region)) {
    expect_equal(regions$ORIGIN[regions$ICR_name == "RTL1" & regions$CHR == "chr14"], "maternal")
  }
  for (build in list(a$hg19, a$hg38)) {
    expect_true(all(build$Rosenski$ORIGIN[build$Rosenski$NAME %in% meg8] == "maternal"))
    expect_equal(build$NanoImprint$ORIGIN[build$NanoImprint$NAME == "cg06804177"], "maternal")
    expect_equal(build$Court$ORIGIN[build$Court$NAME == "cg06804177"], "maternal")
  }
  expect_equal(a$hg19$selected$ICR_name[a$hg19$selected$NAME == "cg06804177"], "MEG8:Int2-DMR")
})
