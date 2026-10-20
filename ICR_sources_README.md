# ICR Annotation Sources

## Legacy hg19 probeset format before updates

Before the Jima annotation and chromosome-label updates, `inst/extdata/probesets_hg19.rds` contained these panels and schemas:

| Panel | Rows | Original columns | `ORIGIN` available |
|---|---:|---|---|
| `Jima` | 1,492 | `NAME`, `CHR`, `MAPINFO`, `Closest_TSS_gene_name`, `Distance_closest_TSS`, `Arm` | No |
| `Joshi` | 1,101 | `NAME`, `CHR`, `MAPINFO`, `Closest_TSS_gene_name`, `Distance_closest_TSS`, `Arm` | No |
| `Court` | 1,027 | `NAME`, `CHR`, `MAPINFO`, `Closest_TSS_gene_name`, `ORIGIN`, `region` | Yes |
| `Rosenski` | 1,050 | `NAME`, `CHR`, `MAPINFO`, `Closest_TSS_gene_name`, `region` | No |
| `selected` | 606 | `NAME`, `CHR`, `MAPINFO`, `Closest_TSS_gene_name`, `ORIGIN`, `region`, `origin2`, `origin3`, `ORIGIN0` | Yes |
| `NanoImprint` | 325 | `NAME`, `CHR`, `MAPINFO`, `Closest_TSS_gene_name`, `Distance_closest_TSS`, `Arm` | No |
| `chr11p15` | 82 | `NAME`, `CHR`, `MAPINFO`, `Closest_TSS_gene_name`, `Distance_closest_TSS`, `Arm`, `GROUP`, `ORIGIN` | Yes |
| `Rosenski_region` | 72 | `CHR`, `start`, `end`, `Closest_TSS_gene_name`, `ORIGIN`, `NAME`, `MAPINFO`, `region`, `ICR_name`, `ICR_type`, `ORIGIN_rule`, `Feature_Type`, `Genome_Build` | Yes |
| `chr11p15_region` | 8 | `CHR`, `start`, `end`, `Closest_TSS_gene_name`, `ORIGIN`, `NAME`, `MAPINFO`, `region`, `ICR_name`, `ICR_type`, `ORIGIN_rule`, `Feature_Type`, `Genome_Build` | Yes |

In particular, the original `Jima`, `Joshi`, `NanoImprint`, and `Rosenski` panels lacked parental-origin annotations and were not sufficient for origin-aware IDS/Angle scoring without additional curation. The updated Jima panel uses the common scoring-oriented schema `NAME`, `CHR`, `MAPINFO`, `Closest_TSS_gene_name`, `Distance_closest_TSS`, `ORIGIN`, and `region`.

### Legacy panels vs the submitted manuscript

The submitted manuscript and its supplementary tables were produced with the legacy panels above. For example, Supplementary Table S1 reports 606 CpGs across 45 ICRs for `selected`. Several of the current panels differ:

| Panel | Legacy (manuscript) | Current |
|---|---|---|
| `selected` | 606 probes, 45 ICRs | 782 probes, rebuilt from the four-panel merge list (see "Generated probe-name lists") |
| `Jima` | 1,492 probes, no `ORIGIN` | 1,833 probes (hg19), 848 maternal / 239 paternal / 746 unresolved |
| `Joshi` | 1,101 probes from `mmc3`, no `ORIGIN` | 844 probes from `mmc2`, 632 maternal / 212 paternal |
| `Rosenski` | 1,050 probes, no `ORIGIN` | 1,050 probes, 832 maternal / 183 paternal / 35 unresolved |

hg19 `NanoImprint` has the same 325 probes as hg38 and now also has `ORIGIN` (228 maternal / 97 paternal). Its hg19 coordinates were regenerated from the hg38 panel by reverse liftover; 45 chain-derived positions differ by two bases from the older bundled hg19 annotation. `Court`, `chr11p15`, `Rosenski_region`, and `chr11p15_region` are unchanged in content.

Results computed with the current panels, including all `selected`-based IDS/Angle values and confidence tiers, will **not** reproduce the numbers in the submitted manuscript. Rerun the affected analyses, and update the manuscript and supplementary tables, before the revision is submitted. Alternatively, archive the legacy panels under distinct names so that the published results remain reproducible.

## Purpose

This document records the source tables and probe-matching decisions used to construct imprintomeR ICR probesets. Illumina methylation-array beta matrices use probe identifiers such as `cg00000029`; genomic coordinates and ICR metadata are used to select and annotate those probes.

## Gametic vs secondary DMRs

Imprinted differentially methylated regions (DMRs) are classified by **when** their parent-specific methylation is established. The `ICR_type` column of `Rosenski_region` records this classification for each of the 72 curated DMRs.

### Gametic DMRs (germline DMRs, gDMRs)

- Methylation is established in the egg or the sperm, before fertilisation. Each gDMR is methylated in only one type of gamete.
- After fertilisation, these marks are protected from the genome-wide wave of demethylation. Every somatic cell therefore keeps one methylated allele, from the parent whose gamete set the mark, and one unmethylated allele. On an array this gives a beta value of about 0.5.
- **Oocyte gDMRs** are methylated on the maternal allele (`ORIGIN` = `maternal`). There are many, for example KCNQ1OT1, PEG3, MEST, PEG10, SNURF, and GNAS-AS1.
- **Sperm gDMRs** are methylated on the paternal allele (`ORIGIN` = `paternal`). Only about three are known in humans: H19/IGF2 IG-DMR, MEG3/DLK1 IG-DMR, and ZDBF2/GPR1 IG-DMR. `Rosenski_region` also types `IGF2:alt-TSS-DMR` as a sperm gDMR.
- These are the true **imprinting control regions (ICRs)**. Their methylation is the primary mark that decides which allele is expressed across an imprinted domain, and it is stable across tissues.

### Secondary DMRs (somatic DMRs)

- Methylation is **not** inherited from a gamete. It is acquired after fertilisation, during development, as a downstream consequence of a nearby gDMR. For example, the MEG3 promoter DMR becomes methylated on the paternal allele because the paternal MEG3/DLK1 IG-DMR was methylated in sperm. Other examples are GNAS-NESP (NESP55) and the MAGEL2 and NDN promoters.
- Secondary DMRs still show parent-of-origin methylation, but they are:
  - **dependent**: a readout of the gDMR rather than its cause;
  - **less stable**: methylation can vary between tissues, with age, and with cell composition, and may not sit near 0.5.

### Other `ICR_type` values

- `none`: parent-of-origin methylation without evidence linking it to either gamete, so it is neither gametic nor secondary.
- `Oocyte gDMR- secondary DMR` (`MKRN3:TSS-DMR` only): a mixed classification. It is treated as ambiguous rather than gametic.

### Why the distinction matters for IDS/Angle scoring

