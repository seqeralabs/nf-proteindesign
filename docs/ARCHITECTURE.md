# Pipeline Architecture: Target-Based Mode

## System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                        nf-proteindesign Pipeline                     │
│                                                                       │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                     main.nf (Entry Point)                      │  │
│  │                                                                 │  │
│  │  1. Read samplesheet                                           │  │
│  │  2. Detect mode (target_structure vs design_yaml column)      │  │
│  │  3. Route to appropriate workflow                              │  │
│  └────┬──────────────────────────────────────────────┬───────────┘  │
│       │                                                │              │
│       ↓ target_structure                               ↓ design_yaml│
│  ┌────────────────────┐                    ┌──────────────────────┐ │
│  │ TARGET-BASED MODE  │                    │  DESIGN-BASED MODE   │ │
│  │      (NEW)         │                    │    (ORIGINAL)        │ │
│  └────────────────────┘                    └──────────────────────┘ │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Mode 1: Target-Based Workflow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                   workflows/target_to_designs.nf                        │
└─────────────────────────────────────────────────────────────────────────┘

INPUT: [meta, target_structure.cif]
  ↓
┌─────────────────────────────────────────────────────────────────────────┐
│ GENERATE_DESIGN_VARIANTS (modules/local/generate_design_variants.nf)   │
│                                                                         │
│ Python Script Logic:                                                    │
│  1. Parse target structure path                                        │
│  2. Generate length ranges (min → max, by step)                        │
│  3. For each length:                                                    │
│      For each variant (1 to n_variants_per_length):                   │
│        • Create design YAML with:                                      │
│          - Designed entity (protein/peptide/nanobody)                  │
│          - Length specification                                        │
│          - Target structure reference                                  │
│          - Chain selections                                            │
│        • Add diversity (variant-specific constraints)                  │
│        • Write YAML file                                               │
│  4. Generate summary info file                                         │
│                                                                         │
│ Output: design_variants/                                               │
│         ├── target_len50_v1.yaml                                       │
│         ├── target_len50_v2.yaml                                       │
│         ├── target_len50_v3.yaml                                       │
│         ├── target_len70_v1.yaml                                       │
│         └── ... (N total YAMLs)                                        │
└─────────────────────────────────────────────────────────────────────────┘
  ↓
OUTPUT: [meta, [yaml1, yaml2, yaml3, ..., yamlN]]
  ↓
┌─────────────────────────────────────────────────────────────────────────┐
│ Channel Transformation (.transpose)                                     │
│                                                                         │
│ Input:  [meta, [yaml1, yaml2, yaml3]]                                 │
│ Output: [meta1, yaml1]                                                 │
│         [meta2, yaml2]                                                 │
│         [meta3, yaml3]                                                 │
│                                                                         │
│ Each meta gets unique ID from YAML filename                            │
└─────────────────────────────────────────────────────────────────────────┘
  ↓
┌──────────────┬──────────────┬──────────────┬──────────────────┐
│ [meta1,yaml1]│ [meta2,yaml2]│ [meta3,yaml3]│ ... [metaN,yamlN]│
└──────┬───────┴──────┬───────┴──────┬───────┴──────┬───────────┘
       ↓              ↓              ↓              ↓
┌──────────────────────────────────────────────────────────────────────┐
│              BOLTZGEN_RUN (modules/local/boltzgen_run.nf)            │
│                     ⚡ GPU-Limited Parallel Execution                 │
│                                                                       │
│  Each design runs independently:                                     │
│  1. Read design YAML                                                 │
│  2. Run Boltzgen with parameters:                                    │
│     • --protocol (from meta)                                         │
│     • --num_designs (from meta)                                      │
│     • --budget (from meta)                                           │
│  3. Generate:                                                         │
│     • Intermediate designs                                           │
│     • Inverse folded sequences                                       │
│     • Final ranked designs                                           │
│     • Structure predictions                                          │
└──────┬───────────┬───────────┬───────────┬──────────────────────────┘
       ↓           ↓           ↓           ↓
