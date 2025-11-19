# Parameter Configuration Cleanup Summary

## Overview
This document summarizes the cleanup of parameter configuration across the pipeline's config files to eliminate confusion about which parameters are controlled where.

## Key Principle
**Design-specific parameters should be controlled at the samplesheet level**, allowing fine-grained control for each individual sample/target. Config file parameters serve only as **fallback defaults**.

## Changes Made

### 1. `nextflow.config`
**Updated sections with clarifying comments:**

#### Design Generation Options (Target Mode)
- `min_design_length`, `max_design_length`, `length_step`, `n_variants_per_length`, `design_type`
- **Status**: Kept as fallback values with clear documentation
- **Comment added**: These parameters serve as FALLBACK values only when not specified in the samplesheet. For actual design work, specify these PER SAMPLE in your samplesheet.

#### Boltzgen Options
- `protocol`, `num_designs`, `budget`
- **Status**: Kept as fallback values with clear documentation
- **Comment added**: These are typically specified PER SAMPLE in the samplesheet for fine-grained control. Config values serve as fallback defaults only.

### 2. `conf/test_target.config`
**Removed redundant parameters:**
- ❌ Deleted: `min_design_length = 80`
- ❌ Deleted: `max_design_length = 120`
- ❌ Deleted: `length_step = 20`
- ❌ Deleted: `n_variants_per_length = 2`
- ❌ Deleted: `design_type = 'protein'`

**Kept minimal fallback values:**
- ✅ Kept: `num_designs = 3` (for backward compatibility)
- ✅ Kept: `budget = 1` (for backward compatibility)

**Added clear documentation:**
```
// NOTE: All design and Boltzgen parameters (min_length, max_length, length_step, 
// n_variants_per_length, design_type, protocol, num_designs, budget) are specified 
// PER SAMPLE in the samplesheet file (samplesheet_target_test.csv).
// This allows full control over design specifications for each individual target.
```

### 3. `conf/test_design.config`
**Added clear documentation:**
```
// NOTE: Key Boltzgen parameters (protocol, num_designs, budget) are specified PER SAMPLE
// in the samplesheet file (samplesheet_design_test.csv) for fine-grained control.
// The following serve as fallback values only for backward compatibility:
```

### 4. `conf/test.config`
**Added clear documentation:**
```
// NOTE: Design and Boltzgen parameters are typically specified PER SAMPLE in the samplesheet
// for fine-grained control. The following serve as fallback values for quick testing:
```

## Parameter Sources - Quick Reference

| Parameter | Samplesheet (Design Mode) | Samplesheet (Target Mode) | Config Fallback |
|-----------|---------------------------|---------------------------|-----------------|
| `sample_id` | ✅ | ✅ | ❌ |
| `design_yaml` | ✅ | ❌ | ❌ |
| `target_structure` | ❌ | ✅ | ❌ |
| `target_chain_ids` | ❌ | ✅ | ❌ |
| `min_length` | ❌ | ✅ | ✅ (as min_design_length) |
| `max_length` | ❌ | ✅ | ✅ (as max_design_length) |
| `length_step` | ❌ | ✅ | ✅ |
| `n_variants_per_length` | ❌ | ✅ | ✅ |
| `design_type` | ❌ | ✅ | ✅ |
| `protocol` | ✅ | ✅ | ✅ |
| `num_designs` | ✅ | ✅ | ✅ |
| `budget` | ✅ | ✅ | ✅ |

## Benefits of This Cleanup

1. **Clearer Intent**: Comments explicitly state that config parameters are fallback values
2. **Reduced Confusion**: Removed duplicate/unused parameters from test configs
3. **Samplesheet-First**: Emphasizes that per-sample control is the primary design pattern
4. **Backward Compatible**: Kept minimal fallback values to ensure existing workflows still work
5. **Better Documentation**: Users now understand where to set parameters for maximum control

## Samplesheet Examples

### Design Mode (Pre-made YAML)
```csv
sample_id,design_yaml,structure_files,protocol,num_designs,budget
my_design,path/to/design.yaml,path/to/structure.cif,protein-anything,10000,50
```

### Target Mode (Auto-generated YAML)
```csv
sample_id,target_structure,target_chain_ids,min_length,max_length,length_step,n_variants_per_length,design_type,protocol,num_designs,budget
my_target,path/to/target.cif,A,80,120,20,3,protein,protein-anything,10000,50
```

## Recommendations for Users

1. **Always specify key parameters in your samplesheet** for production runs
2. **Use config fallbacks only** for quick tests or when all samples share the same parameters
3. **Leverage per-sample control** to test different design strategies in parallel
4. **Review samplesheet schema** before creating production samplesheets

## Files Modified

- ✏️ `nextflow.config` - Added clarifying comments for fallback parameters
- ✏️ `conf/test.config` - Added documentation
- ✏️ `conf/test_design.config` - Added documentation
- ✏️ `conf/test_target.config` - Removed redundant parameters, added documentation
