#!/usr/bin/env bash
# =============================================================================
# 01_download.sh
# Downloads raw FASTQ files from SRA for samples in the sample sheet.
# Usage: bash 01_download.sh <sample_sheet.tsv> <output_dir> [sample_id]
#
# Arguments:
#   sample_sheet.tsv  : path to config/sample_sheet.tsv
#   output_dir        : where to save downloaded FASTQs (data/raw/)
#   sample_id         : optional - download only this sample (for testing)
# =============================================================================

set -euo pipefail

# Input arguments
SAMPLE_SHEET="${1:?Usage: bash 01_download.sh <sample_sheet.tsv> <output_dir> [sample_id]}"
OUTPUT_DIR="${2:?Usage: bash 01_download.sh <sample_sheet.tsv> <output_dir> [sample_id]}"
FILTER_SAMPLE="${3:-}"

# Create output directory if it does not exist
mkdir -p "${OUTPUT_DIR}"

# Check required tools are available
for tool in prefetch fasterq-dump gzip; do
    if ! command -v "${tool}" &>/dev/null; then
        echo "ERROR: ${tool} not found. Activate the conda environment first."
        echo "       conda activate scrna-env"
        exit 1
    fi
done

# Logging setup
LOG_FILE="${OUTPUT_DIR}/download_log.txt"
echo "Download started: $(date)" | tee -a "${LOG_FILE}"
echo "Sample sheet: ${SAMPLE_SHEET}" | tee -a "${LOG_FILE}"
echo "Output directory: ${OUTPUT_DIR}" | tee -a "${LOG_FILE}"

# Main download loop - skip header line
tail -n +2 "${SAMPLE_SHEET}" | while IFS=$'\t' read -r sample_id gsm srr condition patient_id fraction; do

    # If a filter sample was specified, skip all others
    if [[ -n "${FILTER_SAMPLE}" && "${sample_id}" != "${FILTER_SAMPLE}" ]]; then
        continue
    fi

    echo "Processing: ${sample_id} | SRR: ${srr}" | tee -a "${LOG_FILE}"

    # Create a directory per sample inside output dir
    SAMPLE_DIR="${OUTPUT_DIR}/${sample_id}"
    mkdir -p "${SAMPLE_DIR}"

    # Step 1: prefetch
    echo "  [1/2] Prefetching ${srr}..." | tee -a "${LOG_FILE}"
    prefetch "${srr}" \
        --output-directory "${SAMPLE_DIR}" \
        --progress \
        2>&1 | tee -a "${LOG_FILE}" || true

    # Step 2: fasterq-dump
    echo "  [2/2] Converting to FASTQ..." | tee -a "${LOG_FILE}"
    fasterq-dump "${SAMPLE_DIR}/${srr}/${srr}.sra" \
        --outdir "${SAMPLE_DIR}" \
        --split-files \
        --threads 4 \
        2>&1 | tee -a "${LOG_FILE}"

    # Compress the FASTQs
    echo "  Compressing FASTQs..." | tee -a "${LOG_FILE}"
    gzip "${SAMPLE_DIR}"/*.fastq

    echo "  Done: ${sample_id}" | tee -a "${LOG_FILE}"

done

# Summary
echo "Download completed: $(date)" | tee -a "${LOG_FILE}"
echo "Output written to: ${OUTPUT_DIR}" | tee -a "${LOG_FILE}"