# Data Files for imprintomeR

This directory contains documentation and scripts for preparing the large data files required by imprintomeR.

## Files

- **download_data.R** - Documentation and scripts for preparing/downloading data files

## Required Data Files

The imprintomeR package requires two large annotation files:

1. **anno.uniq_harmonized.liftover.rds** (52 MB)
   - CpG probe annotations from Illumina EPIC/HM450K arrays
   - Contains genomic coordinates (hg19 liftover)
   
2. **probesets_hg19.rds** (256 KB)
   - ICR (Imprinted Gene Region) probeset definitions
   - Contains chromosome, origin (maternal/paternal), and gene annotations

## Setup

These files are managed separately from the main repository to keep it lean. When you install imprintomeR:

1. **Automatic** (recommended):
   ```r
   library(imprintomeR)
   setup_imprintome_data()  # Downloads files if missing
   ```

2. **Manual**:
   - See `download_data.R` for instructions on where to download files
   - Files should be placed in `inst/extdata/`

## Note for Developers

If preparing files for a new GitHub release:

1. Prepare files using the function in `download_data.R`
2. Upload to GitHub Releases
3. Update URLs in `R/zzz.R` 

See `download_data.R` for detailed instructions.
