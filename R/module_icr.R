# Module: per-ICR scoring
#
# Per-ICR deviations (AnalyzeICRStatus), the per-sample multi-locus summary built from them
# (SummarizeICRStatus), and the per-ICR heatmap (PlotICRHeatmap). The ICR-balanced sample-level
# IDS/Angle is AnalyzeImprintStatus(..., balance = "icr"), which uses the same per-ICR deviations.

.icr_sd_floor <- 0.02

# Load beta and metadata for scoring: resolves an ImprintomeSet, subsets the beta matrix to the
# probeset (dropping probes with any missing value), aligns samples, and validates the probeset.
.load_scoring_input <- function(betaFile, metaFile, probeset, genome) {
  if (methods::is(betaFile, "ImprintomeSet")) {
    if (!is.null(metaFile)) {
      stop("When betaFile is an ImprintomeSet, metaFile must be missing or NULL.")
    }
    obj <- betaFile
    betaFile <- beta(obj)
    metaFile <- meta(obj)
    genome <- obj@genome
  }
  if (is.null(metaFile)) {
    stop("metaFile is required unless betaFile is an ImprintomeSet.")
  }
  if (!is.character(probeset) || length(probeset) != 1 || is.na(probeset) || !nzchar(probeset)) {
    stop("probeset must be a single non-empty character value.")
  }
  genome <- match.arg(tolower(genome), c("hg19", "hg38"))

  input <- LoadMetaBeta(metaFile, betaFile, probeset = NULL)
  meta <- input[["meta"]]
  tmp <- SubsetBeta_By_Probeset(input[["beta"]], probeset = probeset, prefix = NULL, genome = genome)
  probesets <- tmp[["probesets"]]
  used <- na.omit(tmp[["beta"]])
  if (is.null(used) || ncol(used) == 0) {
    stop("No sample columns available after preprocessing.")
  }
  sample_ids <- intersect(meta$Sample_Name, colnames(used))
  if (length(sample_ids) == 0) {
    stop("No overlapping samples between metadata and processed beta matrix.")
  }
  .validate_probeset_annotation(probesets, probeset)
  list(meta = meta[sample_ids, , drop = FALSE], used = used[, sample_ids, drop = FALSE],
       probesets = probesets, sample_ids = sample_ids, genome = genome)
}

# Deviation of each ICR from its reference, per sample: the median over the ICR's probes of
# (beta - reference), or median(beta) - 0.5 with the fixed reference. ICRs with fewer than
# `min_probes` probes are dropped. Returns an ICR-by-sample matrix with attribute n_probes.
.icr_deviations <- function(beta, ref = NULL, icr, min_probes = 3L) {
  keep <- !is.na(icr) & nzchar(icr)
  groups <- split(rownames(beta)[keep], icr[keep])
  groups <- groups[lengths(groups) >= min_probes]
  if (!length(groups)) {
    out <- matrix(numeric(0), nrow = 0, ncol = ncol(beta), dimnames = list(NULL, colnames(beta)))
    attr(out, "n_probes") <- integer(0)
    return(out)
  }
  out <- t(vapply(groups, function(rows) {
    b <- as.matrix(beta[rows, , drop = FALSE])
    if (is.null(ref)) {
      apply(b, 2, median, na.rm = TRUE) - 0.5
    } else {
      apply(b - ref[rows, , drop = FALSE], 2, median, na.rm = TRUE)
    }
  }, numeric(ncol(beta))))
  if (ncol(beta) == 1L) out <- matrix(out, ncol = 1L, dimnames = list(names(groups), colnames(beta)))
  colnames(out) <- colnames(beta)
  attr(out, "n_probes") <- lengths(groups)
  out
}

# ICR-balanced deviation of one parental class: the median across ICRs of the per-ICR
# deviations, so that each ICR counts once whatever its number of probes.
.balanced_deviation <- function(beta, ref, icr, min_probes = 3L) {
  dev <- .icr_deviations(beta, ref, icr, min_probes)
  list(deviation = if (nrow(dev)) apply(dev, 2, median) else rep(NA_real_, ncol(beta)), n_icrs = nrow(dev))
}


