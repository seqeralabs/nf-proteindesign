# Basic Usage

This guide covers the fundamental concepts for using nf-proteindesign.

## :material-play: Basic Command Structure

```bash
nextflow run seqeralabs/nf-proteindesign \
    -profile <PROFILE> \
    --input <SAMPLESHEET> \
    --outdir <OUTPUT_DIR> \
    [OPTIONS]
```

### Components

- **`-profile`**: Execution profile (`docker`, `test`)
- **`--input`**: Path to samplesheet CSV file
- **`--outdir`**: Output directory path
- **`[OPTIONS]`**: Additional pipeline parameters

## :material-file-table: Samplesheet Format

The pipeline uses a CSV samplesheet to specify design jobs. Each row represents a separate design run.

### Required Columns

| Column | Required | Description |
|--------|----------|-------------|
| `sample` | ✅ | Unique sample identifier |
| `design_yaml` | ✅ | Path to design YAML file (see below) |

### Optional Columns

Additional columns can override default parameters per sample:

| Column | Type | Description |
|--------|------|-------------|
| `num_designs` | Integer | Number of designs to generate (overrides `--num_designs`) |
| `budget` | Integer | Number of final designs to keep (overrides `--budget`) |

### Example Samplesheet

```csv
sample,design_yaml,num_designs,budget
protein_binder,designs/egfr_binder.yaml,10000,50
nanobody_design,designs/spike_nanobody.yaml,5000,20
peptide_binder,designs/il6_peptide.yaml,3000,10
```

## :material-file-document: Design YAML Format

For Design mode, create YAML files following this structure:

```yaml
# Boltzgen design specification
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
--input            # Path to samplesheet CSV (required)
--outdir           # Output directory (required)
--mode             # Explicit mode: design, target, binder (optional, auto-detected)
```

### Design Parameters

```bash
--n_samples        # Number of designs per specification (default: 10)
--timesteps        # Diffusion timesteps (default: 100)
--save_traj        # Save trajectory files (default: false)
```

### Analysis Options

```bash
--run_ipsae        # Enable IPSAE scoring (default: false)
--run_prodigy      # Enable PRODIGY affinity prediction (default: false)
```

### Resource Management

```bash
--max_cpus         # Maximum CPUs (default: 16)
--max_memory       # Maximum memory (default: 128.GB)
--max_time         # Maximum time per job (default: 48.h)
```

## :material-folder-open: Output Structure

The pipeline creates an organized output directory:

```
results/
├── {sample_id}/
│   ├── boltzgen/
│   │   ├── final_ranked_designs/    # Your final designs ⭐
│   │   │   ├── design_1.cif
│   │   │   ├── design_2.cif
│   │   │   └── ...
│   │   ├── intermediate_designs/    # Intermediate outputs
│   │   │   └── ...
│   │   └── boltzgen.log            # Execution log
│   │
│   ├── prodigy/                     # If --run_prodigy enabled
│   │   ├── design_1_prodigy_results.txt
│   │   ├── design_1_prodigy_summary.csv
│   │   └── ...
│   │
│   └── ipsae/                       # If --run_ipsae enabled
│       └── design_1_ipsae_scores.csv
│
└── pipeline_info/
    ├── execution_report.html        # Execution summary
    ├── execution_timeline.html      # Timeline visualization
    └── execution_trace.txt          # Detailed trace
```

### Key Output Files

!!! tip "Most Important Files"
    - **Final designs**: `boltzgen/{sample}/final_ranked_designs/*.cif`
    - **Execution report**: `pipeline_info/execution_report.html`
    - **Affinity predictions**: `prodigy/{sample}/design_*_summary.csv`

## :material-play-circle: Example Workflows

### Example 1: Basic Protein Design

```bash
# 1. Create design YAML
cat > protein_design.yaml << EOF
name: egfr_binder
target:
  structure: data/egfr.pdb
  residues: [10, 11, 12, 45, 46]
designed:
  chain_type: protein
  length: [60, 100]
global:
  n_samples: 20
EOF

# 2. Create samplesheet
cat > samples.csv << EOF
sample,design_yaml
egfr_binder,protein_design.yaml
EOF

# 3. Run pipeline
nextflow run seqeralabs/nf-proteindesign \
    -profile docker \
    --input samples.csv \
    --outdir results
```

### Example 2: Multiple Designs with Analysis

```bash
# 1. Create design YAMLs for different targets
cat > egfr_design.yaml << EOF
name: egfr_binder
target:
  structure: data/egfr.pdb
  residues: [10, 11, 12, 45, 46]
designed:
  chain_type: protein
  length: [60, 120]
EOF

cat > spike_design.yaml << EOF
name: spike_nanobody
target:
  structure: data/spike.cif
  residues: [417, 484, 501]
designed:
  chain_type: nanobody
  length: [110, 130]
EOF

# 2. Create samplesheet
cat > samples.csv << EOF
sample,design_yaml,num_designs,budget
egfr_binder,egfr_design.yaml,10000,50
spike_nanobody,spike_design.yaml,5000,20
EOF

# 3. Run with analysis modules
nextflow run seqeralabs/nf-proteindesign \
    -profile docker \
    --input samples.csv \
    --outdir results \
    --run_proteinmpnn \
    --run_protenix_refold \
    --run_prodigy \
    --run_consolidation
```

### Example 3: Test Run

```bash
# Use built-in test profile
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
