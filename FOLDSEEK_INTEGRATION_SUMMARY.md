# Foldseek Integration Summary

## Overview
Successfully integrated Foldseek structural similarity search to analyze both Boltzgen budget designs and Protenix refolded structures against structural databases (e.g., AlphaFold, Swiss-Model).

## Changes Made

### 1. Workflow Updates (`workflows/protein_design.nf`)

#### Foldseek Analysis Section
- **Location**: After PRODIGY, before CONSOLIDATION
- **Execution**: Runs in parallel with ipSAE and PRODIGY analyses
- **Input Sources**:
  - **Boltzgen budget designs**: From `BOLTZGEN_RUN.out.budget_design_cifs`
  - **Protenix structures**: From `PROTENIX_REFOLD.out.structures` (if enabled)

#### Key Features
- Searches ALL budget designs (not just filtered final designs)
- Supports both Boltzgen and Protenix structures
- Automatic source tracking via metadata (`source = "boltzgen"` or `source = "protenix"`)
- GPU-accelerated for 4-27x speedup
- Integrated into consolidation workflow

### 2. Parameter Documentation Updates

#### `nextflow.config`
```groovy
run_foldseek               = false  // Enable Foldseek for budget designs and Protenix structures
foldseek_database          = null   // Path to database (e.g., AlphaFold/Swiss-Model)
```

#### `nextflow_schema.json`
- Updated descriptions to reflect budget design + Protenix analysis
- Enhanced help text mentioning AlphaFold/Swiss-Model databases
- Noted GPU acceleration (4-27x speedup)

#### `README.md`
- Added Foldseek to Optional Analysis Modules list
- Clarified it searches AlphaFold/Swiss-Model databases with GPU acceleration

## Workflow Execution Flow

```
BOLTZGEN_RUN
    ├─> budget_design_cifs ──┬─> IPSAE_CALCULATE (parallel)
    │                        ├─> PRODIGY_PREDICT (parallel)
    │                        └─> FOLDSEEK_SEARCH (parallel)
    │
    └─> (if ProteinMPNN enabled)
        └─> PROTEINMPNN_OPTIMIZE
            └─> PROTENIX_REFOLD
                ├─> structures ──┬─> IPSAE_CALCULATE (parallel)
                │                ├─> PRODIGY_PREDICT (parallel)
                │                └─> FOLDSEEK_SEARCH (parallel)
                │
                └─> confidence ──> CONVERT_PROTENIX_TO_NPZ
```

## Foldseek Module Configuration

### GPU Support
- **Container**: `quay.io/biocontainers/foldseek:9.427df8a--pl5321hf1761c0_0`
- **Accelerator**: 1 NVIDIA GPU per process
- **GPU Flags**: Automatically detected and enabled if available
- **Speedup**: 4-27x faster than CPU-only execution

### Search Parameters
- `foldseek_evalue`: 0.001 (default)
- `foldseek_max_seqs`: 100 (default)
- `foldseek_sensitivity`: 9.5 (default, range: 1.0-9.5)
- `foldseek_coverage`: 0.0 (default, range: 0.0-1.0)
- `foldseek_alignment_type`: 2 (default, 3Di+AA local alignment)

### Output Structure
```
results/
└── <sample_id>/
    └── foldseek/
        ├── <sample_id>_<design_id>_foldseek_results.tsv     (all matches)
        ├── <sample_id>_<design_id>_foldseek_summary.tsv     (top 10 hits)
        └── <sample_id>_<design_id>_protenix_foldseek_results.tsv  (if Protenix enabled)
```

## Usage Example

### Basic Usage
```bash
nextflow run seqeralabs/nf-proteindesign \
    --input samplesheet.csv \
    --run_foldseek \
    --foldseek_database /path/to/alphafold_db \
    --outdir results
```

### With Full Analysis Pipeline
```bash
nextflow run seqeralabs/nf-proteindesign \
    --input samplesheet.csv \
    --run_proteinmpnn \
    --run_protenix_refold \
    --run_ipsae \
    --run_prodigy \
    --run_foldseek \
    --foldseek_database /data/alphafold/afdb50 \
    --run_consolidation \
    --outdir results
```

## Recommended Databases

### AlphaFold Database
- **AlphaFold/UniProt50**: Comprehensive, high-quality structural predictions
- **AlphaFold/UniProt100**: Full UniProt coverage
- **AlphaFold/Swiss-Prot**: Curated, reviewed proteins only

### Download Instructions
```bash
# Download AlphaFold/UniProt50 database
wget https://foldseek.steineggerlab.workers.dev/afdb50.tar.gz
tar xvzf afdb50.tar.gz

# Or create custom database from PDB files
foldseek createdb pdb_files/ custom_db
```

## Parallel Execution Benefits

### Resource Optimization
- **ipSAE, PRODIGY, and Foldseek run simultaneously**
- Each process gets dedicated GPU/CPU resources
- No sequential bottlenecks
- Faster total pipeline runtime

### Metadata Tracking
All outputs include source tracking:
- `meta.source = "boltzgen"` - Original Boltzgen designs
- `meta.source = "protenix"` - Protenix refolded structures
- `meta.parent_id` - Links to original Boltzgen design
- `meta.mpnn_parent_id` - Links to ProteinMPNN sequence (Protenix only)

## Consolidation Integration
Foldseek results are automatically included in the consolidated metrics report when `--run_consolidation` is enabled. The consolidation process waits for all analyses (ipSAE, PRODIGY, Foldseek) to complete before generating the final report.

## Testing Recommendations

### Test with Small Database First
```bash
# Create small test database
foldseek createdb test_structures/ test_db

# Test Foldseek integration
nextflow run seqeralabs/nf-proteindesign \
    -profile test_design_protein,docker \
    --run_foldseek \
    --foldseek_database test_db
```

### Verify GPU Acceleration
- Check logs for "GPU detected - Foldseek will use GPU acceleration"
- Monitor GPU utilization with `nvidia-smi`
- Compare runtimes with/without GPU

## Notes
- Foldseek requires a pre-built database (not included in pipeline)
- GPU significantly improves performance (4-27x speedup)
- Works with both Boltzgen and Protenix structures
- Results are source-tagged for easy filtering in downstream analysis
- Runs in parallel with other quality metrics (ipSAE, PRODIGY)