#' Per-ICR Imprinting Deviations
#'
#' Scores each imprinting control region (ICR) of a panel separately. For every sample and ICR
#' with at least `min_probes` probes, the deviation is the median over the ICR's probes of
#' `beta - reference` (`median(beta) - 0.5` with the fixed reference). Each ICR has a single
#' parental origin, so its deviation lies on one axis: a gain or loss of methylation on the
#' paternal or maternal axis. Two-axis IDS/Angle for a single imprinted domain is obtained by
#' scoring a locus panel such as `chr11p15` or `chr20q13` with [AnalyzeImprintStatus()].
#'
#' An ICR is called altered when `abs(deviation) >= delta_cutoff` and, when control samples are
#' available, also `abs(z) >= z_cutoff`, where `z` is the deviation standardized by the
#' controls' median and standard deviation for that ICR (the standard deviation is floored at
#' 0.02 so that very homogeneous controls do not inflate `z`). Controls are scored
#' leave-one-out when they also form the reference. The thresholds are exploratory.
#'
#' @inheritParams AnalyzeImprintStatus
#' @param dmr_type `DMR_type` values to score. `NULL` (default) scores every annotated ICR,
#'   gametic and secondary alike; the `DMR_type` column of the result records each ICR's type.
#' @param control_group,control_samples In-cohort controls used to standardize deviations
#'   (`z`). Default to `reference_group` and `reference_samples`. Without controls, `z` is
#'   `NA` and calls use `delta_cutoff` only.
#' @param min_probes Minimum number of probes for an ICR to be scored (default 3).
#' @param delta_cutoff Minimum absolute deviation for an altered call (default 0.15).
#' @param z_cutoff Minimum absolute z-score for an altered call when controls are available
#'   (default 3).
#'
#' @return Data frame with one row per sample and ICR: sample metadata, `probeset`,
#'   `ICR_name`, `ORIGIN`, `DMR_type`, `CHR`, `start`, `n_probes`, `median_beta`, `reference`
#'   (median reference beta), `deviation`, `abs_deviation`, `z`, `direction` (`"gain"` or
#'   `"loss"`) and `altered`. Settings are stored in attribute `icr_settings`.
#' @seealso [SummarizeICRStatus()] for the per-sample multi-locus summary and
#'   [PlotICRHeatmap()].
#' @export
AnalyzeICRStatus <- function(betaFile, metaFile = NULL,
                             probeset = "selected",
                             genome = "hg38",
                             dmr_type = NULL,
                             reference = c("auto", "controls", "fixed"),
                             reference_group = NULL,
                             reference_samples = NULL,
                             reference_beta = NULL,
                             control_group = reference_group,
                             control_samples = reference_samples,
                             min_probes = 3L,
                             delta_cutoff = 0.15,
                             z_cutoff = 3) {
  reference <- match.arg(reference)
  for (arg in c("delta_cutoff", "z_cutoff", "min_probes")) {
    value <- get(arg)
    if (!is.numeric(value) || length(value) != 1L || is.na(value) || value < 0) {
      stop(arg, " must be a single non-negative number.")
    }
  }
  inp <- .load_scoring_input(betaFile, metaFile, probeset, genome)
  probesets <- inp$probesets
  if (!"ICR_name" %in% colnames(probesets)) {
    stop("Probeset '", probeset, "' has no ICR_name column; per-ICR scoring is unavailable.")
  }
  if (!is.null(dmr_type) && !identical(dmr_type, "all")) {
    if (!"DMR_type" %in% colnames(probesets)) {
      stop("Probeset '", probeset, "' has no DMR_type column; dmr_type filtering is unavailable.")
    }
    probesets <- probesets[probesets$DMR_type %in% dmr_type, , drop = FALSE]
  }
  origin <- tolower(trimws(as.character(probesets$ORIGIN)))
  probesets <- probesets[!is.na(probesets$ICR_name) & origin %in% c("maternal", "paternal"), , drop = FALSE]

  ref <- .resolve_reference(inp$used, inp$meta, reference, reference_group, reference_samples, reference_beta)
  probes <- intersect(probesets$NAME, ref$probes)
  beta <- inp$used[probes, , drop = FALSE]
  ref_mat <- if (is.null(ref$matrix)) NULL else ref$matrix[probes, inp$sample_ids, drop = FALSE]
  icr <- probesets$ICR_name[match(probes, probesets$NAME)]
  dev <- .icr_deviations(beta, ref_mat, icr, min_probes)
  if (!nrow(dev)) stop("No ICR of probeset '", probeset, "' has at least ", min_probes, " matched probes.")
  icrs <- rownames(dev)

  # Controls for z-scores: explicit names, or a Sample_Group value.
  controls <- character(0)
  if (!is.null(control_samples)) {
    controls <- intersect(control_samples, inp$sample_ids)
  } else if (!is.null(control_group) && "Sample_Group" %in% colnames(inp$meta)) {
    controls <- intersect(inp$meta$Sample_Name[inp$meta$Sample_Group %in% control_group], inp$sample_ids)
  }
  if (length(controls) >= .min_reference_samples) {
    centre <- apply(dev[, controls, drop = FALSE], 1, median)
    spread <- pmax(apply(dev[, controls, drop = FALSE], 1, stats::sd), .icr_sd_floor)
    z <- (dev - centre) / spread
  } else {
    if (length(controls)) warning("Fewer than ", .min_reference_samples, " controls; per-ICR z-scores are not computed.")
    z <- dev * NA
  }

  med_beta <- .icr_deviations(beta, NULL, icr, min_probes)[icrs, , drop = FALSE] + 0.5
  ref_beta <- med_beta - dev
  first <- function(col) probesets[[col]][match(icrs, probesets$ICR_name)]
  start <- vapply(icrs, function(i) min(probesets$MAPINFO[probesets$ICR_name == i]), numeric(1))
  cols_to_keep <- intersect(colnames(inp$meta), c("Sample_Name", "Sample_Group", "ID2"))
  rows <- lapply(seq_along(icrs), function(k) {
    d <- dev[k, ]
    zz <- z[k, ]
    altered <- abs(d) >= delta_cutoff & (is.na(zz) | abs(zz) >= z_cutoff)
    data.frame(
      inp$meta[, cols_to_keep, drop = FALSE],
      probeset = probeset,
      ICR_name = icrs[k],
      ORIGIN = tolower(first("ORIGIN")[k]),
      DMR_type = if ("DMR_type" %in% colnames(probesets)) first("DMR_type")[k] else NA_character_,
      CHR = first("CHR")[k],
      start = start[k],
      n_probes = unname(attr(dev, "n_probes")[k]),
      median_beta = round(med_beta[k, ], 3),
      reference = round(ref_beta[k, ], 3),
      deviation = round(d, 3),
      abs_deviation = round(abs(d), 3),
      z = round(zz, 2),
      direction = ifelse(d >= 0, "gain", "loss"),
      altered = altered,
      stringsAsFactors = FALSE
    )
  })
  res <- do.call(rbind, rows)
  chr_num <- suppressWarnings(as.numeric(sub("^chr", "", res$CHR)))
  res <- res[order(match(res$Sample_Name, inp$sample_ids), chr_num, res$start), ]
  rownames(res) <- NULL
  attr(res, "icr_settings") <- list(min_probes = min_probes, delta_cutoff = delta_cutoff, z_cutoff = z_cutoff,
                                    reference = ref$label, n_controls = length(controls), genome = inp$genome)
  res
}


