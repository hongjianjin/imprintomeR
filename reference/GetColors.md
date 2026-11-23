# Colour Palettes

Colour Palettes

## Usage

``` r
GetColors(palette = "Default", n = 10)
```

## Arguments

- palette:

  Palette name: `"default"` (the package's standard colours), `"seurat"`
  (ggplot2 hue colours), or a viridis palette (`"viridis"`, `"plasma"`,
  `"magma"`, `"inferno"`, `"rocket"`, `"cividis"`, `"kako"` for mako,
  `"turbo"`). Case is ignored.

- n:

  Number of colours (default 10).

## Value

Character vector of `n` colours, or `NULL` for an unknown palette.
