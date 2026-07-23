#' Plot ImprintomeSet Results
#'
#' S4 plotting method for `ImprintomeSet` objects.
#' The method prioritizes precomputed plots stored in `plots(x)` and otherwise
#' generates a default polar plot from result tables containing `IDS` and `Angle`.
#' Default generation uses `PlotPolar()` to preserve existing plot semantics.
#'
#' @param x An `ImprintomeSet` object.
#' @param y Unused. Kept for `plot()` compatibility.
#' @param ... Optional named arguments:
#'   - `plot_type`: one of `"auto"`, `"polar"`, `"mirror_density"`,
#'     `"beeswarm"`, `"beeswarm_origin"`, `"beeswarm_chr"`, `"violin"`,
#'     `"heatmap_by_probe"`, `"heatmap_by_gene"`, `"circular_heatmap",`
#'     `"cor_heatmap"`, `"rainfall"`, `"radar"`.
#'   - `plot_name`: specific stored plot name in `plots(x)`.
#'   - `result_name`: specific results table name in `results(x)`.
#'   - `colorColumn`: grouping column for `PlotPolar()` (default `"Sample_Group"`; if missing from result data, automatically created with all samples grouped as `"All"`).
#'   - `title`: plot title (default `"ImprintomeR:Polar"`).
#'   - `palette`: palette passed to `PlotPolar()` (default `"default"`).
#'   - `alpha`: point alpha passed to `PlotPolar()` (default `0.5`).
#'   - `legend.position`, `legend.nrow`, `legend.ncol`, `legend.page`,
#'     `legend.page.threshold`, `legend.text.size`: optional polar legend controls
#'     passed to `PlotPolar()`; crowded PDF legends can be written to a
#'     separate legend-only page with `legend.page = TRUE` or `legend.page = "auto"`.
#'   - `SAMPLEID`: metadata column used for sample labels in selected plot types
#'     (default `"Sample_Name"`).
#'   - `max_samples`: maximum number of samples shown by
#'     `plot_type = "beeswarm_origin"` or `plot_type = "mirror_density"`
#'     (default `100`; use `Inf` to plot all).
#'   - `probeset`: probeset name used by `"mirror_density"`, `"beeswarm"`,
#'     `"violin"`, `"heatmap_by_probe"`, `"heatmap_by_gene"`, `"circular_heatmap",`
#'     `"cor_heatmap"`, `"rainfall"`, and `"radar"` (default `"selected"`).
#'   - `sample_id`: explicit sample ID used by rainfall/radar plot types.
#'   - `chr`: chromosome label used by `plot_type = "beeswarm_chr"`
#'     (e.g. `"chr11"` or `"11"`; default uses all chromosomes).
#'   - `prefix`: output prefix used by `plot_type = "cor_heatmap"`.
#'   - `sectionColumn`: metadata grouping column used by
#'     `plot_type = "circular_heatmap"` (default `"Sample_Group"`; if column doesn't exist in metadata:
#'     uses `Sample_Name` if available, otherwise creates it with all samples grouped as `"all"`).
#'   - `Samples`: character vector of sample names to include (applied with `plot_type = "circular_heatmap"`, default: all samples).
#'   - `outFile`: optional file path for saving output.
#'   - `width`: optional width in inches when saving stored plots.
#'   - `height`: optional height in inches when saving stored plots.
#'
#' @return Plot object returned by the selected backend function. For example,
#'   `ggplot` objects for polar/beeswarm/violin/radar paths, or backend-specific
#'   objects for heatmap/correlation paths.
#' @name ImprintomeSet-plot
#'
#' @examples
#' \dontrun{
#' p <- plot(x)
#' p <- plot(x, plot_name = "polar.default")
#' p <- plot(x, result_name = "AnalyzeImprintStatus.selected", outFile = "polar.pdf")
#' p <- plot(x, plot_type = "beeswarm", probeset = "selected", SAMPLEID = "Sample_Name")
#' p <- plot(x, plot_type = "beeswarm_origin", probeset = "selected", SAMPLEID = "Sample_Name")
#' p <- plot(x, plot_type = "beeswarm_chr", probeset = "selected", sample_id = colnames(beta(x))[1], chr = "chr11")
#' p <- plot(x, plot_type = "heatmap_by_gene", probeset = "selected", outFile = "heatmap_gene.pdf")
#' p <- plot(x, plot_type = "mirror_density", probeset = "selected")
#' p <- plot(x, plot_type = "circular_heatmap", probeset = "selected", sectionColumn = "Sample_Name")
#' p <- plot(x, plot_type = "rainfall", sample_id = colnames(beta(x))[1])
#' }
if (!methods::isGeneric("plot")) {
  methods::setGeneric("plot", function(x, y, ...) standardGeneric("plot"))
}