#' Multi-Locus Summary of Per-ICR Deviations
#'
#' Summarizes [AnalyzeICRStatus()] output per sample: the numbers of ICRs scored and called
#' altered (gains and losses), the altered ICRs and their chromosomes, and a multi-locus flag.
#' A sample is flagged `MLID` when its altered ICRs lie on at least `min_chromosomes`
#' different chromosomes, so that neighbouring ICRs of one locus (for example the two DIRAS3
#' DMRs) count once.
#'
#' @param icr_table Output of [AnalyzeICRStatus()].
#' @param min_chromosomes Minimum number of chromosomes with an altered ICR for the
#'   multi-locus flag (default 2).
#' @param dmr_type Optional `DMR_type` values to summarize, for example `"gametic"`; `NULL`
#'   (default) uses every ICR in the table.
#' @param exclude_icrs ICRs left out of the counts and the multi-locus flag. The default
#'   excludes `VTRNA2-1:DMR` (nc886), a polymorphically imprinted, metastable DMR that is
#'   unmethylated in a sizeable fraction of healthy individuals. Its per-ICR deviations stay in
#'   the [AnalyzeICRStatus()] table. Use `NULL` to count every ICR.
#'
#' @return Data frame with one row per sample: `n_icrs`, `n_altered`, `n_gain`, `n_loss`,
#'   `n_altered_chromosomes`, `altered_icrs`, `MLID`, and `max_abs_deviation`.
#' @export
SummarizeICRStatus <- function(icr_table, min_chromosomes = 2L, dmr_type = NULL, exclude_icrs = "VTRNA2-1:DMR") {
  if (!is.data.frame(icr_table) || !all(c("Sample_Name", "ICR_name", "altered", "deviation", "CHR") %in% colnames(icr_table))) {
    stop("icr_table must be the output of AnalyzeICRStatus().")
  }
  if (!is.null(dmr_type)) icr_table <- icr_table[icr_table$DMR_type %in% dmr_type, , drop = FALSE]
  if (length(exclude_icrs)) icr_table <- icr_table[!icr_table$ICR_name %in% exclude_icrs, , drop = FALSE]
  samples <- unique(icr_table$Sample_Name)
  meta_cols <- intersect(c("Sample_Name", "Sample_Group", "ID2"), colnames(icr_table))
  out <- lapply(samples, function(s) {
    r <- icr_table[icr_table$Sample_Name == s, , drop = FALSE]
    a <- r[r$altered, , drop = FALSE]
    n_chr <- length(unique(a$CHR))
    data.frame(
      r[1, meta_cols, drop = FALSE],
      n_icrs = nrow(r),
      n_altered = nrow(a),
      n_gain = sum(a$deviation >= 0),
      n_loss = sum(a$deviation < 0),
      n_altered_chromosomes = n_chr,
      altered_icrs = if (nrow(a)) paste0(a$ICR_name, " (", ifelse(a$deviation >= 0, "+", ""), a$deviation, ")", collapse = "; ") else "",
      MLID = n_chr >= min_chromosomes,
      max_abs_deviation = max(abs(r$deviation)),
      stringsAsFactors = FALSE
    )
  })
  res <- do.call(rbind, out)
  rownames(res) <- NULL
  res
}


