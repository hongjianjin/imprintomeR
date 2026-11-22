# Control-probe metrics, SNP genotypes, donor matching and sample-swap checks for runMethQC().
#
# Native re-implementation of the ewastools functions read_idats() (control and SNP probes only),
# control_metrics(), call_genotypes(learn = FALSE), check_snp_agreement() and
# enumerate_sample_donors() from ewastools 1.8.2 (Heiss JA, Just AC. Clin Epigenetics 2018;10:73;
# https://github.com/hhhh5/ewastools, licence "Unlimited"). Probe annotation comes from the minfi
# manifest of the RGChannelSet. On 450K, EPICv1 and EPICv2 IDATs the outputs are identical to
# ewastools 1.8.2 (see tests/testthat/test-qc-controls.R).

# Probe tables in minfi::getProbeInfo() format ("Control", "SnpI", "SnpII").
.qc_minfi_pinfo <- function(rg) function(type) as.data.frame(minfi::getProbeInfo(rg, type = type))

# Bead counts for selected addresses, read from the green IDATs. NA where the IDAT is not found.
.qc_nbeads <- function(basenames, addresses) {
  addresses <- unique(as.character(addresses))
  out <- vapply(basenames, function(b) {
    f <- paste0(b, c("_Grn.idat", "_Grn.idat.gz"))
    f <- f[file.exists(f)]
    if (!length(f)) return(rep(NA_integer_, length(addresses)))
    q <- illuminaio::readIDAT(f[1])$Quants
    as.integer(q[match(addresses, rownames(q)), "NBeads"])
  }, integer(length(addresses)), USE.NAMES = FALSE)
  matrix(out, nrow = length(addresses), dimnames = list(addresses, basename(basenames)))
}

# Control-probe intensities; addresses read from zero beads are NA (as in ewastools).
.qc_control_intensities <- function(rg, nbeads = NULL, pinfo = .qc_minfi_pinfo(rg)) {
  ci <- pinfo("Control")
  ci <- ci[as.character(ci$Address) %in% rownames(rg), , drop = FALSE]
  addr <- as.character(ci$Address)
  G <- minfi::getGreen(rg)[addr, , drop = FALSE]
  R <- minfi::getRed(rg)[addr, , drop = FALSE]
  if (!is.null(nbeads)) {
    z <- nbeads[addr, , drop = FALSE]
    z <- !is.na(z) & z == 0
    G[z] <- NA
    R[z] <- NA
  }
  # minfi's 450K manifest names two probes "BS Conversion I C1" / "BS Conversion I U1".
  nm <- sub("^BS Conversion I ([CU][0-9])$", "BS Conversion I-\\1", ci$ExtendedType)
  list(controls = data.frame(group = toupper(ci$Type), name = nm, index = seq_len(nrow(ci)),
                             stringsAsFactors = FALSE),
       ctrlG = G, ctrlR = R)
}