.imprint_get_arg_chr <- function(args, key, default = NULL) {
  if (!is.null(args[[key]])) {
    return(as.character(args[[key]])[1])
  }
  default
}

.imprint_pick_result <- function(r_list, result_name = NULL, required_cols = c("IDS", "Angle")) {
  if (length(r_list) == 0L) {
    return(NULL)
  }

  if (!is.null(result_name) && nzchar(result_name) && result_name %in% names(r_list)) {
    candidate <- r_list[[result_name]]
    if (is.data.frame(candidate) && all(required_cols %in% colnames(candidate))) {
      return(candidate)
    }
  }

  ordered_names <- sort(names(r_list))
  ok <- vapply(
    r_list[ordered_names],
    function(tbl) is.data.frame(tbl) && all(required_cols %in% colnames(tbl)),
    logical(1)
  )
  valid_names <- ordered_names[ok]
  if (length(valid_names) == 0L) {
    return(NULL)
  }
  r_list[[valid_names[1]]]
}

.imprint_choose_sample_id <- function(beta_x, meta_x = NULL, requested_sample = NULL) {
  beta_cols <- colnames(beta_x)
  if (is.null(beta_cols) || length(beta_cols) < 1L) {
    return(NULL)
  }

  if (!is.null(requested_sample) && nzchar(requested_sample) && requested_sample %in% beta_cols) {
    return(requested_sample)
  }

  if (!is.null(meta_x) && is.data.frame(meta_x) && "Sample_Name" %in% colnames(meta_x)) {
    valid <- intersect(beta_cols, as.character(meta_x$Sample_Name))
    if (length(valid) > 0L) {
      return(valid[1])
    }
  }

  fallback <- setdiff(beta_cols, c("NAME", "TargetID", "ID"))
  if (length(fallback) > 0L) {
    return(fallback[1])
  }

  beta_cols[1]
}

.imprint_subset_beta_by_probeset <- function(beta_x, probeset_name, plot_type, probeset_df = NULL) {
  if (!is.character(probeset_name) || length(probeset_name) != 1L || is.na(probeset_name) || !nzchar(probeset_name)) {
    stop("plot_type='", plot_type, "' requires a non-empty 'probeset' parameter.")
  }

  if (is.null(probeset_df)) {
    probesets_path <- .resolve_extdata_file("probesets_hg19.rds")
    probesets_all <- readRDS(probesets_path)
    if (!(probeset_name %in% names(probesets_all))) {
      stop("plot_type='", plot_type, "' received unavailable probeset: ", probeset_name)
    }

    probeset_df <- probesets_all[[probeset_name]]
  }
  if (!is.data.frame(probeset_df) || !"NAME" %in% colnames(probeset_df)) {
    stop("Probeset annotation for '", probeset_name, "' is invalid or missing NAME column.")
  }

  keep_probes <- intersect(rownames(beta_x), as.character(probeset_df$NAME))
  if (length(keep_probes) == 0L) {
    stop("plot_type='", plot_type, "' found no overlapping probes between beta(x) and probeset '", probeset_name, "'.")
  }

  beta_x[keep_probes, , drop = FALSE]
}

.imprint_normalize_chr <- function(chr_vals) {
  chr_vals <- as.character(chr_vals)
  chr_vals <- gsub("^chr", "", chr_vals, ignore.case = TRUE)
  paste0("chr", chr_vals)
}

