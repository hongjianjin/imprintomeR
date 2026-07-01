#' Platform Detection and QC Factory for MethQcSet
#'
#' Functions for detecting array platform from IDAT files and creating
#' QC-processed `MethQcSet` objects from raw IDAT data.
#'
#' @name MethQcSet-io
NULL

# ============================================================================
# .detect_platform_one() - Internal: detect platform for a single Basename
# ============================================================================

#' @keywords internal
.detect_platform_one <- function(basename, sample_name, max_retries = 5) {
  retry_count <- 0

  while (retry_count < max_retries) {
    result <- tryCatch({
      rgSet <- minfi::read.metharray(basenames = basename, force = TRUE)

      array_size <- nrow(rgSet)
      if (array_size < 400000) {
        stop(paste0("Incomplete IDAT read: only ", array_size, " probes detected (expected >400k)"))
      }

      platform_ann <- minfi::annotation(rgSet)
      platform_raw <- gsub("IlluminaHumanMethylation", "", platform_ann["array"])
      platform_raw <- trimws(as.character(platform_raw))

      # Validate and correct by array size (source of truth: meth_check_platform.R)
      expected <- if (array_size > 1100000) "EPICv2" else
                  if (array_size > 1000000) "EPIC"   else
                  if (array_size > 400000)  "450K"   else
                  if (array_size > 20000)   "27K"    else NA_character_

      if (!is.na(expected) && !grepl(expected, platform_raw, ignore.case = TRUE)) {
        warning(sample_name, ": platform mismatch - annotation '", platform_raw,
                "' vs array size suggests '", expected, "'. Using array-size value.")
        platform_raw <- expected
      }

      manifest <- NA_character_
      if (length(platform_ann) >= 2) {
        m <- trimws(as.character(platform_ann[2]))
        if (grepl("ilm|hg", m, ignore.case = TRUE)) manifest <- m
      }
      if (is.na(manifest) && "manifest" %in% names(platform_ann)) {
        manifest <- trimws(as.character(platform_ann["manifest"]))
      }

      data.frame(
        Sample_Name  = sample_name,
        Platform     = platform_raw,
        Array_Size   = array_size,
        Manifest     = manifest,
        Status       = "Success",
        stringsAsFactors = FALSE
      )
    }, error = function(e) NULL)

    if (!is.null(result)) return(result)

    retry_count <- retry_count + 1
    if (retry_count < max_retries) Sys.sleep(2)
  }

  message(sample_name, "\tFailed to read IDAT after ", max_retries, " attempts")
  data.frame(
    Sample_Name  = sample_name,
    Platform     = NA_character_,
    Array_Size   = NA_integer_,
    Manifest     = NA_character_,
    Status       = "Failed",
    stringsAsFactors = FALSE
  )
}

# ============================================================================
# check_platform() - Detect platform and append to meta
# ============================================================================