┌─────────────────────────────────────────────────────────────────────┐
│                        Organized Results                             │
│                                                                       │
│  results/                                                            │
│  └── target_id/                                                      │
│      ├── design_variants/         ← Generated YAMLs                  │
│      ├── design_info.txt          ← Summary                         │
│      ├── target_len50_v1/         ← Boltzgen results                │
│      │   ├── intermediate_designs/                                  │
│      │   ├── intermediate_designs_inverse_folded/                   │
│      │   ├── final_ranked_designs/  ⭐ BEST RESULTS                 │
│      │   └── predictions/                                           │
│      ├── target_len50_v2/                                           │
│      ├── target_len50_v3/                                           │
│      └── ... (N result directories)                                 │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Mode 2: Design-Based Workflow (Original)

```
INPUT: samplesheet with design_yaml column
  ↓
┌─────────────────────────────────────────────────────────────────────┐
│ Parse Samplesheet                                                    │
│  • Read CSV                                                          │
│  • Validate design_yaml files exist                                 │
│  • Create channel: [meta, design_yaml]                              │
└─────────────────────────────────────────────────────────────────────┘
  ↓
┌─────────────────────────────────────────────────────────────────────┐
│ BOLTZGEN_RUN (Parallel Execution)                                   │
│  • Process each pre-made YAML                                       │
│  • Same as target-based mode                                        │
└─────────────────────────────────────────────────────────────────────┘
  ↓
┌─────────────────────────────────────────────────────────────────────┐
│ Results                                                              │
│  results/                                                            │
│  ├── sample1/                                                        │
│  │   ├── intermediate_designs/                                      │
│  │   ├── final_ranked_designs/                                      │
│  │   └── predictions/                                               │
│  └── sample2/                                                        │
│      └── ...                                                         │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Module Architecture

```
modules/local/
├── generate_design_variants.nf    ← NEW: YAML generation
│   └── Python script embedded
│       ├── Parse parameters
│       ├── Generate length ranges
│       ├── Create design specifications
│       └── Write YAML files
│
├── create_design_samplesheet.nf   ← NEW: Samplesheet creation (optional)
│   └── Python script embedded
│       ├── List YAML files
│       └── Generate CSV samplesheet
│
├── boltzgen_run.nf                ← UNCHANGED: Core Boltzgen execution
│   └── Docker/Singularity container
│       └── boltz/boltzgen:latest
│
└── ipsae_calculate.nf             ← UNCHANGED: Optional scoring
    └── Custom Python script
        └── assets/ipsae.py
```

---

## Workflow Architecture

```
workflows/
└── target_to_designs.nf           ← NEW: Target-based orchestration
    │
    ├── take: ch_targets
    │   └── Channel: [meta, target_structure]
    │
    ├── main:
    │   ├── GENERATE_DESIGN_VARIANTS(ch_targets)
    │   ├── ch_individual_designs = .transpose().map()
    │   ├── BOLTZGEN_RUN(ch_individual_designs)
    │   └── Optional: IPSAE_CALCULATE(...)
    │
    └── emit:
        ├── design_variants
        ├── design_info
        ├── boltzgen_results
        └── final_designs
```

---

## Data Flow: Channel Transformations

### Initial Channel
```groovy
ch_targets = Channel
    .fromPath(params.input)
    .splitCsv(header: true)
    .map { row -> 
        [meta, target_file]
    }
```

**Example**:
```
[
  [id: 'egfr', min_length: 60, max_length: 120, ...],
  file('data/egfr.cif')
]
```

### After GENERATE_DESIGN_VARIANTS
```groovy
GENERATE_DESIGN_VARIANTS.out.design_yamls
```

**Example**:
```
[
  [id: 'egfr', min_length: 60, ...],
  [
    file('egfr_len60_v1.yaml'),
    file('egfr_len60_v2.yaml'),
    file('egfr_len60_v3.yaml'),
    file('egfr_len80_v1.yaml'),
    ...
  ]
]
```

### After Transpose
```groovy
.transpose()
```

**Example**:
```
[
  [id: 'egfr', ...],
  file('egfr_len60_v1.yaml')
]
[
  [id: 'egfr', ...],
  file('egfr_len60_v2.yaml')
]
[
  [id: 'egfr', ...],
  file('egfr_len60_v3.yaml')
]
...
```

### After Map (ID Assignment)
```groovy
.map { meta, yaml_file ->
    def design_meta = meta.clone()
    design_meta.id = yaml_file.baseName
    [design_meta, yaml_file]
}
```

**Example**:
```
[
  [id: 'egfr_len60_v1', parent_id: 'egfr', ...],
  file('egfr_len60_v1.yaml')
]
[
  [id: 'egfr_len60_v2', parent_id: 'egfr', ...],
  file('egfr_len60_v2.yaml')
]
...
```

### Into BOLTZGEN_RUN
Each item processed independently in parallel:
```groovy
BOLTZGEN_RUN(ch_individual_designs)
```

---

## Mode Detection Logic

```groovy
// main.nf

