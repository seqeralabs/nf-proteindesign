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

## :material-file-table: Samplesheet Template

```csv
sample_id,design_yaml,structure_files,protocol,num_designs,budget
design1,designs/my_design.yaml,data/target.pdb,protein-anything,100,10
design2,designs/another_design.yaml,data/target.cif,peptide-anything,100,10
```

**Required columns:**
- `sample_id`: Unique identifier for the design
- `design_yaml`: Path to Boltzgen design YAML specification

**Optional columns:**
- `structure_files`: Additional structure files (comma-separated if multiple)
- `protocol`: Boltzgen protocol (protein-anything, peptide-anything, nanobody-anything, protein-small_molecule)
- `num_designs`: Number of intermediate designs (default: 100)
- `budget`: Number of final diversity-optimized designs (default: 10)

## :material-cog: Common Parameters

### Essential Parameters

| Parameter | Description | Default | Example |
|-----------|-------------|---------|---------|
| `--input` | Samplesheet path | Required | `samplesheet.csv` |
| `--outdir` | Output directory | `./results` | `results/` |
| `--protocol` | Boltzgen protocol | `protein-anything` | `peptide-anything` |

### Design Parameters

| Parameter | Description | Default | Example |
|-----------|-------------|---------|---------|
| `--num_designs` | Intermediate designs | 100 | `50` |
| `--budget` | Final optimized designs | 10 | `20` |
| `--cache_dir` | Model cache directory | `null` | `/cache` |

### Analysis Parameters

| Parameter | Description | Default | Example |
|-----------|-------------|---------|---------|
| `--run_proteinmpnn` | Enable ProteinMPNN | false | `true` |
| `--run_ipsae` | Enable IPSAE scoring | false | `true` |
| `--run_prodigy` | Enable PRODIGY | false | `true` |
| `--run_consolidation` | Consolidated report | false | `true` |

### Resource Parameters

| Parameter | Description | Default | Example |
|-----------|-------------|---------|---------|
| `--max_cpus` | Maximum CPUs | 16 | `32` |
| `--max_memory` | Maximum memory | 128.GB | `256.GB` |
| `--max_time` | Maximum time | 240.h | `72.h` |

## :material-play: Command Recipes

### Quick Test

```bash
nextflow run seqeralabs/nf-proteindesign \
    -profile test_design_protein,docker \
    --outdir test_results
```

### Standard Run

```bash
nextflow run seqeralabs/nf-proteindesign \
    -profile docker \
    --input samplesheet.csv \
    --outdir results
```

### With Analysis Tools

```bash
nextflow run seqeralabs/nf-proteindesign \
    -profile docker \
    --input samplesheet.csv \
    --outdir results \
    --run_proteinmpnn \
    --run_ipsae \
    --run_prodigy \
    --run_consolidation
```

### Peptide Design

```bash
nextflow run seqeralabs/nf-proteindesign \
    -profile docker \
    --input peptide_samplesheet.csv \
    --protocol peptide-anything \
    --outdir peptide_designs
```

### Nanobody Design

```bash
nextflow run seqeralabs/nf-proteindesign \
    -profile docker \
    --input nanobody_samplesheet.csv \
    --protocol nanobody-anything \
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
# Boltzgen design specification
entities:
  # Designed protein entity
  - protein:
      id: C
      sequence: 80..120  # Length range for designed protein
  
  # Target structure entity
  - file:
      path: target_protein.cif
      include:
        - chain:
            id: A  # Target chain to bind
```

See the [Boltzgen documentation](https://github.com/generatebio/boltz#-design-specification) for complete YAML specification details.

## :material-chart-line: Performance Estimates

| Configuration | num_designs | budget | Time (1 GPU) | GPU Memory |
|---------------|-------------|--------|--------------|------------|
| Quick test | 5-10 | 2-5 | 5-10 min | 8GB |
| Standard | 50-100 | 10 | 30-60 min | 16GB |
| Production | 100-200 | 20 | 1-3 hours | 16-24GB |
| Large campaign | 200+ | 50+ | 4-12 hours | 24GB+ |

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
- [Basic Usage](usage.md)
- [Parameter Reference](../reference/parameters.md)
- [Example Workflows](../reference/examples.md)
- [Analysis Modules](../analysis/proteinmpnn-protenix.md)
- [GitHub Repository](https://github.com/seqeralabs/nf-proteindesign)

---

!!! tip "Bookmark This Page"
    This quick reference covers 90% of common use cases. Keep it handy!
