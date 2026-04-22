# 🧬 nf-proteindesign

> ⚠️ **IMPORTANT**: This pipeline was developed by Seqera as a proof of principle using Seqera AI. It demonstrates the capabilities of AI-assisted bioinformatics pipeline development but should be thoroughly validated before use in production environments.

A Nextflow pipeline for AI-powered protein design using Proteina-Complexa to design protein binders, nanobodies, and peptides.

## 📋 Overview

This pipeline automates the process of designing novel protein binders using Proteina-Complexa and provides comprehensive analysis through optional modules:

- 🎯 **Complexa Design**: Generate protein, nanobody, or peptide binders for target structures
- 🧬 **ProteinMPNN**: Optimize sequences for improved stability and expression
- 🔄 **Boltz-2 Refolding**: Validate designs through structure prediction
- 📊 **IPSAE**: Score protein-protein interface quality
- ⚡ **PRODIGY**: Predict binding affinity
- 🔍 **Foldseek**: Search structural databases for similar designs
- 📈 **Metrics Consolidation**: Generate comprehensive analysis reports

## 🚀 Quick Start

### ✅ Prerequisites

- ⚙️ Nextflow (≥23.10)
- 🐳 Docker or Singularity
- 🎮 GPU recommended for optimal performance

### 🧪 Running with Test Profiles

Test the pipeline with one of three available profiles:

```bash
# Test protein binder design
nextflow run main.nf -profile test_design_protein,docker

# Test nanobody binder design
nextflow run main.nf -profile test_design_nanobody,docker

# Test peptide binder design
nextflow run main.nf -profile test_design_peptide,docker
```

Replace `docker` with `singularity` if using Singularity containers.

### 🔬 Running with Your Own Data

```bash
nextflow run main.nf \
  --input samplesheet.csv \
  --outdir results \
  -profile docker
```

## 📝 Input Format

The pipeline requires a CSV samplesheet with design specifications. See `assets/test_data/` for examples:

```csv
sample_id,target_pdb,pipeline_config,target_sequence,target_msa,target_template
my_design,target.pdb,configs/search_binder_local_pipeline.yaml,target.fasta,,
```

| Column | Required | Description |
|--------|----------|-------------|
| `sample_id` | ✅ | Unique sample identifier |
| `target_pdb` | ✅ | Target structure (PDB or CIF) |
| `pipeline_config` | ✅ | Complexa Hydra pipeline config YAML |
| `target_sequence` | ✅ | Target sequence FASTA (for Boltz-2 refolding) |
| `target_msa` | | Pre-computed MSA for target (e.g., `.a3m`) |
| `target_template` | | Template structure for Boltz-2 (PDB/CIF) |

## ⚙️ Key Parameters

- `--input`: Path to samplesheet CSV
- `--outdir`: Output directory (default: `./results`)
- `--complexa_ckpt_dir`: Path to Complexa model checkpoint directory
- `--complexa_search_algorithm`: Search algorithm (`best-of-n`, `beam-search`, etc.)
- `--complexa_nsteps`: Diffusion sampling steps (default: 400)
- `--complexa_batch_size`: Generation batch size (default: 16)
- `--run_proteinmpnn`: Enable ProteinMPNN sequence optimization
- `--run_boltz2_refold`: Enable Boltz-2 structure prediction
- `--run_ipsae`: Enable IPSAE interface scoring
- `--run_prodigy`: Enable PRODIGY affinity prediction
- `--run_foldseek`: Enable Foldseek structural similarity search
- `--run_consolidation`: Generate consolidated metrics report

See `nextflow.config` for all available parameters.

## 📁 Output

Results are organized by sample in the output directory:

```
results/
├── complexa/          # Complexa designs and structures
├── proteinmpnn/       # Optimized sequences (if enabled)
├── boltz2/            # Refolded structures (if enabled)
├── ipsae/             # Interface scores (if enabled)
├── prodigy/           # Affinity predictions (if enabled)
├── foldseek/          # Structural search results (if enabled)
└── consolidated/      # Combined metrics report (if enabled)
```

## 📚 Citation

If you use this pipeline, please cite:

- **Proteina-Complexa**: [Add Complexa citation]
- **ProteinMPNN**: Dauparas et al. (2022) Science
- **Nextflow**: Di Tommaso et al. (2017) Nature Biotechnology

## 📄 License

This pipeline is distributed under the MIT License. See LICENSE for details.

---

<div align="center">

**Built with ❤️ using Nextflow and Seqera AI**

[Documentation](https://seqeralabs.github.io/nf-proteindesign/) | [Issues](https://github.com/seqeralabs/nf-proteindesign/issues) | [Seqera](https://seqera.io)

</div>
