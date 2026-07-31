#!/usr/bin/env Rscript
#' Imprinting Analysis Pipeline Script
#'
#' Purpose: Orchestrate post-QC imprinting analysis from MethQcSet or beta+metadata
#'          through ImprintomeSet conversion, imprinting scoring, visualization,
#'          and export (TSV + directly saved PDF plots).
#'
#' Features:
#'   - Flexible input: MethQcSet RDS file OR beta.txt + meta.txt files
#'   - QC-clean subsetting with subsetMethQC() when MethQcSet QC results are available
#'   - ImprintomeSet conversion with configurable probeset
#'   - Core imprinting analysis (IDS, Angle, Status and mechanism classification)
#'   - User-configurable plotting through runImprintomeVisualizations()
#'   - TSV/RDS/PDF export with manifest
#'   - Comprehensive error handling and logging
#'
#' Author: Generated for imprintomeR package
#' Date: 2026

library(optparse)

# ============================================================================
# PHASE 1: CLI SETUP & ARGUMENT PARSING
# ============================================================================

option_list <- list(
    make_option(c("-b", "--beta-file"), type = "character", default = NA,
        help = "Beta matrix file (beta.txt or beta_EPIC.txt) [REQUIRED unless -r provided]"),

    make_option(c("-m", "--meta-file"), type = "character", default = NA,
        help = "Metadata file (meta.txt or metadata.tsv) [REQUIRED unless -r provided]"),

    make_option(c("-r", "--rds"), type = "character", default = NA,
        help = "MethQcSet RDS file (alternative to beta + meta) [OPTIONAL]"),

    make_option(c("-o", "--outdir"), type = "character", default = NA,
        help = "Output directory for results (will be created if not exists) [REQUIRED]"),

    make_option(c("--probeset"), type = "character", default = "selected",
        help = "ICR probeset: selected, NanoImprint, Joshi, Court, Rosenski, Jima, chr11p15 [default: %default]"),

    make_option(c("--plot-types"), type = "character", default = "default",
        help = "Comma-separated plot types, or default/all. Supported: polar, beeswarm, beeswarm_origin, beeswarm_chr, heatmap_by_probe, heatmap_by_gene, circular_heatmap, rainfall, radar, mirror_density, violin, cor_heatmap [default: %default]"),

    make_option(c("--ids-cutoff"), type = "double", default = 0.2,
        help = "IDS cutoff threshold for plot filtering [default: %default]"),

    make_option(c("--genome"), type = "character", default = "hg19",
        help = "Genome version for probeset loading (hg19, hg38) [default: %default]"),

    make_option(c("--radar-all"), type = "logical", default = NULL,
        help = "Generate one multipage radar PDF for all samples when TRUE [default: NULL]"),

    make_option(c("--beeswarm-chr-all"), type = "logical", default = NULL, dest = "beeswarm_chr_all",
        help = "Generate one multipage chromosome beeswarm PDF for all samples when TRUE [default: NULL]"),

    make_option(c("--skip-plots"), action = "store_true", default = FALSE,
        help = "Suppress all plot generation"),

    make_option(c("-p", "--prefix"), type = "character", default = NA,
        help = "Output filename prefix (default: basename of --outdir)"),

    make_option(c("-v", "--verbose"), action = "store_true", default = FALSE,
        help = "Enable verbose logging (timestamps, phase details)")
)

parser <- OptionParser(
    usage = "%prog -b <beta.txt> -m <meta.txt> -o <outdir> [options]\n  OR  %prog -r <qcset.rds> -o <outdir> [options]",
    description = "Post-QC imprinting analysis: convert to ImprintomeSet -> analyze -> save plot PDFs -> export",
    option_list = option_list,
    epilogue = paste(
        "Examples:\n",
        "  # From MethQcSet RDS (from run_meth_QC.R):\n",
        "  Rscript run_imprintomeR.R -r qc_results/epic/epic_qcset.rds -o analysis_epic\n\n",
        "  # From beta + metadata files:\n",
        "  Rscript run_imprintomeR.R -b /data/beta.txt -m /data/meta.txt -o analysis --plot-types polar,heatmap_by_gene\n\n",
        "  # All plots, custom probeset and IDS cutoff:\n",
        "  Rscript run_imprintomeR.R -r qcset.rds -o analysis --plot-types all --probeset Joshi --ids-cutoff 0.3 -v\n",
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
        if (verbose) cat("Package not available:", pkg, "", conditionMessage(e), "\n")
        FALSE
    })
    result
}

.log_message <- function(msg, level = "INFO", timestamp = TRUE, verbose = FALSE) {
    prefix <- if (timestamp) {
        paste0("[", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "] ", level, ": ")
    } else {
        paste0("[", level, "]: ")
    }
    full_message <- paste0(prefix, msg)

    # Before sink() is active, write to stdout. After sink() redirects stdout
    # to the log file, verbose messages are written to stderr for console visibility.
    if (verbose && sink.number() > 0) {
        cat(full_message, "\n", file = stderr(), sep = "")
    } else {
        cat(full_message, "\n", sep = "")
    }
}

# Load imprintomeR package (required)
if (args$verbose) .log_message("Loading imprintomeR package...")

tryCatch({
    suppressPackageStartupMessages({
        suppressMessages({
            library(imprintomeR)
            library(ggplot2)
        })
    })
    if (args$verbose) .log_message("Required packages loaded successfully.")
}, error = function(e) {
    .log_message(paste0("ERROR: Failed to load required package: ", conditionMessage(e)),
                level = "ERROR")
    quit("no", status = 1)
})

# ============================================================================
# PHASE 2: INPUT VALIDATION & PREPARATION
# ============================================================================

