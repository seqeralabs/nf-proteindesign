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
3. **Collect Results**: Organizes outputs including final ranked designs, intermediate designs, and metrics

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
