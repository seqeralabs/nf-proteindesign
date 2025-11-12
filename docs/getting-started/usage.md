# Basic Usage

This guide covers the fundamental concepts for using nf-proteindesign.

## :material-play: Basic Command Structure

```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile <PROFILE> \
    --input <SAMPLESHEET> \
    --outdir <OUTPUT_DIR> \
    [OPTIONS]
```

### Components

- **`-profile`**: Execution profile (`docker`, `singularity`, `test`)
- **`--input`**: Path to samplesheet CSV file
- **`--outdir`**: Output directory path
- **`[OPTIONS]`**: Additional pipeline parameters

## :material-file-table: Samplesheet Format

The samplesheet determines which mode the pipeline runs in.

### Mode Auto-Detection

The pipeline automatically detects the mode based on column headers:

| Column Present | Mode | Description |
|----------------|------|-------------|
| `design_yaml` | Design | Use pre-made YAML files |
| `target_structure` | Target | Generate design variants |
| `target_structure` + P2Rank | P2Rank | Predict binding sites |

### Required Columns by Mode

=== "Design Mode"
    | Column | Required | Description |
    |--------|----------|-------------|
    | `sample` | ✅ | Unique sample identifier |
    | `design_yaml` | ✅ | Path to design YAML file |

=== "Target Mode"
    | Column | Required | Description |
    |--------|----------|-------------|
    | `sample` | ✅ | Unique sample identifier |
    | `target_structure` | ✅ | Path to target structure (PDB/CIF) |
    | `target_residues` | Optional | Binding site residues (comma-separated) |
    | `chain_type` | Optional | Type: `protein`, `peptide`, `nanobody` |
    | `min_length` | Optional | Minimum binder length |
    | `max_length` | Optional | Maximum binder length |

=== "P2Rank Mode"
    | Column | Required | Description |
    |--------|----------|-------------|
    | `sample` | ✅ | Unique sample identifier |
    | `target_structure` | ✅ | Path to target structure (PDB/CIF) |
    | `chain_type` | Optional | Type: `protein`, `peptide`, `nanobody` |
    | `min_length` | Optional | Minimum binder length |
    | `max_length` | Optional | Maximum binder length |

## :material-file-document: Design YAML Format

For Design mode, create YAML files following this structure:

```yaml
name: my_design_name
target:
  structure: path/to/target.pdb
  residues: [10, 11, 12, 45, 46, 47]  # Binding site residues
designed:
  chain_type: protein  # Options: protein, peptide, nanobody
  length: [50, 100]    # [min_length, max_length]
global:
  n_samples: 20        # Number of designs to generate
  timesteps: 100       # Diffusion timesteps
  save_traj: false     # Save trajectory files
  seed: 42            # Random seed for reproducibility
```

## :material-cog: Common Parameters

### Essential Parameters

```bash
--input            # Path to samplesheet CSV (required)
--outdir           # Output directory (required)
--mode             # Explicit mode: design, target, p2rank (optional, auto-detected)
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

### Example 1: Simple Design Mode

```bash
# 1. Create design YAML
cat > my_design.yaml << EOF
name: antibody_target
target:
  structure: data/target.pdb
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
design1,my_design.yaml
EOF

# 3. Run pipeline
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --input samples.csv \
    --outdir results
```

### Example 2: Target Mode with Analysis

```bash
# 1. Create samplesheet
cat > targets.csv << EOF
sample,target_structure,target_residues,chain_type,min_length,max_length
egfr,data/egfr.pdb,"10,11,12,45,46",protein,60,120
spike,data/spike.cif,"417,484,501",nanobody,110,130
EOF

# 2. Run with affinity prediction
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --mode target \
    --input targets.csv \
    --outdir results \
    --n_samples 30 \
    --run_prodigy
```

### Example 3: P2Rank Discovery

```bash
# 1. Create samplesheet
cat > unknown_targets.csv << EOF
sample,target_structure,chain_type,min_length,max_length
unknown1,data/target1.pdb,protein,50,100
unknown2,data/target2.pdb,nanobody,110,130
EOF

# 2. Run with P2Rank
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --mode p2rank \
    --input unknown_targets.csv \
    --outdir results \
    --p2rank_top_n 3 \
    --n_samples 20
```

## :material-refresh: Resume Failed Runs

Nextflow can resume from the last successful step:

```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
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
nextflow run FloWuenne/nf-proteindesign-2025 \
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

# Singularity with custom settings
nextflow run ... -profile singularity,custom
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

- Learn about [Pipeline Modes](../modes/overview.md) in detail
- Check the [Quick Reference](quick-reference.md) for common commands
- Explore [Analysis Tools](../analysis/prodigy.md) integration

---

!!! question "Need Help?"
    - See [Quick Reference](quick-reference.md) for command templates
    - Check [GitHub Issues](https://github.com/FloWuenne/nf-proteindesign-2025/issues)