.imprint_get_probeset_df <- function(probeset_name, plot_type, required_cols = c("NAME", "ORIGIN", "CHR"), probeset_df = NULL) {
  if (!is.character(probeset_name) || length(probeset_name) != 1L || is.na(probeset_name) || !nzchar(probeset_name)) {
    stop("plot_type='", plot_type, "' requires a non-empty 'probeset' parameter.")
  }

  if (is.null(probeset_df)) {
    probesets_path <- .resolve_extdata_file("probesets_hg19.rds")
    probesets_all <- readRDS(probesets_path)
    if (!(probeset_name %in% names(probesets_all))) {
      stop("plot_type='", plot_type, "' received unavailable probeset: ", probeset_name)
    }

    probeset_df <- probesets_all[[probeset_name]]
  }
  missing_cols <- setdiff(required_cols, colnames(probeset_df))
  if (length(missing_cols) > 0L) {
    stop("Probeset '", probeset_name, "' is missing required columns: ", paste(missing_cols, collapse = ", "))
  }
  probeset_df
}

.imprint_beeswarm_origin <- function(beta_x, meta_x, SAMPLEID, probeset_name, alpha = 0.5,
                                     outFile = NULL, width = NULL, height = NULL,
                                     title = "ImprintomeR: Beeswarm Origin", max_samples = 100,
                                     probeset_df = NULL) {
  if (!is.data.frame(meta_x) || !all(c("Sample_Name", SAMPLEID) %in% colnames(meta_x))) {
    stop("plot_type='beeswarm_origin' requires meta(x) with Sample_Name and ", SAMPLEID, " columns.")
  }

  probeset_df <- .imprint_get_probeset_df(probeset_name, plot_type = "beeswarm_origin", probeset_df = probeset_df)
  common_probes <- intersect(rownames(beta_x), as.character(probeset_df$NAME))
  if (length(common_probes) == 0L) {
    stop("plot_type='beeswarm_origin' found no overlapping probes between beta(x) and probeset '", probeset_name, "'.")
  }

  valid_ids <- intersect(as.character(meta_x$Sample_Name), colnames(beta_x))
  if (length(valid_ids) == 0L) {
    stop("plot_type='beeswarm_origin' requires overlapping sample IDs between beta(x) and meta(x)$Sample_Name.")
  }

  n_valid_ids <- length(valid_ids)
  max_samples <- as.numeric(max_samples)[1]
  if (is.na(max_samples) || max_samples <= 0) {
    max_samples <- Inf
  }
  if (is.finite(max_samples) && n_valid_ids > max_samples) {
    max_samples <- as.integer(max_samples)
    valid_ids <- valid_ids[seq_len(max_samples)]
    message(
      "plot_type='beeswarm_origin' uses the first ", max_samples,
      " of ", n_valid_ids, " matched samples. Set max_samples = Inf to plot all samples."
    )
  }

  meta_sub <- meta_x[match(valid_ids, as.character(meta_x$Sample_Name)), , drop = FALSE]
  beta_sub <- beta_x[common_probes, valid_ids, drop = FALSE]
  sample_labels <- as.character(meta_sub[[SAMPLEID]])
  colnames(beta_sub) <- sample_labels

  plot_df <- as.data.frame(beta_sub, stringsAsFactors = FALSE, check.names = FALSE)
  plot_df$Probe <- rownames(beta_sub)
  anno <- probeset_df[match(common_probes, as.character(probeset_df$NAME)), c("NAME", "ORIGIN"), drop = FALSE]
  rownames(anno) <- as.character(anno$NAME)
  plot_df$CATEGORY_RAW <- as.character(anno[plot_df$Probe, "ORIGIN"])

  used <- reshape2::melt(
    plot_df,
    id.vars = c("Probe", "CATEGORY_RAW"),
    variable.name = "ID",
    value.name = "value"
  )
  used$value <- as.numeric(as.character(used$value))
  used <- used[is.finite(used$value), , drop = FALSE]
  used$CATEGORY <- ifelse(
    grepl("maternal", used$CATEGORY_RAW, ignore.case = TRUE), "maternal",
    ifelse(grepl("paternal", used$CATEGORY_RAW, ignore.case = TRUE), "paternal", "other")
  )
  used$CATEGORY <- factor(used$CATEGORY, levels = c("maternal", "paternal", "other"))
  if (nrow(used) == 0L) {
    stop("plot_type='beeswarm_origin' has no finite probe values after filtering.")
  }

  num_groups <- length(unique(used$CATEGORY))
  dotSize <- max(0.3, 1 - log10(nrow(used) + 1) / 5)

  pg <- ggplot2::ggplot(used, ggplot2::aes(x = interaction(ID, CATEGORY), y = value, color = CATEGORY)) +
    ggbeeswarm::geom_quasirandom(size = dotSize, alpha = alpha, pch = 20) +
    ggplot2::stat_summary(
      fun = median,
      geom = "errorbar",
      ggplot2::aes(ymin = after_stat(y), ymax = after_stat(y)),
      width = 0.75,
      linewidth = 0.8,
      color = "grey30"
    ) +
    ggplot2::facet_wrap(~ID, nrow = 1, scales = "free_x", strip.position = "bottom") +
    ggplot2::scale_x_discrete(labels = function(x) {
      labels <- rep("", length(x))
      labels[seq(1, length(x), by = num_groups)] <- unlist(strsplit(as.character(x), "\\."))[1]
      labels
    }) +
    ggplot2::theme_minimal() +
    ggplot2::theme_classic(base_size = 10) +
    ggplot2::labs(
      title = title,
      subtitle = paste0("Probeset: ", probeset_name, " | Cohort origin-split beeswarm"),
      y = "Methylation Level",
      x = "ID"
    ) +
    ggplot2::theme(
      axis.text.x = ggplot2::element_text(angle = 90, hjust = 1),
      axis.title.x = ggplot2::element_blank(),
      axis.ticks.x = ggplot2::element_blank(),
      strip.text = ggplot2::element_blank(),
      strip.background = ggplot2::element_blank()
    )

  if (!is.null(outFile)) {
    ggplot2::ggsave(
      filename = outFile,
      plot = pg,
      width = ifelse(is.null(width), 10, width),
      height = ifelse(is.null(height), 6, height),
      units = "in",
      limitsize = TRUE
    )
  }
  pg
}

