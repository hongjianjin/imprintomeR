#!/usr/bin/env Rscript
#' Methylation Array QC Processing Script
#'
#' Purpose: Orchestrate the Meth_QC workflow from raw IDAT files through
#'          QC metric computation, validation, and export (Excel, RDS, summary report).
#'
#' Features:
#'   - Pre-flight validation (metadata, file accessibility, platform detection)
#'   - Auto-subset by platform if mixed
#'   - Per-platform QC processing with configurable thresholds
#'   - Export to Excel (color-coded pass/fail), RDS (full MethQcSet), summary report
#'   - Optional QC visualization (intensity, detection p-value, QC bar plots)
#'   - Comprehensive error handling and logging
#'
#' Author: Generated for imprintomeR package
#' Date: 2026

library(optparse)

# ============================================================================
# PHASE 1: CLI SETUP & ARGUMENT PARSING
# ============================================================================

option_list <- list(
    make_option(c("-m", "--metadata"), type = "character", default = NA,
        help = "Metadata file (TSV/CSV) with columns: Sample_Name, Basename, Sample_Group [REQUIRED]"),

    make_option(c("-b", "--datadir"), type = "character", default = NA,
        help = "IDAT directory prefix (parent directory containing Sentrix_ID files) [REQUIRED]"),

    make_option(c("-o", "--outdir"), type = "character", default = NA,
        help = "Output directory for results (will be created if not exists) [REQUIRED]"),

    make_option(c("-p", "--pcutoff"), type = "double", default = 0.05,
        help = "Detection p-value threshold (max mean p-val to pass QC) [default: %default]"),

    make_option(c("-i", "--icutoff"), type = "double", default = 11,
        help = "Reference line for intensity QC plots only; intensity no longer determines Final.QC [default: %default]"),

    make_option(c("--platform"), type = "character", default = NA,
        help = "Override platform detection (EPIC, EPICv2, 450K). If NA, auto-detect from IDAT files [default: auto-detect]"),

    make_option(c("--plot-types"), type = "character", default = NA,
        help = "QC plot types to generate: 'intensity', 'detection_pval', 'qc_bar', or 'all'. [default: intensity,qc_bar]"),

    make_option(c("--no-qc-plots"), action = "store_true", default = FALSE,
        help = "Suppress all QC plot generation"),

    make_option(c("--skip-ewastools"), action = "store_true", default = FALSE,
        help = "Skip ewastools control metrics (if not installed)"),

    make_option(c("-v", "--verbose"), action = "store_true", default = FALSE,
        help = "Enable verbose logging (timestamps, platform summaries)")
)

parser <- OptionParser(
    usage = "%prog -m <metadata.tsv> -b <idat_dir> -o <outdir> [options]",
    description = "Run Meth_QC workflow: validate metadata -> detect platform -> QC processing -> export",
    option_list = option_list,
    epilogue = paste(
        "Examples:\n",
        "  # Basic QC run:\n",
        "  Rscript run_meth_QC.R -m meta.tsv -b /path/to/idats -o qc_output\n\n",
        "  # With custom thresholds and plots:\n",
        "  Rscript run_meth_QC.R -m meta.tsv -b /path/to/idats -o qc_output -p 0.03 -i 12 --plot-types all -v\n\n",
        "  # Override platform (no auto-detect):\n",
        "  Rscript run_meth_QC.R -m meta.tsv -b /path/to/idats -o qc_output --platform EPIC\n",
        sep = ""
    )
)

# Parse arguments with error handling
args <- tryCatch({
    parse_args(parser, positional_arguments = FALSE)
}, error = function(e) {
    cat("Error parsing arguments:\n", conditionMessage(e), "\n")
    print_help(parser)
    quit("no", status = 1)
})

# Show help if no arguments provided
if (length(commandArgs(trailingOnly = TRUE)) == 0) {
    print_help(parser)
    quit("no", status = 0)
}

# ============================================================================
# PHASE 1B: UTILITY FUNCTIONS
# ============================================================================

.try_load_package <- function(pkg, verbose = FALSE) {
    result <- tryCatch({
        library(pkg, character.only = TRUE, quietly = TRUE)
        if (verbose) cat("Package loaded:", pkg, "\n")
        TRUE
    }, error = function(e) {
        if (verbose) cat("Package not available:", pkg, "->", conditionMessage(e), "\n")
        FALSE
    })
    result
}

