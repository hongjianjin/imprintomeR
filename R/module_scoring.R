# Auto-refactored from utilities2.R
# Module: scoring

#' @export
DetectMosaicism <- function(res_table, roi_ref_mean = 0.06, roi_ref_sd = 0.03) {
  # 1. Calculate Z-score based on healthy reference distribution
  res_table$IDS_Zscore <- (res_table$IDS - roi_ref_mean) / roi_ref_sd
  
  # 2. Define Mosaicism: 
  # High Z-score (>3) BUT still below the hard 'Alteration' threshold
  res_table$Is_Mosaic <- case_when(
     res_table$IDS >= 0.2 ~ "Constitutive",
    res_table$IDS_Zscore > 3 & res_table$IDS < 0.2 & res_table$consistency >0.8 ~ "High-Confidence Mosaic",
    res_table$IDS_Zscore > 2 & res_table$IDS < 0.2 & res_table$consistency >0.8 ~ "Possible Mosaic",
    TRUE ~ "Stable"
  )
  #The Inner Ellipse (Z < 2): "Stable (ROI)".
  #The Middle Ring (Z 2-3): "Possible Mosaic".
  #The Outer Ring (Z > 3): "Likely Mosaic".
  #Outside the Square: "Constitutive".

  # 3. Estimate Mosaic Percentage
  # Theory: A shift of 0.5 in Beta (from 0.5 to 0 or 1.0) = 100% cells altered.
  # Therefore: % Mosaic = (Abs Deviation from 0.5 / 0.5) * 100
  # Note: This takes the max deviation from either Pat or Mat median
  dev_pat <- abs(res_table$paternal_median - 0.5)
  dev_mat <- abs(res_table$maternal_median - 0.5)
  res_table$Mosaic_Pct_Est <- pmax(dev_pat, dev_mat) / 0.5 * 100
  
  return(res_table)
}


#' Compute Imprint Deviation Score (IDS)
#'
#' Computes the Euclidean distance from the balanced imprinting state
#' \eqn{(0.5, 0.5)} using paternal and maternal median methylation.
#'
#' Formula:
#' \eqn{IDS = sqrt((paternal_median - 0.5)^2 + (maternal_median - 0.5)^2)}
#'
#' @param paternal_median Numeric vector of paternal median beta values.
#' @param maternal_median Numeric vector of maternal median beta values.
#'
#' @return Numeric vector of IDS values.
#' @export
compute_ids <- function(paternal_median, maternal_median) {
  sqrt((paternal_median - 0.5)^2 + (maternal_median - 0.5)^2)
}


#' Compute Mechanism Angle from Maternal/Paternal Medians
#'
#' Computes directional angle in degrees from deviations relative to 0.5,
#' using `atan2(maternal_dev, paternal_dev)` and normalizing to `[0, 360)`.
#'
#' @param paternal_median Numeric vector of paternal median beta values.
#' @param maternal_median Numeric vector of maternal median beta values.
#'
#' @return Numeric vector of angles in degrees, normalized to `[0, 360)`.
#' @export
compute_angle <- function(paternal_median, maternal_median) {
  radians <- atan2(maternal_median - 0.5, paternal_median - 0.5)
  (radians * 180 / pi + 360) %% 360
}


#' Classify Imprinting Mechanism from Angle
#'
#' Maps angle values to 8 mechanism sectors using a 22.5 degree shift and
#' 45 degree bins. Optionally applies ROI override when IDS is provided.
#'
#' @param angle_degrees Numeric vector of angles in degrees `[0, 360)`.
#' @param ids Optional numeric vector of IDS values; when provided, entries with
#'   `ids < roi_cutoff` are labeled as `"ROI"`.
#' @param roi_cutoff Numeric ROI threshold used only when `ids` is provided.
#'
#' @return Character vector of mechanism labels.
#' @export
classify_mechanism <- function(angle_degrees, ids = NULL, roi_cutoff = 0.2) {
  mechanism_labels <- c(
    "Pat-Gain", "Global-Hyper", "Mat-Gain", "Mat-Gain+Pat-Loss",
    "Pat-Loss", "Global-Hypo", "Mat-Loss", "Pat-Gain+Mat-Loss"
  )

  shifted_degrees <- (angle_degrees + 22.5) %% 360
  mechanism <- mechanism_labels[cut(
    shifted_degrees,
    breaks = seq(0, 360, by = 45),
    labels = FALSE,
    include.lowest = TRUE
  )]

  if (!is.null(ids)) {
    mechanism <- ifelse(ids < roi_cutoff, "ROI", as.character(mechanism))
  }

  mechanism
}


#' Compute Allelic Consistency Metrics Per Sample
#'
#' Calculates paternal/maternal concordance and average consistency for each
#' sample based on direction relative to a reference (0.5 by default).
#'
#' @param paternal_beta Numeric matrix/data frame of paternal probes (rows) by
#'   samples (columns).
#' @param maternal_beta Numeric matrix/data frame of maternal probes (rows) by
#'   samples (columns).
#' @param sample_ids Character vector of sample IDs to evaluate.
#' @param paternal_reference,maternal_reference Reference methylation that
#'   direction is measured against: a scalar (default `0.5`), a per-probe
#'   vector, or a probe-by-sample matrix with the same layout as the beta input.
#'
#' @return Data frame with columns `pat_cons`, `mat_cons`, and `consistency`.
#' @export
compute_consistency <- function(paternal_beta, maternal_beta, sample_ids,
                                paternal_reference = 0.5, maternal_reference = 0.5) {
  ref_column <- function(ref, sid) if (is.matrix(ref)) ref[, sid] else ref
  consistency_scores <- t(sapply(sample_ids, function(sid) {
    p_vals <- paternal_beta[, sid]
    m_vals <- maternal_beta[, sid]
    p_dev <- p_vals - ref_column(paternal_reference, sid)
    m_dev <- m_vals - ref_column(maternal_reference, sid)

    p_dir <- if (median(p_dev, na.rm = TRUE) > 0) 1 else -1
    m_dir <- if (median(m_dev, na.rm = TRUE) > 0) 1 else -1

    p_concordance <- if (length(p_vals) > 0) sum(p_dev * p_dir >= 0, na.rm = TRUE) / length(p_vals) else 1
    m_concordance <- if (length(m_vals) > 0) sum(m_dev * m_dir >= 0, na.rm = TRUE) / length(m_vals) else 1

    c(
      pat_cons = p_concordance,
      mat_cons = m_concordance,
      consistency = mean(c(p_concordance, m_concordance))
    )
  }))

  as.data.frame(consistency_scores)
}


#================================================================
# Reference centring helpers