# Illumina BeadArray Controls Reporter metrics, one numeric vector per metric with a
# "threshold" attribute (as ewastools::control_metrics(FFPE = FALSE)).
.qc_control_metrics <- function(raw) {
  ctl <- raw$controls
  G <- raw$ctrlG
  R <- raw$ctrlR
  sel <- function(group = NULL, pattern = NULL, name = NULL) {
    i <- rep(TRUE, nrow(ctl))
    if (!is.null(group)) i <- i & ctl$group == group
    if (!is.null(pattern)) i <- i & grepl(pattern, ctl$name)
    if (!is.null(name)) i <- i & ctl$name == name
    ctl$index[i]
  }
  cmax <- function(M, i) apply(M[i, , drop = FALSE], 2, max)
  cmin <- function(M, i) apply(M[i, , drop = FALSE], 2, min)
  one <- function(M, i) M[i[1], ]
  th <- function(x, t) {
    x <- as.numeric(x)
    attr(x, "threshold") <- t
    x
  }
  cg <- sel("EXTENSION", "^Extension \\([CG]\\)$")
  at <- sel("EXTENSION", "^Extension \\([AT]\\)$")
  bkgG <- cmax(G, at) + 3000
  bs1u12 <- sel("BISULFITE CONVERSION I", "BS Conversion I-U[12]")
  bs1u456 <- sel("BISULFITE CONVERSION I", "BS Conversion I-U[456]")
  b2 <- sel("BISULFITE CONVERSION II")
  s2 <- sel("SPECIFICITY II")
  npcg <- sel("NON-POLYMORPHIC", "NP \\([CG]\\)")
  npat <- sel("NON-POLYMORPHIC", "NP \\([AT]\\)")
  m <- list()
  m$Restoration <- th(one(G, sel("RESTORATION")) / bkgG, 0)
  m$`Bisulfite Conversion I Green` <- th(cmin(G, sel("BISULFITE CONVERSION I", "BS Conversion I-C[12]")) /
                                           cmax(G, bs1u12), 1)
  m$`Bisulfite Conversion I Green (Bkg)` <- th(bkgG / cmax(G, bs1u12), 1)
  m$`Bisulfite Conversion I Red` <- th(cmin(R, sel("BISULFITE CONVERSION I", "BS Conversion I-C[456]")) /
                                         cmax(R, bs1u456), 1)
  m$`Bisulfite Conversion I Red (Bkg)` <- th((cmax(R, cg) + 3000) / cmax(R, bs1u456), 1)
  m$`Bisulfite Conversion II` <- th(cmin(R, b2) / cmax(G, b2), 1)
  m$`Bisulfite Conversion II (Bkg)` <- th(bkgG / cmax(G, b2), 1)
  m$`Hybridization High/Medium` <- th(one(G, sel(name = "Hyb (High)")) / one(G, sel(name = "Hyb (Medium)")), 1)
  m$`Hybridization Medium/Low` <- th(one(G, sel(name = "Hyb (Medium)")) / one(G, sel(name = "Hyb (Low)")), 1)
  m$`Extension Green` <- th(cmin(G, cg) / cmax(G, at), 5)
  m$`Extension Red` <- th(cmin(R, at) / cmax(R, cg), 5)
  m$`Staining Green` <- th(one(G, sel(name = "Biotin (High)")) / one(G, sel(name = "Biotin (Bkg)")), 5)
  m$`Staining Red` <- th(one(R, sel(name = "DNP (High)")) / one(R, sel(name = "DNP (Bkg)")), 5)
  m$`Target Removal 1` <- th(bkgG / one(G, sel(name = "Target Removal 1")), 1)
  m$`Target Removal 2` <- th(bkgG / one(G, sel(name = "Target Removal 2")), 1)
  m$`Specificity I Green` <- th(cmin(G, sel("SPECIFICITY I", "Mismatch [123] \\(PM\\)")) /
                                  cmax(G, sel("SPECIFICITY I", "Mismatch [123] \\(MM\\)")), 1)
  m$`Specificity I Red` <- th(cmin(R, sel("SPECIFICITY I", "Mismatch [456] \\(PM\\)")) /
                                cmax(R, sel("SPECIFICITY I", "Mismatch [456] \\(MM\\)")), 1)
  m$`Specificity II` <- th(cmin(R, s2) / cmax(G, s2), 1)
  m$`Specificity II (Bkg)` <- th(bkgG / cmax(G, s2), 1)
  m$`Non-polymorphic Green` <- th(cmin(G, npcg) / cmax(G, npat), 5)
  m$`Non-polymorphic Red` <- th(cmin(R, npat) / cmax(R, npcg), 5)
  m
}

# Unnormalized beta values of the rs (SNP) probes, M / (M + U) with intensities floored at 1;
# intensities read from zero beads are NA. Type I: M and U in the probe's colour channel;
# type II: M green, U red.
.qc_snp_beta <- function(rg, nbeads = NULL, pinfo = .qc_minfi_pinfo(rg)) {
  G <- minfi::getGreen(rg)
  R <- minfi::getRed(rg)
  s1 <- pinfo("SnpI")
  s2 <- pinfo("SnpII")
  pick <- function(addr, col) {
    addr <- as.character(addr)
    out <- matrix(NA_real_, length(addr), ncol(G))
    g <- col == "Grn"
    out[g, ] <- G[addr[g], , drop = FALSE]
    out[!g, ] <- R[addr[!g], , drop = FALSE]
    out
  }
  M <- rbind(pick(s1$AddressB, s1$Color), G[as.character(s2$AddressA), , drop = FALSE])
  U <- rbind(pick(s1$AddressA, s1$Color), R[as.character(s2$AddressA), , drop = FALSE])
  M <- pmax(M, 1)
  U <- pmax(U, 1)
  if (!is.null(nbeads)) {
    zero <- function(a) {
      z <- nbeads[as.character(a), , drop = FALSE]
      !is.na(z) & z == 0
    }
    M[zero(c(s1$AddressB, s2$AddressA))] <- NA
    U[zero(c(s1$AddressA, s2$AddressA))] <- NA
  }
  b <- M / (M + U)
  dimnames(b) <- list(c(s1$Name, s2$Name), colnames(G))
  b
}

