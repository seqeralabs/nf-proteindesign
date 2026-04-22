# Pipeline Architecture

## :material-sitemap: Overview

The nf-proteindesign pipeline processes design YAML specifications through Complexa with a comprehensive suite of optional analysis modules for sequence optimization, structure validation, and quality assessment.

## :octicons-workflow-24: Complete Pipeline Flow

```mermaid
flowchart TD
    A[Input Samplesheet<br/>with Design YAMLs] --> B{Check Complexa<br/>Output Dir}
    
    B -->|Null| C[Run Complexa Design<br/>GPU Process]
    B -->|Provided| D[Stage Precomputed<br/>Complexa Results]
    
    C --> E[Budget Designs<br/>CIF + NPZ Files]
    D --> E
    
    E --> F{ProteinMPNN<br/>Enabled?}
    F -->|No| Z1[Output Complexa<br/>Designs Only]
    
    F -->|Yes| G[Convert CIF to PDB<br/>Per Design]
    G --> H[ProteinMPNN Optimize<br/>Parallel per Budget Design<br/>GPU Process]
    
    H --> I[Optimized Sequences<br/>FASTA + Scores]
    
    I --> J{Boltz-2 Refold<br/>Enabled?}
    J -->|No| Z2[Output MPNN<br/>Sequences Only]
    
    J -->|Yes| K[Prepare Boltz-2 Input<br/>Split MPNN FASTA<br/>Process Target FASTA]
    
    K --> L[Boltz-2 Structure Prediction<br/>Parallel per Sequence<br/>GPU Process]
    
    L --> M[Boltz-2 Outputs<br/>CIF + Confidence JSON<br/>+ PAE NPZ]
    
    M --> N{Analysis<br/>Modules<br/>Enabled?}
    
    N -->|IPSAE| O[IPSAE Calculate<br/>Interface Scoring<br/>GPU Process]
    N -->|PRODIGY| P[PRODIGY Predict<br/>Binding Affinity<br/>CPU Process]
    N -->|Foldseek| Q[Foldseek Search<br/>Structural Similarity<br/>GPU Process]
    
    O --> R[IPSAE Scores<br/>TXT + ByRes]
    P --> S[PRODIGY Results<br/>TXT Files]
    Q --> T[Foldseek Results<br/>TSV + Summary]
    
    R --> U{Consolidation<br/>Enabled?}
    S --> U
    T --> U
    
    U -->|Yes| V[Consolidate Metrics<br/>Combine All Results<br/>CPU Process]
    
    V --> W[Unified Report<br/>CSV + HTML + MD]
    
    W --> X[Final Output]
    M --> X
    Z1 --> X
    Z2 --> X
    
    style C fill:#9C27B0,color:#fff,stroke:#9C27B0,stroke-width:3px
    style H fill:#8E24AA,color:#fff,stroke:#8E24AA,stroke-width:3px
    style L fill:#7B1FA2,color:#fff,stroke:#7B1FA2,stroke-width:3px
    style V fill:#6A1B9A,color:#fff,stroke:#6A1B9A,stroke-width:3px
    
    classDef gpuProcess fill:#E1BEE7,stroke:#9C27B0,stroke-width:2px
    classDef cpuProcess fill:#F3E5F5,stroke:#9C27B0,stroke-width:1px
    classDef dataNode fill:#FFF9C4,stroke:#FBC02D,stroke-width:2px
    
    class C,H,L,O,Q gpuProcess
    class G,K,P,V cpuProcess
    class E,I,M,R,S,T,W dataNode
```

!!! warning "Key Architecture Notes"
    - **Analysis modules** (IPSAE, PRODIGY, Foldseek) **only process Boltz-2 structures**
    - Both `--run_proteinmpnn` and `--run_boltz2_refold` must be enabled for analysis
    - Complexa budget designs are NOT analyzed directly - only used for ProteinMPNN input
    - Precomputed Complexa results can be reused via `complexa_output_dir` in samplesheet

## :material-puzzle: Key Components

### 1. Core Design Module

Complexa generates protein designs from YAML specifications:

```groovy
process COMPLEXA_RUN {
    label 'gpu'
    
    input:
    tuple val(meta), path(design_yaml), path(structure_files)
    path cache_dir
    
    output:
    tuple val(meta), path("${meta.id}_output"), emit: results
    tuple val(meta), path("${meta.id}_output/intermediate_designs_inverse_folded/refold_cif/*.cif"), emit: budget_design_cifs
    tuple val(meta), path("${meta.id}_output/intermediate_designs_inverse_folded/refold_confidence/*.npz"), emit: budget_design_npz
    
    script:
    """
    complexa design \\
        --design_file ${design_yaml} \\
        --output_dir ${meta.id}_output \\
        --num_designs ${meta.num_designs} \\
        --budget ${meta.budget}
    """
}
```

### 2. ProteinMPNN Sequence Optimization

Optimizes sequences for designed structures:

```groovy
workflow {
    if (params.run_proteinmpnn) {
        CONVERT_CIF_TO_PDB(budget_designs)
        PROTEINMPNN_OPTIMIZE(pdb_files)
        
        if (params.run_boltz2_refold) {
            EXTRACT_TARGET_SEQUENCES(complexa_structures)
            PROTENIX_REFOLD(mpnn_sequences, target_sequences)
            CONVERT_PROTENIX_TO_NPZ(boltz2_outputs)
        }
    }
}
```