.imprint_beeswarm_chr <- function(beta_x, meta_x, SAMPLEID, probeset_name, sample_id = NULL,
                                  chr = NULL, alpha = 0.5, outFile = NULL,
                                  width = NULL, height = NULL,
                                  title = "ImprintomeR: Beeswarm by Chromosome") {
  probeset_df <- .imprint_get_probeset_df(probeset_name, plot_type = "beeswarm_chr")
  common_probes <- intersect(rownames(beta_x), as.character(probeset_df$NAME))
  if (length(common_probes) == 0L) {
    stop("plot_type='beeswarm_chr' found no overlapping probes between beta(x) and probeset '", probeset_name, "'.")
  }

  chosen_sample <- .imprint_choose_sample_id(beta_x, meta_x = meta_x, requested_sample = sample_id)
  if (is.null(chosen_sample)) {
    stop("plot_type='beeswarm_chr' requires a valid sample_id in beta(x).")
  }

  anno <- probeset_df[match(common_probes, as.character(probeset_df$NAME)), c("NAME", "ORIGIN", "CHR"), drop = FALSE]
  rownames(anno) <- as.character(anno$NAME)
  sample_vals <- as.numeric(beta_x[common_probes, chosen_sample])
  used <- data.frame(
    Probe = common_probes,
    value = sample_vals,
    CATEGORY_RAW = as.character(anno[common_probes, "ORIGIN"]),
    Chromosome = .imprint_normalize_chr(anno[common_probes, "CHR"]),
    stringsAsFactors = FALSE
  )
  used <- used[is.finite(used$value), , drop = FALSE]
  used$CATEGORY <- ifelse(
    grepl("maternal", used$CATEGORY_RAW, ignore.case = TRUE), "maternal",
    ifelse(grepl("paternal", used$CATEGORY_RAW, ignore.case = TRUE), "paternal", "other")
  )
  used$CATEGORY <- factor(used$CATEGORY, levels = c("maternal", "paternal", "other"))

  chr_scope <- "all"
  if (!is.null(chr) && nzchar(chr) && tolower(chr) != "all") {
    chr_norm <- .imprint_normalize_chr(chr)
    used <- used[used$Chromosome %in% chr_norm, , drop = FALSE]
    chr_scope <- chr_norm
  }
  if (nrow(used) == 0L) {
    stop("plot_type='beeswarm_chr' has no probe values after chromosome/probe filtering.")
  }

  used$Chromosome <- factor(used$Chromosome, levels = stringr::str_sort(unique(used$Chromosome), numeric = TRUE))
  used$ID <- as.character(used$Chromosome)
  num_groups <- length(unique(used$CATEGORY))
  dot_size <- max(2, 2 - log10(nrow(used) + 1) / 6)

  pg <- ggplot2::ggplot(used, ggplot2::aes(x = interaction(ID, CATEGORY), y = value, color = CATEGORY)) +
    ggbeeswarm::geom_quasirandom(size = dot_size, alpha = alpha, pch = 20) +
    ggplot2::stat_summary(
      fun = median,
      geom = "errorbar",
      ggplot2::aes(ymin = after_stat(y), ymax = after_stat(y)),
      width = 0.75,
      linewidth = 0.8,
      color = "grey30"
    ) +
    ggplot2::facet_wrap(~Chromosome, nrow = 1, scales = "free_x", strip.position = "bottom") +
    ggplot2::scale_x_discrete(labels = function(x) {
      labels <- rep("", length(x))
      labels[seq(1, length(x), by = num_groups)] <- vapply(
        strsplit(as.character(x), "\\."),
        function(parts) parts[1],
        character(1)
      )[seq(1, length(x), by = num_groups)]
      labels
    }) +
    ggplot2::geom_hline(yintercept = 0.5, linetype = "dashed", color = .imprint_origin_colors()["reference"]) +
    ggplot2::scale_color_manual(
      values = c(
        maternal = unname(.imprint_origin_colors()["maternal"]),
        paternal = unname(.imprint_origin_colors()["paternal"]),
        other = unname(.imprint_origin_colors()["reference"])
      ),
      name = "Allelic origin"
    ) +
    ggplot2::theme_minimal() +
    ggplot2::theme_classic(base_size = 10) +
    ggplot2::theme(
      axis.text.x = ggplot2::element_text(angle = 90, hjust = 1),
      axis.title.x = ggplot2::element_blank(),
      axis.ticks.x = ggplot2::element_blank(),
      strip.text = ggplot2::element_blank(),
      strip.background = ggplot2::element_blank(),
      legend.position = "bottom"
    ) +
    ggplot2::labs(
      title = title,
      subtitle = paste0("Sample: ", chosen_sample, " | Probeset: ", probeset_name, " | Chromosome: ", paste(chr_scope, collapse = ",")),
      x = "ID",
      y = "Methylation Level"
    ) +
    ggplot2::ylim(0, 1)

  if (!is.null(outFile)) {
    n_chr <- length(unique(used$Chromosome))
    ggplot2::ggsave(
      filename = outFile,
      plot = pg,
      width = ifelse(is.null(width), max(6, n_chr * 1.5), width),
      height = ifelse(is.null(height), 4, height),
      units = "in",
      limitsize = TRUE
    )
  }
  pg
}