.min_reference_samples <- 3L

# Default DMR_type selection per panel: the core `selected` panel is scored on gametic
# ICRs only (secondary DMRs are tissue-variable and unmethylated in sperm); other
# panels are scored on all probes.
.default_dmr_type <- function(probeset) {
  if (identical(probeset, "selected")) "gametic" else NULL
}
.recommended_reference_samples <- 5L

# Per-probe medians of a probe-by-sample matrix, keeping probe names.
.row_medians <- function(x) {
  stats::setNames(matrixStats::rowMedians(as.matrix(x), na.rm = TRUE), rownames(x))
}

# Turn an external reference (beta matrix/data frame, file path, or a profile from
# BuildReferenceProfile()) into a named per-probe vector with attribute n_samples.
.as_reference_profile <- function(reference_beta) {
  if (is.character(reference_beta) && length(reference_beta) == 1L &&
      grepl("\\.rds$", reference_beta, ignore.case = TRUE) && file.exists(reference_beta)) {
    reference_beta <- readRDS(reference_beta)
  }
  if (is.numeric(reference_beta) && is.null(dim(reference_beta))) {
    if (is.null(names(reference_beta)) || anyNA(names(reference_beta))) {
      stop("A reference profile must be a numeric vector named by probe ID.")
    }
    profile <- reference_beta[!is.na(reference_beta)]
    attr(profile, "n_samples") <- attr(reference_beta, "n_samples", exact = TRUE)
    attr(profile, "normalization") <- attr(reference_beta, "normalization", exact = TRUE)
    return(profile)
  }
  ref <- LoadBeta(reference_beta)
  ref <- ref[, vapply(ref, is.numeric, logical(1)), drop = FALSE]
  if (!ncol(ref)) stop("reference_beta has no numeric sample columns.")
  profile <- .row_medians(ref)
  profile <- profile[!is.na(profile)]
  attr(profile, "n_samples") <- ncol(ref)
  profile
}

# Resolve the per-probe reference as a probe-by-sample matrix aligned to `used`.
# Order of preference: external controls, then in-cohort controls, then the fixed
# 0.5 (used only when no controls are available, unless reference = "fixed").
.resolve_reference <- function(used, meta, reference, reference_group, reference_samples, reference_beta) {
  fixed <- list(matrix = NULL, label = "fixed (0.5)", n = rep(0L, ncol(used)), probes = rownames(used))
  has_external <- !is.null(reference_beta)
  has_internal <- !is.null(reference_group) || !is.null(reference_samples)
  if (!is.null(reference_group) && !is.null(reference_samples)) {
    stop("Supply either reference_group or reference_samples, not both.")
  }
  if (has_external && has_internal) {
    stop("Supply either an external reference (reference_beta) or in-cohort controls ",
         "(reference_group/reference_samples), not both.")
  }
  if (reference == "fixed") {
    if (has_external || has_internal) warning("reference = \"fixed\": supplied controls are ignored and 0.5 is used.")
    return(fixed)
  }
  if (!has_external && !has_internal) {
    if (reference == "controls") {
      stop("reference = \"controls\" requires reference_group, reference_samples or reference_beta.")
    }
    return(fixed)
  }

  # Too few controls: an error when controls were demanded, otherwise fall back to 0.5.
  too_few <- function(n, what) {
    msg <- paste0(what, " has ", n, " sample(s); at least ", .min_reference_samples,
                  " are needed for a control reference")
    if (reference == "controls") stop(msg, ".")
    warning(msg, "; falling back to the fixed 0.5 reference.")
    fixed
  }
  few <- function(n) {
    if (n < .recommended_reference_samples) {
      warning("Control reference built from ", n, " samples; at least ",
              .recommended_reference_samples, " tissue-matched controls are recommended.")
    }
  }

  if (has_external) {
    profile <- .as_reference_profile(reference_beta)
    n_ref <- attr(profile, "n_samples", exact = TRUE)
    if (!is.null(n_ref) && n_ref < .min_reference_samples) return(too_few(n_ref, "reference_beta"))
    if (!is.null(n_ref)) few(n_ref)
    probes <- intersect(rownames(used), names(profile))
    if (!length(probes)) stop("reference_beta shares no probes with the scored probeset.")
    dropped <- nrow(used) - length(probes)
    if (dropped) message("[AnalyzeImprintStatus] ", dropped, " probe(s) absent from reference_beta were dropped.")
    ref <- matrix(profile[probes], nrow = length(probes), ncol = ncol(used),
                  dimnames = list(probes, colnames(used)))
    n_lab <- if (is.null(n_ref)) "" else paste0(", n=", n_ref)
    norm <- attr(profile, "normalization", exact = TRUE)
    if (!is.null(norm) && !identical(norm, "unspecified")) n_lab <- paste0(n_lab, ", ", norm)
    return(list(matrix = ref, label = paste0("external controls", n_lab),
                n = rep(if (is.null(n_ref)) NA_integer_ else as.integer(n_ref), ncol(used)), probes = probes))
  }

  if (!is.null(reference_samples)) {
    unknown <- setdiff(reference_samples, colnames(used))
    if (length(unknown)) {
      stop("reference_samples not found among scored samples: ", paste(unknown, collapse = ", "))
    }
    controls <- unique(reference_samples)
    what <- "reference_samples"
  } else {
    if (!"Sample_Group" %in% colnames(meta)) stop("reference_group requires a Sample_Group column in the metadata.")
    controls <- intersect(meta$Sample_Name[meta$Sample_Group %in% reference_group], colnames(used))
    what <- paste0("reference_group '", paste(reference_group, collapse = "+"), "'")
  }
  if (length(controls) < .min_reference_samples) return(too_few(length(controls), what))
  few(length(controls))

  # Non-control samples share the median over all controls. Each control is scored
  # against the median of the other controls (leave-one-out), not against itself.
  base <- .row_medians(used[, controls, drop = FALSE])
  ref <- matrix(base, nrow = nrow(used), ncol = ncol(used), dimnames = dimnames(used))
  n <- rep(length(controls), ncol(used))
  names(n) <- colnames(used)
  for (sid in controls) {
    ref[, sid] <- .row_medians(used[, setdiff(controls, sid), drop = FALSE])
    n[sid] <- length(controls) - 1L
  }
  list(matrix = ref, label = paste0("in-cohort controls, n=", length(controls)),
       n = unname(n), probes = rownames(used))
}