### 3. Parallel Analysis Modules

Multiple analyses run simultaneously:

```groovy
workflow {
    // All analyses run in parallel on budget designs
    if (params.run_ipsae) {
        IPSAE_CALCULATE(complexa_cifs, complexa_npz)
        if (boltz2_enabled) {
            IPSAE_CALCULATE(boltz2_cifs, boltz2_npz)
        }
    }
    
    if (params.run_prodigy) {
        PRODIGY_PREDICT(all_cif_files)
    }
    
    if (params.run_foldseek) {
        FOLDSEEK_SEARCH(all_cif_files, database)
    }
    
    if (params.run_consolidation) {
        CONSOLIDATE_METRICS(all_results)
    }
}
```

## :material-package: Process Organization

### Core Processes

| Process | Purpose | Label | Output |
|---------|---------|-------|--------|
| `COMPLEXA_RUN` | Design proteins with Complexa diffusion | `gpu` | CIF + NPZ (budget designs) |
| `CONVERT_CIF_TO_PDB` | Convert CIF structures to PDB format | `cpu` | PDB files |
| `PROTEINMPNN_OPTIMIZE` | Sequence optimization for designs | `gpu` | FASTA sequences + scores |
| `PREPARE_BOLTZ2_SEQUENCES` | Split MPNN FASTA + process target | `cpu` | Individual FASTA files |
| `BOLTZ2_REFOLD` | Structure prediction for MPNN sequences | `gpu` | CIF + JSON + NPZ |
| `IPSAE_CALCULATE` | Interface quality scoring (Boltz-2 only) | `gpu` | TXT scores + byres |
| `PRODIGY_PREDICT` | Binding affinity prediction (Boltz-2 only) | `cpu` | TXT results |
| `FOLDSEEK_SEARCH` | Structural similarity search (Boltz-2 only) | `gpu` | TSV + summary |
| `CONSOLIDATE_METRICS` | Unified metrics report generation | `cpu` | CSV + HTML + MD |

!!! note "Process Dependencies"
    - **BOLTZ2_REFOLD** requires **PROTEINMPNN_OPTIMIZE** output
    - **Analysis processes** (IPSAE, PRODIGY, Foldseek) require **BOLTZ2_REFOLD** output
    - **CONSOLIDATE_METRICS** requires at least one analysis process to be enabled

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
main.nf                              # Main entry point with input parsing
workflows/
└── protein_design.nf                # Main workflow orchestration

modules/local/
├── complexa_run.nf                  # Complexa design generation (GPU)
├── convert_cif_to_pdb.nf            # CIF to PDB conversion
├── proteinmpnn_optimize.nf          # ProteinMPNN sequence optimization (GPU)
├── prepare_boltz2_sequences.nf      # Split MPNN FASTA + process target
├── boltz2_refold.nf                 # Boltz-2 structure prediction (GPU)
├── ipsae_calculate.nf               # ipSAE interface scoring (GPU, Boltz-2 only)
├── prodigy_predict.nf               # PRODIGY binding affinity (CPU, Boltz-2 only)
├── foldseek_search.nf               # Foldseek structural search (GPU, Boltz-2 only)
└── consolidate_metrics.nf           # Metrics consolidation (CPU)

assets/
├── schema_input_design.json         # Samplesheet validation schema
├── ipsae.py                         # ipSAE calculation script
├── parse_prodigy_output.py          # PRODIGY parser script
├── consolidate_design_metrics.py    # Consolidation script
├── NO_MSA                           # Placeholder for missing MSA
└── NO_TEMPLATE                      # Placeholder for missing template
```

!!! info "Asset Files"
    Python helper scripts in `assets/` are staged into process working directories at runtime. Placeholder files enable Kubernetes/cloud execution when optional inputs are not provided.

## :material-cog: Configuration

### Profile System

```groovy
profiles {
    docker {
        docker.enabled = true
        docker.runOptions = '--gpus all'
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

- Parse samplesheet with design YAMLs
- Validate inputs and structure files
- Create input channels

### 2. Design Generation

- Parallel Complexa design runs
- Generate budget designs (CIF + NPZ)
- GPU-accelerated diffusion sampling

### 3. Sequence Optimization (Optional)

- Convert CIF to PDB format
- ProteinMPNN sequence optimization
- Boltz-2 structure prediction
- Convert Boltz-2 JSON to NPZ

### 4. Parallel Analysis (Optional)

- **ipSAE**: Interface quality scoring (Complexa + Boltz-2)
- **PRODIGY**: Binding affinity prediction (all structures)
- **Foldseek**: Structural similarity search (all structures)

### 5. Consolidation (Optional)

- Collect all analysis metrics
- Generate unified CSV report
- Create markdown summary

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

## :material-book-open: Further Reading

- [Implementation Details](implementation.md)
- [Nextflow Documentation](https://www.nextflow.io/docs/latest/)
- [DSL2 Guide](https://www.nextflow.io/docs/latest/dsl2.html)

---

!!! note "Extensibility"
    The modular architecture makes it easy to add new analysis tools or features while maintaining compatibility with existing workflows.
