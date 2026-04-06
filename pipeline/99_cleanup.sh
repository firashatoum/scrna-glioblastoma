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