# ImprintomeSet S4 Class

Formal container for imprintomeR inputs and derived outputs.

## Slots

- `beta`:

  Matrix or data.frame of beta values (rows = probes, columns =
  samples).

- `meta`:

  data.frame of sample metadata. Must include `Sample_Name` and
  `Sample_Group` columns.

- `probeset`:

  data.frame or list containing probeset annotation.

- `genome`:

  Character scalar indicating genome build.

- `assay`:

  Character scalar indicating array assay.

- `results`:

  Named list of derived result tables/objects.

- `plots`:

  Named list of generated plots.