#' Detect Array Platform from IDAT Files and Annotate Metadata
#'
#' Reads IDAT files for each sample in `meta` and detects the Illumina array
#' platform by reading probe count from the raw channel data. Appends
#' `Platform`, `Array_Size`, `Manifest`, and `Status` columns to `meta`.
#'
#' Use this function before `runMethQC()` when the platform is unknown or when
#' you need to check whether a cohort spans multiple array types.
#'
#' @param meta A `data.frame` with required column `Basename` (path prefix to
#'   IDAT files, e.g. `/path/to/idats/Sentrix_ID`). A `Sample_Name` column is
#'   used for messaging; if absent, row numbers are used.
#' @param max_retries Integer. Number of read attempts per sample before
#'   marking as `"Failed"`. Default: 5.
#'
#' @return `meta` with four columns appended:
#'   \describe{
#'     \item{Platform}{Detected platform: `"EPIC"`, `"EPICv2"`, `"450K"`, `"27K"`, or `NA`}
#'     \item{Array_Size}{Number of probes in the raw IDAT}
#'     \item{Manifest}{Manifest string from array annotation (may be `NA`)}
#'     \item{Status}{`"Success"` or `"Failed"`}
#'   }
#'
#' @details
#' Platform is inferred from array size using the same logic as
#' `meth_check_platform.R::CheckPlatform()`:
#' - `> 1,100,000` probes → `"EPICv2"`
#' - `> 1,000,000` probes → `"EPIC"`
#' - `> 400,000` probes → `"450K"`
#' - `> 20,000` probes → `"27K"`
#'
#' If the annotation string disagrees with the array size, the array-size
#' inference is used and a warning is issued.
#'
#' @examples
#' \dontrun{
#' meta <- read.table("meta.tsv", header = TRUE, sep = "\t")
#' meta_updated <- check_platform(meta)
#' table(meta_updated$Platform)
#'
#' # Split by platform before running QC
#' meta_epic <- meta_updated[meta_updated$Platform == "EPIC", ]
#' qcset <- runMethQC(meta_epic)
#' }
#'
#' @export
check_platform <- function(meta, max_retries = 5) {
  if (!is.data.frame(meta)) stop("meta must be a data.frame.")

  # Normalize legacy column names to package conventions.
  if ("BASENAME" %in% colnames(meta) && !"Basename" %in% colnames(meta))
    colnames(meta)[colnames(meta) == "BASENAME"] <- "Basename"
  meta <- .normalize_methqc_sample_name(meta)

  if (!"Basename" %in% colnames(meta))
    stop("meta must contain a 'Basename' column with IDAT file path prefixes.")

  sample_names <- if ("Sample_Name" %in% colnames(meta)) {
    meta$Sample_Name
  } else {
    as.character(seq_len(nrow(meta)))
  }

  message("Detecting platform for ", nrow(meta), " samples...")

  results <- mapply(
    .detect_platform_one,
    basename    = meta$Basename,
    sample_name = sample_names,
    MoreArgs    = list(max_retries = max_retries),
    SIMPLIFY    = FALSE
  )
  results_df <- do.call(rbind, results)

  meta$Platform   <- results_df$Platform
  meta$Array_Size <- results_df$Array_Size
  meta$Manifest   <- results_df$Manifest
  meta$Status     <- results_df$Status

  n_failed <- sum(results_df$Status == "Failed", na.rm = TRUE)
  if (n_failed > 0) {
    warning(n_failed, " sample(s) failed platform detection. Check meta$Status for details.")
  }

  platform_tbl <- table(meta$Platform[meta$Status == "Success"])
  message("Platform summary:\n", paste(
    sprintf("  %s: %d sample(s)", names(platform_tbl), as.integer(platform_tbl)),
    collapse = "\n"
  ))

  meta
}

# ============================================================================
# runMethQC() - Public factory: load IDAT, detect/resolve platform, run QC
# ============================================================================

