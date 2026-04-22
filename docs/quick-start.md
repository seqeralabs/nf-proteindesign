# Quick Start Guide

Get up and running with nf-proteindesign in minutes!

## :material-download: Prerequisites

Before running the pipeline, ensure you have:

### Required Software

1. **Nextflow** (>=23.04.0)
   ```bash
   curl -s https://get.nextflow.io | bash
   sudo mv nextflow /usr/local/bin/
   ```

2. **Container Engine**:
   - **Docker** (required)
     ```bash
     # Install Docker: https://docs.docker.com/get-docker/
     docker --version
     ```

### Hardware Requirements

!!! warning "GPU Required"
    Both BoltzGen and Complexa require an NVIDIA GPU with CUDA support for reasonable execution times. CPU execution is possible but extremely slow.

- **GPU**: NVIDIA GPU with CUDA 11.8+ support
- **Memory**: 16GB RAM minimum, 32GB+ recommended
- **Storage**: 50GB+ for dependencies and outputs

## :material-file-document: Prepare Input Files

The pipeline supports two design backends, each with its own samplesheet format. Choose the one that matches your `--protein_design_tool` setting.

### Option A: BoltzGen (default)

#### 1. Design YAML Files

Create a design specification file following BoltzGen format:

```yaml title="my_design.yaml"
entities:
  - protein:
      id: C
      sequence: 80..120  # Length range for designed protein
  - file:
      path: target_protein.cif
      include:
        - chain:
            id: A  # Target chain to bind
```

#### 2. Create Samplesheet

```csv title="samplesheet.csv"
sample_id,design_yaml,structure_files,protocol,num_designs,budget,reuse,target_msa,target_sequence,target_template
design1,designs/my_design.yaml,target.cif,protein-anything,3,2,,target.a3m,target.fasta,
```

**Column descriptions:**

- `sample_id`: Unique identifier for the design
- `design_yaml`: Path to the BoltzGen design YAML file
- `target_sequence`: Path to target protein FASTA sequence (for Boltz-2 refolding)
- `structure_files` (optional): Comma-separated structure files (PDB/CIF)
- `protocol` (optional): Design protocol — `protein-anything`, `peptide-anything`, `nanobody-anything`, `protein-small_molecule`
- `num_designs` (optional): Number of intermediate designs to generate
- `budget` (optional): Number of final diversity-optimized designs to keep
- `target_msa` (optional): Pre-computed MSA for target (`.a3m`)
- `target_template` (optional): Template structure for Boltz-2 (CIF)

### Option B: Proteina-Complexa

#### 1. Pipeline Config YAML

Create a Complexa Hydra pipeline config YAML (see Complexa documentation for format details).

#### 2. Create Samplesheet

```csv title="samplesheet_complexa.csv"
sample_id,target_pdb,pipeline_config,target_sequence,target_msa,target_template
design1,target.cif,configs/pipeline.yaml,target.fasta,target.a3m,
```

**Column descriptions:**

- `sample_id`: Unique identifier for the design
- `target_pdb`: Target structure (PDB or CIF)
- `pipeline_config`: Path to Complexa Hydra pipeline config YAML
- `target_sequence`: Target protein FASTA sequence (for Boltz-2 refolding)
- `target_msa` (optional): Pre-computed MSA for target (`.a3m`)
- `target_template` (optional): Template structure for Boltz-2 (PDB/CIF)

## :material-run: Running the Pipeline

### Basic Execution

Choose the appropriate profile and design tool for your system:

=== "BoltzGen (default)"
    ```bash
    nextflow run seqeralabs/nf-proteindesign \
        -profile docker \
        --input samplesheet.csv \
        --outdir results
    ```

=== "Complexa"
    ```bash
    nextflow run seqeralabs/nf-proteindesign \
        -profile docker \
        --protein_design_tool complexa \
        --input samplesheet_complexa.csv \
        --complexa_ckpt_dir /path/to/checkpoints \
        --outdir results
    ```

### With Analysis Modules

All analysis modules are enabled by default. To run the full pipeline with a Foldseek database:

```bash
nextflow run seqeralabs/nf-proteindesign \
    -profile docker \
    --input samplesheet.csv \
    --outdir results \
    --foldseek_database /path/to/database_dir \
    --foldseek_database_name afdb
```

