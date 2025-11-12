# Testing Checklist for CIF File Staging

## Pre-Commit Checks

- [ ] All modified files saved
- [ ] No syntax errors in Nextflow files
- [ ] Samplesheet examples updated with structure_files column
- [ ] Schema updated with structure_files field

## Unit Tests

### Test 1: Design Mode with Single CIF
```bash
# Create test samplesheet
cat > test_design_single.csv << EOF
sample_id,design_yaml,structure_files,protocol,num_designs,budget
test1,assets/test_data/egfr_protein_design.yaml,assets/test_data/1IVO.cif,protein-anything,2,1
EOF

# Run pipeline
nextflow run . \
  --input test_design_single.csv \
  --mode design \
  --outdir results_design_single \
  -profile docker
```

**Expected Result:**
- [ ] Pipeline launches successfully
- [ ] BOLTZGEN_RUN receives both YAML and CIF
- [ ] Work directory contains: `egfr_protein_design.yaml` and `1IVO.cif`
- [ ] Boltzgen runs without "file not found" errors
- [ ] Designs are generated successfully

### Test 2: Design Mode with Multiple CIFs
```bash
# Create test with multiple structures
cat > test_design_multi.csv << EOF
sample_id,design_yaml,structure_files,protocol,num_designs,budget
test2,assets/test_data/egfr_protein_design.yaml,assets/test_data/1IVO.cif,assets/test_data/1IVO.cif,protein-anything,2,1
EOF

# Run pipeline
nextflow run . \
  --input test_design_multi.csv \
  --mode design \
  --outdir results_design_multi \
  -profile docker
```

**Expected Result:**
- [ ] Both CIF files are parsed correctly
- [ ] Both CIF files are staged into work directory
- [ ] Pipeline completes successfully

### Test 3: Target Mode
```bash
# Use existing target mode test
cat > test_target.csv << EOF
sample_id,target_structure,target_chain_ids,min_length,max_length,length_step,n_variants_per_length,design_type,protocol,num_designs,budget
egfr_target,assets/test_data/1IVO.cif,A,80,120,20,2,protein,protein-anything,2,1
EOF

# Run pipeline
nextflow run . \
  --input test_target.csv \
  --mode target \
  --outdir results_target \
  -profile docker
```

**Expected Result:**
- [ ] GENERATE_DESIGN_VARIANTS creates YAMLs with basename references
- [ ] Generated YAMLs contain `path: 1IVO.cif` (not full path)
- [ ] Structure file propagates to all BOLTZGEN_RUN tasks
- [ ] All design variants run successfully

### Test 4: P2Rank Mode
```bash
# Use existing p2rank test
cat > test_p2rank.csv << EOF
sample_id,target_structure,use_p2rank,top_n_pockets,min_pocket_score,design_type,min_length,max_length,protocol,num_designs,budget
egfr_p2rank,assets/test_data/1IVO.cif,true,2,0.5,protein,80,120,protein-anything,2,1
EOF

# Run pipeline
nextflow run . \
  --input test_p2rank.csv \
  --mode p2rank \
  --outdir results_p2rank \
  -profile docker
```

**Expected Result:**
- [ ] P2Rank identifies binding pockets
- [ ] FORMAT_BINDING_SITES creates YAMLs with basename references
- [ ] Generated YAMLs contain `path: 1IVO.cif` (not full path)
- [ ] Structure file propagates to all pocket-specific designs
- [ ] All pocket designs run successfully

## Validation Checks

### Check 1: Generated YAML Content
```bash
# After running Target or P2Rank mode, inspect generated YAMLs
cat results_target/*/design_variants/*.yaml | grep "path:"
```

**Expected Output:**
```yaml
path: 1IVO.cif
```

**NOT:**
```yaml
path: /full/path/to/assets/test_data/1IVO.cif
```

### Check 2: Work Directory Contents
```bash
# Find a BOLTZGEN_RUN work directory
find work -name "*.yaml" -type f | head -1 | xargs dirname

# List files in that directory
ls -la $(find work -name "*.yaml" -type f | head -1 | xargs dirname)
```

**Expected Files:**
- [ ] `design.yaml` (or similar)
- [ ] `1IVO.cif` (or target structure)
- [ ] `.command.sh`
- [ ] Output directories

### Check 3: Boltzgen Logs
```bash
# Check for file not found errors
find work -name ".command.log" -exec grep -l "FileNotFoundError\|No such file" {} \;
```

**Expected Result:**
- [ ] No file not found errors
- [ ] All structure files loaded successfully

## Integration Tests

### Test 5: End-to-End P2Rank → Design → IPSAE
```bash
nextflow run . \
  --input assets/test_data/samplesheet_p2rank_test.csv \
  --mode p2rank \
  --run_ipsae true \
  --outdir results_full_pipeline \
  -profile docker
```

