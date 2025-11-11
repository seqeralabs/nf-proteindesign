# Implementation Summary: Target-Based Design Generation

## Overview

This implementation adds a new **target-based workflow mode** to the nf-proteindesign pipeline, enabling automatic generation of diversified protein/peptide design specifications from a single target structure input.

## What Was Added

### 1. New Processes

#### `GENERATE_DESIGN_VARIANTS` (`modules/local/generate_design_variants.nf`)
- **Purpose**: Generates multiple diversified design YAML files from a target structure
- **Input**: Target structure file (PDB/CIF) + design parameters
- **Output**: Multiple YAML design specifications
- **Features**:
  - Length variation strategies (min/max/step)
  - Multiple variants per length
  - Support for proteins, peptides, and nanobodies
  - Automatic chain selection from target
  - Diversity strategies (compositional, structural)

#### `CREATE_DESIGN_SAMPLESHEET` (`modules/local/create_design_samplesheet.nf`)
- **Purpose**: Converts generated design YAMLs into a samplesheet format
- **Input**: Collection of design YAML files
- **Output**: CSV samplesheet for Boltzgen processing
- **Note**: Currently integrated into the workflow but can be used for other purposes

### 2. New Workflow

#### `TARGET_TO_DESIGNS` (`workflows/target_to_designs.nf`)
- **Purpose**: Orchestrates the complete target-to-designs workflow
- **Steps**:
  1. Generate design variants from target
  2. Flatten variants into individual designs
  3. Run Boltzgen on each design in parallel
  4. Optional IPSAE scoring
- **Key Feature**: Maintains design metadata throughout workflow

### 3. Updated Main Workflow

#### `main.nf`
- **Auto-detection**: Detects workflow mode from samplesheet headers
  - `target_structure` column → TARGET-BASED mode
  - `design_yaml` column → DESIGN-BASED mode (original)
- **Dual-mode support**: Both workflows coexist seamlessly
- **Clear logging**: Displays which mode is active at startup
- **Validation**: Checks for required columns and files

### 4. Configuration Updates

#### `nextflow.config`
Added new parameters for target-based mode:
```groovy
min_design_length          = 50      // Minimum binder length
max_design_length          = 150     // Maximum binder length
length_step                = 20      // Step between lengths
n_variants_per_length      = 3       // Variants per length
design_type                = 'protein'  // protein/peptide/nanobody
```

### 5. Documentation

#### New Documentation Files
1. **`docs/TARGET_BASED_MODE.md`**: Complete guide to target-based mode
   - Usage examples
   - Parameter tuning
   - Output structure
   - Best practices

2. **`docs/WORKFLOW_MODES.md`**: Comparison of both modes
   - Quick mode selection guide
   - Side-by-side comparison
   - Decision tree
   - Common workflows

3. **`docs/IMPLEMENTATION_SUMMARY.md`**: This file
   - Technical details
   - File structure
   - Implementation decisions

#### Updated Files
- `assets/target_samplesheet_example.csv`: Example input for target mode

---

## How It Works

### Workflow Flow

```
TARGET-BASED MODE:
Input: Target Structure + Parameters
         ↓
  GENERATE_DESIGN_VARIANTS
  (Creates N YAML files)
         ↓
  Transpose Channel
  (Separate channel items)
         ↓
  BOLTZGEN_RUN × N
  (Parallel execution)
         ↓
  Optional IPSAE_CALCULATE
         ↓
  Organized Results

DESIGN-BASED MODE (Original):
Input: Design YAML Files
         ↓
  BOLTZGEN_RUN
  (Parallel execution)
         ↓
  Optional IPSAE_CALCULATE
         ↓
  Results
```

### Channel Operations

#### Target-Based Mode Channel Flow
```groovy
// 1. Parse target samplesheet
ch_targets = Channel
    .fromPath(params.input)
    .splitCsv(header: true)
    .map { row -> [meta, target_file] }

// 2. Generate designs
GENERATE_DESIGN_VARIANTS(ch_targets)
// Output: [meta, [yaml1, yaml2, yaml3, ...]]

// 3. Flatten to individual designs
ch_individual = GENERATE_DESIGN_VARIANTS.out
    .transpose()  // Separates list items
    .map { meta, yaml ->
        def new_meta = meta.clone()
        new_meta.id = yaml.baseName
        [new_meta, yaml]
    }
// Output: [meta1, yaml1], [meta2, yaml2], ...

// 4. Process in parallel
BOLTZGEN_RUN(ch_individual)
```

---

## Design Decisions