#' Heatmap of Per-ICR Deviations
#'
#' Tiles of the per-ICR deviation from [AnalyzeICRStatus()], samples in rows (grouped by
#' `Sample_Group`) and ICRs in columns (maternal then paternal, by chromosome position).
#' Altered ICRs are marked with a dot.
#'
#' @param icr_table Output of [AnalyzeICRStatus()].
#' @param title Plot title.
#' @param limit Colour-scale limit for the deviation (default 0.4).
#' @param outFile Optional PDF/PNG path.
#' @param width,height Size in inches when saving.
#'
#' @return A ggplot object.
#' @export
PlotICRHeatmap <- function(icr_table, title = "Per-ICR deviation", limit = 0.4, outFile = NULL, width = 12, height = 8) {
  if (!is.data.frame(icr_table) || !all(c("Sample_Name", "ICR_name", "deviation", "ORIGIN", "altered") %in% colnames(icr_table))) {
    stop("icr_table must be the output of AnalyzeICRStatus().")
  }
  d <- icr_table
  key <- unique(d[, c("ICR_name", "ORIGIN", "CHR", "start", "DMR_type")])
  chr_num <- suppressWarnings(as.numeric(sub("^chr", "", key$CHR)))
  key <- key[order(key$ORIGIN, chr_num, key$start), ]
  label <- paste0(key$ICR_name, ifelse(!is.na(key$DMR_type) & key$DMR_type != "gametic", " *", ""))
  d$ICR <- factor(label[match(d$ICR_name, key$ICR_name)], levels = label)
  grp <- if ("Sample_Group" %in% colnames(d)) d$Sample_Group else "all"
  sample_order <- unique(d$Sample_Name[order(grp, d$Sample_Name)])
  d$Sample <- factor(d$Sample_Name, levels = rev(sample_order))
  d$Group <- grp
  d$value <- pmax(pmin(d$deviation, limit), -limit)
  p <- ggplot2::ggplot(d, ggplot2::aes(x = ICR, y = Sample, fill = value)) +
    ggplot2::geom_tile(colour = "white", linewidth = 0.2) +
    ggplot2::geom_point(data = d[d$altered, , drop = FALSE], size = 0.8, colour = "black") +
    ggplot2::scale_fill_gradient2(name = "Deviation", low = "#2166AC", mid = "white", high = "#B2182B",
                                  midpoint = 0, limits = c(-limit, limit)) +
    ggplot2::facet_grid(Group ~ ORIGIN, scales = "free", space = "free") +
    ggplot2::labs(title = title, x = NULL, y = NULL,
                  caption = "Dots: altered ICRs. *: secondary or other non-gametic DMR. Deviations beyond the limit are capped.") +
    ggplot2::theme_minimal(base_size = 9) +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 60, hjust = 1, size = 7),
                   axis.text.y = ggplot2::element_text(size = 5), panel.grid = ggplot2::element_blank(),
                   strip.text.y = ggplot2::element_text(angle = 0))
  if (!is.null(outFile)) ggplot2::ggsave(outFile, p, width = width, height = height)
  p
}
