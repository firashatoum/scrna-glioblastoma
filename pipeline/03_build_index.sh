#!/usr/bin/env bash
# =============================================================================
# 03_build_index.sh
# Builds STAR genome index from reference FASTA and GTF annotation.
# Run once per genome assembly. Index is reused for all alignment runs.
#
# Usage: bash 03_build_index.sh <genome_fasta> <gtf_file> <index_dir>
#
# Arguments:
#   genome_fasta : path to reference genome FASTA (.fa or .fa.gz)
#   gtf_file     : path to gene annotation GTF (.gtf or .gtf.gz)
#   index_dir    : where to write the STAR index (e.g. data/reference/hg38/)
#
# Notes:
#   - Requires ~30GB disk space for the index
#   - Takes ~45 minutes on a standard laptop
#   - Only needs to be run once per genome assembly
#   - Index is gitignored due to size
# =============================================================================

set -euo pipefail

# Always run from repo root
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Input arguments
GENOME_FASTA="${1:?Usage: bash 03_build_index.sh <genome_fasta> <gtf_file> <index_dir>}"
GTF_FILE="${2:?Usage: bash 03_build_index.sh <genome_fasta> <gtf_file> <index_dir>}"
INDEX_DIR="${3:?Usage: bash 03_build_index.sh <genome_fasta> <gtf_file> <index_dir>}"

# Create index directory
mkdir -p "${INDEX_DIR}"

# Check required tools
for tool in STAR; do
    if ! command -v "${tool}" &>/dev/null; then
        echo "ERROR: ${tool} not found. Activate the conda environment first."
        echo "       conda activate scrna-env"
        exit 1
    fi
done

# Logging setup
LOG_FILE="${INDEX_DIR}/build_index_log.txt"
echo "Index building started: $(date)" | tee -a "${LOG_FILE}"
echo "Genome FASTA: ${GENOME_FASTA}" | tee -a "${LOG_FILE}"
echo "GTF file: ${GTF_FILE}" | tee -a "${LOG_FILE}"
echo "Index directory: ${INDEX_DIR}" | tee -a "${LOG_FILE}"
echo "STAR version: $(STAR --version)" | tee -a "${LOG_FILE}"

# Build STAR genome index
echo "Building STAR genome index..." | tee -a "${LOG_FILE}"
echo "This will take approximately 45 minutes..." | tee -a "${LOG_FILE}"

STAR \
    --runMode genomeGenerate \
    --genomeDir "${INDEX_DIR}" \
    --genomeFastaFiles "${GENOME_FASTA}" \
    --sjdbGTFfile "${GTF_FILE}" \
    --runThreadN 2 \
    --genomeSAindexNbases 14 \
    --limitGenomeGenerateRAM 25000000000 \
    2>&1 | tee -a "${LOG_FILE}"

# Summary
echo "Index building completed: $(date)" | tee -a "${LOG_FILE}"
echo "Index written to: ${INDEX_DIR}" | tee -a "${LOG_FILE}"