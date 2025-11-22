# Fixes Summary: ProteinMPNN Execution Count & EXTRACT_TARGET_SEQUENCES

## Date: 2025-11-22

---

## Issue 1: ProteinMPNN Running 5 Times Instead of 2

### Problem
ProteinMPNN was executing 5 times even though `params.budget = 2` (meaning only 2 budget designs should exist).

### Root Cause
The input channel for `CONVERT_CIF_TO_PDB` was incorrectly configured:

**BEFORE (INCORRECT):**
```groovy
ch_structures_for_conversion = BOLTZGEN_RUN.out.results
    .map { meta, results_dir ->
        def budget_designs_dir = file("${results_dir}/intermediate_designs_inverse_folded")
        [meta, budget_designs_dir]
    }
```

This was passing the **entire results directory** which contains:
- `final_1_designs/` (1 structure)
- `intermediate_ranked_10_designs/` (10 structures) 
- `intermediate_designs_inverse_folded/` (2 structures - budget designs)
- `intermediate_designs/` (10 structures)
- etc.

So it was converting **ALL structures** from multiple subdirectories, not just the budget designs.

### Solution
Changed to use the dedicated `budget_design_cifs` output from BOLTZGEN_RUN:

**AFTER (CORRECT):**
```groovy
CONVERT_CIF_TO_PDB(BOLTZGEN_RUN.out.budget_design_cifs)
```

The `budget_design_cifs` output is specifically curated to contain **ONLY** the budget designs (2 structures when budget=2).

### Expected Behavior Now
- ProteinMPNN will run **exactly 2 times** (once per budget design)
- Each execution processes one PDB structure
- Downstream Protenix refolding inherits the same parallelization

---

## Issue 2: EXTRACT_TARGET_SEQUENCES - Purpose and Naming

### What Does EXTRACT_TARGET_SEQUENCES Do?

This process extracts the **target protein sequence** (binding partner) from the original Boltzgen-designed structures.

### Why Do We Need It?

**Context:** When ProteinMPNN generates new sequences for the binder protein, we want to refold those sequences with Protenix to verify they maintain the correct structure.

**Problem:** Protenix needs to know which chain is the **target** (the protein you're designing a binder against) so it can:
1. Keep the target chain in its correct position during refolding
2. Properly model the binder-target interaction
3. Generate accurate confidence scores for the complex

**Solution:** Extract the target sequence from the original Boltzgen structures and pass it to Protenix along with the new ProteinMPNN sequences.

### What Is the Target Sequence?

In a binder design workflow:
- **Binder chain**: The small protein you're designing (gets optimized by ProteinMPNN)
- **Target chain**: The larger protein you want to bind to (stays fixed, extracted by this process)

### Process Flow

```
Boltzgen Structure (CIF)
    ↓
EXTRACT_TARGET_SEQUENCES
    ↓
Target Sequence (TXT file)
    ↓
    ├→ Protenix Input 1: ProteinMPNN optimized sequence (binder)
    └→ Protenix Input 2: Target sequence (from this extraction)
    ↓
Protenix Refolds Complex
```

### Naming and No Collisions

✅ **Process name**: `EXTRACT_TARGET_SEQUENCES` (unique, no collision)
✅ **Module file**: `modules/local/extract_target_sequences.nf`
✅ **Script file**: `assets/extract_target_sequence.py`
✅ **Output files**: `${meta.id}_target_sequences.txt` (unique per design)

No naming collisions exist - this process has a distinct name and purpose separate from:
- `PROTEINMPNN_OPTIMIZE` (optimizes binder sequences)
- `PROTENIX_REFOLD` (refolds optimized binders with target)
- `EXTRACT_*` other modules (none exist)

### Example Output

For design `insulin_binder`:
```
insulin_binder_target_sequences.txt:
MALWMRLLPLLALLALWGPDPAAAFVNQHLCGSHLVEALYLVCGERGFFYTPKTRREAEDLQVGQVELGGGPGAGSLQPLALEGSLQKRGIVEQCCTSICSLYQLENYCN
```

This is the insulin sequence (target) that will be passed to Protenix along with the ProteinMPNN-optimized binder sequences.

---

## Summary of Changes

### Files Modified
1. `workflows/protein_design.nf`
   - Fixed ProteinMPNN input channel to use `budget_design_cifs`
   - Added comprehensive documentation for `EXTRACT_TARGET_SEQUENCES` step

### Expected Impact
- ProteinMPNN executions: ~~5~~ → **2** (correct)
- Protenix executions: Proportional reduction (2 × num_seq_per_target)
- Clearer understanding of target sequence extraction purpose
- No naming collisions or process conflicts

### Testing Recommendation
Run with minimal parameters to verify:
```bash
nextflow run main.nf \
  --designs test_designs/ \
  --budget 2 \
  --run_proteinmpnn true \
  --run_protenix_refold true \
  --mpnn_num_seq_per_target 3
```

Expected process counts:
- BOLTZGEN_RUN: 1 (per design YAML)
- CONVERT_CIF_TO_PDB: 1 (processes 2 budget CIFs)
- PROTEINMPNN_OPTIMIZE: 2 (once per budget design)
- EXTRACT_TARGET_SEQUENCES: 1 (once per design)
- PROTENIX_REFOLD: 6 (2 budget designs × 3 sequences each)

---

## Documentation Added

Enhanced inline documentation in workflow to explain:
1. Why we use `budget_design_cifs` not `results` directory
2. Purpose of target sequence extraction
3. How target sequence is used by Protenix
4. Expected parallelization pattern

This should prevent future confusion about:
- Which structures feed into ProteinMPNN
- Why we extract target sequences separately
- How the binder-target complex is modeled
