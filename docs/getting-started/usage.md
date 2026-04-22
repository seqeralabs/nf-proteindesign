# Basic Usage

This guide covers the fundamental concepts for using nf-proteindesign.

## :material-play: Basic Command Structure

```bash
nextflow run seqeralabs/nf-proteindesign \
    -profile <PROFILE> \
    --protein_design_tool <boltzgen|complexa> \
    --input <SAMPLESHEET> \
    --outdir <OUTPUT_DIR> \
    [OPTIONS]
```

### Components

- **`-profile`**: Execution profile (`docker`, `singularity`, `test_design_protein`, etc.)
- **`--protein_design_tool`**: Design backend — `boltzgen` (default) or `complexa`
- **`--input`**: Path to samplesheet CSV file (format depends on design tool)
- **`--outdir`**: Output directory path
- **`[OPTIONS]`**: Additional pipeline parameters

## :material-file-table: Samplesheet Format

The samplesheet format depends on the chosen design tool. Each row represents a separate design run.

### BoltzGen Samplesheet (default)

| Column | Required | Type | Description |
|--------|----------|------|-------------|
| `sample_id` | ✅ | string | Unique sample identifier |
| `design_yaml` | ✅ | string | Path to BoltzGen design YAML file |
| `target_sequence` | ✅ | string | Path to target protein FASTA sequence |
| `structure_files` | | string | Comma-separated structure files (PDB/CIF) |
| `protocol` | | string | Design protocol (`protein-anything`, `peptide-anything`, `nanobody-anything`, `protein-small_molecule`) |
| `num_designs` | | integer | Number of intermediate designs |
| `budget` | | integer | Number of final diversity-optimized designs |
| `reuse` | | boolean | Reuse previous results |
| `target_msa` | | string | Pre-computed MSA for target (`.a3m`) |
| `target_template` | | string | Template structure for Boltz-2 (CIF) |

```csv
sample_id,design_yaml,structure_files,protocol,num_designs,budget,reuse,target_msa,target_sequence,target_template
protein_binder,designs/egfr_binder.yaml,egfr.cif,protein-anything,3,2,,target.a3m,egfr.fasta,
nanobody_design,designs/spike_nanobody.yaml,spike.cif,nanobody-anything,3,2,,,spike.fasta,
```

### Complexa Samplesheet

| Column | Required | Type | Description |
|--------|----------|------|-------------|
| `sample_id` | ✅ | string | Unique sample identifier |
| `target_pdb` | ✅ | string | Target structure (PDB or CIF) |
| `pipeline_config` | ✅ | string | Complexa Hydra pipeline config YAML |
| `target_sequence` | ✅ | string | Target sequence FASTA |
| `target_msa` | | string | Pre-computed MSA for target |
| `target_template` | | string | Template structure for Boltz-2 |

```csv
sample_id,target_pdb,pipeline_config,target_sequence,target_msa,target_template
protein_binder,target.cif,configs/pipeline.yaml,target.fasta,target.a3m,
```

## :material-file-document: Design YAML Format (BoltzGen)

For BoltzGen, create design YAML files following this structure:

```yaml
# BoltzGen design specification
entities:
  # Designed protein entity
  - protein:
      id: C
      sequence: 50..100  # Length range for designed protein
  
  # Target structure entity
  - file:
      path: target.cif
      include:
        - chain:
            id: A  # Target chain to bind
```

## :material-cog: Common Parameters

### Essential Parameters

```bash
--input                  # Path to samplesheet CSV (required)
--outdir                 # Output directory (required)
--protein_design_tool    # Design backend: 'boltzgen' (default) or 'complexa'
```

### BoltzGen Parameters

```bash
--cache_dir              # Cache directory for BoltzGen model weights
```

### Complexa Parameters

```bash
--complexa_ckpt_dir      # Complexa checkpoint directory (required for Complexa)
--complexa_search_algorithm  # Search algorithm (default: 'best-of-n')
--complexa_nsteps        # Diffusion sampling steps (default: 400)
--complexa_replicas      # Replicas for best-of-n (default: 2)
--complexa_batch_size    # Batch size (default: 16)
```

### Analysis Options (all enabled by default)

```bash
--run_proteinmpnn        # ProteinMPNN sequence optimization (default: true)
--run_boltz2_refold      # Boltz-2 structure prediction (default: true)
--run_ipsae              # IPSAE interface scoring (default: true)
--run_prodigy            # PRODIGY affinity prediction (default: true)
--run_foldseek           # Foldseek structural search (default: true)
--run_consolidation      # Consolidated metrics report (default: true)
```

### Resource Management

```bash
--max_cpus         # Maximum CPUs (default: 16)
--max_memory       # Maximum memory (default: 128.GB)
--max_time         # Maximum time per job (default: 240.h)
--max_gpus         # Maximum GPUs per process (default: 1)
```

## :material-folder-open: Output Structure

The pipeline creates an organized output directory:

```
results/
├── {sample_id}/
│   ├── boltzgen/ or complexa/       # Design outputs (depends on tool)
│   │   ├── design_*.pdb / *.cif     # Generated structures
│   │   └── ...
│   │
│   ├── proteinmpnn/                  # If --run_proteinmpnn enabled
│   │   ├── sequences/               # Optimized FASTA sequences
│   │   └── scores/                  # ProteinMPNN scores
│   │
│   ├── boltz2/                       # If --run_boltz2_refold enabled
│   │   ├── structures/              # Predicted CIF structures
│   │   ├── confidence/              # Confidence scores (JSON)
│   │   └── npz/                     # PAE NPZ files
│   │
│   ├── ipsae/                        # If --run_ipsae enabled
│   │   └── *_ipsae_scores.txt
│   │
│   ├── prodigy/                      # If --run_prodigy enabled
│   │   └── *_prodigy_results.txt
│   │
│   ├── foldseek/                     # If --run_foldseek enabled
│   │   └── *_foldseek_summary.tsv
│   │
│   └── consolidated/                 # If --run_consolidation enabled
│       ├── consolidated_metrics.csv
│       └── consolidated_report.html
│
└── pipeline_info/
    ├── execution_report.html         # Execution summary
    ├── execution_timeline.html       # Timeline visualization
    └── execution_trace.txt           # Detailed trace
```

