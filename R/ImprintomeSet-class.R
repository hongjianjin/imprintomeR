#' ImprintomeSet S4 Class
#'
#' Formal container for imprintomeR inputs and derived outputs.
#'
#' @slot beta Matrix or data.frame of beta values (rows = probes, columns = samples).
#' @slot meta data.frame of sample metadata. Must include `Sample_Name` and `Sample_Group` columns.
#' @slot probeset data.frame or list containing probeset annotation.
#' @slot genome Character scalar indicating genome build.
#' @slot assay Character scalar indicating array assay.
#' @slot results Named list of derived result tables/objects.
#' @slot plots Named list of generated plots.
#'
#' @name ImprintomeSet-class
#' @exportClass ImprintomeSet
NULL

setClassUnion("MatrixOrDataFrame", c("matrix", "data.frame"))
setClassUnion("DataFrameOrList", c("data.frame", "list"))

.validate_ImprintomeSet <- function(object) {
  errors <- character()

  beta <- object@beta
  meta <- object@meta
  probeset <- object@probeset

  # Basic scalar checks
  if (!is.character(object@genome) || length(object@genome) != 1L || is.na(object@genome) || !nzchar(object@genome)) {
    errors <- c(errors, "slot 'genome' must be a non-empty character scalar")
  }
  if (!is.character(object@assay) || length(object@assay) != 1L || is.na(object@assay) || !nzchar(object@assay)) {
    errors <- c(errors, "slot 'assay' must be a non-empty character scalar")
  }

  # beta structure checks
  if (is.null(dim(beta)) || length(dim(beta)) != 2L) {
    errors <- c(errors, "slot 'beta' must be 2-dimensional")
  } else {
    if (nrow(beta) < 1L || ncol(beta) < 1L) {
      errors <- c(errors, "slot 'beta' must have at least 1 row and 1 column")
    }
    if (is.null(colnames(beta))) {
      errors <- c(errors, "slot 'beta' must have sample column names")
    }
  }

  # meta structure checks
  if (!is.data.frame(meta)) {
    errors <- c(errors, "slot 'meta' must be a data.frame")
  } else {
    if (nrow(meta) < 1L) {
      errors <- c(errors, "slot 'meta' must have at least 1 row")
    }
    # Check required columns
    if (!("Sample_Name" %in% colnames(meta))) {
      errors <- c(errors, "slot 'meta' must contain column 'Sample_Name'")
    } else {
      if (anyDuplicated(meta$Sample_Name)) {
        errors <- c(errors, "slot 'meta$Sample_Name' must be unique")
      }
      if (!is.null(colnames(beta))) {
        common_samples <- intersect(colnames(beta), as.character(meta$Sample_Name))
        if (length(common_samples) == 0L) {
          errors <- c(errors, "no overlapping samples between colnames(beta) and meta$Sample_Name")
        }
      }
    }
    if (!("Sample_Group" %in% colnames(meta))) {
      errors <- c(errors, "slot 'meta' must contain column 'Sample_Group'")
    }
  }

  # probeset structural checks where possible
  if (is.data.frame(probeset)) {
    if (nrow(probeset) < 1L) {
      errors <- c(errors, "slot 'probeset' data.frame must have at least 1 row")
    }
    if (!is.null(rownames(beta)) && "NAME" %in% colnames(probeset)) {
      common_probes <- intersect(rownames(beta), as.character(probeset$NAME))
      if (length(common_probes) == 0L) {
        errors <- c(errors, "no overlapping probes between rownames(beta) and probeset$NAME")
      }
    }
  } else if (is.list(probeset)) {
    if (length(probeset) == 0L) {
      errors <- c(errors, "slot 'probeset' list must not be empty")
    }
  }

  # results / plots should be lists for stable downstream handling
  if (!is.list(object@results)) {
    errors <- c(errors, "slot 'results' must be a list")
  }
  if (!is.list(object@plots)) {
    errors <- c(errors, "slot 'plots' must be a list")
  }

  if (length(errors)) errors else TRUE
}

setClass(
  "ImprintomeSet",
  slots = c(
    beta = "MatrixOrDataFrame",
    meta = "data.frame",
    probeset = "DataFrameOrList",
    genome = "character",
    assay = "character",
    results = "list",
    plots = "list"
  ),
  prototype = list(
    results = list(),
    plots = list()
  ),
  validity = .validate_ImprintomeSet
)

#' Construct an ImprintomeSet Object
#'
#' @param beta Matrix or data.frame of beta values (rows = probes, columns = samples).
#' @param meta data.frame containing sample metadata. Must include `Sample_Name`; `Sample_Group` is required unless `auto_group=TRUE`.
#' @param probeset data.frame or list containing probeset annotation.
#' @param genome Character scalar for genome build (for example, `"hg19"` or `"hg38"`).
#' @param assay Character scalar for assay type (for example, `"450K"`, `"EPICv1"`, `"EPICv2"`).
#' @param results Optional named list of result objects.
#' @param plots Optional named list of plot objects.
#' @param auto_group Logical. If `TRUE` and `Sample_Group` column is missing, auto-creates it with value `"Unknown"` for all samples (Tier C: minimal metadata). Default: `FALSE`.
#'
#' @details
#' **Three metadata tiers supported:**
#' - **Tier A (QC-ready):** Sample_Name + Sample_Group + Basename (for runMethQC)
#' - **Tier B (Analysis-ready):** Sample_Name + Sample_Group (default requirement)
#' - **Tier C (Auto-group):** Sample_Name only (if `auto_group=TRUE`; Sample_Group auto-created with "Unknown")
#'
#' @return An object of class `ImprintomeSet`.
#' @export
ImprintomeSet <- function(beta,
                          meta,
                          probeset,
                          genome,
                          assay,
                          results = list(),
                          plots = list(),
                          auto_group = FALSE) {
  # Auto-create Sample_Group if missing and auto_group=TRUE (Tier C: minimal metadata)
  if (auto_group && !is.null(meta) && is.data.frame(meta)) {
    if (!"Sample_Group" %in% colnames(meta)) {
      meta$Sample_Group <- "Unknown"
      message("[ImprintomeSet] Sample_Group column not found. Auto-created with value 'Unknown' (auto_group=TRUE).")
    }
  }
  
  methods::new(
    "ImprintomeSet",
    beta = beta,
    meta = meta,
    probeset = probeset,
    genome = genome,
    assay = assay,
    results = results,
    plots = plots
  )
}

