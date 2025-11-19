# Quick Reference Guide

Fast reference for common commands and configurations.

## :material-flash: One-Line Commands

### Basic Run

```bash
# Simplest possible run (auto-detects mode)
nextflow run seqeralabs/nf-proteindesign -profile docker --input samplesheet.csv --outdir results
```

### With Analysis

```bash
# Include affinity prediction and scoring
nextflow run seqeralabs/nf-proteindesign -profile docker --input samplesheet.csv --outdir results --run_prodigy --run_ipsae
```

### Resume Failed Run

```bash
# Resume from where it stopped
nextflow run seqeralabs/nf-proteindesign -profile docker --input samplesheet.csv --outdir results -resume
```

## :material-file-table: Samplesheet Templates

=== "Design Mode"
    ```csv
    sample,design_yaml
    design1,designs/my_design.yaml
    design2,designs/another_design.yaml
    ```

=== "Target Mode (Minimal)"
    ```csv
    sample,target_structure
    target1,data/target1.pdb
    target2,data/target2.cif
    ```

=== "Target Mode (Full)"
    ```csv
    sample,target_structure,target_residues,chain_type,min_length,max_length
    egfr,data/egfr.pdb,"10,11,12,45,46",protein,60,120
    spike,data/spike.cif,"417,484,501",nanobody,110,130
    ```

=== ""
    ```csv
    sample,target_structure,chain_type,min_length,max_length
    unknown1,data/target1.pdb,protein,50,100
    unknown2,data/target2.pdb,nanobody,110,130
    ```

## :material-cog: Common Parameters

### Essential Parameters

| Parameter | Description | Default | Example |
|-----------|-------------|---------|---------|
| `--input` | Samplesheet path | Required | `samplesheet.csv` |
| `--outdir` | Output directory | Required | `results/` |
| `--mode` | Pipeline mode | Auto-detect | `design`, `target`,  |

### Design Parameters

| Parameter | Description | Default | Example |
|-----------|-------------|---------|---------|
| `--n_samples` | Designs per specification | 10 | `50` |
| `--timesteps` | Diffusion timesteps | 100 | `200` |
| `--save_traj` | Save trajectories | false | `true` |

### Target Mode Parameters

| Parameter | Description | Default | Example |
|-----------|-------------|---------|---------|
| `--min_design_length` | Minimum binder length | 50 | `60` |
| `--max_design_length` | Maximum binder length | 150 | `120` |
| `--length_step` | Length increment | 20 | `10` |
| `--n_variants_per_length` | Variants per length | 3 | `5` |
| `--chain_type` | Designed chain type | protein | `peptide`, `nanobody` |

| Parameter | Description | Default | Example |
|-----------|-------------|---------|---------|

### Analysis Parameters

| Parameter | Description | Default | Example |
|-----------|-------------|---------|---------|
| `--run_ipsae` | Enable IPSAE scoring | false | `true` |
| `--run_prodigy` | Enable PRODIGY | false | `true` |
| `--prodigy_selection` | Chain selection | Auto | `'A,B'` |

### Resource Parameters

| Parameter | Description | Default | Example |
|-----------|-------------|---------|---------|
| `--max_cpus` | Maximum CPUs | 16 | `32` |
| `--max_memory` | Maximum memory | 128.GB | `256.GB` |
| `--max_time` | Maximum time | 48.h | `72.h` |

## :material-play: Command Recipes

### Quick Test (2 minutes)

```bash
nextflow run seqeralabs/nf-proteindesign \
    -profile docker \
    --input test.csv \
    --mode target \
    --n_samples 5 \
    --min_design_length 60 \
    --max_design_length 80 \
    --length_step 20 \
    --n_variants_per_length 1 \
    --outdir test_results
```

### Standard Run (30-60 minutes)

```bash
nextflow run seqeralabs/nf-proteindesign \
    -profile docker \
    --input samplesheet.csv \
    --n_samples 20 \
    --run_prodigy \
    --outdir results
```

### Production Run (several hours)

```bash
nextflow run seqeralabs/nf-proteindesign \
    -profile docker \
    --input samplesheet.csv \
    --mode target \
    --min_design_length 50 \
    --max_design_length 150 \
    --length_step 10 \
    --n_variants_per_length 5 \
    --n_samples 100 \
    --run_prodigy \
    --run_ipsae \
    --outdir production_results
```