.validate_arguments <- function(args) {
    errors <- character()

    raw_args <- commandArgs(trailingOnly = TRUE)
    prefix_hits <- sum(raw_args %in% c("-p", "--prefix") | grepl("^--prefix=", raw_args))
    if (prefix_hits > 1L) {
        errors <- c(errors, "ERROR: -p/--prefix was supplied more than once. Use one prefix only; --probeset controls probeset selection.")
    }

    # Check for required output
    if (is.na(args$outdir)) {
        errors <- c(errors, "ERROR: --outdir is required")
    }

    # Check input options: must provide either RDS OR (beta + meta)
    has_rds <- !is.na(args$rds)
    has_beta <- !is.na(args$`beta-file`)
    has_meta <- !is.na(args$`meta-file`)

    if (!has_rds && (!has_beta || !has_meta)) {
        errors <- c(errors, "ERROR: Must provide either -r/--rds OR both -b/--beta-file and -m/--meta-file")
    }

    if (has_rds) {
        if (!file.exists(args$rds)) {
            errors <- c(errors, paste0("ERROR: RDS file not found: ", args$rds))
        }
    } else {
        if (has_beta && !file.exists(args$`beta-file`)) {
            errors <- c(errors, paste0("ERROR: Beta file not found: ", args$`beta-file`))
        }
        if (has_meta && !file.exists(args$`meta-file`)) {
            errors <- c(errors, paste0("ERROR: Meta file not found: ", args$`meta-file`))
        }
    }

    # Validate probeset
    valid_probesets <- c("selected", "NanoImprint", "Joshi", "Court", "Rosenski", "Jima", "chr11p15")
    if (!args$probeset %in% valid_probesets) {
        errors <- c(errors, paste0("ERROR: Invalid probeset '", args$probeset,
                                   "'. Must be one of: ", paste(valid_probesets, collapse = ", ")))
    }

    # Validate plot types if specified
    if (!is.na(args$`plot-types`)) {
        valid_plots <- c("default", "polar", "beeswarm", "beeswarm_origin", "beeswarm_chr", "heatmap_by_probe", "heatmap_by_gene", "circular_heatmap", "rainfall", "radar", "mirror_density", "violin", "cor_heatmap", "all")
        plot_types <- strsplit(tolower(args$`plot-types`), ",\\s*")[[1]]
        invalid_plots <- setdiff(plot_types, valid_plots)
        if (length(invalid_plots) > 0 && !("all" %in% plot_types)) {
            errors <- c(errors, paste0("ERROR: Invalid plot types: ", paste(invalid_plots, collapse = ", ")))
        }
    }

    if (length(errors) > 0) {
        for (err in errors) cat(err, "\n")
        stop("Validation failed. See errors above.")
    }
}

.load_input_data <- function(beta_file, meta_file, rds_file, verbose = FALSE) {
    if (verbose) .log_message("Loading input data...", verbose = verbose)

    # Mode 1: Load from RDS
    if (!is.na(rds_file)) {
        if (verbose) .log_message(paste0("  Loading MethQcSet RDS: ", rds_file), verbose = verbose)

        data <- tryCatch({
            suppressWarnings({
                readRDS(rds_file)
            })
        }, error = function(e) {
            stop("Failed to load RDS file: ", conditionMessage(e))
        })

        # Validate it's a MethQcSet
        if (!is(data, "MethQcSet")) {
            stop("RDS file does not contain a MethQcSet object")
        }

        if (verbose) {
            .log_message(paste0("  Loaded MethQcSet: ", ncol(beta(data)), " samples, ", nrow(beta(data)), " probes"), verbose = verbose)
        }

        return(list(
            data = data,
            source = "MethQcSet RDS",
            platform = data@platform[1]
        ))
    }

    # Mode 2: Load from explicit beta + meta files using imprintomeR built-in functions
    else if (!is.na(beta_file) && !is.na(meta_file)) {
        if (verbose) {
            .log_message(paste0("  Loading beta: ", basename(beta_file)), verbose = verbose)
            .log_message(paste0("  Loading meta: ", basename(meta_file)), verbose = verbose)
        }

        # Use package's LoadMetaBeta() function (handles normalization, alignment, etc.)
        data_list <- tryCatch({
            suppressMessages({
                LoadMetaBeta(meta_file, beta_file)
            })
        }, error = function(e) {
            if (verbose) .log_message(paste0("  LoadMetaBeta failed: ", conditionMessage(e), "; trying separate loads"), verbose = verbose)

            # Fallback: Load separately using LoadMeta() and LoadBeta()
            meta <- tryCatch({
                suppressMessages(LoadMeta(meta_file))
            }, error = function(e) {
                stop("Failed to load metadata: ", conditionMessage(e))
            })

            beta <- tryCatch({
                suppressMessages(LoadBeta(beta_file))
            }, error = function(e) {
                stop("Failed to load beta matrix: ", conditionMessage(e))
            })

            # Convert LoadBeta result (may have TargetID column) to pure matrix
            if (is.data.frame(beta)) {
                rownames(beta) <- beta[, 1]  # First column is probe ID
                beta <- as.matrix(beta[, -1])  # Remove ID column, convert to matrix
            }

            list(meta = meta, beta = beta)
        })

        # Extract beta and meta from result
        beta <- if (is.matrix(data_list$beta)) {
            data_list$beta
        } else if (is.data.frame(data_list$beta)) {
            as.matrix(data_list$beta)
        } else if (is.list(data_list) && "beta" %in% names(data_list)) {
            as.matrix(data_list$beta)
        } else {
            stop("Could not extract beta matrix from loaded data")
        }

        meta <- if (is.data.frame(data_list$meta)) {
            data_list$meta
        } else if (is.list(data_list) && "meta" %in% names(data_list)) {
            data_list$meta
        } else {
            stop("Could not extract metadata from loaded data")
        }

        # Infer platform from meta
        platform <- if ("Platform" %in% colnames(meta)) {
            unique(meta$Platform)[1]
        } else {
            "EPIC"  # Default fallback
        }

        # Check for sample name overlap
        beta_samples <- colnames(beta)
        meta_samples <- if ("Sample_Name" %in% colnames(meta)) as.character(meta$Sample_Name) else rownames(meta)
        overlapping <- intersect(beta_samples, meta_samples)

        if (length(overlapping) == 0) {
            cat("\n\n[ERROR] Sample name mismatch:\n")
            cat("  Beta file column names (first 5): ", paste(head(beta_samples, 5), collapse = ", "), "\n")
            cat("  Meta file Sample_Name (first 5): ", paste(head(meta_samples, 5), collapse = ", "), "\n")
            cat("  Overlapping samples: 0\n\n")
            stop("No overlapping samples between beta file columns and meta Sample_Name")
        }

        if (verbose) {
            .log_message(paste0("    Beta: ", ncol(beta), " samples, ", nrow(beta), " probes"), verbose = verbose)
            .log_message(paste0("    Meta: ", nrow(meta), " samples"), verbose = verbose)
            .log_message(paste0("    Overlapping: ", length(overlapping), " samples"), verbose = verbose)
            .log_message(paste0("    Platform: ", platform), verbose = verbose)
        }

        return(list(
            data = list(beta = beta, meta = meta),
            source = "beta.txt + meta.txt",
            platform = platform
        ))
    }

    else {
        stop("Internal error: neither RDS nor beta+meta provided")
    }
}

