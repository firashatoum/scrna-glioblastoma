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