### Peptide Design

```bash
nextflow run seqeralabs/nf-proteindesign \
    -profile docker \
    --input peptides.csv \
    --mode target \
    --chain_type peptide \
    --min_design_length 10 \
    --max_design_length 30 \
    --length_step 5 \
    --n_samples 50 \
    --outdir peptide_designs
```

### Nanobody Discovery

```bash
nextflow run seqeralabs/nf-proteindesign \
    -profile docker \
    --input targets.csv \
    --chain_type nanobody \
    --min_design_length 110 \
    --max_design_length 130 \
    --n_samples 30 \
    --outdir nanobody_designs
```

## :material-folder-open: Output Structure

```
results/
├── {sample}/
│   ├── boltzgen/
│   │   ├── final_ranked_designs/    ← Your final designs
│   │   │   ├── design_1.cif
│   │   │   ├── design_2.cif
│   │   │   └── ...
│   │   ├── intermediate_designs/
│   │   └── boltzgen.log
│   ├── prodigy/
│   │   ├── design_1_prodigy_summary.csv
│   │   └── ...
│   └── ipsae/
│       └── design_1_ipsae_scores.csv
└── pipeline_info/
    ├── execution_report.html        ← Check this first
    ├── execution_timeline.html
    └── execution_trace.txt
```

## :material-bug: Troubleshooting Quick Fixes

### GPU Not Found

```bash
# Test GPU access
docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi

# If fails, install nvidia-container-toolkit
# https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html
```

### Out of Memory

```bash
# Reduce parallel samples
nextflow run ... --n_samples 10  # Lower value

# Increase available memory
nextflow run ... --max_memory 64.GB
```

### Pipeline Fails Mid-Run

```bash
# Resume from last checkpoint
nextflow run seqeralabs/nf-proteindesign \
    -profile docker \
    --input samplesheet.csv \
    --outdir results \
    -resume  # ← Add this flag
```

### Container Pull Issues

```bash
# Pre-pull containers
docker pull ghcr.io/flouwuenne/boltzgen:latest
docker pull ghcr.io/flouwuenne/prodigy:latest
```

## :material-file-code: Design YAML Template

```yaml title="design_template.yaml"
name: my_protein_design
target:
  structure: data/target_protein.pdb
  residues: [10, 11, 12, 45, 46, 47]  # Binding site
designed:
  chain_type: protein  # or 'peptide', 'nanobody'
  length: [50, 100]    # [min, max] length range
global:
  n_samples: 20
  timesteps: 100
  save_traj: false
  seed: 42
```

## :material-chart-line: Performance Estimates

| Configuration | Designs | Time (1 GPU) | GPU Memory |
|---------------|---------|--------------|------------|
| Quick test | 5 | 2-5 min | 8GB |
| Standard | 20-50 | 20-60 min | 16GB |
| Production | 100+ | 2-6 hours | 16-24GB |
| Large campaign | 500+ | 12-24 hours | 24GB+ |

## :material-console: Useful Commands

### Check Pipeline Status

```bash
# List running processes
nextflow log

# View specific run
nextflow log <run_name> -f workdir,status,exit

# Clean work directory
nextflow clean -f
```

### Monitor Resources

```bash
# Watch GPU usage
watch -n 1 nvidia-smi

# Check disk usage
du -sh results/ work/

# Monitor memory
free -h
```

### Analyze Results

```bash
# Count final designs
find results/ -name "*.cif" -path "*/final_ranked_designs/*" | wc -l

# Find best PRODIGY scores
cat results/*/prodigy/*_summary.csv | \
    grep -v "sample_id" | \
    sort -t',' -k3,3n | \
    head -5

# Check pipeline status
grep "Succeeded" results/pipeline_info/execution_trace.txt | wc -l
```

## :material-link: Quick Links

- [Full Documentation](../index.md)
- [Pipeline Modes](../modes/overview.md)
- [Parameter Reference](../reference/parameters.md)
- [Example Workflows](../reference/examples.md)
- [GitHub Repository](https://github.com/seqeralabs/nf-proteindesign)

---

!!! tip "Bookmark This Page"
    This quick reference covers 90% of common use cases. Keep it handy!