.prepare_qcset_for_analysis <- function(qcset, verbose = FALSE) {
    if (!is(qcset, "MethQcSet")) {
        return(qcset)
    }

    if (verbose) .log_message("Preparing QC-clean MethQcSet...", verbose = verbose)

    qc_tabs <- qc_tables(qcset)
    if (is.null(qc_tabs$QC_matrix) || !"Final.QC" %in% colnames(qc_tabs$QC_matrix)) {
        if (verbose) .log_message("  QC_matrix/Final.QC not available; using all samples", verbose = verbose)
        return(qcset)
    }

    qc_matrix <- qc_tabs$QC_matrix
    pass_count <- sum(qc_matrix$Final.QC == "PASS", na.rm = TRUE)
    fail_count <- sum(qc_matrix$Final.QC == "FAIL", na.rm = TRUE)

    if (verbose) {
        .log_message(paste0("  QC summary: ", pass_count, " PASS, ",
                            fail_count, " FAIL, ",
                            nrow(qc_matrix) - pass_count - fail_count, " other"), verbose = verbose)
    }

    if (pass_count == 0L) {
        stop("No samples with Final.QC == 'PASS'; cannot continue to imprintome analysis")
    }

    if (fail_count > 0L || pass_count < ncol(beta(qcset))) {
        qcset <- tryCatch({
            subsetMethQC(qcset, final_qc = "PASS")
        }, error = function(e) {
            stop("Failed to subset MethQcSet to QC-pass samples: ", conditionMessage(e))
        })
        if (verbose) .log_message(paste0("  Using QC-clean samples: ", ncol(beta(qcset))), verbose = verbose)
    }

    qcset
}

# ============================================================================
# PHASE 3: CONVERSION TO IMPRINTOMESET
# ============================================================================

.load_probeset_by_name <- function(probeset_name, genome, verbose = FALSE) {
    # Load probeset data from package inst/extdata based on genome version
    # Follows README.md workflow: loads from probesets_{genome}.rds

    # If already data structure, return as-is
    if (is.data.frame(probeset_name) || is(probeset_name, "DataFrame")) {
        return(probeset_name)
    }

    if (!is.character(probeset_name)) {
        if (verbose) .log_message("  Probeset is not character; returning as-is", verbose = verbose)
        return(probeset_name)
    }

    # Determine probeset file based on genome version
    probeset_file <- system.file(
        "extdata",
        paste0("probesets_", tolower(genome), ".rds"),
        package = "imprintomeR"
    )

    if (!file.exists(probeset_file)) {
        stop("Probeset file not found: ", probeset_file, ". Supported genomes: hg19, hg38")
    }

    # Load probeset list from RDS
    probeset_list <- tryCatch({
        suppressWarnings(readRDS(probeset_file))
    }, error = function(e) {
        stop("Failed to load probeset file: ", conditionMessage(e))
    })

    # Handle different probeset name cases
    name_to_find <- tolower(probeset_name)

    # Try exact name match
    if (probeset_name %in% names(probeset_list)) {
        if (verbose) .log_message(paste0("  Loaded probeset: ", probeset_name), verbose = verbose)
        return(probeset_list[[probeset_name]])
    }

    # Try case-insensitive match
    matched_idx <- which(tolower(names(probeset_list)) == name_to_find)
    if (length(matched_idx) > 0) {
        matched_name <- names(probeset_list)[matched_idx[1]]
        if (verbose) .log_message(paste0("  Loaded probeset: ", matched_name), verbose = verbose)
        return(probeset_list[[matched_idx[1]]])
    }

    # Special case: "all" returns the entire list (for compatibility)
    if (name_to_find == "all") {
        if (verbose) .log_message("  Loaded all probesets from file", verbose = verbose)
        return(probeset_list)
    }

    # If not found, error out
    available <- paste(names(probeset_list), collapse = ", ")
    stop("Probeset '", probeset_name, "' not found. Available: ", available)
}

.convert_to_imprintomeset <- function(input_data, probeset, platform, genome, verbose = FALSE) {
    # Convert input_data to ImprintomeSet following README.md workflow
    # Handles: MethQcSet conversion, EPICv2 aggregation, direct construction from beta+meta

    if (is(input_data, "ImprintomeSet")) {
        if (verbose) .log_message("  Input already ImprintomeSet; skipping conversion", verbose = verbose)
        return(input_data)
    }

    # Load probeset data from RDS file
    if (verbose) .log_message(paste0("  Loading probeset '", probeset, "' from ", genome), verbose = verbose)
    probeset_data <- tryCatch({
        .load_probeset_by_name(probeset, genome, verbose = verbose)
    }, error = function(e) {
        stop("Failed to load probeset: ", conditionMessage(e))
    })

    # Show probeset size
    probeset_size <- if (is.data.frame(probeset_data)) {
        nrow(probeset_data)
    } else if (is.list(probeset_data)) {
        length(unique(unlist(probeset_data)))
    } else {
        NA
    }
    if (verbose && !is.na(probeset_size)) {
        .log_message(paste0("    Probeset '", probeset, "' contains ", probeset_size, " probes"), verbose = verbose)
    }

    # CASE 1: Convert from MethQcSet (main path from QC preprocessing)
    if (is(input_data, "MethQcSet")) {
        if (verbose) .log_message(paste0("  Converting MethQcSet  ImprintomeSet (platform: ",
                                        input_data@platform[1], ")"), verbose = verbose)

        qcset <- input_data

        # REQUIRED: EPICv2 aggregation (README.md emphasizes this must happen before conversion)
        if (qcset@platform[1] == "EPICv2") {
            if (verbose) .log_message("   EPICv2 detected: aggregating replicate probes...", verbose = verbose)
            qcset <- tryCatch({
                aggregate_probes(qcset)
            }, error = function(e) {
                stop("EPICv2 aggregation failed: ", conditionMessage(e))
            })
            if (verbose) {
                .log_message(paste0("    Aggregation complete: ", nrow(qcset@beta), " unique probes"), verbose = verbose)
            }
        }

        # Convert to ImprintomeSet
        imp_set <- tryCatch({
            as.ImprintomeSet(qcset, probeset = probeset_data, genome = genome)
        }, error = function(e) {
            stop("Conversion to ImprintomeSet failed: ", conditionMessage(e))
        })
    }
    # CASE 2: Construct directly from beta + meta (Option B: QC already done externally)
    else if (is.list(input_data) && "beta" %in% names(input_data) && "meta" %in% names(input_data)) {
        if (verbose) .log_message("  Constructing ImprintomeSet from beta + meta (external QC)", verbose = verbose)

        imp_set <- tryCatch({
            ImprintomeSet(
                beta = input_data$beta,
                meta = input_data$meta,
                probeset = probeset_data,
                genome = genome,
                assay = platform,
                auto_group = TRUE
            )
        }, error = function(e) {
            stop("Failed to construct ImprintomeSet: ", conditionMessage(e))
        })
    }
    else {
        stop("Input data must be MethQcSet or list(beta=matrix, meta=data.frame)")
    }

    if (verbose) {
        probeset_info <- if (is.data.frame(probeset_data)) {
            paste0(nrow(probeset_data), " probes")
        } else if (is.list(probeset_data)) {
            paste0(length(unique(unlist(probeset_data))), " probes")
        } else {
            "unknown"
        }
        .log_message(paste0("   ImprintomeSet ready: ", ncol(imp_set@beta), " samples  ",
                           nrow(imp_set@beta), " total probes, ", probeset_info, " in probeset (",
                           genome, ", ", imp_set@assay[1], ")"), verbose = verbose)
    }

    imp_set
}

