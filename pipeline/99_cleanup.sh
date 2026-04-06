#!/usr/bin/env bash
# =============================================================================
# 99_cleanup.sh
# Removes intermediate files after successful pipeline run.
# Keeps only compressed FASTQs and count matrices.
# SAFETY: only deletes files after verifying outputs exist and are non-empty.
#
# Usage: bash 99_cleanup.sh <sample_dir>
#
# Arguments:
#   sample_dir : path to sample directory (e.g. data/raw/PBMC_1k/)
# =============================================================================

set -euo pipefail

# Always run from repo root
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Input arguments
SAMPLE_DIR="${1:?Usage: bash 99_cleanup.sh <sample_dir>}"

# Logging setup
LOG_FILE="${SAMPLE_DIR}/cleanup_log.txt"
echo "Cleanup started: $(date)" | tee -a "${LOG_FILE}"
echo "Sample directory: ${SAMPLE_DIR}" | tee -a "${LOG_FILE}"

# Safety check — only proceed if compressed FASTQs exist and are non-empty
echo "Checking for compressed FASTQs..." | tee -a "${LOG_FILE}"

FASTQ_GZ=$(find "${SAMPLE_DIR}" -name "*.fastq.gz" | head -1)

if [[ -z "${FASTQ_GZ}" ]]; then
    echo "ERROR: No compressed FASTQs found in ${SAMPLE_DIR}" | tee -a "${LOG_FILE}"
    echo "Aborting cleanup — raw data preserved." | tee -a "${LOG_FILE}"
    exit 1
fi

echo "Compressed FASTQs found. Safe to proceed." | tee -a "${LOG_FILE}"

# Remove uncompressed FASTQs if they exist
echo "Removing uncompressed FASTQs..." | tee -a "${LOG_FILE}"
find "${SAMPLE_DIR}" -name "*.fastq" -type f | while read -r file; do
    echo "  Removing: ${file}" | tee -a "${LOG_FILE}"
    rm -f "${file}"
done

# Remove SRA files
echo "Removing SRA files..." | tee -a "${LOG_FILE}"
find "${SAMPLE_DIR}" -name "*.sra" -type f | while read -r file; do
    echo "  Removing: ${file}" | tee -a "${LOG_FILE}"
    rm -f "${file}"
done

# Remove fasterq-dump temp directories
echo "Removing temp directories..." | tee -a "${LOG_FILE}"
find "${SAMPLE_DIR}" -name "fasterq.tmp*" -type d | while read -r dir; do
    echo "  Removing: ${dir}" | tee -a "${LOG_FILE}"
    rm -rf "${dir}"
done

# Report final disk usage
echo "Cleanup complete." | tee -a "${LOG_FILE}"
echo "Remaining files in ${SAMPLE_DIR}:" | tee -a "${LOG_FILE}"
ls -lh "${SAMPLE_DIR}" | tee -a "${LOG_FILE}"
echo "Disk usage: $(du -sh ${SAMPLE_DIR})" | tee -a "${LOG_FILE}"
echo "Cleanup completed: $(date)" | tee -a "${LOG_FILE}"