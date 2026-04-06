#!/usr/bin/env bash
# =============================================================================
# 04_align.sh
# Aligns scRNA-seq reads using STARsolo and generates count matrices.
# Works on any standard 10x Genomics paired-end FASTQ dataset.
#
# Usage: bash 04_align.sh <fastq_dir> <index_dir> <output_dir> <chemistry>
#
# Arguments:
#   fastq_dir   : directory containing FASTQ files
#   index_dir   : path to STAR genome index (built by 03_build_index.sh)
#   output_dir  : where to save alignment results and count matrix
#   chemistry   : 10x chemistry version - CB_UMI_Simple for v2/v3
#
# Notes:
#   - Requires R1 (barcodes) and R2 (cDNA) files
#   - Whitelist path must be set in params or passed as argument
#   - Output includes BAM file and genes x cells count matrix
#   - Works for any 10x Genomics dataset regardless of species or tissue
# =============================================================================

set -euo pipefail

# Always run from repo root
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Input arguments
FASTQ_DIR="${1:?Usage: bash 04_align.sh <fastq_dir> <index_dir> <output_dir> <whitelist>}"
INDEX_DIR="${2:?Usage: bash 04_align.sh <fastq_dir> <index_dir> <output_dir> <whitelist>}"
OUTPUT_DIR="${3:?Usage: bash 04_align.sh <fastq_dir> <index_dir> <output_dir> <whitelist>}"
WHITELIST="${4:?Usage: bash 04_align.sh <fastq_dir> <index_dir> <output_dir> <whitelist>}"

# Create output directory
mkdir -p "${OUTPUT_DIR}"

# Check required tools
for tool in STAR samtools; do
    if ! command -v "${tool}" &>/dev/null; then
        echo "ERROR: ${tool} not found. Activate the conda environment first."
        echo "       conda activate scrna-env"
        exit 1
    fi
done

# Logging setup
LOG_FILE="${OUTPUT_DIR}/align_log.txt"
echo "Alignment started: $(date)" | tee -a "${LOG_FILE}"
echo "FASTQ directory: ${FASTQ_DIR}" | tee -a "${LOG_FILE}"
echo "Index directory: ${INDEX_DIR}" | tee -a "${LOG_FILE}"
echo "Output directory: ${OUTPUT_DIR}" | tee -a "${LOG_FILE}"
echo "Whitelist: ${WHITELIST}" | tee -a "${LOG_FILE}"
echo "STAR version: $(STAR --version)" | tee -a "${LOG_FILE}"

# Detect R1 and R2 files automatically
# Handles multiple lanes by finding all matching files and joining with comma
R1_FILES=$(find "${FASTQ_DIR}" -name "*_R1_*.fastq.gz" | sort | tr '\n' ',' | sed 's/,$//')
R2_FILES=$(find "${FASTQ_DIR}" -name "*_R2_*.fastq.gz" | sort | tr '\n' ',' | sed 's/,$//')

# Validate files were found
if [[ -z "${R1_FILES}" ]]; then
    echo "ERROR: No R1 FASTQ files found in ${FASTQ_DIR}" | tee -a "${LOG_FILE}"
    exit 1
fi

if [[ -z "${R2_FILES}" ]]; then
    echo "ERROR: No R2 FASTQ files found in ${FASTQ_DIR}" | tee -a "${LOG_FILE}"
    exit 1
fi

echo "R1 files: ${R1_FILES}" | tee -a "${LOG_FILE}"
echo "R2 files: ${R2_FILES}" | tee -a "${LOG_FILE}"

# Run STARsolo alignment
echo "Running STARsolo..." | tee -a "${LOG_FILE}"

STAR \
    --runMode alignReads \
    --genomeDir "${INDEX_DIR}" \
    --readFilesIn "${R2_FILES}" "${R1_FILES}" \
    --readFilesCommand zcat \
    --soloType CB_UMI_Simple \
    --soloCBwhitelist "${WHITELIST}" \
    --soloCBstart 1 --soloCBlen 16 \
    --soloUMIstart 17 --soloUMIlen 12 \
    --outSAMtype BAM SortedByCoordinate \
    --outSAMattributes NH HI nM AS CR UR CB UB GX GN sS sQ sM \
    --runThreadN 4 \
    --outFileNamePrefix "${OUTPUT_DIR}/" \
    --soloOutDir "${OUTPUT_DIR}/solo_out" \
    --soloFeatures Gene \
    --soloCellFilter EmptyDrops_CR \
    2>&1 | tee -a "${LOG_FILE}"

echo "Alignment completed: $(date)" | tee -a "${LOG_FILE}"
echo "Count matrix written to: ${OUTPUT_DIR}/solo_out/" | tee -a "${LOG_FILE}"

# Index the BAM file for downstream use
echo "Indexing BAM file..." | tee -a "${LOG_FILE}"
samtools index "${OUTPUT_DIR}/Aligned.sortedByCoord.out.bam" \
    2>&1 | tee -a "${LOG_FILE}"

# Summary
echo "Alignment completed: $(date)" | tee -a "${LOG_FILE}"
echo "BAM file: ${OUTPUT_DIR}/Aligned.sortedByCoord.out.bam" | tee -a "${LOG_FILE}"
echo "Count matrix: ${OUTPUT_DIR}/solo_out/Gene/filtered/" | tee -a "${LOG_FILE}"SS