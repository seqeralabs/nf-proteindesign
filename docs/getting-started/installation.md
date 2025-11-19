# Installation Guide

## :material-download: Prerequisites

### Required Software

#### 1. Nextflow

Install Nextflow (version >=23.04.0):

```bash
# Download and install
curl -s https://get.nextflow.io | bash

# Move to system path
sudo mv nextflow /usr/local/bin/

# Verify installation
nextflow -version
```

#### 2. Container Engine

You need either Docker or Singularity:

=== "Docker (Recommended for Local)"
    ```bash
    # Install Docker: https://docs.docker.com/get-docker/
    # Verify installation
    docker --version
    docker run hello-world
    ```

=== "Singularity (Recommended for HPC)"
    ```bash
    # Install Singularity: https://sylabs.io/guides/latest/user-guide/
    # Verify installation
    singularity --version
    ```

### GPU Requirements

!!! warning "NVIDIA GPU Required"
    Boltzgen requires an NVIDIA GPU with CUDA support. CPU execution is possible but extremely slow.

#### Setup NVIDIA Container Toolkit (Docker)

```bash
# Install nvidia-container-toolkit
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list

sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
sudo systemctl restart docker

# Test GPU access
docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi
```

## :material-cloud-download: Pipeline Installation

The pipeline can be run directly from GitHub without manual installation:

```bash
# Run directly (Nextflow will handle download)
nextflow run FloWuenne/nf-proteindesign-2025 -profile docker --input samplesheet.csv --outdir results
```

### Alternative: Clone Repository

For development or offline use:

```bash
# Clone repository
git clone https://github.com/FloWuenne/nf-proteindesign-2025.git
cd nf-proteindesign-2025

# Run from local directory
nextflow run main.nf -profile docker --input samplesheet.csv --outdir results
```

## :material-test-tube: Test Installation

### Quick Test

```bash
# Create test samplesheet
echo "sample,design_yaml" > test.csv
echo "test,test_data/test_design.yaml" >> test.csv

# Run test
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker,test \
    --input test.csv \
    --outdir test_results
```

### Verify GPU Access

```bash
# Check NVIDIA driver
nvidia-smi

# Test with container
docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi
```

## :material-cog: Configuration

### Nextflow Config

Create `~/.nextflow/config` for personal settings:

```groovy
docker {
    enabled = true
    runOptions = '--gpus all'
}

process {
    executor = 'local'
    cpus = 16
    memory = '64 GB'
}
```

### Resource Limits

Set appropriate resource limits for your system:

```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --input samplesheet.csv \
    --outdir results \
    --max_cpus 32 \
    --max_memory 128.GB \
    --max_time 72.h
```

## :material-server: HPC Setup

### SLURM Configuration

Create `hpc.config`:

```groovy
process {
    executor = 'slurm'
    queue = 'gpu'
    clusterOptions = '--gres=gpu:1'
    
    withLabel: gpu {
        clusterOptions = '--gres=gpu:1 --mem=32GB'
        time = '48h'
    }
}

singularity {
    enabled = true
    autoMounts = true
    cacheDir = '/path/to/singularity/cache'
}
```

Run with custom config:

```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile singularity \
    -c hpc.config \
    --input samplesheet.csv \
    --outdir results
```

## :material-package: Container Images

The pipeline uses pre-built containers from GitHub Container Registry:

- **Boltzgen**: `ghcr.io/flouwuenne/boltzgen:latest`
- **PRODIGY**: `ghcr.io/flouwuenne/prodigy:latest`

### Pre-pull Containers

```bash
# Docker
docker pull ghcr.io/flouwuenne/boltzgen:latest
docker pull ghcr.io/flouwuenne/prodigy:latest

# Singularity
export NXF_SINGULARITY_CACHEDIR="/path/to/cache"
singularity pull docker://ghcr.io/flouwuenne/boltzgen:latest
```

## :material-help-circle: Troubleshooting

### Common Issues

!!! bug "Permission Denied (Docker)"
    **Error**: `permission denied while trying to connect to the Docker daemon`
    
    **Solution**: Add user to docker group:
    ```bash
    sudo usermod -aG docker $USER
    newgrp docker
    ```

!!! bug "GPU Not Available"
    **Error**: `CUDA device not found`
    
    **Solution**: Ensure NVIDIA drivers and container toolkit are installed:
    ```bash
    # Check driver
    nvidia-smi
    
    # Install container toolkit
    # See GPU Requirements section above
    ```

!!! bug "Out of Disk Space"
    **Error**: `No space left on device`
    
    **Solution**: Clean Nextflow work directory:
    ```bash
    nextflow clean -f
    ```

## :material-update: Updates

### Update Pipeline

```bash
# Pull latest version
nextflow pull FloWuenne/nf-proteindesign-2025

# Or update local clone
cd nf-proteindesign-2025
git pull origin main
```

### Update Containers

```bash
# Docker
docker pull ghcr.io/flouwuenne/boltzgen:latest

# Singularity
rm -rf $NXF_SINGULARITY_CACHEDIR/boltzgen*
# Will re-download on next run
```

## :material-arrow-right: Next Steps

Once installed, check out:

- [Quick Start Guide](../quick-start.md)
- [Basic Usage](usage.md)
- [Pipeline Modes](../modes/overview.md)

---

!!! question "Need Help?"
    - Check [GitHub Issues](https://github.com/FloWuenne/nf-proteindesign-2025/issues)
    - Review [Troubleshooting](../quick-start.md#troubleshooting)