#' Load IDAT Files, Run Quality Control, and Create a MethQcSet
#'
#' Factory function that reads IDAT files for all samples in `meta`, extracts
#' beta values and detection p-values via minfi, constructs a `MethQcSet`
#' object, and computes QC metrics. Returns a fully populated `MethQcSet`.
#'
#' @param meta A `data.frame` with columns:
#'   \describe{
#'     \item{Sample_Name}{Sample identifiers (required)}
#'     \item{Basename}{IDAT file path prefix, e.g. `/path/to/idats/Sentrix_ID`
#'       (required). Files `Sentrix_ID_Red.idat` and `Sentrix_ID_Grn.idat`
#'       must exist at that path.}
#'     \item{Platform}{(optional) Platform string. Used by platform resolution
#'       when `platform = NA`.}
#'   }
#' @param platform Platform string (`"EPIC"`, `"EPICv2"`, `"450K"`) or `NA`
#'   (default). Resolution rules:
#'   \describe{
#'     \item{`NA` + `Platform` column in meta with one unique value}{Auto-use
#'       that value. Run `check_platform(meta)` first to populate this column.}
#'     \item{`NA` + `Platform` column in meta with multiple values}{Error with
#'       instructions to subset meta by platform and re-call.}
#'     \item{`NA` + no `Platform` column in meta}{Error with instructions to
#'       run `check_platform(meta)` first.}
#'     \item{Explicit string (e.g. `"EPIC"`)}{Use provided value; any existing
#'       `Platform` column in meta is ignored.}
#'   }
#' @param pcutoff Numeric. Maximum mean detection p-value to pass QC (default: 0.05).
#' @param save_qc_report Logical. If `TRUE`, write `minfi::qcReport()`
#'   density-report PDFs for all, PASS, and FAIL samples. Default: `TRUE`.
#' @param outdir Directory for QC density-report PDFs. Default: `"."`.
#' @param prefix Filename prefix for QC density-report PDFs. If `NULL`,
#'   the resolved platform name is used.
#' @param ... Additional arguments passed to `minfi::read.metharray.exp()`.
#'
#' @return A `MethQcSet` object with:
#'   \itemize{
#'     \item `beta` slot populated from `minfi::getBeta()`
#'     \item `detection_pval` slot populated from `minfi::detectionP()`
#'     \item `qc_tables` slot populated with QC metrics
#'     \item `platform` slot set to the resolved platform string
#'   }
#'
#' @examples
#' \dontrun{
#' # Case 1: Known single-platform cohort
#' meta <- read.table("meta.tsv", header = TRUE, sep = "\t")
#' qcset <- runMethQC(meta, platform = "EPIC")
#'
#' # Default minfi density-report PDFs:
#' qcset <- runMethQC(meta, platform = "EPIC",
#'                    outdir = "qc_output",
#'                    prefix = "epic")
#'
#' # Case 2: Platform unknown - detect first, then run QC
#' meta <- check_platform(meta)
#' table(meta$Platform)  # inspect
#'
#' meta_epic <- meta[meta$Platform == "EPIC", ]
#' qcset_epic <- runMethQC(meta_epic)  # platform auto-resolved from meta$Platform
#'
#' meta_450k <- meta[meta$Platform == "450K", ]
#' qcset_450k <- runMethQC(meta_450k)
#' }
#'
#' @seealso [check_platform()] to detect and annotate platforms before calling
#'   this function; [MethQcSet-class] for the returned object.
#'
#' @export
runMethQC <- function(meta, platform = NA, pcutoff = 0.05,
                      save_qc_report = TRUE, outdir = ".", prefix = NULL, ...) {
  if (!is.data.frame(meta)) stop("meta must be a data.frame.")

  # ------------------------------------------------------------------
  # Step 0: Normalize legacy column names to package conventions.
  # ------------------------------------------------------------------
  if ("BASENAME" %in% colnames(meta) && !"Basename" %in% colnames(meta))
    colnames(meta)[colnames(meta) == "BASENAME"] <- "Basename"
  meta <- .normalize_methqc_sample_name(meta)

  # ------------------------------------------------------------------
  # Step 1: Resolve platform
  # ------------------------------------------------------------------
  resolved_platform <- .resolve_platform(meta, platform)

  # ------------------------------------------------------------------
  # Step 2: Validate Basename
  # ------------------------------------------------------------------
  if (!"Basename" %in% colnames(meta)) {
    stop("meta must contain a 'Basename' column with IDAT file path prefixes.")
  }

  missing_files <- meta$Basename[!file.exists(paste0(meta$Basename, "_Red.idat")) &
                                   !file.exists(paste0(meta$Basename, ".idat"))]
  if (length(missing_files) > 0) {
    stop("IDAT files not found for ", length(missing_files), " sample(s):\n",
         paste(" ", missing_files, collapse = "\n"))
  }

  # ------------------------------------------------------------------
  # Step 3: Load IDAT files via minfi
  # ------------------------------------------------------------------
  message("Loading IDAT files for ", nrow(meta), " samples (platform: ", resolved_platform, ")...")

  rgSet <- minfi::read.metharray.exp(targets = meta, force = TRUE, ...)

  # ------------------------------------------------------------------
  # Step 4: Extract beta and detection p-values
  # ------------------------------------------------------------------
  message("Preprocessing and extracting beta values...")
  mSet    <- minfi::preprocessRaw(rgSet)
  beta    <- minfi::getBeta(mSet)
  det_pval <- minfi::detectionP(rgSet)

  # Align beta column names to sample identifier.
  # Prefer Sample_Name; accept legacy SAMPLE_NAME for older metadata.
  sample_id_col <- intersect(c("Sample_Name", "SAMPLE_NAME"), colnames(meta))[1]
  if (!is.na(sample_id_col)) {
    colnames(beta)     <- meta[[sample_id_col]]
    colnames(det_pval) <- meta[[sample_id_col]]
  }

  # ------------------------------------------------------------------
  # Step 5: Build MethQcSet and compute QC
  # ------------------------------------------------------------------
  qcset <- MethQcSet(
    meta            = meta,
    platform        = resolved_platform,
    beta            = beta,
    detection_pval  = det_pval
  )

  message("Computing QC metrics...")
  qcset <- computeQC(qcset, pcutoff = pcutoff)

  # ------------------------------------------------------------------
  # Step 6: Compute intensity and merge into QC_matrix
  # ------------------------------------------------------------------
  tryCatch({
    mMed  <- log2(matrixStats::colMedians(minfi::getMeth(mSet),   na.rm = TRUE))
    uMed  <- log2(matrixStats::colMedians(minfi::getUnmeth(mSet), na.rm = TRUE))
    aveMed <- round((mMed + uMed) / 2, 2)
    intensity_df <- data.frame(
      Sample_Name      = colnames(beta),
      mMed.Intensity   = round(mMed,  2),
      uMed.Intensity   = round(uMed,  2),
      aveMed.Intensity = aveMed,
      stringsAsFactors = FALSE
    )
    qm  <- qcset@qc_tables[["QC_matrix"]]
    idx <- match(qm$Sample_Name, intensity_df$Sample_Name)
    qm$mMed.Intensity   <- intensity_df$mMed.Intensity[idx]
    qm$uMed.Intensity   <- intensity_df$uMed.Intensity[idx]
    qm$aveMed.Intensity <- intensity_df$aveMed.Intensity[idx]
    # Intensity metrics are reported for review but do not determine Final.QC.
    qcset@qc_tables[["QC_matrix"]] <- qm
  }, error = function(e) {
    warning("Intensity computation skipped: ", conditionMessage(e))
  })

  # ------------------------------------------------------------------
  # Step 7: Predict sex (optional, requires mapToGenome)
  # ------------------------------------------------------------------
  tryCatch({
    gMset  <- minfi::mapToGenome(mSet)
    estSex <- minfi::getSex(gMset)
    qm     <- qcset@qc_tables[["QC_matrix"]]
    qm$predictedSex <- estSex$predictedSex[match(qm$Sample_Name, rownames(estSex))]
    qcset@qc_tables[["QC_matrix"]] <- qm
  }, error = function(e) {
    message("predictedSex not computed: ", conditionMessage(e))
  })

  # ------------------------------------------------------------------
  # Step 8: ewastools-based metrics (ctrl_metrics, contamination,
  #         predUniqDonor_ID) — optional, requires ewastools package
  # ------------------------------------------------------------------
  if (requireNamespace("ewastools", quietly = TRUE)) {
    tryCatch({
      message("Running ewastools-based QC (ctrl_metrics, contamination, predUniqDonor_ID)...")
      meth_et <- ewastools::read_idats(meta$Basename, quiet = TRUE)

      # Control probe metrics
      ctrls   <- ewastools::control_metrics(meth_et)
      ctrl_df <- as.data.frame(do.call(cbind, lapply(ctrls, as.numeric)))
      colnames(ctrl_df) <- names(ctrls)
      ctrl_df <- cbind(
        data.frame(Sample_Name = colnames(beta), stringsAsFactors = FALSE),
        round(ctrl_df, 2)
      )
      ctrl_df$CtrlMetrics.QC <- ifelse(ewastools::sample_failure(ctrls), "FAIL", "PASS")
      qcset@qc_tables[["ctrl_metrics"]] <- ctrl_df

      # Update Final.QC to also require ctrl_metrics PASS
      qm  <- qcset@qc_tables[["QC_matrix"]]
      idx <- match(qm$Sample_Name, ctrl_df$Sample_Name)
      ctrl_qc <- ctrl_df$CtrlMetrics.QC[idx]
      qm$Final.QC[!is.na(ctrl_qc) & ctrl_qc == "FAIL"] <- "FAIL"
      qcset@qc_tables[["QC_matrix"]] <- qm

      # Genotyping for contamination and donor deduplication
      beta_ew   <- ewastools::dont_normalize(meth_et)
      snp_rows  <- meth_et$manifest[meth_et$manifest$probe_type == "rs", ]
      snps      <- beta_ew[snp_rows$index, , drop = FALSE]
      genotypes <- ewastools::call_genotypes(snps, learn = FALSE)

      # Contamination: SNP agreement check
      donor_ids <- if ("Donor_ID" %in% colnames(meta)) meta$Donor_ID else meta$Sample_Name
      sample_ids <- if ("Sample_Name" %in% colnames(meta)) meta$Sample_Name else colnames(beta)
      cont_res <- ewastools::check_snp_agreement(genotypes, donor_ids, sample_ids)
      qcset@qc_tables[["contamination"]] <- as.data.frame(cont_res)

      # Predicted unique donor IDs
      pred_donor <- ewastools::enumerate_sample_donors(genotypes)
      qm <- qcset@qc_tables[["QC_matrix"]]
      qm$predictedDonorID <- pred_donor
      qcset@qc_tables[["QC_matrix"]] <- qm
      uniq_dnr <- do.call(rbind, lapply(unique(pred_donor), function(d) {
        idx  <- pred_donor == d
        pass <- qm$Final.QC[idx] == "PASS"
        data.frame(
          predictedDonorID = d,
          PASS_COUNT = sum(pass),
          FAIL_COUNT = sum(!pass),
          PASS_IDs   = paste(qm$Sample_Name[idx][pass],  collapse = ","),
          FAIL_IDs   = paste(qm$Sample_Name[idx][!pass], collapse = ","),
          TOTAL      = sum(idx),
          stringsAsFactors = FALSE
        )
      }))
      qcset@qc_tables[["predUniqDonor_ID"]] <- uniq_dnr

    }, error = function(e) {
      message("ewastools QC skipped: ", conditionMessage(e))
    })
  }

  # ------------------------------------------------------------------
  # Step 9: minfi density-report PDFs
  # ------------------------------------------------------------------
  if (isTRUE(save_qc_report)) {
    report_prefix <- prefix
    if (is.null(report_prefix) || !nzchar(as.character(report_prefix)[1])) {
      report_prefix <- tolower(as.character(resolved_platform))
    }
    report_prefix <- as.character(report_prefix)[1]
    report_df <- .write_methqc_density_reports(
      rgSet = rgSet,
      meta = meta,
      qcm = qcset@qc_tables[["QC_matrix"]],
      outdir = outdir,
      prefix = report_prefix
    )
    qcset@qc_tables[["qc_report_files"]] <- report_df
  }

  n_pass <- sum(qcset@qc_tables[["QC_matrix"]]$Final.QC == "PASS", na.rm = TRUE)
  n_fail <- sum(qcset@qc_tables[["QC_matrix"]]$Final.QC == "FAIL", na.rm = TRUE)
  message("QC complete: ", n_pass, " PASS, ", n_fail, " FAIL")

  qcset
}


