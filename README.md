# scRNA-seq Analysis of Glioblastoma Tumor Microenvironment

## Overview
Full single-cell RNA-seq analysis pipeline for GSE182109 — a 10x Genomics dataset
of 44 glioblastoma samples spanning newly diagnosed (ndGBM), recurrent (rGBM),
and low-grade glioma (LGG) patients.

**Biological questions:**
1. How does immune cell composition differ between newly diagnosed and recurrent GBM?
2. Which immune cell populations are associated with patient survival when projected onto TCGA bulk RNA-seq?


---

## Project Structure

### Two-Dataset Strategy

This project uses two datasets with clearly separate roles:

| Role | Dataset | Format | Used for |
|------|---------|--------|----------|
| Pipeline validation | 10x PBMC 3k | Raw FASTQ | Validating bash scripts end to end |
| Biological analysis | GSE182109 GBM | Published count matrix | All Seurat and TCGA analysis |

**Why two datasets?**

GSE182109 is available in SRA as pre-aligned BAM files rather than raw FASTQs,
which prevents reprocessing with alignment-based tools such as STARsolo.

To ensure full validation of the preprocessing pipeline, a standard 10x Genomics
PBMC dataset (raw FASTQs) is used for end-to-end testing of download, QC,
alignment, and quantification steps.

All downstream biological analyses are performed on the published GSE182109
count matrix, which is the appropriate and standard approach when only
preprocessed data are available.

---

## Pipeline Overview

All steps are modular, parameterized, and designed for reproducibility
and future orchestration via Nextflow.

### Stage 1 — Bash Preprocessing Pipeline
Validated on 10x PBMC 1k v3. Generic and works on any standard 10x FASTQ deposit.
```text
01_download.sh  →  02_qc.sh  →  03_build_index.sh  →  04_align.sh  →  99_cleanup.sh
prefetch +         FastQC +      STAR genome           STARsolo          remove
fasterq-dump       MultiQC       index (run once)      align + count     intermediates
```

### Stage 2 — Seurat Analysis
Run on GSE182109 published count matrix.
```text
01_qc_filtering.R → 02_normalization.R → 03_dimreduction.R → 04_clustering.R
→ 05_annotation.R → 06_deg_analysis.R → 07_trajectory.R
```

### Stage 3 — TCGA Bulk Integration
TCGAbiolinks download → deconvolution → survival analysis
```text
08_bulk_integration.R
```

### Stage 4 — Nextflow
Wrapping the bash pipeline for full reproducibility.
> **Note on Nextflow:** A generalizable Nextflow wrapper for this pipeline 
> is maintained as a separate repository: `nextflow-scrna-pipeline` (coming soon).
> The bash and R scripts in this repo are designed to be fully modular and 
> reusable as Nextflow process modules.

---

## Datasets

### GSE182109 — Biological Analysis
- **GEO**: [GSE182109](https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE182109)
- **Paper**: A glioma immune cell atlas identifies prognostic macrophage signatures
  and a novel immunotherapy target, S100A4
- **Samples**: 44 total — ndGBM (newly diagnosed), rGBM (recurrent), LGG
- **Technology**: 10x Genomics, Illumina HiSeq 4000 + DNBSEQ-G400
- **Data used**: Published count matrix (GSE182109_RAW.tar, 2.3GB MTX format)

### 10x PBMC 1k v3 — Pipeline Validation
- **Source**: [10x Genomics public datasets](https://www.10xgenomics.com)
- **Cells**: ~1000 PBMCs from healthy donor
- **Chemistry**: 10x Chromium v3 (2019, modern paired-end)
- **Size**: ~5GB
- **Data used**: Raw paired-end FASTQs, direct download from 10x servers
- **Note**: 01_download.sh demonstrates the SRA download path for 
  general use. PBMC 1k FASTQs downloaded directly via wget for 
  pipeline validation efficiency.
---

## Repository Structure
```text
scrna-glioblastoma/
├── config/
│   ├── sample_sheet.tsv         # GSE182109 — 44 samples
│   └── make_sample_sheet.py     # sample sheet generation script
├── pipeline/
│   ├── 01_download.sh           # SRA download - prefetch + fasterq-dump
│   ├── 02_qc.sh                 # FastQC + MultiQC
│   ├── 03_build_index.sh        # STAR genome index (run once)
│   ├── 04_align.sh              # STARsolo alignment + quantification
│   └── 99_cleanup.sh            # remove intermediate files
├── analysis/
│   ├── 01_qc_filtering.R        # Seurat QC and filtering
│   ├── 02_normalization.R       # normalization and scaling
│   ├── 03_dimreduction.R        # PCA and UMAP
│   ├── 04_clustering.R          # Louvain clustering
│   ├── 05_annotation.R          # cell type annotation
│   ├── 06_deg_analysis.R        # differential expression
│   ├── 07_trajectory.R          # pseudotime analysis
│   ├── 08_bulk_integration.R    # TCGA deconvolution + survival
│   └── functions/               # reusable R functions
├── environment/
│   └── scrna_env.yml            # conda environment (pinned versions)
├── results/
│   ├── qc/                      # FastQC and MultiQC reports
│   ├── figures/                 # all plots from R analysis
│   └── tables/                  # all output tables from R analysis
├── data/                        # gitignored
│   ├── raw/                     # FASTQs
│   └── processed/               # count matrices
└── docs/
    └── methods_notes.md         # parameter justifications
```

---

## Quick Start
```bash
# 1. Clone the repo
git clone https://github.com/YOUR_USERNAME/scrna-glioblastoma.git
cd scrna-glioblastoma

# 2. Create conda environment
conda env create -f environment/scrna_env.yml
conda activate scrna-env

# 3. Download PBMC 1k test FASTQs (pipeline validation)
mkdir -p data/raw/PBMC_1k
wget -P data/raw/PBMC_1k \
    https://cf.10xgenomics.com/samples/cell-exp/3.0.0/pbmc_1k_v3/pbmc_1k_v3_fastqs.tar
tar -xf data/raw/PBMC_1k/pbmc_1k_v3_fastqs.tar -C data/raw/PBMC_1k/

# 4. Run QC
bash pipeline/02_qc.sh data/raw/PBMC_1k/pbmc_1k_v3_fastqs/ results/qc/PBMC_1k/

# 5. Build STAR genome index (run once, ~45 minutes)
bash pipeline/03_build_index.sh data/reference/ hg38

# 6. Align and quantify
bash pipeline/04_align.sh data/raw/PBMC_1k/pbmc_1k_v3_fastqs/ data/reference/hg38/ data/processed/PBMC_1k/

# 7. R analysis (GSE182109 published matrix)
# Download GSE182109_RAW.tar from GEO and place in data/processed/
# Then run analysis scripts in order
Rscript analysis/01_qc_filtering.R
```

---

## Requirements
- Linux or WSL2 (Ubuntu 22.04 recommended)
- conda/mamba
- ~35GB storage per sample during FASTQ processing
- 32GB RAM for Seurat analysis

---

## Author
Firas Hatoum — MSc Molecular and Cell Biology