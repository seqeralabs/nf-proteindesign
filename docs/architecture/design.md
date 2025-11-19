# Pipeline Architecture

## :material-sitemap: Overview

The nf-proteindesign pipeline features a unified workflow architecture that provides three distinct entry points while maintaining a single execution path. This design maximizes flexibility while ensuring consistency.

## :octicons-workflow-24: Unified Workflow

```mermaid
flowchart TD
    A[Mode Selection] --> B{Entry Point}
    
    B -->|Design Mode| C1[Validate YAMLs]
    B -->|Target Mode| C2[Generate Variants]
    B --> Mode| C3[Predict Pockets]
    
    C1 --> D[Unified Workflow Entry]
    C2 --> D
    C3 --> D
    
    D --> E[Parallel Boltzgen Execution]
    E --> F[Collect Results]
    F --> G{Optional Analysis}
    
    G -->|ipSAE| H1[Score Interfaces]
    G -->|PRODIGY| H2[Predict Affinity]
    
    H1 --> I[Final Output]
    H2 --> I
    
    style D fill:#9C27B0,color:#fff
    style E fill:#8E24AA,color:#fff
    style I fill:#6A1B9A,color:#fff
```

## :material-puzzle: Key Components

### 1. Mode Detection

Automatic detection based on samplesheet:

```groovy
workflow {
    if (params.mode == 'design' || design_yaml_column_present) {
        DESIGN_MODE()
    } else if (params.mode == 'target' || target_structure_column_present) {
        TARGET_MODE()
    }
}
```

### 2. Unified Execution

All modes converge to shared workflow:

```groovy
workflow PROTEIN_DESIGN {
    take:
        design_files
        
    main:
        BOLTZGEN_RUN(design_files)
        
        if (params.run_ipsae) {
            IPSAE_SCORE(BOLTZGEN_RUN.out)
        }
        
        if (params.run_prodigy) {
            PRODIGY_PREDICT(BOLTZGEN_RUN.out)
        }
        
    emit:
        results = BOLTZGEN_RUN.out
}
```

### 3. Parallel Processing

Designs processed in parallel:

```groovy
process BOLTZGEN_RUN {
    label 'gpu'
    
    input:
    tuple val(sample), path(design_yaml)
    
    output:
    tuple val(sample), path("final_ranked_designs/*")
    
    script:
    """
    boltzgen design \
        --design_file ${design_yaml} \
        --output_dir . \
        --n_samples ${params.n_samples}
    """
}
```

## :material-package: Process Organization

### Core Processes

| Process | Purpose | Label |
|---------|---------|-------|
| `FORMAT_BINDING_SITES` | Convert pockets to design specs | `cpu` |
| `GENERATE_DESIGN_VARIANTS` | Create design YAMLs (Target mode) | `cpu` |
| `BOLTZGEN_RUN` | Design proteins with Boltzgen | `gpu` |
| `CONVERT_CIF_TO_PDB` | Convert CIF to PDB format | `cpu` |
| `COLLECT_DESIGN_FILES` | Gather final outputs | `cpu` |
| `PROTEINMPNN_OPTIMIZE` | Sequence optimization | `gpu` |
| `IPSAE_CALCULATE` | Interface scoring | `gpu` |
| `PRODIGY_PREDICT` | Binding affinity prediction | `cpu` |
| `CONSOLIDATE_METRICS` | Generate unified report | `cpu` |

### Resource Labels

```groovy
process {
    withLabel: cpu {
        cpus = 4
        memory = 16.GB
    }
    
    withLabel: gpu {
        cpus = 8
        memory = 32.GB
        clusterOptions = '--gres=gpu:1'
    }
}
```

## :material-file-tree: Module Structure

```
main.nf                           # Main entry point with mode detection
workflows/
└── protein_design.nf             # Unified workflow handling all two modes

modules/local/
├── generate_design_variants.nf   # Generate design YAMLs for target mode
├── create_design_samplesheet.nf  # Create samplesheet for unified workflow
├── boltzgen_run.nf               # Execute Boltzgen design
├── convert_cif_to_pdb.nf         # Convert CIF outputs to PDB format
├── collect_design_files.nf       # Collect final design files
├── proteinmpnn_optimize.nf       # ProteinMPNN sequence optimization
├── ipsae_calculate.nf            # IPSAE interface scoring
├── prodigy_predict.nf            # PRODIGY binding affinity
└── consolidate_metrics.nf        # Consolidated metrics report
```

## :material-cog: Configuration

### Profile System

```groovy
profiles {
    docker {
        docker.enabled = true
        docker.runOptions = '--gpus all'
    }
    
    singularity {
        singularity.enabled = true
        singularity.autoMounts = true
    }
    
    test {
        includeConfig 'conf/test.config'
    }
}
```

### Resource Management

```groovy
params {
    max_cpus = 16
    max_memory = 128.GB
    max_time = 48.h
}
```

## :material-speedometer: Execution Flow

### 1. Initialization

- Parse samplesheet
- Validate inputs
- Detect mode

### 2. Preprocessing

- **Design mode**: Validate YAMLs
- **Target mode**: Generate variants
- ****: Predict pockets + generate YAMLs

### 3. Execution

- Parallel Boltzgen runs
- GPU scheduling
- Result collection

### 4. Post-processing

- Optional ipSAE scoring
- Optional PRODIGY prediction
- Report generation

## :material-chart-timeline: Performance Characteristics

### Parallelization

```
Samples:    Parallel across all samples
Designs:    Parallel within each sample
GPU:        One design per GPU at a time
```

### Scaling

| Resources | Throughput |
|-----------|------------|
| 1 GPU | ~6 designs/hour |
| 4 GPUs | ~24 designs/hour |
| 8 GPUs | ~48 designs/hour |

## :material-source-branch: Development

### Adding New Modules

```groovy
// modules/new_tool/main.nf
process NEW_TOOL {
    label 'cpu'
    
    input:
    tuple val(sample), path(input_file)
    
    output:
    tuple val(sample), path("output/*")
    
    script:
    """
    new_tool --input ${input_file} --output output/
    """
}
```

### Adding New Workflows

```groovy
// workflows/new_mode.nf
include { PROTEIN_DESIGN } from './protein_design'

workflow NEW_MODE {
    take:
        samplesheet
        
    main:
        // Mode-specific preprocessing
        preprocessed = PREPROCESS(samplesheet)
        
        // Call unified workflow
        PROTEIN_DESIGN(preprocessed)
        
    emit:
        results = PROTEIN_DESIGN.out
}
```

## :material-book-open: Further Reading

- [Implementation Details](implementation.md)
- [Nextflow Documentation](https://www.nextflow.io/docs/latest/)
- [DSL2 Guide](https://www.nextflow.io/docs/latest/dsl2.html)

---

!!! note "Extensibility"
    The unified architecture makes it easy to add new modes, analysis tools, or features while maintaining compatibility with existing workflows.
