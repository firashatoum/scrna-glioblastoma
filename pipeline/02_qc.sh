#!/usr/bin/env bash
# =============================================================================
# 02_qc.sh
# Runs FastQC on R2 reads and MultiQC to aggregate results.
# Usage: bash 02_qc.sh <fastq_dir> <output_dir>
#
# Arguments:
#   fastq_dir   : directory containing FASTQ files (e.g. data/raw/PBMC_1k/pbmc_1k_v3_fastqs/)
#   output_dir  : where to save QC results (e.g. results/qc/)
#
# Notes:
#   - Only R2 reads are assessed (cDNA reads)
#   - R1 reads contain barcodes and have a different quality profile
#   - Works on any standard 10x FASTQ directory
# =============================================================================

set -euo pipefail

# Always run from repo root
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Input arguments
FASTQ_DIR="${1:?Usage: bash 02_qc.sh <fastq_dir> <output_dir>}"
OUTPUT_DIR="${2:?Usage: bash 02_qc.sh <fastq_dir> <output_dir>}"

# Create output directory
mkdir -p "${OUTPUT_DIR}"

# Check required tools
for tool in fastqc multiqc; do
    if ! command -v "${tool}" &>/dev/null; then
        echo "ERROR: ${tool} not found. Activate the conda environment first."
        echo "       conda activate scrna-env"
        exit 1
    fi
done

# Logging setup
LOG_FILE="${OUTPUT_DIR}/qc_log.txt"
echo "QC started: $(date)" | tee -a "${LOG_FILE}"
echo "FASTQ directory: ${FASTQ_DIR}" | tee -a "${LOG_FILE}"
echo "Output directory: ${OUTPUT_DIR}" | tee -a "${LOG_FILE}"

# Run FastQC on R2 reads only (cDNA reads)
# R1 contains barcodes - different quality profile, not meaningful to assess
echo "Running FastQC on R2 reads..." | tee -a "${LOG_FILE}"

R2_FILES=$(find "${FASTQ_DIR}" -name "*_R2_*.fastq.gz" | sort)

if [[ -z "${R2_FILES}" ]]; then
    echo "ERROR: No R2 FASTQ files found in ${FASTQ_DIR}" | tee -a "${LOG_FILE}"
    exit 1
fi

echo "Found R2 files:" | tee -a "${LOG_FILE}"
echo "${R2_FILES}" | tee -a "${LOG_FILE}"

fastqc \
    --outdir "${OUTPUT_DIR}" \
    --threads 4 \
    ${R2_FILES} \
    2>&1 | tee -a "${LOG_FILE}"

echo "FastQC complete." | tee -a "${LOG_FILE}"

# Run MultiQC to aggregate all FastQC reports
echo "Running MultiQC..." | tee -a "${LOG_FILE}"

multiqc \
    "${OUTPUT_DIR}" \
    --outdir "${OUTPUT_DIR}" \
    --filename "multiqc_report" \
    --force \
    2>&1 | tee -a "${LOG_FILE}"

echo "MultiQC complete." | tee -a "${LOG_FILE}"

# Summary
echo "QC completed: $(date)" | tee -a "${LOG_FILE}"
echo "Results written to: ${OUTPUT_DIR}" | tee -a "${LOG_FILE}"
echo "Open ${OUTPUT_DIR}/multiqc_report.html to view results." | tee -a "${LOG_FILE}"