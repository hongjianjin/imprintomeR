# Accessors for ImprintomeSet

Bioconductor-style accessors for reading and updating `ImprintomeSet`
slots.

## Usage

``` r
# S4 method for class 'ImprintomeSet'
beta(x)

# S4 method for class 'ImprintomeSet'
beta(x) <- value

# S4 method for class 'ImprintomeSet'
meta(x)

# S4 method for class 'ImprintomeSet'
meta(x) <- value

probeset(x)

# S4 method for class 'ImprintomeSet'
probeset(x)

probeset(x) <- value

# S4 method for class 'ImprintomeSet'
probeset(x) <- value

genome(x)

# S4 method for class 'ImprintomeSet'
genome(x)

genome(x) <- value

# S4 method for class 'ImprintomeSet'
genome(x) <- value

assay(x)

# S4 method for class 'ImprintomeSet'
assay(x)

assay(x) <- value

# S4 method for class 'ImprintomeSet'
assay(x) <- value

results(x)

# S4 method for class 'ImprintomeSet'
results(x)

results(x) <- value

# S4 method for class 'ImprintomeSet'
results(x) <- value

plots(x)

# S4 method for class 'ImprintomeSet'
plots(x)

plots(x) <- value

# S4 method for class 'ImprintomeSet'
plots(x) <- value
```

## Arguments

- x:

  An `ImprintomeSet` object.

- value:

  Replacement value for a slot.

## Value

Getter methods return the requested slot value. Replacement methods
return an updated `ImprintomeSet` object.
