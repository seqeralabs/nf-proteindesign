# GPU Configuration Guide

This document describes the GPU acceleration capabilities of the nf-proteindesign pipeline and how to configure your environment to take full advantage of them.

## Overview

The nf-proteindesign pipeline has been optimized to utilize NVIDIA GPUs for processes that benefit from GPU acceleration. This can provide significant speedup for computationally intensive tasks like protein structure prediction and sequence optimization.

## GPU-Accelerated Processes

### 1. BOLTZGEN_RUN (Required GPU)
- **GPU Support**: ✅ Required
- **Speedup**: ~10-50x compared to CPU
- **GPU Configuration**: Uses 1 GPU by default
- **Description**: Boltzgen is the core protein design engine and requires GPU for efficient inference. Running on CPU is possible but significantly slower.

### 2. PROTEINMPNN_OPTIMIZE (Optional GPU)
- **GPU Support**: ✅ Supported (automatic detection)
- **Speedup**: ~3-10x compared to CPU
- **GPU Configuration**: Uses 1 GPU by default
- **Description**: ProteinMPNN is PyTorch-based and CUDA-compatible. The process automatically detects GPU availability and uses CUDA acceleration when available.

### 3. FOLDSEEK_SEARCH (Optional GPU)
- **GPU Support**: ✅ Supported (automatic detection)
- **Speedup**: ~4-27x compared to CPU
- **GPU Configuration**: Uses 1 GPU by default
- **Description**: Foldseek supports GPU-accelerated protein structure searches. The process automatically detects GPU availability and enables GPU mode with optimal prefilter settings.

### Other Processes (CPU-Only)
The following processes do not currently benefit from GPU acceleration:
- `IPSAE_CALCULATE`: NumPy-based calculations (CPU-optimized)
- `PRODIGY_PREDICT`: Binding affinity prediction (CPU-only)
- `CONVERT_CIF_TO_PDB`: BioPython file conversion (I/O bound)
- `GENERATE_DESIGN_VARIANTS`: YAML generation (minimal compute)
- `COLLECT_DESIGN_FILES`: File operations (I/O bound)
- `CONSOLIDATE_METRICS`: Data aggregation (CPU-optimized)

## Hardware Requirements

### Minimum GPU Specifications
- **GPU**: NVIDIA GPU with CUDA support
- **VRAM**: 
  - Boltzgen: 16GB minimum (48GB recommended for large designs)
  - ProteinMPNN: 4GB minimum (8GB recommended)
  - Foldseek: 8GB minimum (16GB recommended for large databases)
- **CUDA Version**: 11.0 or higher
- **Driver**: NVIDIA driver 450.80.02 or higher

### Recommended GPU Configurations
1. **Single GPU Workstation**:
   - NVIDIA RTX 4090 (24GB)
   - NVIDIA RTX A6000 (48GB)
   - NVIDIA A100 (40GB or 80GB)

2. **Multi-GPU Systems**:
   - Each process uses 1 GPU by default
   - Multiple samples can run in parallel on different GPUs
   - Set `max_gpus` parameter to match your system

3. **Cloud GPU Instances**:
   - AWS: g5.xlarge, g5.2xlarge, p3.2xlarge, p4d.24xlarge
   - Google Cloud: n1-standard with T4, V100, or A100 GPUs
   - Azure: NC-series, ND-series

## Container Configuration

### Docker
The pipeline automatically configures Docker containers for GPU access using the `--gpus all` flag.

**Example Docker command** (automatically handled by Nextflow):
```bash
docker run --gpus all <container_image>
```

**Requirements**:
- Docker version 19.03 or higher
- NVIDIA Container Toolkit installed
- nvidia-docker2 package

**Installation** (Ubuntu/Debian):
```bash
# Install NVIDIA Container Toolkit
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | \
  sudo tee /etc/apt/sources.list.d/nvidia-docker.list

sudo apt-get update
sudo apt-get install -y nvidia-docker2
sudo systemctl restart docker
```

### Singularity/Apptainer
The pipeline automatically configures Singularity/Apptainer containers for GPU access using the `--nv` flag.

**Example Singularity command** (automatically handled by Nextflow):
```bash
singularity exec --nv <container_image>
```

**Requirements**:
- Singularity 3.0+ or Apptainer 1.0+
- NVIDIA drivers installed on the host

**GPU binding**: The `--nv` flag automatically binds:
- NVIDIA driver libraries
- GPU devices (/dev/nvidia*)
- CUDA libraries

## Pipeline Configuration

### Default Configuration
The pipeline is pre-configured with GPU support enabled for all compatible processes. No additional configuration is required for basic GPU usage.

### Configuring Maximum GPUs
To increase the maximum number of GPUs per process (for multi-GPU support in future):

**In nextflow.config**:
```groovy
params {
    max_gpus = 4  // Allow up to 4 GPUs per process
}
```

**On command line**:
```bash
nextflow run main.nf --max_gpus 4
```

### Process-Specific GPU Configuration

#### Boltzgen
```groovy
process {
    withName:BOLTZGEN_RUN {
        accelerator = 1  // Number of GPUs
        memory = 48.GB   // Increase for large designs
        time = 72.h      // Extended time for complex designs
    }
}
```

#### ProteinMPNN
```groovy
process {
    withName:PROTEINMPNN_OPTIMIZE {
        accelerator = 1  // Number of GPUs
        memory = 16.GB
        time = 6.h
    }
}
```

#### Foldseek
```groovy
process {
    withName:FOLDSEEK_SEARCH {
        accelerator = 1  // Number of GPUs
        memory = 32.GB
        time = 4.h
    }
}
```

## Running on Different Executors

