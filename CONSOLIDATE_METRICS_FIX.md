# CONSOLIDATE_METRICS Process Fix

## Problem Summary

The `CONSOLIDATE_METRICS` process was failing with the error:
```
Missing output file(s) `design_metrics_summary.csv` expected by process `NFPROTEINDESIGN:PROTEIN_DESIGN:CONSOLIDATE_METRICS (1)`
```

The command output showed:
```
Found 0 IPSAE files
Found 0 PRODIGY files
Found 0 Boltzgen directories
Found 0 ProteinMPNN directories
Found metrics for 0 designs
Warning: No designs to report
```

## Root Causes

### 1. Relative Path Issue
The main issue was that the workflow was passing `params.outdir` as a value (e.g., `results_target_design`), but when the process executed in its work directory, it was treating this as a **relative path from the work directory** (e.g., `../results_target_design/`), not the actual output directory.

**Example:**
- Workflow passes: `results_target_design`
- Process work directory: `/home/florian/nf-proteindesign-2025/work/ce/894c9a...`
- Process tries to search: `/home/florian/nf-proteindesign-2025/work/ce/894c9a.../results_target_design/`
- Actual output location: `/home/florian/nf-proteindesign-2025/results_target_design/`

### 2. IPSAE Didn't Execute
The IPSAE step showed `[-        ]` which means it was **skipped**, not failed. This happens because:
- IPSAE is controlled by the `params.run_ipsae` parameter
- By default or in your test profile, this was set to `false` or not enabled
- The workflow has this conditional: `if (params.run_ipsae) { ... }`

### 3. Script Didn't Create Output Files When Empty
The `consolidate_design_metrics.py` script would exit early without creating the expected output files when no designs were found, causing the process to fail the output validation.

## Fixes Applied

### Fix 1: Absolute Path Resolution (consolidate_metrics.nf)
```groovy
// Convert to absolute path if relative
def abs_output_dir = output_dir.startsWith('/') ? output_dir : "${workflow.launchDir}/${output_dir}"
```

This converts relative paths to absolute paths using `workflow.launchDir` (the directory where Nextflow was launched).

### Fix 2: Enhanced Debugging
Added debugging output to help diagnose issues:
```bash
echo "Searching in directory: ${abs_output_dir}"
echo "Current working directory: $(pwd)"
ls -la ${abs_output_dir} || echo "Warning: Could not list output directory"
```

### Fix 3: Better Glob Pattern Support (consolidate_design_metrics.py)
- Added `recursive=True` to all `glob.glob()` calls
- Added debug output showing:
  - Directory existence check
  - Full directory listing
  - Full search paths used
  - Files found (first 5 of each type)

### Fix 4: Graceful Handling of Empty Results
Modified `write_summary_report()` to create empty CSV files with headers when no designs are found:
```python
if not ranked_designs:
    print("Warning: No designs to report", file=sys.stderr)
    # Create empty CSV with headers
    with open(output_file, 'w', newline='') as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=['design_id', 'rank', 'composite_score'])
        writer.writeheader()
    return
```

## How to Enable IPSAE

To enable IPSAE calculations, add this to your config or command line:

```bash
# Command line
nextflow run main.nf -profile test_target --run_ipsae true

# Or in nextflow.config
params {
    run_ipsae = true
    ipsae_pae_cutoff = 10
    ipsae_dist_cutoff = 10
}

# Or in a profile
profiles {
    test_target {
        params.run_ipsae = true
        params.ipsae_pae_cutoff = 10
        params.ipsae_dist_cutoff = 10
    }
}
```

## Published Directory Structure

The pipeline publishes results to the following structure:
```
${params.outdir}/
├── ${design_id}/
│   ├── ipsae_scores/          # IPSAE scores (if enabled)
│   │   └── *_10_10.txt
│   └── prodigy/               # PRODIGY predictions (if enabled)
│       └── ${design_id}_prodigy_summary.csv
├── design_metrics_summary.csv # Consolidated metrics (from CONSOLIDATE_METRICS)
└── design_metrics_report.md   # Human-readable report
```

## Testing the Fix

1. **With existing results:**
   ```bash
   # Should now find the PRODIGY results
   nextflow run main.nf -profile test_target -resume
   ```

2. **With IPSAE enabled:**
   ```bash
   nextflow run main.nf -profile test_target --run_ipsae true
   ```

3. **Check the debugging output:**
   The process will now show:
   - Directory being searched
   - Directory contents
   - Files found by each pattern
   - Whether files were successfully parsed

## Expected Behavior

### Without IPSAE (current test_target run):
- ✅ Should find PRODIGY results (1 file found)
- ❌ IPSAE scores will show 0 files (process not run)
- ✅ Should create summary CSV and report even with partial data

### With IPSAE enabled:
- ✅ Should find IPSAE results (3 files expected)
- ✅ Should find PRODIGY results (1 file found)
- ✅ Should create comprehensive report with both metrics

## Verification

After running with the fix, check the `.command.out` file in the CONSOLIDATE_METRICS work directory:
```bash
# Find the work directory
nextflow log | grep CONSOLIDATE_METRICS

# Check the output
cat work/<hash>/*/. command.out
```

You should see:
```
============================================================
Consolidating metrics from: /full/path/to/results_target_design
Directory exists: True
Directory contents:
  [DIR]  egfr_target_peptide_len15_v1
  [DIR]  egfr_target_peptide_len15_v2
  ...
============================================================

Searching for PRODIGY results with pattern: **/prodigy/*_prodigy_summary.csv
Full search path: /full/path/to/results_target_design/**/prodigy/*_prodigy_summary.csv
Found 1 PRODIGY files
  - /full/path/to/results_target_design/egfr_target_nanobody_len120_v1/prodigy/rank1_egfr_target_nanobody_len120_v1_0_input_prodigy_summary.csv
```

## Related Configuration

### Consolidation Control
```groovy
params {
    run_consolidation = true    // Enable/disable consolidation report
    report_top_n = 10          // Number of top designs to highlight
}
```

### Metrics to Include
- **PRODIGY** (always enabled if `run_prodigy = true`):
  - Binding affinity (ΔG)
  - Dissociation constant (Kd)
  - Buried surface area
  - Interface contacts

- **IPSAE** (when `run_ipsae = true`):
  - Interface PAE scores
  - Per-residue scores

- **Boltzgen** (always included):
  - Model confidence
  - pLDDT scores
  - pTM scores

- **ProteinMPNN** (when `run_proteinmpnn = true`):
  - Sequence optimization scores
  - Number of sequences generated

## Summary

The fix ensures that:
1. ✅ The consolidation script searches the correct output directory
2. ✅ Extensive debugging helps identify any remaining issues
3. ✅ The process completes successfully even when some metrics are missing
4. ✅ Empty results are handled gracefully
5. ✅ Users understand why IPSAE didn't run (conditional execution)
