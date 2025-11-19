# nf-proteindesign

[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A523.04.0-23aa62.svg)](https://www.nextflow.io/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)
[![Documentation](https://img.shields.io/badge/docs-mkdocs-blue)](https://flouwuenne.github.io/nf-proteindesign-2025/)

> **📚 [Full Documentation](https://flouwuenne.github.io/nf-proteindesign-2025/)** | **🚀 [Quick Start Guide](https://flouwuenne.github.io/nf-proteindesign-2025/quick-start/)** | **📖 [User Guide](https://flouwuenne.github.io/nf-proteindesign-2025/getting-started/usage/)**

## Introduction

**nf-proteindesign** is a Nextflow pipeline for high-throughput protein design using [Boltzgen](https://github.com/HannesStark/boltzgen), an all-atom generative diffusion model that designs proteins, peptides, and nanobodies to bind various biomolecular targets.

### Two Operational Modes

The pipeline features a **unified workflow architecture** with two entry points:

1. **🎯 Design Mode**: Use pre-made design YAML specifications
2. **📐 Target Mode**: Auto-generate design variants from target structures

Both modes converge to the same core workflow for consistent, parallel execution.

## Quick Start

```bash
# 1. Install Nextflow (>=23.04.0)
curl -s https://get.nextflow.io | bash

# 2. Test the pipeline (minimal resources)
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile test_design,docker

# 3. Run with your data
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --input samplesheet.csv \
    --outdir results
```

> ⚠️ **GPU Required**: Boltzgen requires NVIDIA GPU with CUDA support. See [Installation Guide](https://flouwuenne.github.io/nf-proteindesign-2025/getting-started/installation/) for setup details.

## Pipeline Features

### Core Capabilities
- ✅ **Parallel Design Processing**: Run multiple designs simultaneously
- ✅ **Two Flexible Modes**: Pre-made configs or auto-generated variants
- ✅ **Automatic Mode Detection**: Pipeline auto-detects mode from samplesheet headers
- ✅ **GPU-Accelerated**: Optimized for NVIDIA GPUs with CUDA

### Optional Analysis Modules
- 🧬 **ProteinMPNN**: Sequence optimization for designed structures
- 📊 **ipSAE Scoring**: Evaluate protein-protein interface quality
- ⚡ **PRODIGY**: Predict binding affinity (ΔG and Kd)
- 📈 **Consolidated Metrics**: Unified quality report across all analyses

## Test Profiles

Comprehensive tests using EGFR (PDB: 1IVO):

```bash
# Test Design Mode - Quick validation (15-20 minutes)
nextflow run FloWuenne/nf-proteindesign-2025 -profile test_design,docker

# Test Target Mode - Auto-generation (30-45 minutes) 
nextflow run FloWuenne/nf-proteindesign-2025 -profile test_target,docker

# Test Production Scale - Full production run (4-8 hours)
nextflow run FloWuenne/nf-proteindesign-2025 -profile test_production,docker
```

### Test Profile Comparison

| Profile | Mode | Designs | Budget | Runtime | Purpose |
|---------|------|---------|--------|---------|---------|
| `test_design` | Design | 10 | 2 | ~20 min | Quick validation of design mode |
| `test_target` | Target | 10 | 2 | ~45 min | Test auto-generation features |
| `test_production` | Design | 10,000 | 10 | ~6 hrs | Validate production-scale workflow |

## Example Commands

### Design Mode (Pre-made YAMLs)
```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --mode design \
    --input samplesheet_designs.csv \
    --num_designs 10000 \
    --budget 50 \
    --outdir results
```

### Target Mode (Auto-generate Variants)
```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --mode target \
    --input samplesheet_targets.csv \
    --min_design_length 50 \
    --max_design_length 150 \
    --design_type protein \
    --outdir results
```

### With Optional Analysis Modules
```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --input samplesheet.csv \
    --run_proteinmpnn \
    --run_ipsae \
    --run_prodigy \
    --run_consolidation \
    --outdir results
```

## Documentation

📚 **Complete documentation available at:** [https://flouwuenne.github.io/nf-proteindesign-2025/](https://flouwuenne.github.io/nf-proteindesign-2025/)

### Key Documentation Pages

- **[Quick Start Guide](https://flouwuenne.github.io/nf-proteindesign-2025/quick-start/)** - Get started in minutes
- **[Installation](https://flouwuenne.github.io/nf-proteindesign-2025/getting-started/installation/)** - Setup and requirements
- **[Usage Guide](https://flouwuenne.github.io/nf-proteindesign-2025/getting-started/usage/)** - Detailed usage instructions
- **[Pipeline Modes](https://flouwuenne.github.io/nf-proteindesign-2025/modes/overview/)** - Design, Target modes
- **[Analysis Tools](https://flouwuenne.github.io/nf-proteindesign-2025/analysis/ipsae/)** - Optional analysis modules
- **[Parameters Reference](https://flouwuenne.github.io/nf-proteindesign-2025/reference/parameters/)** - Complete parameter list
- **[Output Files](https://flouwuenne.github.io/nf-proteindesign-2025/reference/outputs/)** - Understanding results
- **[Examples](https://flouwuenne.github.io/nf-proteindesign-2025/reference/examples/)** - Real-world use cases

## Samplesheet Format

**Design Mode** - requires `design_yaml` column:
```csv
sample_id,design_yaml,num_designs,budget
protein_binder,designs/target1.yaml,10000,20
```

**Target Mode** - requires `target_structure` column:
```csv
sample_id,target_structure,target_chain_ids,design_type
protein1,structures/target1.pdb,A,protein
```

See [samplesheet documentation](https://flouwuenne.github.io/nf-proteindesign-2025/getting-started/usage/#samplesheet-format) for complete specifications.

## Key Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--input` | - | Path to samplesheet CSV (required) |
| `--outdir` | `./results` | Output directory |
| `--mode` | auto-detect | Mode: `design` or `target` |
| `--num_designs` | `100` | Number of intermediate designs (use 10,000-60,000 for production) |
| `--budget` | `10` | Number of final diversity-optimized designs |
| `--protocol` | `protein-anything` | Design protocol |
| `--run_proteinmpnn` | `false` | Enable sequence optimization |
| `--run_ipsae` | `false` | Enable interface scoring |
| `--run_prodigy` | `false` | Enable binding affinity prediction |
| `--run_consolidation` | `false` | Generate unified metrics report |

See [complete parameter reference](https://flouwuenne.github.io/nf-proteindesign-2025/reference/parameters/) for all options.

## Output Structure

```
results/
└── sample_id/
    ├── sample_id_output/
    │   ├── intermediate_designs/              # Initial designs
    │   ├── intermediate_designs_inverse_folded/ # After inverse folding
    │   │   └── refold_cif/                    # Main structures for analysis
    │   └── final_ranked_designs/              # Quality-filtered results
    │       └── final_<budget>_designs/        # Top designs
    ├── proteinmpnn/                           # ProteinMPNN outputs (if enabled)
    ├── ipsae_scores/                          # ipSAE scores (if enabled)
    ├── prodigy/                               # PRODIGY predictions (if enabled)
    └── consolidated_metrics/                  # Unified report (if enabled)
```

See [output documentation](https://flouwuenne.github.io/nf-proteindesign-2025/reference/outputs/) for detailed descriptions.

## Performance

**Timing on NVIDIA A100** (per design):
- Design generation: ~few seconds
- Inverse folding: ~few seconds  
- Refolding: ~few seconds
- Filtering: ~15 seconds (CPU)
- **Total**: ~10-20 seconds per design

**Recommended Settings:**
- **Test runs**: `--num_designs 50 --budget 5`
- **Production runs**: `--num_designs 10000-60000 --budget 50-100`

## Resource Requirements

- **GPU**: NVIDIA GPU with CUDA support (tested on A100)
- **Memory**: 64-128 GB RAM recommended
- **Storage**: 1-10 GB per design run
- **Cache**: ~6 GB for initial model download

## Citations

If you use this pipeline, please cite:

**Boltzgen**:  
> Stark, H., Lee, B., Shuaibi, M., Errica, F., et al. (2024). BoltzGen: Generative Diffusion for Biomolecular Complexes. [Paper](https://hannes-stark.com/assets/boltzgen.pdf)

**Nextflow**:  
> Di Tommaso, P., Chatzou, M., Floden, E. W., et al. (2017). Nextflow enables reproducible computational workflows. *Nature Biotechnology*, 35(4), 316-319. [doi:10.1038/nbt.3820](https://doi.org/10.1038/nbt.3820)

## Credits

**nf-proteindesign** was created by Florian Wuennemann.

This pipeline uses [Boltzgen](https://github.com/HannesStark/boltzgen) developed by the MIT Jameel Clinic and collaborators.

## License

This pipeline is released under the MIT License. See [LICENSE](LICENSE) for details.

## Support

- 📖 [Documentation](https://flouwuenne.github.io/nf-proteindesign-2025/)
- 🐛 [Report Issues](https://github.com/FloWuenne/nf-proteindesign-2025/issues)
- 💬 [Discussions](https://github.com/FloWuenne/nf-proteindesign-2025/discussions)