# ============================================================================
# .write_methqc_density_reports() - Internal: optional minfi qcReport PDFs
# ============================================================================

#' @keywords internal
.write_methqc_density_reports <- function(rgSet, meta, qcm, outdir, prefix) {
  if (!requireNamespace("minfi", quietly = TRUE)) {
    warning("minfi is required to write QC density reports.")
    return(data.frame(
      report = character(0),
      file = character(0),
      status = character(0),
      message = character(0),
      stringsAsFactors = FALSE
    ))
  }

  if (!dir.exists(outdir)) {
    dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
  }

  n_samples <- ncol(rgSet)
  sample_names <- if ("Sample_Name" %in% colnames(meta)) {
    as.character(meta$Sample_Name)
  } else if ("SAMPLE_NAME" %in% colnames(meta)) {
    as.character(meta$SAMPLE_NAME)
  } else {
    colnames(rgSet)
  }
  if (length(sample_names) != n_samples) sample_names <- colnames(rgSet)

  sample_groups <- if ("Sample_Group" %in% colnames(meta)) {
    as.character(meta$Sample_Group)
  } else {
    rep("All", n_samples)
  }
  if (length(sample_groups) != n_samples) sample_groups <- rep("All", n_samples)

  write_one <- function(report, idx) {
    out_file <- file.path(outdir, paste0(prefix, "_QC_densityPlot_", report, ".pdf"))
    if (length(idx) == 0) {
      msg <- paste0("No ", report, " samples; skipped.")
      message(msg)
      return(data.frame(
        report = report,
        file = out_file,
        status = "skipped",
        message = msg,
        stringsAsFactors = FALSE
      ))
    }

    tryCatch({
      minfi::qcReport(
        rgSet[, idx],
        sampNames = sample_names[idx],
        sampGroups = sample_groups[idx],
        pdf = out_file
      )
      data.frame(
        report = report,
        file = out_file,
        status = "saved",
        message = "saved",
        stringsAsFactors = FALSE
      )
    }, error = function(e) {
      msg <- conditionMessage(e)
      warning("QC density report skipped for ", report, ": ", msg)
      data.frame(
        report = report,
        file = out_file,
        status = "failed",
        message = msg,
        stringsAsFactors = FALSE
      )
    })
  }

  idx_all <- seq_len(n_samples)
  if (is.data.frame(qcm) && all(c("Sample_Name", "Final.QC") %in% colnames(qcm))) {
    pass_names <- as.character(qcm$Sample_Name[qcm$Final.QC == "PASS"])
    fail_names <- as.character(qcm$Sample_Name[qcm$Final.QC == "FAIL"])
    idx_pass <- match(pass_names, sample_names)
    idx_fail <- match(fail_names, sample_names)
    idx_pass <- idx_pass[!is.na(idx_pass)]
    idx_fail <- idx_fail[!is.na(idx_fail)]
  } else {
    warning("QC_matrix with Sample_Name and Final.QC not found; writing all-sample QC density report only.")
    idx_pass <- integer(0)
    idx_fail <- integer(0)
  }

  do.call(rbind, list(
    write_one("all", idx_all),
    write_one("pass", idx_pass),
    write_one("fail", idx_fail)
  ))
}