# ============================================================================
# PHASE 4: CORE ANALYSIS (runImprintome)
# ============================================================================

.run_core_analysis <- function(imp_set, probeset, ids_cutoff, verbose = FALSE) {
    if (verbose) .log_message("Running imprinting analysis...", verbose = verbose)

    imp_set_analyzed <- tryCatch({
        suppressMessages({
            # CRITICAL: Pass probeset name to runImprintome() to determine result name
            # probeset parameter controls BOTH which probes filter results AND the result name
            # Result will be stored as "AnalyzeImprintStatus.{probeset}"
            runImprintome(imp_set, probeset = probeset, ids_cutoff = ids_cutoff)
        })
    }, error = function(e) {
        stop("Imprinting analysis failed: ", conditionMessage(e))
    })

    result_name <- paste0("AnalyzeImprintStatus.", probeset)
    result_list <- results(imp_set_analyzed)
    if (result_name %in% names(result_list)) {
        attr(result_list[[result_name]], "imprintomeR_cache") <- list(
            probeset = probeset,
            genome = as.character(imp_set_analyzed@genome)[1],
            ids_cutoff = as.numeric(ids_cutoff)[1]
        )
        results(imp_set_analyzed) <- result_list
    }

    # Extract results summary
    res <- tryCatch({
        results(imp_set_analyzed)
    }, error = function(e) {
        if (verbose) .log_message("  Warning: Could not extract results; skipping summary", verbose = verbose)
        NULL
    })

    if (!is.null(res) && verbose) {
        result_name <- paste0("AnalyzeImprintStatus.", probeset)
        status_tbl <- if (result_name %in% names(res)) res[[result_name]] else res[[1]]
        if (is.data.frame(status_tbl) && "Status" %in% colnames(status_tbl)) {
            status_table <- table(status_tbl$Status)
            .log_message(paste0("  Status classification: ",
                               paste(names(status_table), status_table, sep = "=", collapse = ", ")), verbose = verbose)
        }
        if (is.data.frame(status_tbl) && "Mechanism" %in% colnames(status_tbl)) {
            mech_table <- table(status_tbl$Mechanism)
            .log_message(paste0("  Mechanism classification: ",
                               paste(names(mech_table), mech_table, sep = "=", collapse = ", ")), verbose = verbose)
        }
    }

    if (verbose) .log_message("  Analysis complete", verbose = verbose)

    imp_set_analyzed
}

.activate_probeset <- function(imp_set, probeset, genome, verbose = FALSE) {
    probeset(imp_set) <- .load_probeset_by_name(probeset, genome, verbose = verbose)
    imp_set
}

.cached_result_matches <- function(imp_set, probeset, genome, ids_cutoff) {
    if (!identical(tolower(as.character(imp_set@genome)[1]), tolower(genome))) {
        return(FALSE)
    }

    result_name <- paste0("AnalyzeImprintStatus.", probeset)
    result_list <- results(imp_set)
    if (!(result_name %in% names(result_list))) {
        return(FALSE)
    }

    cache_info <- attr(result_list[[result_name]], "imprintomeR_cache", exact = TRUE)
    is.list(cache_info) &&
        identical(cache_info$probeset, probeset) &&
        identical(tolower(cache_info$genome), tolower(genome)) &&
        isTRUE(all.equal(as.numeric(cache_info$ids_cutoff), as.numeric(ids_cutoff)))
}

# ============================================================================
# PHASE 5: PLOTTING (CONDITIONAL)
# ============================================================================

.parse_plot_types <- function(plot_types_str, skip_plots) {
    if (skip_plots || is.na(plot_types_str)) {
        return(character())
    }

    plot_list <- unique(tolower(strsplit(plot_types_str, ",\\s*")[[1]]))
    plot_list <- plot_list[nzchar(plot_list)]

    if (length(plot_list) == 0L) {
        return("default")
    }
    if ("all" %in% plot_list) {
        return("all")
    }
    if ("default" %in% plot_list) {
        return("default")
    }

    plot_list
}

.strip_plot_payload <- function(imp_set) {
    plots(imp_set) <- list()
    attr(imp_set, "visualization_manifest") <- NULL
    imp_set
}

