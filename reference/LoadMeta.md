# Load and Standardize Metadata Table

Accepts either a metadata data frame or path to a tab-delimited metadata
file. Validates required columns (case-insensitive) and normalizes them
to canonical form.

## Usage

``` r
LoadMeta(input)
```

## Arguments

- input:

  Data frame or file path (tab-delimited with header).

## Value

Standardized metadata data frame with `Sample_Name` row names. Columns
are normalized to canonical form.

## Details

**Required columns (case-insensitive input; normalized to canonical
form):**

- `Sample_Name` - Unique sample identifier (normalized from ID,
  SAMPLE_NAME, sample_name, etc.)

- `Sample_Group` - Sample grouping/stratification (normalized from
  GROUP, SAMPLE_GROUP, sample_group, etc.)

**Column normalization behavior:** User may provide columns in any case
(e.g., `sample_name`, `SAMPLE_NAME`, `Sample_Name`). LoadMeta()
automatically normalizes to the canonical mixed-case form: `Sample_Name`
and `Sample_Group`. Preserves case of other columns.