// 1. Read samplesheet first line
def samplesheet_headers = file(params.input)
    .readLines()[0]
    .split(',')
    .collect { it.trim() }

// 2. Check for mode-specific columns
def is_target_mode = samplesheet_headers.contains('target_structure')
def is_design_mode = samplesheet_headers.contains('design_yaml')

// 3. Validate
if (!is_target_mode && !is_design_mode) {
    error """
    ERROR: Invalid samplesheet format!
    Samplesheet must contain either:
    - 'target_structure' column for target-based mode
    - 'design_yaml' column for design-based mode
    """
}

// 4. Route to workflow
if (is_target_mode) {
    log.info "Running in TARGET-BASED MODE"
    // Create ch_targets
    TARGET_TO_DESIGNS(ch_targets)
} else {
    log.info "Running in DESIGN-BASED MODE"
    // Create ch_input
    BOLTZGEN_RUN(ch_input)
}
```

---

## Parameter Flow

### Global Parameters (nextflow.config)
```groovy
params {
    // Design generation
    min_design_length = 50
    max_design_length = 150
    length_step = 20
    n_variants_per_length = 3
    design_type = 'protein'
    
    // Boltzgen
    protocol = 'protein-anything'
    num_designs = 100
    budget = 10
}
```

### Per-Sample Override (samplesheet)
```csv
sample_id,target_structure,min_length,max_length,num_designs
sample1,data/s1.cif,60,120,1000
```

### Parameter Resolution
```groovy
// In channel creation
meta.min_length = row.min_length ? 
                  row.min_length.toInteger() : 
                  params.min_design_length
```

**Priority**: `Samplesheet` > `Command-line` > `Config default`

---

## Parallelization Strategy

### GPU Resource Management

```groovy
// conf/base.config
process {
    withLabel: 'process_high_gpu' {
        cpus = { check_max(4, 'cpus') }
        memory = { check_max(16.GB, 'memory') }
        time = { check_max(24.h, 'time') }
        accelerator = 1  // 1 GPU per process
        maxForks = 4     // Max 4 parallel GPU jobs
    }
}
```

### Execution Flow

**Example**: 12 designs, 4 GPUs

```
Batch 1 (parallel):  [Design 1] [Design 2] [Design 3] [Design 4]
                          GPU 1      GPU 2      GPU 3      GPU 4
                            ↓          ↓          ↓          ↓
Batch 2 (parallel):  [Design 5] [Design 6] [Design 7] [Design 8]
                          GPU 1      GPU 2      GPU 3      GPU 4
                            ↓          ↓          ↓          ↓
Batch 3 (parallel):  [Design 9] [Design10] [Design11] [Design12]
                          GPU 1      GPU 2      GPU 3      GPU 4
```

**Total Time**: ~3× single design time (not 12×)

---

## Error Handling

### Input Validation
```groovy
// Check target structure exists
if (!file(row.target_structure).exists()) {
    error "ERROR: Target structure file does not exist: ${row.target_structure}"
}

