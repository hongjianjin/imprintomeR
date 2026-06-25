#' Run Standard ImprintomeSet Visualizations
#'
#' Generate a standard set of `ImprintomeSet` plots using the object-first
#' `plot()` dispatcher. Successful plots can be stored in `plots(x)` and/or
#' written to disk. Direct-draw plots, such as circular heatmaps, are captured
#' as file-backed plot objects when possible.
#'
#' @param x An `ImprintomeSet` object.
#' @param plot_types Character vector of plot types. Use `"default"` for the
#'   standard workflow set, or `"all"` for all supported non-auto plot types.
#' @param probeset Probeset name passed to plot backends.
#' @param result_name Optional result table name for result-driven plots.
#' @param sample_id Optional sample ID for sample-level plot types.
#' @param prefix Filename prefix used when `save_plots = TRUE`.
#' @param outdir Output directory used when `save_plots = TRUE`.
#' @param save_plots Logical; write plot files while generating plots.
#' @param store_plots Logical; store successful plot objects in `plots(x)`.
#' @param overwrite Logical; overwrite existing plot files.
#' @param SAMPLEID Metadata column used for sample labels.
#' @param annoColumn Metadata column used for heatmap annotation.
#' @param sectionColumn Metadata column used for circular heatmap sections.
#' @param colorColumn Result column used for polar plot colors.
#' @param rainfall_probeset Probeset used for rainfall plots.
#' @param chr Chromosome focus for `beeswarm_chr`; `NULL` uses all chromosomes.
#' @param plot_device File extension for saved plots. Currently only `"pdf"` is
#'   supported because several plotting backends write PDF devices directly.
#' @param verbose Logical; print progress messages.
#' @param ... Additional arguments passed to `plot()`.
#'
#' @return The updated `ImprintomeSet`. A data.frame describing attempted plots
#'   is attached as `attr(x, "visualization_manifest")`.
#' @export
#'
#' @examples
#' \dontrun{
#' x <- runImprintomeVisualizations(x, prefix = "GSE240091")
#' names(plots(x))
#' }
runImprintomeVisualizations <- function(x,
                                        plot_types = "default",
                                        probeset = "selected",
                                        result_name = NULL,
                                        sample_id = NULL,
                                        prefix = "imprintome",
                                        outdir = NULL,
                                        save_plots = FALSE,
                                        store_plots = TRUE,
                                        overwrite = TRUE,
                                        SAMPLEID = "Sample_Name",
                                        annoColumn = "Sample_Group",
                                        sectionColumn = "Sample_Group",
                                        colorColumn = "Sample_Group",
                                        rainfall_probeset = "classifier3",
                                        chr = NULL,
                                        plot_device = "pdf",
                                        verbose = TRUE,
                                        ...) {
  if (!methods::is(x, "ImprintomeSet")) {
    stop("x must be an ImprintomeSet object.", call. = FALSE)
  }

  default_types <- c(
    "polar",
    "beeswarm_origin",
    "mirror_density",
    "heatmap_by_probe",
    "heatmap_by_gene",
    "radar",
    "beeswarm_chr",
    "rainfall"
  )
  all_types <- c(
    "polar",
    "mirror_density",
    "beeswarm",
    "beeswarm_origin",
    "beeswarm_chr",
    "violin",
    "heatmap_by_probe",
    "heatmap_by_gene",
    "circular_heatmap",
    "cor_heatmap",
    "rainfall",
    "radar"
  )

  if (identical(plot_types, "default")) {
    plot_types <- default_types
  } else if (identical(plot_types, "all")) {
    plot_types <- all_types
  }
  plot_types <- unique(tolower(as.character(plot_types)))

  valid_types <- c("auto", all_types)
  invalid <- setdiff(plot_types, valid_types)
  if (length(invalid) > 0L) {
    stop("Unsupported plot_types: ", paste(invalid, collapse = ", "), call. = FALSE)
  }

  plot_device <- tolower(as.character(plot_device)[1])
  if (!identical(plot_device, "pdf")) {
    stop("plot_device must be 'pdf'.", call. = FALSE)
  }

  if (isTRUE(save_plots)) {
    if (is.null(outdir) || !nzchar(outdir)) {
      stop("outdir is required when save_plots = TRUE.", call. = FALSE)
    }
    dir.create(outdir, showWarnings = FALSE, recursive = TRUE)
  }

  safe_name <- function(s) gsub("[^A-Za-z0-9_.-]", "_", as.character(s)[1])
  safe_prefix <- safe_name(prefix)
  if (is.na(safe_prefix) || !nzchar(safe_prefix)) {
    safe_prefix <- "imprintome"
  }

  beta_x <- beta(x)
  meta_x <- meta(x)
  chosen_sample <- .imprint_choose_sample_id(beta_x, meta_x = meta_x, requested_sample = sample_id)
  sample_suffix <- if (!is.null(chosen_sample) && nzchar(chosen_sample)) safe_name(chosen_sample) else "sample1"

  plot_name_for <- function(plot_type) {
    switch(plot_type,
      "auto" = "auto.selected",
      "polar" = paste0("polar.", probeset),
      "mirror_density" = paste0("mirror_density.", probeset),
      "beeswarm" = paste0("beeswarm.", probeset),
      "beeswarm_origin" = paste0("beeswarm_origin.", probeset),
      "beeswarm_chr" = paste0("beeswarm_chr.", sample_suffix),
      "violin" = paste0("violin.", probeset),
      "heatmap_by_probe" = paste0("heatmap.", probeset),
      "heatmap_by_gene" = paste0("heatmap_by_gene.", probeset),
      "circular_heatmap" = paste0("circular.", probeset),
      "cor_heatmap" = paste0("cor_heatmap.", probeset),
      "rainfall" = paste0("rainfall.", sample_suffix),
      "radar" = paste0("radar.", sample_suffix),
      paste0(plot_type, ".", probeset)
    )
  }

  plot_file_for <- function(plot_type, plot_name) {
    if (!isTRUE(save_plots)) {
      return(NULL)
    }
    file.path(outdir, paste0(safe_prefix, "_", safe_name(plot_name), ".", plot_device))
  }

  common_args <- list(...)
  p_list <- plots(x)
  manifest <- data.frame(
    plot_type = character(0),
    name = character(0),
    status = character(0),
    file = character(0),
    message = character(0),
    stringsAsFactors = FALSE
  )

  for (plot_type in plot_types) {
    plot_name <- plot_name_for(plot_type)
    out_file <- plot_file_for(plot_type, plot_name)
    if (!is.null(out_file) && file.exists(out_file) && !isTRUE(overwrite)) {
      manifest <- rbind(
        manifest,
        data.frame(plot_type = plot_type, name = plot_name, status = "skipped_exists", file = out_file, message = "", stringsAsFactors = FALSE)
      )
      next
    }

    plot_args <- list(
      x = x,
      plot_type = plot_type,
      result_name = result_name,
      probeset = probeset,
      SAMPLEID = SAMPLEID,
      annoColumn = annoColumn,
      sectionColumn = sectionColumn,
      colorColumn = colorColumn,
      outFile = out_file
    )

    if (plot_type %in% c("rainfall", "radar", "beeswarm_chr")) {
      plot_args$sample_id <- chosen_sample
    }
    if (plot_type == "rainfall") {
      plot_args$probeset <- rainfall_probeset
    }
    if (plot_type == "beeswarm_chr" && !is.null(chr)) {
      plot_args$chr <- chr
    }
    if (plot_type == "cor_heatmap") {
      plot_args$prefix <- if (isTRUE(save_plots)) {
        tools::file_path_sans_ext(out_file)
      } else {
        safe_prefix
      }
      plot_args$outFile <- NULL
    }

    plot_args <- utils::modifyList(plot_args, common_args)

    capture_file <- NULL
    if (identical(plot_type, "circular_heatmap") && isTRUE(store_plots) && !isTRUE(save_plots)) {
      capture_file <- tempfile(pattern = paste0(safe_prefix, "_", safe_name(plot_name), "_"), fileext = ".pdf")
      plot_args$outFile <- capture_file
    }

    if (isTRUE(verbose)) {
      message("Generating ", plot_type, " ...", appendLF = FALSE)
    }

    plot_obj <- NULL
    err <- NULL
    tryCatch(
      {
        if (!is.null(capture_file)) {
          utils::capture.output(plot_obj <- do.call(plot, plot_args))
        } else {
          plot_obj <- do.call(plot, plot_args)
        }
      },
      error = function(e) {
        err <<- conditionMessage(e)
      }
    )

    if (!is.null(err)) {
      if (!is.null(capture_file) && file.exists(capture_file)) {
        unlink(capture_file)
      }
      if (isTRUE(verbose)) {
        message(" skipped: ", err)
      }
      warning("Skipping plot_type='", plot_type, "': ", err, call. = FALSE)
      manifest <- rbind(
        manifest,
        data.frame(plot_type = plot_type, name = plot_name, status = "skipped_error", file = ifelse(is.null(out_file), "", out_file), message = err, stringsAsFactors = FALSE)
      )
      next
    }

    if (isTRUE(store_plots) && is.null(plot_obj) && !is.null(capture_file) && file.exists(capture_file)) {
      plot_obj <- structure(
        list(
          device = "pdf",
          filename = paste0(safe_name(plot_name), ".pdf"),
          bytes = readBin(capture_file, what = "raw", n = file.info(capture_file)$size),
          plot_type = plot_type
        ),
        class = c("imprintome_plot_file", "list")
      )
      unlink(capture_file)
    }

    if (isTRUE(store_plots) && is.null(plot_obj) && !isTRUE(save_plots)) {
      plot_obj <- tryCatch(
        grDevices::recordPlot(),
        error = function(e) NULL
      )
    }

    if (isTRUE(store_plots) && !is.null(plot_obj)) {
      p_list[[plot_name]] <- plot_obj
    }

    status <- if (isTRUE(save_plots)) "saved" else "generated"
    if (isTRUE(store_plots) && !is.null(plot_obj) && !isTRUE(save_plots)) {
      status <- if (inherits(plot_obj, "imprintome_plot_file")) "stored_file" else if (inherits(plot_obj, "recordedplot")) "stored_recorded" else "stored"
    }
    if (isTRUE(verbose)) {
      message(" ", status)
    }
    manifest <- rbind(
      manifest,
      data.frame(plot_type = plot_type, name = plot_name, status = status, file = ifelse(is.null(out_file), "", out_file), message = "", stringsAsFactors = FALSE)
    )
  }

  if (isTRUE(store_plots)) {
    plots(x) <- p_list
  }
  attr(x, "visualization_manifest") <- manifest
  methods::validObject(x)
  x
}
