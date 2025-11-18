# Implementation Details

## :material-code-tags: Technical Overview

This document provides technical details about the nf-proteindesign pipeline implementation, including design decisions, container specifications, and development guidelines.

## :material-docker: Container Strategy

### Base Images

The pipeline uses specialized containers for each component:

```yaml
Containers:
  boltzgen: "ghcr.io/flouwuenne/boltzgen:latest"
  proteinmpnn: "ghcr.io/flouwuenne/proteinmpnn:latest"
  ipsae: "ghcr.io/flouwuenne/ipsae:latest"
  prodigy: "ghcr.io/flouwuenne/prodigy:latest"  
  p2rank: "davidhoksza/p2rank:2.4.2"
```

### GPU Support

CUDA 11.8+ required for Boltzgen:

```dockerfile
FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04
RUN pip install torch==2.0.1 --index-url https://download.pytorch.org/whl/cu118
```

## :material-file-code: Code Organization

### Directory Structure

```
nf-proteindesign-2025/
├── main.nf                              # Main entry point with mode detection
├── nextflow.config                      # Pipeline configuration
├── conf/
│   ├── base.config                     # Base resource settings
│   ├── modules.config                  # Module-specific configuration
│   ├── test.config                     # Test profile configuration
│   └── test_full.config                # Full test profile
├── workflows/
│   └── protein_design.nf               # Unified workflow handling all modes
├── modules/local/
│   ├── p2rank_predict.nf
│   ├── format_binding_sites.nf
│   ├── generate_design_variants.nf
│   ├── create_design_samplesheet.nf
│   ├── boltzgen_run.nf
│   ├── convert_cif_to_pdb.nf
│   ├── collect_design_files.nf
│   ├── proteinmpnn_optimize.nf
│   ├── ipsae_calculate.nf
│   ├── prodigy_predict.nf
│   └── consolidate_metrics.nf
├── bin/
│   ├── convert_cif_to_pdb.py          # CIF to PDB conversion
│   ├── collect_boltzgen_outputs.py    # Collect Boltzgen results
│   ├── consolidate_metrics.py         # Generate unified metrics report
│   └── create_design_yaml.py          # Generate design YAML files
└── assets/
    ├── schema_input_design.json        # Design mode samplesheet schema
    ├── schema_input_target.json        # Target mode samplesheet schema
    ├── schema_input_p2rank.json        # P2Rank mode samplesheet schema
    └── test_data/                       # Test datasets
        ├── designs/                     # Pre-made design YAMLs
        ├── structures/                  # Test structures
        └── samplesheets/                # Test samplesheets
```

## :material-language-python: Helper Scripts

### Samplesheet Validation

```python
#!/usr/bin/env python3
"""
Validates samplesheet format and content.
"""

import sys
import csv
from pathlib import Path

def validate_samplesheet(file_path):
    """Validate samplesheet CSV format."""
    
    required_columns = ['sample']
    mode_columns = {
        'design': ['design_yaml'],
        'target': ['target_structure'],
        'p2rank': ['target_structure']
    }
    
    with open(file_path) as f:
        reader = csv.DictReader(f)
        headers = reader.fieldnames
        
        # Check required columns
        for col in required_columns:
            if col not in headers:
                sys.exit(f"Missing required column: {col}")
        
        # Detect mode
        mode = detect_mode(headers)
        print(f"Detected mode: {mode}")
        
        return True

if __name__ == '__main__':
    validate_samplesheet(sys.argv[1])
```

## :material-test-tube: Testing

### Test Configuration

```groovy
// conf/test.config
params {
    input = 'test_data/samplesheet_test.csv'
    outdir = 'test_results'
    n_samples = 5
    max_cpus = 4
    max_memory = 16.GB
}
```

### Running Tests

```bash
# Quick test
nextflow run main.nf -profile test,docker

# Full test suite
nextflow run tests/ -profile test,docker
```

## :material-format-list-checks: Best Practices

### Process Definition

