#' Run Core Imprintome Analysis
#'
#' User-facing entry point for running the core IDS/Angle/mechanism workflow on
#' an `ImprintomeSet` object using existing `AnalyzeImprintStatus()` logic.
#'
#' @param x An `ImprintomeSet` object.
#' @param probeset Character scalar probeset name (for example, `"selected"`).
#' @param ids_cutoff Numeric IDS cutoff passed to `AnalyzeImprintStatus()`.
#' @param result_name Optional name for storing output in `results(x)`.
#' @param dmr_type `DMR_type` selection passed to `AnalyzeImprintStatus()`.
#'   `NULL` (default) uses the panel default: gametic ICRs only for the core
#'   `selected` panel, all probes for other panels. Use `"all"` for all probes
#'   or, for example, `"secondary"` to score secondary DMRs separately. An
#'   explicit value is added to the default result name (for example
#'   `AnalyzeImprintStatus.selected.all`); the `dmr_type` column of the result
#'   records the selection applied.
#' @param reference,reference_group,reference_samples,reference_beta Reference
#'   centring options passed to `AnalyzeImprintStatus()`. By default (`"auto"`),
#'   external controls (`reference_beta`) or in-cohort controls
#'   (`reference_group`/`reference_samples`) are used when supplied, and the
#'   fixed 0.5 reference only when no controls are available.
#' @param infinium_type Infinium design types to score (`"all"`, `"I"`, `"II"`
#'   or `"balanced"`), passed to `AnalyzeImprintStatus()`.
#' @param balance `"probe"` (default) or `"icr"` for the ICR-balanced
#'   sample-level IDS/Angle, passed to `AnalyzeImprintStatus()`; `"icr"` adds
#'   `.icr` to the default result name.
#' @param min_probes Minimum probes per ICR for ICR-balanced and per-ICR
#'   scoring (default 3).
#' @param icr Logical. If `TRUE`, also score each ICR with
#'   [AnalyzeICRStatus()] (all annotated ICRs, with the same reference) and
#'   store the per-ICR table as `ICRStatus.<probeset>` and its per-sample
#'   multi-locus summary ([SummarizeICRStatus()]) as `ICRSummary.<probeset>`.
#' @param delta_cutoff,z_cutoff Thresholds for altered-ICR calls, passed to
#'   [AnalyzeICRStatus()] when `icr = TRUE` (defaults 0.075 and 3).
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
#'   Sample_Name = colnames(beta_mat),
#'   Sample_Group = rep(c("A", "B"), each = 5),
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
  function(x, probeset = "selected", ids_cutoff = 0.2, result_name = NULL, dmr_type = NULL,
           reference = c("auto", "controls", "fixed"), reference_group = NULL,
           reference_samples = NULL, reference_beta = NULL,
           infinium_type = c("all", "I", "II", "balanced"), balance = c("probe", "icr"),
           min_probes = 3L, icr = FALSE, delta_cutoff = 0.075, z_cutoff = 3, ...) {
    methods::validObject(x)

    # Convert beta matrix to data frame with TargetID column (required by LoadBeta)
    beta_df <- as.data.frame(beta(x))
    beta_df <- cbind(TargetID = rownames(beta(x)), beta_df)

    analysis_table <- AnalyzeImprintStatus(
      betaFile = beta_df,
      metaFile = meta(x),
      probeset = probeset,
      ids_cutoff = ids_cutoff,
      genome = genome(x),
      dmr_type = dmr_type,
      reference = reference,
      reference_group = reference_group,
      reference_samples = reference_samples,
      reference_beta = reference_beta,
      infinium_type = infinium_type,
      balance = balance,
      min_probes = min_probes
    )

    current_results <- results(x)
    if (is.null(result_name) || !nzchar(result_name)) {
      result_name <- paste0("AnalyzeImprintStatus.", probeset)
      if (!is.null(dmr_type)) {
        result_name <- paste0(result_name, ".", paste(dmr_type, collapse = "+"))
      }
      # Suffixes only for non-default choices, so default result names are unchanged.
      if (!startsWith(analysis_table$reference[1], "fixed")) {
        result_name <- paste0(result_name, ".ref-controls")
      }
      if (analysis_table$infinium_type[1] != "all") {
        result_name <- paste0(result_name, ".type", analysis_table$infinium_type[1])
      }
      if (analysis_table$balance[1] == "icr") {
        result_name <- paste0(result_name, ".icr")
      }
    }
    current_results[[result_name]] <- analysis_table

    if (isTRUE(icr)) {
      icr_table <- AnalyzeICRStatus(
        betaFile = beta_df,
        metaFile = meta(x),
        probeset = probeset,
        genome = genome(x),
        reference = reference,
        reference_group = reference_group,
        reference_samples = reference_samples,
        reference_beta = reference_beta,
        min_probes = min_probes,
        delta_cutoff = delta_cutoff,
        z_cutoff = z_cutoff
      )
      current_results[[paste0("ICRStatus.", probeset)]] <- icr_table
      current_results[[paste0("ICRSummary.", probeset)]] <- SummarizeICRStatus(icr_table)
    }
    results(x) <- current_results

    x
  }
)
