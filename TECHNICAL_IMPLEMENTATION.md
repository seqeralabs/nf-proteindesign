# Implementation Details

## Technical Overview

This document provides technical details about the nf-proteindesign pipeline implementation, including design decisions, container specifications, and development guidelines.

---

## Development Log (Seqera AI-Assisted)

This pipeline was developed iteratively using **Seqera AI** as a proof of principle. Below is a chronological record of major implementation steps, what was done, and approximate time spent.

### Step 1 — Initial Pipeline Scaffolding (~15 min)

Initial Investigation and Understanding of current nf-proteindesign pipeline

- `main.nf` entry point with parameter validation and input parsing
- `workflows/protein_design.nf` main workflow orchestrating all modules
- `nextflow.config` with profiles for Docker, Singularity, test data, and Seqera Platform
- `conf/base.config` with resource labels (CPU, GPU, memory tiers)
- `conf/modules.config` with per-process publishDir configuration
- Input samplesheet validation via nf-schema (`assets/schema_input_design.json`)

### Step 2 — Core Design Module: BoltzGen → Complexa (~20 min)

Implemented the generative protein design module:

- **Originally** created `modules/local/boltzgen_run.nf` wrapping the BoltzGen model
- Authored `bin/collect_complexa_outputs.py` to gather CIF structures and confidence files from model output
- Wired samplesheet fields (`design_yaml`, `protocol`, `num_designs`, `budget`) through to the process
- GPU resource allocation with dynamic retry strategy

### Step 3 — Downstream Analysis Modules (~30 min)

Added the full suite of optional post-design analysis modules:

| Module | File | Purpose |
|--------|------|---------|
| ProteinMPNN | `proteinmpnn_optimize.nf` | Sequence optimization for designed binders |
| Boltz-2 Refold | `boltz2_refold.nf`, `prepare_boltz2_sequences.nf` | Independent structure prediction to validate designs |
| IPSAE | `ipsae_calculate.nf` | Interface pairwise shape & electrostatic scoring |
| PRODIGY | `prodigy_predict.nf` | Binding affinity prediction (ΔG) |
| Foldseek | `foldseek_search.nf` | Structural similarity search against PDB/AlphaFold DB |
| Consolidation | `consolidate_metrics.nf` | Unified CSV/JSON metrics report across all modules |

Supporting utilities created:

- `convert_cif_to_pdb.nf` — CIF → PDB conversion for tools requiring PDB input
- `collect_design_files.nf` — File collection and organization per sample
- `split_proteinmpnn_sequences.nf` — Split multi-sequence FASTA for parallel refolding
- `extract_target_sequences.nf` — Extract target chain sequences from design YAMLs
- `create_design_samplesheet.nf` — Dynamic samplesheet generation for batched designs

### Step 4 — Test Data & Profiles (~10 min)

Created three test profiles with real-world design specifications:

- `test_design_protein` — Protein binder against Nipah virus glycoprotein (2VSM)
- `test_design_nanobody` — Nanobody design using built-in scaffolds
- `test_design_peptide` — Peptide binder design

Test data in `assets/test_data/`:

- Nipah virus glycoprotein structure (`.cif`), target sequence (`.fasta`), MSA (`.a3m`)
- Three design YAML specifications
- Three corresponding samplesheet CSVs

### Step 5 — Documentation Site (~15 min)

Generated a full MkDocs Material documentation site:

- Architecture diagrams (Mermaid flowcharts)
- Getting started guides (installation, usage, quick reference)
- Per-module analysis documentation (ProteinMPNN, IPSAE, PRODIGY, Foldseek, consolidation)
- Auto-generated parameter reference from `nextflow_schema.json`
- `mkdocs.yml` configuration with navigation, search, and theme

### Step 6 — Schema & Parameter Validation (~5 min)

