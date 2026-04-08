#!/usr/bin/env bash
# =============================================================================
# 03_build_index.sh
# Builds STAR genome index from reference FASTA and GTF annotation.
# Run once per genome assembly. Index is reused for all alignment runs.
#
# Usage: bash 03_build_index.sh <genome_fasta> <gtf_file> <index_dir> [threads]
#
# Arguments:
#   genome_fasta : path to reference genome FASTA (.fa or .fa.gz)
#   gtf_file     : path to gene annotation GTF (.gtf or .gtf.gz)
#   index_dir    : where to write the STAR index
#   threads      : number of threads (optional, default: 4)
#
# Notes:
#   - Requires ~30GB disk space for the index
#   - Takes ~45 minutes on a standard laptop
#   - Only needs to be run once per genome assembly
#   - Index is gitignored due to size
# =============================================================================

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

GENOME_FASTA="${1:?Usage: bash 03_build_index.sh <genome_fasta> <gtf_file> <index_dir> [threads]}"
GTF_FILE="${2:?Usage: bash 03_build_index.sh <genome_fasta> <gtf_file> <index_dir> [threads]}"
INDEX_DIR="${3:?Usage: bash 03_build_index.sh <genome_fasta> <gtf_file> <index_dir> [threads]}"
THREADS="${4:-4}"

mkdir -p "${INDEX_DIR}"

for tool in STAR; do
    if ! command -v "${tool}" &>/dev/null; then
        echo "ERROR: ${tool} not found. Activate the conda environment first."
        echo "       conda activate scrna-env"
        exit 1
    fi
done

# Decompress FASTA if gzipped
if [[ "${GENOME_FASTA}" == *.gz ]]; then
    echo "Decompressing FASTA: ${GENOME_FASTA}"
    gunzip "${GENOME_FASTA}"
    GENOME_FASTA="${GENOME_FASTA%.gz}"
fi

# Decompress GTF if gzipped
if [[ "${GTF_FILE}" == *.gz ]]; then
    echo "Decompressing GTF: ${GTF_FILE}"
    gunzip "${GTF_FILE}"
    GTF_FILE="${GTF_FILE%.gz}"
fi

LOG_FILE="${INDEX_DIR}/build_index_log.txt"
echo "Index building started: $(date)" | tee -a "${LOG_FILE}"
echo "Genome FASTA: ${GENOME_FASTA}" | tee -a "${LOG_FILE}"
echo "GTF file: ${GTF_FILE}" | tee -a "${LOG_FILE}"
echo "Index directory: ${INDEX_DIR}" | tee -a "${LOG_FILE}"
echo "Threads: ${THREADS}" | tee -a "${LOG_FILE}"
echo "STAR version: $(STAR --version)" | tee -a "${LOG_FILE}"

echo "Building STAR genome index..." | tee -a "${LOG_FILE}"
echo "This will take approximately 45 minutes..." | tee -a "${LOG_FILE}"

STAR \
    --runMode genomeGenerate \
    --genomeDir "${INDEX_DIR}" \
    --genomeFastaFiles "${GENOME_FASTA}" \
    --sjdbGTFfile "${GTF_FILE}" \
    --runThreadN "${THREADS}" \
    --limitGenomeGenerateRAM 22000000000 \
    2>&1 | tee -a "${LOG_FILE}"

echo "Index building completed: $(date)" | tee -a "${LOG_FILE}"
echo "Index written to: ${INDEX_DIR}" | tee -a "${LOG_FILE}"