**Expected Result:**
- [ ] Complete pipeline executes
- [ ] Multiple pocket-specific designs generated
- [ ] IPSAE calculations complete
- [ ] All outputs in results directory

### Test 6: Resume Capability
```bash
# Run partial pipeline
nextflow run . --input test_target.csv --mode target -profile docker

# Resume
nextflow run . --input test_target.csv --mode target -profile docker -resume
```

**Expected Result:**
- [ ] Cached tasks are skipped
- [ ] File staging works correctly on resume
- [ ] Pipeline completes successfully

## Edge Cases

### Test 7: Absolute Path Structure Files
```bash
cat > test_absolute.csv << EOF
sample_id,design_yaml,structure_files,protocol,num_designs,budget
test_abs,assets/test_data/egfr_protein_design.yaml,$(pwd)/assets/test_data/1IVO.cif,protein-anything,2,1
EOF

nextflow run . --input test_absolute.csv --mode design -profile docker
```

**Expected Result:**
- [ ] Absolute path resolved correctly
- [ ] File staged properly
- [ ] Pipeline completes

### Test 8: Relative Path Structure Files
```bash
# Run from different directory
cd assets/test_data
cat > ../../test_relative.csv << EOF
sample_id,design_yaml,structure_files,protocol,num_designs,budget
test_rel,egfr_protein_design.yaml,1IVO.cif,protein-anything,2,1
EOF
cd ../..

nextflow run . --input test_relative.csv --mode design -profile docker
```

**Expected Result:**
- [ ] Relative paths resolved correctly
- [ ] Files found and staged
- [ ] Pipeline completes

### Test 9: Missing Structure File
```bash
cat > test_missing.csv << EOF
sample_id,design_yaml,structure_files,protocol,num_designs,budget
test_missing,assets/test_data/egfr_protein_design.yaml,nonexistent.cif,protein-anything,2,1
EOF

nextflow run . --input test_missing.csv --mode design -profile docker
```

**Expected Result:**
- [ ] Pipeline fails with clear error message
- [ ] Error indicates which file is missing
- [ ] Failure happens early (during input validation)

## Performance Tests

### Test 10: Parallel Execution
```bash
# Create samplesheet with multiple samples
cat > test_parallel.csv << EOF
sample_id,target_structure,use_p2rank,top_n_pockets,design_type,protocol,num_designs,budget
sample1,assets/test_data/1IVO.cif,true,2,protein,protein-anything,2,1
sample2,assets/test_data/1IVO.cif,true,2,peptide,peptide-anything,2,1
sample3,assets/test_data/1IVO.cif,true,2,nanobody,nanobody-anything,2,1
EOF

nextflow run . --input test_parallel.csv --mode p2rank -profile docker
```

**Expected Result:**
- [ ] Multiple samples run in parallel
- [ ] Each sample's designs run in parallel
- [ ] No file staging conflicts
- [ ] All samples complete successfully

## Cleanup

```bash
# After all tests pass
rm -rf work/ results_* test_*.csv .nextflow* .nextflow.log*
```

## Sign-Off Checklist

- [ ] All unit tests passed
- [ ] All integration tests passed
- [ ] All edge cases handled correctly
- [ ] No file not found errors in any test
- [ ] Generated YAMLs use basenames
- [ ] Structure files staged correctly
- [ ] Pipeline performance acceptable
- [ ] Documentation complete and accurate

## Notes

Record any issues found during testing:

```
Issue 1: 
  Description: 
  Resolution:

Issue 2:
  Description:
  Resolution:
```

## Test Results Summary

| Test | Status | Notes |
|------|--------|-------|
| Design Mode Single CIF | ☐ Pass ☐ Fail | |
| Design Mode Multi CIF | ☐ Pass ☐ Fail | |
| Target Mode | ☐ Pass ☐ Fail | |
| P2Rank Mode | ☐ Pass ☐ Fail | |
| YAML Content Check | ☐ Pass ☐ Fail | |
| Work Directory Check | ☐ Pass ☐ Fail | |
| Boltzgen Logs Check | ☐ Pass ☐ Fail | |
| End-to-End Pipeline | ☐ Pass ☐ Fail | |
| Resume Capability | ☐ Pass ☐ Fail | |
| Absolute Paths | ☐ Pass ☐ Fail | |
| Relative Paths | ☐ Pass ☐ Fail | |
| Missing File Handling | ☐ Pass ☐ Fail | |
| Parallel Execution | ☐ Pass ☐ Fail | |

**Overall Status:** ☐ Ready for Production ☐ Needs Fixes

**Tested By:** ________________
**Date:** ________________
**Version:** ________________
