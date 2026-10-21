# Add INFINIUM_DESIGN_TYPE (I/II) to every probe-level panel in both genome builds,
# taken from the harmonized annotation by probe NAME. Region panels (whose NAME holds
# region names, not probe IDs) are left untouched.
anno <- readRDS("inst/extdata/anno.uniq_harmonized.liftover.rds")
stopifnot(!anyDuplicated(anno$NAME), all(anno$INFINIUM_DESIGN_TYPE %in% c("I", "II")))

for (build in c("hg19", "hg38")) {
  path <- sprintf("inst/extdata/probesets_%s.rds", build)
  panels <- readRDS(path)
  for (name in names(panels)) {
    panel <- panels[[name]]
    if (!"NAME" %in% colnames(panel) || !any(panel$NAME %in% anno$NAME)) next
    type <- anno$INFINIUM_DESIGN_TYPE[match(panel$NAME, anno$NAME)]
    if (anyNA(type)) stop(build, " ", name, ": probes missing from annotation")
    panel$INFINIUM_DESIGN_TYPE <- type
    panels[[name]] <- panel
    cat(build, name, "I:", sum(type == "I"), "II:", sum(type == "II"), "\n")
  }

  # Write to a temporary file, then copy into place with retries (files in
  # inst/extdata are occasionally locked briefly by other processes on Windows).
  tmp <- tempfile(fileext = ".rds")
  saveRDS(panels, tmp, version = 3)
  for (k in 1:10) {
    if (isTRUE(suppressWarnings(file.copy(tmp, path, overwrite = TRUE)))) break
    if (k == 10) stop("Could not write ", path)
    Sys.sleep(1)
  }
}
