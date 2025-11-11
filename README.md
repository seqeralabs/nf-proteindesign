# nf-proteindesign

[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A523.04.0-23aa62.svg)](https://www.nextflow.io/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)

## Introduction

**nf-proteindesign** is a Nextflow pipeline for running [Boltzgen](https://github.com/HannesStark/boltzgen) protein design workflows in parallel across multiple design specifications. Boltzgen is an all-atom generative diffusion model that can design proteins, peptides, and nanobodies to bind various biomolecular targets (proteins, nucleic acids, small molecules).

The pipeline allows you to define multiple protein design experiments in a samplesheet, each with its own design specification YAML file and parameters, enabling high-throughput parallel protein design.

## Pipeline summary

1. **Validate Samplesheet**: Checks samplesheet format and validates design YAML files exist
2. **Run Boltzgen**: Executes Boltzgen for each sample in parallel with specified parameters
3. **IPSAE Scoring** (optional): Evaluates protein-protein interactions using ipSAE metrics
4. **Collect Results**: Organizes outputs including final ranked designs, intermediate designs, and metrics

## Pipeline Flow

```mermaid
flowchart TD
    A[📋 Input Samplesheet CSV] --> B{Parse & Validate}
    B --> C[Create Channels per Sample]
    
    C --> D1[🧬 Sample 1: Design YAML]
    C --> D2[🧬 Sample 2: Design YAML]
    C --> D3[🧬 Sample N: Design YAML]
    
    D1 --> E1[⚡ BOLTZGEN_RUN<br/>GPU Process]
    D2 --> E2[⚡ BOLTZGEN_RUN<br/>GPU Process]
    D3 --> E3[⚡ BOLTZGEN_RUN<br/>GPU Process]
    
    E1 --> F1[🔄 Design Generation<br/>Inverse Folding<br/>Refolding<br/>Analysis<br/>Filtering]
    E2 --> F2[🔄 Design Generation<br/>Inverse Folding<br/>Refolding<br/>Analysis<br/>Filtering]
    E3 --> F3[🔄 Design Generation<br/>Inverse Folding<br/>Refolding<br/>Analysis<br/>Filtering]
    
    F1 --> G1[📁 Sample 1 Results<br/>- intermediate_designs/<br/>- inverse_folded/<br/>- final_ranked_designs/]
    F2 --> G2[📁 Sample 2 Results<br/>- intermediate_designs/<br/>- inverse_folded/<br/>- final_ranked_designs/]
    F3 --> G3[📁 Sample N Results<br/>- intermediate_designs/<br/>- inverse_folded/<br/>- final_ranked_designs/]
    
    G1 --> H[✅ Organized Output Directory]
    G2 --> H
    G3 --> H
    
    H --> I[📊 Final Designs + Metrics<br/>📈 results_overview.pdf]
    
    style A fill:#e1f5ff
    style B fill:#fff4e1
    style E1 fill:#ffe1f5
    style E2 fill:#ffe1f5
    style E3 fill:#ffe1f5
    style H fill:#e1ffe1
    style I fill:#e1ffe1
```

### Parallel Execution

Each sample runs **independently and in parallel**, limited only by available GPU resources. This enables high-throughput protein design campaigns with multiple targets or strategies simultaneously.

## Quick Start

1. Install [`Nextflow`](https://www.nextflow.io/docs/latest/getstarted.html#installation) (`>=23.04.0`)

2. Install [`Docker`](https://docs.docker.com/engine/installation/) or [`Singularity`](https://www.sylabs.io/guides/3.0/user-guide/) (required for GPU access)

3. Prepare your design YAML files following [Boltzgen design specification format](#design-specification-format)

4. Create a samplesheet (see [example](#samplesheet-format))

5. Run the pipeline:

   ```bash
   nextflow run FloWuenne/nf-proteindesign-2025 \
       -profile docker \
       --input samplesheet.csv \
       --outdir results
   ```

## GPU Requirements

⚠️ **IMPORTANT: Boltzgen requires GPU (CUDA) to run.** The pipeline cannot run on CPU-only systems.

The pipeline is configured to work with:
- **Docker**: Uses `--gpus all` flag to enable GPU access
- **Singularity/Apptainer**: Uses `--nv` flag for NVIDIA GPU support

Ensure your compute environment has:
- NVIDIA GPU with CUDA support
- Appropriate GPU drivers installed
- Docker/Singularity configured for GPU access

Tested on NVIDIA A100 GPUs. See [Boltzgen documentation](https://github.com/HannesStark/boltzgen) for timing benchmarks.

## Samplesheet Format

The input samplesheet is a CSV file with the following columns:

| Column       | Required | Description |
|--------------|----------|-------------|
| sample_id    | Yes      | Unique identifier for the design run |
| design_yaml  | Yes      | Path to Boltzgen design specification YAML file |
| protocol     | No       | Boltzgen protocol (defaults to pipeline parameter) |
| num_designs  | No       | Number of intermediate designs (defaults to pipeline parameter) |
| budget       | No       | Final diversity-optimized design count (defaults to pipeline parameter) |
| reuse        | No       | Whether to reuse previous run results (true/false) |

### Example Samplesheet

```csv
sample_id,design_yaml,protocol,num_designs,budget
protein_binder_1,designs/protein_target1.yaml,protein-anything,10000,20
peptide_binder_1,designs/peptide_target1.yaml,peptide-anything,5000,10
nanobody_design,designs/nanobody_target.yaml,nanobody-anything,15000,30
small_mol_binder,designs/small_molecule.yaml,protein-small_molecule,8000,15
```

## Design Specification Format

Each design YAML file follows the Boltzgen design specification format. Here's a minimal example:

```yaml
entities:
  # Designed protein chain
  - protein: 
      id: C
      sequence: 80..140  # Random length between 80-140 residues
  
  # Target from PDB/CIF file
  - file:
      path: target.cif
      include: 
        - chain:
            id: A
```

### Example with binding site specification:

```yaml
entities:
  # Designed peptide
  - protein: 
      id: G
      sequence: 12..20
  
  # Target with specific binding site
  - file:
      path: target.cif
      include:
        - chain:
            id: A
      binding_types:
        - chain:
            id: A
            binding: 343,344,251  # Specific residues to bind
      structure_groups: "all"
```

See the [Boltzgen repository](https://github.com/HannesStark/boltzgen) for more complex examples including:
- Cyclic peptides
- Disulfide bonds
- Secondary structure constraints
- Nanobody scaffolds
- And more...

## Parameters

### Required Parameters

| Parameter | Description |
|-----------|-------------|
| `--input` | Path to samplesheet CSV file |

### Boltzgen Configuration

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--protocol` | `protein-anything` | Default protocol for designs |
| `--num_designs` | `100` | Default number of intermediate designs (recommend 10,000-60,000 for production) |
| `--budget` | `10` | Default number of final diversity-optimized designs |
| `--cache_dir` | `null` | Directory for model weights (~6GB, defaults to ~/.cache) |
| `--boltzgen_config` | `null` | Path to custom Boltzgen config YAML |
| `--steps` | `null` | Comma-separated list of pipeline steps to run (e.g., 'filtering') |

### Output Options

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--outdir` | `./results` | Output directory for results |
| `--publish_dir_mode` | `copy` | Method for publishing output files (copy, symlink, etc.) |

### Resource Limits

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--max_memory` | `128.GB` | Maximum memory per process |
| `--max_cpus` | `16` | Maximum CPUs per process |
| `--max_time` | `240.h` | Maximum time per process |
| `--max_gpus` | `1` | Maximum GPUs per process |

## IPSAE Scoring (Optional)

The pipeline includes optional **IPSAE (interprotein Structural Alignment Error)** scoring to evaluate the quality of protein-protein interactions in predicted structures. IPSAE is particularly useful for assessing the predicted binding interfaces between designed proteins/peptides and their targets.

### What is IPSAE?

IPSAE is a scoring function specifically developed for evaluating protein-protein interactions in AlphaFold2, AlphaFold3, and Boltz predictions. It provides:

- **ipSAE scores**: Quantitative assessment of predicted binding interfaces
- **Per-residue scores**: Identification of key interface residues
- **Multiple metrics**: Including pDockQ, pDockQ2, ipTM, and LIS scores
- **PyMOL visualization scripts**: For easy inspection of results

Reference: [Dunbrack Lab IPSAE](https://github.com/DunbrackLab/IPSAE)

### Enabling IPSAE Scoring

To enable IPSAE scoring, add the `--run_ipsae` flag:

```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --input samplesheet.csv \
    --outdir results \
    --run_ipsae
```

### IPSAE Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--run_ipsae` | false | Enable IPSAE scoring |
| `--ipsae_pae_cutoff` | 10 | PAE cutoff in Angstroms for interface residue identification |
| `--ipsae_dist_cutoff` | 10 | Distance cutoff in Angstroms for CA-CA contacts |

### Custom IPSAE Cutoffs

```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --input samplesheet.csv \
    --run_ipsae \
    --ipsae_pae_cutoff 15 \
    --ipsae_dist_cutoff 15
```

### IPSAE Output Files

When IPSAE scoring is enabled, the following files are generated for each model:

```
results/
└── sample_id/
    ├── ipsae_scores/
    │   ├── *_model_0_10_10.txt                    # Chain-chain interaction scores
    │   ├── *_model_0_10_10_byres.txt              # Per-residue scores
    │   ├── *_model_0_10_10.pml                    # PyMOL visualization script
    │   ├── *_model_1_10_10.txt                    # Scores for additional models
    │   └── ...
```

#### Score File Format

The main score file (`*_10_10.txt`) contains:

- **Chain-pair metrics**: ipSAE, ipTM, pDockQ, pDockQ2, LIS
- **Residue counts**: Number of interface residues per chain
- **Distance metrics**: d0 values for different calculation methods

The per-residue file (`*_10_10_byres.txt`) provides:

- **Per-residue ipSAE scores**: Contribution of each residue to binding
- **pLDDT values**: Confidence scores per residue
- **Chain assignments**: Which residues interact with which chains

### Interpreting IPSAE Scores

- **ipSAE**: Higher values (0-1) indicate better predicted interfaces
  - > 0.6: High-confidence interaction
  - 0.4-0.6: Moderate confidence
  - < 0.4: Low confidence / likely non-specific

- **pDockQ**: Quality of protein-protein docking
  - > 0.23: Acceptable quality
  - > 0.49: Good quality

- **ipTM**: Interface predicted TM-score
  - > 0.5: Good interface alignment

## Protocols

Boltzgen supports four main protocols:

| Protocol | Use Case | Key Features |
|----------|----------|--------------|
| `protein-anything` | Design proteins to bind proteins/peptides | Includes design folding step |
| `peptide-anything` | Design (cyclic) peptides to bind proteins | No Cys in inverse folding, no design folding |
| `protein-small_molecule` | Design proteins to bind small molecules | Includes binding affinity prediction |
| `nanobody-anything` | Design nanobodies (single-domain antibodies) | No Cys in inverse folding, no design folding |

## Output Structure

For each sample, the pipeline creates:

```
results/
└── sample_id/
    ├── sample_id_output/
    │   ├── config/                                    # Configuration files
    │   ├── intermediate_designs/                      # Initial designs before inverse folding
    │   │   ├── *.cif                                 # Structure files
    │   │   └── *.npz                                 # Metadata
    │   ├── intermediate_designs_inverse_folded/       # After inverse folding and refolding
    │   │   ├── *.cif                                 # Inverse folded structures
    │   │   ├── *.npz                                 # Metadata
    │   │   ├── refold_cif/                           # Refolded complexes (main input for analysis)
    │   │   ├── refold_design_cif/                    # Refolded binders only
    │   │   ├── aggregate_metrics_analyze.csv         # Aggregated metrics
    │   │   └── per_target_metrics_analyze.csv        # Per-target metrics
    │   └── final_ranked_designs/                      # Quality + diversity filtered results
    │       ├── intermediate_ranked_<N>_designs/      # Top-N by quality
    │       ├── final_<budget>_designs/               # Final diversity-optimized set
    │       ├── all_designs_metrics.csv               # All design metrics
    │       ├── final_designs_metrics_<budget>.csv    # Final set metrics
    │       └── results_overview.pdf                  # Summary plots
    └── ipsae_scores/                                  # IPSAE scoring results (if --run_ipsae enabled)
        ├── *_model_0_10_10.txt                       # Chain-chain interaction scores
        ├── *_model_0_10_10_byres.txt                 # Per-residue IPSAE scores
        └── *_model_0_10_10.pml                       # PyMOL visualization script
```

## Running the Pipeline

### Basic run with default parameters

```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --input samplesheet.csv \
    --outdir results
```

### Production run with recommended parameters

```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --input samplesheet.csv \
    --outdir results \
    --num_designs 20000 \
    --budget 50 \
    --cache_dir /shared/boltzgen_cache
```

### Rerun only filtering step with different settings

```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --input samplesheet.csv \
    --outdir results \
    --steps filtering \
    --budget 100
```

### Using Singularity on HPC

```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile singularity \
    --input samplesheet.csv \
    --outdir results \
    --num_designs 50000 \
    --budget 100 \
    --max_memory 256.GB \
    --max_time 168.h
```

## Performance Considerations

### Number of Designs

- **Test runs**: Start with `--num_designs 50` and `--budget 2-5` to verify everything works
- **Production runs**: Use `--num_designs 10000-60000` depending on target complexity
- More designs generally yield better results but take longer

### Timing (per design on A100 GPU)

Based on Boltzgen benchmarks:
- Design generation: ~few seconds
- Inverse folding: ~few seconds  
- Refolding: ~few seconds
- Analysis: ~few seconds
- Filtering: ~15 seconds (CPU-based, can be rerun quickly)

Total: Approximately 10-20 seconds per design for the full pipeline

### Resource Recommendations

- **GPU**: NVIDIA A100 or equivalent
- **Memory**: 64-80 GB RAM
- **Storage**: ~1-10 GB per design run depending on num_designs
- **Cache**: ~6 GB for initial model download

## Rerunning Filtering

The filtering step can be quickly rerun with different parameters without regenerating designs:

```bash
# Rerun with different budget
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --input samplesheet.csv \
    --outdir results \
    --steps filtering \
    --budget 200
```

Alternatively, use the provided `filter.ipynb` Jupyter notebook in the Boltzgen repository for interactive filtering.

## Credits

nf-proteindesign was created by Florian Wuennemann.

The pipeline uses [Boltzgen](https://github.com/HannesStark/boltzgen), developed by the MIT Jameel Clinic and collaborators.

## Citations

If you use this pipeline, please cite:

- **Boltzgen**: [BoltzGen paper](https://hannes-stark.com/assets/boltzgen.pdf)

- **Nextflow**: Di Tommaso, P., Chatzou, M., Floden, E. W., Barja, P. P., Palumbo, E., & Notredame, C. (2017). Nextflow enables reproducible computational workflows. Nature Biotechnology, 35(4), 316-319. doi: [10.1038/nbt.3820](https://doi.org/10.1038/nbt.3820)

## License

This pipeline is released under the MIT License.

Boltzgen is also released under the MIT License.