- `nextflow_schema.json` with grouped parameters, descriptions, defaults, and enums
- `bin/generate_parameter_docs.py` to auto-generate `docs/reference/parameters.md` from schema
- MkDocs pre-build hook (`docs/hooks/update_dynamic_content.py`) for automatic doc regeneration

### Step 7 — BoltzGen → Proteina-Complexa Rename (~15 min)

Renamed the generative design engine throughout the entire codebase after the tool was rebranded:

- **New module**: `modules/local/proteina_complexa_design.nf` (rewired process name, container, and commands)
- **Deleted**: `modules/local/boltzgen_run.nf`
- **Workflow**: Updated `protein_design.nf` — process call `BOLTZGEN_RUN` → `PROTEINA_COMPLEXA_DESIGN`, all channel names
- **Config**: All `boltzgen` process labels, params, and container refs → `complexa` / `proteina_complexa` across `nextflow.config`, `conf/base.config`, `conf/modules.config`
- **Schema**: `nextflow_schema.json` parameter names, descriptions, output directory references
- **Container images**: `ghcr.io/flouwuenne/boltzgen:latest` → `cr.seqera.io/scidev/complexa:latest`
- **Docs**: All 15+ markdown files updated — terminology, URLs (`Proteina-AI/complexa`), navigation
- **Test data YAMLs**: Comment headers updated
- **Python scripts**: `bin/prepare_boltz2_input.py`, `assets/ipsae.py` — code comments
- **README.md**: Full rewrite of all references
- **Verification**: Zero `boltzgen` references remain project-wide

### Summary

| Phase | Description | Approx. Time |
|-------|-------------|---------------|
| 1 | Pipeline scaffolding | ~15 min |
| 2 | Core design module (BoltzGen) | ~20 min |
| 3 | Downstream analysis modules (6 tools) | ~30 min |
| 4 | Test data & profiles | ~10 min |
| 5 | Documentation site (MkDocs) | ~15 min |
| 6 | Schema & parameter validation | ~5 min |
| 7 | BoltzGen → Complexa rename | ~15 min |
| **Total** | **End-to-end pipeline + docs + rename** | **~1 hr 50 min** |

!!! info "All development was performed interactively with Seqera AI"
    Each step involved conversational iteration — describing intent, reviewing generated code, requesting adjustments, and validating outputs. The times above reflect wall-clock time including review and refinement, not just code generation.

---

## Container Strategy

### Base Images

The pipeline uses specialized containers for each component:

```yaml
Containers:
  complexa: "cr.seqera.io/scidev/complexa:latest"
  proteinmpnn: "ghcr.io/flouwuenne/proteinmpnn:latest"
  ipsae: "ghcr.io/flouwuenne/ipsae:latest"
  prodigy: "ghcr.io/flouwuenne/prodigy:latest"  
```

### GPU Support

CUDA 11.8+ required for Complexa:

```dockerfile
FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04
RUN pip install torch==2.0.1 --index-url https://download.pytorch.org/whl/cu118
```

## Code Organization

### Directory Structure