# Per-sample deviation of one parental class from its reference: the median over
# probes of (beta - reference). With the fixed reference this is median(beta) - 0.5.
# With `design`, the deviation is computed within Infinium type I and type II probes
# separately and the two are averaged, so type composition does not drive the score.
.class_deviation <- function(beta, ref = NULL, design = NULL) {
  deviation <- function(rows) {
    b <- as.matrix(beta[rows, , drop = FALSE])
    if (is.null(ref)) {
      apply(b, 2, median, na.rm = TRUE) - 0.5
    } else {
      apply(b - ref[rows, , drop = FALSE], 2, median, na.rm = TRUE)
    }
  }
  if (is.null(design)) {
    out <- deviation(rownames(beta))
  } else {
    per_type <- lapply(split(rownames(beta), design), deviation)
    out <- Reduce(`+`, per_type) / length(per_type)
  }
  stats::setNames(out, colnames(beta))
}


#================================================================

#' Comprehensive Imprinting Analysis for a Sample Cohort
#'
#' Computes maternal/paternal medians, IDS, angle, mechanism, status, and
#' confidence per sample for a selected probeset. Supports both legacy
#' beta/meta inputs and object-first `ImprintomeSet` input.
#'
#' @param betaFile Data frame/matrix or file path containing probe-by-sample
#'   beta values, or an `ImprintomeSet` object.
#' @param metaFile Metadata data frame or file path. Must be provided unless
#'   `betaFile` is an `ImprintomeSet`.
#' @param probeset Character scalar naming a probeset key.
#' @param ids_cutoff Numeric scalar threshold used to call imprinting
#'   alteration by IDS.
#' @param genome Genome build of the probeset annotation, `"hg19"` or `"hg38"`
#'   (default `"hg38"`). Ignored when `betaFile` is an `ImprintomeSet`, whose own
#'   genome is used.
#' @param dmr_type `DMR_type` values to score:
#'   - `NULL` (default): the panel default. The core `selected` panel is scored
#'     on gametic ICRs only (`"gametic"`); every other panel, and any panel
#'     without a `DMR_type` column, is scored on all probes.
#'   - `"all"`: all probes, including secondary DMRs (the earlier default for
#'     `selected`).
#'   - one or more `DMR_type` values, for example `"gametic"` or
#'     `"secondary"` (secondary DMRs reported separately). Requires a
#'     `DMR_type` column in the probeset.
#'
#'   The `dmr_type` output column records the selection that was applied.
#' @param reference How the balanced reference state is defined.
#'   - `"auto"` (default): use control samples when they are supplied, either
#'     external (`reference_beta`) or in-cohort (`reference_group`/
#'     `reference_samples`). Fall back to the fixed 0.5 only when no controls are
#'     given, or when fewer than 3 are available (with a warning).
#'   - `"controls"`: require a control reference; too few controls is an error.
#'   - `"fixed"`: always use 0.5, the original behaviour.
#'
#'   With controls, each probe's reference is the median beta of that probe
#'   across the controls. Paternal and maternal deviations are medians of
#'   `beta - reference`, and IDS and Angle are computed from these deviations
#'   instead of from `median - 0.5`.
#' @param reference_group Optional `Sample_Group` value(s) whose samples form an
#'   in-cohort control reference. Each control is itself scored against the
#'   other controls (leave-one-out).
#' @param reference_samples Optional character vector of in-cohort control sample
#'   names, used instead of `reference_group`.
#' @param reference_beta Optional external control reference, used when the
#'   cohort has no (or too few) controls. It can be one of:
#'   - a probe-by-sample beta matrix or data frame;
#'   - a beta file path;
#'   - a per-probe profile from [BuildReferenceProfile()], given as the object or
#'     as an `.rds` path.
#'
#'   It should match the cohort's tissue, array type and preprocessing. Probes
#'   absent from the reference are dropped.
#' @param infinium_type Infinium probe design types to score:
#'   - `"all"` (default): all probes;
#'   - `"I"` or `"II"`: only that design type;
#'   - `"balanced"`: compute each parental-class deviation separately within
#'     type I and type II probes, then average them.
#'
#'   Anything other than `"all"` requires an `INFINIUM_DESIGN_TYPE` column in
#'   the probeset.
#'
#' @param balance How probes are pooled into each parental class:
#'   - `"probe"` (default): the median over all probes of the class, so that
#'     probe-rich ICRs weigh more;
#'   - `"icr"`: ICR-balanced, the median within each ICR (see
#'     [AnalyzeICRStatus()]) followed by the median across the class's ICRs, so
#'     that each ICR counts once. Requires an `ICR_name` column; probes outside
#'     annotated ICRs are not used. Cannot be combined with
#'     `infinium_type = "balanced"`.
#' @param min_probes Minimum number of probes for an ICR to count when
#'   `balance = "icr"` (default 3).
#' @param n_boot Number of bootstrap replicates for confidence intervals of IDS
#'   and Angle (default 0, none). Several hundred to a few thousand are typical.
#' @param n_perm Number of permutations for the parental-label null of the
#'   origin contrast (default 0, none).
#' @param conf_level Confidence level of the bootstrap intervals (default 0.95).
#' @param resample Bootstrap resampling unit within each parental class:
#'   - `"icr"` (default): two-stage cluster bootstrap. ICRs are resampled with
#'     replacement, then probes within each drawn ICR, so that correlated probes
#'     of one ICR are not treated as independent. Probes outside annotated ICRs
#'     count as their own cluster, and a class with a single ICR (for example
#'     IC1 or IC2 of `chr11p15`) reduces to resampling its probes. Requires an
#'     `ICR_name` column; otherwise `"probe"` is used, with a message.
#'   - `"probe"`: probes are resampled within the class (within Infinium design
#'     types for `infinium_type = "balanced"`, within ICRs for `balance = "icr"`).
#'     This ignores within-ICR correlation and gives narrower intervals.
#' @param permute Permutation unit for the null:
#'   - `"probe"` (default): the parental labels of probes are shuffled, keeping
#'     the numbers of paternal and maternal probes (per design type for
#'     `infinium_type = "balanced"`);
#'   - `"icr"`: whole ICRs are reassigned; requires at least two annotated ICRs
#'     in each parental class. Always used with `balance = "icr"`.
#' @param seed Optional random seed for `n_boot`/`n_perm`, for reproducible
#'   results; the caller's random number stream is restored afterwards.
#'
#' @section Uncertainty:
#' With `n_boot > 0`, each sample's paternal and maternal deviations are
#' recomputed on resampled probes (see `resample`), and percentile intervals are
#' reported for IDS (`IDS_lower`, `IDS_upper`) and Angle (`Angle_lower`,
#' `Angle_upper`, a circular interval around the observed angle, read clockwise
#' from lower to upper). `Mechanism_support` is the fraction of replicates in
#' the reported `Mechanism` sector (including `"ROI"`), a measure of label
#' stability. The intervals are conditional on the reference: the controls are
#' not resampled. Because IDS is a distance, its interval never includes 0 and is
#' biased upward for samples near balanced imprinting, so it describes stability
#' and ranking rather than testing against 0; the Angle interval is
#' uninformative when the IDS interval reaches the ROI zone.
#'
#' With `n_perm > 0`, `origin_perm_p` tests whether the sample's deviation
#' depends on the parental-origin annotation, as an imprinting defect does,
#' rather than being shared by all probes. The statistic is the origin contrast
#' `|paternal_deviation - maternal_deviation|`, which is zero for a shift common
#' to both classes (Global-Hyper, Global-Hypo) and large for single-axis or
#' opposite-axis deviations; the p-value is
#' `(1 + #{contrast_perm >= contrast}) / (1 + n_perm)` after reassigning the
#' parental labels. IDS itself is not used, because when one class has many more
#' probes, shuffled labels give both classes the majority's deviation. With
#' `permute = "probe"` correlated probes are exchanged individually, so p-values
#' are anti-conservative. p-values are per sample and not adjusted for multiple
#' testing.
#'
#' @return Data frame with sample-level imprinting metrics and labels.
#'   `paternal_deviation` and `maternal_deviation` are the coordinates that IDS
#'   and Angle are computed from. `reference` and `n_reference_samples` describe
#'   the reference used. `balance` records the pooling; with `balance = "icr"`, the columns
#'   `n_paternal_icrs` / `n_maternal_icrs` give the numbers of ICRs used. With
#'   `n_boot > 0`, the columns `IDS_lower`, `IDS_upper`, `Angle_lower`,
#'   `Angle_upper`, `Mechanism_support`, `n_boot` and `resample` are added; with
#'   `n_perm > 0`, `origin_perm_p`, `n_perm` and `permute` (see Uncertainty).
#'   Calibrate the IDS cutoff on controls with [CalibrateIDS()].

