# Methods Notes
Parameter decisions and justifications will be documented here as analysis progresses.

## QC Notes — PBMC 1k v3 Pipeline Validation

### FastQC Results
- Per base sequence quality: yellow in some positions — acceptable for scRNA-seq
- Sequence duplication: high (yellow/red) — EXPECTED for scRNA-seq data
  UMI-based deduplication is handled by STARsolo during alignment, not pre-alignment

### Why we do not trim
- 10x Genomics libraries are clean — no adapter contamination detected
- Trimming R1 would destroy barcode/UMI sequences that STARsolo needs
- High duplication is biological, not technical — do not filter pre-alignment

### Conclusion
Data passes QC. Proceed directly to STARsolo alignment.

## Reference Genome Choice
- Assembly: GRCh38 (hg38) — current human reference
- Annotation: GENCODE v44 — comprehensive, well maintained
- Why GENCODE over Ensembl: GENCODE includes more non-coding annotations
  and is the standard for 10x Genomics pipelines
- data/reference/ — gitignored (genome index too large for git)

## STARsolo vs CellRanger
- STARsolo produces identical results to CellRanger
- STARsolo is open source, no license required
- STARsolo is faster and more memory efficient
- CellRanger is the 10x official tool but requires registration
- For reproducible open science STARsolo is the correct choice

## STARsolo Alignment Parameters

### Read order
- R2 (cDNA) passed first, R1 (barcodes) second — STARsolo convention
- Counterintuitive but required — do not swap

### Chemistry — 10x v3
- Cell barcode: positions 1-16 in R1 (16bp)
- UMI: positions 17-28 in R1 (12bp)
- For v2 chemistry: UMI is only 10bp, adjust --soloUMIlen accordingly

### Cell filtering
- EmptyDrops_CR used instead of simple UMI threshold
- Same algorithm as CellRanger — more accurate cell calling
- Distinguishes real cells from empty droplets statistically

### Output
- Coordinate-sorted BAM with cell barcode and UMI tags
- Gene-level count matrix in filtered/ directory
- filtered/ contains only called cells — use this for Seurat
- raw/ contains all barcodes including empty droplets

## scRNA-seq QC Filtering — GSE182109

### Dataset
- 44 samples: 26 ndGBM, 14 rGBM, 4 LGG
- Published count matrices from GEO (GSE182109_RAW.tar)
- MTX format, reorganized into per-sample directories for Seurat compatibility

### QC Metrics and Thresholds
Three standard metrics applied simultaneously:

**Minimum genes per cell: 200**
- Below this threshold = likely empty droplet capturing ambient RNA
- Empty droplets have near-zero transcriptional complexity

**Maximum genes per cell: 6000**
- Above this threshold = likely doublet (two cells in one droplet)
- Doublets appear as one cell with roughly double the gene count

**Minimum UMIs per cell: 500**
- Below this threshold = poor quality cell or empty droplet
- Complements gene filter — requires sufficient RNA capture depth

**Maximum mitochondrial percentage: 20%**
- Above this threshold = likely dead or damaged cell
- Dead cells lose cytoplasmic RNA through membrane leakage
- Mitochondrial RNA is retained longer due to membrane protection
- Mitochondrial genes identified by ^MT- prefix (GENCODE annotation)

### Results
- Total cells before filtering: 264,672
- Total cells after filtering: 242,107
- Cells removed: 22,565 (8.5%)
- Overall retention rate: 91.5% — indicates high quality dataset

### Per-Sample Observations

**ndGBM-10:** 11,190 cells retained, median genes 770, median UMIs 1,623.
Unusually high cell count but very low transcriptional complexity per cell.
Likely dominated by transcriptionally sparse immune cells (microglia or
infiltrating monocytes). Worth monitoring in clustering — may skew immune
cell proportions.

**ndGBM-11 (patient 11, fractions A-D):** Consistently low cell recovery
across all four fractions (377-2839 cells). Low mitochondrial percentage
(0.8-5.2%) confirms captured cells are healthy — dissociation yield was
simply poor, likely due to tumor fibrosis or small biopsy volume. All
fractions retained (above 200-cell exclusion threshold). Lower statistical
power for this patient in downstream per-patient analyses.

**rGBM-02-4:** Only 1,032 cells, while other fractions from patient 02
range from 2,286 to 10,866 cells. Fraction-specific dissociation failure
rather than patient-level issue. Retained for analysis.

**LGG samples:** Higher median mitochondrial percentage (7-14%) compared
to GBM samples (2-8%). May reflect IDH mutation-associated metabolic
alterations — IDH-mutant cells have altered mitochondrial function and
TCA cycle activity. Alternatively may reflect different cellular composition
with fewer immune infiltrates in LGG. To be investigated in clustering.

**rGBM samples:** Higher median UMIs and genes per cell compared to ndGBM
(rGBM-04 and rGBM-05 median UMIs 10,000-12,000 vs ndGBM median 2,000-6,000).
Suggests recurrent tumor cells are more transcriptionally active, possibly
reflecting clonal evolution under treatment pressure or enrichment of
metabolically active immune populations post-treatment.

### Decision
All 44 samples retained. Low-yield samples (ndGBM-11-A, ndGBM-11-B,
rGBM-02-4) documented but not excluded — cells that were captured passed
quality filters and contribute to population-level characterization.
