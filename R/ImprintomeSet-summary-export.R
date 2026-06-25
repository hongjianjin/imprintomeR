#' Summarize ImprintomeSet Contents
#'
#' Returns a concise, deterministic summary of object slots and stored outputs.
#'
#' @param object An `ImprintomeSet` object.
#' @param ... Reserved for future extensions.
#'
#' @return A list with `object`, `results`, and `plots` summary tables.
#' @name summarize
#' @export
#'
#' @examples
#' \dontrun{
#' s <- summarize(x)
#' s$object
#' s$results
#' }
#' @rdname summarize
#' @export
methods::setMethod(
  "summarize",
  signature(object = "ImprintomeSet"),
  function(object, ...) {
    methods::validObject(object)

    beta_obj <- beta(object)
    meta_obj <- meta(object)
    ps_obj <- probeset(object)

    beta_nrow <- if (!is.null(dim(beta_obj))) nrow(beta_obj) else NA_integer_
    beta_ncol <- if (!is.null(dim(beta_obj))) ncol(beta_obj) else NA_integer_

    meta_nrow <- if (is.data.frame(meta_obj)) nrow(meta_obj) else NA_integer_
    meta_ncol <- if (is.data.frame(meta_obj)) ncol(meta_obj) else NA_integer_

    probeset_type <- class(ps_obj)[1]
    if (is.data.frame(ps_obj)) {
      probeset_nrow <- nrow(ps_obj)
      probeset_ncol <- ncol(ps_obj)
      probeset_info <- if ("NAME" %in% colnames(ps_obj)) {
        paste0("NAME column present (n=", length(unique(ps_obj$NAME)), ")")
      } else {
        "NAME column absent"
      }
    } else {
      probeset_nrow <- as.integer(length(ps_obj))
      probeset_ncol <- NA_integer_
      probeset_info <- "list-based probeset"
    }

    object_tbl <- data.frame(
      assay = object@assay,
      genome = object@genome,
      beta_nrow = beta_nrow,
      beta_ncol = beta_ncol,
      meta_nrow = meta_nrow,
      meta_ncol = meta_ncol,
      probeset_type = probeset_type,
      probeset_nrow = probeset_nrow,
      probeset_ncol = probeset_ncol,
      probeset_info = probeset_info,
      stringsAsFactors = FALSE
    )

    res_list <- results(object)
    res_names <- names(res_list)
    if (is.null(res_names)) {
      res_names <- paste0("result_", seq_along(res_list))
    }
    if (length(res_list) > 0L) {
      ord <- order(res_names)
      res_names <- res_names[ord]
      res_list <- res_list[ord]
      results_tbl <- data.frame(
        name = res_names,
        class = vapply(res_list, function(z) class(z)[1], character(1)),
        nrow = vapply(res_list, function(z) if (!is.null(dim(z))) nrow(z) else NA_integer_, integer(1)),
        ncol = vapply(res_list, function(z) if (!is.null(dim(z))) ncol(z) else NA_integer_, integer(1)),
        stringsAsFactors = FALSE
      )
    } else {
      results_tbl <- data.frame(name = character(0), class = character(0), nrow = integer(0), ncol = integer(0), stringsAsFactors = FALSE)
    }

    plot_list <- plots(object)
    if (length(plot_list) > 0L) {
      plot_names <- names(plot_list)
      if (is.null(plot_names) || length(plot_names) != length(plot_list)) {
        plot_names <- rep("", length(plot_list))
      }
      missing_plot_names <- is.na(plot_names) | !nzchar(plot_names)
      plot_names[missing_plot_names] <- paste0("plot_", which(missing_plot_names))

      ord <- order(plot_names)
      plot_names <- plot_names[ord]
      plot_list <- plot_list[ord]
      plots_tbl <- data.frame(
        name = plot_names,
        class = vapply(plot_list, function(z) class(z)[1], character(1)),
        stringsAsFactors = FALSE
      )
    } else {
      plots_tbl <- data.frame(name = character(0), class = character(0), stringsAsFactors = FALSE)
    }

    list(object = object_tbl, results = results_tbl, plots = plots_tbl)
  }
)