#' @export
AnalyzeImprintStatus <- function(betaFile, metaFile,
                                 probeset = probeset_options,
                                 ids_cutoff = 0.2,
                                 genome = "hg38",
                                 dmr_type = NULL,
                                 reference = c("auto", "controls", "fixed"),
                                 reference_group = NULL,
                                 reference_samples = NULL,
                                 reference_beta = NULL,
                                 infinium_type = c("all", "I", "II", "balanced"),
                                 balance = c("probe", "icr"),
                                 min_probes = 3L,
                                 n_boot = 0L,
                                 n_perm = 0L,
                                 conf_level = 0.95,
                                 resample = c("icr", "probe"),
                                 permute = c("probe", "icr"),
                                 seed = NULL) {
  if (missing(metaFile)) metaFile <- NULL
  if (!is.character(probeset) || length(probeset) != 1 || is.na(probeset) || !nzchar(probeset)) {
    stop("probeset must be a single non-empty character value.")
  }
  if (!is.numeric(ids_cutoff) || length(ids_cutoff) != 1 || is.na(ids_cutoff) || !is.finite(ids_cutoff)) {
    stop("ids_cutoff must be a single finite numeric value.")
  }
  if (!is.null(dmr_type) &&
      (!is.character(dmr_type) || !length(dmr_type) || anyNA(dmr_type) || any(!nzchar(dmr_type)))) {
    stop("dmr_type must be NULL or a non-empty character vector.")
  }
  if ("all" %in% dmr_type && length(dmr_type) > 1L) {
    stop("dmr_type = \"all\" cannot be combined with other DMR_type values.")
  }
  reference <- match.arg(reference)
  infinium_type <- match.arg(infinium_type)
  balance <- match.arg(balance)
  if (balance == "icr" && infinium_type == "balanced") {
    stop("infinium_type = \"balanced\" cannot be combined with balance = \"icr\"; use \"I\" or \"II\" to filter design types.")
  }
  if (!is.numeric(min_probes) || length(min_probes) != 1L || is.na(min_probes) || min_probes < 1) {
    stop("min_probes must be a single positive number.")
  }
  for (arg in c("n_boot", "n_perm")) {
    value <- get(arg)
    if (!is.numeric(value) || length(value) != 1L || is.na(value) || value < 0 || value != round(value)) {
      stop(arg, " must be a single non-negative whole number.")
    }
  }
  if (!is.numeric(conf_level) || length(conf_level) != 1L || is.na(conf_level) || conf_level <= 0 || conf_level >= 1) {
    stop("conf_level must be a single number between 0 and 1.")
  }
  resample <- match.arg(resample)
  permute <- match.arg(permute)
  for (arg in c("reference_group", "reference_samples")) {
    value <- get(arg)
    if (!is.null(value) && (!is.character(value) || !length(value) || anyNA(value))) {
      stop(arg, " must be NULL or a non-empty character vector.")
    }
  }

  # 1. Feature Alignment (an ImprintomeSet supplies its own beta, metadata and genome)
  inp <- .load_scoring_input(betaFile, metaFile, probeset, genome)
  meta <- inp$meta
  used <- inp$used
  probesets <- inp$probesets
  sample_ids <- inp$sample_ids

  if (is.null(dmr_type)) {
    # Panel default: gametic ICRs for the core panel when it is DMR-type annotated.
    dmr_type <- .default_dmr_type(probeset)
    if (!is.null(dmr_type) && !"DMR_type" %in% colnames(probesets)) dmr_type <- NULL
  } else if (identical(dmr_type, "all")) {
    dmr_type <- NULL
  }
  if (!is.null(dmr_type)) {
    if (!"DMR_type" %in% colnames(probesets)) {
      stop("Probeset '", probeset, "' has no DMR_type column; dmr_type filtering is unavailable.")
    }
    probesets <- probesets[probesets$DMR_type %in% dmr_type, , drop = FALSE]
  }
  dmr_label <- if (is.null(dmr_type)) "all" else paste(dmr_type, collapse = "+")
  if (infinium_type != "all") {
    if (!"INFINIUM_DESIGN_TYPE" %in% colnames(probesets)) {
      stop("Probeset '", probeset, "' has no INFINIUM_DESIGN_TYPE column; infinium_type filtering is unavailable.")
    }
    if (infinium_type %in% c("I", "II")) {
      probesets <- probesets[probesets$INFINIUM_DESIGN_TYPE %in% infinium_type, , drop = FALSE]
    }
  }

  # Reference: external or in-cohort controls when supplied, otherwise 0.5.
  ref <- .resolve_reference(used, meta, reference, reference_group, reference_samples, reference_beta)

  maternal_probes <- intersect(probesets$NAME[grep("maternal", probesets$ORIGIN, ignore.case = TRUE)], ref$probes)
  paternal_probes <- intersect(probesets$NAME[grep("paternal", probesets$ORIGIN, ignore.case = TRUE)], ref$probes)
  if (!length(maternal_probes) || !length(paternal_probes)) {
    stop("Probeset '", probeset, "' (dmr_type: ", dmr_label, ", infinium_type: ", infinium_type,
         ") has no matched probes for both maternal and paternal origins in the beta matrix.")
  }
  maternal_beta <- used[maternal_probes, , drop = FALSE]
  paternal_beta <- used[paternal_probes, , drop = FALSE]
  maternal_ref <- if (is.null(ref$matrix)) NULL else ref$matrix[maternal_probes, sample_ids, drop = FALSE]
  paternal_ref <- if (is.null(ref$matrix)) NULL else ref$matrix[paternal_probes, sample_ids, drop = FALSE]

  consistency_df <- compute_consistency(
    paternal_beta = paternal_beta,
    maternal_beta = maternal_beta,
    sample_ids = sample_ids,
    paternal_reference = if (is.null(paternal_ref)) 0.5 else paternal_ref,
    maternal_reference = if (is.null(maternal_ref)) 0.5 else maternal_ref
  )

  # 2. Metric Calculation (Median aggregation)
  # Note: apply on 1-row matrix works correctly here
  mat_med <- apply(maternal_beta, 2, median, na.rm = TRUE)
  pat_med <- apply(paternal_beta, 2, median, na.rm = TRUE)

  # Deviations from the reference; with the fixed reference these equal median - 0.5.
  design_of <- function(probes) {
    if (infinium_type == "balanced") probesets$INFINIUM_DESIGN_TYPE[match(probes, probesets$NAME)] else NULL
  }
  n_mat_icrs <- n_pat_icrs <- NA_integer_
  if (balance == "probe") {
    mat_dev <- .class_deviation(maternal_beta, maternal_ref, design_of(maternal_probes))
    pat_dev <- .class_deviation(paternal_beta, paternal_ref, design_of(paternal_probes))
  } else {
    # ICR-balanced: median within each ICR, then median across the class's ICRs.
    if (!"ICR_name" %in% colnames(probesets)) {
      stop("Probeset '", probeset, "' has no ICR_name column; balance = \"icr\" is unavailable.")
    }
    icr_of <- function(probes) probesets$ICR_name[match(probes, probesets$NAME)]
    mat <- .balanced_deviation(maternal_beta, maternal_ref, icr_of(maternal_probes), min_probes)
    pat <- .balanced_deviation(paternal_beta, paternal_ref, icr_of(paternal_probes), min_probes)
    if (!mat$n_icrs || !pat$n_icrs) {
      stop("Probeset '", probeset, "' (dmr_type: ", dmr_label, ") has no maternal or no paternal ICR with at least ",
           min_probes, " matched probes; balance = \"icr\" is unavailable.")
    }
    mat_dev <- stats::setNames(mat$deviation, colnames(maternal_beta))
    pat_dev <- stats::setNames(pat$deviation, colnames(paternal_beta))
    n_mat_icrs <- mat$n_icrs
    n_pat_icrs <- pat$n_icrs
  }

  # 3. Euclidean Distance (IDS) calculation (same as compute_ids() on deviations)
  ids <- sqrt(pat_dev^2 + mat_dev^2)

  # 4. Directional Vector (Angle) (same as compute_angle() on deviations)
  degrees <- (atan2(mat_dev, pat_dev) * 180 / pi + 360) %% 360

  # 5. Define directional categories
  mechanism <- classify_mechanism(degrees)

  # 6. Status and Confidence Logic
  status <- ifelse(ids >= ids_cutoff, "Imprinting Alteration", "Normal")
  confidence <- ifelse(
    ids < 0.1,
    "High (Normal)",
    ifelse(ids < 0.2, "Low (Normal)", ifelse(ids < 0.4, "Moderate (Alteration)", "High (Alteration)"))
  )
  final_mechanism <- classify_mechanism(degrees, ids = ids, roi_cutoff = 0.2)

  # 7. Metadata selection
  cols_to_keep <- intersect(colnames(meta), c("Sample_Name", "Sample_Group", "ID2"))
  meta_selected <- meta[, cols_to_keep, drop = FALSE]

  # 8. Final Results Assembly
  res <- data.frame(
    meta_selected,
    probeset        = probeset,
    dmr_type        = dmr_label,
    infinium_type   = infinium_type,
    reference       = ref$label,
    n_reference_samples = ref$n,
    n_paternal_probes = length(paternal_probes),
    n_maternal_probes = length(maternal_probes),
    balance         = balance,
    n_paternal_icrs = n_pat_icrs,
    n_maternal_icrs = n_mat_icrs,
    paternal_median = round(pat_med, 3),
    maternal_median = round(mat_med, 3),
    paternal_deviation = round(pat_dev, 3),
    maternal_deviation = round(mat_dev, 3),
    consistency_df,
    IDS             = round(ids, 3),
    Angle           = round(degrees, 1),
    Mechanism       = final_mechanism,
    Status          = status,
    Confidence      = confidence,
    stringsAsFactors = FALSE
  )
  # ICR counts only apply to ICR-balanced scoring.
  if (balance != "icr") res$n_paternal_icrs <- res$n_maternal_icrs <- NULL

  # 9. Optional bootstrap intervals and permutation null (unrounded observed scores).
  if (n_boot > 0 || n_perm > 0) {
    has_icr <- "ICR_name" %in% colnames(probesets)
    icr_or_na <- function(probes) {
      if (has_icr) probesets$ICR_name[match(probes, probesets$NAME)] else rep(NA_character_, length(probes))
    }
    if (n_boot > 0 && resample == "icr" && !has_icr) {
      message("[AnalyzeImprintStatus] Probeset '", probeset, "' has no ICR_name column; bootstrap resamples probes.")
      resample <- "probe"
    }
    if (balance == "icr") permute <- "icr"
    class_spec <- function(beta, ref, probes) {
      D <- as.matrix(beta) - (if (is.null(ref)) 0.5 else ref)
      icr <- icr_or_na(probes)
      design <- design_of(probes)
      if (balance == "icr") {
        # Only ICRs with at least min_probes probes, as in the ICR-balanced score.
        sizes <- table(icr[!is.na(icr) & nzchar(icr)])
        keep <- !is.na(icr) & icr %in% names(sizes)[sizes >= min_probes]
        D <- D[keep, , drop = FALSE]
        icr <- icr[keep]
      }
      list(D = D, icr = icr, design = design)
    }
    pat_spec <- class_spec(paternal_beta, paternal_ref, paternal_probes)
    mat_spec <- class_spec(maternal_beta, maternal_ref, maternal_probes)
    if (n_perm > 0 && permute == "icr") {
      n_icrs <- function(icr) length(unique(icr[!is.na(icr) & nzchar(icr)]))
      if (n_icrs(pat_spec$icr) < 2L || n_icrs(mat_spec$icr) < 2L) {
        stop("permute = \"icr\" needs at least two annotated ICRs in each parental class; use permute = \"probe\".")
      }
    }
    unc <- .imprint_uncertainty(
      pat_spec, mat_spec,
      obs = list(pat = unname(pat_dev), mat = unname(mat_dev), ids = unname(ids), angle = unname(degrees),
                 mechanism = final_mechanism),
      by_icr = balance == "icr", n_boot = n_boot, n_perm = n_perm, conf_level = conf_level,
      resample = resample, permute = permute, seed = seed
    )
    res <- cbind(res, unc)
  }

  return(res)
}


