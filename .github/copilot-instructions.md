# Copilot Instructions for imprintomeR

This repository is an R package for genomic imprinting analysis from EPIC methylation arrays.

## Priorities
1. Preserve scientific correctness.
2. Do not change formulas silently.
3. Prefer small composable functions.
4. Add roxygen2 docs to exported functions.
5. Add testthat tests for scoring logic.
6. Keep plotting functions separate from scoring functions.
7. Preserve maternal vs paternal origin-aware analysis.

## Core definitions
- IDS = sqrt((paternal_median - 0.5)^2 + (maternal_median - 0.5)^2)
- IDI = (beta - 0.5) * 2
- Angle is computed from paternal and maternal deviations relative to 0.5
- Use median aggregation by default for ICR summaries

## Coding style
- Write idiomatic R
- Use roxygen2
- Prefer explicit return values
- Avoid deeply nested code
- Do not introduce new dependencies without justification

## Package structure
- R/: exported and internal functions
- tests/testthat/: unit tests
- man/: generated docs
- vignettes/: workflow docs

## When editing code
- preserve backward compatibility where practical
- refactor giant functions into helpers
- add or update tests when changing scoring logic