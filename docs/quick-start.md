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
    Boltzgen requires an NVIDIA GPU with CUDA support for reasonable execution times. CPU execution is possible but extremely slow.

- **GPU**: NVIDIA GPU with CUDA 11.8+ support
- **Memory**: 16GB RAM minimum, 32GB+ recommended
- **Storage**: 50GB+ for dependencies and outputs

## :material-file-document: Prepare Input Files

### 1. Design YAML Files (Design Mode)

Create a design specification file following Boltzgen format:

```yaml title="my_design.yaml"
name: antibody_design_example
target:
  structure: data/target_protein.pdb
  residues: [10, 11, 12, 45, 46, 47, 89]  # Binding site residues
designed:
  chain_type: protein
  length: [50, 80]  # Range of acceptable lengths
global:
  n_samples: 10
  save_traj: true
```

### 2. Create Samplesheet

Create a CSV file with your design specifications:

```csv title="samplesheet.csv"
sample_id,design_yaml,num_designs,budget
design1,/path/to/design1.yaml,10000,20
design2,/path/to/design2.yaml,5000,10
design3,/path/to/design3.yaml,15000,30
```

**Column descriptions:**
- `sample_id`: Unique identifier for the design
- `design_yaml`: Path to the design YAML file
- `num_designs`: Number of intermediate designs to generate (10,000-60,000 for production)
- `budget`: Number of final diversity-optimized designs to keep

## :material-run: Running the Pipeline

### Basic Execution

Choose the appropriate profile for your system:

=== "Docker"
    ```bash
    nextflow run seqeralabs/nf-proteindesign \
        -profile docker \
        --input samplesheet.csv \
        --outdir results
    ```

=== "Local (with Docker)"
    ```bash
    nextflow run seqeralabs/nf-proteindesign \
        -profile docker,local \
        --input samplesheet.csv \
        --outdir results
    ```

### With Analysis Modules

Enable optional analysis steps for comprehensive quality assessment:

```bash
nextflow run seqeralabs/nf-proteindesign \
    -profile docker \
    --input samplesheet.csv \
    --outdir results \
    --run_proteinmpnn \
    --run_protenix_refold \
    --run_ipsae \
    --run_prodigy \
    --run_foldseek \
    --foldseek_database /path/to/afdb \
    --run_consolidation
```

## :material-tune: Common Options

### Design Parameters

Customize design generation:

```bash
nextflow run seqeralabs/nf-proteindesign \
    -profile docker \
    --input samplesheet.csv \
    --outdir results \
    --num_designs 10000 \     # Number of intermediate designs
    --budget 20 \             # Number of final designs to keep
    --protocol protein-anything  # Design protocol
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
├── boltzgen/              # Main Boltzgen outputs
│   ├── sample1/
│   │   ├── final_ranked_designs/
│   │   ├── intermediate_designs/
│   │   └── boltzgen.log
│   └── sample2/
│       └── ...
├── ipsae/                 # IPSAE scores (if enabled)
│   └── sample1_ipsae_scores.csv
├── prodigy/              # PRODIGY predictions (if enabled)
│   └── sample1_prodigy_predictions.csv
├── pipeline_info/        # Execution reports
│   ├── execution_report.html
│   ├── execution_timeline.html
│   └── execution_trace.txt
└── multiqc/              # MultiQC report (if enabled)
    └── multiqc_report.html
```

!!! tip "Final Designs"
    The most important files are in `boltzgen/*/final_ranked_designs/` - these contain your ranked protein designs ready for experimental validation.

## :material-test-tube: Example Workflow

Here's a complete example from start to finish:

### 1. Prepare Design File

```yaml title="antibody_target.yaml"
name: covid_spike_binder
target:
  structure: data/spike_protein.pdb
  residues: [417, 484, 501]  # RBD key residues
designed:
  chain_type: nanobody
  length: [110, 130]
global:
  n_samples: 20
  timesteps: 100
  save_traj: true
```

### 2. Create Samplesheet

```csv title="spike_designs.csv"
sample,design_yaml
spike_nb1,designs/antibody_target.yaml
```

### 3. Run Pipeline

```bash
nextflow run seqeralabs/nf-proteindesign \
    -profile docker \
    --input spike_designs.csv \
    --outdir covid_binders \
    --run_prodigy true
```

### 4. Check Results

```bash
# View execution report
open covid_binders/pipeline_info/execution_report.html

# Check final designs
ls covid_binders/boltzgen/spike_nb1/final_ranked_designs/

# View binding predictions
cat covid_binders/prodigy/spike_nb1_prodigy_predictions.csv
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
    
    **Solution**: Reduce batch size or number of parallel samples:
    ```bash
    --n_samples 10  # Reduce from default
    ```

!!! bug "Container Pull Failed"
    **Error**: `Error pulling container image`
    
    **Solution**: Pre-pull containers or use cached versions:
    ```bash
    docker pull ghcr.io/flouwuenne/boltzgen:latest
    ```

## :material-arrow-right: Next Steps

Now that you're up and running:

1. **Learn Basic Usage**: Check the [Usage Guide](getting-started/usage.md) for detailed instructions
2. **Optimize Parameters**: See the [Parameters Reference](reference/parameters.md)
3. **Enable Analysis Modules**: Learn about [ProteinMPNN/Protenix](analysis/proteinmpnn-protenix.md), [PRODIGY](analysis/prodigy.md), and [ipSAE](analysis/ipsae.md)
4. **Advanced Usage**: Explore [Architecture](architecture/design.md) details

---

!!! question "Need Help?"
    - Check the [GitHub Issues](https://github.com/seqeralabs/nf-proteindesign/issues)
    - Review [example workflows](reference/examples.md)
    - See the [Quick Reference](getting-started/quick-reference.md)