#' Build a Reusable Control Reference Profile
#'
#' Summarizes a set of control samples into per-probe median beta values. The
#' result can be passed as `reference_beta` to [AnalyzeImprintStatus()] or
#' [runImprintome()], so that one tissue-matched control set (for example public
#' normal samples) can centre cohorts that have no controls of their own. Save
#' it with `saveRDS()` to reuse it across studies.
#'
#' @param beta Probe-by-sample beta matrix, data frame, file path, a
#'   `MethQcSet` (EPICv2 data must be aggregated first with
#'   `aggregate_probes()`), or an `ImprintomeSet`.
#' @param samples Optional character vector of control sample names; `NULL` uses
#'   all samples.
#' @param probeset Optional probeset name. The profile is limited to its probes.
#'   `NULL` (default) keeps every probe of every probe-level panel of `genome`,
#'   so one profile serves all panels.
#' @param genome Genome build of the probeset annotation, `"hg19"` or `"hg38"`
#'   (default `"hg38"`). Ignored when `beta` is an `ImprintomeSet`, whose own
#'   genome is used.
#' @param normalization Beta normalization of the control data, for example
#'   `"noob"` (see [runMethQC()]). Taken from `qc_params(beta)$normalization`
#'   when `beta` is a `MethQcSet` and this argument is `NULL`. It is recorded in
#'   the profile and reported in the `reference` column of scoring results, so
#'   that a profile can be matched to cohorts preprocessed the same way.
#'
#' @return Named numeric vector of per-probe median beta values, with attributes
#'   `n_samples`, `genome`, `probeset`, and `normalization` (`"unspecified"` when
#'   unknown).
#' @export
BuildReferenceProfile <- function(beta, samples = NULL, probeset = NULL, genome = "hg38", normalization = NULL) {
  if (methods::is(beta, "MethQcSet")) {
    if (identical(toupper(beta@platform), "EPICV2") && !identical(beta@aggregation_status, "epicv2_aggregated")) {
      stop("EPICv2 data must be aggregated before building a reference profile. Run: qcset <- aggregate_probes(qcset)")
    }
    if (is.null(normalization)) normalization <- beta@qc_params$normalization
    beta <- beta@beta
  } else if (methods::is(beta, "ImprintomeSet")) {
    genome <- beta@genome
    beta <- beta(beta)
  }
  genome <- match.arg(tolower(genome), c("hg19", "hg38"))
  ref <- LoadBeta(beta)
  ref <- ref[, vapply(ref, is.numeric, logical(1)), drop = FALSE]
  if (!is.null(samples)) {
    unknown <- setdiff(samples, colnames(ref))
    if (length(unknown)) stop("samples not found in beta: ", paste(unknown, collapse = ", "))
    ref <- ref[, unique(samples), drop = FALSE]
  }
  if (ncol(ref) < .min_reference_samples) {
    stop("A reference profile needs at least ", .min_reference_samples, " control samples; got ", ncol(ref), ".")
  }

  panels <- .load_probesets(genome)
  if (is.null(probeset)) {
    probes <- unique(unlist(lapply(panels, `[[`, "NAME")))
  } else {
    if (!probeset %in% names(panels)) stop("Unavailable probeset '", probeset, "' for genome '", genome, "'.")
    probes <- panels[[probeset]]$NAME
  }
  probes <- intersect(rownames(ref), probes)
  if (!length(probes)) stop("beta shares no probes with the requested probeset(s).")

  profile <- .row_medians(ref[probes, , drop = FALSE])
  profile <- profile[!is.na(profile)]
  attr(profile, "n_samples") <- ncol(ref)
  attr(profile, "genome") <- genome
  attr(profile, "probeset") <- if (is.null(probeset)) "all panels" else probeset
  attr(profile, "normalization") <- if (is.null(normalization)) "unspecified" else as.character(normalization)[1]
  profile
}
#=====================================
#================================================================

