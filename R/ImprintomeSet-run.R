#' Run Core Imprintome Analysis
#'
#' User-facing entry point for running the core IDS/Angle/mechanism workflow on
#' an `ImprintomeSet` object using existing `AnalyzeImprintStatus()` logic.
#'
#' @param x An `ImprintomeSet` object.
#' @param probeset Character scalar probeset name (for example, `"selected"`).
#' @param ids_cutoff Numeric IDS cutoff passed to `AnalyzeImprintStatus()`.
#' @param result_name Optional name for storing output in `results(x)`.
#' @param ... Reserved for future compatibility.
#'
#' @return Updated `ImprintomeSet` object with analysis table stored in
#'   `results(x)`.
#' @name runImprintome
#' @export
#'
#' @examples
#' \dontrun{
#' beta_mat <- matrix(runif(200), nrow = 20)
#' rownames(beta_mat) <- paste0("cg", sprintf("%08d", seq_len(20)))
#' colnames(beta_mat) <- c("S1", "S2", "S3", "S4", "S5", "S6", "S7", "S8", "S9", "S10")
#'
#' meta_df <- data.frame(
#'   SAMPLE_NAME = colnames(beta_mat),
#'   SAMPLE_GROUP = rep(c("A", "B"), each = 5),
#'   stringsAsFactors = FALSE
#' )
#'
#' probeset_df <- data.frame(
#'   NAME = rownames(beta_mat),
#'   stringsAsFactors = FALSE
#' )
#'
#' x <- ImprintomeSet(
#'   beta = beta_mat,
#'   meta = meta_df,
#'   probeset = probeset_df,
#'   genome = "hg19",
#'   assay = "EPICv1"
#' )
#'
#' x <- runImprintome(x, probeset = "selected", ids_cutoff = 0.2)
#' head(results(x)[["AnalyzeImprintStatus.selected"]])
#' }
if (!methods::isGeneric("runImprintome")) {
  methods::setGeneric(
    "runImprintome",
    function(x, probeset = "selected", ids_cutoff = 0.2, result_name = NULL, ...) {
      standardGeneric("runImprintome")
    }
  )
}

#' @rdname runImprintome
#' @export
methods::setMethod(
  "runImprintome",
  signature(x = "ImprintomeSet"),
  function(x, probeset = "selected", ids_cutoff = 0.2, result_name = NULL, ...) {
    methods::validObject(x)

    # Convert beta matrix to data frame with TargetID column (required by LoadBeta)
    beta_df <- as.data.frame(beta(x))
    beta_df <- cbind(TargetID = rownames(beta(x)), beta_df)

    analysis_table <- AnalyzeImprintStatus(
      betaFile = beta_df,
      metaFile = meta(x),
      probeset = probeset,
      ids_cutoff = ids_cutoff
    )

    current_results <- results(x)
    if (is.null(result_name) || !nzchar(result_name)) {
      result_name <- paste0("AnalyzeImprintStatus.", probeset)
    }
    current_results[[result_name]] <- analysis_table
    results(x) <- current_results

    x
  }
)