```groovy
process EXAMPLE_PROCESS {
    tag "$sample"           // Show sample name in logs
    label 'gpu'            // Apply resource label
    publishDir "${params.outdir}/${sample}", 
        mode: 'copy'       // Copy instead of symlink
    
    input:
    tuple val(sample), path(input_file)
    
    output:
    tuple val(sample), path("output/*"), emit: results
    path "*.log", emit: logs
    
    script:
    """
    tool --input ${input_file} \
         --output output/ \
         --threads ${task.cpus} \
         2>&1 | tee process.log
    """
}
```

### Error Handling

```groovy
workflow {
    main:
        PROCESS(input_ch)
            .map { sample, files ->
                if (files.isEmpty()) {
                    log.warn "No output for sample: ${sample}"
                    return null
                }
                return [sample, files]
            }
            .filter { it != null }
}
```

## :material-database: Channel Management

### Creating Channels

```groovy
// From samplesheet
Channel
    .fromPath(params.input)
    .splitCsv(header: true)
    .map { row ->
        [row.sample, file(row.design_yaml)]
    }
    .set { design_ch }

// From file patterns
Channel
    .fromPath("${params.outdir}/*/final_ranked_designs/*.cif")
    .map { file ->
        def sample = file.parent.parent.parent.name
        [sample, file]
    }
    .set { results_ch }
```

### Combining Channels

```groovy
// Join by sample ID
design_ch
    .join(metadata_ch, by: 0)
    .set { combined_ch }

// Combine all
Channel
    .of(design_ch, metadata_ch)
    .flatten()
    .collect()
    .set { all_inputs }
```

## :material-cog: Configuration Management

### Parameter Validation

```groovy
// nextflow.config
params {
    // Validate parameters
    validate_params = true
}

def validateParameters() {
    if (params.n_samples < 1) {
        error "n_samples must be >= 1"
    }
    if (params.max_length < params.min_length) {
        error "max_length must be >= min_length"
    }
}

if (params.validate_params) {
    validateParameters()
}
```

### Profile Inheritance

```groovy
profiles {
    base {
        process.container = 'ubuntu:22.04'
    }
    
    docker {
        includeConfig 'conf/base.config'
        docker.enabled = true
        docker.runOptions = '--gpus all'
    }
    
    singularity {
        includeConfig 'conf/base.config'
        singularity.enabled = true
    }
}
```

## :material-speedometer: Performance Optimization

### Resource Allocation

```groovy
process {
    // Dynamic resource allocation
    withLabel: gpu {
        cpus = { 8 * task.attempt }
        memory = { 32.GB * task.attempt }
        time = { 24.h * task.attempt }
        errorStrategy = 'retry'
        maxRetries = 2
    }
}
```

### Caching Strategy

```bash
# Enable Nextflow caching
nextflow run main.nf -resume

# Clear cache if needed
nextflow clean -f
```

## :material-bug: Debugging

### Enable Debug Mode

```bash
# Verbose logging
nextflow run main.nf -with-trace -with-timeline -with-report

# Debug specific processes
nextflow run main.nf -process.debug true
```

### Inspect Work Directory

```bash
# Find failed process
grep 'FAILED' .nextflow.log

# Check work directory
cd work/ab/cd1234...
cat .command.log
cat .command.err
```

## :material-file-document: Documentation

### Module Documentation

```groovy
/**
 * BOLTZGEN_RUN: Execute Boltzgen protein design
 *
 * @input tuple(sample_id, design_yaml)
 * @output tuple(sample_id, designs_dir)
 * @param params.n_samples Number of designs to generate
 * @param params.timesteps Diffusion timesteps
 */
process BOLTZGEN_RUN {
    // Process implementation
}
```

## :material-source-branch: Version Control

### Release Process

1. Update version in `nextflow.config`
2. Update `CHANGELOG.md`
3. Create git tag
4. Push containers to registry
5. Create GitHub release

```bash
# Tag release
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0
```

## :material-arrow-right: Further Reading

- [Pipeline Architecture](design.md)
- [Nextflow Patterns](https://nextflow-io.github.io/patterns/)
- [Best Practices](https://nf-co.re/docs/contributing/guidelines)

---

!!! tip "Contributing"
    See the [GitHub repository](https://github.com/FloWuenne/nf-proteindesign-2025) for contribution guidelines.
