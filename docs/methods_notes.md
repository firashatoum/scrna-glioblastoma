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

## STARsolo vs CellRanger
- STARsolo produces identical results to CellRanger
- STARsolo is open source, no license required
- STARsolo is faster and more memory efficient
- CellRanger is the 10x official tool but requires registration
- For reproducible open science STARsolo is the correct choice