.log_message <- function(msg, level = "INFO", timestamp = TRUE) {
    prefix <- if (timestamp) {
        paste0("[", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "] ", level, ": ")
    } else {
        paste0("[", level, "]: ")
    }
    cat(prefix, msg, "\n", sep = "")
}

# Load imprintomeR package
if (args$verbose) .log_message("Loading imprintomeR package...")

tryCatch({
    suppressPackageStartupMessages({
        suppressMessages({
            library(imprintomeR)
        })
    })
    if (args$verbose) .log_message("imprintomeR loaded successfully.")
}, error = function(e) {
    .log_message(paste0("ERROR: Failed to load imprintomeR package: ", conditionMessage(e)),
                level = "ERROR")
    quit("no", status = 1)
})

# Try to load optional packages (suppress startup messages)
suppressPackageStartupMessages({
    has_ewastools <- .try_load_package("ewastools", verbose = args$verbose)
})

# ============================================================================
# PHASE 2: PRE-FLIGHT VALIDATION
# ============================================================================

.validate_arguments <- function(args) {
    errors <- character()

    if (is.na(args$metadata)) {
        errors <- c(errors, "ERROR: --metadata is required")
    } else if (!file.exists(args$metadata)) {
        errors <- c(errors, paste0("ERROR: Metadata file not found: ", args$metadata))
    }

    if (is.na(args$datadir)) {
        errors <- c(errors, "ERROR: --datadir is required")
    } else if (!dir.exists(args$datadir)) {
        errors <- c(errors, paste0("ERROR: IDAT directory not found: ", args$datadir))
    }

    if (is.na(args$outdir)) {
        errors <- c(errors, "ERROR: --outdir is required")
    }

    if (!is.na(args$platform) && !args$platform %in% c("EPIC", "EPICv2", "450K", "27K")) {
        errors <- c(errors, paste0("ERROR: Invalid platform '", args$platform,
                                   "'. Must be one of: EPIC, EPICv2, 450K, 27K"))
    }

    if (length(errors) > 0) {
        for (err in errors) cat(err, "\n")
        stop("Validation failed. See errors above.")
    }
}

.validate_metadata <- function(meta_file, verbose = FALSE) {
    if (verbose) .log_message("Validating metadata file...")

    # Use imprintomeR's LoadMeta() which handles all normalization and validation
    meta <- tryCatch({
        invisible(capture.output({
            suppressMessages({
                meta <- LoadMeta(meta_file)
            })
        }))
        meta
    }, error = function(e) {
        stop("Metadata validation failed: ", conditionMessage(e))
    })

    # LoadMeta() should normalize to Sample_Name, but keep a defensive fallback
    # for older package versions or pre-standardized metadata.
    if (!"Sample_Name" %in% colnames(meta) && "SAMPLE_NAME" %in% colnames(meta)) {
        colnames(meta)[colnames(meta) == "SAMPLE_NAME"] <- "Sample_Name"
    }
    if (!"Sample_Name" %in% colnames(meta)) {
        stop("Metadata missing required column: Sample_Name")
    }
    if (anyDuplicated(meta$Sample_Name)) {
        stop("Metadata contains duplicated Sample_Name values: ",
             paste(unique(meta$Sample_Name[duplicated(meta$Sample_Name)]), collapse = ", "))
    }


    # Ensure Basename column exists
    if (!"Basename" %in% colnames(meta)) {
        stop("Metadata missing required column: Basename (path to IDAT files)")
    }

    if (verbose) {
        .log_message(paste0("  Metadata loaded: ", nrow(meta), " samples, ",
                           ncol(meta), " columns"))
        .log_message(paste0("  Columns: ", paste(colnames(meta), collapse = ", ")))
    }

    meta
}

