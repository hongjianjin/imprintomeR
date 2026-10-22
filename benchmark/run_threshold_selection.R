#!/usr/bin/env Rscript
# Prespecified threshold selection for imprintomeR (benchmark/threshold_selection_protocol.md, version 1.0).
#
# Usage:
#   Rscript run_threshold_selection.R --data-root DIR --out DIR [--manifest FILE] [--labels FILE] [--package DIR]
#   Rscript run_threshold_selection.R --synthetic --out DIR [--package DIR]
#
# --data-root holds one folder per dataset (named as in the manifest) with the listed files.
# --synthetic runs the full pipeline on simulated cohorts built from the panel probes; it only checks
# the code and its output must not be used as a result.

PROTOCOL_VERSION <- "1.0"
DELTA_GRID <- seq(0.05, 0.30, by = 0.025)
Z_GRID <- c(NA, 2, 2.5, 3, 3.5, 4)          # NA = z criterion off
IDS_GRID <- seq(0.05, 0.40, by = 0.01)
TIERS <- c(0.1, 0.2, 0.4)
SPEC_TARGET <- 0.995
MIN_PROBES <- 3L
EXCLUDE_ICR <- "VTRNA2-1:DMR"
MIN_CHROMOSOMES <- 2L
N_BOOT <- 2000L
SEED <- 20261022L
IC1 <- "H19/IGF2:IG-DMR"
IC2 <- "KCNQ1OT1:TSS-DMR"

# ---------------------------------------------------------------- arguments and package
arg_value <- function(flag, default = NULL) {
  a <- commandArgs(TRUE)
  i <- match(flag, a)
  if (is.na(i) || i == length(a)) default else a[i + 1L]
}
synthetic <- "--synthetic" %in% commandArgs(TRUE)
script_dir <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]), mustWork = FALSE))
out_dir <- arg_value("--out")
if (is.null(out_dir)) stop("--out is required")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
pkg <- arg_value("--package")
if (!is.null(pkg)) suppressMessages(pkgload::load_all(pkg, quiet = TRUE)) else suppressMessages(library(imprintomeR))
quiet <- function(expr) { v <- NULL; invisible(capture.output(v <- suppressWarnings(suppressMessages(expr)))); v }

log_file <- file.path(out_dir, "run_log.txt")
log_line <- function(...) cat(paste0(...), "\n", file = log_file, append = TRUE)
cat("", file = log_file)
log_line("imprintomeR threshold selection, protocol version ", PROTOCOL_VERSION, ", run ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"))
log_line("Mode: ", if (synthetic) "SYNTHETIC (code check only; not a result)" else "development data")
log_line("Package: ", if (!is.null(pkg)) normalizePath(pkg) else "installed imprintomeR", "; commit ",
         tryCatch(system2("git", c("-C", shQuote(if (!is.null(pkg)) pkg else "."), "rev-parse", "--short", "HEAD"), stdout = TRUE),
                  error = function(e) "unknown"))
log_line("R: ", R.version.string)

