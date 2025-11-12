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

2. **Container Engine** (one of):
   - **Docker** (recommended for local execution)
     ```bash
     # Install Docker: https://docs.docker.com/get-docker/
     docker --version
     ```
   - **Singularity** (recommended for HPC)
     ```bash
     # Install Singularity: https://sylabs.io/guides/latest/user-guide/
     singularity --version
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

=== "Design Mode"
    ```csv title="samplesheet_design.csv"
    sample,design_yaml
    design1,/path/to/design1.yaml
    design2,/path/to/design2.yaml
    design3,/path/to/design3.yaml
    ```

=== "Target Mode"
    ```csv title="samplesheet_target.csv"
    sample,target_structure,target_residues,chain_type,min_length,max_length
    target1,/path/to/target1.pdb,"10,11,12,45,46",protein,50,80
    target2,/path/to/target2.pdb,"5,6,7,8,9,10",peptide,10,20
    ```

=== "P2Rank Mode"
    ```csv title="samplesheet_p2rank.csv"
    sample,target_structure,chain_type,min_length,max_length
    p2rank1,/path/to/target1.pdb,protein,50,80
    p2rank2,/path/to/target2.pdb,nanobody,100,120
    ```

## :material-run: Running the Pipeline

### Basic Execution

Choose the appropriate profile for your system:

=== "Docker"
    ```bash
    nextflow run FloWuenne/nf-proteindesign-2025 \
        -profile docker \
        --input samplesheet.csv \
        --outdir results
    ```

=== "Singularity"
    ```bash
    nextflow run FloWuenne/nf-proteindesign-2025 \
        -profile singularity \
        --input samplesheet.csv \
        --outdir results
    ```

=== "Local (with Docker)"
    ```bash
    nextflow run FloWuenne/nf-proteindesign-2025 \
        -profile docker,local \
        --input samplesheet.csv \
        --outdir results
    ```

### Specify Pipeline Mode

While the pipeline auto-detects mode from samplesheet, you can specify explicitly:

=== "Design Mode"
    ```bash
    nextflow run FloWuenne/nf-proteindesign-2025 \
        -profile docker \
        --mode design \
        --input samplesheet_designs.csv \
        --outdir results
    ```

=== "Target Mode"
    ```bash
    nextflow run FloWuenne/nf-proteindesign-2025 \
        -profile docker \
        --mode target \
        --input samplesheet_targets.csv \
        --outdir results \
        --n_samples 20
    ```

=== "P2Rank Mode"
    ```bash
    nextflow run FloWuenne/nf-proteindesign-2025 \
        -profile docker \
        --mode p2rank \
        --input samplesheet_p2rank.csv \
        --outdir results \
        --p2rank_top_n 3
    ```

## :material-tune: Common Options

### Analysis Tools

Enable optional analysis steps:

```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --input samplesheet.csv \
    --outdir results \
    --run_ipsae true \        # Enable IPSAE scoring
    --run_prodigy true        # Enable PRODIGY affinity prediction
```

### Boltzgen Parameters

Customize design generation:

```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --input samplesheet.csv \
    --outdir results \
    --n_samples 50 \          # Number of designs per specification
    --timesteps 100 \         # Diffusion timesteps
    --save_traj true          # Save trajectory files
```

### Resource Allocation

Adjust compute resources:

```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
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
nextflow run FloWuenne/nf-proteindesign-2025 \
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

1. **Learn More About Modes**: Check the [Pipeline Modes](modes/overview.md) documentation
2. **Optimize Parameters**: See the [Parameters Reference](reference/parameters.md)
3. **Analyze Results**: Learn about [PRODIGY](analysis/prodigy.md) and [ipSAE](analysis/ipsae.md)
4. **Advanced Usage**: Explore [Architecture](architecture/design.md) details

---

!!! question "Need Help?"
    - Check the [GitHub Issues](https://github.com/FloWuenne/nf-proteindesign-2025/issues)
    - Review [example workflows](reference/examples.md)
    - See the [Quick Reference](getting-started/quick-reference.md)
