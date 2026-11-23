# Summarize ImprintomeSet Contents

Returns a concise, deterministic summary of object slots and stored
outputs.

## Usage

``` r
# S4 method for class 'ANY'
summarize(object, ...)

# S4 method for class 'ImprintomeSet'
summarize(object, ...)
```

## Arguments

- object:

  An `ImprintomeSet` object. Any other object (for example a data frame
  or grouped tibble) is passed to
  [`dplyr::summarise()`](https://dplyr.tidyverse.org/reference/summarise.html),
  so `summarize()` keeps working in dplyr pipelines when imprintomeR is
  attached after dplyr.

- ...:

  Reserved for future extensions; for other objects, passed to
  [`dplyr::summarise()`](https://dplyr.tidyverse.org/reference/summarise.html).

## Value

For an `ImprintomeSet`, a list with `object`, `results`, and `plots`
summary tables; otherwise the result of
[`dplyr::summarise()`](https://dplyr.tidyverse.org/reference/summarise.html).

## Examples

``` r
if (FALSE) { # \dontrun{
s <- summarize(x)
s$object
s$results
} # }
```
