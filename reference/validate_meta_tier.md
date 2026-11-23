# Validate Metadata Against Tier Requirements

Checks if metadata data.frame conforms to specified tier requirements:

- **Tier A:** Sample_Name + Sample_Group + Basename (QC-ready for
  runMethQC)

- **Tier B:** Sample_Name + Sample_Group (analysis-ready for
  ImprintomeSet)

- **Tier C:** Sample_Name only (minimal; allows auto_group=TRUE)

## Usage

``` r
validate_meta_tier(meta, tier = "B", verbose = TRUE)
```

## Arguments

- meta:

  data.frame containing sample metadata

- tier:

  Character scalar: one of "A", "B", or "C" (default: "B")

- verbose:

  Logical. If TRUE, print detailed validation messages (default: TRUE)

## Value

Logical: TRUE if meta satisfies tier requirements, FALSE otherwise. If
verbose=TRUE, prints detailed status; returns invisibly.

## Examples

``` r
# Tier B (standard)
meta_b <- data.frame(
  Sample_Name = c("S1", "S2"),
  Sample_Group = c("case", "control")
)
validate_meta_tier(meta_b, tier = "B")
#> [validate_meta_tier] Tier B (Analysis-ready (Sample_Name + Sample_Group)): PASS
#>   Samples: 2

# Tier C (minimal, allows auto_group)
meta_c <- data.frame(Sample_Name = c("S1", "S2"))
validate_meta_tier(meta_c, tier = "C")
#> [validate_meta_tier] Tier C (Minimal (Sample_Name only)): PASS
#>   Samples: 2
```
