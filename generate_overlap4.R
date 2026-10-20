panels_to_compare <- c("Jima", "Joshi", "Court", "Rosenski")

generate_name_files <- function(genome) {
  panels <- readRDS(file.path("inst", "extdata", paste0("probesets_", genome, ".rds")))
  stopifnot(all(panels_to_compare %in% names(panels)))

  for (panel_name in panels_to_compare) {
    panel <- panels[[panel_name]]
    stopifnot("NAME" %in% names(panel))
    probe_names <- as.character(panel$NAME)
    stopifnot(!anyNA(probe_names), !anyDuplicated(probe_names))
    writeLines(probe_names, paste0(panel_name, "_", genome, ".txt"))
    cat(panel_name, genome, "probes:", length(probe_names), "\n")
  }
}

generate_name_files("hg19")
generate_name_files("hg38")