# ---------------------------------------------------------------- synthetic cohorts (code check only)
make_synthetic <- function(root) {
  set.seed(1)
  p <- .load_probesets("hg38")
  sel <- p$selected
  probes <- unique(c(sel$NAME, p$chr11p15$NAME))
  icr_of <- sel$ICR_name[match(probes, sel$NAME)]
  chr_of <- sel$CHR[match(probes, sel$NAME)]
  ori_of <- sel$ORIGIN[match(probes, sel$NAME)]
  chr11p15 <- p$chr11p15
  cohort <- function(name, groups, shift) {
    n <- sum(groups)
    ids <- paste0(name, "_", seq_len(n))
    grp <- rep(names(groups), groups)
    b <- matrix(pmin(pmax(rnorm(length(probes) * n, 0.5, 0.03), 0.01), 0.99), nrow = length(probes), dimnames = list(probes, ids))
    for (j in seq_len(n)) b <- shift(b, j, grp[j])
    dir.create(file.path(root, name), recursive = TRUE, showWarnings = FALSE)
    write.table(data.frame(TargetID = probes, b, check.names = FALSE), file.path(root, name, "beta.txt"), sep = "\t", quote = FALSE, row.names = FALSE)
    write.table(data.frame(Sample_Name = ids, Sample_Group = grp), file.path(root, name, "meta.txt"), sep = "\t", quote = FALSE, row.names = FALSE)
  }
  at <- function(b, j, rows, d) { b[rows, j] <- pmin(pmax(b[rows, j] + d, 0.01), 0.99); b }
  h19 <- probes %in% chr11p15$NAME[chr11p15$ICR_name == IC1] | icr_of %in% IC1
  kv <- probes %in% chr11p15$NAME[chr11p15$ICR_name == IC2] | icr_of %in% IC2
  cohort("SYN_A", c(control = 20, `11p15 LOM` = 10, mUPD_chr7 = 5, MLID = 5, SLID = 5), function(b, j, g) {
    if (g == "11p15 LOM") b <- at(b, j, h19, -0.25)
    if (g == "mUPD_chr7") b <- at(b, j, chr_of %in% "chr7" & ori_of %in% "maternal", 0.3)
    if (g == "MLID") for (i in c("PEG3:TSS-DMR", "MEST:alt-TSS-DMR", "GNAS-AS1:TSS-DMR")) b <- at(b, j, icr_of %in% i, -0.3)
    if (g == "SLID") b <- at(b, j, kv, -0.3)
    b
  })
  cohort("SYN_B", c(control = 20, pUPD11 = 8, BWS = 4), function(b, j, g) {
    if (g == "pUPD11") { b <- at(b, j, kv, -0.25); b <- at(b, j, h19, 0.2) }
    if (g == "BWS" && j %% 2 == 0) b <- at(b, j, kv, -0.25)
    b
  })
  cohort("SYN_C", c(mUPD_chr15 = 6, GW = 2), function(b, j, g) {
    if (g == "mUPD_chr15") { b <- at(b, j, chr_of %in% "chr15" & ori_of %in% "maternal", 0.3); b <- at(b, j, chr_of %in% "chr15" & ori_of %in% "paternal", -0.3) }
    b
  })
  manifest <- data.frame(dataset = c("SYN_A", "SYN_B", "SYN_C"), platform = "450K", beta_file = "beta.txt", meta_file = "meta.txt",
                         group_file = "", group_key = "", group_col = "", controls = c("control", "control", ""),
                         reference = c("self", "self", "external"), external_from = c("", "", "SYN_A,SYN_B"))
  labels <- data.frame(
    dataset = c("SYN_A", "SYN_A", "SYN_A", "SYN_A", "SYN_A", "SYN_B", "SYN_B", "SYN_B", "SYN_C", "SYN_C"),
    Sample_Group = c("control", "11p15 LOM", "mUPD_chr7", "MLID", "SLID", "control", "pUPD11", "BWS",
                     "regex:^mUPD_chr([0-9,]+)$", "regex:.*"),
    label = c("control", "locus|H19/IGF2:IG-DMR=loss", "upd|mat|7", "mlid", "slid", "control",
              "locus|KCNQ1OT1:TSS-DMR=loss|H19/IGF2:IG-DMR=gain", "clinical|BWS", "upd|mat|\\1", "exclude"),
    note = "")
  write.table(manifest, file.path(root, "manifest.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
  write.table(labels, file.path(root, "labels.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
}

if (synthetic) {
  data_root <- file.path(out_dir, "synthetic_data")
  make_synthetic(data_root)
  manifest_file <- file.path(data_root, "manifest.tsv")
  labels_file <- file.path(data_root, "labels.tsv")
} else {
  data_root <- arg_value("--data-root")
  if (is.null(data_root)) stop("--data-root is required unless --synthetic")
  manifest_file <- arg_value("--manifest", file.path(script_dir, "manifest_development.tsv"))
  labels_file <- arg_value("--labels", file.path(script_dir, "labels_development.tsv"))
}
manifest <- read.delim(manifest_file, stringsAsFactors = FALSE, colClasses = "character")
labels <- read.delim(labels_file, stringsAsFactors = FALSE, colClasses = "character", quote = "")
manifest[is.na(manifest)] <- ""

# ---------------------------------------------------------------- input checksums (before any scoring)
sha <- function(f) if (requireNamespace("digest", quietly = TRUE)) digest::digest(file = f, algo = "sha256") else paste0("md5:", unname(tools::md5sum(f)))
inputs <- c(manifest_file, labels_file)
for (i in seq_len(nrow(manifest))) {
  for (col in c("beta_file", "meta_file", "group_file")) {
    if (nzchar(manifest[[col]][i])) inputs <- c(inputs, file.path(data_root, manifest$dataset[i], manifest[[col]][i]))
  }
}
missing_inputs <- inputs[!file.exists(inputs)]
if (length(missing_inputs)) stop("Missing input files:\n", paste(missing_inputs, collapse = "\n"))
log_line("Input checksums (SHA-256 unless prefixed):")
for (f in inputs) log_line("  ", sha(f), "  ", f)

# ---------------------------------------------------------------- data loading and labels
load_dataset <- function(row) {
  dir <- file.path(data_root, row$dataset)
  if (grepl("imprintomeSet\\.rds$", row$beta_file)) {
    x <- readRDS(file.path(dir, row$beta_file))
    b <- as.matrix(beta(x))
    m <- meta(x)[, c("Sample_Name", "Sample_Group")]
  } else {
    bt <- quiet(LoadBeta(file.path(dir, row$beta_file)))
    b <- as.matrix(bt[, vapply(bt, is.numeric, logical(1)), drop = FALSE])
    mt <- read.delim(file.path(dir, row$meta_file), stringsAsFactors = FALSE, check.names = FALSE)
    m <- data.frame(Sample_Name = mt$Sample_Name, Sample_Group = mt$Sample_Group, stringsAsFactors = FALSE)
  }
  if (nzchar(row$group_file)) {
    g <- read.delim(file.path(dir, row$group_file), stringsAsFactors = FALSE, check.names = FALSE)
    sub_grp <- g[[row$group_col]][match(m$Sample_Name, g[[row$group_key]])]
    m$Sample_Group <- ifelse(is.na(sub_grp), m$Sample_Group, sub_grp)
  }
  m <- m[m$Sample_Name %in% colnames(b), , drop = FALSE]
  list(beta = b, meta = m)
}

label_of <- function(dataset, group) {
  rows <- labels[labels$dataset == dataset, , drop = FALSE]
  for (k in seq_len(nrow(rows))) {
    pat <- rows$Sample_Group[k]
    if (startsWith(pat, "regex:")) {
      rx <- sub("^regex:", "", pat)
      if (grepl(rx, group)) return(sub(rx, rows$label[k], group))
    } else if (identical(pat, group)) {
      return(rows$label[k])
    }
  }
  "exclude"
}

datasets <- setNames(lapply(seq_len(nrow(manifest)), function(i) load_dataset(manifest[i, ])), manifest$dataset)
for (d in names(datasets)) {
  datasets[[d]]$meta$label <- vapply(datasets[[d]]$meta$Sample_Group, function(g) label_of(d, g), character(1))
  log_line("Dataset ", d, ": ", ncol(datasets[[d]]$beta), " samples; labels: ",
           paste(names(table(datasets[[d]]$meta$label)), table(datasets[[d]]$meta$label), sep = "=", collapse = ", "))
}

# ---------------------------------------------------------------- scoring (once per dataset)
EXT <- "external control"
score_dataset <- function(i) {
  row <- manifest[i, ]
  d <- datasets[[row$dataset]]
  b <- d$beta
  m <- d$meta[, c("Sample_Name", "Sample_Group", "label")]
  # In-cohort references are the samples labelled "control" (the manifest's controls column documents
  # the source group; Sample_Group may hold GEO sample titles).
  ctrl <- "reference control"
  m$Sample_Group[m$label == "control"] <- ctrl
  if (row$reference == "external") {
    ext <- trimws(strsplit(row$external_from, ",")[[1]])
    # Align probes by name across the cohort and every external source before binding columns.
    probes <- Reduce(intersect, c(list(rownames(b)), lapply(ext, function(e) rownames(datasets[[e]]$beta))))
    eb <- do.call(cbind, lapply(ext, function(e) {
      x <- datasets[[e]]
      x$beta[probes, x$meta$Sample_Name[x$meta$label == "control"], drop = FALSE]
    }))
    colnames(eb) <- paste0("ext_", colnames(eb))
    b <- cbind(b[probes, , drop = FALSE], eb)
    m <- rbind(m, data.frame(Sample_Name = colnames(eb), Sample_Group = EXT, label = "external_control"))
    ctrl <- EXT
  }
  bdf <- data.frame(TargetID = rownames(b), b, check.names = FALSE)
  meta <- m[, c("Sample_Name", "Sample_Group")]
  icr <- quiet(AnalyzeICRStatus(bdf, meta, probeset = "selected", reference_group = ctrl, control_group = ctrl,
                                min_probes = MIN_PROBES, delta_cutoff = 0, z_cutoff = 0))
  icr$label <- m$label[match(icr$Sample_Name, m$Sample_Name)]
  icr$dataset <- row$dataset
  ids <- lapply(c(chr11p15 = "chr11p15", selected = "selected"), function(ps) {
    r <- quiet(AnalyzeImprintStatus(bdf, meta, probeset = ps, reference = "fixed"))
    setNames(r$IDS, r$Sample_Name)
  })
  sl <- data.frame(dataset = row$dataset, Sample_Name = m$Sample_Name, label = m$label,
                   IDS_chr11p15 = unname(ids$chr11p15[m$Sample_Name]), IDS_selected = unname(ids$selected[m$Sample_Name]),
                   stringsAsFactors = FALSE)
  list(icr = icr, sample = sl)
}
scored <- lapply(seq_len(nrow(manifest)), score_dataset)
icr_all <- do.call(rbind, lapply(scored, `[[`, "icr"))
sample_all <- do.call(rbind, lapply(scored, `[[`, "sample"))
icr_all <- icr_all[icr_all$ICR_name != EXCLUDE_ICR, ]

# ---------------------------------------------------------------- E1 units
expected_units <- function(r) {
  lab <- r$label[1]
  parts <- strsplit(lab, "|", fixed = TRUE)[[1]]
  if (parts[1] == "control") return(data.frame(ICR_name = r$ICR_name, expected = "none", positive = FALSE))
  if (parts[1] == "locus") {
    kv <- do.call(rbind, strsplit(parts[-1], "=", fixed = TRUE))
    k <- match(kv[, 1], r$ICR_name)
    k <- k[!is.na(k)]
    return(data.frame(ICR_name = r$ICR_name[k], expected = kv[match(r$ICR_name[k], kv[, 1]), 2], positive = rep(TRUE, length(k))))
  }
  if (parts[1] == "upd") {
    chrs <- paste0("chr", trimws(strsplit(parts[3], ",")[[1]]))
    k <- which(r$CHR %in% chrs)
    gain_origin <- if (parts[2] == "mat") "maternal" else "paternal"
    return(data.frame(ICR_name = r$ICR_name[k], expected = ifelse(r$ORIGIN[k] == gain_origin, "gain", "loss"), positive = rep(TRUE, length(k))))
  }
  NULL
}
unit_rows <- list()
for (key in unique(paste(icr_all$dataset, icr_all$Sample_Name, sep = "\r"))) {
  r <- icr_all[paste(icr_all$dataset, icr_all$Sample_Name, sep = "\r") == key, ]
  e <- expected_units(r)
  if (is.null(e) || !nrow(e)) next
  k <- match(e$ICR_name, r$ICR_name)
  unit_rows[[length(unit_rows) + 1]] <- data.frame(dataset = r$dataset[1], Sample_Name = r$Sample_Name[1], label = r$label[1],
                                                   ICR_name = e$ICR_name, expected = e$expected, positive = e$positive,
                                                   deviation = r$deviation[k], z = r$z[k], stringsAsFactors = FALSE)
}
units <- do.call(rbind, unit_rows)
log_line("E1 units: ", sum(units$positive), " positive, ", sum(!units$positive), " negative, from ",
         length(unique(paste(units$dataset, units$Sample_Name))), " samples")

called <- function(dev, z, delta, zc) abs(dev) >= delta & (is.na(zc) | is.na(z) | abs(z) >= zc)
detect <- function(u, delta, zc) {
  cl <- called(u$deviation, u$z, delta, zc)
  dir <- ifelse(u$deviation >= 0, "gain", "loss")
  ifelse(u$positive, cl & dir == u$expected, cl)
}
metrics <- function(u, hit) c(sensitivity = if (any(u$positive)) mean(hit[u$positive]) else NA,
                             specificity = if (any(!u$positive)) 1 - mean(hit[!u$positive]) else NA,
                             n_pos = sum(u$positive), n_neg = sum(!u$positive))
frozen_file <- arg_value("--frozen")
if (!is.null(frozen_file)) {
  # Held-out validation (protocol section 6): frozen thresholds, no grid search, selection or cross-validation.
  log_line("VALIDATION with frozen thresholds: ", frozen_file, " (", sha(frozen_file), ")")
  fz <- read.delim(frozen_file, stringsAsFactors = FALSE, colClasses = "character")
  fv <- function(p) fz$value[fz$parameter == p]
  f_delta <- as.numeric(fv("delta_cutoff"))
  f_z <- if (fv("z_cutoff") == "off") NA else as.numeric(fv("z_cutoff"))
  units$hit <- detect(units, f_delta, f_z)
  set.seed(SEED)
  ci <- if (nrow(units)) {
    keys <- split(seq_len(nrow(units)), paste(units$dataset, units$Sample_Name, sep = "\r"))
    by_ds <- split(names(keys), sub("\r.*$", "", names(keys)))
    reps <- t(replicate(N_BOOT, {
      idx <- unlist(keys[unlist(lapply(by_ds, function(s) sample(s, length(s), replace = TRUE)), use.names = FALSE)], use.names = FALSE)
      metrics(units[idx, ], units$hit[idx])[1:2]
    }))
    apply(reps, 2, stats::quantile, c(0.025, 0.975), na.rm = TRUE)
  }
  m <- metrics(units, units$hit)
  write.table(data.frame(estimate = "held-out validation (frozen thresholds)", delta_cutoff = f_delta, z_cutoff = fv("z_cutoff"),
                         sensitivity = m[1], sens_lo = ci[1, 1], sens_hi = ci[2, 1], specificity = m[2], spec_lo = ci[1, 2],
                         spec_hi = ci[2, 2], n_pos = m[3], n_neg = m[4]),
              file.path(out_dir, "validation_e1_summary.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
  write.table(do.call(rbind, lapply(split(units, paste(units$dataset, units$label, units$ICR_name, units$expected)), function(u)
    data.frame(dataset = u$dataset[1], label = u$label[1], ICR_name = u$ICR_name[1], expected = u$expected[1], t(metrics(u, u$hit))))),
    file.path(out_dir, "validation_e1_by_label_icr.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
  write.table(units, file.path(out_dir, "validation_e1_units.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
  # E3 at the frozen IDS cutoffs and the tiers (AUC per class), cases against their cohort's controls.
  e3v <- list()
  for (cl in c("chr11p15", "selected")) {
    cut <- suppressWarnings(as.numeric(fv(paste0("ids_cutoff_", cl))))
    for (dd in unique(sample_all$dataset)) {
      s <- sample_all[sample_all$dataset == dd, ]
      lab_class <- ifelse(startsWith(s$label, "locus|") & (grepl(IC1, s$label, fixed = TRUE) | grepl(IC2, s$label, fixed = TRUE)),
                          "chr11p15", ifelse(startsWith(s$label, "upd|"), "selected", NA))
      cases <- s[!is.na(lab_class) & lab_class == cl, ]
      ctrl <- s[s$label %in% c("control", "external_control"), ]
      if (!nrow(cases) || !nrow(ctrl)) next
      col <- paste0("IDS_", cl)
      x <- cases[[col]]; y <- ctrl[[col]]
      r <- rank(c(x, y)); a <- (sum(r[seq_along(x)]) - length(x) * (length(x) + 1) / 2) / (length(x) * length(y))
      for (cc in unique(c(TIERS, if (length(cut) && !is.na(cut)) cut))) {
        is_frozen <- length(cut) && isTRUE(all.equal(cc, cut))
        basis <- if (is_frozen && cc %in% TIERS) "frozen (= tier)" else if (is_frozen) "frozen" else "tier"
        e3v[[length(e3v) + 1]] <- data.frame(class = cl, dataset = dd, cutoff = cc, basis = basis,
                                             sensitivity = mean(x >= cc), specificity = mean(y < cc), AUC = a, n_cases = length(x), n_controls = length(y))
      }
    }
  }
  if (length(e3v)) write.table(do.call(rbind, e3v), file.path(out_dir, "validation_e3_ids.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
  log_line("Validation done: sensitivity ", round(m[1], 3), ", specificity ", round(m[2], 3), " (", m[3], " positive / ", m[4], " negative units)")
  cat(readLines(log_file), sep = "\n")
  quit(save = "no", status = 0)
}

grid <- expand.grid(delta = DELTA_GRID, z = Z_GRID)
eval_grid <- function(u) cbind(grid, t(vapply(seq_len(nrow(grid)), function(i) metrics(u, detect(u, grid$delta[i], grid$z[i])), numeric(4))))
select_e1 <- function(u) {
  g <- eval_grid(u)
  zr <- ifelse(is.na(g$z), -Inf, g$z)
  ok <- !is.na(g$specificity) & g$specificity >= SPEC_TARGET
  if (any(ok)) {
    cand <- g[ok, ]; zc <- zr[ok]
    o <- order(-cand$sensitivity, -cand$delta, -zc)
    rule <- "max sensitivity with specificity >= target"
  } else {
    cand <- g; zc <- zr
    o <- order(-(cand$sensitivity + cand$specificity - 1), -cand$delta, -zc)
    rule <- "max Youden (specificity target not reached)"
  }
  s <- cand[o[1], ]
  s$rule <- rule
  s
}

# ---------------------------------------------------------------- E1 cross-validation, CIs, final selection
cv_rows <- list()
for (k in unique(units$dataset)) {
  train <- units[units$dataset != k, ]
  test <- units[units$dataset == k, ]
  if (!any(train$positive) || !any(!train$positive)) next
  s <- select_e1(train)
  test$hit <- detect(test, s$delta, s$z)
  test$cv_delta <- s$delta
  test$cv_z <- s$z
  cv_rows[[k]] <- test
}
cv <- do.call(rbind, cv_rows)
boot_ci <- function(u, hit_col = "hit") {
  set.seed(SEED)
  keys <- split(seq_len(nrow(u)), paste(u$dataset, u$Sample_Name, sep = "\r"))
  by_ds <- split(names(keys), sub("\r.*$", "", names(keys)))
  reps <- t(replicate(N_BOOT, {
    pick <- unlist(lapply(by_ds, function(s) sample(s, length(s), replace = TRUE)), use.names = FALSE)
    idx <- unlist(keys[pick], use.names = FALSE)
    metrics(u[idx, ], u[[hit_col]][idx])[1:2]
  }))
  apply(reps, 2, stats::quantile, c(0.025, 0.975), na.rm = TRUE)
}
final <- select_e1(units)
units$hit <- detect(units, final$delta, final$z)
summ <- function(u, what) {
  m <- metrics(u, u$hit)
  ci <- boot_ci(u)
  data.frame(estimate = what, sensitivity = m[1], sens_lo = ci[1, 1], sens_hi = ci[2, 1],
             specificity = m[2], spec_lo = ci[1, 2], spec_hi = ci[2, 2], n_pos = m[3], n_neg = m[4], row.names = NULL)
}
e1_summary <- rbind(summ(cv, "cross-validated (leave-one-cohort-out)"), summ(units, "apparent (final thresholds on all data)"))
by_label <- do.call(rbind, lapply(split(cv, paste(cv$dataset, cv$label)), function(u)
  data.frame(dataset = u$dataset[1], label = u$label[1], t(metrics(u, u$hit)), cv_delta = u$cv_delta[1], cv_z = u$cv_z[1])))
write.table(eval_grid(units), file.path(out_dir, "e1_grid.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
write.table(cv, file.path(out_dir, "e1_cv_predictions.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
write.table(e1_summary, file.path(out_dir, "e1_summary.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
write.table(by_label, file.path(out_dir, "e1_cv_by_label.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
log_line("E1 final thresholds: delta_cutoff = ", final$delta, ", z_cutoff = ", ifelse(is.na(final$z), "off", final$z), " (", final$rule, ")")

# ---------------------------------------------------------------- E2 multi-locus flag
flag_at <- function(delta, zc) {
  x <- icr_all[icr_all$label %in% c("mlid", "slid", "control"), ]
  x$hit <- called(x$deviation, x$z, delta, zc)
  do.call(rbind, lapply(split(x, paste(x$dataset, x$Sample_Name, sep = "\r")), function(r)
    data.frame(dataset = r$dataset[1], Sample_Name = r$Sample_Name[1], label = r$label[1], n_altered = sum(r$hit),
               MLID_flag = length(unique(r$CHR[r$hit])) >= MIN_CHROMOSOMES)))
}
e2 <- flag_at(final$delta, final$z)
e2 <- e2[e2$dataset %in% unique(e2$dataset[e2$label %in% c("mlid", "slid")]), ]
e2_summary <- do.call(rbind, lapply(split(e2, e2$label), function(r)
  data.frame(label = r$label[1], n = nrow(r), flagged = sum(r$MLID_flag), rate = mean(r$MLID_flag), median_altered = median(r$n_altered))))
write.table(e2_summary, file.path(out_dir, "e2_mlid.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)

# E2 per individual against the published array-based classes (amendment 4): replicate hybridizations
# are collapsed, and an individual is flagged when every one of its hybridizations is flagged.
e2_class_file <- arg_value("--e2-classes", file.path(script_dir, "e2_array_classes.tsv"))
if (!synthetic && file.exists(e2_class_file)) {
  cls <- read.delim(e2_class_file, stringsAsFactors = FALSE)
  log_line("E2 array classes: ", sha(e2_class_file), "  ", e2_class_file)
  x <- merge(e2, cls[, c("dataset", "Sample_Name", "individual", "array_class")], by = c("dataset", "Sample_Name"))
  per <- do.call(rbind, lapply(split(x, paste(x$dataset, x$individual, sep = "\r")), function(r)
    data.frame(dataset = r$dataset[1], individual = r$individual[1], array_class = r$array_class[1],
               n_hybridizations = nrow(r), MLID_flag = all(r$MLID_flag), n_altered = median(r$n_altered))))
  e2_ind <- do.call(rbind, lapply(split(per, per$array_class), function(r)
    data.frame(array_class = r$array_class[1], individuals = nrow(r), flagged = sum(r$MLID_flag),
               rate = mean(r$MLID_flag), median_altered = median(r$n_altered))))
  write.table(per, file.path(out_dir, "e2_mlid_individuals.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
  write.table(e2_ind, file.path(out_dir, "e2_mlid_array_classes.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
}

# ---------------------------------------------------------------- E3 sample-level IDS cutoff and tiers
class_of <- function(lab) {
  is_11p15 <- startsWith(lab, "locus|") & (grepl(IC1, lab, fixed = TRUE) | grepl(IC2, lab, fixed = TRUE))
  ifelse(is_11p15, "chr11p15", ifelse(startsWith(lab, "upd|"), "selected", NA))
}
e3_rows <- list()
for (cl in c("chr11p15", "selected")) {
  for (d in unique(sample_all$dataset)) {
    s <- sample_all[sample_all$dataset == d, ]
    cases <- s[!is.na(class_of(s$label)) & class_of(s$label) == cl, ]
    if (!nrow(cases)) next
    ctrl <- s[s$label %in% c("control", "external_control"), ]
    col <- paste0("IDS_", cl)
    e3_rows[[length(e3_rows) + 1]] <- data.frame(class = cl, dataset = d, Sample_Name = c(cases$Sample_Name, ctrl$Sample_Name),
                                                 case = c(rep(TRUE, nrow(cases)), rep(FALSE, nrow(ctrl))),
                                                 IDS = c(cases[[col]], ctrl[[col]]))
  }
}
e3 <- do.call(rbind, e3_rows)
auc <- function(x, y) { r <- rank(c(x, y)); (sum(r[seq_along(x)]) - length(x) * (length(x) + 1) / 2) / (length(x) * length(y)) }
ss <- function(u, cut) c(sensitivity = mean(u$IDS[u$case] >= cut), specificity = mean(u$IDS[!u$case] < cut))
select_e3 <- function(u) {
  j <- vapply(IDS_GRID, function(c) sum(ss(u, c)) - 1, numeric(1))
  cand <- IDS_GRID[j == max(j)]
  cand[which.min(abs(cand - 0.2))]
}
e3_summary <- do.call(rbind, lapply(split(e3, e3$class), function(u) {
  cut_final <- select_e3(u)
  cvp <- do.call(rbind, lapply(unique(u$dataset), function(k) {
    tr <- u[u$dataset != k, ]
    te <- u[u$dataset == k, ]
    if (!any(tr$case) || !any(!tr$case)) return(NULL)
    te$cut <- select_e3(tr)
    te
  }))
  cv_ss <- if (!is.null(cvp)) c(sensitivity = mean(cvp$IDS[cvp$case] >= cvp$cut[cvp$case]),
                               specificity = mean(cvp$IDS[!cvp$case] < cvp$cut[!cvp$case])) else c(NA, NA)
  rbind(data.frame(class = u$class[1], cutoff = c(TIERS, cut_final), basis = c(rep("tier", length(TIERS)), "selected (all data)"),
                   t(vapply(c(TIERS, cut_final), function(c) ss(u, c), numeric(2))),
                   AUC = auc(u$IDS[u$case], u$IDS[!u$case]), n_cases = sum(u$case), n_controls = sum(!u$case)),
        data.frame(class = u$class[1], cutoff = NA, basis = "cross-validated (leave-one-cohort-out)", sensitivity = cv_ss[1],
                   specificity = cv_ss[2], AUC = NA, n_cases = sum(u$case), n_controls = sum(!u$case)))
}))
write.table(e3_summary, file.path(out_dir, "e3_ids_cutoffs.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)

# ---------------------------------------------------------------- secondary endpoint: clinical diagnoses without subtype
clin <- icr_all[startsWith(icr_all$label, "clinical|"), ]
if (nrow(clin)) {
  clin$hit <- called(clin$deviation, clin$z, final$delta, final$z)
  clin$dir <- ifelse(clin$deviation >= 0, "gain", "loss")
  sec <- do.call(rbind, lapply(split(clin, paste(clin$dataset, clin$Sample_Name, sep = "\r")), function(r) {
    dx <- sub("^clinical\\|", "", r$label[1])
    exp_hit <- if (dx == "BWS") any(r$hit & ((r$ICR_name == IC2 & r$dir == "loss") | (r$ICR_name == IC1 & r$dir == "gain")))
               else any(r$hit & ((r$ICR_name == IC1 & r$dir == "loss") | (r$CHR == "chr7" & r$ORIGIN == "maternal" & r$dir == "gain")))
    data.frame(dataset = r$dataset[1], diagnosis = dx, Sample_Name = r$Sample_Name[1], expected_locus_call = exp_hit)
  }))
  sec_summary <- do.call(rbind, lapply(split(sec, paste(sec$dataset, sec$diagnosis)), function(r)
    data.frame(dataset = r$dataset[1], diagnosis = r$diagnosis[1], n = nrow(r), with_expected_call = sum(r$expected_locus_call))))
  write.table(sec_summary, file.path(out_dir, "secondary_clinical.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
}

# ---------------------------------------------------------------- frozen thresholds
frozen <- data.frame(parameter = c("delta_cutoff", "z_cutoff", "min_probes", "min_chromosomes", "excluded_icr",
                                   paste0("ids_cutoff_", e3_summary$class[e3_summary$basis == "selected (all data)"])),
                     value = c(final$delta, ifelse(is.na(final$z), "off", final$z), MIN_PROBES, MIN_CHROMOSOMES, EXCLUDE_ICR,
                               e3_summary$cutoff[e3_summary$basis == "selected (all data)"]),
                     protocol_version = PROTOCOL_VERSION, synthetic = synthetic)
write.table(frozen, file.path(out_dir, "selected_thresholds.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
log_line("Done. Outputs in ", normalizePath(out_dir))
cat(readLines(log_file), sep = "\n")
print(e1_summary)
print(e2_summary)
print(e3_summary)
