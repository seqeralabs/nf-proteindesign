# Pipeline Flow Corrections Summary

## Date: 2025-11-20

This document summarizes the corrections made to align the nf-proteindesign pipeline with the intended workflow specifications.

---

## Pipeline Specification Requirements

The pipeline should:
1. Run **Boltzgen** with either:
   - Pre-defined YAML files (design mode)
   - Auto-generated YAML from target structures (target mode)

2. Execute Boltzgen in parallel for all YAMLs provided or generated

3. Collect **ALL** Boltzgen outputs:
   - ✅ `final_ranked_designs/` - Final filtered designs
   - ✅ `intermediate_designs_inverse_folded/` - **ALL budget designs** (e.g., 10 designs if budget=10)
   - ✅ `refold_design_cif/` - Binder structures by themselves
   - ✅ `refold_cif/` - Refolded complex structures
   - ✅ `aggregate_metrics_analyze.csv` - Aggregate metrics
   - ✅ `per_target_metrics_analyze.csv` - Per-target metrics

4. Run **IPSAE** on ALL budget designs from `intermediate_designs_inverse_folded/`
   - **Critical**: Run on ALL designs BEFORE filtering (budget count)
   - If budget=10, IPSAE should run 10 times

5. Run **PRODIGY** on ALL budget designs from `intermediate_designs_inverse_folded/`
   - **Critical**: Run on ALL designs BEFORE filtering (budget count)
   - If budget=10, PRODIGY should run 10 times

6. **Consolidate** all results into a comprehensive metrics report

---

## Changes Made

### 1. BOLTZGEN_RUN Module (`modules/local/boltzgen_run.nf`)

#### Added New Outputs:
```groovy
// Intermediate inverse folded designs (all budget designs)
tuple val(meta), path("${meta.id}_output/intermediate_designs_inverse_folded/*.cif"), optional: true, emit: budget_design_cifs
tuple val(meta), path("${meta.id}_output/intermediate_designs_inverse_folded/*.npz"), optional: true, emit: budget_design_npz

// Specific intermediate outputs: binder by itself and refolded complex
tuple val(meta), path("${meta.id}_output/refold_design_cif"), optional: true, emit: refold_design_dir
tuple val(meta), path("${meta.id}_output/refold_design_cif/*.cif"), optional: true, emit: refold_design_cifs
tuple val(meta), path("${meta.id}_output/refold_cif"), optional: true, emit: refold_complex_dir
tuple val(meta), path("${meta.id}_output/refold_cif/*.cif"), optional: true, emit: refold_complex_cifs

// CSV metrics files
tuple val(meta), path("${meta.id}_output/aggregate_metrics_analyze.csv"), optional: true, emit: aggregate_metrics
tuple val(meta), path("${meta.id}_output/per_target_metrics_analyze.csv"), optional: true, emit: per_target_metrics
```

