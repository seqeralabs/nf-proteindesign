# Quick Start Guide

Get started with nf-proteindesign in 5 minutes!

## ⚠️ GPU Requirement

**Boltzgen requires NVIDIA GPU with CUDA support.** This pipeline cannot run on CPU-only systems.

## Prerequisites Checklist

- [ ] Nextflow >= 23.04.0 installed
- [ ] Docker OR Singularity installed
- [ ] NVIDIA GPU available
- [ ] GPU configured for container access

## 5-Minute Setup

### 1. Test GPU Access

**Docker:**
```bash
docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi
```

**Singularity:**
```bash
singularity exec --nv docker://nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi
```

If this fails, GPU is not properly configured. See [USAGE.md](USAGE.md#troubleshooting) for help.

### 2. Prepare Your Design

Create a design YAML file (or use examples in `assets/design_examples/`):

**protein_design.yaml:**
```yaml
entities:
  - protein: 
      id: C
      sequence: 80..120
  - file:
      path: target.cif  # Your target structure
      include: 
        - chain:
            id: A
```

### 3. Create Samplesheet

**samplesheet.csv:**
```csv
sample_id,design_yaml,protocol,num_designs,budget
test_design,protein_design.yaml,protein-anything,10,2
```

### 4. Run Test

```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --input samplesheet.csv \
    --outdir test_results
```

### 5. Check Results

```bash
# View final designs
ls test_results/test_design/test_design_output/final_ranked_designs/final_2_designs/

# View summary PDF
open test_results/test_design/test_design_output/final_ranked_designs/results_overview.pdf
```

## Production Run

Once test succeeds, increase design numbers:

```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --input samplesheet.csv \
    --outdir results \
    --num_designs 20000 \
    --budget 50
```

## What Gets Generated?

For each sample, you get:

```
results/
└── sample_id/
    └── sample_id_output/
        ├── intermediate_designs/              # Initial designs
        ├── intermediate_designs_inverse_folded/ # After inverse folding
        │   └── refold_cif/                   # Refolded structures
        └── final_ranked_designs/              # ⭐ MAIN RESULTS
            ├── final_<budget>_designs/        # ⭐ Use these designs!
            │   ├── design_XXXX.cif
            │   └── ...
            ├── final_designs_metrics.csv      # Design metrics
            └── results_overview.pdf           # Visual summary
```

**Key files:**
- `final_<budget>_designs/*.cif` - Your designed protein structures
- `results_overview.pdf` - Quality and diversity plots
- `final_designs_metrics.csv` - Detailed metrics

## Common Issues

### GPU not detected
```bash
# Docker: Install NVIDIA Container Toolkit
# https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html

# Singularity: Ensure --nv support is enabled
```

### Out of memory
```bash
# Reduce num_designs or increase --max_memory
nextflow run ... --num_designs 5000 --max_memory 128.GB
```

### Pipeline hangs
```bash
# Increase timeout
nextflow run ... --max_time 72.h
```

## Next Steps

- Read [USAGE.md](USAGE.md) for detailed instructions
- See [README.md](README.md) for parameter descriptions
- Check `assets/design_examples/` for more complex designs
- Join [Boltzgen Slack](https://boltz.bio/join-slack) for help

## Example Workflows

### Multiple Targets in Parallel

**samplesheet.csv:**
```csv
sample_id,design_yaml,protocol,num_designs,budget
target1,designs/target1.yaml,protein-anything,20000,30
target2,designs/target2.yaml,protein-anything,20000,30
target3,designs/target3.yaml,protein-anything,20000,30
```

```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --input samplesheet.csv \
    --outdir results
```

All samples run in parallel (limited by available GPUs).

### Different Design Strategies

**samplesheet.csv:**
```csv
sample_id,design_yaml,protocol,num_designs,budget
protein_binder,designs/target_protein.yaml,protein-anything,20000,30
peptide_binder,designs/target_peptide.yaml,peptide-anything,15000,20
nanobody,designs/target_nanobody.yaml,nanobody-anything,25000,40
```

Test different approaches to the same target in one run.

## Help & Support

- **Pipeline Issues**: [GitHub Issues](https://github.com/FloWuenne/nf-proteindesign-2025/issues)
- **Boltzgen Questions**: [Boltzgen Slack](https://boltz.bio/join-slack)
- **Nextflow Help**: [Nextflow Slack](https://www.nextflow.io/slack.html)

## Tips

1. **Always test first**: Use `--num_designs 10 --budget 2` for initial runs
2. **Use resume**: Add `-resume` to restart interrupted runs
3. **Monitor resources**: Check GPU memory usage with `nvidia-smi`
4. **Organize files**: Keep design YAMLs in a dedicated directory
5. **Review metrics**: Don't just pick top designs - review diversity too

Happy protein designing! 🧬🔬
