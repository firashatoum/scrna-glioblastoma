# =============================================================================
# 01_qc_filtering.R
# Loads raw 10x MTX matrices, performs per-sample and merged QC,
# filters low quality cells, and saves filtered Seurat object.
#
# Usage:
#   Rscript analysis/01_qc_filtering.R \
#     <matrix_dir> <sample_sheet> <out_dir> <project_name> \
#     [min_genes] [max_genes] [max_mt_pct] [min_umi]
#
# Arguments:
#   matrix_dir   : directory containing per-sample MTX subdirectories
#   sample_sheet : path to sample_sheet.tsv
#   out_dir      : directory for output files (RDS, plots, tables)
#   project_name : name used for output file naming (e.g. GSE182109)
#
# Parameters (optional, biologically justified defaults):
#   min_genes    : minimum genes per cell (default: 200)
#                  below this = likely empty droplet
#   max_genes    : maximum genes per cell (default: 6000)
#                  above this = likely doublet
#   max_mt_pct   : maximum mitochondrial % per cell (default: 20)
#                  above this = likely dead or damaged cell
#   min_umi      : minimum UMIs per cell (default: 500)
#                  below this = likely empty droplet or poor quality
#
# Outputs:
#   <out_dir>/rds/01_seurat_filtered.rds     — filtered Seurat object
#   <out_dir>/figures/01_qc_per_sample.pdf   — per-sample QC violin plots
#   <out_dir>/figures/01_qc_merged.pdf       — merged QC plots
#   <out_dir>/tables/01_qc_summary.csv       — per-sample QC statistics
# =============================================================================

# --- Arguments ----------------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)

matrix_dir   <- args[1]
sample_sheet <- args[2]
out_dir      <- args[3]
project_name <- args[4]
min_genes    <- if (!is.na(args[5])) as.integer(args[5]) else 200L
max_genes    <- if (!is.na(args[6])) as.integer(args[6]) else 6000L
max_mt_pct   <- if (!is.na(args[7])) as.numeric(args[7]) else 20.0
min_umi      <- if (!is.na(args[8])) as.integer(args[8]) else 500L

# Validate required arguments
if (is.na(matrix_dir) || is.na(sample_sheet) || is.na(out_dir) || is.na(project_name)) {
  stop(
    "Usage: Rscript 01_qc_filtering.R ",
    "<matrix_dir> <sample_sheet> <out_dir> <project_name> ",
    "[min_genes] [max_genes] [max_mt_pct] [min_umi]"
  )
}

# Create output directories
dir.create(file.path(out_dir, "rds"),     showWarnings = FALSE, recursive = TRUE)
dir.create(file.path(out_dir, "figures"), showWarnings = FALSE, recursive = TRUE)
dir.create(file.path(out_dir, "tables"),  showWarnings = FALSE, recursive = TRUE)

# Log parameters
message("=== 01_qc_filtering.R ===")
message("Matrix directory : ", matrix_dir)
message("Sample sheet     : ", sample_sheet)
message("Output directory : ", out_dir)
message("Project name     : ", project_name)
message("Min genes        : ", min_genes)
message("Max genes        : ", max_genes)
message("Max MT %         : ", max_mt_pct)
message("Min UMI          : ", min_umi)
message("Started          : ", Sys.time())

# --- Libraries ----------------------------------------------------------------
library(Seurat)
library(Matrix)
library(tidyverse)
library(patchwork)

# --- Load sample sheet --------------------------------------------------------
message("Loading sample sheet...")

sample_info <- read.delim(sample_sheet, stringsAsFactors = FALSE)

# Validate required columns
required_cols <- c("sample_id", "condition", "patient_id")
missing_cols  <- setdiff(required_cols, colnames(sample_info))
if (length(missing_cols) > 0) {
  stop("Sample sheet missing required columns: ", paste(missing_cols, collapse = ", "))
}

message("Samples found in sheet: ", nrow(sample_info))
message("Conditions: ", paste(unique(sample_info$condition), collapse = ", "))

# --- Load per-sample matrices -------------------------------------------------
message("Loading per-sample matrices...")

seurat_list <- list()

for (i in seq_len(nrow(sample_info))) {
  
  sid       <- sample_info$sample_id[i]
  condition <- sample_info$condition[i]
  patient   <- sample_info$patient_id[i]
  
  sample_path <- file.path(matrix_dir, sid)
  
  # Check sample directory exists
  if (!dir.exists(sample_path)) {
    warning("Sample directory not found, skipping: ", sample_path)
    next
  }
  
  message("  Loading: ", sid)
  
  # Load MTX matrix
  counts <- Read10X(data.dir = sample_path)
  
  # Create Seurat object — initial loose filter to remove truly empty droplets
  seurat_obj <- CreateSeuratObject(
    counts    = counts,
    project   = sid,
    min.cells = 3,
    min.features = 50
  )
  
  # Add metadata
  seurat_obj$sample_id  <- sid
  seurat_obj$condition  <- condition
  seurat_obj$patient_id <- patient
  
  # Calculate mitochondrial percentage
  seurat_obj[["percent.mt"]] <- PercentageFeatureSet(
    seurat_obj,
    pattern = "^MT-"
  )
  
  # Store in list
  seurat_list[[sid]] <- seurat_obj
  
  message("    Cells loaded: ", ncol(seurat_obj))
  
}

message("Samples successfully loaded: ", length(seurat_list))

# --- Per-sample QC visualization ----------------------------------------------
message("Generating per-sample QC plots...")