// Validate samplesheet format
if (!is_target_mode && !is_design_mode) {
    error "ERROR: Invalid samplesheet format!"
}
```

### Process-Level Error Handling
```groovy
process GENERATE_DESIGN_VARIANTS {
    errorStrategy 'retry'
    maxRetries 3
    
    // Validation in Python script
    script:
    """
    #!/usr/bin/env python3
    try:
        # Generate designs
    except Exception as e:
        print(f"ERROR: {e}")
        sys.exit(1)
    """
}
```

---

## Output Organization

```
results/
└── {sample_id}/                      ← Per-target directory
    ├── design_variants/              ← Generated YAMLs
    │   ├── {sample}_len{X}_v1.yaml
    │   ├── {sample}_len{X}_v2.yaml
    │   └── ...
    │
    ├── design_info.txt               ← Summary
    │
    ├── {sample}_len{X}_v1/           ← Per-design results
    │   ├── intermediate_designs/
    │   │   ├── ranked_0.cif
    │   │   ├── ranked_1.cif
    │   │   └── ...
    │   │
    │   ├── intermediate_designs_inverse_folded/
    │   │   ├── ranked_0.cif
    │   │   └── ...
    │   │
    │   ├── final_ranked_designs/     ⭐ START HERE
    │   │   ├── ranked_0.cif
    │   │   ├── ranked_1.cif
    │   │   └── ...
    │   │
    │   └── predictions/
    │       ├── ranked_0_model_0.cif
    │       ├── pae_ranked_0_model_0.npz
    │       └── ...
    │
    └── {sample}_len{X}_v2/
        └── ...
```

---

## Extension Architecture

### Adding New Diversity Strategies

```python
# In generate_design_variants.nf

# Current: Length + variant index
for length in lengths:
    for variant_idx in range(n_per_length):
        design_spec = create_design(length, variant_idx)

# Extended: Add new dimensions
for length in lengths:
    for variant_idx in range(n_per_length):
        for ss_preference in ['helix', 'sheet', 'mixed']:
            for compactness in ['high', 'medium', 'low']:
                design_spec = create_design(
                    length, variant_idx,
                    ss_preference, compactness
                )
```

### Custom Processes

```groovy
// Add new process to workflow
include { CUSTOM_FILTER } from './modules/local/custom_filter'

workflow TARGET_TO_DESIGNS {
    GENERATE_DESIGN_VARIANTS(ch_targets)
    CUSTOM_FILTER(GENERATE_DESIGN_VARIANTS.out.design_yamls)
    BOLTZGEN_RUN(CUSTOM_FILTER.out.filtered)
}
```

---

## Performance Characteristics

### Time Complexity
- **Design generation**: O(n) where n = number of designs
  - Typically < 1 minute for 100 designs
  
- **Boltzgen execution**: O(m × k) where:
  - m = num_designs parameter
  - k = number of design variants
  - Limited by GPU availability

### Space Complexity
- **Per design**: ~2-5 GB
- **Total**: n_designs × 3-5 GB
- **Temporary**: Additional 2-3 GB during execution

### Scaling Limits
- **Design count**: Limited by disk space and time
- **Parallel execution**: Limited by GPU count
- **Memory**: Limited by GPU RAM (~10-15 GB per design)

---

## Technology Stack

```
┌─────────────────────────────────────────┐
│            User Interface               │
│  Command Line / Seqera Platform         │
└─────────────────────────────────────────┘
                   ↓
┌─────────────────────────────────────────┐
│         Workflow Engine                 │
│        Nextflow (DSL2)                  │
└─────────────────────────────────────────┘
                   ↓
┌─────────────────────────────────────────┐
│       Container Runtime                 │
│    Docker / Singularity                 │
└─────────────────────────────────────────┘
                   ↓
┌─────────────────────────────────────────┐
│         Execution Layers                │
│  ┌───────────────────────────────────┐  │
│  │   Python 3.11                     │  │
│  │   • Design generation (PyYAML)    │  │
│  │   • IPSAE calculation (NumPy)     │  │
│  └───────────────────────────────────┘  │
│  ┌───────────────────────────────────┐  │
│  │   Boltzgen (Python)               │  │
│  │   • Diffusion models              │  │
│  │   • Structure prediction          │  │
│  │   • Inverse folding               │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
                   ↓
┌─────────────────────────────────────────┐
│         Hardware Layer                  │
│  • CPU: Multi-core                     │
│  • GPU: NVIDIA CUDA                    │
│  • Storage: Network/Local              │
└─────────────────────────────────────────┘
```

---

## Summary

This architecture provides:

✅ **Modularity**: Clear separation of concerns  
✅ **Scalability**: Parallel GPU execution  
✅ **Flexibility**: Dual-mode support  
✅ **Extensibility**: Easy to add new features  
✅ **Maintainability**: Well-organized code structure  
✅ **Robustness**: Error handling and validation  

The design allows for future enhancements while maintaining backward compatibility and production stability.