#' Export ImprintomeSet Outputs to Disk
#'
#' Writes the `ImprintomeSet` object, selected result tables, and optionally stored plots to `outdir`.
#' Data-frame/matrix results are exported as TSV; other result objects are saved
#' as RDS. Plot export supports ggplot-compatible, ComplexHeatmap, recorded, and
#' file-backed plot objects as plot files when possible; other plot object types are serialized as RDS.
#'
#' @param x An `ImprintomeSet` object.
#' @param outdir Output directory.
#' @param result_names Character vector of result names to export. `NULL` means all.
#' @param prefix Filename prefix for exported files, including the saved `ImprintomeSet` object and plot files.
#' @param save_plots Logical; whether to export plot objects in `plots(x)`.
#' @param plot_names Character vector of plot names to export when `save_plots=TRUE`.
#'   `NULL` means all stored plots.
#' @param plot_device Graphics device for ggplot export (`"pdf"` or `"png"`).
#' @param width Plot width in inches.
#' @param height Plot height in inches.
#' @param overwrite Logical; overwrite existing files.
#' @param ... Reserved for future extensions.
#'
#' @return A data.frame manifest with one row per exported object.
#' @name export
#' @export
#'
#' @examples
#' \dontrun{
#' manifest <- export(x, outdir = "imprintome_export", prefix = "imprintome", save_plots = TRUE)
#' head(manifest)
#' }
if (!methods::isGeneric("export")) {
  methods::setGeneric(
    "export",
    function(x, outdir, result_names = NULL, save_plots = FALSE, plot_names = NULL,
             plot_device = "pdf", width = 8, height = 6, overwrite = TRUE, prefix = "imprintome", ...) {
      standardGeneric("export")
    }
  )
}