#' @export
Survey_Global_Imprinting <- function(beta, sampleID,probeset=c("selected", "NanoImprint", "Joshi", "Court", "Rosenski", "Jima", "chr11p15", "chr20q13"), min_probes = 10, ids_cutoff=0.2, genome = "hg38") {
  suppressMessages(suppressWarnings(library("dplyr")))
  library(stringr)
  probeset <- match.arg(probeset)
  beta <- .resolve_beta_input(beta)
  #================================================================
  # prepare chromosome
  beta <- as.data.frame(beta)
  probes <- .get_probeset(probeset, genome)
    anno <- probes[,c("CHR","MAPINFO","Closest_TSS_gene_name","ORIGIN")]   
    colnames(anno)[3] <- "GENE"
    rownames(anno) <- probes$NAME

  common_probes <- intersect(rownames(anno), rownames(beta))
  beta <- beta[common_probes, ]
  #================================================================
  #================================================================
  beta$Probe <- rownames(beta)
  beta$Chromosome <-  anno[common_probes,"CHR"]
  beta$ORIGIN <-  anno[common_probes,"ORIGIN"]

  # 1. Filter for the specific sample
  sample_data <- beta[, c("Probe", "Chromosome","ORIGIN",sampleID) ]
  colnames(sample_data)[ncol(sample_data)] <- "beta"
  # print(head(sample_data))

  # 2. Group by Chromosome and calculate vectors
  # Assuming your 'data' has columns: Chromosome, ORIGIN (maternal/paternal), and beta
  chrom_survey <- sample_data %>%
    group_by(Chromosome) %>%
    summarise(
      n_mat = sum(ORIGIN %in%  "maternal", na.rm=TRUE),
      n_pat = sum(ORIGIN %in% "paternal", na.rm=TRUE),
      # Calculate Maternal Median ONLY if >= 10 probes
      maternal_median = if(n_mat >= min_probes) {
                    median(beta[ORIGIN %in% "maternal"], na.rm = TRUE)
                } else { 0.5 },
                
      # Calculate Paternal Median ONLY if >= 10 probes
      paternal_median = if(n_pat >= min_probes) {
                    median(beta[ORIGIN %in% "paternal"], na.rm = TRUE)
                } else { 0.5 },
      # Maternal Consistency
      mat_cons = if(any(ORIGIN %in% "maternal")) {
        m_vals <- beta[ORIGIN %in% "maternal"]
        m_dir  <- if(median(m_vals, na.rm=TRUE) > 0.5) 1 else -1
        sum((m_vals - 0.5) * m_dir > 0, na.rm=TRUE) / sum(ORIGIN %in% "maternal")
      } else { 0 },
      
      # Paternal Consistency
      pat_cons = if(any(ORIGIN %in% "paternal")) {
        p_vals <- beta[ORIGIN %in% "paternal"]
        p_dir  <- if(median(p_vals, na.rm=TRUE) > 0.5) 1 else -1
        sum((p_vals - 0.5) * p_dir > 0, na.rm=TRUE) / sum(ORIGIN %in% "paternal")
      } else { 0 },     
      max_cons = pmax(mat_cons, pat_cons, na.rm = TRUE), 
      n_total = n(),
      .groups = 'drop'
    ) %>%
    filter(n_mat >= min_probes | n_pat >= min_probes) %>%
    mutate(
      # Calculate the Vector components
      mat_dev = maternal_median - 0.5,
      pat_dev = paternal_median - 0.5,
      IDS = sqrt(mat_dev^2 + pat_dev^2),
      # ANGLE LOGIC: Handling cases with only 1 allele type
      Angle = case_when(
        n_pat == 0 & mat_dev > 0 ~ 90,   # Pure Maternal Gain
        n_pat == 0 & mat_dev < 0 ~ 270,  # Pure Maternal Loss
        n_mat == 0 & pat_dev > 0 ~ 0,    # Pure Paternal Gain
        n_mat == 0 & pat_dev < 0 ~ 180,  # Pure Paternal Loss
        TRUE ~ (atan2(mat_dev, pat_dev) * 180 / pi + 360) %% 360
      )
    )
    #================================================================
      mechanism_labels <- c(
        "Pat-Gain", "Global-Hyper", "Mat-Gain", "Mat-Gain/Pat-Loss", 
        "Pat-Loss", "Global-Hypo", "Mat-Loss", "Pat-Gain/Mat-Loss"
      )    
      shifted_degrees <- (chrom_survey$Angle + 22.5) %% 360
      mechanism <- mechanism_labels[cut(shifted_degrees, 
                                    breaks = seq(0, 360, by = 45), 
                                    labels = FALSE, 
                                    include.lowest = TRUE)]
    #================================================================
    
    
    status_logic <- data.frame(ids = chrom_survey$IDS) %>%
    mutate(
      Status = if_else(ids >= ids_cutoff, "Imprinting Alteration", "Normal"),
      Confidence = case_when(
        ids < 0.1  ~ "High (Normal)",
        ids < 0.2  ~ "Low (Normal)",
        ids < 0.4  ~ "Moderate (Alteration)",
        TRUE       ~ "High (Alteration)"
      ),
      # Prioritize ROI: If IDS is very low, the mechanism is "Retention"
      Mechanism = if_else(ids < 0.2, "ROI", as.character(mechanism))
    )
  status_logic$ids <- NULL
  chrom_survey  <- cbind(chrom_survey,status_logic )
  chrom_survey <- chrom_survey %>%
                   mutate(Chromosome = factor(Chromosome, levels = str_sort(unique(Chromosome), numeric = TRUE))) %>%  
                   arrange(Chromosome)

  return(chrom_survey)
}

