# Bundled probesets

[← Back to README](../README.md)

`probesets_hg19.rds` and `probesets_hg38.rds` contain the same eleven panels in the same order: the probe-level `Jima`, `Joshi`, `Court`, `Rosenski`, `selected` (782 probes, selected on 450K and EPICv1 and/or EPICv2: all 782 on 450K, 742 on EPICv1, 683 on EPICv2), `NanoImprint`, `chr11p15` and `chr20q13` (GNAS) panels, and the region-level `Rosenski_region`, `chr11p15_region` and `chr20q13_region` panels. Every probe-level panel carries parental-origin (`ORIGIN`) labels, an `ICR_name` and a `DMR_type` (gametic, secondary, ambiguous or uncurated) following Monk et al. (2018), and the Infinium design type of each probe. Probe coordinates come from `anno.uniq_harmonized.liftover.rds`, which merges the Illumina 450K, EPIC v1.0 B5 and EPICv2 manifests; its chromosome labels were checked against the UCSC hg19ToHg38 and hg38ToHg19 chains.

The `selected` panel is built from four source panels:

| Source panel | Probes (hg38) | Derived from |
|---|---:|---|
| `Court` (Court et al., 2014) | 1,027 | regions mapped to array probes by coordinate overlap in hg19 |
| `Jima` (Jima et al., 2022) | 1,835 | candidate ICRs (Supplementary Table S1) mapped by coordinate overlap in hg38 |
| `Joshi` (Joshi et al., 2016) | 844 | 450K probe identifiers reported by the study |
| `Rosenski` (Rosenski et al., 2025) | 1,050 | regions mapped by coordinate overlap in hg19 |

The source catalogues come from whole-genome bisulfite sequencing and/or 450K methylation profiling. Each panel was carried to the other genome build by probe identifier using `anno.uniq_harmonized.liftover.rds`. Probe membership is the same in hg19 and hg38, except two Jima probes without an hg19 coordinate. Together the four panels contain 2,724 distinct probes.

`selected` keeps the 868 probes present in at least two of the four panels and, of these, the 782 that are on the 450K array and on EPICv1 and/or EPICv2. The 86 excluded probes are 17 found only on 450K and 69 found only on EPICv1 and/or EPICv2. Selection is probe-based, so ICRs were not chosen individually. The submitted manuscript used earlier source panels (808 probes in at least two panels; 606 selected).

Platform coverage of the 782 `selected` probes, from the `ASSAY` column of `anno.uniq_harmonized.liftover.rds` (`EPICV10b5` is EPICv1, the EPIC v1.0 B5 manifest). Every probe is on 450K and on EPICv1, EPICv2 or both:

| `ASSAY` value | 450K | EPICv1 | EPICv2 | Probes |
|---|:---:|:---:|:---:|---:|
| `450K,EPICV10b5,EPICV2` | ✓ | ✓ | ✓ | 643 |
| `450K,EPICV10b5` | ✓ | ✓ | | 99 |
| `450K,EPICV2` | ✓ | | ✓ | 40 |
| **Probes on each array** | **782** | **742** | **683** | **782** |
