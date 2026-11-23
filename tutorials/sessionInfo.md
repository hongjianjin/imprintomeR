# Session information

The R session used to build and test imprintomeR 1.6.0 (2026-11-23), recorded with:

```r
library(imprintomeR)
sessionInfo()
```

```
R version 4.3.3 (2024-02-29 ucrt)
Platform: x86_64-w64-mingw32/x64 (64-bit)
Running under: Windows 11 x64 (build 26200)

Matrix products: default


locale:
[1] LC_COLLATE=English_United States.utf8 
[2] LC_CTYPE=English_United States.utf8   
[3] LC_MONETARY=English_United States.utf8
[4] LC_NUMERIC=C                          
[5] LC_TIME=English_United States.utf8    

time zone: America/Chicago
tzcode source: internal

attached base packages:
[1] stats     graphics  grDevices utils     datasets  methods   base     

other attached packages:
[1] imprintomeR_1.6.0

loaded via a namespace (and not attached):
 [1] generics_0.1.4        tidyr_1.3.1           shape_1.4.6.1        
 [4] stringi_1.8.4         digest_0.6.36         magrittr_2.0.3       
 [7] grid_4.3.3            RColorBrewer_1.1-3    iterators_1.0.14     
[10] circlize_0.4.18       foreach_1.5.2         doParallel_1.0.17    
[13] plyr_1.8.9            ggrepel_0.9.6         zip_2.3.2            
[16] GlobalOptions_0.1.4   ComplexHeatmap_2.18.0 purrr_1.0.2          
[19] scales_1.4.0          codetools_0.2-20      cli_3.6.3            
[22] rlang_1.1.4           crayon_1.5.3          ggbeeswarm_0.7.3     
[25] tools_4.3.3           parallel_4.3.3        reshape2_1.4.4       
[28] dplyr_1.1.4           colorspace_2.1-1      ggplot2_3.5.2        
[31] GetoptLong_1.0.5      BiocGenerics_0.48.1   vctrs_0.6.5          
[34] R6_2.6.1              png_0.1-8             matrixStats_1.5.0    
[37] stats4_4.3.3          lifecycle_1.0.5       stringr_1.6.0        
[40] S4Vectors_0.40.2      IRanges_2.36.0        vipor_0.4.7          
[43] clue_0.3-65           cluster_2.1.6         pkgconfig_2.0.3      
[46] beeswarm_0.4.0        pillar_1.11.1         openxlsx_4.2.8       
[49] gtable_0.3.6          data.table_1.17.0     glue_1.7.0           
[52] Rcpp_1.0.13           tibble_3.2.1          tidyselect_1.2.1     
[55] dichromat_2.0-1       farver_2.1.2          rjson_0.2.21         
[58] compiler_4.3.3       
```

## Declared dependencies

`sessionInfo()` lists only the packages loaded when imprintomeR is attached. Packages used by individual functions, such as `minfi` for QC, load on first use. The versions installed in the same session were:

| Imports | Version |
|---|---|
| ggplot2 | 3.5.2 |
| dplyr | 1.1.4 |
| tidyr | 1.3.1 |
| data.table | 1.17.0 |
| matrixStats | 1.5.0 |
| ComplexHeatmap | 2.18.0 |
| circlize | 0.4.18 |
| reshape2 | 1.4.4 |
| ggbeeswarm | 0.7.3 |
| ggrepel | 0.9.6 |
| openxlsx | 4.2.8 |
| stringr | 1.6.0 |
| viridisLite | 0.4.3 |
| patchwork | 1.3.0 |
| minfi | 1.48.0 |
| illuminaio | 0.44.0 |

| Suggests | Version |
|---|---|
| testthat | 3.2.1.1 |
| knitr | 1.48 |
| rmarkdown | 2.27 |
| bedr | not installed (optional) |
| BiocGenerics | 0.48.1 |
| cowplot | 1.1.3 |
| GenomeInfoDb | 1.38.8 |
| GenomicRanges | 1.54.1 |
| ggridges | 0.5.7 |
| gridBase | 0.4.7 |
| IRanges | 2.36.0 |
| minfiData | 0.48.0 |
| pheatmap | 1.0.13 |
| ragg | 1.3.2 |
| rtracklayer | 1.62.0 |
| Rtsne | 0.17 |
| S4Vectors | 0.40.2 |
| UpSetR | not installed (optional) |
| venn | 1.12 |

Base packages (`graphics`, `grDevices`, `grid`, `methods`, `stats`, `tools`, `utils`) are those of R 4.3.3.

The package is also checked on every change by GitHub Actions with the current R release on Linux, macOS and Windows (`R CMD check`, and a clean install that runs the README Quick start and `supplementary/Supplementary_Code.R`); the versions used there are in the workflow logs.