#' @rdname ImprintomeSet-plot
#' @export
methods::setMethod(
  "plot",
  signature(x = "ImprintomeSet", y = "missing"),
  function(x, y, ...) {
    methods::validObject(x)

    args <- list(...)
    plot_type <- tolower(.imprint_get_arg_chr(args, "plot_type", "auto"))
    plot_name <- .imprint_get_arg_chr(args, "plot_name", NULL)
    result_name <- .imprint_get_arg_chr(args, "result_name", NULL)
    colorColumn <- .imprint_get_arg_chr(args, "colorColumn", "Sample_Group")
    probeset_name <- .imprint_get_arg_chr(args, "probeset", "selected")
    plot_probeset_df <- probeset(x)
    if (!is.data.frame(plot_probeset_df) || !"NAME" %in% colnames(plot_probeset_df)) plot_probeset_df <- NULL
    # Determine plot-type-specific default title
    default_title <- switch(plot_type,
      "polar" = "ImprintomeR:Polar",
      "mirror_density" = "ImprintomeR:Mirror Density",
      "beeswarm" = "ImprintomeR: beeswarm",
      "beeswarm_origin" = "ImprintomeR:beeswarm_origin",
      "beeswarm_chr" = "ImprintomeR:beeswarm_chr",
      "violin" = "ImprintomeR: Violin",
      "heatmap_by_probe" = "ImprintomeR: Heatmap",
      "circular_heatmap" = "ImprintomeR: Circular Heatmap",
      "cor_heatmap" = "ImprintomeR: Correlation",
      "rainfall" = "ImprintomeR: Rainfall",
      "radar" = "ImprintomeR: Radar",
      "ImprintomeR:Polar"  # fallback
    )
    title <- .imprint_get_arg_chr(args, "title", default_title)
    palette <- .imprint_get_arg_chr(args, "palette", "default")
    alpha <- if (!is.null(args$alpha)) as.numeric(args$alpha)[1] else 0.5
    legend.position <- .imprint_get_arg_chr(args, "legend.position", "auto")
    legend.nrow <- if (!is.null(args$legend.nrow)) as.integer(args$legend.nrow)[1] else NULL
    legend.ncol <- if (!is.null(args$legend.ncol)) as.integer(args$legend.ncol)[1] else NULL
    legend.page <- if (!is.null(args$legend.page)) args$legend.page[[1]] else "auto"
    legend.page.threshold <- if (!is.null(args$legend.page.threshold)) as.numeric(args$legend.page.threshold)[1] else 20
    legend.text.size <- if (!is.null(args$legend.text.size)) as.numeric(args$legend.text.size)[1] else 8
    outFile <- .imprint_get_arg_chr(args, "outFile", NULL)
    width <- if (!is.null(args$width)) as.numeric(args$width)[1] else 10
    height <- if (!is.null(args$height)) as.numeric(args$height)[1] else 10
    SAMPLEID <- .imprint_get_arg_chr(args, "SAMPLEID", "Sample_Name")
    max_samples <- if (!is.null(args$max_samples)) as.numeric(args$max_samples)[1] else 100

    sample_id <- .imprint_get_arg_chr(args, "sample_id", NULL)
    chr_focus <- .imprint_get_arg_chr(args, "chr", NULL)
    prefix <- .imprint_get_arg_chr(args, "prefix", NULL)
    sectionColumn <- .imprint_get_arg_chr(args, "sectionColumn", "Sample_Group")
    annoColumn <- .imprint_get_arg_chr(args, "annoColumn", "Sample_Group")
    clusterRows <- if (!is.null(args$clusterRows)) isTRUE(args$clusterRows) else TRUE
    clusterColumns <- if (!is.null(args$clusterColumns)) isTRUE(args$clusterColumns) else TRUE

    valid_plot_types <- c(
      "auto", "polar", "mirror_density", "beeswarm", "beeswarm_origin", "beeswarm_chr", "violin",
      "heatmap_by_probe", "heatmap_by_gene", "circular_heatmap", "cor_heatmap", "rainfall", "radar"
    )
    if (!(plot_type %in% valid_plot_types)) {
      stop("Unsupported plot_type: ", plot_type)
    }

    # 1) Dispatch to stored ggplot objects when available for auto mode.
    p_list <- plots(x)
    if (plot_type == "auto" && length(p_list) > 0L) {
      p_names <- names(p_list)
      if (is.null(p_names)) {
        p_names <- paste0("plot_", seq_along(p_list))
      }
      names(p_list) <- p_names

      candidate_name <- NULL
      if (!is.null(plot_name) && nzchar(plot_name) && plot_name %in% names(p_list)) {
        candidate_name <- plot_name
      } else {
        ordered_names <- sort(names(p_list))
        gg_candidates <- ordered_names[vapply(p_list[ordered_names], function(obj) inherits(obj, "ggplot"), logical(1))]
        if (length(gg_candidates) > 0L) {
          candidate_name <- gg_candidates[1]
        }
      }

      if (!is.null(candidate_name)) {
        stored_plot <- p_list[[candidate_name]]
        if (!is.null(outFile)) {
          ggplot2::ggsave(filename = outFile, plot = stored_plot, width = width, height = height, units = "in", limitsize = TRUE)
        }
        return(stored_plot)
      }
    }

    # 2) Resolve object slots for explicit dispatch and auto fallback.
    beta_x <- beta(x)
    meta_x <- meta(x)
    r_list <- results(x)

    r_names <- names(r_list)
    if (is.null(r_names) && length(r_list) > 0L) {
      r_names <- paste0("result_", seq_along(r_list))
      names(r_list) <- r_names
    }

    if (plot_type == "auto") {
      # Auto fallback: generate a default polar plot from results with IDS/Angle.
      if (length(r_list) == 0L) {
        stop("No stored plots available and results(x) is empty.")
      }

      plot_data <- .imprint_pick_result(
        r_list = r_list,
        result_name = result_name,
        required_cols = c("IDS", "Angle")
      )

      if (is.null(plot_data)) {
        stop("Could not find a result table with required columns: IDS and Angle.")
      }

      if (!colorColumn %in% colnames(plot_data)) {
        plot_data[[colorColumn]] <- "All"
      }

      return(
        PlotPolar(
          data = plot_data,
          outFile = outFile,
          colorColumn = colorColumn,
          title = title,
          palette = palette,
          alpha = alpha,
          legend.position = legend.position,
          legend.nrow = legend.nrow,
          legend.ncol = legend.ncol,
          legend.page = legend.page,
          legend.page.threshold = legend.page.threshold,
          legend.text.size = legend.text.size
        )
      )
    }

    # 3) Explicit plot type dispatch.
    if (plot_type == "polar") {
      plot_data <- .imprint_pick_result(
        r_list = r_list,
        result_name = result_name,
        required_cols = c("IDS", "Angle")
      )
      if (is.null(plot_data)) {
        stop("plot_type='polar' requires a result table containing IDS and Angle.")
      }
      if (!colorColumn %in% colnames(plot_data)) {
        plot_data[[colorColumn]] <- "All"
      }
      return(
        PlotPolar(
          data = plot_data,
          outFile = outFile,
          colorColumn = colorColumn,
          title = title,
          subtitle = paste0("Probeset: ", probeset_name),
          palette = palette,
          alpha = alpha,
          legend.position = legend.position,
          legend.nrow = legend.nrow,
          legend.ncol = legend.ncol,
          legend.page = legend.page,
          legend.page.threshold = legend.page.threshold,
          legend.text.size = legend.text.size
        )
      )
    }

    if (plot_type == "mirror_density") {
      return(
        MirrorDensity(
          betaFile = beta_x,
          metaFile = meta_x,
          SAMPLEID = SAMPLEID,
          probeset = probeset_name,
          outFile = outFile,
          max_samples = max_samples
        )
      )
    }

    if (plot_type == "beeswarm") {
      beta_plot <- .imprint_subset_beta_by_probeset(beta_x, probeset_name, plot_type = "beeswarm", probeset_df = plot_probeset_df)
      return(
        BetaBeePlot(
          beta = beta_plot,
          meta = meta_x,
          SAMPLEID = SAMPLEID,
          outFile = outFile,
          alpha = alpha,
          subtitle = paste0("Probeset: ", probeset_name),
          width = width,
          height = height
        )
      )
    }

    if (plot_type == "beeswarm_origin") {
      return(
        .imprint_beeswarm_origin(
          beta_x = beta_x,
          meta_x = meta_x,
          SAMPLEID = SAMPLEID,
          probeset_name = probeset_name,
          alpha = alpha,
          outFile = outFile,
          width = width,
          height = height,
          title = title,
          max_samples = max_samples,
          probeset_df = plot_probeset_df
        )
      )
    }

    if (plot_type == "beeswarm_chr") {
      return(
        .imprint_beeswarm_chr(
          beta_x = beta_x,
          meta_x = meta_x,
          SAMPLEID = SAMPLEID,
          probeset_name = probeset_name,
          sample_id = sample_id,
          chr = chr_focus,
          alpha = alpha,
          outFile = outFile,
          width = width,
          height = height,
          title = title
        )
      )
    }

    if (plot_type == "violin") {
      beta_plot <- .imprint_subset_beta_by_probeset(beta_x, probeset_name, plot_type = "violin", probeset_df = plot_probeset_df)
      return(
        BetaVlnPlot(
          beta = beta_plot,
          meta = meta_x,
          SAMPLEID = SAMPLEID,
          outFile = outFile,
          alpha = alpha
        )
      )
    }

    if (plot_type == "heatmap_by_probe") {
      beta_plot <- .imprint_subset_beta_by_probeset(beta_x, probeset_name, plot_type = "heatmap_by_probe", probeset_df = plot_probeset_df)
      return(
        BetaHeatmap(
          beta = beta_plot,
          meta = meta_x,
          SAMPLEID = SAMPLEID,
          annoColumn = annoColumn,
          clusterRows = clusterRows,
          clusterColumns = clusterColumns,
          outFile = outFile
        )
      )
    }

    if (plot_type == "heatmap_by_gene") {
      return(
        BetaHeatmapByGene(
          beta = beta_x,
          meta = meta_x,
          probeset = probeset_name,
          SAMPLEID = SAMPLEID,
          annoColumn = annoColumn,
          clusterRows = clusterRows,
          clusterColumns = clusterColumns,
          outFile = outFile,
          imgSizeFactor = 0.5,
          probeset_data = plot_probeset_df
        )
      )
    }

    if (plot_type == "circular_heatmap") {
      # Use same probeset subsetting logic as beeswarm: subset beta first, then visualize
      beta_plot <- .imprint_subset_beta_by_probeset(beta_x, probeset_name, plot_type = "circular_heatmap", probeset_df = plot_probeset_df)

      # Check if sectionColumn exists and has meaningful values (not all "Unknown")
      effective_section_column <- sectionColumn
      if (!sectionColumn %in% colnames(meta_x)) {
        # sectionColumn doesn't exist; try to use Sample_Name instead
        effective_section_column <- "Sample_Name"
      } else {
        # sectionColumn exists but check if all values are "Unknown"
        unique_values <- unique(as.character(meta_x[[sectionColumn]]))
        if (length(unique_values) == 1 && unique_values[1] == "Unknown") {
          # All values are "Unknown"; use Sample_Name instead for meaningful grouping
          effective_section_column <- "Sample_Name"
        }
      }

      return(
        BetaCircularHeatmap(
          beta = beta_plot,
          meta = meta_x,
          probeset = NULL,
          SAMPLEID = SAMPLEID,
          sectionColumn = effective_section_column,
          outFile = outFile
        )
      )
    }

    if (plot_type == "cor_heatmap") {
      beta_plot <- .imprint_subset_beta_by_probeset(beta_x, probeset_name, plot_type = "cor_heatmap", probeset_df = plot_probeset_df)
      if (is.null(prefix) || !nzchar(prefix)) {
        if (!is.null(outFile) && nzchar(outFile)) {
          prefix <- tools::file_path_sans_ext(outFile)
        } else {
          prefix <- "imprintome"
        }
      }
      return(
        PlotCorHeatmap(
          betaFile = beta_plot,
          metaFile = meta_x,
          SAMPLEID = SAMPLEID,
          prefix = prefix
        )
      )
    }

    if (plot_type == "rainfall") {
      chosen_sample <- .imprint_choose_sample_id(beta_x, meta_x = meta_x, requested_sample = sample_id)
      if (is.null(chosen_sample)) {
        stop("plot_type='rainfall' requires at least one sample column in beta(x).")
      }
      return(
        PlotRainfall(
          beta = beta_x,
          sampleID = chosen_sample,
          title = title,
          probeset = probeset_name,
          outFile = outFile
        )
      )
    }

    if (plot_type == "radar") {
      beta_for_radar <- as.data.frame(beta_x, stringsAsFactors = FALSE, check.names = FALSE)
      numeric_cols <- vapply(beta_for_radar, is.numeric, logical(1))
      if (!all(numeric_cols)) {
        beta_for_radar <- beta_for_radar[, numeric_cols, drop = FALSE]
      }
      if (ncol(beta_for_radar) == 0L) {
        stop("plot_type='radar' requires at least one numeric sample column in beta(x).")
      }

      agg <- AggregateByLocus(beta_for_radar, probeset = probeset_name, probeset_data = plot_probeset_df)
      if (!is.data.frame(agg) || nrow(agg) == 0L || ncol(agg) == 0L) {
        stop("plot_type='radar' could not compute aggregated loci from beta(x).")
      }
      chosen_sample <- .imprint_choose_sample_id(agg, meta_x = meta_x, requested_sample = sample_id)
      if (is.null(chosen_sample)) {
        stop("plot_type='radar' requires a valid sample_id in aggregated beta matrix.")
      }
      radar_df <- data.frame(value = (agg[, chosen_sample] - 0.5) * 2)
      rownames(radar_df) <- rownames(agg)
      return(
        PlotRadar(
          df = radar_df,
          id = chosen_sample,
          title = title,
          outFile = outFile
        )
      )
    }

    stop("Unsupported plot_type: ", plot_type)
  }
)

