#' Merge and Intersection Methods for MethQcSet
#'
#' Methods for combining multiple MethQcSet objects with synchronized metadata and beta alignment.
#'
#' @name MethQcSet-merge
NULL

# ============================================================================
# merge() - Synchronized merge of multiple MethQcSet objects
# ============================================================================

if (!methods::isGeneric("merge")) {
  methods::setGeneric("merge", function(x, y, ...) standardGeneric("merge"))
}

#' Merge Multiple MethQcSet Objects
#'
#' Combine multiple `MethQcSet` objects from the same platform with synchronized
#' metadata and beta matrix alignment.
#'
#' @param x A `MethQcSet` object.
#' @param y A `MethQcSet` object or list of `MethQcSet` objects.
#' @param how Character, join type for beta matrices: "inner" (default), "outer", "left", or "right".
#' @param ... Additional arguments (reserved for future use).
#'
#' @return A single `MethQcSet` object with:
#'   \itemize{
#'     \item Metadata deduplicated by `SAMPLE_NAME` and merged
#'     \item Beta matrices joined by probe `TargetID` (rownames)
#'     \item Metadata reordered to match final beta sample order
#'     \item Detection p-values aligned if present in all inputs
#'     \item QC tables merged where applicable
#'   }
#'
#' @details
#' **Merge Contract (Synchronized Operation):**
#' 1. Validates all inputs are same platform
#' 2. Merges metadata: stack by rows, deduplicate by SAMPLE_NAME (keeping first occurrence)
#' 3. Merges beta matrices: join by TargetID (rownames), concat by sample columns
#' 4. Merges detection p-values: same method as beta (if present)
#' 5. Reorders metadata to match final beta column order
#' 6. Concatenates QC tables, filtering to samples in final object
#'
#' This ensures metadata, beta, and detection p-values remain synchronized
#' (no hidden sample drift).
#'
#' @export
methods::setMethod("merge", "MethQcSet", function(x, y, how = "inner", ...) {
  # Use dplyr functions without globally loading the package
  # This avoids conflicts with other generics like summarise

  # Coerce y to list if single object
  if (is(y, "MethQcSet")) {
    y <- list(y)
  } else if (!is.list(y)) {
    stop("y must be a MethQcSet object or list of MethQcSet objects")
  }

  # Collect all objects: x, then y
  all_objects <- c(list(x), y)

  # Validate all same platform
  platforms <- sapply(all_objects, function(obj) obj@platform)
  if (length(unique(platforms)) > 1) {
    stop("Cannot merge MethQcSet objects from different platforms. Found: ", paste(unique(platforms), collapse = ", "))
  }

  # Warn if any non-aggregated EPICv2
  for (i in seq_along(all_objects)) {
    if (platforms[i] == "EPICv2" && all_objects[[i]]@aggregation_status != "epicv2_aggregated") {
      warning("Object ", i, " is EPICv2 but not aggregated. Consider running aggregate_probes() first.")
    }
  }

  # ========================================================================
  # Step 1: Merge metadata (deduplicate by Sample_Name)
  # ========================================================================
  metas <- lapply(all_objects, function(obj) obj@meta)
  meta_merged <- do.call(rbind, metas)
  rownames(meta_merged) <- NULL

  # Deduplicate: keep first occurrence of each Sample_Name
  meta_merged <- meta_merged[!duplicated(meta_merged$Sample_Name), ]

  # ========================================================================
  # Step 2: Merge beta matrices (join by TargetID, concat by samples)
  # ========================================================================
  betas <- lapply(all_objects, function(obj) as.data.frame(obj@beta))

  # Add TargetID column for joins
  for (i in seq_along(betas)) {
    betas[[i]]$TargetID <- rownames(all_objects[[i]]@beta)
  }

  # Perform join by TargetID
  how_lower <- tolower(how)
  if (how_lower == "inner") {
    beta_merged <- betas[[1]]
    for (i in 2:length(betas)) {
      beta_merged <- dplyr::inner_join(beta_merged, betas[[i]], by = "TargetID")
    }
  } else if (how_lower == "outer") {
    beta_merged <- betas[[1]]
    for (i in 2:length(betas)) {
      beta_merged <- dplyr::full_join(beta_merged, betas[[i]], by = "TargetID")
    }
  } else if (how_lower == "left") {
    beta_merged <- betas[[1]]
    for (i in 2:length(betas)) {
      beta_merged <- dplyr::left_join(beta_merged, betas[[i]], by = "TargetID")
    }
  } else if (how_lower == "right") {
    beta_merged <- betas[[1]]
    for (i in 2:length(betas)) {
      beta_merged <- dplyr::right_join(beta_merged, betas[[i]], by = "TargetID")
    }
  } else {
    stop("how must be one of: 'inner', 'outer', 'left', 'right'")
  }

  # Convert back to matrix
  rownames(beta_merged) <- beta_merged$TargetID
  beta_merged$TargetID <- NULL
  beta_merged <- as.matrix(beta_merged)

  # ========================================================================
  # Step 3: Merge detection p-values (same logic as beta)
  # ========================================================================
  dpvals <- lapply(all_objects, function(obj) obj@detection_pval)

  # Only merge if all have detection_pval
  if (!any(sapply(dpvals, is.null))) {
    dpvals_df <- lapply(seq_along(dpvals), function(i) {
      as.data.frame(dpvals[[i]])
    })

    for (i in seq_along(dpvals_df)) {
      dpvals_df[[i]]$TargetID <- rownames(all_objects[[i]]@detection_pval)
    }

    dpval_merged <- dpvals_df[[1]]
    for (i in 2:length(dpvals_df)) {
      if (how_lower == "inner") {
        dpval_merged <- inner_join(dpval_merged, dpvals_df[[i]], by = "TargetID")
      } else if (how_lower == "outer") {
        dpval_merged <- full_join(dpval_merged, dpvals_df[[i]], by = "TargetID")
      } else if (how_lower == "left") {
        dpval_merged <- left_join(dpval_merged, dpvals_df[[i]], by = "TargetID")
      } else if (how_lower == "right") {
        dpval_merged <- right_join(dpval_merged, dpvals_df[[i]], by = "TargetID")
      }
    }

    rownames(dpval_merged) <- dpval_merged$TargetID
    dpval_merged$TargetID <- NULL
    dpval_merged <- as.matrix(dpval_merged)
  } else {
    dpval_merged <- NULL
  }

  # ========================================================================
  # Step 4: Reorder metadata to match final beta column order
  # ========================================================================
  final_samples <- colnames(beta_merged)
  meta_idx <- match(final_samples, meta_merged$Sample_Name)
  meta_merged <- meta_merged[meta_idx, ]
  rownames(meta_merged) <- NULL

  # ========================================================================
  # Step 5: Merge QC tables (keep only samples in final object)
  # ========================================================================
  qc_tables_merged <- list()

  # Collect all table names
  all_qc_names <- unique(unlist(lapply(all_objects, function(obj) names(obj@qc_tables))))

  for (qc_name in all_qc_names) {
    qc_list <- lapply(all_objects, function(obj) {
      if (qc_name %in% names(obj@qc_tables)) {
        obj@qc_tables[[qc_name]]
      } else {
        NULL
      }
    })

    # Remove NULLs and merge
    qc_list <- qc_list[!sapply(qc_list, is.null)]
    if (length(qc_list) > 0) {
      qc_table <- do.call(rbind, qc_list)
      rownames(qc_table) <- NULL

      # Filter to final samples if Sample_Name column exists
      if ("Sample_Name" %in% colnames(qc_table)) {
        qc_table <- qc_table[qc_table$Sample_Name %in% final_samples, ]
      }

      qc_tables_merged[[qc_name]] <- qc_table
    }
  }

  # ========================================================================
  # Create merged object
  # ========================================================================
  merged_obj <- MethQcSet(
    meta = meta_merged,
    platform = x@platform,
    beta = beta_merged,
    detection_pval = dpval_merged,
    qc_tables = qc_tables_merged,
    aggregation_status = x@aggregation_status,  # Inherit from first object
    qc_params = x@qc_params  # Inherit from first object
  )

  merged_obj
})

# ============================================================================
# find_intersection() - Find common samples or probes
# ============================================================================

#' Find Common Samples or Probes Between MethQcSet Objects
#'
#' Identify common samples or probes between two `MethQcSet` objects.
#'
#' @param x A `MethQcSet` object.
#' @param y A `MethQcSet` object.
#' @param by Character, "samples" (default) to find common samples, or "probes" for common probes.
#'
#' @return Character vector of common identifiers (sample names or probe IDs).
#'
#' @export
find_intersection <- function(x, y, by = c("samples", "probes")) {
  if (!is(x, "MethQcSet") || !is(y, "MethQcSet")) {
    stop("Both x and y must be MethQcSet objects")
  }

  by <- match.arg(by)

  if (by == "samples") {
    return(base::intersect(colnames(x@beta), colnames(y@beta)))
  } else if (by == "probes") {
    return(base::intersect(rownames(x@beta), rownames(y@beta)))
  }
}
