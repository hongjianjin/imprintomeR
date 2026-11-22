#' Example data: GSE52576 beta values and metadata
#'
#' Small example bundled with imprintomeR for trying the package without downloading data:
#' the beta values of the 782 probes of the `"selected"` ICR panel for the 28 samples of GEO
#' series GSE52576 (Court et al., 2014; Illumina 450K), and their metadata. The samples include
#' normal tissues, androgenetic hydatidiform moles (paternal genome only), parthenogenetic
#' embryonic stem cells (maternal genome only) and leukocytes with genome-wide paternal or
#' maternal uniparental disomy.
#'
#' The files were built from the GEO series matrix (beta values as deposited) by
#' `data-raw/GSE52576_example.R` in the package source.
#'
#' @param which `"beta"` or `"meta"`.
#' @param path If `TRUE`, return the path of the tab-delimited file instead of its contents
#'   (for example to pass to `run_imprintomeR.R --beta` / `--meta`).
#'
#' @return For `"beta"`, a numeric matrix with probes in rows (row names are probe IDs) and
#'   samples in columns (GSM accessions); for `"meta"`, a `data.frame` with `Sample_Name`
#'   (GSM accession), `Sample_Group` (GEO source name), `title`, `health_state` and `gender`.
#'   With `path = TRUE`, a file path.
#'
#' @references Court F, et al. Genome-wide parent-of-origin DNA methylation analysis reveals the
#'   intricacies of human imprinting and suggests a germline methylation-independent mechanism
#'   of establishment. Genome Res. 2014;24:554-569.
#'
#' @examples
#' beta <- imprintome_example("beta")
#' meta <- imprintome_example("meta")
#' dim(beta)
#' table(meta$Sample_Group)
#' imprintome_example("beta", path = TRUE)
#' @export
imprintome_example <- function(which = c("beta", "meta"), path = FALSE) {
  which <- match.arg(which)
  f <- system.file("extdata", switch(which, beta = "GSE52576_selected_beta.tsv", meta = "GSE52576_meta.tsv"),
                   package = "imprintomeR", mustWork = TRUE)
  if (isTRUE(path)) return(f)
  x <- utils::read.delim(f, check.names = FALSE, stringsAsFactors = FALSE)
  if (which == "meta") return(x)
  m <- as.matrix(x[, -1, drop = FALSE])
  rownames(m) <- x$TargetID
  m
}
