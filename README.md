# nf-proteindesign

> [!WARNING]
> **Proof of Principle Pipeline**
> 
> This pipeline was developed by Seqera as a proof of principle using Seqera AI. It demonstrates the capabilities of AI-assisted bioinformatics pipeline development but should be thoroughly validated before use in production environments.

[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A523.04.0-23aa62.svg)](https://www.nextflow.io/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![Documentation](https://img.shields.io/badge/docs-mkdocs-blue)](https://seqeralabs.github.io/nf-proteindesign/)

> **📚 [Full Documentation](https://seqeralabs.github.io/nf-proteindesign/)** | **🚀 [Quick Start Guide](https://seqeralabs.github.io/nf-proteindesign/quick-start/)** | **📖 [User Guide](https://seqeralabs.github.io/nf-proteindesign/getting-started/usage/)**

## Introduction

**nf-proteindesign** is a Nextflow pipeline for high-throughput protein design using [Boltzgen](https://github.com/HannesStark/boltzgen), an all-atom generative diffusion model that designs proteins, peptides, and nanobodies to bind various biomolecular targets.

The pipeline uses pre-made design YAML specifications to generate protein designs in parallel, with optional downstream analysis modules for sequence optimization and quality assessment.

## Quick Start

```bash
# 1. Install Nextflow (>=23.04.0)
curl -s https://get.nextflow.io | bash

# 2. Test the pipeline (minimal resources)
nextflow run seqeralabs/nf-proteindesign \
    -profile test_design_protein,docker

# 3. Run with your data
nextflow run seqeralabs/nf-proteindesign \
    -profile docker \
    --input samplesheet.csv \
    --outdir results
```

> ⚠️ **GPU Required**: Boltzgen requires NVIDIA GPU with CUDA support. See [Installation Guide](https://seqeralabs.github.io/nf-proteindesign/getting-started/installation/) for setup details.

## Pipeline Features

### Core Capabilities
- ✅ **Parallel Design Processing**: Run multiple designs simultaneously
- ✅ **YAML-Based Configuration**: Use custom design specifications for full control
- ✅ **GPU-Accelerated**: Optimized for NVIDIA GPUs with CUDA

### Optional Analysis Modules
- 🧬 **ProteinMPNN**: Sequence optimization for designed structures
- 🔄 **Protenix**: Refold ProteinMPNN sequences for validation
- 📊 **ipSAE Scoring**: Evaluate protein-protein interface quality (Boltzgen + Protenix)
- ⚡ **PRODIGY**: Predict binding affinity (ΔG and Kd) for Boltzgen + Protenix structures
- 🔍 **Foldseek**: Search for structural homologs in AlphaFold/Swiss-Model databases (GPU-accelerated)
- 📈 **Consolidated Metrics**: Unified quality report across all analyses

## Test Profiles

Comprehensive tests using EGFR (PDB: 1IVO) with 3 test profiles for different design types:

```bash
# Test protein binder design
nextflow run seqeralabs/nf-proteindesign -profile test_design_protein,docker

# Test peptide binder design
nextflow run seqeralabs/nf-proteindesign -profile test_design_peptide,docker

# Test nanobody design
nextflow run seqeralabs/nf-proteindesign -profile test_design_nanobody,docker
```

### Test Profile Comparison

| Profile | Type | Designs | Budget | Runtime | Purpose |
|---------|------|---------|--------|---------|---------|
| `test_design_protein` | Protein | 5 | 2 | ~15 min | Test protein binder design |
| `test_design_peptide` | Peptide | 5 | 2 | ~15 min | Test peptide binder design |
| `test_design_nanobody` | Nanobody | 5 | 2 | ~15 min | Test nanobody design |

## Example Commands

### Basic Usage
```bash
nextflow run seqeralabs/nf-proteindesign \
    -profile docker \
    --input samplesheet_designs.csv \
    --outdir results
```

### With Optional Analysis Modules
```bash
nextflow run seqeralabs/nf-proteindesign \
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

The samplesheet must include `design_yaml` column with path to your custom design YAML file:
```csv
sample_id,design_yaml,num_designs,budget
protein_binder,designs/target1.yaml,10000,20
```

See [samplesheet documentation](https://flouwuenne.github.io/nf-proteindesign-2025/getting-started/usage/#samplesheet-format) for complete specifications.

## Key Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--input` | - | Path to samplesheet CSV (required) |
| `--outdir` | `./results` | Output directory |
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

- 📖 [Documentation](https://seqeralabs.github.io/nf-proteindesign/)
- 🐛 [Report Issues](https://github.com/seqeralabs/nf-proteindesign/issues)
- 💬 [Discussions](https://github.com/seqeralabs/nf-proteindesign/discussions)