#================================================================

#' @export
Survey_Global_Imprinting_Batch <- function(betaFile, metaFile = NULL,
                                          subset = "all", 
                                          probeset = c("selected", "NanoImprint", "Joshi", "Court", "Rosenski", "Jima", "chr11p15", "chr20q13"), 
                                          min_probes = 10, 
                                          ids_cutoff = 0.2,
                                          genome = "hg38") {
  
  suppressMessages(suppressWarnings({
    library(dplyr)
    library(tidyr)
    library(stringr)
    library(data.table)
  }))
  
  probeset <- match.arg(probeset)

  resolved <- .resolve_beta_meta_inputs(betaFile, metaFile, require_meta = TRUE)
  betaFile <- resolved$beta
  metaFile <- resolved$meta
  
  input <- LoadMetaBeta(metaFile, betaFile, probeset = NULL)
  beta0 <- input[["beta"]]
  meta <- input[["meta"]]
  tmp  <- SubsetBeta_By_Probeset(beta0, probeset=probeset,prefix=NULL)

  # 1. Load Beta Data (Supports RDS and TXT/TSV)
  beta <- tmp[["beta"]]
  beta <- na.omit(beta) # removed NA

  # 2. Load Annotation
  probes_info <- .get_probeset(probeset, genome)
  anno <- probes_info %>%
    select(NAME, CHR, ORIGIN) %>%
    as.data.frame()
  rownames(anno) <- anno$NAME

  # 3. Filter by Subset (Chromosome)
  if (subset != "all") {
    anno <- anno %>% filter(CHR == subset)
  }

  # 4. Align and Pivot to Long Format
  common_probes <- intersect(rownames(anno), rownames(beta))
  
  # Merging annotation with beta values
  combined_data <- beta[common_probes, , drop = FALSE] %>%
    mutate(Probe = common_probes,
           Chromosome = anno[common_probes, "CHR"],
           ORIGIN = anno[common_probes, "ORIGIN"]) %>%
    # Transform table so we have one row per Probe-Sample pair
    pivot_longer(cols = -c(Probe, Chromosome, ORIGIN), 
                 names_to = "Sample_Name", 
                 values_to = "beta_val")

  # 5. Global Calculation (Group by Sample AND Chromosome)
  results <- combined_data %>%
    group_by(Sample_Name, Chromosome) %>%
    summarise(
      n_mat = sum(ORIGIN == "maternal", na.rm = TRUE),
      n_pat = sum(ORIGIN == "paternal", na.rm = TRUE),
      maternal_median = if(n_mat >= min_probes) median(beta_val[ORIGIN == "maternal"], na.rm = TRUE) else 0.5,
      paternal_median = if(n_pat >= min_probes) median(beta_val[ORIGIN == "paternal"], na.rm = TRUE) else 0.5,
      .groups = 'drop'
    ) %>%
    filter(n_mat >= min_probes | n_pat >= min_probes) %>%
    mutate(
      mat_dev = maternal_median - 0.5,
      pat_dev = paternal_median - 0.5,
      IDS = sqrt(mat_dev^2 + pat_dev^2),
      Angle = (atan2(mat_dev, pat_dev) * 180 / pi + 360) %% 360
    )

  # 6. Apply Mechanism Labels
  mechanism_labels <- c("Pat-Gain", "Global-Hyper", "Mat-Gain", "Mat-Gain/Pat-Loss", 
                        "Pat-Loss", "Global-Hypo", "Mat-Loss", "Pat-Gain/Mat-Loss")
  


  report <- results %>%
    mutate(
      mechanism_idx = cut((Angle + 22.5) %% 360, breaks = seq(0, 360, by = 45), labels = FALSE, include.lowest = TRUE),
      raw_mech = mechanism_labels[mechanism_idx],
      Status = if_else(IDS >= ids_cutoff, "Alteration", "Normal"),
      Mechanism = if_else(IDS < 0.2, "ROI (Retention)", raw_mech),
      Chromosome = factor(Chromosome, levels = str_sort(unique(Chromosome), numeric = TRUE))
    ) %>%
    select(Sample_Name, Chromosome, n_mat, n_pat, IDS, Status, Mechanism, Angle) %>%
    arrange(Sample_Name, Chromosome)

    cols_to_keep <- intersect(colnames(meta), c("Sample_Name", "Sample_Group", "ID2"))
    meta_selected <- meta[, cols_to_keep, drop = FALSE]
  
  # Join metadata to the report
  final_report <- report %>%
    left_join(meta_selected, by = "Sample_Name") %>%
    select(Sample_Name, any_of(c("Sample_Group", "ID2")), Chromosome, n_mat, n_pat, IDS, Status, Mechanism, Angle) %>%
    arrange(Sample_Name, Chromosome)

  return(final_report)
}
#================================================================

