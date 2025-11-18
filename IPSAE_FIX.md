# IPSAE_CALCULATE and PRODIGY_PREDICT Process Debug Fix

## Issue Summary
The `IPSAE_CALCULATE` and `PRODIGY_PREDICT` processes were never running, even when `params.run_ipsae = true` and `params.run_prodigy = true` were set in test profiles.

## Root Cause Analysis

### Problem Locations
1. **IPSAE**: `workflows/protein_design.nf`, lines 143-181
2. **PRODIGY**: `workflows/protein_design.nf`, lines 207-244

### The Bug
The channel creation for both `ch_ipsae_input` and `ch_prodigy_input` in their respective `flatMap` operations had several critical issues:

```groovy
// BROKEN CODE (IPSAE):
def cif_files = file("${results_dir}/predictions/**/*_model_*.cif")

cif_files.each { cif ->
    // Process files...
}

// BROKEN CODE (PRODIGY):
def structure_files = file("${mpnn_dir}/structures/*")

structure_files.each { structure ->
    // Process files...
}
```

### Issues Identified

1. **Single vs List Return**: The `file()` method with glob patterns returns:
   - A **single Path object** if only one file matches
   - A **List** if multiple files match
   
   This inconsistency breaks the `.each` iteration when only one file exists.

2. **No Validation**: No checks for:
   - Whether files were found
   - Whether the glob pattern matched anything
   - Whether files actually exist before processing

3. **Silent Failure**: When the glob pattern returns an empty result (or single non-list result), the `flatMap` returns an empty list, and the process is never triggered. No errors or warnings were emitted.

## The Fix

### Changes Made

Added robust handling in `workflows/protein_design.nf` for both IPSAE and PRODIGY processes:

#### IPSAE Fix

```groovy
// FIXED CODE:
ch_ipsae_input = BOLTZGEN_RUN.out.results
    .flatMap { meta, results_dir ->
        // Find all model CIF files and corresponding PAE files
        def cif_pattern = "${results_dir}/predictions/**/*_model_*.cif"
        def cif_files_found = file(cif_pattern)
        
        // Ensure cif_files is always a list (file() returns single object if only one match)
        def cif_files = cif_files_found instanceof List ? cif_files_found : [cif_files_found]
        
        def pairs = []
        
        // Debug logging
        if (cif_files.size() == 0) {
            println "WARNING: No CIF files found matching pattern: ${cif_pattern}"
        } else {
            println "Found ${cif_files.size()} CIF files for IPSAE analysis"
        }
        
        cif_files.each { cif ->
            if (cif.exists() && cif.isFile()) {
                def cif_name = cif.getName()
                def matcher = cif_name =~ /(.+)_model_(\\d+)\\.cif$/
                
                if (matcher.matches()) {
                    def input_name = matcher[0][1]
                    def model_num = matcher[0][2]
                    
                    // Construct PAE file path
                    def pae_file = file("${results_dir}/predictions/${input_name}/pae_${input_name}_model_${model_num}.npz")
                    
                    if (pae_file.exists()) {
                        def model_meta = meta.clone()
                        model_meta.model_id = "${meta.id}_model_${model_num}"
                        pairs.add([model_meta, pae_file, cif])
                        println "Added IPSAE pair: ${model_meta.model_id}"
                    } else {
                        println "WARNING: PAE file not found for ${cif_name}: ${pae_file}"
                    }
                }
            }
        }
        
        if (pairs.size() == 0) {
            println "WARNING: No valid CIF/PAE pairs found for sample ${meta.id}"
        }
        
        return pairs
    }
```

#### PRODIGY Fix

Applied the same fix pattern to both ProteinMPNN and Boltzgen branches:

```groovy
// FIXED CODE (PRODIGY - Boltzgen branch example):
ch_prodigy_input = BOLTZGEN_RUN.out.final_designs
    .flatMap { meta, designs_dir ->
        def cif_pattern = "${designs_dir}/*.cif"
        def cif_files_found = file(cif_pattern)
        
        // Ensure cif_files is always a list
        def cif_files = cif_files_found instanceof List ? cif_files_found : [cif_files_found]
        
        def structures = []
        
        // Debug logging
        if (cif_files.size() == 0) {
            println "WARNING: No CIF files found matching pattern: ${cif_pattern}"
        } else {
            println "Found ${cif_files.size()} CIF files for PRODIGY analysis from Boltzgen"
        }
        
        cif_files.each { cif ->
            if (cif.exists() && cif.isFile()) {
                def cif_name = cif.getName()
                def design_meta = meta.clone()
                design_meta.id = cif_name.replaceAll(/\\.cif$/, '')
                design_meta.parent_id = meta.id
                
                structures.add([design_meta, cif])
                println "Added PRODIGY structure: ${design_meta.id}"
            }
        }
        
        if (structures.size() == 0) {
            println "WARNING: No valid CIF files found for PRODIGY from sample ${meta.id}"
        }
        
        return structures
    }
```