- A gDMR deviating from 0.5 is direct evidence of an imprinting defect: loss of the gametic mark, uniparental disomy (UPD), or a genome-wide androgenetic or parthenogenetic state.
- A secondary DMR deviating from 0.5 may reflect the tissue rather than an imprinting defect. For example, normal adrenal (GSE131350) and skeletal-muscle (GSE167059) controls score as altered with panels that include secondary DMRs.
- A purely paternal methylome, such as sperm, should be highly methylated at sperm gDMRs. Secondary DMRs are not methylated in sperm, because they form only after fertilisation. Sperm samples (GSE52576) are classified as "Global-Hypo" with the current panels because most of those panels' "paternal" probes lie in secondary DMRs.
- Because so few sperm gDMRs exist, and the array barely covers MEG3/DLK1 IG-DMR and does not cover ZDBF2/GPR1 IG-DMR, a gametic-only paternal class is almost entirely 11p15.5 H19/IGF2. In hg19, 51 of the 60 sperm-gDMR `cg` probes present on both 450K and EPIC are at H19/IGF2 IG-DMR, and the other 9 are at `IGF2:alt-TSS-DMR`. With a gametic-only panel, an H19/IGF2 gain or loss of methylation would therefore shift the sample-level paternal axis.

### Composition of the current hg19 panels

Each probe was classified by its hg19 `MAPINFO` falling inside an hg19 `Rosenski_region` interval, using `Rosenski_region$ICR_type` (rechecked 2026-10-20 after the MEG8:Int2-DMR correction). This table therefore inherits `ICR_type`'s gaps relative to Monk 2018: see "Source of the gametic/secondary classification". For `selected`, the Monk-based `DMR_type` counts are in "`DMR_type` annotation of `selected`". "Outside" means the probe is not in any of the 72 curated Rosenski DMRs; it does not mean the probe is not imprinted.

| Panel | Probes | Maternal: gametic / secondary / `none` / outside | Paternal: gametic / secondary / `none` / outside | Unresolved `ORIGIN` |
|---|---:|---|---|---:|
| `selected` | 782 | 424 / 26 / 126 / 79 | 49 / 68 / 8 / 2 | 0 |
| `Court` | 1,027 | 429 / 30 / 134 / 273 | 56 / 80 / 15 / 10 | 0 |
| `Rosenski` | 1,050 | 492 / 36 / 304 / 0 | 71 / 97 / 15 / 0 | 35 |
| `NanoImprint` | 325 | 174 / 5 / 39 / 10 | 43 / 54 / 0 / 0 | 0 |
| `Jima` | 1,833 | 413 / 23 / 68 / 344 | 14 / 0 / 4 / 221 | 746 |
| `Joshi` | 844 | 315 / 23 / 119 / 175 | 9 / 68 / 8 / 127 | 0 |

The "secondary" column includes the mixed `MKRN3:TSS-DMR` probes.

Observations:

- Every panel mixes gametic and secondary DMRs. In `selected`, `Court`, `Rosenski`, and `NanoImprint`, secondary DMRs (MEG3 TSS, NESP55, ZNF597, MAGEL2) make up most of the paternal class; only 35-44% of paternal probes are in sperm gDMRs.
- In `Jima` and `Joshi`, most paternal probes lie outside the curated DMRs. These are discovery-stage candidate regions without gametic confirmation. Only 6% (Jima) and 4% (Joshi) of their paternal probes are in gDMRs.
- The 9 Joshi paternal probes inside gDMRs cannot be in sperm gDMRs, because Joshi has no H19/IGF2 or IGF2 probes. They therefore lie in oocyte (maternal) gDMRs, and Joshi's `paternal` label conflicts with Rosenski's `maternal` annotation for these probes. These conflicts have not yet been resolved or recorded in an audit file.
- Filtering `Jima` or `Joshi` to gDMRs would leave only 14 or 9 paternal probes, and Joshi's 9 are the conflicting ones. A gametic-only analysis is therefore better served by a single panel built from the gDMR intervals and the probe-level array annotation than by gametic subsets of each existing panel.

### Source of the gametic/secondary classification

- Rosenski et al. 2025 Data S2 (`tmp_ICR_sources/Rosenski_2025/41467_2025_57433_MOESM4_ESM.xlsx`, sheet "S2") provides only DMR names and boundaries (`chrom`, `start`, `end`, `ICR name`, and the original ICR start and end). It provides **no** parental origin and **no** gametic/secondary type.
- `ICR_type` and `ORIGIN` in `Rosenski_region` were therefore curated in this project. `ORIGIN_rule` records the evidence behind each `ORIGIN` (Monk 2018, Court 2014, Hiura 2010, an atlas overlap, or Rosenski 2025). No equivalent per-region evidence column exists for `ICR_type`.
- Cite Rosenski 2025 for the DMR boundaries only, not for the classification.
- Reference hierarchy for gametic vs secondary status:
  1. **Monk et al. 2018**, *Epigenetics* 13:117 (`tmp_ICR_sources/Monk_2018/`). Table 1 of the paper lists 50 imprinted DMRs with hg19 extent, CpG count, parental origin of methylation, and a "Germline derived" column: 37 oocyte or sperm gDMRs, 11 secondary ("No-secondary DMR"), and 2 mixed (`MKRN3:TSS-DMR`, `ZDBF2/GPR1:IG-DMR`). The supplementary tables (450K probes per DMR, DMR intervals in hg19/hg38, MS-MLPA sites) do not repeat the classification. Table 1 is transcribed to `tmp_ICR_sources/Monk_2018/Table1_germline_status.tsv`; all 50 rows were checked programmatically against the PDF text (coordinates, CpG count, origin, and germline column).
  2. **Sanchez-Delgado et al. 2016**, *PLoS Genet* 12:e1006427 (`tmp_ICR_sources/Monk_2016/`, files `pgen.1006427.*`). Its S1 Table gives oocyte (`OO`) and sperm (`SP`) methylation per maternal gDMR, alongside blastocyst, placenta, and 15 somatic tissues. Its S5 Table classifies named gDMRs as ubiquitous or placenta-specific. The oocyte and embryo methylomes come from JGAS00000000006 (Okae et al. 2014, *PLoS Genet* 10:e1004868), so Okae 2014 is cited as the gamete-data source but is not needed as a separate input.
  3. **`Rosenski_region$ICR_type`** (project curation), only for DMRs that Monk 2018 does not list.
  4. **Rosenski et al. 2025**: refined DMR boundaries only.