#================================================================

validate_imprinting_fit <- function(purity, obs_dev, sample_ids) {
  library(ggplot2)
  # 1. Calculate Expected Deviation based on the "Perfect LOI" model
  # D_exp = 0.5 * Purity
  exp_dev <- 0.5 * purity
  
  # 2. Calculate the Residual (The "Mismatch")
  # A positive residual means more deviation than expected (Higher than 100% LOI in tumor)
  # A negative residual means less deviation (Partial LOI or stochastic drift)
  residual <- obs_dev - exp_dev
  
  # 3. Calculate Consistency Score (0 to 1, where 1 is a perfect fit)
  # We use a simple Gaussian-like decay for the score
  consistency_score <- exp(-(residual^2) / 0.01) 
  
  results <- data.frame(
    SampleID = sample_ids,
    Purity = purity,
    Observed_Dev = obs_dev,
    Expected_Dev = exp_dev,
    Residual = round(residual, 3),
    Fit_Score = round(consistency_score, 3)
  )
  
  # 4. Flagging Logic
  results$Status <- ifelse(results$Residual < -0.1, "Partial LOI / Drift",
                    ifelse(results$Residual > 0.1, "Purity Underestimated", "Consistent LOI"))
  
  return(results)
}

if(F){
  # --- Example Usage ---
  samples <- c("Sample_A", "Sample_B", "Sample_C")
  purity_vals <- c(0.70, 0.90, 0.40)
  observed_devs <- c(0.40, 0.45, 0.05) # 40%, 45%, 5%

  fit_data <- validate_imprinting_fit(purity_vals, observed_devs, samples)
  print(fit_data) 

}

#================================================================

calculate_imprint_age <- function(beta_matrix, icr_sites, global_clocks_age, trained_weights = NULL) {
  library(dplyr)
  library(matrixStats)
  # 1. Subset for ICR-specific sites
  common_sites <- intersect(rownames(beta_matrix), icr_sites)
  icr_beta <- beta_matrix[common_sites, ]
  
  # 2. If no weights are provided, we use a Z-score deviation model
  # This measures how 'disordered' the ICRs are compared to a young/normal baseline
  if (is.null(trained_weights)) {
    message("No trained weights provided. Calculating Deviation-based ImprintAge...")
    
    # Deviation from the 'perfect' 0.5 methylation state
    # High deviation in specific directions correlates with epigenetic fatigue
    imprint_age_score <- colMeans(abs(icr_beta - 0.5), na.rm = TRUE)
    
    # Scale to a year-based metric for comparison (heuristic scaling)
    imprint_age_years <- (imprint_age_score * 100) + 20 
  } else {
    # 3. Use Linear Model: Age = intercept + sum(Beta_i * Weight_i)
    # This is the standard Horvath-style calculation
    imprint_age_years <- colSums(icr_beta * trained_weights[common_sites], na.rm = TRUE)
  }
  
  # 4. Calculate Age Acceleration (The delta)
  age_acceleration <- imprint_age_years - global_clocks_age
  
  results <- data.frame(
    SampleID = colnames(beta_matrix),
    Global_BioAge = global_clocks_age,
    ImprintAge = round(imprint_age_years, 2),
    Age_Acceleration = round(age_acceleration, 2)
  )
  
  # Categorize results
  results$Aging_Status <- ifelse(results$Age_Acceleration > 5, "Accelerated",
                          ifelse(results$Age_Acceleration < -5, "Decelerated", "Normal"))
  
  return(results)
}

# --- Example Usage ---
# icr_sites <- c("cg000002", "cg000005", ...) # Sites inside ICR boundaries
# global_ages <- c(45, 62, 30) # Ages calculated via standard Horvath/Hannum clocks
# clock_results <- calculate_imprint_age(my_betas, icr_sites, global_ages)

#================================================================
if(F){

  library(ggplot2)
  plot_imprint_clock <- function(df) {
    ggplot(df, aes(x = Global_BioAge, y = ImprintAge)) +
      geom_point(aes(color = Aging_Status), size = 3) +
      geom_abline(intercept = 0, slope = 1, linetype = "dashed", color = "grey") + # The "Perfect Match" line
      geom_smooth(method = "lm", color = "blue", se = FALSE) +
      scale_color_manual(values = c("Accelerated" = "red", "Normal" = "black", "Decelerated" = "green")) +
      labs(
        title = "ImprintAge Clock: ICR Aging vs. Global BioAge",
        subtitle = "Points above the line indicate Accelerated Imprinting Decay",
        x = "Global Biological Age (Standard Clock)",
        y = "ImprintAge (ICR-Specific Clock)"
      ) +
      theme_classic()
  }
}

#================================================================
library(ComplexHeatmap)
library(circlize)