#' @rdname export
#' @export
methods::setMethod(
  "export",
  signature(x = "ImprintomeSet"),
  function(x, outdir, result_names = NULL, save_plots = FALSE, plot_names = NULL,
           plot_device = "pdf", width = 8, height = 6, overwrite = TRUE, prefix = "imprintome", ...) {
    methods::validObject(x)

    if (!dir.exists(outdir)) {
      dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
    }

    sanitize_name <- function(s) gsub("[^A-Za-z0-9_.-]", "_", s)

    manifest <- data.frame(
      category = character(0),
      name = character(0),
      file = character(0),
      status = character(0),
      stringsAsFactors = FALSE
    )

    safe_prefix <- if (is.null(prefix) || length(prefix) == 0L) "" else sanitize_name(as.character(prefix)[1])
    if (is.na(safe_prefix) || !nzchar(safe_prefix)) {
      safe_prefix <- "imprintome"
    }

    # Export full ImprintomeSet object
    object_path <- file.path(outdir, paste0(safe_prefix, "_imprintomeSet.rds"))
    if (!overwrite && file.exists(object_path)) {
      object_status <- "skipped_exists"
    } else {
      saveRDS(x, object_path)
      object_status <- "written"
    }
    manifest <- rbind(
      manifest,
      data.frame(category = "object", name = "ImprintomeSet", file = object_path, status = object_status, stringsAsFactors = FALSE)
    )

    # Export results
    res_list <- results(x)
    res_names <- names(res_list)
    if (is.null(res_names)) {
      res_names <- paste0("result_", seq_along(res_list))
      names(res_list) <- res_names
    }

    if (is.null(result_names)) {
      result_names <- res_names
    }
    result_names <- sort(intersect(result_names, names(res_list)))

    for (nm in result_names) {
      obj <- res_list[[nm]]
      safe_nm <- sanitize_name(nm)

      if (is.data.frame(obj) || is.matrix(obj)) {
        fpath <- file.path(outdir, paste0("results_", safe_nm, ".tsv"))
        if (!overwrite && file.exists(fpath)) {
          status <- "skipped_exists"
        } else {
          write.table(obj, fpath, sep = "\t", quote = FALSE, row.names = FALSE, col.names = TRUE)
          status <- "written"
        }
      } else {
        fpath <- file.path(outdir, paste0("results_", safe_nm, ".rds"))
        if (!overwrite && file.exists(fpath)) {
          status <- "skipped_exists"
        } else {
          saveRDS(obj, fpath)
          status <- "written"
        }
      }

      manifest <- rbind(
        manifest,
        data.frame(category = "results", name = nm, file = fpath, status = status, stringsAsFactors = FALSE)
      )
    }

    # Export plots
    if (isTRUE(save_plots)) {
      p_list <- plots(x)
      if (length(p_list) == 0L) {
        message("No stored plots found in plots(x); skipping plot export.")
      } else {
        p_names <- names(p_list)
        if (is.null(p_names) || length(p_names) != length(p_list)) {
          p_names <- rep("", length(p_list))
        }
        missing_plot_names <- is.na(p_names) | !nzchar(p_names)
        p_names[missing_plot_names] <- paste0("plot_", which(missing_plot_names))
        names(p_list) <- p_names

        if (is.null(plot_names)) {
          plot_names <- p_names
        }
        requested_plot_names <- plot_names
        plot_names <- sort(intersect(plot_names, names(p_list)))
        if (length(plot_names) == 0L) {
          message("No matching stored plots found for export. Stored plots: ", paste(names(p_list), collapse = ", "),
                  "; requested plots: ", paste(requested_plot_names, collapse = ", "))
        }

        plot_device <- tolower(plot_device)
        if (!plot_device %in% c("pdf", "png")) {
          stop("plot_device must be one of: pdf, png")
        }

        for (nm in plot_names) {
          pobj <- p_list[[nm]]
          safe_nm <- sanitize_name(nm)

          if (inherits(pobj, "ggplot") || inherits(pobj, "patchwork")) {
            fpath <- file.path(outdir, paste0(safe_prefix, "_plot_", safe_nm, ".", plot_device))
            if (!overwrite && file.exists(fpath)) {
              status <- "skipped_exists"
            } else {
              ggplot2::ggsave(filename = fpath, plot = pobj, width = width, height = height, units = "in", limitsize = TRUE)
              status <- "written"
            }
          } else if (inherits(pobj, "imprintome_plot_file") && is.raw(pobj$bytes)) {
            device <- if (!is.null(pobj$device) && nzchar(pobj$device)) pobj$device else "pdf"
            fpath <- file.path(outdir, paste0(safe_prefix, "_plot_", safe_nm, ".", device))
            if (!overwrite && file.exists(fpath)) {
              status <- "skipped_exists"
            } else {
              writeBin(pobj$bytes, fpath)
              status <- "written"
            }
          } else if (inherits(pobj, "Heatmap") || inherits(pobj, "HeatmapList")) {
            fpath <- file.path(outdir, paste0(safe_prefix, "_plot_", safe_nm, ".", plot_device))
            if (!overwrite && file.exists(fpath)) {
              status <- "skipped_exists"
            } else {
              if (identical(plot_device, "pdf")) {
                grDevices::pdf(fpath, width = width, height = height)
              } else {
                grDevices::png(fpath, width = width, height = height, units = "in", res = 300)
              }
              tryCatch(
                ComplexHeatmap::draw(pobj, merge_legend = TRUE),
                finally = grDevices::dev.off()
              )
              status <- "written"
            }
          } else if (inherits(pobj, "recordedplot")) {
            fpath <- file.path(outdir, paste0(safe_prefix, "_plot_", safe_nm, ".pdf"))
            if (!overwrite && file.exists(fpath)) {
              status <- "skipped_exists"
            } else {
              grDevices::pdf(fpath, width = width, height = height)
              tryCatch(
                grDevices::replayPlot(pobj),
                finally = grDevices::dev.off()
              )
              status <- "written"
            }
          } else {
            fpath <- file.path(outdir, paste0(safe_prefix, "_plot_", safe_nm, ".rds"))
            if (!overwrite && file.exists(fpath)) {
              status <- "skipped_exists"
            } else {
              saveRDS(pobj, fpath)
              status <- "written"
            }
          }

          manifest <- rbind(
            manifest,
            data.frame(category = "plots", name = nm, file = fpath, status = status, stringsAsFactors = FALSE)
          )
        }
      }
    }

    manifest
  }
)
