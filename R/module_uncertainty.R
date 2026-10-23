#================================================================
# Resampling-based uncertainty for IDS and Angle
#
# Bootstrap confidence intervals for the sample-level scores of AnalyzeImprintStatus() and a
# permutation null for their dependence on parental origin (arguments n_boot / n_perm), and
# CalibrateIDS() for cohort-specific cutoffs from control samples. The reference (0.5 or control medians) is held fixed: the
# intervals describe probe- and ICR-level sampling variability given that reference.

# Evaluate `expr` with a fixed seed and restore the caller's random number stream afterwards.
.with_seed <- function(seed, expr) {
  if (is.null(seed)) return(expr)
  env <- globalenv()
  had_seed <- exists(".Random.seed", envir = env, inherits = FALSE)
  old_seed <- if (had_seed) get(".Random.seed", envir = env, inherits = FALSE)
  on.exit({
    if (had_seed) assign(".Random.seed", old_seed, envir = env)
    else if (exists(".Random.seed", envir = env, inherits = FALSE)) rm(".Random.seed", envir = env)
  }, add = TRUE)
  set.seed(seed)
  force(expr)
}

# Row-index groups of one parental class: one group per ICR, and one per probe outside an
# annotated ICR (or per probe when no ICR annotation is available).
.icr_units <- function(icr) {
  icr <- as.character(icr)
  key <- ifelse(is.na(icr) | !nzchar(icr), paste0("<probe ", seq_along(icr), ">"), icr)
  unname(split(seq_along(key), factor(key, levels = unique(key))))
}

# Deviation of one class from a set of drawn row groups: the median over the pooled rows
# (averaged over Infinium design types when `design` is given), or, with `by_icr`, the median
# within each group followed by the median across groups.
.draw_deviation <- function(D, draws, design = NULL, by_icr = FALSE) {
  if (by_icr) {
    per_icr <- vapply(draws, function(r) matrixStats::colMedians(D, rows = r, na.rm = TRUE), numeric(ncol(D)))
    return(matrixStats::rowMedians(matrix(per_icr, nrow = ncol(D)), na.rm = TRUE))
  }
  rows <- unlist(draws, use.names = FALSE)
  if (is.null(design)) return(matrixStats::colMedians(D, rows = rows, na.rm = TRUE))
  per_type <- lapply(split(rows, design[rows]), function(r) matrixStats::colMedians(D, rows = r, na.rm = TRUE))
  Reduce(`+`, per_type) / length(per_type)
}

# One bootstrap draw: resample the groups (two-stage) or keep them, then resample rows within each.
.resample_units <- function(units, two_stage) {
  if (two_stage) units <- units[sample.int(length(units), length(units), replace = TRUE)]
  lapply(units, function(r) r[sample.int(length(r), length(r), replace = TRUE)])
}

# Sampling plan of one class for the bootstrap.
#   resample = "icr": two-stage cluster bootstrap (ICRs, then probes within ICRs); a class with a
#     single ICR reduces to resampling its probes.
#   resample = "probe": probes within the class (within design types for balanced scoring), or,
#     with ICR-balanced scoring, probes within each ICR.
.boot_plan <- function(icr, design, resample, by_icr) {
  n <- length(icr)
  if (by_icr || resample == "icr") return(list(units = .icr_units(icr), two_stage = resample == "icr"))
  units <- if (is.null(design)) list(seq_len(n)) else unname(split(seq_len(n), design))
  list(units = units, two_stage = FALSE)
}

# Percentile interval of angles on the circle, centred on the observed angle.
.angle_interval <- function(angles, observed, probs) {
  d <- ((angles - observed + 180) %% 360) - 180
  q <- stats::quantile(d, probs, na.rm = TRUE, names = FALSE)
  (observed + q + 360) %% 360
}