.generate_imprintome_plots <- function(imp_set, plot_types, probeset, outdir, prefix, verbose = FALSE) {
    if (length(plot_types) == 0) {
        if (verbose) .log_message("Plot generation skipped", verbose = verbose)
        return(imp_set)
    }

    if (verbose) .log_message(paste0("Generating and saving plot PDFs: ", paste(plot_types, collapse = ", ")), verbose = verbose)

    results_available <- names(results(imp_set))
    expected_result <- paste0("AnalyzeImprintStatus.", probeset)
    result_name <- if (expected_result %in% results_available) {
        expected_result
    } else if (length(results_available) > 0) {
        results_available[1]
    } else {
        NULL
    }

    if (is.null(result_name)) {
        warning("No analysis results found; skipping plot generation")
        return(.strip_plot_payload(imp_set))
    }

    sample_id <- colnames(beta(imp_set))[1]
    imp_set <- tryCatch({
        runImprintomeVisualizations(
            imp_set,
            plot_types = plot_types,
            probeset = probeset,
            result_name = result_name,
            sample_id = sample_id,
            prefix = prefix,
            outdir = outdir,
            save_plots = TRUE,
            store_plots = FALSE,
            overwrite = TRUE,
            verbose = verbose
        )
    }, error = function(e) {
        warning("runImprintomeVisualizations() failed: ", conditionMessage(e))
        imp_set
    })

    if (verbose && !is.null(attr(imp_set, "visualization_manifest"))) {
        vis_manifest <- attr(imp_set, "visualization_manifest")
        .log_message(paste0("  Visualization attempts: ", nrow(vis_manifest)), verbose = verbose)
        if ("file" %in% colnames(vis_manifest)) {
            saved_files <- basename(na.omit(vis_manifest$file))
            if (length(saved_files) > 0L) {
                .log_message(paste0("  Saved plot files: ", paste(saved_files, collapse = ", ")), verbose = verbose)
            }
        }
    }

    .strip_plot_payload(imp_set)
}

.plot_types_without_single_radar <- function(plot_types) {
    if (identical(plot_types, "default")) {
        return(c("polar", "beeswarm_origin", "mirror_density",
                 "heatmap_by_probe", "heatmap_by_gene", "beeswarm_chr", "rainfall"))
    }
    if (identical(plot_types, "all")) {
        return(c("polar", "mirror_density", "beeswarm", "beeswarm_origin",
                 "beeswarm_chr", "violin", "heatmap_by_probe", "heatmap_by_gene",
                 "circular_heatmap", "cor_heatmap", "rainfall"))
    }
    setdiff(plot_types, "radar")
}

.plot_types_without_single_beeswarm_chr <- function(plot_types) {
    if (identical(plot_types, "default")) {
        return(c("polar", "beeswarm_origin", "mirror_density",
                 "heatmap_by_probe", "heatmap_by_gene", "radar", "rainfall"))
    }
    if (identical(plot_types, "all")) {
        return(c("polar", "mirror_density", "beeswarm", "beeswarm_origin",
                 "violin", "heatmap_by_probe", "heatmap_by_gene",
                 "circular_heatmap", "cor_heatmap", "rainfall", "radar"))
    }
    setdiff(plot_types, "beeswarm_chr")
}

.generate_all_radar_plots <- function(imp_set, probeset, outdir, prefix, verbose = FALSE) {
    sample_ids <- colnames(beta(imp_set))
    sample_ids <- sample_ids[!is.na(sample_ids) & nzchar(sample_ids)]
    if (length(sample_ids) == 0L) {
        warning("--radar-all found no sample columns in beta(imp_set)")
        return(invisible(data.frame()))
    }

    safe_probeset <- gsub("[^A-Za-z0-9_.-]", "_", probeset)
    out_file <- file.path(
        outdir,
        paste0(prefix, "_radar.", safe_probeset, ".all.pdf")
    )
    result_name <- paste0("AnalyzeImprintStatus.", probeset)
    manifest <- data.frame(
        sample_id = sample_ids,
        file = rep(out_file, length(sample_ids)),
        status = "pending",
        message = "",
        stringsAsFactors = FALSE
    )

    pdf_opened <- FALSE
    successful <- 0L
    grDevices::pdf(out_file, width = 12, height = 12, onefile = TRUE)
    pdf_opened <- TRUE
    on.exit(if (isTRUE(pdf_opened)) grDevices::dev.off(), add = TRUE)

    for (i in seq_along(sample_ids)) {
        err <- NULL
        tryCatch({
            p <- plot(
                imp_set,
                plot_type = "radar",
                result_name = result_name,
                probeset = probeset,
                sample_id = sample_ids[i]
            )
            print(p)
        }, error = function(e) {
            err <<- conditionMessage(e)
        })

        if (is.null(err)) {
            manifest$status[i] <- "saved"
            successful <- successful + 1L
        } else {
            manifest$status[i] <- "skipped_error"
            manifest$message[i] <- err
            warning("Skipping radar plot for sample '", sample_ids[i], "': ", err, call. = FALSE)
        }
    }

    grDevices::dev.off()
    pdf_opened <- FALSE
    if (successful == 0L && file.exists(out_file)) {
        unlink(out_file)
    }

    if (verbose) {
        .log_message(
            paste0(
                "  Radar-all: ", successful, " pages saved, ",
                sum(manifest$status != "saved"), " skipped; file: ", out_file
            ),
            verbose = verbose
        )
    }
    invisible(manifest)
}

.generate_all_beeswarm_chr_plots <- function(imp_set, probeset, outdir, prefix, verbose = FALSE) {
    sample_ids <- colnames(beta(imp_set))
    sample_ids <- sample_ids[!is.na(sample_ids) & nzchar(sample_ids)]
    if (length(sample_ids) == 0L) {
        warning("--beeswarm-chr-all found no sample columns in beta(imp_set)")
        return(invisible(data.frame()))
    }

    safe_probeset <- gsub("[^A-Za-z0-9_.-]", "_", probeset)
    out_file <- file.path(
        outdir,
        paste0(prefix, "_beeswarm_chr.", safe_probeset, ".all.pdf")
    )
    manifest <- data.frame(
        sample_id = sample_ids,
        file = rep(out_file, length(sample_ids)),
        status = "pending",
        message = "",
        stringsAsFactors = FALSE
    )

    pdf_opened <- FALSE
    successful <- 0L
    grDevices::pdf(out_file, width = 10, height = 4, onefile = TRUE)
    pdf_opened <- TRUE
    on.exit(if (isTRUE(pdf_opened)) grDevices::dev.off(), add = TRUE)

    for (i in seq_along(sample_ids)) {
        err <- NULL
        tryCatch({
            p <- plot(
                imp_set,
                plot_type = "beeswarm_chr",
                probeset = probeset,
                sample_id = sample_ids[i]
            )
            print(p)
        }, error = function(e) {
            err <<- conditionMessage(e)
        })

        if (is.null(err)) {
            manifest$status[i] <- "saved"
            successful <- successful + 1L
        } else {
            manifest$status[i] <- "skipped_error"
            manifest$message[i] <- err
            warning(
                "Skipping chromosome beeswarm for sample '", sample_ids[i], "': ",
                err, call. = FALSE
            )
        }
    }

    grDevices::dev.off()
    pdf_opened <- FALSE
    if (successful == 0L && file.exists(out_file)) {
        unlink(out_file)
    }

    if (verbose) {
        .log_message(
            paste0(
                "  Beeswarm-chr-all: ", successful, " pages saved, ",
                sum(manifest$status != "saved"), " skipped; file: ", out_file
            ),
            verbose = verbose
        )
    }
    invisible(manifest)
}

