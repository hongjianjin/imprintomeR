# Regenerate tutorials/sessionInfo.md: the R session used to build and test imprintomeR,
# with the installed versions of every package declared in DESCRIPTION.
#
# Run from the repository root after installing the version being released:
#   R CMD INSTALL .
#   Rscript data-raw/session_info.R

stopifnot(file.exists("DESCRIPTION"), dir.exists("tutorials"))
desc <- read.dcf("DESCRIPTION", fields = c("Version", "Imports", "Suggests", "Depends"))
pkgs <- function(field) {
  x <- desc[1, field]
  if (is.na(x)) return(character())
  x <- trimws(strsplit(gsub("\\s+", " ", x), ",")[[1]])
  x <- sub("\\s*\\(.*$", "", x)
  setdiff(x[nzchar(x)], "R")
}
base_pkgs <- rownames(installed.packages(priority = "base"))
version_of <- function(p) {
  if (p %in% base_pkgs) return("base R")
  v <- tryCatch(as.character(utils::packageVersion(p)), error = function(e) NA_character_)
  if (is.na(v)) "not installed (optional)" else v
}
table_md <- function(field) {
  p <- setdiff(pkgs(field), base_pkgs)
  if (!length(p)) return(character())
  c(sprintf("| %s | Version |", field), "|---|---|", sprintf("| %s | %s |", p, vapply(p, version_of, "")))
}

suppressPackageStartupMessages(library(imprintomeR))
stopifnot(identical(as.character(packageVersion("imprintomeR")), unname(desc[1, "Version"])))
si <- sessionInfo()
si$BLAS <- basename(si$BLAS)       # no local library paths
si$LAPACK <- basename(si$LAPACK)
si_txt <- utils::capture.output(print(si))
si_txt <- si_txt[!grepl("^(BLAS|LAPACK):", si_txt)]
base_used <- intersect(c(pkgs("Imports"), pkgs("Depends")), base_pkgs)

out <- c(
  "# Session information",
  "",
  sprintf("The R session used to build and test imprintomeR %s (%s), recorded with:", desc[1, "Version"], Sys.Date()),
  "",
  "```r",
  "library(imprintomeR)",
  "sessionInfo()",
  "```",
  "",
  "```",
  si_txt,
  "```",
  "",
  "## Declared dependencies",
  "",
  paste("`sessionInfo()` lists only the packages loaded when imprintomeR is attached. Packages used by",
        "individual functions, such as `minfi` for QC, load on first use. The versions installed in the",
        "same session were:"),
  "",
  table_md("Imports"),
  "",
  table_md("Suggests"),
  "",
  sprintf("Base packages (%s) are those of R %s.",
          paste0("`", sort(base_used), "`", collapse = ", "), paste(R.version$major, R.version$minor, sep = ".")),
  "",
  paste("The package is also checked on every change by GitHub Actions with the current R release on",
        "Linux, macOS and Windows (`R CMD check`, and a clean install that runs the README Quick start",
        "and `supplementary/Supplementary_Code.R`); the versions used there are in the workflow logs.")
)
writeLines(out, "tutorials/sessionInfo.md")
message("Wrote tutorials/sessionInfo.md for imprintomeR ", desc[1, "Version"])
