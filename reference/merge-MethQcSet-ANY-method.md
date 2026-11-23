# Merge Multiple MethQcSet Objects

Combine multiple `MethQcSet` objects from the same platform with
synchronized metadata and beta matrix alignment.

## Usage

``` r
# S4 method for class 'MethQcSet,ANY'
merge(x, y, how = "inner", ...)
```

## Arguments

- x:

  A `MethQcSet` object.

- y:

  A `MethQcSet` object or list of `MethQcSet` objects.

- how:

  Character, join type for beta matrices: "inner" (default), "outer",
  "left", or "right".

- ...:

  Additional arguments (reserved for future use).

## Value

A single `MethQcSet` object with:

- Metadata merged by rows and reordered to match beta sample order

- Beta matrices joined by probe `TargetID` (rownames)

- Metadata reordered to match final beta sample order

- Detection p-values aligned if present in all inputs

- QC tables merged where applicable

## Details

**Merge Contract (Synchronized Operation):**

1.  Validates all inputs are same platform

2.  Requires unique Sample_Name values across inputs

3.  Merges metadata: stack by rows and preserve beta sample order

4.  Merges beta matrices: join by TargetID (rownames), concat by sample
    columns

5.  Merges detection p-values: same method as beta (if present)

6.  Reorders metadata to match final beta column order

7.  Concatenates QC tables, filtering to samples in final object

This ensures metadata, beta, and detection p-values remain synchronized
(no hidden sample drift).