# ============================================================================
# PHASE 6: EXPORT RESULTS (using built-in export() function)
# ============================================================================

.export_imprintome_analysis <- function(imp_set, outdir, probeset, plot_types = NULL, verbose = FALSE) {
    # Export result tables and the original lean ImprintomeSet object.
    # Plot PDFs are generated directly and are not stored in the RDS.

    if (verbose) .log_message("Exporting analysis results and lean ImprintomeSet RDS...", verbose = verbose)

    export_prefix <- if (!is.na(args$prefix)) args$prefix else basename(normalizePath(outdir, mustWork = FALSE))
    if (verbose) {
        .log_message(paste0("  Export prefix: ", export_prefix), verbose = verbose)
        .log_message("  Export stored plots: FALSE", verbose = verbose)
    }

    lean_set <- .strip_plot_payload(imp_set)
    manifest <- tryCatch({
        export(
            lean_set,
            outdir = outdir,
            save_plots = FALSE,
            plot_device = "pdf",
            prefix = export_prefix,
            overwrite = TRUE
        )
    }, error = function(e) {
        if (verbose) {
            .log_message(paste0("  Warning: export() function failed: ", conditionMessage(e)), verbose = verbose)
            .log_message("  Falling back to manual export...", verbose = verbose)
        }

        .export_imprintome_fallback(lean_set, outdir, probeset, verbose = verbose)
    })

    if (verbose && is.data.frame(manifest) && nrow(manifest) > 0) {
        .log_message(paste0("  Export manifest rows: ", nrow(manifest)), verbose = verbose)
        for (k in seq_len(nrow(manifest))) {
            .log_message(paste0("    ", manifest$category[k], "/", manifest$name[k], ": ", basename(manifest$file[k]), " [", manifest$status[k], "]"), verbose = verbose)
        }
    }
    if (verbose) .log_message(paste0("  All results exported to: ", outdir), verbose = verbose)

    invisible(manifest)
}

.export_imprintome_without_rds <- function(imp_set, outdir, prefix, verbose = FALSE) {
    if (verbose) .log_message("Exporting result tables without changing existing ImprintomeSet RDS...", verbose = verbose)
    dir.create(outdir, recursive = TRUE, showWarnings = FALSE)

    sanitize_name <- function(s) gsub("[^A-Za-z0-9_.-]", "_", as.character(s)[1])
    safe_prefix <- sanitize_name(prefix)
    res_list <- results(imp_set)
    res_names <- names(res_list)
    if (is.null(res_names)) {
        res_names <- paste0("result_", seq_along(res_list))
        names(res_list) <- res_names
    }

    manifest <- data.frame(category = character(0), name = character(0), file = character(0), status = character(0), stringsAsFactors = FALSE)
    for (nm in sort(res_names)) {
        obj <- res_list[[nm]]
        safe_nm <- sanitize_name(nm)
        if (is.data.frame(obj) || is.matrix(obj)) {
            fpath <- file.path(outdir, paste0(safe_prefix, "_results_", safe_nm, ".tsv"))
            write.table(obj, fpath, sep = "\t", quote = FALSE, row.names = FALSE, col.names = TRUE)
        } else {
            fpath <- file.path(outdir, paste0(safe_prefix, "_results_", safe_nm, ".rds"))
            saveRDS(obj, fpath)
        }
        manifest <- rbind(manifest, data.frame(category = "results", name = nm, file = fpath, status = "written", stringsAsFactors = FALSE))
    }

    if (verbose && nrow(manifest) > 0) {
        .log_message(paste0("  Exported result files: ", nrow(manifest)), verbose = verbose)
        for (k in seq_len(nrow(manifest))) {
            .log_message(paste0("    ", manifest$category[k], "/", manifest$name[k], ": ", basename(manifest$file[k]), " [", manifest$status[k], "]"), verbose = verbose)
        }
    }

    invisible(manifest)
}

.export_requested_analysis <- function(imp_set, outdir, probeset, artifact_prefix,
                                       imprintome_rds, save_rds = TRUE, verbose = FALSE) {
    result_name <- paste0("AnalyzeImprintStatus.", probeset)
    result_list <- results(imp_set)
    if (!(result_name %in% names(result_list))) {
        stop("Requested analysis result is missing: ", result_name)
    }

    result_file <- file.path(
        outdir,
        paste0(artifact_prefix, "_results_", result_name, ".tsv")
    )
    write.table(result_list[[result_name]], result_file, sep = "\t", quote = FALSE,
                row.names = FALSE, col.names = TRUE)

    if (isTRUE(save_rds)) {
        saveRDS(.strip_plot_payload(imp_set), imprintome_rds)
    }

    manifest <- data.frame(
        category = c("results", if (isTRUE(save_rds)) "data" else character()),
        name = c(result_name, if (isTRUE(save_rds)) "ImprintomeSet" else character()),
        file = c(result_file, if (isTRUE(save_rds)) imprintome_rds else character()),
        status = "written",
        stringsAsFactors = FALSE
    )
    if (verbose) .log_message(paste0("  Exported: ", result_file), verbose = verbose)
    invisible(manifest)
}

