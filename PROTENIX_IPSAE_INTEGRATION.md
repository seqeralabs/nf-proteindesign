# Protenix ipSAE Integration Summary

## Overview
Added support for calculating ipSAE scores on Protenix-refolded structures by implementing a conversion pipeline from Protenix confidence JSON files to NPZ format compatible with ipSAE.

## Changes Made

### 1. New Python Conversion Script
**File**: `assets/convert_protenix_to_npz.py`

**Features**:
- Extracts PAE (Predicted Aligned Error) matrix from Protenix confidence JSON files
- Searches multiple common JSON key locations for PAE data
- Validates matrix format and value ranges
- Converts to NPZ format with `predicted_aligned_error` key (compatible with ipSAE)
- Comprehensive error handling and user feedback
- Command-line interface with argparse

**Improvements over original script**:
- ✅ Proper argparse implementation instead of raw sys.argv
- ✅ Extensive error handling with detailed diagnostics
- ✅ PAE matrix validation (dimensions, value ranges)
- ✅ Support for nested JSON structures
- ✅ Data type conversion to float32 for consistency
- ✅ Verbose output with progress tracking

### 2. New Nextflow Module
**File**: `modules/local/convert_protenix_to_npz.nf`

**Process**: `CONVERT_PROTENIX_TO_NPZ`
- **Label**: `process_low` (lightweight operation)
- **Container**: `community.wave.seqera.io/library/numpy:2.3.5--f8d2712d76b3e3ce`
- **Inputs**: 
  - `tuple val(meta), path(confidence_json), path(cif_file)` - Protenix outputs
  - `path conversion_script` - Python conversion script
- **Outputs**:
  - `npz_with_cif` - Paired NPZ and CIF files for ipSAE
  - `npz_only` - NPZ files only (for other uses)
  - `versions.yml` - Version tracking

### 3. Workflow Integration
**File**: `workflows/protein_design.nf`

#### Added Include Statement
```groovy
include { CONVERT_PROTENIX_TO_NPZ } from '../modules/local/convert_protenix_to_npz'
```

#### Step 4: Conversion Process (Lines ~79-130)
Added after `PROTENIX_REFOLD` to convert JSON confidence files to NPZ format:

**Key Logic**:
1. Pairs Protenix CIF structures with their confidence JSON files
2. Uses `flatMap` to create individual conversion tasks
3. Matches files by basename (handling `_confidence` suffix)
4. Runs conversion in parallel with PRODIGY (no dependencies)

**Execution Flow**:
```
PROTENIX_REFOLD
    ├── structures (CIF files)
    └── confidence (JSON files)
          ↓
    [Join and pair files]
          ↓
CONVERT_PROTENIX_TO_NPZ
          ↓
    NPZ + CIF pairs
```

#### Updated IPSAE Section (Lines ~135-205)
Modified to process both Boltzgen and Protenix structures:

**Before**: Only Boltzgen NPZ files
**After**: Boltzgen NPZ + Protenix NPZ (conditionally)

**Key Changes**:
1. Split into two parts:
   - **Part 1**: Boltzgen budget designs (existing logic)
   - **Part 2**: Protenix converted NPZ files (new)

2. Added `source` metadata field to track origin ("boltzgen" vs "protenix")

3. Used `mix()` operator to combine both sources:
   ```groovy
   ch_ipsae_input = ch_ipsae_boltzgen.mix(ch_ipsae_protenix)
   ```

4. Conditional inclusion - Protenix NPZ only added if:
   - `params.run_proteinmpnn == true`
   - `params.run_protenix_refold == true`

## Pipeline Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    PROTEIN_DESIGN WORKFLOW                   │
└─────────────────────────────────────────────────────────────┘

BOLTZGEN_RUN
    ├── budget_design_cifs ──┐
    └── budget_design_npz ───┼─→ ch_ipsae_boltzgen ──┐
                             │                        │
PROTEINMPNN (optional)       │                        │
    └── sequences            │                        │
         ↓                   │                        │
PROTENIX_REFOLD (optional)  │                        │
    ├── structures ──────┐   │                        │
    └── confidence ──────┼───┘                        ├─→ IPSAE_CALCULATE
                         │                            │
         [Pair & Match]  │                            │
                         ↓                            │
    CONVERT_PROTENIX_TO_NPZ                          │
         └── npz_with_cif ─→ ch_ipsae_protenix ──────┘

         [Parallel Path]
PROTENIX_REFOLD.structures ──→ PRODIGY_PREDICT
```

## Parallel Execution
As requested, the conversion step runs in **parallel** with PRODIGY:

- ✅ **CONVERT_PROTENIX_TO_NPZ** → Only feeds into **IPSAE** and **CONSOLIDATE_METRICS**
- ✅ **PRODIGY_PREDICT** → Independent, uses CIF files directly
- ✅ No blocking dependencies between conversion and PRODIGY

## Dependencies
```
PROTENIX_REFOLD
    ├── CONVERT_PROTENIX_TO_NPZ (depends on PROTENIX outputs)
    │       └── IPSAE_CALCULATE (depends on converted NPZ)
    │               └── CONSOLIDATE_METRICS (depends on IPSAE)
    │
    └── PRODIGY_PREDICT (independent, parallel execution)
            └── CONSOLIDATE_METRICS (depends on PRODIGY)
```

## Configuration
No new parameters required! The integration automatically activates when:
- `--run_proteinmpnn` is enabled
- `--run_protenix_refold` is enabled
- `--run_ipsae` is enabled

## Output Structure
```
results/
└── <sample_id>/
    ├── protenix/
    │   ├── npz/                          # NEW: Converted NPZ files
    │   │   └── seq_0_model_0.npz
    │   └── <mpnn_id>_protenix_output/
    │       ├── *.cif                      # Structure files
    │       └── *_confidence*.json         # Original JSON files
    │
    └── ipsae_scores/
        ├── boltzgen_design_*.txt          # Boltzgen ipSAE scores
        └── protenix_seq_*_model_*.txt     # NEW: Protenix ipSAE scores
```

## Testing Results
- ✅ Python script syntax validated
- ✅ Nextflow workflow syntax validated
- ✅ Pipeline loads without errors
- ✅ All modules properly included
- ✅ Channel operations correctly structured

## Key Benefits
1. **Unified Analysis**: Both Boltzgen and Protenix structures now get ipSAE scores
2. **Parallel Processing**: Conversion doesn't block PRODIGY analysis
3. **Flexible**: Automatically adapts based on enabled modules
4. **Robust**: Comprehensive error handling and validation
5. **Traceable**: Source metadata tracks origin of each score

## Future Considerations
- The conversion script supports multiple PAE key formats for compatibility
- NPZ files are compressed to save storage space
- Metadata tracking allows filtering/grouping by source in downstream analysis
