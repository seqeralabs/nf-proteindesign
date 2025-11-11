# Usage Guide: nf-proteindesign

This guide provides detailed instructions for using the nf-proteindesign pipeline.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Preparing Your Design Specifications](#preparing-your-design-specifications)
4. [Creating a Samplesheet](#creating-a-samplesheet)
5. [Running the Pipeline](#running-the-pipeline)
6. [Understanding the Outputs](#understanding-the-outputs)
7. [Advanced Usage](#advanced-usage)
8. [Troubleshooting](#troubleshooting)

## Prerequisites

### Required

- **Nextflow** >= 23.04.0
- **Container Engine**: Docker OR Singularity/Apptainer
- **GPU**: NVIDIA GPU with CUDA support (tested on A100)
- **GPU Drivers**: NVIDIA drivers compatible with CUDA
- **Storage**: ~6GB for Boltzgen model cache + space for results

### Recommended

- 64-80 GB RAM
- Multiple GPUs for parallel processing of samples
- Fast storage for work directory

## Installation

### 1. Install Nextflow

```bash
# Install Nextflow
curl -s https://get.nextflow.io | bash
chmod +x nextflow
sudo mv nextflow /usr/local/bin/

# Verify installation
nextflow -version
```

### 2. Install Container Engine

**Docker:**
```bash
# Follow instructions at https://docs.docker.com/engine/install/
# Ensure Docker is configured for GPU access
# Install NVIDIA Container Toolkit: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html
```

**Singularity/Apptainer:**
```bash
# Follow instructions at https://apptainer.org/docs/admin/main/installation.html
# Ensure --nv flag works for GPU access
```

### 3. Verify GPU Access

**Docker:**
```bash
docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi
```

**Singularity:**
```bash
singularity exec --nv docker://nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi
```

## Preparing Your Design Specifications

### Step 1: Obtain Target Structures

Download or prepare your target structure files in CIF or PDB format:

```bash
# Example: Download from PDB
wget https://files.rcsb.org/download/1G13.cif
```

### Step 2: Create Design YAML Files

Create a YAML file for each design experiment. See examples in `assets/design_examples/`.

**Basic Protein Design:**

```yaml
entities:
  - protein: 
      id: C
      sequence: 80..120
  - file:
      path: /path/to/target.cif
      include: 
        - chain:
            id: A
```

**Peptide with Binding Site:**

```yaml
entities:
  - protein: 
      id: P
      sequence: 12..20
  - file:
      path: /path/to/target.cif
      include:
        - chain:
            id: A
      binding_types:
        - chain:
            id: A
            binding: 50,51,52,100,101  # Residues to target
      structure_groups: "all"
```

**Cyclic Peptide:**

```yaml
entities:
  - protein: 
      id: P
      sequence: 12..18
      covalent_bonds:
        - [1, N, 12, C]  # Head-to-tail cyclization
  - file:
      path: /path/to/target.cif
      include:
        - chain:
            id: A
```

### Step 3: Validate Design Specification

Before running the full pipeline, validate your design:

```bash
# Using Boltzgen directly (if installed)
boltzgen check your_design.yaml

# View the output in a structure viewer (PyMOL, ChimeraX, or online at https://molstar.org/viewer/)
```

## Creating a Samplesheet

Create a CSV file with your design experiments:

```csv
sample_id,design_yaml,protocol,num_designs,budget
exp1_protein_binder,designs/protein1.yaml,protein-anything,10000,20
exp2_peptide_binder,designs/peptide1.yaml,peptide-anything,5000,10
exp3_nanobody,designs/nanobody1.yaml,nanobody-anything,15000,30
```

### Column Descriptions

| Column | Required | Description | Example |
|--------|----------|-------------|---------|
| sample_id | Yes | Unique identifier | `exp1_protein_binder` |
| design_yaml | Yes | Path to design YAML | `designs/protein1.yaml` |
| protocol | No* | Boltzgen protocol | `protein-anything` |
| num_designs | No* | Number of intermediate designs | `10000` |
| budget | No* | Final design count | `20` |
| reuse | No | Reuse previous results | `true` or `false` |

*If not specified, uses pipeline default parameters

### Protocols

Choose the appropriate protocol for your design:

- **protein-anything**: Standard protein binder design
- **peptide-anything**: Peptide or cyclic peptide design
- **protein-small_molecule**: Protein designs for small molecule binding
- **nanobody-anything**: Nanobody/single-domain antibody design

## Running the Pipeline

### Test Run (Quick Validation)

Start with a small test to ensure everything works:

```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --input samplesheet.csv \
    --outdir test_results \
    --num_designs 10 \
    --budget 2
```

### Production Run

Once validated, run with recommended parameters:

```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --input samplesheet.csv \
    --outdir results \
    --num_designs 20000 \
    --budget 50 \
    --cache_dir /shared/boltzgen_cache
```

### HPC with Singularity

```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile singularity \
    --input samplesheet.csv \
    --outdir results \
    --num_designs 50000 \
    --budget 100 \
    --max_memory 256.GB \
    --max_time 168.h \
    -work-dir /scratch/$USER/nf-work
```

### Resume Interrupted Runs

Nextflow automatically resumes from where it left off:

```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --input samplesheet.csv \
    --outdir results \
    -resume
```

## Understanding the Outputs

### Directory Structure

```
results/
├── pipeline_info/                 # Execution reports and timelines
│   ├── execution_report_*.html
│   ├── execution_timeline_*.html
│   └── execution_trace_*.txt
│
└── sample_id/                     # Per-sample results
    └── sample_id_output/
        ├── config/                # Configuration files used
        │   
        ├── intermediate_designs/  # Initial designs before inverse folding
        │   ├── design_0000.cif
        │   ├── design_0000.npz
        │   └── ...
        │
        ├── intermediate_designs_inverse_folded/
        │   ├── design_0000.cif   # Sequences assigned, backbone only
        │   ├── design_0000.npz
        │   ├── refold_cif/       # ⭐ Main structures for analysis
        │   │   ├── design_0000.cif
        │   │   └── ...
        │   ├── refold_design_cif/ # Binder-only structures
        │   ├── aggregate_metrics_analyze.csv
        │   └── per_target_metrics_analyze.csv
        │
        └── final_ranked_designs/  # ⭐ Final filtered results
            ├── intermediate_ranked_<N>_designs/  # Top N by quality
            │   ├── design_0042.cif
            │   └── ...
            ├── final_<budget>_designs/           # ⭐ Best set (quality + diversity)
            │   ├── design_0007.cif
            │   └── ...
            ├── all_designs_metrics.csv
            ├── final_designs_metrics_<budget>.csv
            └── results_overview.pdf              # Summary plots
```

### Key Output Files

**Most Important:**
- `final_<budget>_designs/*.cif`: Your final designed proteins - these are the structures to use
- `results_overview.pdf`: Visual summary of design quality and diversity
- `final_designs_metrics_<budget>.csv`: Metrics for final designs

**Analysis Files:**
- `all_designs_metrics.csv`: Metrics for all generated designs
- `aggregate_metrics_analyze.csv`: Aggregated statistics
- `refold_cif/`: Full complex structures (binder + target) after refolding

### Interpreting Results

**Quality Metrics to Consider:**
- **ipTM** (predicted TM-score): Confidence in the interaction interface (higher is better)
- **pLDDT**: Confidence in local structure (higher is better)
- **RMSD**: Structure similarity between design and refolded structure (lower is better)
- **Interface metrics**: Contact surface area, shape complementarity

**Filtering Strategy:**
1. Look at `intermediate_ranked_<N>_designs/` for top quality designs
2. Check `final_<budget>_designs/` for quality + diversity balance
3. Review `results_overview.pdf` for visual assessment
4. Use metrics CSV files for detailed analysis

## Advanced Usage

### Custom Boltzgen Configuration

Override default Boltzgen settings with a custom config:

```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --input samplesheet.csv \
    --outdir results \
    --boltzgen_config custom_boltzgen_config.yaml
```

### Rerun Filtering Only

Quickly refilter with different parameters without regenerating designs:

```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --input samplesheet.csv \
    --outdir results \
    --steps filtering \
    --budget 200 \
    -resume
```

**Tip:** Set `reuse=true` in your samplesheet to reuse existing design outputs.

### Multiple GPUs

To utilize multiple GPUs for parallel sample processing, configure your executor:

**Local machine with multiple GPUs:**
```bash
# Docker will use all available GPUs (--gpus all)
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --input samplesheet.csv \
    --max_gpus 4
```

**HPC with SLURM:**

Create a custom config file `custom.config`:

```groovy
process {
    executor = 'slurm'
    queue = 'gpu'
    
    withLabel:process_high_gpu {
        clusterOptions = '--gres=gpu:1 --partition=gpu'
        time = '48.h'
        memory = '64.GB'
    }
}
```

Run with custom config:
```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile singularity \
    -c custom.config \
    --input samplesheet.csv
```

### Monitoring Long Runs

Use Nextflow Tower for real-time monitoring:

```bash
export TOWER_ACCESS_TOKEN=your_token
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --input samplesheet.csv \
    -with-tower
```

## Troubleshooting

### GPU Not Detected

**Docker:**
```bash
# Check NVIDIA Container Toolkit
docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi

# If fails, reinstall NVIDIA Container Toolkit
# https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html
```

**Singularity:**
```bash
# Test GPU access
singularity exec --nv docker://nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi

# If fails, check Singularity installation and --nv support
```

### Out of Memory Errors

Increase memory allocation:

```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --input samplesheet.csv \
    --max_memory 256.GB
```

Or reduce `num_designs` in your samplesheet.

### Pipeline Hangs or Times Out

Increase time limits:

```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --input samplesheet.csv \
    --max_time 240.h
```

### Model Download Fails

Set a custom cache directory with sufficient space:

```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --input samplesheet.csv \
    --cache_dir /path/to/large/disk/boltzgen_cache
```

### Design YAML Validation Errors

Run Boltzgen's check command:

```bash
boltzgen check your_design.yaml
```

Visualize the output structure to verify your design specification.

### Container Pull Errors

Pre-pull containers before running:

```bash
# Docker
docker pull boltz/boltzgen:latest

# Singularity
singularity pull docker://boltz/boltzgen:latest
```

## Getting Help

- **Pipeline Issues**: [GitHub Issues](https://github.com/FloWuenne/nf-proteindesign-2025/issues)
- **Boltzgen Questions**: [Boltzgen Repository](https://github.com/HannesStark/boltzgen) or [Slack](https://boltz.bio/join-slack)
- **Nextflow Questions**: [Nextflow Slack](https://www.nextflow.io/slack.html)

## Tips for Success

1. **Start Small**: Always test with `--num_designs 10-50` first
2. **Check Designs**: Use `boltzgen check` to validate YAML specifications
3. **Monitor Resources**: Watch GPU memory and adjust batch sizes if needed
4. **Use Resume**: Always use `-resume` for interrupted runs
5. **Organize Data**: Keep design YAMLs and target structures well-organized
6. **Review Metrics**: Don't just trust the top designs - review metrics and diversity
7. **Iterate**: Use the filtering step to quickly try different selection criteria

## Example Workflows

### Workflow 1: Single Target, Multiple Strategies

```csv
sample_id,design_yaml,protocol,num_designs,budget
target1_protein_80-120,designs/target1_protein.yaml,protein-anything,20000,30
target1_peptide_12-20,designs/target1_peptide.yaml,peptide-anything,15000,20
target1_nanobody,designs/target1_nanobody.yaml,nanobody-anything,25000,40
```

### Workflow 2: Multiple Targets, Same Strategy

```csv
sample_id,design_yaml,protocol,num_designs,budget
target1_protein,designs/target1.yaml,protein-anything,20000,30
target2_protein,designs/target2.yaml,protein-anything,20000,30
target3_protein,designs/target3.yaml,protein-anything,20000,30
target4_protein,designs/target4.yaml,protein-anything,20000,30
```

### Workflow 3: Optimization Run

```csv
sample_id,design_yaml,protocol,num_designs,budget,reuse
target1_v1,designs/target1.yaml,protein-anything,50000,50,false
target1_v2_refilter,designs/target1.yaml,protein-anything,50000,100,true
```

Run with `--steps filtering` for the second entry to reuse designs and just refilter.