.export_imprintome_fallback <- function(imp_set, outdir, probeset, verbose = FALSE) {
    # Fallback export if built-in export() fails
    # Exports: results (xlsx/tsv), metadata.tsv, imprintomeSet.rds

    manifest <- character()
    outdir_prefix <- if (!is.na(args$prefix)) args$prefix else basename(normalizePath(outdir))

    # Export main analysis results
    results_available <- names(results(imp_set))

    # Determine which result to use (based on probeset that was analyzed)
    expected_result <- paste0("AnalyzeImprintStatus.", probeset)
    result_name <- if (expected_result %in% results_available) {
        expected_result
    } else if (length(results_available) > 0) {
        results_available[1]
    } else {
        NULL
    }

    if (!is.null(result_name)) {
        result_table <- results(imp_set)[[result_name]]

        # Try XLSX first
        if (requireNamespace("openxlsx", quietly = TRUE)) {
            summary_file <- file.path(outdir, paste0(outdir_prefix, "_AnalysisResults.xlsx"))
            tryCatch({
                openxlsx::write.xlsx(result_table, summary_file)
                manifest <- c(manifest, paste0(basename(summary_file), " (", nrow(result_table), " samples)"))
                cat(basename(summary_file), "[saved]\n", file = stderr())
                if (verbose) .log_message(paste0("   ", basename(summary_file), " [saved]"), verbose = verbose)
            }, error = function(e) {
                if (verbose) .log_message(paste0("    Warning: XLSX failed, using TSV: ", conditionMessage(e)), verbose = verbose)
            })
        }

        # TSV fallback
        if (!requireNamespace("openxlsx", quietly = TRUE) || length(manifest) == 0) {
            summary_file <- file.path(outdir, paste0(outdir_prefix, "_AnalysisResults.tsv"))
            tryCatch({
                write.table(result_table, summary_file, sep = "\t", row.names = FALSE, quote = FALSE)
                manifest <- c(manifest, paste0(basename(summary_file), " (", nrow(result_table), " samples)"))
                cat(basename(summary_file), "[saved]\n", file = stderr())
                if (verbose) .log_message(paste0("   ", basename(summary_file), " [saved] (TSV)"), verbose = verbose)
            }, error = function(e) {
                if (verbose) .log_message(paste0("    Error: TSV export failed: ", conditionMessage(e)), verbose = verbose)
            })
        }
    } else if (verbose) {
        .log_message("  Warning: No analysis results found", verbose = verbose)
    }

    # Export metadata
    meta_file <- file.path(outdir, "metadata.tsv")
    tryCatch({
        write.table(imp_set@meta, meta_file, sep = "\t", quote = FALSE, row.names = FALSE)
        manifest <- c(manifest, paste0("metadata.tsv (", nrow(imp_set@meta), " samples)"))
        cat("metadata.tsv [saved]\n", file = stderr())
        if (verbose) .log_message("   metadata.tsv [saved]", verbose = verbose)
    }, error = function(e) {
        if (verbose) .log_message(paste0("    Error: metadata export failed: ", conditionMessage(e)), verbose = verbose)
    })

    # Export full ImprintomeSet as RDS
    rds_file <- file.path(outdir, paste0(outdir_prefix, "_imprintomeSet.rds"))
    tryCatch({
        saveRDS(imp_set, rds_file)
        file_size <- file.size(rds_file) / 1024^2
        manifest <- c(manifest, paste0(basename(rds_file), " (", round(file_size, 2), " MB)"))
        cat(basename(rds_file), "[saved]\n", file = stderr())
        if (verbose) .log_message(paste0("   ", basename(rds_file), " (", round(file_size, 2), " MB) [saved]"), verbose = verbose)
    }, error = function(e) {
        if (verbose) .log_message(paste0("    Error: RDS export failed: ", conditionMessage(e)), verbose = verbose)
    })

    invisible(manifest)
}

# ============================================================================
# PHASE 7: MAIN ORCHESTRATION
# ============================================================================

