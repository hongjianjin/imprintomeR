# Flag Possible Mosaic Imprinting Disturbances

Classifies samples whose IDS is raised relative to a reference
distribution but below the alteration cutoff, as can happen with mosaic
defects, and estimates the altered fraction. Exploratory: the reference
mean and SD should come from tissue-matched controls.

## Usage

``` r
DetectMosaicism(res_table, roi_ref_mean = 0.06, roi_ref_sd = 0.03)
```

## Arguments

- res_table:

  Output of
  [`AnalyzeImprintStatus()`](https://hongjianjin.github.io/imprintomeR/reference/AnalyzeImprintStatus.md)
  (columns `IDS`, `consistency`, `paternal_median`, `maternal_median`).

- roi_ref_mean, roi_ref_sd:

  Mean and standard deviation of IDS in the reference (normal) samples
  (defaults 0.06 and 0.03).

## Value

`res_table` with added columns `IDS_Zscore`; `Is_Mosaic`
(`"Constitutive"` for IDS \>= 0.2; otherwise `"High-Confidence Mosaic"`
for z \> 3 or `"Possible Mosaic"` for z \> 2, both requiring consistency
\> 0.8; else `"Stable"`); and `Mosaic_Pct_Est`, the larger parental
deviation from 0.5 as a percentage of 0.5.