# Genotype calls from SNP beta values with ewastools' fixed three-component beta mixture plus an
# outlier component (call_genotypes(learn = FALSE)). Returns per-value outlier probabilities and
# the posterior probabilities of the three genotypes.
.qc_call_genotypes <- function(snps) {
  x <- as.numeric(snps)
  ok <- !is.na(x)
  alpha <- 0.06646095
  pi <- c(0.2818387, 0.4330363, 0.285125)
  shape1 <- c(2.206479, 80.830012, 40.640821)
  shape2 <- c(38.043029, 84.4119, 3.315509)
  dens <- vapply(1:3, function(k) pi[k] * stats::dbeta(x[ok], shape1[k], shape2[k]), numeric(sum(ok)))
  dens <- (1 - alpha) * matrix(dens, ncol = 3)
  tot <- rowSums(dens)
  fill <- function(v) {
    out <- rep(NA_real_, length(x))
    out[ok] <- v
    dim(out) <- dim(snps)
    out
  }
  list(snps = snps, outliers = fill(alpha / (alpha + tot)),
       gamma = lapply(1:3, function(k) fill(dens[, k] / tot)))
}

# Pairwise genotype agreement between samples; lower triangle filled, NA elsewhere.
.qc_genotype_agreement <- function(gt) {
  w <- 1 - gt$outliers
  J <- ncol(w)
  d <- matrix(NA_real_, J, J)
  for (j in seq_len(J)) {
    tmp <- Reduce(`+`, lapply(gt$gamma, function(g) (w * g) * (w[, j] * g[, j])))
    d[, j] <- colSums(tmp, na.rm = TRUE) / colSums(w * w[, j], na.rm = TRUE)
  }
  d[upper.tri(d, diag = TRUE)] <- NA_real_
  d
}

# Connected components of an undirected graph given as an edge list; numbered by first appearance.
.qc_components <- function(from, to, n) {
  from <- as.integer(from)
  to <- as.integer(to)
  parent <- seq_len(n)
  find <- function(i) {
    while (parent[i] != i) i <- parent[i]
    i
  }
  for (k in seq_along(from)) {
    a <- find(from[k])
    b <- find(to[k])
    if (a != b) parent[max(a, b)] <- min(a, b)
  }
  roots <- vapply(seq_len(n), find, integer(1))
  match(roots, unique(roots))
}

# Predicted donor per sample: samples whose genotype agreement exceeds 0.9 share a donor.
.qc_enumerate_donors <- function(gt) {
  d <- .qc_genotype_agreement(gt)
  e <- which(!is.na(d) & d > 0.9, arr.ind = TRUE)
  .qc_components(e[, 1], e[, 2], ncol(d))
}

# Sample pairs whose genotype agreement contradicts the donor labels: different donors with
# agreement >= 0.9, or the same donor with agreement <= 0.9. One row per pair; `group` numbers
# the connected sets of conflicting samples. NULL when there is no conflict.
.qc_snp_conflicts <- function(gt, donor_ids, sample_ids) {
  stopifnot(!anyDuplicated(sample_ids), length(sample_ids) == ncol(gt$snps))
  d <- .qc_genotype_agreement(gt)
  e <- which(!is.na(d), arr.ind = TRUE)
  out <- data.frame(donor1 = donor_ids[e[, 2]], sample1 = sample_ids[e[, 2]],
                    donor2 = donor_ids[e[, 1]], sample2 = sample_ids[e[, 1]],
                    agreement = d[e], stringsAsFactors = FALSE)
  out <- out[!(out$donor1 != out$donor2 & out$agreement < 0.9) &
               !(out$donor1 == out$donor2 & out$agreement > 0.9), , drop = FALSE]
  if (!nrow(out)) return(NULL)
  ids <- unique(c(out$sample1, out$sample2))
  comp <- .qc_components(match(out$sample1, ids), match(out$sample2, ids), length(ids))
  out$group <- comp[match(out$sample1, ids)]
  rownames(out) <- NULL
  out
}