### Local Executor (GPU Workstation)
```bash
nextflow run main.nf \
    -profile docker \
    --input samplesheet.csv \
    --outdir results
```

**Note**: The local executor will automatically use available GPUs on your system.

### AWS Batch
```groovy
process {
    executor = 'awsbatch'
    queue = 'your-gpu-queue'
    
    withLabel:process_high_gpu {
        // AWS Batch automatically provisions GPU instances based on accelerator directive
        accelerator = 1
    }
}
```

**AWS Batch Compute Environment Requirements**:
- Use GPU-enabled instance types (g5, p3, p4d)
- Enable GPU support in the compute environment
- Use GPU-optimized AMI with NVIDIA drivers

### Google Cloud
```groovy
process {
    executor = 'google-lifesciences'
    
    withLabel:process_high_gpu {
        accelerator = [request: 1, type: 'nvidia-tesla-v100']
    }
}
```

### Kubernetes
```groovy
process {
    executor = 'k8s'
    
    withLabel:process_high_gpu {
        accelerator = 1
        pod = [
            [nodeSelector: 'cloud.google.com/gke-accelerator=nvidia-tesla-v100']
        ]
    }
}
```

## Verification and Troubleshooting

### Verify GPU Availability
Check if GPUs are detected in your environment:
```bash
# Check NVIDIA driver
nvidia-smi

# Check Docker GPU access
docker run --rm --gpus all nvidia/cuda:11.0-base nvidia-smi

# Check Singularity GPU access
singularity exec --nv docker://nvidia/cuda:11.0-base nvidia-smi
```

### Common Issues and Solutions

#### 1. "No GPU detected" messages in logs
**Cause**: GPU drivers not accessible in container
**Solution**: 
- Verify NVIDIA drivers are installed: `nvidia-smi`
- For Docker: Install NVIDIA Container Toolkit
- For Singularity: Use `--nv` flag (automatically configured)

#### 2. "CUDA out of memory" errors
**Cause**: Insufficient GPU memory
**Solution**:
- Reduce `num_designs` or `budget` parameters for Boltzgen
- Reduce `mpnn_batch_size` for ProteinMPNN
- Use GPU with more VRAM
- Process fewer samples in parallel

#### 3. Slow GPU performance
**Cause**: Multiple processes competing for same GPU
**Solution**:
- Set `maxForks` in process configuration to limit parallelism
- Use CUDA_VISIBLE_DEVICES to assign processes to specific GPUs
- Consider using GPU queuing system

#### 4. Container cannot access GPU
**Cause**: Container runtime not configured for GPU
**Solution**:
- Docker: Verify `--gpus all` in containerOptions
- Singularity: Verify `--nv` in runOptions
- Check that container runtime has GPU support enabled

### Debug GPU Usage
Enable GPU diagnostics in process scripts:
```bash
# Check GPU visibility
nvidia-smi
echo "CUDA_VISIBLE_DEVICES: $CUDA_VISIBLE_DEVICES"

# Monitor GPU usage during execution
watch -n 1 nvidia-smi
```

## Performance Optimization

### Single Sample Processing
For single sample runs, ensure each GPU-enabled process gets exclusive GPU access:
```groovy
process {
    maxForks = 1  // Process one sample at a time
}
```

### Multi-Sample Parallel Processing
For multiple samples, allow parallel execution across available GPUs:
```groovy
process {
    withLabel:process_high_gpu {
        maxForks = 4  // Process 4 samples in parallel (requires 4 GPUs)
    }
}
```

### Mixed CPU/GPU Workloads
Optimize resource allocation for workflows with both CPU and GPU tasks:
```groovy
process {
    // CPU processes can run in parallel
    withLabel:process_low {
        maxForks = 8
    }
    
    // GPU processes limited by available GPUs
    withLabel:process_high_gpu {
        maxForks = 2  // If you have 2 GPUs
    }
}
```

## Expected Performance Improvements

### Boltzgen
- **CPU**: ~4-8 hours for small protein designs
- **GPU**: ~30-60 minutes for small protein designs
- **Speedup**: 10-50x depending on design complexity

### ProteinMPNN
- **CPU**: ~5-10 minutes per structure
- **GPU**: ~1-2 minutes per structure
- **Speedup**: 3-10x depending on sequence length

### Foldseek
- **CPU**: ~2-10 minutes per structure (database dependent)
- **GPU**: ~30 seconds - 2 minutes per structure
- **Speedup**: 4-27x depending on database size and search parameters

## Best Practices

1. **GPU Selection**: Use GPUs with at least 16GB VRAM for Boltzgen designs
2. **Batch Processing**: Process multiple samples to maximize GPU utilization
3. **Memory Management**: Monitor GPU memory usage and adjust parameters accordingly
4. **Container Images**: Use official GPU-enabled container images (pre-configured)
5. **Driver Updates**: Keep NVIDIA drivers up to date for optimal performance
6. **Resource Allocation**: Balance CPU and GPU resources based on workflow
7. **Monitoring**: Use `nvidia-smi` to monitor GPU usage and identify bottlenecks

## References

- [Nextflow GPU Configuration](https://www.nextflow.io/docs/latest/process.html#accelerator)
- [NVIDIA Container Toolkit](https://github.com/NVIDIA/nvidia-docker)
- [Singularity GPU Support](https://sylabs.io/guides/3.0/user-guide/gpu.html)
- [Boltzgen Documentation](https://github.com/HannesStark/boltzgen)
- [ProteinMPNN Repository](https://github.com/dauparas/ProteinMPNN)
- [Foldseek GPU Support](https://github.com/steineggerlab/foldseek/wiki)
