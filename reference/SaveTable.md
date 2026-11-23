# Save a Table to an Excel Workbook

Writes a data frame-like object to an `.xlsx` sheet using `openxlsx`.

## Usage

``` r
SaveTable(
  dat,
  sheetName = NULL,
  file = NULL,
  append = FALSE,
  colNames = T,
  rowNames = T,
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

- autoColWidth:

  Logical; auto-fit column widths.

## Value

Invisible side-effect function; writes workbook to disk.