.validate_basenames <- function(meta, idat_dir, verbose = FALSE) {
    if (verbose) .log_message("Validating IDAT file accessibility...")

    idat_exists <- function(prefix, color) {
        any(file.exists(paste0(prefix, "_", color, c(".idat", ".idat.gz"))))
    }

    standardize_idat_names <- function(prefix) {
        pairs <- list(Red = "red", Grn = "green")
        for (canon in names(pairs)) {
            lower <- pairs[[canon]]
            canon_file <- paste0(prefix, "_", canon, ".idat")
            lower_file <- paste0(prefix, "_", lower, ".idat")
            canon_gz <- paste0(canon_file, ".gz")
            lower_gz <- paste0(lower_file, ".gz")

            if (!file.exists(canon_file) && !file.exists(canon_gz)) {
                if (file.exists(lower_file)) {
                    file.rename(lower_file, canon_file)
                } else if (file.exists(lower_gz)) {
                    file.rename(lower_gz, canon_gz)
                }
            }
        }
    }

    resolve_prefix <- function(prefix) {
        candidates <- unique(c(prefix, file.path(idat_dir, prefix)))
        for (candidate in candidates) {
            standardize_idat_names(candidate)
            if (idat_exists(candidate, "Red") && idat_exists(candidate, "Grn")) {
                return(candidate)
            }
        }
        NA_character_
    }

    missing_files <- character()
    resolved <- character(nrow(meta))

    for (i in seq_len(nrow(meta))) {
        basename <- as.character(meta$Basename[i])
        resolved_i <- resolve_prefix(basename)
        if (is.na(resolved_i)) {
            missing_files <- c(missing_files, paste0(
                meta$Sample_Name[i], " (", basename, ")"
            ))
        }
        resolved[i] <- resolved_i
    }

    if (length(missing_files) > 0) {
        stop("IDAT Red/Grn files not found for ", length(missing_files), " sample(s):\n  ",
             paste(missing_files, collapse = "\n  "))
    }

    meta$Basename <- resolved
    if (verbose) .log_message("  All IDAT files accessible; Basename paths resolved.")
    meta
}

.setup_output_dir <- function(outdir, verbose = FALSE) {
    if (verbose) .log_message(paste0("Setting up output directory: ", outdir))

    if (!dir.exists(outdir)) {
        dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
        if (verbose) .log_message("  Output directory created.")
    }

    invisible(outdir)
}

.get_platform_summary <- function(meta, verbose = FALSE) {
    if (!"Platform" %in% colnames(meta)) {
        return(NULL)
    }

    platform_tbl <- table(meta$Platform)
    if (verbose) {
        .log_message("Platform summary:")
        for (p in names(platform_tbl)) {
            .log_message(paste0("  ", p, ": ", platform_tbl[p], " sample(s)"), level = "INFO")
        }
    }

    platform_tbl
}

# Run validation
tryCatch({
    .validate_arguments(args)

    if (args$verbose) .log_message("Phase 1: Pre-flight validation started.")

    # Load and validate metadata
    meta <- .validate_metadata(args$metadata, verbose = args$verbose)

    # Validate IDAT files
    meta <- .validate_basenames(meta, args$datadir, verbose = args$verbose)

    # Setup output directory
    .setup_output_dir(args$outdir, verbose = args$verbose)

    if (args$verbose) .log_message("Phase 1: Pre-flight validation complete. ✓")

}, error = function(e) {
    .log_message(paste0("Pre-flight validation failed: ", conditionMessage(e)), level = "ERROR")
    quit("no", status = 1)
})

# ============================================================================
# PHASE 2B: PLATFORM DETECTION & AUTO-SUBSET
# ============================================================================

tryCatch({
    if (args$verbose) .log_message("Phase 2: Platform detection started.")

    if (is.na(args$platform)) {
        # Auto-detect platform
        if (args$verbose) .log_message("Auto-detecting platform from IDAT files...")
        meta <- suppressMessages({
            check_platform(meta)
        })

        # Check for mixed platforms
        unique_platforms <- unique(meta$Platform[meta$Status == "Success"])

        if (length(unique_platforms) > 1) {
            if (args$verbose) {
                .log_message(paste0("Mixed platforms detected. Auto-subsetting by platform."))
                .get_platform_summary(meta, verbose = TRUE)
            }
        }
    } else {
        # User-specified platform (no auto-detect)
        if (args$verbose) {
            .log_message(paste0("Using user-specified platform: ", args$platform))
        }
        meta$Platform <- args$platform
        meta$Status <- "Success"
    }

    if (args$verbose) .log_message("Phase 2: Platform detection complete. ✓")

}, error = function(e) {
    .log_message(paste0("Platform detection failed: ", conditionMessage(e)), level = "ERROR")
    quit("no", status = 1)
})

# ============================================================================
# PHASE 3: QC PROCESSING (Per-Platform)
# ============================================================================

.expected_qc_rds <- function(platform_outdir, platform) {
    file.path(platform_outdir, paste0(tolower(platform), "_qcset.rds"))
}

