# Load a Table from XLSX or Tab-Delimited Text

Load a Table from XLSX or Tab-Delimited Text

## Usage

``` r
LoadTable(
  xlsxFile = xlsxFile,
  sheet = 1,
  skipEmptyRows = FALSE,
  colNames = TRUE,
  rowNames = FALSE,
  startRow = 1
)
```

## Arguments

- xlsxFile:

  Input file path (`.xlsx` or text table).

- sheet:

  Sheet index/name for Excel input.

- skipEmptyRows:

  Passed to
  [`openxlsx::read.xlsx`](https://rdrr.io/pkg/openxlsx/man/read.xlsx.html).

- colNames:

  Logical; table has column names.

- rowNames:

  Logical; treat first column as row names for Excel mode.

- startRow:

  First row to read for Excel mode.

## Value

A data frame.
