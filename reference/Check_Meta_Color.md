# Assign or Validate Group Colours in Metadata

Adds a `COLOR` column with one standard colour per group when the
metadata has none. When `COLOR` holds category labels rather than
colours, they are moved to `COLORGROUP` and replaced by one colour per
category; when it holds colours, they must map one-to-one onto the
groups.

## Usage

``` r
Check_Meta_Color(meta, groupColumn = "Sample_Group")
```

## Arguments

- meta:

  Sample metadata data frame.

- groupColumn:

  Name of the grouping column (default `"Sample_Group"`;
  `"SAMPLE_GROUP"` is used when only that is present).

## Value

`meta` with a valid `COLOR` column (and `COLORGROUP` for category
labels).
