panels <- readRDS(file.path("inst", "extdata", "probesets_hg19.rds"))
selected_names <- panels[["selected"]]$NAME
panel_names <- lapply(c("Court", "Jima", "Joshi"), function(name) panels[[name]]$NAME)
names(panel_names) <- c("Court", "Jima", "Joshi")

for (panel_name in names(panel_names)) {
  overlap <- intersect(selected_names, panel_names[[panel_name]])
  cat(panel_name, "overlap:", length(overlap), "\n")
}

membership <- vapply(selected_names, function(probe_name) {
  sum(vapply(panel_names, function(names) probe_name %in% names, logical(1)))
}, integer(1))
cat("Absent from Court/Jima/Joshi:", sum(membership == 0L), "\n")
cat("Present in all three:", sum(membership == 3L), "\n")
print(table(membership))