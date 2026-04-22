# Quick Reference Guide

Fast reference for common commands and configurations.

## :material-flash: One-Line Commands

### Basic Run (BoltzGen, default)

```bash
# Simplest possible run — uses BoltzGen with all analysis modules enabled by default
nextflow run seqeralabs/nf-proteindesign -profile docker --input samplesheet.csv --outdir results
```

### Run with Complexa

```bash
# Use Proteina-Complexa backend
nextflow run seqeralabs/nf-proteindesign -profile docker --protein_design_tool complexa --input samplesheet_complexa.csv --complexa_ckpt_dir /path/to/ckpts --outdir results
```

### Resume Failed Run

```bash
# Resume from where it stopped
nextflow run seqeralabs/nf-proteindesign -profile docker --input samplesheet.csv --outdir results -resume
```

## :material-file-table: Samplesheet Templates

### BoltzGen (default)

```csv
sample_id,design_yaml,structure_files,protocol,num_designs,budget,reuse,target_msa,target_sequence,target_template
design1,designs/my_design.yaml,data/target.cif,protein-anything,3,2,,target.a3m,data/target.fasta,
```

**Required:** `sample_id`, `design_yaml`, `target_sequence`

**Optional:** `structure_files`, `protocol`, `num_designs`, `budget`, `reuse`, `target_msa`, `target_template`

### Complexa

```csv
sample_id,target_pdb,pipeline_config,target_sequence,target_msa,target_template
design1,target.cif,configs/pipeline.yaml,target.fasta,target.a3m,
```

**Required:** `sample_id`, `target_pdb`, `pipeline_config`, `target_sequence`

**Optional:** `target_msa`, `target_template`

## :material-cog: Common Parameters

### Essential Parameters

| Parameter | Description | Default | Example |
|-----------|-------------|---------|---------|
| `--input` | Samplesheet path | Required | `samplesheet.csv` |
| `--outdir` | Output directory | `./results` | `results/` |
| `--protein_design_tool` | Design backend | `boltzgen` | `complexa` |

### BoltzGen Parameters

| Parameter | Description | Default | Example |
|-----------|-------------|---------|---------|
| `--cache_dir` | BoltzGen model cache | `null` | `/cache` |

### Complexa Parameters

| Parameter | Description | Default | Example |
|-----------|-------------|---------|---------|
| `--complexa_ckpt_dir` | Checkpoint directory | `null` | `/path/to/ckpts` |
| `--complexa_search_algorithm` | Search algorithm | `best-of-n` | `beam-search` |
| `--complexa_nsteps` | Diffusion steps | `400` | `200` |
| `--complexa_batch_size` | Batch size | `16` | `8` |

### Analysis Parameters (all enabled by default)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `--run_proteinmpnn` | ProteinMPNN optimization | `true` |
| `--run_boltz2_refold` | Boltz-2 structure prediction | `true` |
| `--run_ipsae` | IPSAE interface scoring | `true` |
| `--run_prodigy` | PRODIGY affinity prediction | `true` |
| `--run_foldseek` | Foldseek structural search | `true` |
| `--run_consolidation` | Consolidated report | `true` |

### Resource Parameters

| Parameter | Description | Default | Example |
|-----------|-------------|---------|---------|
| `--max_cpus` | Maximum CPUs | `16` | `32` |
| `--max_memory` | Maximum memory | `128.GB` | `256.GB` |
| `--max_time` | Maximum time | `240.h` | `72.h` |
| `--max_gpus` | Maximum GPUs per process | `1` | `2` |

## :material-play: Command Recipes

### Quick Test

```bash
nextflow run seqeralabs/nf-proteindesign \
    -profile test_design_protein,docker \
    --outdir test_results
```

### Standard Run (BoltzGen)

```bash
nextflow run seqeralabs/nf-proteindesign \
    -profile docker \
    --input samplesheet.csv \
    --outdir results
```

### Standard Run (Complexa)

```bash
nextflow run seqeralabs/nf-proteindesign \
    -profile docker \
    --protein_design_tool complexa \
    --input samplesheet_complexa.csv \
    --complexa_ckpt_dir /path/to/checkpoints \
    --outdir results
```

### Design Only (skip analysis)

```bash
nextflow run seqeralabs/nf-proteindesign \
    -profile docker \
    --input samplesheet.csv \
    --outdir results \
    --run_proteinmpnn false
```

## :material-folder-open: Output Structure

```
results/
├── {sample}/
│   ├── boltzgen/ or complexa/       ← Design outputs (depends on tool)
│   ├── proteinmpnn/                  ← Optimized sequences
│   ├── boltz2/                       ← Refolded structures
│   ├── ipsae/                        ← Interface scores
│   ├── prodigy/                      ← Affinity predictions
│   ├── foldseek/                     ← Structural search results
│   └── consolidated/                 ← Combined metrics report
└── pipeline_info/
    ├── execution_report.html         ← Check this first
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
# Pre-pull containers — check nextflow.config for exact URIs
# for each process in conf/base.config
```

## :material-file-code: Design YAML Template (BoltzGen)

```yaml title="design_template.yaml"
# BoltzGen design specification
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

See the [BoltzGen documentation](https://github.com/jostorge/boltz) and [Complexa documentation](https://github.com/Proteina-AI/complexa) for complete specification details.

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
- [Analysis Modules](../analysis/proteinmpnn-boltz2.md)
- [GitHub Repository](https://github.com/seqeralabs/nf-proteindesign)

---

!!! tip "Bookmark This Page"
    This quick reference covers 90% of common use cases. Keep it handy!