main <- function() {
    start_time <- Sys.time()

    if (args$verbose) {
        .log_message("=== Imprinting Analysis Pipeline ===", verbose = args$verbose)
        .log_message(paste0("Starting at: ", format(start_time, "%Y-%m-%d %H:%M:%S")), verbose = args$verbose)
    }

    # Phase 2: Validate arguments
    tryCatch({
        .validate_arguments(args)
    }, error = function(e) {
        .log_message(conditionMessage(e), level = "ERROR")
        quit("no", status = 1)
    })

    # Create output directory
    if (!dir.exists(args$outdir)) {
        dir.create(args$outdir, showWarnings = FALSE, recursive = TRUE)
    }

    dataset_prefix <- if (!is.na(args$prefix)) args$prefix else basename(normalizePath(args$outdir, mustWork = FALSE))
    cache_prefix <- paste(dataset_prefix, tolower(args$genome), sep = "_")
    imprintome_rds <- file.path(args$outdir, paste0(cache_prefix, "_imprintomeSet.rds"))

    # Set up logging file
    log_file <- file.path(args$outdir, "run_imprintomeR.log")

    # Redirect stderr to log file (in addition to stdout)
    if (!interactive()) {
        sink(log_file, append = TRUE, split = FALSE)
    }

    tryCatch({
        loaded_existing <- FALSE
        if (file.exists(imprintome_rds)) {
            loaded_existing <- FALSE
            if (args$verbose) {
                .log_message(paste0("Existing ImprintomeSet found: ", imprintome_rds), verbose = args$verbose)
                .log_message("Loading existing ImprintomeSet", verbose = args$verbose)
            }
            imp_set <- tryCatch({
                readRDS(imprintome_rds)
            }, error = function(e) {
                stop("Failed to load existing ImprintomeSet RDS: ", conditionMessage(e))
            })
            if (!is(imp_set, "ImprintomeSet")) {
                stop("Existing RDS does not contain an ImprintomeSet object: ", imprintome_rds)
            }
            existing_plot_count <- length(plots(imp_set))
            if (args$verbose) {
                .log_message(paste0("  Loaded ImprintomeSet: ", ncol(beta(imp_set)), " samples, ", nrow(beta(imp_set)), " probes"), verbose = args$verbose)
                .log_message(paste0("  Existing results: ", paste(names(results(imp_set)), collapse = ", ")), verbose = args$verbose)
                .log_message(paste0("  Existing stored plots: ", existing_plot_count), verbose = args$verbose)
            }
            if (existing_plot_count > 0L) {
                imp_set <- .strip_plot_payload(imp_set)
                gc(verbose = FALSE)
                if (args$verbose) .log_message("  Cleared stored plots from in-memory object; existing RDS was not changed", verbose = args$verbose)
            }

            requested_result <- paste0("AnalyzeImprintStatus.", args$probeset)

            if (.cached_result_matches(
                imp_set, args$probeset, args$genome, args$`ids-cutoff`
            )) {
                imp_set <- .activate_probeset(
                    imp_set, args$probeset, args$genome, verbose = args$verbose
                )
                loaded_existing <- TRUE
                if (args$verbose) {
                    .log_message(paste0("  Cached result found: ", requested_result), verbose = args$verbose)
                    .log_message("  Skipping input conversion and core analysis", verbose = args$verbose)
                }
            } else {
                loaded_existing <- FALSE
                imp_set <- .activate_probeset(
                    imp_set, args$probeset, args$genome, verbose = args$verbose
                )
                if (args$verbose) {
                    .log_message(paste0("  Cached result not found for requested probeset: ", requested_result), verbose = args$verbose)
                    .log_message("  Running core analysis on cached ImprintomeSet", verbose = args$verbose)
                }
                imp_set <- .run_core_analysis(
                    imp_set,
                    probeset = args$probeset,
                    ids_cutoff = args$`ids-cutoff`,
                    verbose = args$verbose
                )

                if (args$verbose) {
                    .log_message("Summarizing ImprintomeSet...", verbose = args$verbose)
                    tryCatch({
                        summary_result <- summarize(imp_set)
                        if (!is.null(summary_result)) {
                            .log_message(paste0("   Summary complete: ",
                                              nrow(summary_result$results), " analysis records"), verbose = args$verbose)
                        }
                    }, error = function(e) {
                        .log_message(paste0("  Note: summarize() not available (",
                                           conditionMessage(e), ")"), verbose = args$verbose)
                    })
                }
            }
        } else {
            if (args$verbose) .log_message(paste0("No existing ImprintomeSet found at: ", imprintome_rds), verbose = args$verbose)

            # Phase 2: Load and validate input
            if (args$verbose) .log_message("Phase 2: loading input data", verbose = args$verbose)
            input_list <- .load_input_data(
                beta_file = args$`beta-file`,
                meta_file = args$`meta-file`,
                rds_file = args$rds,
                verbose = args$verbose
            )
            input_data <- input_list$data
            input_source <- input_list$source
            platform <- input_list$platform

            if (args$verbose) .log_message("Phase 2b: preparing QC-clean input", verbose = args$verbose)
            input_data <- .prepare_qcset_for_analysis(input_data, verbose = args$verbose)

            if (args$verbose) {
                .log_message(paste0("Input source: ", input_source), verbose = args$verbose)
                .log_message(paste0("  Platform: ", platform), verbose = args$verbose)
                if (is(input_data, "MethQcSet")) {
                    .log_message(paste0("  Samples: ", ncol(beta(input_data))), verbose = args$verbose)
                } else if (is.list(input_data) && "beta" %in% names(input_data)) {
                    .log_message(paste0("  Samples: ", ncol(input_data$beta)), verbose = args$verbose)
                }
            }

            # Phase 3: Convert to ImprintomeSet (with EPICv2 aggregation if needed)
            if (args$verbose) .log_message("Phase 3: converting to ImprintomeSet", verbose = args$verbose)
            imp_set <- .convert_to_imprintomeset(
                input_data,
                probeset = args$probeset,
                platform = platform,
                genome = args$genome,
                verbose = args$verbose
            )

            # Phase 4: Run analysis
            if (args$verbose) .log_message("Phase 4: running imprintome analysis", verbose = args$verbose)
            imp_set <- .run_core_analysis(
                imp_set,
                probeset = args$probeset,
                ids_cutoff = args$`ids-cutoff`,
                verbose = args$verbose
            )

            # Phase 5: Summarize results
            if (args$verbose) {
                .log_message("Summarizing ImprintomeSet...", verbose = args$verbose)
                tryCatch({
                    summary_result <- summarize(imp_set)
                    if (!is.null(summary_result)) {
                        .log_message(paste0("   Summary complete: ",
                                          nrow(summary_result$results), " analysis records"), verbose = args$verbose)
                    }
                }, error = function(e) {
                    .log_message(paste0("  Note: summarize() not available (",
                                       conditionMessage(e), ")"), verbose = args$verbose)
                })
            }
        }
        # Phase 6: Generate plots and export
        if (args$verbose) .log_message("Phase 6: preparing plots", verbose = args$verbose)
        plot_types <- .parse_plot_types(args$`plot-types`, args$`skip-plots`)
        if (isTRUE(args$`radar-all`)) {
            plot_types <- .plot_types_without_single_radar(plot_types)
        }

        # Generate individual plots if requested
        if (isTRUE(args$beeswarm_chr_all)) {
            plot_types <- .plot_types_without_single_beeswarm_chr(plot_types)
        }
        if (length(plot_types) > 0 && !args$`skip-plots`) {
            imp_set <- .generate_imprintome_plots(imp_set, plot_types, args$probeset, args$outdir, prefix = cache_prefix, verbose = args$verbose)
        }

        # --radar-all is explicit and independent of the ordinary --skip-plots workflow.
        if (isTRUE(args$`radar-all`)) {
            .generate_all_radar_plots(
                imp_set, args$probeset, args$outdir, cache_prefix, verbose = args$verbose
            )
        }


        # --beeswarm-chr-all is explicit and independent of --skip-plots.
        if (isTRUE(args$beeswarm_chr_all)) {
            .generate_all_beeswarm_chr_plots(
                imp_set, args$probeset, args$outdir, cache_prefix, verbose = args$verbose
            )
        }
        # Phase 7: Export only the requested result and update the shared cache when needed.
        if (args$verbose) .log_message("Phase 7: exporting requested analysis", verbose = args$verbose)
        .export_requested_analysis(
            imp_set, args$outdir, args$probeset, cache_prefix,
            imprintome_rds, save_rds = !loaded_existing, verbose = args$verbose
        )
        # Phase 8: Completion summary
        elapsed_time <- difftime(Sys.time(), start_time, units = "secs")

        if (args$verbose) {
            .log_message("=== Pipeline Complete ===", verbose = args$verbose)
            .log_message(paste0("Elapsed time: ", round(elapsed_time, 1), " seconds"), verbose = args$verbose)
            .log_message(paste0("Output directory: ", args$outdir), verbose = args$verbose)
            .log_message(paste0("Log file: ", log_file), verbose = args$verbose)
        }

        cat("SUCCESS: Analysis completed.\n")
        cat("Output directory:", args$outdir, "\n")

        quit("no", status = 0)

    }, error = function(e) {
        .log_message(paste0("FATAL ERROR: ", conditionMessage(e)), level = "ERROR")
        cat("\nERROR:", conditionMessage(e), "\n")
        quit("no", status = 1)
    }, finally = {
        if (!interactive()) {
            sink()  # Close log file
        }
    })
}

# Execute main pipeline
main()