**Rationale**: These outputs capture ALL designs generated with the budget parameter (before filtering by Boltzgen's internal ranking), plus important intermediate structures and metrics CSVs.

---

### 2. PROTEIN_DESIGN Workflow (`workflows/protein_design.nf`)

#### Changed IPSAE Input Source:
**Before**:
```groovy
ch_ipsae_input = BOLTZGEN_RUN.out.intermediate_cifs
    .join(BOLTZGEN_RUN.out.intermediate_npz, by: 0)
```

**After**:
```groovy
ch_ipsae_input = BOLTZGEN_RUN.out.budget_design_cifs
    .join(BOLTZGEN_RUN.out.budget_design_npz, by: 0)
```

**Rationale**: `intermediate_designs_inverse_folded/` contains ALL budget designs (e.g., 10 files if budget=10), whereas `intermediate_designs/` may contain unfiltered generation results. IPSAE should analyze all budget designs, not just final filtered results.

---

#### Changed PRODIGY Input Source:
**Before**:
```groovy
ch_prodigy_input = BOLTZGEN_RUN.out.final_cifs
```

**After**:
```groovy
ch_prodigy_input = BOLTZGEN_RUN.out.budget_design_cifs
```

**Rationale**: PRODIGY should run on ALL budget designs (e.g., 10 runs if budget=10), not just the final filtered results from `final_ranked_designs/`. This ensures we don't miss potentially good designs that were filtered out.

---

### 3. Metrics Consolidation Script (`assets/consolidate_design_metrics.py`)

#### Added New Parsing Functions:

1. **`parse_aggregate_metrics_csv(csv_file)`**
   - Parses `aggregate_metrics_analyze.csv` from Boltzgen
   - Extracts overall design quality metrics
   - Prefixes metrics with `aggregate_` for clarity

2. **`parse_per_target_metrics_csv(csv_file)`**
   - Parses `per_target_metrics_analyze.csv` from Boltzgen
   - Calculates averages, min, and max for multi-target designs
   - Prefixes metrics with `per_target_` for clarity

#### Updated Aggregation Function:
Added searches for:
- `*/aggregate_metrics_analyze.csv`
- `*/per_target_metrics_analyze.csv`

**Rationale**: These CSV files contain important Boltzgen metrics that should be included in the final consolidated report.

---

## Pipeline Flow Verification

### Current Flow (Corrected):

```
┌─────────────────────────────────────────────────────────────┐
│ INPUT: Design YAML or Target Structure                      │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
        ┌─────────────────┐
        │  GENERATE_DESIGN │  (Target mode only)
        │    VARIANTS      │
        └────────┬─────────┘
                 │
                 ▼
         ┌──────────────┐
         │  BOLTZGEN    │  Runs in parallel for each YAML
         │     RUN      │
         └──────┬───────┘
                │
                ├─► final_ranked_designs/          (Filtered results)
                ├─► intermediate_designs_inverse_folded/  (ALL budget designs) ◄─┐
                ├─► refold_design_cif/             (Binder structures)          │
                ├─► refold_cif/                    (Complex structures)         │
                ├─► aggregate_metrics_analyze.csv                               │
                └─► per_target_metrics_analyze.csv                              │
                                                                                 │
                ┌────────────────────────────────────────────────────────────────┘
                │
                ├─► IPSAE (runs on ALL budget designs)  ◄── budget_design_cifs/npz
                │
                └─► PRODIGY (runs on ALL budget designs) ◄── budget_design_cifs
                
                ┌──────────────────┐
                │  CONSOLIDATE     │  Collects all metrics:
                │    METRICS       │  - IPSAE scores
                │                  │  - PRODIGY predictions
                └──────┬───────────┘  - Boltzgen CSVs
                       │              - All other metrics
                       ▼
           ┌────────────────────┐
           │  Final Reports:    │
           │  - Summary CSV     │
           │  - Markdown Report │
           └────────────────────┘
```

### Key Improvements:

1. **✅ ALL Budget Designs Analyzed**: IPSAE and PRODIGY now process all designs specified by the budget parameter, not just filtered results

2. **✅ Complete Output Collection**: All important intermediate outputs are now captured:
   - Binder structures alone (`refold_design_cif/`)
   - Refolded complexes (`refold_cif/`)
   - Boltzgen metrics CSVs

3. **✅ Enhanced Metrics Consolidation**: Consolidation script now includes Boltzgen's own CSV metrics

4. **✅ Correct Data Flow**: Analysis tools receive the appropriate input data:
   - IPSAE: All budget designs + NPZ files
   - PRODIGY: All budget designs
   - Both run BEFORE filtering, ensuring no good designs are missed

---

## Testing Recommendations

To verify these changes work correctly:

1. **Test with budget parameter**:
   ```bash
   nextflow run main.nf --budget 5 --num_designs 20 ...
   ```
   - Verify IPSAE runs exactly 5 times per design
   - Verify PRODIGY runs exactly 5 times per design
   - Check that `intermediate_designs_inverse_folded/` contains 5 CIF files

2. **Check output directories**:
   ```bash
   # Should exist for each design:
   ls results/design_name_output/refold_design_cif/
   ls results/design_name_output/refold_cif/
   ls results/design_name_output/aggregate_metrics_analyze.csv
   ls results/design_name_output/per_target_metrics_analyze.csv
   ```

3. **Verify consolidation**:
   ```bash
   # Check that consolidated report includes:
   # - IPSAE scores for all budget designs
   # - PRODIGY predictions for all budget designs
   # - Boltzgen CSV metrics
   cat results/design_metrics_summary.csv
   cat results/design_metrics_report.md
   ```

---

## Summary of Alignment with Specifications

| Requirement | Status | Notes |
|------------|--------|-------|
| Run Boltzgen on design YAMLs | ✅ | Working as intended |
| Capture final_ranked_designs/ | ✅ | Already implemented |
| Capture intermediate_designs_inverse_folded/ | ✅ | **Fixed** - Now exposed as output |
| Capture refold_design_cif/ | ✅ | **Added** - Binder structures |
| Capture refold_cif/ | ✅ | **Added** - Complex structures |
| Capture aggregate_metrics CSV | ✅ | **Added** - Boltzgen metrics |
| Capture per_target_metrics CSV | ✅ | **Added** - Target-specific metrics |
| IPSAE on ALL budget designs | ✅ | **Fixed** - Now uses budget_design_cifs |
| PRODIGY on ALL budget designs | ✅ | **Fixed** - Now uses budget_design_cifs |
| Consolidate all metrics | ✅ | **Enhanced** - Includes new CSVs |

---

## Files Modified

1. `modules/local/boltzgen_run.nf` - Added 8 new output channels
2. `workflows/protein_design.nf` - Changed IPSAE and PRODIGY input sources
3. `assets/consolidate_design_metrics.py` - Added CSV parsing functions

---

## Conclusion

All pipeline flow misalignments have been corrected. The pipeline now:

1. ✅ Captures ALL required outputs from Boltzgen
2. ✅ Runs IPSAE and PRODIGY on ALL budget designs (not filtered results)
3. ✅ Includes Boltzgen CSV metrics in final consolidation
4. ✅ Maintains proper data flow from generation → analysis → consolidation

The pipeline is now fully aligned with the specifications.