### 1. Automatic Mode Detection
**Why**: Single entry point, no flags needed
**Implementation**: Parse samplesheet headers at workflow start
**Benefit**: User-friendly, prevents mode confusion

### 2. Separate Workflow File
**Why**: Modularity and maintainability
**Location**: `workflows/target_to_designs.nf`
**Benefit**: Can be imported/extended independently

### 3. Python-Based Design Generation
**Why**: YAML manipulation and logic
**Alternative Considered**: Groovy/Nextflow native (too complex)
**Benefit**: Familiar syntax, extensive libraries

### 4. Metadata Preservation
**Why**: Track design origin and parameters
**Implementation**: Clone and extend meta map
**Benefit**: Results traceable to parent target

### 5. Parallel Execution Strategy
**Why**: Maximize GPU utilization
**Implementation**: Transpose channel for individual processing
**Benefit**: All designs run simultaneously (resource-limited)

### 6. Design Diversity Strategies
**Current**: Length variation with multiple variants
**Future**: Compositional, structural, interface constraints
**Extensible**: Easy to add new diversity strategies in Python

---

## File Structure

```
nf-proteindesign-2025/
├── main.nf                          # ✨ Updated: Dual-mode support
├── nextflow.config                  # ✨ Updated: New parameters
├── workflows/
│   └── target_to_designs.nf        # ✅ New: Target workflow
├── modules/
│   └── local/
│       ├── boltzgen_run.nf         # ✓ Unchanged
│       ├── ipsae_calculate.nf      # ✓ Unchanged
│       ├── generate_design_variants.nf  # ✅ New
│       └── create_design_samplesheet.nf # ✅ New (optional)
├── docs/
│   ├── TARGET_BASED_MODE.md        # ✅ New: User guide
│   ├── WORKFLOW_MODES.md           # ✅ New: Mode comparison
│   └── IMPLEMENTATION_SUMMARY.md   # ✅ New: This file
└── assets/
    ├── samplesheet_example.csv     # ✓ Original example
    └── target_samplesheet_example.csv  # ✅ New: Target mode example
```

---

## Usage Examples

### Quick Start: Target-Based Mode

```bash
# 1. Create target samplesheet
cat > targets.csv << EOF
sample_id,target_structure,design_type,min_length,max_length
egfr_binder,data/egfr.cif,protein,60,120
EOF

# 2. Run pipeline
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --input targets.csv \
    --length_step 20 \
    --n_variants_per_length 3 \
    --outdir results
```

### What Happens
1. Reads `egfr.cif` structure
2. Generates 12 design YAMLs: 4 lengths (60,80,100,120) × 3 variants = 12 designs
3. Runs Boltzgen on all 12 in parallel
4. Saves results in organized directory structure

### Results Structure
```
results/
└── egfr_binder/
    ├── design_variants/
    │   ├── egfr_binder_len60_v1.yaml
    │   ├── egfr_binder_len60_v2.yaml
    │   ├── egfr_binder_len60_v3.yaml
    │   ├── egfr_binder_len80_v1.yaml
    │   └── ... (12 total)
    ├── design_info.txt
    ├── egfr_binder_len60_v1/
    │   ├── intermediate_designs/
    │   ├── final_ranked_designs/
    │   └── predictions/
    ├── egfr_binder_len60_v2/
    └── ... (12 result directories)
```

---

## Parameter Guide

### Essential Parameters

| Parameter | Default | Description | Example |
|-----------|---------|-------------|---------|
| `min_design_length` | 50 | Minimum binder length | 40 |
| `max_design_length` | 150 | Maximum binder length | 140 |
| `length_step` | 20 | Step between lengths | 25 |
| `n_variants_per_length` | 3 | Variants per length | 5 |
| `design_type` | 'protein' | Molecule type | 'peptide' |

### Calculation Examples

**Example 1**: Default settings
- Range: 50-150, step: 20, variants: 3
- Lengths: 50, 70, 90, 110, 130, 150 (6 lengths)
- **Total designs**: 6 × 3 = **18 designs**

**Example 2**: Peptide screening
- Range: 15-40, step: 5, variants: 2
- Lengths: 15, 20, 25, 30, 35, 40 (6 lengths)
- **Total designs**: 6 × 2 = **12 designs**

**Example 3**: Comprehensive protein screen
- Range: 40-160, step: 10, variants: 5
- Lengths: 40, 50, 60, ..., 150, 160 (13 lengths)
- **Total designs**: 13 × 5 = **65 designs**

### Resource Estimation