# Bootstrap intervals for IDS and Angle, and permutation p-values for the origin contrast
# |paternal deviation - maternal deviation|.
#   pat, mat: lists with D (probe-by-sample deviations from the reference), icr (ICR name per
#     row, or NULL) and design (Infinium type per row for balanced scoring, or NULL). With
#     by_icr, rows are limited to ICRs with at least min_probes probes.
#   obs: list with the observed paternal and maternal deviations (pat, mat), ids, angle and
#     mechanism per sample.
.imprint_uncertainty <- function(pat, mat, obs, by_icr, n_boot, n_perm, conf_level, resample, permute, seed) {
  samples <- colnames(pat$D)
  out <- data.frame(row.names = samples)
  probs <- c((1 - conf_level) / 2, 1 - (1 - conf_level) / 2)
  ids_of <- function(p, m) sqrt(p^2 + m^2)
  angle_of <- function(p, m) (atan2(m, p) * 180 / pi + 360) %% 360

  .with_seed(seed, {
    if (n_boot > 0) {
      plan_p <- .boot_plan(pat$icr, pat$design, resample, by_icr)
      plan_m <- .boot_plan(mat$icr, mat$design, resample, by_icr)
      ids_b <- angle_b <- matrix(NA_real_, nrow = n_boot, ncol = length(samples))
      for (b in seq_len(n_boot)) {
        p <- .draw_deviation(pat$D, .resample_units(plan_p$units, plan_p$two_stage), pat$design, by_icr)
        m <- .draw_deviation(mat$D, .resample_units(plan_m$units, plan_m$two_stage), mat$design, by_icr)
        ids_b[b, ] <- ids_of(p, m)
        angle_b[b, ] <- angle_of(p, m)
      }
      ids_ci <- matrixStats::colQuantiles(ids_b, probs = probs, na.rm = TRUE, drop = FALSE)
      angle_ci <- t(vapply(seq_along(samples), function(j) .angle_interval(angle_b[, j], obs$angle[j], probs),
                           numeric(2)))
      support <- vapply(seq_along(samples), function(j) {
        ok <- !is.na(ids_b[, j])
        mean(classify_mechanism(angle_b[ok, j], ids = ids_b[ok, j], roi_cutoff = 0.2) == obs$mechanism[j])
      }, numeric(1))
      out$IDS_lower <- round(ids_ci[, 1], 3)
      out$IDS_upper <- round(ids_ci[, 2], 3)
      out$Angle_lower <- round(angle_ci[, 1], 1)
      out$Angle_upper <- round(angle_ci[, 2], 1)
      out$Mechanism_support <- round(support, 3)
      out$n_boot <- as.integer(n_boot)
      out$resample <- resample
    }

    if (n_perm > 0) {
      # Pool both classes and reassign the parental labels, keeping the number of paternal
      # units (per design type for balanced scoring).
      D <- rbind(pat$D, mat$D)
      n_pat <- nrow(pat$D)
      design <- if (is.null(pat$design)) NULL else c(pat$design, mat$design)
      if (permute == "icr") {
        units <- c(.icr_units(pat$icr), lapply(.icr_units(mat$icr), `+`, n_pat))
        pat_units <- length(.icr_units(pat$icr))
      } else {
        units <- as.list(seq_len(nrow(D)))
        is_pat <- seq_len(nrow(D)) <= n_pat
      }
      # The statistic is the origin contrast |pat - mat|: zero for a shift shared by all probes, large
      # for single- or opposite-axis deviations. (IDS itself is not suitable: when one class has far
      # more probes, shuffled labels give both classes the majority's deviation.)
      contrast_obs <- abs(obs$pat - obs$mat)
      exceed <- numeric(length(samples))
      for (k in seq_len(n_perm)) {
        if (permute == "icr") {
          pick <- sample.int(length(units), pat_units)
          p_units <- units[pick]
          m_units <- units[-pick]
        } else if (is.null(design)) {
          lab <- sample(is_pat)
          p_units <- units[lab]
          m_units <- units[!lab]
        } else {
          lab <- is_pat
          for (t in unique(design)) {
            i <- which(design == t)
            lab[i] <- lab[i][sample.int(length(i))]
          }
          p_units <- units[lab]
          m_units <- units[!lab]
        }
        contrast_k <- abs(.draw_deviation(D, p_units, design, by_icr) - .draw_deviation(D, m_units, design, by_icr))
        exceed <- exceed + (!is.na(contrast_k) & contrast_k >= contrast_obs - 1e-12)
      }
      out$origin_perm_p <- signif((1 + exceed) / (1 + n_perm), 3)
      out$n_perm <- as.integer(n_perm)
      out$permute <- permute
    }
  })
  rownames(out) <- NULL
  out
}


