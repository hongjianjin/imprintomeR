# Accessors for MethQcSet

Bioconductor-style accessors for reading and updating `MethQcSet` slots.

## Usage

``` r
meta(x)

# S4 method for class 'MethQcSet'
meta(x)

meta(x) <- value

# S4 method for class 'MethQcSet'
meta(x) <- value

platform(x)

# S4 method for class 'MethQcSet'
platform(x)

platform(x) <- value

# S4 method for class 'MethQcSet'
platform(x) <- value

beta(x)

# S4 method for class 'MethQcSet'
beta(x)

beta(x) <- value

# S4 method for class 'MethQcSet'
beta(x) <- value

detection_pval(x)

# S4 method for class 'MethQcSet'
detection_pval(x)

detection_pval(x) <- value

# S4 method for class 'MethQcSet'
detection_pval(x) <- value

qc_tables(x)

# S4 method for class 'MethQcSet'
qc_tables(x)

qc_tables(x) <- value

# S4 method for class 'MethQcSet'
qc_tables(x) <- value

aggregation_status(x)

# S4 method for class 'MethQcSet'
aggregation_status(x)

aggregation_status(x) <- value

# S4 method for class 'MethQcSet'
aggregation_status(x) <- value

qc_params(x)

# S4 method for class 'MethQcSet'
qc_params(x)

qc_params(x) <- value

# S4 method for class 'MethQcSet'
qc_params(x) <- value

statistics(x)

# S4 method for class 'MethQcSet'
statistics(x)

statistics(x) <- value

# S4 method for class 'MethQcSet'
statistics(x) <- value
```

## Arguments

- x:

  A `MethQcSet` object.

- value:

  Replacement value for a slot.

## Value

Getter methods return the requested slot value. Replacement methods
return an updated `MethQcSet` object.
