# Test Configuration Cleanup Summary

## Overview
Successfully reorganized test configurations from 3 general test profiles to 6 specific test profiles, each testing a single design type with reduced parameters.

## Changes Made

### 1. New Test Profiles Created (6 total)

#### Design Mode Tests (3)
- `test_design_protein` - Tests protein binder design with pre-made YAML
- `test_design_peptide` - Tests peptide binder design with pre-made YAML  
- `test_design_nanobody` - Tests nanobody design with pre-made YAML

#### Target Mode Tests (3)
- `test_target_protein` - Tests auto-generated protein design from target structure
- `test_target_peptide` - Tests auto-generated peptide design from target structure
- `test_target_nanobody` - Tests auto-generated nanobody design from target structure

### 2. New Files Created

#### Config Files (conf/)
- `test_design_nanobody.config`
- `test_design_peptide.config`
- `test_design_protein.config`
- `test_target_nanobody.config`
- `test_target_peptide.config`
- `test_target_protein.config`

#### Samplesheet Files (assets/test_data/)
- `samplesheet_design_nanobody.csv`
- `samplesheet_design_peptide.csv`
- `samplesheet_design_protein.csv`
- `samplesheet_target_nanobody.csv`
- `samplesheet_target_peptide.csv`
- `samplesheet_target_protein.csv`

### 3. Files Removed

#### Old Config Files
- `conf/test_design.config` (replaced by 3 specific design configs)
- `conf/test_target.config` (replaced by 3 specific target configs)
- `conf/test_production.config` (removed as requested)

#### Old Samplesheet Files
- `assets/test_data/samplesheet_design_test.csv`
- `assets/test_data/samplesheet_target_test.csv`
- `assets/test_data/samplesheet_production_test.csv`
- `assets/test_data/samplesheet_target_url_test.csv`

#### Old YAML Files
- `assets/test_data/egfr_protein_production.yaml`

### 4. Updated Files

#### nextflow.config
- Replaced 3 old test profile references with 6 new test profiles
- Updated profile configuration section

#### README.md
- Updated quick start example to use `test_design_protein`
- Completely rewrote test profiles section with all 6 new profiles
- Updated test profile comparison table with new parameters

#### docs/getting-started/installation.md
- Updated quick test section to use new `test_design_protein` profile
- Simplified test instructions

## Parameter Changes

All test profiles now use:
- **num_designs**: 5 (reduced from 10)
- **budget**: 2 (unchanged)
- **Single design per test** (reduced from 3 designs per test)

## Test Profile Details

| Profile | Mode | Type | Sample | num_designs | budget | Runtime |
|---------|------|------|--------|-------------|--------|---------|
| test_design_protein | Design | Protein | egfr_protein_binder | 5 | 2 | ~15 min |
| test_design_peptide | Design | Peptide | egfr_peptide_binder | 5 | 2 | ~15 min |
| test_design_nanobody | Design | Nanobody | egfr_nanobody_binder | 5 | 2 | ~15 min |
| test_target_protein | Target | Protein | egfr_target_protein | 5 | 2 | ~20 min |
| test_target_peptide | Target | Peptide | egfr_target_peptide | 5 | 2 | ~20 min |
| test_target_nanobody | Target | Nanobody | egfr_target_nanobody | 5 | 2 | ~20 min |

## Usage Examples

```bash
# Test design mode with protein binder
nextflow run seqeralabs/nf-proteindesign -profile test_design_protein,docker

# Test design mode with peptide binder
nextflow run seqeralabs/nf-proteindesign -profile test_design_peptide,docker

# Test design mode with nanobody
nextflow run seqeralabs/nf-proteindesign -profile test_design_nanobody,docker

# Test target mode with auto-generated protein design
nextflow run seqeralabs/nf-proteindesign -profile test_target_protein,docker

# Test target mode with auto-generated peptide design
nextflow run seqeralabs/nf-proteindesign -profile test_target_peptide,docker

# Test target mode with auto-generated nanobody design
nextflow run seqeralabs/nf-proteindesign -profile test_target_nanobody,docker
```

## Benefits

1. **Faster Testing**: Reduced num_designs from 10 to 5
2. **Focused Testing**: Each profile tests exactly one design type
3. **Better Organization**: Clear separation between design and target modes
4. **Easier Debugging**: Isolated tests make it easier to identify issues
5. **Comprehensive Coverage**: All three molecule types (protein, peptide, nanobody) tested in both modes

## Verification Steps

All changes have been verified:
- ✅ All 6 new config files created in conf/
- ✅ All 6 new samplesheet files created in assets/test_data/
- ✅ All old config files removed from conf/
- ✅ All old samplesheet files removed from assets/test_data/
- ✅ nextflow.config updated with new profile references
- ✅ README.md updated with new test profiles documentation
- ✅ docs/getting-started/installation.md updated
- ✅ No dangling references to old test profiles

## Next Steps

Ready to commit these changes to the repository!