To disable specific modules, set them to `false`:

```bash
nextflow run seqeralabs/nf-proteindesign \
    -profile docker \
    --input samplesheet.csv \
    --outdir results \
    --run_foldseek false \
    --run_prodigy false
```

## :material-tune: Common Options

### Design Tool Selection

```bash
# BoltzGen (default)
--protein_design_tool boltzgen

# Proteina-Complexa
--protein_design_tool complexa
```

### Resource Allocation

Adjust compute resources:

```bash
nextflow run seqeralabs/nf-proteindesign \
    -profile docker \
    --input samplesheet.csv \
    --outdir results \
    --max_cpus 16 \
    --max_memory 64.GB \
    --max_time 48.h
```

## :material-folder-open: Understanding Outputs

After successful execution, your `results/` directory will contain:

```
results/
├── {sample_id}/
│   ├── boltzgen/ or complexa/    # Design outputs (depends on tool)
│   ├── proteinmpnn/              # Optimized sequences
│   ├── boltz2/                   # Refolded structures
│   ├── ipsae/                    # Interface scores
│   ├── prodigy/                  # Affinity predictions
│   ├── foldseek/                 # Structural search results
│   └── consolidated/             # Combined metrics report
└── pipeline_info/                # Execution reports
    ├── execution_report.html
    ├── execution_timeline.html
    └── execution_trace.txt
```

!!! tip "Final Designs"
    The most important files are the design output PDB/CIF files and the consolidated metrics report in `consolidated/`, which ranks all designs by combined quality scores.

## :material-test-tube: Example Workflow

Here's a complete example from start to finish using BoltzGen (default):

### 1. Prepare Design File

```yaml title="spike_binder_design.yaml"
entities:
  - protein:
      id: C
      sequence: 110..130  # Nanobody length range
  - file:
      path: spike_protein.cif
      include:
        - chain:
            id: A  # Target chain
```

### 2. Create Samplesheet

```csv title="spike_designs.csv"
sample_id,design_yaml,structure_files,protocol,num_designs,budget,reuse,target_msa,target_sequence,target_template
spike_nb1,designs/spike_binder_design.yaml,data/spike_protein.cif,nanobody-anything,3,2,,,data/spike_sequence.fasta,
```

### 3. Run Pipeline

```bash
nextflow run seqeralabs/nf-proteindesign \
    -profile docker \
    --input spike_designs.csv \
    --outdir covid_binders
```

### 4. Check Results

```bash
# View execution report
open covid_binders/pipeline_info/execution_report.html

# Check design outputs
ls covid_binders/spike_nb1/

# View consolidated metrics
cat covid_binders/spike_nb1/consolidated_metrics.csv
```

## :material-help-circle: Troubleshooting

### Common Issues

!!! bug "GPU Not Detected"
    **Error**: `CUDA device not found`
    
    **Solution**: Ensure NVIDIA drivers are installed and Docker has GPU access:
    ```bash
    # Test GPU access
    docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi
    ```

!!! bug "Out of Memory"
    **Error**: `CUDA out of memory`
    
    **Solution**: Reduce batch size or number of designs:
    ```bash
    # For Complexa, reduce batch size
    --complexa_batch_size 8
    ```

!!! bug "Container Pull Failed"
    **Error**: `Error pulling container image`
    
    **Solution**: Pre-pull containers or use cached versions. Check `nextflow.config` for the exact container URIs used by each process.

## :material-arrow-right: Next Steps

Now that you're up and running:

1. **Learn Basic Usage**: Check the [Usage Guide](getting-started/usage.md) for detailed instructions
2. **Optimize Parameters**: See the [Parameters Reference](reference/parameters.md)
3. **Explore Analysis Modules**: Learn about [ProteinMPNN/Boltz-2](analysis/proteinmpnn-boltz2.md), [PRODIGY](analysis/prodigy.md), [ipSAE](analysis/ipsae.md), and [Foldseek](analysis/foldseek.md)
4. **Advanced Usage**: Explore [Architecture](architecture/design.md) details

---

!!! question "Need Help?"
    - Check the [GitHub Issues](https://github.com/seqeralabs/nf-proteindesign/issues)
    - Review [example workflows](reference/examples.md)
    - See the [Quick Reference](getting-started/quick-reference.md)