```
nf-proteindesign/
├── main.nf                              # Main entry point with parameter validation
├── nextflow.config                      # Pipeline configuration & profiles
├── nextflow_schema.json                 # Parameter schema (nf-schema v2)
├── conf/
│   ├── base.config                     # Base resource settings (CPU/GPU labels)
│   ├── modules.config                  # Per-process publishDir configuration
│   ├── test_design_protein.config      # Test profile: protein binder design
│   ├── test_design_nanobody.config     # Test profile: nanobody design
│   └── test_design_peptide.config      # Test profile: peptide design
├── workflows/
│   └── protein_design.nf               # Unified workflow orchestrating all modules
├── modules/local/
│   ├── proteina_complexa_design.nf     # Core: Complexa generative design (GPU)
│   ├── collect_design_files.nf         # Collect & organize design outputs
│   ├── convert_cif_to_pdb.nf          # CIF → PDB format conversion
│   ├── proteinmpnn_optimize.nf         # ProteinMPNN sequence optimization
│   ├── split_proteinmpnn_sequences.nf  # Split multi-seq FASTA for parallel refold
│   ├── extract_target_sequences.nf     # Extract target sequences from design YAMLs
│   ├── create_design_samplesheet.nf    # Dynamic samplesheet for batched designs
│   ├── prepare_boltz2_sequences.nf     # Prepare inputs for Boltz-2 refolding
│   ├── boltz2_refold.nf               # Boltz-2 structure prediction (GPU)
│   ├── ipsae_calculate.nf             # IPSAE interface scoring
│   ├── prodigy_predict.nf             # PRODIGY binding affinity prediction
│   ├── foldseek_search.nf            # Foldseek structural similarity search
│   └── consolidate_metrics.nf         # Unified metrics report generation
├── bin/
│   ├── collect_complexa_outputs.py    # Collect Complexa CIF/confidence outputs
│   ├── convert_cif_to_pdb.py         # CIF to PDB conversion script
│   ├── prepare_boltz2_input.py        # Prepare Boltz-2 input sequences
│   ├── consolidate_metrics.py         # Generate unified CSV/JSON metrics
│   ├── boltz_predict_wrapper.py       # Boltz-2 prediction wrapper
│   ├── generate_parameter_docs.py     # Auto-generate parameter docs from schema
│   └── validate_docs.py              # Documentation validation
└── assets/
    ├── schema_input_design.json       # Samplesheet validation schema
    ├── ipsae.py                       # IPSAE scoring utilities
    └── test_data/
        ├── nipah_protein_design.yaml            # Protein binder design spec
        ├── nipah_nanobody_design.yaml           # Nanobody design spec
        ├── nipah_peptide_design.yaml            # Peptide design spec
        ├── nipah_virus_Glycoprotein_*.cif       # Target structure (2VSM)
        ├── nipah_virus_target_sequence_*.fasta  # Target sequence
        ├── nipah_glycoprotein_msa_*.a3m         # MSA for target
        ├── samplesheet_design_protein.csv       # Test samplesheet: protein
        ├── samplesheet_design_nanobody.csv      # Test samplesheet: nanobody
        └── samplesheet_design_peptide.csv       # Test samplesheet: peptide
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
    
    required_columns = ['sample_id', 'design_yaml']
    
    with open(file_path) as f:
        reader = csv.DictReader(f)
        headers = reader.fieldnames
        
        # Check required columns
        for col in required_columns:
            if col not in headers:
                sys.exit(f"Missing required column: {col}")
        
        print(f"Valid design mode samplesheet")
        
        return True

if __name__ == '__main__':
    validate_samplesheet(sys.argv[1])
```

## Testing

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

## Best Practices

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

## Configuration Management

### Parameter Validation

```groovy
// nextflow.config
params {
    // Validate parameters
    validate_params = true
}

def validateParameters() {
    if (params.num_designs < 1) {
        error "num_designs must be >= 1"
    }
    if (params.budget < 1) {
        error "budget must be >= 1"
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

## Debugging

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
 * PROTEINA_COMPLEXA_DESIGN: Execute Complexa generative protein design
 *
 * @input tuple(meta, design_yaml)
 * @output tuple(meta, cif_files, confidence_files)
 * @param params.num_designs Number of designs to generate
 * @param params.budget Diffusion budget (sampling steps)
 */
process PROTEINA_COMPLEXA_DESIGN {
    // Process implementation
}
```

## Version Control

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

## Further Reading

- [Pipeline Architecture](design.md)
- [Nextflow Patterns](https://nextflow-io.github.io/patterns/)
- [Best Practices](https://nf-co.re/docs/contributing/guidelines)

---

!!! tip "Contributing"
    See the [GitHub repository](https://github.com/seqeralabs/nf-proteindesign) for contribution guidelines.