- Comparison of `Rosenski_region` with Monk 2018 Table 1, by coordinate overlap (2026-10-20):
  - 58 `Rosenski_region` rows overlap a Monk DMR. 55 carry the same name; Monk `SVOPL:alt-TSS-DMR` has no `Rosenski_region` counterpart.
  - **Name differences in Rosenski Data S2:** the two DIRAS3 DMR names are swapped (`DIRAS3:TSS-DMR` ↔ `DIRAS3:Ex2-DMR`). The interval Data S2 calls **`RTL1`** (original coordinates `chr14:101,370,741-101,371,419`) is exactly Monk's **`MEG8:Int2-DMR`**. Data S2's own `MEG8:Int2-DMR` row (`chr14:101,348,186-101,349,932`) does not overlap any Monk DMR; its `paternal` label and "Secondary DMR" type are unverified and were left unchanged. No current panel except `Rosenski` has probes in it.
  - **Classification differences:** `ICR_type` is "none" for 15 DMRs that Monk classifies: 13 oocyte gDMRs (PPIEL, NAP1L5, WDR27, HTR5A, ERLIN2, FANCC, INPP5F, RB1, MCTS2P, GNAS-XL, WRB, SNU13, and ZNF597:3'DMR), 2 secondary DMRs (GNAS A/B, SNRPN:Int1-DMR2), and the mixed ZDBF2/GPR1:IG-DMR. Monk's MEG8:Int2-DMR (Data S2 "RTL1") is also typed "none". `Rosenski_region$ICR_type` itself is left unchanged; `selected` takes its `DMR_type` from Monk.
  - Monk prints `SNRPN:Int1-DMR1` as `25,093,008-25,193,829` (about 100 kb for 44 CpGs, probably a typo). That interval contains `SNRPN:Int1-DMR2`, so overlaps resolve to the smaller (more specific) Monk DMR.

### MEG8:Int2-DMR origin correction (2026-10-20)

- Monk 2018 gives `MEG8:Int2-DMR` maternal methylation (secondary DMR). The matching Data S2 interval, named `RTL1`, was labelled `paternal` in `Rosenski_region` (`ORIGIN_rule` "atlas_overlap_suggested").
- `tmp_fix_meg8_origin.R` sets that row to `maternal` in hg19 and hg38 `Rosenski_region` (hg38 then stored in the since-removed `probesets_hg38_regions.rds`; now in `probesets_hg38.rds`), with `ORIGIN_rule` "Monk2018_Table1_coordinate_match:MEG8:Int2-DMR(maternal);DataS2_name:RTL1". It then relabels the three Rosenski probes in the interval (`cg06804177`, `cg03664700`, `cg26981637`) `maternal` in both builds, and NanoImprint `cg06804177` in both builds.
- The `Court` and `selected` panels already labelled `cg06804177` maternal.
- New counts: `Rosenski` 832 maternal / 183 paternal / 35 unresolved (both builds); `NanoImprint` 228 maternal / 97 paternal (both builds).
- `tmp_update_nanoprint_region.R` reproduces the corrected hg38 NanoImprint panel exactly from the corrected Rosenski panel.

### `DMR_type` annotation of `selected`

The hg19 `selected` panel has three additional columns. They are generated by `tmp_annotate_selected_dmr_type.R`; existing rows, columns, and `ORIGIN` are unchanged. The hg38 `selected` panel copies them by probe `NAME` (see "hg38 selected panel").

- **Assignment rule:**
  - A probe is assigned to the `Rosenski_region` interval containing it (hg19 `MAPINFO`), which defines the DMR boundaries.
  - That interval is matched to a Monk 2018 DMR by coordinate overlap, not by name.
  - Probes outside every `Rosenski_region` interval stay `uncurated`, even if they fall inside Monk's wider methyl-seq extent, because Rosenski's boundaries exclude sub-regions that are hyper- or hypomethylated in every tissue. The one exception is `SVOPL:alt-TSS-DMR`, which has no `Rosenski_region` counterpart; its probes are assigned by Monk's extent.
- `ICR_name`: the Monk 2018 DMR name when the probe's DMR is in Monk Table 1; otherwise the `Rosenski_region` name; `NA` for `uncurated` probes.
- `DMR_type`:

  | `DMR_type` | Rule | Maternal | Paternal |
  |---|---|---:|---:|
  | `gametic` | Monk "Oocyte gDMR" or "Sperm gDMR" | 505 | 49 |
  | `secondary` | Monk "No-secondary DMR" | 68 | 68 |
  | `ambiguous` | Monk "Oocyte gDMR-secondary DMR" (`MKRN3:TSS-DMR`) or "Sperm gDMR-secondary DMR" (`ZDBF2/GPR1:IG-DMR`) | 4 | 8 |
  | `unclassified` | not in Monk, and `ICR_type` "none" | 0 | 0 |
  | `uncurated` | outside all `Rosenski_region` intervals and not in `SVOPL:alt-TSS-DMR` | 78 | 2 |

  For DMRs not in Monk, `Rosenski_region$ICR_type` maps "Oocyte gDMR"/"Sperm gDMR" to `gametic`, "Secondary DMR" to `secondary`, "Oocyte gDMR- secondary DMR" to `ambiguous`, and "none" to `unclassified`. No `selected` probe currently needs this fallback.
- `DMR_type_source`: `Monk2018_Table1` (702 probes), `Rosenski_region ICR_type (imprintomeR curation)` (0 probes in `selected`), or `NA` for `uncurated` probes (80).

The script checks that every probe in a Monk DMR has the same `ORIGIN` as Monk's methylation origin for that DMR; there are no mismatches. The 49 gametic paternal probes are 48 at `H19/IGF2:IG-DMR` and 1 at `IGF2:alt-TSS-DMR`. The 505 gametic maternal probes cover 34 oocyte gDMRs; `MEST:alt-TSS-DMR` (60), `GNAS-AS1:TSS-DMR` (56), `PEG10:TSS-DMR` (54), `KCNQ1OT1:TSS-DMR` (37), and `PEG3:TSS-DMR` (36) account for 243 of them.

Compared with the earlier `ICR_type`-based annotation (424 / 49 gametic, 22 / 68 secondary), Monk adds:
- 81 gametic maternal probes: NAP1L5 15, RB1 13, MCTS2P 9, SNU13 8, ERLIN2 7, GNAS-XL 6, HTR5A 4, INPP5F 4, PPIEL 4, WRB 4, WDR27 3, ZNF597:3'DMR 2, FANCC 1, SVOPL 1;
- 46 secondary maternal probes: GNAS A/B and SNRPN:Int1-DMR2, plus `cg06804177` in MEG8:Int2-DMR;
- 8 ambiguous paternal probes (ZDBF2/GPR1:IG-DMR).

The DIRAS3 probes keep their gametic type but now carry Monk's DIRAS3 names, which are swapped relative to Data S2.

`AnalyzeImprintStatus()` and `runImprintome()` accept `dmr_type` to score only probes of the given `DMR_type` values. The default, `NULL`, scores all probes and reproduces the previous results; the output also gains the columns `dmr_type`, `n_paternal_probes`, and `n_maternal_probes`.

### `DMR_type` annotation of `chr11p15`

- The hg19 `chr11p15` panel carries the same three columns, generated by the same rule in `tmp_annotate_selected_dmr_type.R` (2026-10-20). Existing rows and columns, including `GROUP` and `ORIGIN`, are unchanged.
- All 82 probes are `gametic` with `DMR_type_source` `Monk2018_Table1`, at two ICRs:

  | `ICR_name` | Monk type | `ORIGIN` | `GROUP` | Probes |
  |---|---|---|---|---:|
  | `H19/IGF2:IG-DMR` (IC1) | Sperm gDMR | paternal | `H19` | 51 |
  | `KCNQ1OT1:TSS-DMR` (IC2) | Oocyte gDMR | maternal | `KCNQ1OT1` | 31 |

- `dmr_type = "gametic"` therefore gives the same IDS/Angle as no filter on `chr11p15`; the columns make a uniform `dmr_type` workflow possible across panels.
- The panel is already gametic-only and split by ICR: its paternal axis is IC1 alone and its maternal axis is IC2 alone. The 11p15 IDS/Angle therefore separates IC1 gain or loss of methylation (paternal axis), IC2 loss of methylation (maternal axis), and pUPD11 (both axes).
- The 11p15 secondary or unclassified regions in `chr11p15_region` (`IGF2:Ex9-DMR`, `KCNQ1`, `KCNQ1DN`, `CDKN1C`) have no probes in `chr11p15`.
- `chr11p15` exists only in hg19; there is no hg38 `chr11p15` probe panel. The region-level `chr11p15_region` exists in both builds (see "hg38 chr11p15_region panel").

## Jima 2022 source

Source file:

- `tmp_ICR_sources/Jima_2022.pdf`
- `tmp_ICR_sources/kepi_a_2091815_sm3324.docx`

The paper describes candidate imprint control regions identified from methylation and sequencing analyses. The DOCX contains the supplementary tables referenced by the paper.

### Supplementary Table S1

**Title:** Candidate imprint control regions meeting the criteria for an ICR.

S1 contains 1,488 candidate ICR rows with these fields:

- `ID`
- `Genomic Coordinates`
- `Parental Origin of Methylation`
- `Nearest Transcript`
- `Distance to Nearest Transcript`

This is the primary Jima source for imprintomeR because it provides genomic intervals, parental-origin annotations, and transcript context. The parental-origin values include:

- `M` and `M**`: maternal origin
- `P` and `P**`: paternal origin
- blank values: no parental-origin annotation
- `S`: unresolved/other classification; do not infer maternal or paternal origin

For scoring, `M`/`M**` are normalized to `maternal`, and `P`/`P**` are normalized to `paternal`. Blank and `S` values remain `NA` and must be flagged or excluded from origin-aware scoring.

S1 does not contain Illumina `cg...` probe IDs. Probe IDs must therefore be extracted by intersecting its genomic intervals with a probe-level array annotation.

### Supplementary Table S2

**Title:** Candidate ICRs predicted by Sciome, Inc.

S2 contains 1,142 genomic-coordinate entries, corresponding to 1,141 unique regions because one coordinate is duplicated. It provides candidate regions and transcript/distance context but does not provide the parental-origin annotation required for origin-aware IDS scoring.

S2 should therefore be treated as an auxiliary candidate-region or visualization source, not as the primary scoring panel.

### Main Table 1

The paper's main Table 1 is titled **Candidate ICRs with gametic origin of methylation**. It can be used as a stricter reference set when an analysis is intentionally limited to gametic-origin ICRs. It should not replace S1 for the complete candidate-ICR catalogue unless that narrower biological scope is explicit.

## Joshi 2016 source

Source files:

- `tmp_ICR_sources/Joshi_2016/Joshi_2016.pdf`
- `tmp_ICR_sources/Joshi_2016/mmc1.pdf`
- `tmp_ICR_sources/Joshi_2016/mmc2.xlsx`
- `tmp_ICR_sources/Joshi_2016/mmc3.xlsx`
- `tmp_ICR_sources/Joshi_2016/mmc4.xlsx`
- `tmp_ICR_sources/Joshi_2016/mmc5.xlsx`

Joshi et al. used the Illumina Infinium HumanMethylation450 BeadChip and reciprocal UPD samples to identify parent-of-origin methylation bias and candidate imprinted DMRs.

### Recommended supplementary table

Use `mmc2.xlsx`, **Supplementary Table 2**, sheet `FINALhg19`, as the current primary Joshi discovery panel for imprintomeR. It contains the 844 probe-level parent-of-origin methylation discoveries reported by the study:

- `Probe ID`
- `Chr`
- `Start_CpG, hg19`
- `End_CpG, hg19`
- probe type and strand
- RefSeq promoter/gene annotations
- `Maternally methyated`
- `Paternally methylated`

Recommended mapping:

```text
Probe ID                    -> NAME
Chr                         -> CHR
Start_CpG, hg19             -> MAPINFO
Closest Refseq gene         -> Closest_TSS_gene_name
```

The maternal and paternal methylation columns are numeric boolean flags: value `1` means `TRUE`, while `NA` means no flag. Joshi `ORIGIN` is therefore derived strictly as `maternal` when `Maternally methyated == 1` and `Paternally methylated` is not `1`, or `paternal` when `Paternally methylated == 1` and `Maternally methyated` is not `1`. Probes with both flags or neither flag remain unresolved. The flags should not be converted to parental-origin labels merely because a probe has a nonzero or non-missing value under a different encoding.

The current `Joshi` panel uses this S2 discovery set directly: 632 maternal probes and 212 paternal probes, with hg19 regions represented as `chr:start-end`.

The previous 1,101-probe Joshi panel was derived from `mmc3.xlsx`, Supplementary Table 3, sheet `Galaxy12-(Join_two_Datasets_on_...)`; all 1,101 legacy probe IDs occur there. `mmc3` is therefore retained as the provenance source for the superseded broad panel, while `mmc2` is the source for the current origin-aware 844-probe discovery panel. `mmc4.xlsx` and `mmc5.xlsx` provide other analyses and are not the preferred source for the current core Joshi panel.

### Reference genome

Joshi 2016 uses **hg19 / GRCh37** for the WGBS alignment and the 450K probe coordinate annotations. The Joshi panel should therefore be treated as an hg19 panel unless its probe coordinates are regenerated against a verified hg38 annotation or lifted over with an auditable chain file.

The stable matching key is the Illumina probe `Probe ID`/`NAME` (`cg...`); chromosome and coordinate fields are build-specific metadata.

### Main scientific deliverables

Joshi 2016 reported 77 autosomal parent-of-origin methylation regions based on reciprocal UPD methylation profiles, including 34 previously unreported regions. The analysis identified 844 probes passing the study's discovery criteria, with 60 regions showing maternal methylation bias and 17 showing paternal bias. The paper also reported extended parent-of-origin bias across the PWS/AS domain, subtle rather than uniformly hemi-methylated parental differences, and rare individuals with broad shifts across multiple imprinted DMRs in a population cohort.

For imprintomeR provenance, the 844-probe discovery set is represented by the current `Joshi` panel. The former 1,101-probe `Joshi` panel represented a broader `mmc3`-derived candidate set and should not be conflated with the paper's 844-probe discovery deliverable.

## Court 2014 source

Source file:

- `tmp_ICR_sources/Court_2014/Court_2014.pdf`

Court et al. combined whole-genome bisulfite sequencing with the Illumina Infinium HumanMethylation450 BeadChip and reciprocal genome-wide UPD samples to identify parent-of-origin methylation regions.

### Recommended supplementary table

Use the paper's **Main Table 1** as the primary Court source for the default imprintomeR core panel. It is explicitly titled "Location of parent-of-origin methylation identified in this study" and provides the most focused set of regions with reported parent-of-origin methylation.

Use **Supplemental Table S1** as an extended/discovery source. It is broader than the core set and contains 145 non-overlapping 450K-derived regions, whereas the existing Court panel contains 67 curated regions. The current Court panel has 1,027 probes, compared with the broader S1 region catalogue, and only 761 of those probes fall inside the S1 145-region intervals. Thus, the current panel is not an exact extraction of S1.

Use **Supplemental Table S2** only as an auxiliary panel for additional locus-specific or reciprocal-imprinting findings, not as the primary all-region scoring panel.

### Why Main Table 1 is the default

The existing Court panel is consistent with representative Main Table 1 regions, including PPIEL, H19, WDR27, HTR5A, GNAS, and ZNF331. Its 67-region structure and explicit maternal/paternal labels are therefore better suited to a focused, interpretable IDS/Angle scoring panel.

By contrast, Supplemental Table S1 is a broader catalogue derived from multiple WGBS and 450K analyses. Its 145-region sheet is useful for discovery, sensitivity analysis, and expanded visualization, but using it as the default would change panel scope and could introduce regions that are not equivalent to the curated Main Table 1 set.

Accordingly, imprintomeR treats the existing panel as a curated **Court core** panel based primarily on the Main Table 1 evidence, while S1 should support a separately named **Court extended** panel if it is added later. The current Court panel should not be described as an exact row-for-row extraction of Supplemental Table S1.

The existing Court panel in `inst/extdata/probesets_hg19.rds` is compatible with origin-aware imprintomeR scoring:

- 1,027 unique Illumina `cg...` probes
- columns: `NAME`, `CHR`, `MAPINFO`, `Closest_TSS_gene_name`, `ORIGIN`, `region`
- 866 maternal probes
- 161 paternal probes

### Reference genome

The Court paper explicitly uses the **hg19 reference genome** for the methylation-array coordinate workflow and for UCSC Browser coordinate checks. Therefore, the Court panel is treated as an hg19 panel. It should not be labeled hg38 unless the probe coordinates are regenerated from a verified hg38 annotation or lifted over with an auditable mapping.

The stable matching key remains the Illumina probe `NAME` (`cg...`); genomic coordinates are build-specific metadata.

## Probe-level array annotation

Source file:

- `inst/extdata/anno.uniq_harmonized.liftover.rds`

This is a probe-level annotation table with 1,082,418 unique `NAME` values, including 1,079,262 `cg...` identifiers. It provides both builds:

- `CHR_HG19`, `MAPINFO_HG19`
- `CHR_HG38`, `MAPINFO_HG38`

The hg38 coordinates are used to select probes overlapping S1 intervals. Chromosome values are normalized to the `chrN` form before interval joins.

### hg19 annotation repair for Court probes

The 37 Court probes with invalid source hg38 coordinates (`chr0:0`) were repaired in `anno.uniq_harmonized.liftover.rds` by probe `NAME`:

- 36 coordinates were taken from `IlluminaHumanMethylation450kanno.ilmn12.hg19`.
- One probe not represented in the installed manifest name tables was retained using its validated existing hg19 Court-panel coordinate.
- The repaired fields are `CHR_HG19`, `MAPINFO_HG19`, and `STRAND_HG19`.
- The complete before/after record is stored in `tmp_ICR_sources/anno_hg19_manifest_repair.tsv`.

The hg19 manifest repairs provide the source coordinates for a subsequent hg19-to-hg38 liftover. The 37 former `chr0:0` rows had all three hg38 fields updated: `CHR_HG38`, `MAPINFO_HG38`, and `STRAND_HG38`. They were uniquely lifted to hg38 with the UCSC `hg19ToHg38.over.chain.gz` chain; the liftover audit is stored in `tmp_ICR_sources/Court_hg38_liftover_repair.tsv`.

## Generated probeset assets

### hg19

- `inst/extdata/probesets_hg19.rds`
- Existing legacy panels include `Jima`, `Court`, `selected`, `chr11p15`, and region-oriented panels.
- The updated `Rosenski` panel retains 1,050 probe rows and adds `ORIGIN` from the exact matching `Rosenski_region` metadata. It contains 832 maternal, 183 paternal, and 35 unresolved region annotations (after the 2026-10-20 MEG8:Int2-DMR correction; see "MEG8:Int2-DMR origin correction").
- `Distance_closest_TSS` is intentionally not included because the available Rosenski region and harmonized probe sources do not provide TSS coordinates from which a defensible distance can be calculated.
- The Rosenski hg19 probe panel matches the 72-region Rosenski 2025 Data S2 catalogue through 68 distinct probe-region labels; the separate `Rosenski_region` panel matches all 72 Data S2 regions exactly.
- In hg38, `Rosenski_region` remains the authoritative 72-region Data S2 representation. The probe-expanded `Rosenski` panel contains 1,050 probes across 84 probe-derived spans; 68 of the 72 region-level loci have a unique overlapping probe span, while four regions have no overlapping mapped array probes: ZDBF2/GPR1:IG-DMR, FAM50B:TSS-DMR, WDR27:Int13-DMR, and IGF2:Ex9-DMR.
- The current `Joshi` panel contains the 844-probe parent-of-origin discovery set from `mmc2.xlsx`, `FINALhg19`, with columns `NAME`, `CHR`, `MAPINFO`, `Closest_TSS_gene_name`, `ORIGIN`, and `region`.
- It contains 632 maternal and 212 paternal probes; `ORIGIN` is derived from the numeric flag rule `1 = TRUE`.
- The superseded 1,101-probe panel was derived from `mmc3.xlsx`, Supplementary Table 3; its relationship to the current S2 panel is recorded in `tmp_ICR_sources/Joshi_mmc2_replacement_audit.tsv`.
- The hg19 `Jima` panel is synchronized to the hg38 Jima probe names and contains 1,833 `cg...` probes with origin-aware annotations.
- Two hg38 Jima probes were excluded because `anno.uniq_harmonized.liftover.rds` has no hg19 coordinate for them.
- Eight malformed source chromosome labels were corrected: `chr23` to `chr22` and `chr24` to `chr18`. The details are recorded in `tmp_ICR_sources/Jima_hg19_chromosome_correction.tsv`.
- The hg19 `NanoImprint` panel keeps the legacy columns `NAME`, `CHR`, `MAPINFO`, `Closest_TSS_gene_name`, `Distance_closest_TSS`, and `Arm`, and adds `ORIGIN`. `ORIGIN` is transferred from the hg38 `NanoImprint` panel by exact Illumina probe `NAME` matching: all 325 probes match one-to-one, giving 228 maternal and 97 paternal labels. The hg19 coordinates are regenerated from hg38 with `rtracklayer::liftOver` and the official UCSC `tmp_ICR_sources/hg38ToHg19.over.chain.gz` chain. The hg38 provenance of the labels, including the 10 nearest-gene labels, is described under "hg38 NanoImprint panel" below. The transfer is implemented in `tmp_update_nanoprint_hg19_origin.R`; coordinate conversion is implemented in `liftover_nanoprint_hg38_to_hg19.R` and validated by `validate_nanoprint_liftover.R`.
- hg19 `NanoImprint` has no `region`, `region_T2T`, or `ICR_name` columns. The NanoImprint authors provide region files only for hg38 and T2T-CHM13, not hg19.

The hg19 correction order was:

1. Join by probe `NAME` to a trusted hg19 manifest when available.
2. Otherwise use a verified hg38-to-hg19 liftOver result.
3. Correct malformed source chromosome labels `chr23` to `chr22` and `chr24` to `chr18` for the affected probes.
4. Keep only unique, validated hg19 mappings; retain unresolved probes in hg38 and report them rather than inventing hg19 coordinates.

### hg38 panels

- `inst/extdata/probesets_hg38.rds`
- Contains the probe-level `Jima`, `Joshi`, `NanoImprint`, `Rosenski`, `selected`, and `Court` panels described below, and the region-level `Rosenski_region` panel (the 72 Data S2 DMRs in hg38 coordinates) and `chr11p15_region` panel, mirroring `probesets_hg19.rds`.
- `Rosenski_region` was previously stored on its own in `inst/extdata/probesets_hg38_regions.rds`. It was moved into `probesets_hg38.rds` unchanged on 2026-10-20, and the separate file was removed.

### hg38 chr11p15_region panel

- In hg19, `chr11p15_region` is exactly the eight 11p15.5 rows of `Rosenski_region`, identical in every column.
- The hg38 `chr11p15_region` (2026-10-20) takes the corresponding eight rows of hg38 `Rosenski_region`, which lists the same 72 DMRs in the same order. It keeps the hg19 columns.
  - `ICR_name`, `ICR_type`, `ORIGIN`, `ORIGIN_rule`, `Closest_TSS_gene_name`, and `Feature_Type` are unchanged.
  - `start`, `end`, `NAME`, `MAPINFO`, and `region` are hg38, and `Genome_Build` is `hg38`.
  - Interval widths are unchanged.
- Cross-check: each hg19 `start` and `end` lifts through the UCSC `hg19ToHg38` chain exactly to the hg38 `start` and `end`.
- Regions: `H19/IGF2:IG-DMR` (two intervals), `IGF2:Ex9-DMR`, `IGF2:alt-TSS-DMR`, `KCNQ1`, `KCNQ1OT1:TSS-DMR`, `KCNQ1DN`, `CDKN1C`. `ICR_type` is the project-curated `Rosenski_region` value; there is no `DMR_type` column on the region-level panels.
- Generated by `tmp_build_chr11p15_region_hg38.R`. Rerun it after any change to `Rosenski_region` in either build.

### hg38 Jima panel

The hg38 `Jima` panel is generated from Jima S1 intervals and `anno.uniq_harmonized.liftover.rds`. It has these columns:

```text
NAME
CHR
MAPINFO
Closest_TSS_gene_name
Distance_closest_TSS
ORIGIN
region
```

It contains 1,835 unique `cg...` probes:

- 848 maternal
- 239 paternal
- 748 with missing/unresolved parental origin retained as `NA`

Each probe was selected when its hg38 `CHR` and `MAPINFO` fell within exactly one S1 genomic interval. No ambiguous interval matches were retained.

The synchronized hg19 `Jima` panel uses the same S1-derived probe annotations and the corresponding hg19 coordinates. Its `region` values are hg19 spans of the mapped probes within each source interval; liftover cases that split across chromosomes are represented as chromosome-specific spans.

### hg38 NanoImprint panel

- `inst/extdata/probesets_hg38.rds` contains a 325-probe `NanoImprint` panel created by stable Illumina `NAME` matching from the hg19 panel to `anno.uniq_harmonized.liftover.rds`.
- The panel has the columns `NAME`, `CHR`, `MAPINFO`, `Closest_TSS_gene_name`, `ORIGIN`, `region`, `region_T2T`, and `ICR_name`.
- All 325 probes have valid hg38 coordinates.
- The original NanoImprint source panel did not provide parental-origin annotation. In the generated hg38 asset, `ORIGIN` is transferred by exact Illumina probe `NAME` matching from the curated Rosenski probe panel.
- This supplies 315 labels (218 maternal and 97 paternal). The remaining 10 probes are not in the Rosenski probe panel and were labelled `maternal` by a nearest-gene rule on `Closest_TSS_gene_name` (`MAGEL2` and `GNAS`). This is an inference from genomic proximity, not a transfer from a curated source. The generated panel therefore contains 228 maternal and 97 paternal labels (after the 2026-10-20 MEG8:Int2-DMR correction, which relabelled `cg06804177` maternal). The Figure 1 region labels were not used to assign origin.
- Check of the 10 nearest-gene labels against hg38 `Rosenski_region` intervals:
  - The 9 `GNAS` probes (`chr20:58,852,501-58,852,775`) lie between the two maternally methylated `GNAS-AS1:TSS-DMR` oocyte gDMR intervals (`58,849,382-58,852,482` and `58,852,887-58,852,978`) and away from the paternally methylated `GNAS-NESP:TSS-DMR` (`58,838,984-58,843,778`). `maternal` is consistent with the flanking DMR.
  - The `MAGEL2` probe `cg22872376` (`chr15:23,648,595`) lies about 0.7 kb downstream of `MAGEL2:TSS-DMR` (`23,647,008-23,647,929`), which Rosenski annotates as a maternally methylated secondary DMR. `MAGEL2` is paternally *expressed*, but `ORIGIN` records the parental allele that is *methylated*, so the probe is labelled `maternal`. Earlier versions of the panel labelled it `paternal` (226 maternal / 99 paternal); that label was corrected on 2026-10-20.
- Region source: the NanoImprint paper (Figure 1) prints region coordinates on T2T-CHM13v2.0 only. The authors' repository (`github.com/carolinehey/NanoImprint`, `main` branch, commit `e7309833715ebc905ac015dc92193762d390811a`) provides the regions of interest in both builds, as `regions_hg38.bed` and `regions_T2T.bed`. Copies are stored in `tmp_ICR_sources/NanoImprint_2024/`.
  - Both files list the same 15 DMRs in the same row order and carry no names. `ICR_name` follows the paper's Figure 1 nomenclature in that row order.
  - The files contain one DMR that is not in Figure 1: `MEG3/DLK1:IG-DMR` (hg38 `chr14:100809335-100811397`, T2T `chr14:95043978-95046609`). Its name is inferred from its location.
  - The hg38 intervals are the authors' own, not exact liftovers of the T2T intervals: 4 of the 15 are the same length in both builds, and the other 11 are shorter in hg38. The repository README notes that hg38 mapping of `H19/IGF2:IG-DMR` is incomplete.
- `region` holds the hg38 interval and `region_T2T` the corresponding T2T-CHM13v2.0 interval, both as `chr:start-end` strings. `region` is in the same build as `CHR`/`MAPINFO` and as `region` in the other hg38 panels.
- Each probe is assigned to its region by coordinate overlap: its hg38 `MAPINFO` must fall inside exactly one hg38 interval. All 325 probes do, so no probe is unassigned or ambiguous.
- Probe counts per DMR:

  | `ICR_name` | Probes |
  |---|---:|
  | `PLAGL1:alt-TSS-DMR` | 12 |
  | `GRB10:alt-TSS-DMR` | 2 |
  | `MEST:alt-TSS-DMR` | 43 |
  | `H19/IGF2:IG-DMR` | 43 |
  | `KCNQ1OT1:TSS-DMR` | 25 |
  | `MEG3/DLK1:IG-DMR` | 0 |
  | `MEG3:TSS-DMR` | 32 |
  | `MEG8:Int2-DMR` | 1 |
  | `MAGEL2:TSS-DMR` | 6 |
  | `SNURF:TSS-DMR` | 6 |
  | `PEG3:TSS-DMR` | 34 |
  | `GNAS-NESP:TSS-DMR` | 22 |
  | `GNAS-AS1:TSS-DMR` | 61 |
  | `GNASXL:Ex1-DMR` | 5 |
  | `GNAS A/B:TSS-DMR` | 33 |

  The 325 probes cover 14 of the 15 DMRs, including all 14 in Figure 1. The germline `MEG3/DLK1:IG-DMR` has no probe in this panel.
- Correction on 2026-10-20: regions were previously assigned from `Closest_TSS_gene_name` and hand-set GNAS breakpoints. That put 5 probes in the `GNASXL:Ex1-DMR` interval (`cg07284407`, `cg21625881`, `cg14203179`, `cg09437522`, `cg10468484`; hg38 58,854,803-58,856,248) under `GNAS-AS1:TSS-DMR`, and left `GNASXL:Ex1-DMR` with no probes. Coordinate overlap moves these 5 probes to `GNASXL:Ex1-DMR`. Every other probe keeps its previous region. Both DMRs are maternally methylated, so `ORIGIN` is unaffected.
- The 10 probes with nearest-gene `ORIGIN` labels also fall inside the matching NanoImprint hg38 intervals: the 9 `GNAS` probes in `GNAS-AS1:TSS-DMR` and `cg22872376` in `MAGEL2:TSS-DMR`.
- The reproducible update is implemented in `tmp_update_nanoprint_region.R`. It checks that both BED files have 15 rows with matching chromosomes and that every probe falls in exactly one hg38 interval. After saving the RDS, it checks the coordinate format of `region` and `region_T2T`, that no `ICR_name` is missing, and the 228/97 origin counts.

### hg38 Rosenski panel

- `inst/extdata/probesets_hg38.rds` contains the 1,050-probe `Rosenski` panel derived from the hg19 Rosenski panel by stable Illumina `NAME` matching in `anno.uniq_harmonized.liftover.rds`.
- The panel retains `NAME`, `CHR`, `MAPINFO`, `Closest_TSS_gene_name`, `region`, and `ORIGIN`.
- Origin counts are 832 maternal, 183 paternal, and 35 unresolved (after the 2026-10-20 MEG8:Int2-DMR correction).
- Five invalid source hg38 coordinates were uniquely repaired by hg19-to-hg38 UCSC liftover; the audit is in `tmp_ICR_sources/Rosenski_hg38_liftover_repair.tsv`.
- The hg38 panel contains all 1,050 Rosenski probes after repair, with hg38 `CHR`/`MAPINFO` values taken from the harmonized annotation and hg38 `region` spans rebuilt from the mapped probes.

### hg38 Joshi panel

- `inst/extdata/probesets_hg38.rds` contains the 844-probe `Joshi` discovery panel from `mmc2.xlsx`, `FINALhg19`.
- All 844 Joshi probe IDs have hg38 coordinates in `anno.uniq_harmonized.liftover.rds`.
- The panel retains `NAME`, `CHR`, `MAPINFO`, `Closest_TSS_gene_name`, `ORIGIN`, and `region`.
- Origin counts remain 632 maternal and 212 paternal.
- `region` values are rebuilt as hg38 spans of probes within each hg19 S2 source interval grouping.

### hg38 Court panel

- `inst/extdata/probesets_hg38.rds` also contains a probe-level `Court` panel derived from the existing hg19 Court panel by matching stable Illumina `NAME` values to `anno.uniq_harmonized.liftover.rds`.
- The panel retains the columns `NAME`, `CHR`, `MAPINFO`, `Closest_TSS_gene_name`, `ORIGIN`, and `region`.
- 1,027 hg19 Court probes were evaluated and all 1,027 now have valid hg38 coordinates.
- The 37 former `chr0:0` rows were repaired by unique UCSC hg19-to-hg38 liftover.
- The nonstandard source label for `cg10943497` was resolved by the same liftover workflow; the repair is recorded in `tmp_ICR_sources/Court_hg38_liftover_repair.tsv`.

### hg38 selected panel

- `inst/extdata/probesets_hg38.rds` contains a 782-probe `selected` panel built from hg19 `selected` by stable Illumina `NAME` matching (2026-10-20).
- Columns are the same as hg19: `NAME`, `CHR`, `MAPINFO`, `Closest_TSS_gene_name`, `ORIGIN`, `region`, `ICR_name`, `DMR_type`, and `DMR_type_source`.
- `CHR`/`MAPINFO` are the hg38 fields (`CHR_HG38`, `MAPINFO_HG38`) of `anno.uniq_harmonized.liftover.rds`.
  - All 782 probes have valid hg38 coordinates.
  - Every probe's annotation-file hg19 position equals its hg19 `selected` position.
  - No probe changes chromosome between builds.
- `Closest_TSS_gene_name`, `ORIGIN`, `ICR_name`, `DMR_type`, and `DMR_type_source` are copied unchanged by `NAME`; they describe the DMR, not the genome build. The `DMR_type` counts therefore equal hg19's: gametic 505 maternal / 49 paternal, secondary 68 / 68, ambiguous 4 / 8, uncurated 78 / 2.
- `region` is the hg38 span (minimum to maximum `MAPINFO`) of the probes sharing each hg19 `region`, as for the hg38 Court panel. The 130 hg19 regions map one-to-one to 130 hg38 spans.
  - hg19 `region` values are interval strings carried over from the source panels.
  - hg38 `region` values are probe spans, so they can be narrower than the source DMR.
- Consistency check: every probe with an `ICR_name`, except the Monk-only `SVOPL:alt-TSS-DMR` probe, lies inside an interval of hg38 `Rosenski_region` (in `probesets_hg38.rds`), and no `uncurated` probe does.
- The panel is generated by `tmp_build_selected_hg38.R`. Rerun it after any change to hg19 `selected`, including `tmp_annotate_selected_dmr_type.R`.

### Gene-label normalization

The original S1 transcript field can contain multiple names separated by `|`. Both Jima panels now use one label per probe. Labels are selected using a curated canonical imprint-gene list and explicit locus overrides, including:

- `KCNQ1|KCNQ1OT1` -> `KCNQ1`
- `TRAPPC9|PEG13` -> `PEG13`
- `MEST|MESTIT1` -> `MEST`
- `BLCAP|NNAT` -> `NNAT`
- `PLAGL1|HYMAI` -> `PLAGL1`
- `ZIM2|PEG3|MIMT1` -> `PEG3`
- `HM13|MCTS2P` -> `MCTS2P`
- `MRPL23|H19` -> `H19`

When no recognized canonical imprint gene is present, the first transcript is retained as a nearest-transcript fallback. These fallback labels are not asserted to be imprinted genes. The complete before/after audit is stored in `tmp_ICR_sources/Jima_gene_label_audit.tsv`.

## Recommended use in imprintomeR

For origin-aware scoring:

1. Use `selected`, the `runImprintome()` default, in either build. It requires a probe to appear in at least two source panels and on both 450K and EPIC arrays, and every probe has a resolved `ORIGIN`. The hg38 panel carries the same probes and annotation as hg19 (see "hg38 selected panel").
2. For single-source comparisons, prefer panels whose `ORIGIN` is fully resolved:
   - `Court` (both builds)
   - `Joshi` (both builds)
   - `NanoImprint` (both builds; 10 of its labels come from a nearest-gene rule, see above)
3. `Jima` and `Rosenski` can be scored, but only probes with a maternal or paternal `ORIGIN` contribute. In Jima, 41% of probes (746 in hg19, 748 in hg38) are unresolved, and S1 is a broad candidate-ICR catalogue rather than a curated set of gametic ICRs. Use Jima for discovery and sensitivity analyses, not as the default scoring panel.
4. None of the current panels is restricted to gametic ICRs: each mixes gametic ICRs with secondary DMRs. For `selected` (hg19 and hg38), use the `DMR_type` column (see "`DMR_type` annotation of `selected`"):
   - `dmr_type = "gametic"` for core scoring, e.g. `runImprintome(x, probeset = "selected", dmr_type = "gametic")`;
   - `dmr_type = "secondary"` to report secondary DMRs separately.

   The gametic paternal class is essentially 11p15.5 H19/IGF2, so report its probe count (`n_paternal_probes`) alongside the scores. Other panels have no `DMR_type` column yet; `dmr_type` filtering on them stops with an error.
5. Require both maternal and paternal annotations to be present in the matched beta matrix; the scoring functions stop with an error otherwise.
6. Track the number of matched probes (`n_maternal_probes`, `n_paternal_probes` in the `AnalyzeImprintStatus()` output) and the number of probes with missing `ORIGIN`.
7. Treat angle and IDS as exploratory summaries of bulk array beta values, not definitive parent-of-origin calls.

Visualization-only (not origin-aware): Jima S2 candidate regions.

For region-level visualization or exploratory coverage:

- Use `Rosenski_region` from `probesets_hg19.rds` or `probesets_hg38.rds`.
- S2 may be used as an auxiliary candidate-region catalogue, but it should not silently supply parental-origin labels.

## Generated probe-name lists

The four-panel probe lists are generated from the build-specific probe-set assets using the `NAME` column as the stable Illumina probe identifier. For each genome build, the following files contain one unique probe name per line:

- `Jima_hg19.txt`, `Joshi_hg19.txt`, `Court_hg19.txt`, `Rosenski_hg19.txt`
- `Jima_hg38.txt`, `Joshi_hg38.txt`, `Court_hg38.txt`, `Rosenski_hg38.txt`

They are generated by `generate_overlap4.R` from `probesets_hg19.rds` and `probesets_hg38.rds`. The script validates that every panel contains a non-missing, unique `NAME` column and preserves the source panel order. The hg19 and hg38 lists are generated independently; they are not created by converting coordinates between builds.

The merge list `tmp_ICR_sources/probes/2026-10-19.mergeList_4_hg19.txt` is assembled from the same four hg19 `NAME` lists. Each row records membership in `Rosenski`, `Joshi`, `Jima`, and `Court`, followed by `count`, the number of panels containing the probe. The `ASSAY` column is added by exact matching of `Symbol` to `NAME` in `inst/extdata/anno.uniq_harmonized.liftover.rds`; all merge-list symbols must match a unique annotation record.

The selected merge list `tmp_ICR_sources/probes/2026-10-19.mergeList_4_hg19_selected.txt` is produced by `subset_merge_list_4_hg19.R` and retains rows satisfying both conditions:

```text
count >= 2
ASSAY contains "450K,EPIC"
```

This includes assay values such as `450K,EPICV10b5`, `450K,EPICV10b5,EPICV2`, and `450K,EPICV2`. The current selected file contains 782 rows. The filter preserves all original columns and row values, including `ASSAY`.

The hg19 `selected` panel in `probesets_hg19.rds` is recreated from the 782 selected merge-list `NAME` values by `recreate_selected_hg19.R`. Existing `selected` annotations are retained first. Missing values are then filled by exact `NAME` matching in this order: Court, Jima, Joshi, and Rosenski. The harmonized annotation supplies hg19 coordinates and fallback gene labels where needed; missing regions are represented by probe-coordinate intervals. The resulting panel has the columns `NAME`, `CHR`, `MAPINFO`, `Closest_TSS_gene_name`, `ORIGIN`, and `region`, with no missing gene labels, coordinates, regions, or origins.

The hg19 NanoImprint probe coordinates are regenerated from the hg38 NanoImprint panel with `rtracklayer::liftOver` and the official UCSC `tmp_ICR_sources/hg38ToHg19.over.chain.gz` chain. The reverse liftover produced one unique hg19 mapping for all 325 probes. The chain-derived coordinates are retained as authoritative for this conversion; 45 probes differ by two bases from the older bundled hg19 annotation, and this discrepancy is checked but not silently overridden.

## Reproducibility notes

The generated hg38 Jima panel is derived by interval overlap, not by assuming that S1 row IDs are Illumina probe IDs. S1 IDs such as `ICR_1` are region identifiers. The `cg...` names come from the harmonized probe annotation, while transcript, distance, origin, and region fields come from the matched S1 interval.

Any future regeneration should verify:

- unique probe `NAME` values;
- complete hg38 coordinate availability;
- one-to-one interval assignment;
- explicit counts of maternal, paternal, and unresolved probes;
- exact output columns and stable panel names;
- numeric chromosome and `MAPINFO` ordering in both Jima panels;
- compatibility with `AnalyzeImprintStatus(..., genome = "hg38")`.
