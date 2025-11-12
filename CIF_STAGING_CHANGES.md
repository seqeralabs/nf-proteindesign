# CIF File Staging Implementation

## Overview

This document describes the changes made to properly stage CIF/PDB structure files for Boltzgen design tasks. Previously, the pipeline generated YAML files that referenced structure files by their full paths, but these files were not staged into the Boltzgen process work directory, causing "file not found" errors.

## Problem Statement

Boltzgen YAML files reference target structure files (CIF/PDB) using the `path:` field in `file:` entity specifications. For example:

```yaml
entities:
  - file:
      path: 1IVO.cif
      include:
        - chain:
            id: A
```

However, these CIF files were not being staged into the BOLTZGEN_RUN process, causing runtime failures.

## Solution

### 1. Modified BOLTZGEN_RUN Module

**File:** `modules/local/boltzgen_run.nf`

**Change:** Added `structure_files` input parameter

```nextflow
input:
tuple val(meta), path(design_yaml), path(structure_files)
```

This ensures CIF/PDB files are staged into the work directory alongside the design YAML.

### 2. Updated YAML Generation to Use Basenames

Modified three modules to reference only the basename of structure files in generated YAMLs:

#### a. FORMAT_BINDING_SITES (P2Rank mode)

**File:** `modules/local/format_binding_sites.nf`

- Added: `structure_basename = os.path.basename('${protein_structure}')`
- Changed all `path: '${protein_structure}'` to `path: structure_basename`

#### b. GENERATE_DESIGN_VARIANTS (Target mode)

**File:** `modules/local/generate_design_variants.nf`

- Added: `target_file_basename = os.path.basename("${target_structure}")`
- Changed `path: target_file` to `path: target_file_basename`

### 3. Updated Workflows to Pass Structure Files

Modified all three workflow modes to pass structure files to BOLTZGEN_RUN:

#### a. DESIGN Mode

**File:** `main.nf`

- Added `structure_files` column to samplesheet parsing
- Updated input channel to: `[meta, design_yaml, structure_files]`
- Users must now provide structure files in the samplesheet

#### b. TARGET Mode

**File:** `workflows/protein_design.nf`

- Modified channel operations to preserve `target_structure` through GENERATE_DESIGN_VARIANTS
- Output channel format: `[design_meta, yaml_file, structure_file]`

#### c. P2RANK Mode

**Files:** 
- `workflows/protein_design.nf`
- `workflows/p2rank_to_designs.nf`

- Modified channel operations to preserve structure file through FORMAT_BINDING_SITES
- Used `ch_p2rank_results.join().transpose()` to maintain structure file association
- Output channel format: `[design_meta, yaml_file, structure]`

### 4. Updated Samplesheet Schema and Examples

#### a. Design Mode Schema

**File:** `assets/schema_input_design.json`

Added new field:
```json
"structure_files": {
  "type": "string",
  "errorMessage": "Structure files must be a comma-separated list of PDB/CIF file paths"
}
```

#### b. Updated Example Samplesheets

**Files:**
- `assets/samplesheet_example.csv`
- `assets/test_data/samplesheet_design_test.csv`

Added `structure_files` column:
```csv
sample_id,design_yaml,structure_files,protocol,num_designs,budget
egfr_protein_binder,assets/test_data/egfr_protein_design.yaml,assets/test_data/1IVO.cif,protein-anything,10,2
```

## Channel Flow Diagrams

### DESIGN Mode
```
Samplesheet → [meta, yaml, [structures]] → BOLTZGEN_RUN
```

### TARGET Mode
```
Samplesheet → [meta, structure]
           ↓
GENERATE_DESIGN_VARIANTS → [meta, [yamls]]
           ↓ (join)
     [meta, [yamls], structure]
           ↓ (transpose)
     [meta, yaml, structure] → BOLTZGEN_RUN
```

### P2RANK Mode
```
Samplesheet → [meta, structure]
           ↓
P2RANK_PREDICT → [meta, structure, predictions, residues]
           ↓
FORMAT_BINDING_SITES → [meta, [yamls]]
           ↓ (join + transpose)
     [meta, yaml, structure] → BOLTZGEN_RUN
```

## Key Benefits

1. **Correct File Staging:** All required CIF/PDB files are now properly staged into Boltzgen work directories
2. **Portability:** YAML files use relative basenames, making them portable across different execution environments
3. **Consistency:** All three modes (design/target/p2rank) now handle structure files consistently
4. **Multiple Files:** Design mode supports multiple structure files via comma-separated list

## Testing Recommendations

1. **Design Mode:** Test with custom YAML referencing multiple CIF files
2. **Target Mode:** Verify structure file propagates through GENERATE_DESIGN_VARIANTS
3. **P2Rank Mode:** Confirm structure file maintains association through multiple channel operations
4. **Edge Cases:** Test with structure files in different locations (absolute paths, relative paths, remote URLs)

## Migration Guide for Users

### For Design Mode Users

**OLD samplesheet:**
```csv
sample_id,design_yaml,protocol,num_designs,budget
my_design,path/to/design.yaml,protein-anything,100,10
```

**NEW samplesheet:**
```csv
sample_id,design_yaml,structure_files,protocol,num_designs,budget
my_design,path/to/design.yaml,path/to/structure.cif,protein-anything,100,10
```

**For multiple structure files:**
```csv
sample_id,design_yaml,structure_files,protocol,num_designs,budget
my_design,path/to/design.yaml,struct1.cif,struct2.pdb,protein-anything,100,10
```

**Update YAML files to use basenames:**
```yaml
# OLD
entities:
  - file:
      path: /full/path/to/1IVO.cif

# NEW
entities:
  - file:
      path: 1IVO.cif
```

### For Target/P2Rank Mode Users

No changes needed! The `target_structure` column already contains the CIF file path.

## Related Files Modified

1. `modules/local/boltzgen_run.nf`
2. `modules/local/format_binding_sites.nf`
3. `modules/local/generate_design_variants.nf`
4. `workflows/protein_design.nf`
5. `workflows/p2rank_to_designs.nf`
6. `main.nf`
7. `assets/schema_input_design.json`
8. `assets/samplesheet_example.csv`
9. `assets/test_data/samplesheet_design_test.csv`

## Questions Answered

**Q: Is the CIF file always the same as the target we design against?**

A: Yes! In all modes:
- **P2Rank mode:** `target_structure` is the CIF file used for pocket prediction AND design
- **Target mode:** `target_structure` is the CIF file used for design variant generation
- **Design mode:** Users provide both YAML and structure files, and they should match the references in the YAML

The CIF file represents the biological target (e.g., EGFR kinase domain), and we design binders against it. The same file is used throughout the workflow for consistency.
