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
    plot_names <- names(plot_list)
    if (is.null(plot_names)) {
      plot_names <- paste0("plot_", seq_along(plot_list))
    }
    if (length(plot_list) > 0L) {
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
#' Writes selected result tables and optionally stored plots to `outdir`.
#' Data-frame/matrix results are exported as TSV; other result objects are saved
#' as RDS. Plot export supports ggplot-compatible objects via `ggsave`; other
#' plot objects are saved as RDS.
#'
#' @param x An `ImprintomeSet` object.
#' @param outdir Output directory.
#' @param result_names Character vector of result names to export. `NULL` means all.
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
#' manifest <- export(x, outdir = "imprintome_export", save_plots = TRUE)
#' head(manifest)
#' }
if (!methods::isGeneric("export")) {
  methods::setGeneric(
    "export",
    function(x, outdir, result_names = NULL, save_plots = FALSE, plot_names = NULL,
             plot_device = "pdf", width = 8, height = 6, overwrite = TRUE, ...) {
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
           plot_device = "pdf", width = 8, height = 6, overwrite = TRUE, ...) {
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
      p_names <- names(p_list)
      if (is.null(p_names)) {
        p_names <- paste0("plot_", seq_along(p_list))
        names(p_list) <- p_names
      }

      if (is.null(plot_names)) {
        plot_names <- p_names
      }
      plot_names <- sort(intersect(plot_names, names(p_list)))

      plot_device <- tolower(plot_device)
      if (!plot_device %in% c("pdf", "png")) {
        stop("plot_device must be one of: pdf, png")
      }

      for (nm in plot_names) {
        pobj <- p_list[[nm]]
        safe_nm <- sanitize_name(nm)

        if (inherits(pobj, "ggplot") || inherits(pobj, "patchwork")) {
          fpath <- file.path(outdir, paste0("plot_", safe_nm, ".", plot_device))
          if (!overwrite && file.exists(fpath)) {
            status <- "skipped_exists"
          } else {
            ggplot2::ggsave(filename = fpath, plot = pobj, width = width, height = height, units = "in", limitsize = TRUE)
            status <- "written"
          }
        } else {
          fpath <- file.path(outdir, paste0("plot_", safe_nm, ".rds"))
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

    manifest
  }
)
