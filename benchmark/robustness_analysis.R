#!/usr/bin/env Rscript
# Robustness analyses of the per-ICR thresholds (protocol amendment 5). They read the unit tables
# written by run_threshold_selection.R and do not change the selected thresholds.
#
# Usage:
#   Rscript robustness_analysis.R --dev DIR --heldout DIR --frozen FILE --out DIR [--n-boot N]
#
#   --dev      output folder of the development run (e1_cv_predictions.tsv)
#   --heldout  output folder of the held-out validation run (validation_e1_units.tsv)
#   --frozen   selected_thresholds.tsv used for the validation run
#
# Outputs (tab-separated, in --out):
#   robust_grid.tsv                 sensitivity/specificity over the (delta, z) grid, development and held-out units
#   robust_selection_bootstrap.tsv  thresholds reselected on bootstrap replicates of the development units, and the
#                                   held-out performance of each replicate's selection
#   robust_selection_summary.tsv    selection frequency of each (delta, z) pair; selection-aware held-out intervals
#   robust_patient_level.tsv        per-patient specificity (controls without any call) and sensitivity
#   robust_subtype.tsv              sensitivity per molecular subtype with exact (Clopper-Pearson) intervals

# Same grid, target and rules as run_threshold_selection.R (protocol version 1.0).
DELTA_GRID <- seq(0.05, 0.30, by = 0.025)
Z_GRID <- c(NA, 2, 2.5, 3, 3.5, 4)
SPEC_TARGET <- 0.995
SEED <- 20261022L

arg_value <- function(flag, default = NULL) {
  a <- commandArgs(TRUE)
  i <- match(flag, a)
  if (is.na(i) || i == length(a)) default else a[i + 1L]
}
dev_dir <- arg_value("--dev")
heldout_dir <- arg_value("--heldout")
frozen_file <- arg_value("--frozen")
out_dir <- arg_value("--out")
n_boot <- as.integer(arg_value("--n-boot", "1000"))
if (is.null(dev_dir) || is.null(heldout_dir) || is.null(frozen_file) || is.null(out_dir)) {
  stop("--dev, --heldout, --frozen and --out are required")
}
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
write_tsv <- function(x, name) write.table(x, file.path(out_dir, name), sep = "\t", quote = FALSE, row.names = FALSE)

read_units <- function(f) {
  u <- read.delim(f, stringsAsFactors = FALSE)
  u$positive <- as.logical(u$positive)
  u$hit <- as.logical(u$hit)
  u
}
dev <- read_units(file.path(dev_dir, "e1_cv_predictions.tsv"))
held <- read_units(file.path(heldout_dir, "validation_e1_units.tsv"))
fz <- read.delim(frozen_file, stringsAsFactors = FALSE, colClasses = "character")
f_delta <- as.numeric(fz$value[fz$parameter == "delta_cutoff"])
f_z_raw <- fz$value[fz$parameter == "z_cutoff"]
f_z <- if (f_z_raw == "off") NA else as.numeric(f_z_raw)

# ---------------------------------------------------------------- rules (copied from run_threshold_selection.R)
called <- function(dev, z, delta, zc) abs(dev) >= delta & (is.na(zc) | is.na(z) | abs(z) >= zc)
detect <- function(u, delta, zc) {
  cl <- called(u$deviation, u$z, delta, zc)
  dir <- ifelse(u$deviation >= 0, "gain", "loss")
  ifelse(u$positive, cl & dir == u$expected, cl)
}
metrics <- function(u, hit) c(sensitivity = if (any(u$positive)) mean(hit[u$positive]) else NA,
                             specificity = if (any(!u$positive)) 1 - mean(hit[!u$positive]) else NA,
                             n_pos = sum(u$positive), n_neg = sum(!u$positive))
grid <- expand.grid(delta = DELTA_GRID, z = Z_GRID)
eval_grid <- function(u) cbind(grid, t(vapply(seq_len(nrow(grid)), function(i) metrics(u, detect(u, grid$delta[i], grid$z[i])), numeric(4))))
select_e1 <- function(u) {
  g <- eval_grid(u)
  zr <- ifelse(is.na(g$z), -Inf, g$z)
  ok <- !is.na(g$specificity) & g$specificity >= SPEC_TARGET
  if (any(ok)) {
    cand <- g[ok, ]; zc <- zr[ok]
    o <- order(-cand$sensitivity, -cand$delta, -zc)
  } else {
    cand <- g; zc <- zr
    o <- order(-(cand$sensitivity + cand$specificity - 1), -cand$delta, -zc)
  }
  cand[o[1], ]
}
z_label <- function(z) ifelse(is.na(z), "off", as.character(z))

# Patients resampled with replacement within each cohort; returns row indices.
cluster_draw <- function(u) {
  keys <- split(seq_len(nrow(u)), paste(u$dataset, u$Sample_Name, sep = "\r"))
  by_ds <- split(names(keys), sub("\r.*$", "", names(keys)))
  pick <- unlist(lapply(by_ds, function(s) s[sample.int(length(s), length(s), replace = TRUE)]), use.names = FALSE)
  unlist(keys[pick], use.names = FALSE)
}