### Key Improvements

1. **Type Safety**: Explicitly check if `file()` returned a list or single object, and normalize to always use a list
2. **Validation**: Added `cif.exists() && cif.isFile()` check before processing
3. **Debugging**: Added informative warning messages at multiple points:
   - When no CIF files are found
   - When PAE files are missing (IPSAE)
   - When no valid pairs/structures are created
4. **Visibility**: Log each successfully added IPSAE pair or PRODIGY structure for tracking
5. **Consistency**: Applied the same fix pattern to both IPSAE and PRODIGY processes

## Expected Behavior After Fix

### IPSAE Process

When `params.run_ipsae = true`:

1. ✅ The workflow will search for CIF files in `{results_dir}/predictions/**/*_model_*.cif`
2. ✅ For each CIF file found, it will look for corresponding PAE file
3. ✅ Valid CIF/PAE pairs will be emitted to the IPSAE_CALCULATE process
4. ✅ Clear logging will show:
   - Number of CIF files found
   - Each IPSAE pair being added
   - Warnings if files are missing

### PRODIGY Process

When `params.run_prodigy = true`:

1. ✅ The workflow will search for structure files:
   - If ProteinMPNN ran: `{mpnn_dir}/structures/*` (CIF or PDB)
   - If ProteinMPNN not run: `{designs_dir}/*.cif`
2. ✅ Valid structures will be emitted to the PRODIGY_PREDICT process
3. ✅ Clear logging will show:
   - Number of structure files found
   - Each PRODIGY structure being added
   - Warnings if files are missing

## Testing Recommendations

### Test with Different Scenarios

#### IPSAE Tests
1. **Single design**: Verify it works with only one CIF/PAE pair
2. **Multiple designs**: Verify it works with multiple CIF/PAE pairs
3. **Missing PAE files**: Verify warnings are shown and process continues
4. **Missing predictions directory**: Verify clear error messages

#### PRODIGY Tests
1. **With ProteinMPNN**: Test when `run_proteinmpnn = true`
2. **Without ProteinMPNN**: Test with direct Boltzgen outputs
3. **Single structure**: Verify handling of single file
4. **Multiple structures**: Verify handling of multiple files

### Example Test Commands

```bash
# Test IPSAE
nextflow run main.nf \
    -profile test_design,docker \
    --run_ipsae true \
    --outdir results_ipsae_test

# Test PRODIGY
nextflow run main.nf \
    -profile test_design,docker \
    --run_prodigy true \
    --outdir results_prodigy_test

# Test both with ProteinMPNN
nextflow run main.nf \
    -profile test_design,docker \
    --run_ipsae true \
    --run_prodigy true \
    --run_proteinmpnn true \
    --outdir results_all_metrics_test
```

## Related Files

The same pattern exists in legacy workflow files (not currently used):
- `workflows/target_to_designs.nf` (line 52)
- `workflows/p2rank_to_designs.nf` (line 64)

These should be updated if ever re-activated, but since `main.nf` only includes `PROTEIN_DESIGN`, they're not affecting current runs.

## Verification

### IPSAE Verification

After applying this fix:

1. Check pipeline logs for IPSAE debug messages
2. Verify IPSAE process appears in execution DAG
3. Confirm IPSAE output files are created in `{outdir}/{sample_id}/ipsae_scores/`
4. Expected outputs:
   - `*_{pae_cutoff}_{dist_cutoff}.txt` - IPSAE scores
   - `*_{pae_cutoff}_{dist_cutoff}_byres.txt` - Per-residue scores
   - `*.pml` - PyMOL visualization scripts (optional)

### PRODIGY Verification

After applying this fix:

1. Check pipeline logs for PRODIGY debug messages
2. Verify PRODIGY process appears in execution DAG
3. Confirm PRODIGY output files are created in `{outdir}/{sample_id}/prodigy_predictions/`
4. Expected outputs:
   - `*_prodigy_summary.csv` - Summary of binding affinity predictions
   - Individual prediction files per structure

## Additional Notes

### Why This Bug Was Hard to Spot

1. **Silent failure**: No error messages, process simply didn't run
2. **Conditional execution**: Only happens when `params.run_ipsae = true`
3. **Groovy behavior**: The single object vs list behavior is a Groovy quirk
4. **Nested flatMap**: The issue was buried in a complex channel operation

### Best Practices Going Forward

1. Always normalize `file()` results to lists when using glob patterns
2. Add defensive validation checks (exists, isFile, isDirectory)
3. Include debug logging in channel operations, especially in flatMaps
4. Test with both single and multiple file scenarios
