# Save a Table to Excel with Conditional Formatting

Writes a data frame to an `.xlsx` sheet and applies conditional
formatting based on pass/fail rules defined in a format specification
data frame.

## Usage

``` r
SaveTableStyle(
  dat,
  sheetName = NULL,
  file = NULL,
  append = FALSE,
  colNames = T,
  rowNames = T,
  condFmt = NULL,
  autoColWidth = TRUE
)
```

## Arguments

- dat:

  Data frame or matrix to write.

- sheetName:

  Optional worksheet name. Defaults to `"sheet1"`.

- file:

  Output workbook path.

- append:

  Logical; append/update existing workbook when `TRUE`.

- colNames:

  Logical; write column names.

- rowNames:

  Logical; write row names.

- condFmt:

  Optional data frame with conditional formatting rules. Must contain
  columns:

  - `Control`: column name in `dat`

  - `Threshold`: threshold value (used for "Final.QC" / "QC" fields)

  - `Pass`: expression or substring matching for pass condition (e.g.,
    `">95"`)

  - `Fail`: expression or substring matching for fail condition (e.g.,
    `"<=95"`)

- autoColWidth:

  Logical; auto-fit column widths.

## Value

Invisible side-effect function; writes workbook to disk.