# ============================================================================
# .resolve_platform() - Internal: resolve platform from parameter or meta col
# ============================================================================

#' @keywords internal
.resolve_platform <- function(meta, platform) {
  if (!is.na(platform)) {
    # Explicit value provided — use it directly
    return(as.character(platform))
  }

  # platform is NA — look for Platform column in meta
  if (!"Platform" %in% colnames(meta)) {
    stop(
      "platform is NA and no 'Platform' column found in meta.\n",
      "Run check_platform(meta) first to detect platforms, or pass platform= explicitly.\n",
      "Example: qcset <- runMethQC(meta, platform = \"EPIC\")"
    )
  }

  unique_platforms <- unique(meta$Platform[!is.na(meta$Platform)])

  if (length(unique_platforms) == 1) {
    message("Platform auto-resolved from meta$Platform: ", unique_platforms)
    return(unique_platforms)
  }

  if (length(unique_platforms) > 1) {
    platform_counts <- table(meta$Platform)
    platform_summary <- paste(
      sprintf("  %s: %d sample(s)", names(platform_counts), as.integer(platform_counts)),
      collapse = "\n"
    )
    stop(
      "Multiple platforms detected in meta$Platform:\n", platform_summary, "\n\n",
      "Subset meta by platform and call runMethQC() separately for each platform.\n",
      "Example:\n",
      "  meta_epic <- meta[meta$Platform == \"EPIC\", ]\n",
      "  qcset_epic <- runMethQC(meta_epic)\n",
      "  meta_450k <- meta[meta$Platform == \"450K\", ]\n",
      "  qcset_450k <- runMethQC(meta_450k)"
    )
  }

  # All Platform values are NA
  stop(
    "platform is NA and all values in meta$Platform are NA.\n",
    "Run check_platform(meta) to detect platforms or pass platform= explicitly."
  )
}