.is_valid_cached_qcset <- function(qcset, meta_subset, expected_platform, verbose = FALSE) {
    if (!methods::is(qcset, "MethQcSet")) {
        if (verbose) .log_message("  Cached object is not a MethQcSet", level = "WARN")
        return(FALSE)
    }

    cached_platform <- tryCatch(as.character(methods::slot(qcset, "platform")), error = function(e) NA_character_)
    if (!is.na(cached_platform) && !identical(as.character(cached_platform), as.character(expected_platform))) {
        if (verbose) .log_message(paste0("  Cached platform mismatch: ", cached_platform, " vs ", expected_platform), level = "WARN")
        return(FALSE)
    }

    cached_samples <- tryCatch(as.character(meta(qcset)$Sample_Name), error = function(e) character(0))
    requested_samples <- as.character(meta_subset$Sample_Name)
    if (!setequal(cached_samples, requested_samples)) {
        if (verbose) .log_message("  Cached sample set does not match current metadata", level = "WARN")
        return(FALSE)
    }

    TRUE
}
.run_qc_per_platform <- function(meta_subset, outdir, args, verbose = FALSE) {
    platform <- unique(meta_subset$Platform)

    if (length(platform) > 1) {
        stop("Platform subset must contain exactly one platform, got: ",
             paste(platform, collapse = ", "))
    }

    platform <- platform[1]

    if (verbose) {
        .log_message(paste0("Running QC for platform ", platform,
                           " (", nrow(meta_subset), " samples)"))
    }

    # Create platform-specific output subdirectory
    platform_outdir <- file.path(outdir, tolower(platform))
    if (!dir.exists(platform_outdir)) {
        dir.create(platform_outdir, recursive = TRUE, showWarnings = FALSE)
    }

    # Run QC
    qcset <- tryCatch({
        suppressMessages({
            runMethQC(meta_subset,
                      platform = platform,
                      pcutoff = args$pcutoff)
        })
    }, error = function(e) {
        stop("QC processing failed for platform ", platform, ": ",
             conditionMessage(e))
    })

    if (verbose) {
        .log_message(paste0("  QC complete. MethQcSet object created."))
    }

    list(qcset = qcset, platform = platform, outdir = platform_outdir)
}

.generate_qc_plots <- function(qcset, platform_outdir, plot_types, pcutoff = 0.05, icutoff = 11, verbose = FALSE) {
    # Handle "none" explicitly; NA/empty should use defaults (handled by caller)
    if (!is.null(plot_types) && tolower(plot_types) == "none") {
        return(invisible(NULL))
    }

    plots_dir <- file.path(platform_outdir, "plots")
    if (!dir.exists(plots_dir)) {
        dir.create(plots_dir, recursive = TRUE, showWarnings = FALSE)
    }

    # Get absolute path for reliability
    tryCatch({
        plots_dir_abs <- normalizePath(plots_dir, mustWork = TRUE)
    }, error = function(e) {
        .log_message(paste0("ERROR: Cannot access plots directory: ", plots_dir), level = "ERROR")
        return(invisible(NULL))
    })

    # Normalize plot_types input
    if (tolower(plot_types) == "all") {
        plot_types <- c("intensity", "detection_pval", "qc_bar")
    } else {
        plot_types <- strsplit(plot_types, ",")[[1]]
        plot_types <- trimws(tolower(plot_types))
    }

    if (verbose) {
        .log_message(paste0("Generating QC plots: ", paste(plot_types, collapse = ", ")))
        .log_message(paste0("  Output directory: ", plots_dir_abs))
    }

    for (ptype in plot_types) {
        fname_abs <- file.path(plots_dir_abs, paste0("qc_", ptype, ".png"))

        if (verbose) {
            .log_message(paste0("  Creating plot: ", ptype))
            .log_message(paste0("    Output file: ", fname_abs))
        }

        tryCatch({
            # Open PNG device
            png(fname_abs, width = 1200, height = 800, res = 100)

            if (verbose) .log_message(paste0("    PNG device opened"))

            # Generate plot and catch any errors
            plot_error <- tryCatch({
                p <- if (ptype == "intensity") {
                    plot(qcset, type = "intensity", icutoff = icutoff)
                } else if (ptype == "detection_pval") {
                    plot(qcset, type = "detection_pval", pcutoff = pcutoff)
                } else if (ptype == "qc_bar") {
                    plot(qcset, type = "qc_bar")
                }
                # Print the ggplot object to the PNG device
                if (!is.null(p)) {
                    print(p)
                }
                NULL
            }, error = function(e) {
                return(conditionMessage(e))
            })

            if (!is.null(plot_error)) {
                .log_message(paste0("    ERROR: ", plot_error), level = "ERROR")
            } else if (verbose) {
                .log_message(paste0("    Plot rendered successfully"))
            }

            # Close device
            dev.off()

            # Wait and verify file was written
            Sys.sleep(0.1)
            if (file.exists(fname_abs)) {
                file_size <- file.size(fname_abs) / 1024
                if (verbose) .log_message(paste0("  ✓ Saved: ", fname_abs, " (", round(file_size, 1), " KB)"))
            } else {
                .log_message(paste0("  ERROR: Plot file not created after dev.off(): ", fname_abs), level = "ERROR")
            }

        }, error = function(e) {
            .log_message(paste0("  Exception in plot generation: ", conditionMessage(e)), level = "ERROR")
            # Try to close device if still open
            tryCatch({
                dev.off()
            }, error = function(e2) {
                # Already closed or other issue
            })
        })
    }
}

