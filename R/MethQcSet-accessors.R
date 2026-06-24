#' Accessors for MethQcSet
#'
#' Bioconductor-style accessors for reading and updating `MethQcSet` slots.
#'
#' @param x A `MethQcSet` object.
#' @param value Replacement value for a slot.
#'
#' @return Getter methods return the requested slot value.
#' Replacement methods return an updated `MethQcSet` object.
#'
#' @name MethQcSet-accessors
NULL

# ============================================================================
# meta() accessor
# ============================================================================

#' @export
methods::setGeneric("meta", function(x) standardGeneric("meta"))

#' @rdname MethQcSet-accessors
#' @export
methods::setMethod("meta", "MethQcSet", function(x) x@meta)

#' @export
methods::setGeneric("meta<-", function(x, value) standardGeneric("meta<-"))

#' @rdname MethQcSet-accessors
#' @export
methods::setReplaceMethod("meta", "MethQcSet", function(x, value) {
  value <- .normalize_methqc_sample_name(value)
  x@meta <- value
  methods::validObject(x)
  x
})

# ============================================================================
# platform() accessor
# ============================================================================

#' @export
methods::setGeneric("platform", function(x) standardGeneric("platform"))

#' @rdname MethQcSet-accessors
#' @export
methods::setMethod("platform", "MethQcSet", function(x) x@platform)

#' @export
methods::setGeneric("platform<-", function(x, value) standardGeneric("platform<-"))

#' @rdname MethQcSet-accessors
#' @export
methods::setReplaceMethod("platform", "MethQcSet", function(x, value) {
  x@platform <- value
  methods::validObject(x)
  x
})

# ============================================================================
# beta() accessor
# ============================================================================

#' @export
methods::setGeneric("beta", function(x) standardGeneric("beta"))

#' @rdname MethQcSet-accessors
#' @export
methods::setMethod("beta", "MethQcSet", function(x) x@beta)

#' @export
methods::setGeneric("beta<-", function(x, value) standardGeneric("beta<-"))

#' @rdname MethQcSet-accessors
#' @export
methods::setReplaceMethod("beta", "MethQcSet", function(x, value) {
  x@beta <- value
  methods::validObject(x)
  x
})

# ============================================================================
# detection_pval() accessor
# ============================================================================

#' @export
methods::setGeneric("detection_pval", function(x) standardGeneric("detection_pval"))

#' @rdname MethQcSet-accessors
#' @export
methods::setMethod("detection_pval", "MethQcSet", function(x) x@detection_pval)

#' @export
methods::setGeneric("detection_pval<-", function(x, value) standardGeneric("detection_pval<-"))

#' @rdname MethQcSet-accessors
#' @export
methods::setReplaceMethod("detection_pval", "MethQcSet", function(x, value) {
  x@detection_pval <- value
  methods::validObject(x)
  x
})

# ============================================================================
# qc_tables() accessor
# ============================================================================

#' @export
methods::setGeneric("qc_tables", function(x) standardGeneric("qc_tables"))

#' @rdname MethQcSet-accessors
#' @export
methods::setMethod("qc_tables", "MethQcSet", function(x) x@qc_tables)

#' @export
methods::setGeneric("qc_tables<-", function(x, value) standardGeneric("qc_tables<-"))

#' @rdname MethQcSet-accessors
#' @export
methods::setReplaceMethod("qc_tables", "MethQcSet", function(x, value) {
  x@qc_tables <- value
  methods::validObject(x)
  x
})

# ============================================================================
# aggregation_status() accessor
# ============================================================================

#' @export
methods::setGeneric("aggregation_status", function(x) standardGeneric("aggregation_status"))

#' @rdname MethQcSet-accessors
#' @export
methods::setMethod("aggregation_status", "MethQcSet", function(x) x@aggregation_status)

#' @export
methods::setGeneric("aggregation_status<-", function(x, value) standardGeneric("aggregation_status<-"))

#' @rdname MethQcSet-accessors
#' @export
methods::setReplaceMethod("aggregation_status", "MethQcSet", function(x, value) {
  x@aggregation_status <- value
  methods::validObject(x)
  x
})

# ============================================================================
# qc_params() accessor
# ============================================================================

#' @export
methods::setGeneric("qc_params", function(x) standardGeneric("qc_params"))

#' @rdname MethQcSet-accessors
#' @export
methods::setMethod("qc_params", "MethQcSet", function(x) x@qc_params)

#' @export
methods::setGeneric("qc_params<-", function(x, value) standardGeneric("qc_params<-"))

#' @rdname MethQcSet-accessors
#' @export
methods::setReplaceMethod("qc_params", "MethQcSet", function(x, value) {
  x@qc_params <- value
  methods::validObject(x)
  x
})

# ============================================================================
# statistics() accessor
# ============================================================================

#' @export
methods::setGeneric("statistics", function(x) standardGeneric("statistics"))

#' @rdname MethQcSet-accessors
#' @export
methods::setMethod("statistics", "MethQcSet", function(x) x@statistics)

#' @export
methods::setGeneric("statistics<-", function(x, value) standardGeneric("statistics<-"))

#' @rdname MethQcSet-accessors
#' @export
methods::setReplaceMethod("statistics", "MethQcSet", function(x, value) {
  x@statistics <- value
  methods::validObject(x)
  x
})
