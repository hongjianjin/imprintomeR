#' Accessors for ImprintomeSet
#'
#' Bioconductor-style accessors for reading and updating `ImprintomeSet` slots.
#'
#' @param x An `ImprintomeSet` object.
#' @param value Replacement value for a slot.
#'
#' @return Getter methods return the requested slot value.
#' Replacement methods return an updated `ImprintomeSet` object.
#'
#' @name ImprintomeSet-accessors
NULL

#' @rdname ImprintomeSet-accessors
#' @export
methods::setMethod("beta", "ImprintomeSet", function(x) x@beta)

#' @rdname ImprintomeSet-accessors
#' @export
methods::setReplaceMethod("beta", "ImprintomeSet", function(x, value) {
  x@beta <- value
  methods::validObject(x)
  x
})

#' @rdname ImprintomeSet-accessors
#' @export
methods::setMethod("meta", "ImprintomeSet", function(x) x@meta)

#' @rdname ImprintomeSet-accessors
#' @export
methods::setReplaceMethod("meta", "ImprintomeSet", function(x, value) {
  x@meta <- value
  methods::validObject(x)
  x
})

#' @export
methods::setGeneric("probeset", function(x) standardGeneric("probeset"))

#' @rdname ImprintomeSet-accessors
#' @export
methods::setMethod("probeset", "ImprintomeSet", function(x) x@probeset)

#' @export
methods::setGeneric("probeset<-", function(x, value) standardGeneric("probeset<-"))

#' @rdname ImprintomeSet-accessors
#' @export
methods::setReplaceMethod("probeset", "ImprintomeSet", function(x, value) {
  x@probeset <- value
  methods::validObject(x)
  x
})

#' @export
methods::setGeneric("genome", function(x) standardGeneric("genome"))

#' @rdname ImprintomeSet-accessors
#' @export
methods::setMethod("genome", "ImprintomeSet", function(x) {
  # Return the genome slot directly to avoid conflicts with BiocGenerics
  x@genome
})

#' @export
methods::setGeneric("genome<-", function(x, value) standardGeneric("genome<-"))

#' @rdname ImprintomeSet-accessors
#' @export
methods::setReplaceMethod("genome", "ImprintomeSet", function(x, value) {
  x@genome <- value
  methods::validObject(x)
  x
})

#' @export
methods::setGeneric("assay", function(x) standardGeneric("assay"))

#' @rdname ImprintomeSet-accessors
#' @export
methods::setMethod("assay", "ImprintomeSet", function(x) x@assay)

#' @export
methods::setGeneric("assay<-", function(x, value) standardGeneric("assay<-"))

#' @rdname ImprintomeSet-accessors
#' @export
methods::setReplaceMethod("assay", "ImprintomeSet", function(x, value) {
  x@assay <- value
  methods::validObject(x)
  x
})

#' @export
methods::setGeneric("results", function(x) standardGeneric("results"))

#' @rdname ImprintomeSet-accessors
#' @export
methods::setMethod("results", "ImprintomeSet", function(x) x@results)

#' @export
methods::setGeneric("results<-", function(x, value) standardGeneric("results<-"))

#' @rdname ImprintomeSet-accessors
#' @export
methods::setReplaceMethod("results", "ImprintomeSet", function(x, value) {
  x@results <- value
  methods::validObject(x)
  x
})

#' @export
methods::setGeneric("plots", function(x) standardGeneric("plots"))

#' @rdname ImprintomeSet-accessors
#' @export
methods::setMethod("plots", "ImprintomeSet", function(x) x@plots)

#' @export
methods::setGeneric("plots<-", function(x, value) standardGeneric("plots<-"))

#' @rdname ImprintomeSet-accessors
#' @export
methods::setReplaceMethod("plots", "ImprintomeSet", function(x, value) {
  x@plots <- value
  methods::validObject(x)
  x
})