# Partition metadata by platform and run QC
qc_results <- list()

tryCatch({
    if (args$verbose) .log_message("Phase 3: QC processing started.")

    # Split by platform
    platforms <- unique(meta$Platform[meta$Status == "Success"])

    for (plat in platforms) {
        meta_plat <- meta[meta$Platform == plat & meta$Status == "Success", ]

        if (nrow(meta_plat) == 0) {
            if (args$verbose) .log_message(paste0("Skipping platform ", plat,
                                                  " (no successful samples)"),
                                          level = "WARN")
            next
        }

        # Check if the expected MethQcSet RDS already exists - if so, load and
        # reuse only when platform and Sample_Name set match the current request.
        platform_outdir <- file.path(args$outdir, tolower(plat))
        rds_file <- .expected_qc_rds(platform_outdir, plat)

        if (file.exists(rds_file)) {
            # Load existing RDS instead of rerunning QC when it matches metadata
            if (args$verbose) {
                .log_message(paste0("Loading existing QC results from: ", rds_file))
            }

            qcset <- tryCatch({
                suppressWarnings({
                    readRDS(rds_file)
                })
            }, error = function(e) {
                .log_message(paste0("Warning: Failed to load RDS file, rerunning QC: ",
                                   conditionMessage(e)), level = "WARN")
                NULL
            })

            if (!is.null(qcset) && .is_valid_cached_qcset(qcset, meta_plat, plat, verbose = args$verbose)) {
                result <- list(qcset = qcset, platform = plat, outdir = platform_outdir)
                qc_results[[plat]] <- result

                if (args$verbose) {
                    .log_message(paste0("  Skipped QC processing (using cached results)"))
                }

                # Still generate plots even if QC was skipped
                if (!args$`no-qc-plots`) {
                    plot_types_to_use <- if (is.na(args$`plot-types`)) {
                        "intensity,qc_bar"
                    } else {
                        args$`plot-types`
                    }

                    if (args$verbose) {
                        .log_message(paste0("Calling plot generation (from cached RDS) for platform ", plat))
                        .log_message(paste0("  plot_types_to_use: '", plot_types_to_use, "'"))
                        .log_message(paste0("  platform_outdir: '", result$outdir, "'"))
                    }

                    .generate_qc_plots(result$qcset, result$outdir, plot_types_to_use,
                                      pcutoff = args$pcutoff, icutoff = args$icutoff,
                                      verbose = args$verbose)
                }

                next  # Skip to next platform
            } else if (!is.null(qcset)) {
                if (args$verbose) .log_message("  Cached QC RDS did not match current request; rerunning QC", level = "WARN")
            }
        }

        # Run QC if RDS doesn't exist or failed to load
        result <- .run_qc_per_platform(meta_plat, args$outdir, args,
                                       verbose = args$verbose)
        qc_results[[plat]] <- result

        # Generate plots unless --no-qc-plots is set
        if (!args$`no-qc-plots`) {
            # Use specified plot types, or default to smart defaults
            plot_types_to_use <- if (is.na(args$`plot-types`)) {
                "intensity,qc_bar"  # Smart defaults: intensity + QC pass/fail bar
            } else {
                args$`plot-types`
            }

            if (args$verbose) {
                .log_message(paste0("Calling plot generation for platform ", plat))
                .log_message(paste0("  plot_types_to_use: '", plot_types_to_use, "'"))
                .log_message(paste0("  platform_outdir: '", result$outdir, "'"))
            }

            .generate_qc_plots(result$qcset, result$outdir, plot_types_to_use,
                                      pcutoff = args$pcutoff, icutoff = args$icutoff,
                                      verbose = args$verbose)
        } else {
            if (args$verbose) {
                .log_message(paste0("Plot generation suppressed (--no-qc-plots flag set)"))
            }
        }
    }

    if (args$verbose) .log_message("Phase 3: QC processing complete. ✓")

}, error = function(e) {
    .log_message(paste0("QC processing failed: ", conditionMessage(e)), level = "ERROR")
    quit("no", status = 1)
})