### Key Output Files

!!! tip "Most Important Files"
    - **Design structures**: `{sample}/boltzgen/*.pdb` or `{sample}/complexa/*.pdb`
    - **Consolidated report**: `{sample}/consolidated/consolidated_metrics.csv`
    - **Execution report**: `pipeline_info/execution_report.html`

## :material-play-circle: Example Workflows

### Example 1: Basic Protein Design (BoltzGen)

```bash
# 1. Create design YAML
cat > protein_design.yaml << EOF
entities:
  - protein:
      id: C
      sequence: 60..100
  - file:
      path: egfr.cif
      include:
        - chain:
            id: A
EOF

# 2. Create samplesheet
cat > samples.csv << EOF
sample_id,design_yaml,structure_files,protocol,num_designs,budget,reuse,target_msa,target_sequence,target_template
egfr_binder,protein_design.yaml,egfr.cif,protein-anything,3,2,,,egfr_sequence.fasta,
EOF

# 3. Run pipeline (all analysis modules enabled by default)
nextflow run seqeralabs/nf-proteindesign \
    -profile docker \
    --input samples.csv \
    --outdir results
```

### Example 2: Multiple Designs with Complexa

```bash
# 1. Create samplesheet for Complexa
cat > samples_complexa.csv << EOF
sample_id,target_pdb,pipeline_config,target_sequence,target_msa,target_template
egfr_binder,data/egfr.cif,configs/egfr_pipeline.yaml,data/egfr.fasta,,
spike_nanobody,data/spike.cif,configs/spike_pipeline.yaml,data/spike.fasta,,
EOF

# 2. Run with Complexa backend
nextflow run seqeralabs/nf-proteindesign \
    -profile docker \
    --protein_design_tool complexa \
    --input samples_complexa.csv \
    --complexa_ckpt_dir /path/to/checkpoints \
    --outdir results
```

### Example 3: Test Run

```bash
# Use built-in test profile (BoltzGen by default)
nextflow run seqeralabs/nf-proteindesign \
    -profile test_design_protein,docker
```

## :material-refresh: Resume Failed Runs

Nextflow can resume from the last successful step:

```bash
nextflow run seqeralabs/nf-proteindesign \
    -profile docker \
    --input samplesheet.csv \
    --outdir results \
    -resume  # ← Add this flag
```

!!! tip "Always Use Resume"
    The `-resume` flag is safe to use even on successful runs and saves significant time if something fails.

## :material-monitor: Monitoring Execution

### Check Pipeline Progress

```bash
# Watch Nextflow output
# Progress is shown in real-time

# Monitor GPU usage
watch -n 1 nvidia-smi

# Check disk usage
du -sh work/ results/
```

### View Execution Report

After completion, open the HTML report:

```bash
# Linux
xdg-open results/pipeline_info/execution_report.html

# Mac
open results/pipeline_info/execution_report.html

# View timeline
xdg-open results/pipeline_info/execution_timeline.html
```

## :material-wrench: Advanced Usage

### Custom Configuration

Create a custom config file `my_config.config`:

```groovy
process {
    withLabel: gpu {
        memory = '32 GB'
        time = '24 h'
    }
}

params {
    n_samples = 50
    timesteps = 200
}
```

Use with:

```bash
nextflow run seqeralabs/nf-proteindesign \
    -profile docker \
    -c my_config.config \
    --input samplesheet.csv \
    --outdir results
```

### Profile Combinations

Combine multiple profiles:

```bash
# Docker with test data
nextflow run ... -profile docker,test

# Docker with custom settings
nextflow run ... -profile docker,custom
```

## :material-bug: Common Issues

### Issue 1: Samplesheet Format

!!! bug "Error"
    `Invalid samplesheet format`

**Solution**: Ensure CSV is properly formatted with required columns:
```bash
# Check for proper headers
head -n 1 samplesheet.csv

# Validate no trailing commas
cat samplesheet.csv | grep -E ',$'
```

### Issue 2: File Not Found

!!! bug "Error"
    `File not found: design.yaml`

**Solution**: Use absolute paths or paths relative to work directory:
```bash
# Absolute path
sample,design_yaml
design1,/full/path/to/design.yaml

# Or use $PWD
sample,design_yaml
design1,$PWD/designs/design.yaml
```

### Issue 3: GPU Memory

!!! bug "Error"
    `CUDA out of memory`

**Solution**: Reduce `--n_samples` or use sequential processing:
```bash
nextflow run ... --n_samples 10  # Reduce batch size
```

## :material-arrow-right: Next Steps

- Check the [Quick Reference](quick-reference.md) for common commands
- Explore [Analysis Tools](../analysis/prodigy.md) integration
- Review [Pipeline Parameters](../reference/parameters.md) for advanced configuration

---

!!! question "Need Help?"
    - See [Quick Reference](quick-reference.md) for command templates
    - Check [GitHub Issues](https://github.com/seqeralabs/nf-proteindesign/issues)
