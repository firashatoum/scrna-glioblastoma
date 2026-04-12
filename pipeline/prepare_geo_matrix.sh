#!/usr/bin/env bash
# =============================================================================
# prepare_geo_matrix.sh
# Reorganizes flat GEO MTX files into per-sample directories.
# Required before loading data with Seurat's Read10X().
#
# GEO deposits MTX files as flat triplets:
#   GSM5518596_rGBM-01-A_barcodes.tsv.gz
#   GSM5518596_rGBM-01-A_features.tsv.gz
#   GSM5518596_rGBM-01-A_matrix.mtx.gz
#
# This script reorganizes them into:
#   rGBM-01-A/
#     barcodes.tsv.gz
#     features.tsv.gz
#     matrix.mtx.gz
#
# Usage: bash pipeline/prepare_geo_matrix.sh <matrix_dir>
#
# Arguments:
#   matrix_dir : directory containing flat GEO MTX files
#                (e.g. data/processed/GSE182109/)
#
# Notes:
#   - Run once after extracting GEO tar archive
#   - Original flat files are removed after reorganization
#   - Safe to re-run — skips samples already organized
# =============================================================================

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

MATRIX_DIR="${1:?Usage: bash pipeline/prepare_geo_matrix.sh <matrix_dir>}"

if [[ ! -d "${MATRIX_DIR}" ]]; then
    echo "ERROR: Directory not found: ${MATRIX_DIR}"
    exit 1
fi

echo "Reorganizing GEO matrix files in: ${MATRIX_DIR}"
echo "Started: $(date)"

# Find all barcodes files — one per sample, drives the loop
find "${MATRIX_DIR}" -maxdepth 1 -name "*_barcodes.tsv.gz" | sort | while read -r barcodes_file; do

    # Extract filename only
    filename=$(basename "${barcodes_file}")

    # Extract sample label — strip GSM accession prefix and _barcodes.tsv.gz suffix
    # Example: GSM5518596_rGBM-01-A_barcodes.tsv.gz -> rGBM-01-A
    sample_label=$(echo "${filename}" | sed 's/^GSM[0-9]*_//' | sed 's/_barcodes\.tsv\.gz//')

    SAMPLE_DIR="${MATRIX_DIR}/${sample_label}"

    # Skip if already organized
    if [[ -d "${SAMPLE_DIR}" ]]; then
        echo "  Skipping ${sample_label} — directory already exists"
        continue
    fi

    echo "  Organizing: ${sample_label}"
    mkdir -p "${SAMPLE_DIR}"

    # Move and rename the three files
    mv "${MATRIX_DIR}/GSM"*"_${sample_label}_barcodes.tsv.gz"  "${SAMPLE_DIR}/barcodes.tsv.gz"
    mv "${MATRIX_DIR}/GSM"*"_${sample_label}_features.tsv.gz"  "${SAMPLE_DIR}/features.tsv.gz"
    mv "${MATRIX_DIR}/GSM"*"_${sample_label}_matrix.mtx.gz"    "${SAMPLE_DIR}/matrix.mtx.gz"

done

echo "Done: $(date)"
echo "Sample directories created in: ${MATRIX_DIR}"