#' Calibrate the IDS Cutoff on Control Samples
#'
#' Derives a cohort-specific IDS cutoff from control samples of the same tissue, platform and
#' preprocessing, and expresses each sample's IDS relative to the control distribution. The
#' package default cutoff (0.2) and confidence tiers are exploratory; control IDS depends on
#' tissue and sample type, so a cutoff calibrated on matched controls is preferable when such
#' controls exist.
#'
#' Control IDS should come from the same scoring run as the cases. With a control reference
#' (`reference_group` or `reference_samples` in [AnalyzeImprintStatus()]) each control is scored
#' leave-one-out, so its IDS is an honest estimate of control variation; with the fixed 0.5
#' reference the control IDS measures the controls' offset from 0.5.
#'
#' @param results A data frame returned by [AnalyzeImprintStatus()] (for example
#'   `results(x)[["AnalyzeImprintStatus.selected"]]`), with columns `Sample_Name` and `IDS`.
#' @param controls Control samples: `Sample_Group` value(s), sample names, or a logical vector
#'   along the rows of `results`.
#' @param method How the cutoff is derived:
#'   - `"quantile"` (default): the `probs` quantile of control IDS;
#'   - `"max"`: the maximum control IDS;
#'   - `"youden"`: the cutoff maximizing sensitivity + specificity between `cases` and
#'     controls (requires `cases`). Candidate cutoffs lie midway between adjacent observed IDS
#'     values; among tied optima the middle one is taken.
#' @param probs Quantile used by `method = "quantile"` (default 0.99).
#' @param cases Optional case samples, given like `controls`. Required for `"youden"`; when
#'   given, the area under the ROC curve (cases versus controls) is reported.
#'
#' @return `results` with added columns `IDS_z` (robust z-score, `(IDS - median) / MAD` of the
#'   controls, with the MAD floored at 0.01), `IDS_control_percentile` (percentage of controls
#'   with a lower or equal IDS) and `Status_calibrated` (`"Imprinting Alteration"` when
#'   `IDS > cutoff`, otherwise `"Normal"`; for `"youden"`, `IDS >= cutoff`). The attribute
#'   `calibration` is a one-row data frame with the method, cutoff, number of controls, control
#'   median and maximum IDS, and the AUC and Youden sensitivity/specificity when cases are given.
#' @export
#'
#' @examples
#' res <- data.frame(Sample_Name = paste0("S", 1:8),
#'                   Sample_Group = rep(c("control", "case"), each = 4),
#'                   IDS = c(0.03, 0.05, 0.04, 0.08, 0.30, 0.12, 0.45, 0.26))
#' cal <- CalibrateIDS(res, controls = "control", method = "max", cases = "case")
#' attr(cal, "calibration")
CalibrateIDS <- function(results, controls, method = c("quantile", "max", "youden"), probs = 0.99,
                         cases = NULL) {
  method <- match.arg(method)
  if (!is.data.frame(results) || !all(c("Sample_Name", "IDS") %in% colnames(results))) {
    stop("results must be a data frame with Sample_Name and IDS columns (output of AnalyzeImprintStatus()).")
  }
  if (!is.numeric(probs) || length(probs) != 1L || is.na(probs) || probs <= 0 || probs > 1) {
    stop("probs must be a single number in (0, 1].")
  }
  select <- function(which, what) {
    if (is.logical(which)) {
      if (length(which) != nrow(results)) stop(what, " given as a logical vector must have one value per row of results.")
      idx <- which %in% TRUE
    } else if (is.character(which)) {
      groups <- if ("Sample_Group" %in% colnames(results)) results$Sample_Group else character(0)
      idx <- results$Sample_Name %in% which | groups %in% which
    } else {
      stop(what, " must be Sample_Group values, sample names or a logical vector.")
    }
    if (!any(idx)) stop("No ", what, " found in results.")
    idx
  }
  is_ctrl <- select(controls, "controls")
  is_case <- if (is.null(cases)) NULL else select(cases, "cases")
  if (!is.null(is_case) && any(is_case & is_ctrl)) stop("Samples cannot be both controls and cases.")
  if (method == "youden" && is.null(is_case)) stop("method = \"youden\" requires cases.")

  ctrl <- results$IDS[is_ctrl]
  ctrl <- ctrl[!is.na(ctrl)]
  if (length(ctrl) < 2L) stop("At least two controls with an IDS are needed for calibration.")
  if (length(ctrl) < 5L) warning("Calibration on ", length(ctrl), " controls; at least 5 tissue-matched controls are recommended.")

  auc <- sens <- spec <- NA_real_
  if (!is.null(is_case)) {
    case <- results$IDS[is_case]
    case <- case[!is.na(case)]
    if (!length(case)) stop("No cases with an IDS.")
    r <- rank(c(case, ctrl))
    auc <- (sum(r[seq_along(case)]) - length(case) * (length(case) + 1) / 2) / (length(case) * length(ctrl))
  }
  cutoff <- switch(method,
    quantile = stats::quantile(ctrl, probs, names = FALSE, type = 7),
    max = max(ctrl),
    youden = {
      # Candidate cutoffs midway between adjacent observed values; among tied optima the middle one,
      # so that perfectly separated groups get a cutoff in the middle of the gap.
      v <- sort(unique(c(case, ctrl)))
      cand <- if (length(v) > 1L) (v[-1] + v[-length(v)]) / 2 else v
      j <- vapply(cand, function(cu) mean(case >= cu) + mean(ctrl < cu) - 1, numeric(1))
      tied <- which(j >= max(j) - 1e-12)
      cand[tied[ceiling((length(tied) + 1) / 2)]]
    })
  if (!is.null(is_case)) {
    sens <- if (method == "youden") mean(case >= cutoff) else mean(case > cutoff)
    spec <- if (method == "youden") mean(ctrl < cutoff) else mean(ctrl <= cutoff)
  }

  med <- stats::median(ctrl)
  spread <- max(stats::mad(ctrl), 0.01)
  results$IDS_z <- round((results$IDS - med) / spread, 2)
  results$IDS_control_percentile <- round(100 * vapply(results$IDS, function(v) mean(ctrl <= v), numeric(1)), 1)
  altered <- if (method == "youden") results$IDS >= cutoff else results$IDS > cutoff
  results$Status_calibrated <- ifelse(altered, "Imprinting Alteration", "Normal")
  attr(results, "calibration") <- data.frame(
    method = method, probs = if (method == "quantile") probs else NA_real_, cutoff = round(cutoff, 3),
    n_controls = length(ctrl), control_median = round(med, 3), control_max = round(max(ctrl), 3),
    n_cases = if (is.null(is_case)) NA_integer_ else sum(is_case), AUC = round(auc, 3),
    sensitivity = round(sens, 3), specificity = round(spec, 3), stringsAsFactors = FALSE)
  results
}