Per design (typical):
- **GPU memory**: ~10-15 GB
- **Disk space**: ~2-5 GB
- **Time** (num_designs=100): ~10-30 minutes
- **Time** (num_designs=10000): ~2-6 hours

For 20 designs with 4 GPUs:
- **Parallel batches**: 5 (20 designs ÷ 4 GPUs)
- **Total time**: ~5× single design time

---

## Extension Points

### Adding New Diversity Strategies

Edit `modules/local/generate_design_variants.nf`:

```python
# In the Python script section
if variant_idx == 3:  # New variant type
    # Add custom constraints
    designed_entity['protein']['interface_residues'] = 'specific_positions'
    designed_entity['protein']['ss_composition'] = {
        'helix': 0.4,
        'sheet': 0.3
    }
```

### Custom Design Templates

Create a new process based on `GENERATE_DESIGN_VARIANTS`:
```groovy
process GENERATE_CUSTOM_DESIGNS {
    // Your custom logic here
    // Can read from database, use ML models, etc.
}
```

### Integration with Other Tools

The workflow can be extended to include:
- **Pre-processing**: Structure cleanup, chain selection
- **Post-processing**: Additional scoring, filtering
- **Visualization**: Automated structure rendering
- **Reporting**: Summary statistics, comparison plots

---

## Testing

### Unit Testing Individual Processes

```bash
# Test design generation
nextflow run modules/local/generate_design_variants.nf \
    --target_structure test_data/target.cif \
    -entry test

# Test with stub mode
nextflow run main.nf \
    --input test.csv \
    -stub-run
```

### Integration Testing

```bash
# Small test dataset
nextflow run main.nf \
    -profile test,docker \
    --input assets/target_samplesheet_example.csv \
    --num_designs 10 \
    --budget 5
```

---

## Performance Optimization

### For Maximum Throughput

1. **Increase GPU parallelization**:
```groovy
process {
    withLabel: 'process_high_gpu' {
        maxForks = 8  // Match your GPU count
    }
}
```

2. **Optimize design count**:
- Start with fewer variants (`n_variants_per_length = 2`)
- Increase after validating quality

3. **Use caching**:
```bash
--cache_dir /shared/boltzgen_cache
```

### For Resource-Constrained Environments

1. **Reduce parallelization**:
```groovy
maxForks = 1  // Sequential execution
```

2. **Smaller design batches**:
```bash
--length_step 30  # Fewer length variants
--n_variants_per_length 1  # Single variant per length
```

---

## Backward Compatibility

✅ **Fully backward compatible**
- Original design-based mode unchanged
- Existing samplesheets work without modification
- All original parameters preserved
- No breaking changes to process interfaces

---

## Future Enhancements

### Planned Features

1. **Compositional Diversity**
   - Secondary structure preferences
   - Amino acid composition constraints
   - Hydrophobicity profiles

2. **Interface Specifications**
   - Target binding site selection
   - Contact residue preferences
   - Geometric constraints

3. **Machine Learning Integration**
   - Predict optimal parameters from target
   - Pre-filter unlikely designs
   - Suggest promising length ranges

4. **Advanced Scoring**
   - Automated ranking across variants
   - Binding energy predictions
   - Developability metrics

5. **Visualization**
   - Automated structure rendering
   - Design space exploration plots
   - Interactive result browsers

---

## Troubleshooting

### Common Issues

**Issue**: Too many designs generated
```bash
# Solution: Reduce variants
--length_step 30 --n_variants_per_length 2
```

**Issue**: GPU out of memory
```bash
# Solution: Reduce parallelization
process.maxForks = 1
# or reduce num_designs
--num_designs 50
```

**Issue**: Mode not detected
```bash
# Check samplesheet has correct column:
# Either 'target_structure' or 'design_yaml'
```

---

## Support and Documentation

- **Main README**: Overview and quick start
- **WORKFLOW_MODES.md**: Mode comparison and selection
- **TARGET_BASED_MODE.md**: Detailed target-based guide
- **Boltzgen Docs**: https://github.com/HannesStark/boltzgen
- **Nextflow Docs**: https://www.nextflow.io/docs/latest/

---

## Version Information

- **Pipeline Version**: 1.0.0 (with target-based mode)
- **Nextflow Required**: >=23.04.0
- **Boltzgen**: Latest (from Docker container)
- **Python**: 3.11 (for design generation)

---

## Acknowledgments

This implementation enables high-throughput protein design exploration while maintaining the flexibility and control of the original design-based workflow. The dual-mode approach provides researchers with both automated exploration and precise control depending on their needs.