# ============================================================================
# PHASE 4: EXPORT RESULTS
# ============================================================================

tryCatch({
    if (args$verbose) .log_message("Phase 4: Export results started.")

    for (platform in names(qc_results)) {
        result <- qc_results[[platform]]

        if (args$verbose) {
            .log_message(paste0("Exporting results for platform ", platform))
        }

        # Use imprintomeR's export method to handle all formats
        export(result$qcset,
               outdir = result$outdir,
               format = c("xlsx", "rds", "txt"),
               prefix = tolower(platform))

        if (args$verbose) {
            .log_message(paste0("  Export complete for platform ", platform))
        }
    }

    if (args$verbose) .log_message("Phase 4: Export results complete. ✓")

}, error = function(e) {
    .log_message(paste0("Export failed: ", conditionMessage(e)), level = "ERROR")
    quit("no", status = 1)
})

# ============================================================================
# PHASE 5: SUCCESS SUMMARY & LOG FILE
# ============================================================================

log_file <- file.path(args$outdir, "run_meth_QC.log")

tryCatch({
    sink(log_file, append = TRUE)

    cat("\n================================================================================\n")
    cat("RUN METH_QC COMPLETION LOG\n")
    cat("================================================================================\n")
    cat("Date/Time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
    cat("Status: SUCCESS\n")
    cat("\n")

    cat("COMMAND LINE ARGUMENTS\n")
    for (arg_name in names(args)) {
        arg_val <- args[[arg_name]]
        if (is.logical(arg_val)) {
            arg_val <- if (arg_val) "TRUE" else "FALSE"
        }
        cat(sprintf("  %s = %s\n", arg_name, arg_val))
    }
    cat("\n")

    cat("PLATFORMS PROCESSED\n")
    for (platform in names(qc_results)) {
        result <- qc_results[[platform]]
        n_samples <- nrow(qc_tables(result$qcset)[["QC_matrix"]])
        n_passed <- sum(qc_tables(result$qcset)[["QC_matrix"]]$Final.QC == "PASS", na.rm = TRUE)
        cat(sprintf("  %s: %d samples (%d passed)\n", platform, n_samples, n_passed))
    }
    cat("\n")

    cat("OUTPUT DIRECTORY\n")
    cat("  ", args$outdir, "\n")
    cat("\n")

    cat("RESULTS LOCATION\n")
    cat("  Excel files: ", file.path(args$outdir, "*/*.xlsx"), "\n")
    cat("  Text files: ", file.path(args$outdir, "*/*.txt"), "\n")
    cat("  RDS objects: ", file.path(args$outdir, "*/*.rds"), "\n")
    cat("  Plots: ", file.path(args$outdir, "*/plots/"), "\n")
    cat("\n")

    cat("================================================================================\n")

    sink()
}, error = function(e) {
    .log_message(paste0("Warning: Log file write failed: ", conditionMessage(e)),
                level = "WARN")
})

# Print success message to console
.log_message("QC PROCESSING COMPLETE ✓", level = "SUCCESS")
.log_message(paste0("Results written to: ", args$outdir), level = "SUCCESS")
.log_message(paste0("Log file: ", log_file), level = "SUCCESS")

if (args$verbose) {
    cat("\nTo view results:\n")
    cat("  Excel files:", file.path(args$outdir, "*/*_qc_table_*.xlsx"), "\n")
    cat("  Summaries:", file.path(args$outdir, "*/*_summary.txt"), "\n")
}

quit("no", status = 0)