# ---------------------------------------------------------------- 1. stability surface
g_dev <- eval_grid(dev)
g_held <- eval_grid(held)
surface <- rbind(data.frame(set = "development (all units)", g_dev), data.frame(set = "held-out", g_held))
surface$z <- z_label(surface$z)
surface$selected <- abs(surface$delta - f_delta) < 1e-9 & surface$z == z_label(f_z)
write_tsv(surface, "robust_grid.tsv")

# ---------------------------------------------------------------- 2. selection-aware intervals
set.seed(SEED)
boot <- do.call(rbind, lapply(seq_len(n_boot), function(b) {
  s <- select_e1(dev[cluster_draw(dev), ])
  m <- metrics(held, detect(held, s$delta, s$z))
  data.frame(replicate = b, delta = s$delta, z = z_label(s$z), heldout_sensitivity = m[[1]], heldout_specificity = m[[2]])
}))
write_tsv(boot, "robust_selection_bootstrap.tsv")
freq <- aggregate(replicate ~ delta + z, data = boot, FUN = length)
names(freq)[3] <- "n_replicates"
freq$fraction <- round(freq$n_replicates / n_boot, 3)
freq <- freq[order(-freq$n_replicates), ]
q <- function(x) stats::quantile(x, c(0.025, 0.975), na.rm = TRUE, names = FALSE)
m_frozen <- metrics(held, detect(held, f_delta, f_z))
sel_summary <- rbind(
  data.frame(item = paste0("selection frequency: delta=", freq$delta, ", z=", freq$z), estimate = freq$fraction,
             lower = NA, upper = NA),
  data.frame(item = c("held-out sensitivity, frozen thresholds; interval over reselected thresholds",
                      "held-out specificity, frozen thresholds; interval over reselected thresholds"),
             estimate = c(m_frozen[[1]], m_frozen[[2]]),
             lower = c(q(boot$heldout_sensitivity)[1], q(boot$heldout_specificity)[1]),
             upper = c(q(boot$heldout_sensitivity)[2], q(boot$heldout_specificity)[2])))
write_tsv(sel_summary, "robust_selection_summary.tsv")

# ---------------------------------------------------------------- 3. patient-level performance
exact <- function(x, n) if (n > 0) stats::binom.test(x, n)$conf.int[1:2] else c(NA, NA)
patient_level <- function(u, set) {
  per <- do.call(rbind, lapply(split(u, paste(u$dataset, u$Sample_Name, sep = "\r")), function(r)
    data.frame(dataset = r$dataset[1], Sample_Name = r$Sample_Name[1], case = any(r$positive),
               n_icr = nrow(r), any_call = any(r$hit[!r$positive]),
               all_expected = if (any(r$positive)) all(r$hit[r$positive]) else NA,
               any_expected = if (any(r$positive)) any(r$hit[r$positive]) else NA)))
  ctrl <- per[!per$case, ]
  cases <- per[per$case, ]
  row <- function(what, x, n) {
    ci <- exact(x, n)
    data.frame(set = set, measure = what, count = x, n = n, estimate = if (n) x / n else NA, lower = ci[1], upper = ci[2])
  }
  rbind(row("controls without any altered ICR (patient-level specificity)", sum(!ctrl$any_call), nrow(ctrl)),
        row("cases with every expected ICR detected", sum(cases$all_expected), nrow(cases)),
        row("cases with at least one expected ICR detected", sum(cases$any_expected), nrow(cases)),
        data.frame(set = set, measure = "median ICRs scored per control", count = NA, n = nrow(ctrl),
                   estimate = stats::median(ctrl$n_icr), lower = NA, upper = NA))
}
write_tsv(rbind(patient_level(dev, "development (cross-validated)"), patient_level(held, "held-out (frozen)")),
          "robust_patient_level.tsv")

# ---------------------------------------------------------------- 4. per-subtype sensitivity
subtype_of <- function(u) {
  parts <- strsplit(u$label, "|", fixed = TRUE)
  vapply(seq_len(nrow(u)), function(i) {
    p <- parts[[i]]
    if (p[1] == "upd") paste0(if (p[2] == "mat") "maternal" else "paternal", " UPD", p[3])
    else paste0(u$ICR_name[i], " ", u$expected[i])
  }, character(1))
}
subtype_table <- function(u, set) {
  pos <- u[u$positive, ]
  pos$subtype <- subtype_of(pos)
  do.call(rbind, lapply(split(pos, pos$subtype), function(r) {
    ci <- exact(sum(r$hit), nrow(r))
    pts <- unique(paste(r$dataset, r$Sample_Name))
    data.frame(set = set, subtype = r$subtype[1], detected = sum(r$hit), units = nrow(r), patients = length(pts),
               sensitivity = mean(r$hit), lower = ci[1], upper = ci[2], share_of_positive_units = nrow(r) / nrow(pos))
  }))
}
write_tsv(rbind(subtype_table(dev, "development (cross-validated)"), subtype_table(held, "held-out (frozen)")),
          "robust_subtype.tsv")

cat("Robustness outputs in", normalizePath(out_dir), "\n")
print(freq)
print(sel_summary[sel_summary$item %in% sel_summary$item[!is.na(sel_summary$lower)], ])
