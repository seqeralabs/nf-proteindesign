# 🧬 nf-proteindesign

> ⚠️ **IMPORTANT**: This pipeline was developed by Seqera as a proof of principle using Seqera AI. It demonstrates the capabilities of AI-assisted bioinformatics pipeline development but should be thoroughly validated before use in production environments.

A Nextflow pipeline for AI-powered protein design supporting two generative backends — **BoltzGen** (default) and **Proteina-Complexa** — to design protein binders, nanobodies, and peptides.

## 📋 Overview

This pipeline automates the process of designing novel protein binders and provides comprehensive analysis through optional downstream modules:

- 🎯 **BoltzGen** (default): Flow-matching generative model for protein design using design YAML specifications
- 🏗️ **Proteina-Complexa**: Generative diffusion model for protein design using pipeline config YAMLs
- 🧬 **ProteinMPNN**: Optimize sequences for improved stability and expression
- 🔄 **Boltz-2 Refolding**: Validate designs through structure prediction
- 📊 **IPSAE**: Score protein-protein interface quality
- ⚡ **PRODIGY**: Predict binding affinity
- 🔍 **Foldseek**: Search structural databases for similar designs
- 📈 **Metrics Consolidation**: Generate comprehensive analysis reports

Both design backends converge into the same downstream pipeline (ProteinMPNN → Boltz-2 → Analysis → Consolidation).

## 🚀 Quick Start

### ✅ Prerequisites

- ⚙️ Nextflow (≥23.04.0)
- 🐳 Docker or Singularity
- 🎮 GPU recommended for optimal performance

### 🧪 Running with Test Profiles

Test the pipeline with one of three available profiles (uses BoltzGen by default):

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

#### BoltzGen (default)

```bash
nextflow run main.nf \
  --input samplesheet.csv \
  --outdir results \
  -profile docker
```

#### Proteina-Complexa

```bash
nextflow run main.nf \
  --protein_design_tool complexa \
  --input samplesheet_complexa.csv \
  --complexa_ckpt_dir /path/to/checkpoints \
  --outdir results \
  -profile docker
```

## 📝 Input Format

The samplesheet format depends on the chosen design tool (`--protein_design_tool`). See `assets/test_data/` for examples.

### BoltzGen Samplesheet (default)

```csv
sample_id,design_yaml,structure_files,protocol,num_designs,budget,reuse,target_msa,target_sequence,target_template
design1,designs/my_design.yaml,target.cif,protein-anything,3,2,,target.a3m,target.fasta,
```

| Column | Required | Description |
|--------|----------|-------------|
| `sample_id` | ✅ | Unique sample identifier |
| `design_yaml` | ✅ | Path to BoltzGen design YAML specification |
| `target_sequence` | ✅ | Target sequence FASTA (for Boltz-2 refolding) |
| `structure_files` | | Comma-separated structure files (PDB/CIF) |
| `protocol` | | Design protocol (`protein-anything`, `peptide-anything`, `nanobody-anything`, `protein-small_molecule`) |
| `num_designs` | | Number of intermediate designs to generate |
| `budget` | | Number of final diversity-optimized designs to keep |
| `reuse` | | Reuse previous results (`true`/`false`) |
| `target_msa` | | Pre-computed MSA for target (e.g., `.a3m`) |
| `target_template` | | Template structure for Boltz-2 (CIF) |

### Complexa Samplesheet

```csv
sample_id,target_pdb,pipeline_config,target_sequence,target_msa,target_template
design1,target.cif,configs/pipeline.yaml,target.fasta,target.a3m,
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

### Design Tool Selection

- `--protein_design_tool`: Design backend to use — `boltzgen` (default) or `complexa`

### Common Parameters

- `--input`: Path to samplesheet CSV
- `--outdir`: Output directory (default: `./results`)
- `--run_proteinmpnn`: Enable ProteinMPNN sequence optimization (default: `true`)
- `--run_boltz2_refold`: Enable Boltz-2 structure prediction (default: `true`)
- `--run_ipsae`: Enable IPSAE interface scoring (default: `true`)
- `--run_prodigy`: Enable PRODIGY affinity prediction (default: `true`)
- `--run_foldseek`: Enable Foldseek structural similarity search (default: `true`)
- `--run_consolidation`: Generate consolidated metrics report (default: `true`)

### BoltzGen-Specific Parameters

- `--cache_dir`: Cache directory for BoltzGen model weights

### Complexa-Specific Parameters

- `--complexa_ckpt_dir`: Path to Complexa checkpoint directory
- `--complexa_search_algorithm`: Search algorithm (`best-of-n`, `beam-search`, etc.)
- `--complexa_nsteps`: Diffusion sampling steps (default: 400)
- `--complexa_batch_size`: Generation batch size (default: 16)

See `nextflow.config` for all available parameters.

## 📁 Output

Results are organized by sample in the output directory:

```
results/
├── {sample_id}/
│   ├── boltzgen/          # BoltzGen designs (if using boltzgen)
│   ├── complexa/          # Complexa designs (if using complexa)
│   ├── proteinmpnn/       # Optimized sequences
│   ├── boltz2/            # Refolded structures
│   ├── ipsae/             # Interface scores
│   ├── prodigy/           # Affinity predictions
│   ├── foldseek/          # Structural search results
│   └── consolidated/      # Combined metrics report
└── pipeline_info/         # Execution reports
```

## 📚 Citation

If you use this pipeline, please cite:

- **BoltzGen**: Jing et al. (2024) "Generative Modeling of Molecular Dynamics Trajectories"
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