# Open PDF for per-sample plots
pdf(file.path(out_dir, "figures", "01_qc_per_sample.pdf"), width = 14, height = 8)

for (sid in names(seurat_list)) {
  
  obj <- seurat_list[[sid]]
  
  # Violin plots of the three core QC metrics
  p1 <- VlnPlot(obj, features = "nFeature_RNA", pt.size = 0.1) +
    geom_hline(yintercept = c(min_genes, max_genes), 
               linetype = "dashed", color = "red") +
    labs(title = paste0(sid, " — Genes per cell"),
         x = NULL) +
    theme(legend.position = "none")
  
  p2 <- VlnPlot(obj, features = "nCount_RNA", pt.size = 0.1) +
    geom_hline(yintercept = min_umi,
               linetype = "dashed", color = "red") +
    labs(title = paste0(sid, " — UMIs per cell"),
         x = NULL) +
    theme(legend.position = "none")
  
  p3 <- VlnPlot(obj, features = "percent.mt", pt.size = 0.1) +
    geom_hline(yintercept = max_mt_pct,
               linetype = "dashed", color = "red") +
    labs(title = paste0(sid, " — Mitochondrial %"),
         x = NULL) +
    theme(legend.position = "none")
  
  # Scatter plot — UMIs vs genes, colored by MT%
  # Reveals doublets (top right) and dead cells (high MT, low genes)
  p4 <- FeatureScatter(obj, 
                       feature1 = "nCount_RNA", 
                       feature2 = "nFeature_RNA",
                       pt.size  = 0.5) +
    labs(title = paste0(sid, " — UMIs vs Genes")) +
    theme(legend.position = "none")
  
  # Combine and print to PDF
  print((p1 | p2 | p3) / p4)
  
}

dev.off()
message("Per-sample QC plots saved.")

# --- Merge all samples --------------------------------------------------------
message("Merging ", length(seurat_list), " samples into one Seurat object...")

# Pull first sample out as the base object
first_id     <- names(seurat_list)[1]
seurat_merged <- seurat_list[[first_id]]

# Merge remaining samples into the base
seurat_merged <- merge(
  x          = seurat_merged,
  y          = seurat_list[names(seurat_list) != first_id],
  add.cell.ids = names(seurat_list),
  project    = project_name
)

message("Total cells before filtering: ", ncol(seurat_merged))
message("Total genes before filtering: ", nrow(seurat_merged))

# --- Filter low quality cells -------------------------------------------------
message("Applying QC filters...")

# Store pre-filter counts for summary
cells_before <- ncol(seurat_merged)

# Apply biological filters
seurat_filtered <- subset(
  seurat_merged,
  subset = nFeature_RNA >= min_genes &
    nFeature_RNA <= max_genes &
    nCount_RNA   >= min_umi   &
    percent.mt   <= max_mt_pct
)

cells_after  <- ncol(seurat_filtered)
cells_removed <- cells_before - cells_after

message("Cells before filtering : ", cells_before)
message("Cells after filtering  : ", cells_after)
message("Cells removed          : ", cells_removed, 
        " (", round(cells_removed / cells_before * 100, 1), "%)")

# --- QC summary table ---------------------------------------------------------
message("Generating QC summary table...")

# Per-sample summary before filtering
summary_before <- data.frame(
  sample_id = seurat_merged$sample_id,
  condition = seurat_merged$condition,
  patient_id = seurat_merged$patient_id,
  nFeature_RNA = seurat_merged$nFeature_RNA,
  nCount_RNA   = seurat_merged$nCount_RNA,
  percent.mt   = seurat_merged$percent.mt
) %>%
  group_by(sample_id, condition, patient_id) %>%
  summarise(
    cells_before    = n(),
    median_genes    = median(nFeature_RNA),
    median_umi      = median(nCount_RNA),
    median_mt_pct   = median(percent.mt),
    .groups = "drop"
  )

# Per-sample summary after filtering
summary_after <- data.frame(
  sample_id = seurat_filtered$sample_id
) %>%
  group_by(sample_id) %>%
  summarise(
    cells_after = n(),
    .groups = "drop"
  )

# Join and calculate retention rate
qc_summary <- left_join(summary_before, summary_after, by = "sample_id") %>%
  mutate(
    cells_removed    = cells_before - cells_after,
    retention_pct    = round(cells_after / cells_before * 100, 1)
  ) %>%
  arrange(condition, sample_id)

# Save to CSV
write.csv(
  qc_summary,
  file      = file.path(out_dir, "tables", "01_qc_summary.csv"),
  row.names = FALSE
)

message("QC summary table saved.")
message("Overall retention: ", 
        round(sum(qc_summary$cells_after) / sum(qc_summary$cells_before) * 100, 1),
        "% of cells passed filters")
# --- Save filtered Seurat object ----------------------------------------------
message("Saving filtered Seurat object...")

saveRDS(
  seurat_filtered,
  file = file.path(out_dir, "rds", "01_seurat_filtered.rds")
)

message("Filtered Seurat object saved.")
message("=== 01_qc_filtering.R complete ===")
message("Finished: ", Sys.time())
message("Output directory: ", out_dir)
message("Summary:")
message("  Samples loaded    : ", length(seurat_list))
message("  Cells before QC   : ", cells_before)
message("  Cells after QC    : ", cells_after)
message("  Cells removed     : ", cells_removed, 
        " (", round(cells_removed / cells_before * 100, 1), "%)")
message("  Output RDS        : ", 
        file.path(out_dir, "rds", "01_seurat_filtered.rds"))
