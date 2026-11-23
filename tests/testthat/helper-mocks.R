# Replace internal functions in the package namespace while `code` runs and always put
# the originals back. (testthat's mocked-bindings helpers did not restore namespace
# bindings under pkgload::load_all() with testthat 3.2.1.1, and a leaked mock of
# .detect_platform_one() made later tests see "EPIC" for 450K IDATs on Windows CI.)
.with_namespace_mocks <- function(mocks, code) {
  ns <- getNamespace("imprintomeR")
  originals <- mget(names(mocks), envir = ns)
  set <- function(values) for (n in names(values)) {
    locked <- bindingIsLocked(n, ns)
    if (locked) unlockBinding(n, ns)
    assign(n, values[[n]], envir = ns)
    if (locked) lockBinding(n, ns)
  }
  set(mocks)
  on.exit(set(originals), add = TRUE)
  force(code)
}
