# Metrics Consolidation Update

## Overview

Updated the `CONSOLIDATE_METRICS` process and `consolidate_design_metrics.py` script to comprehensively collect and rank all pipeline outputs. The updated consolidation now provides a complete view of design quality across all analysis stages.

## What Was Changed

### Enhanced Metric Collection

The consolidation script now collects metrics from **all pipeline stages**:

#### 1. **Boltzgen Original Design Quality**
- `aggregate_plddt` - Per-residue confidence (0-100)
- `aggregate_ptm` - Predicted TM-score (0-1)
- `aggregate_iptm` - Interface predicted TM-score (0-1)
- `aggregate_pae_interaction` - Interface PAE score
- All fields from `aggregate_metrics_analyze.csv`
- All fields from `per_target_metrics_analyze.csv`

#### 2. **ProteinMPNN Sequence Optimization**
- `mpnn_score` - Negative log probability (lower is better)
- `mpnn_global_score` - Overall sequence likelihood
- `mpnn_seq_recovery` - Fraction of original residues kept (0-1)
- `mpnn_num_sequences` - Number of optimized sequences
- Parsed from `*_scores.fa` FASTA files

#### 3. **Protenix Refolding Validation**
- `protenix_plddt` - Confidence after refolding (0-100)
- `protenix_ptm` - Predicted TM-score after refolding (0-1)
- `protenix_iptm` - Interface quality after refolding (0-1)
- `protenix_ranking_score` - Overall model ranking
- Parsed from confidence JSON files

#### 4. **IPSAE Interface Quality**
- `ipsae_score` - Interface PAE score (lower is better, <5 excellent)
- Runs on ALL budget designs (before filtering)

#### 5. **PRODIGY Binding Affinity**
- `predicted_binding_affinity` - ΔG in kcal/mol (more negative = stronger)
- `predicted_kd` - Dissociation constant in M
- `buried_surface_area` - Interface size in Ų
- `num_interface_contacts` - Number of residue contacts

#### 6. **Foldseek Structural Similarity**
- `foldseek_top_hit` - Most similar structure in database
- `foldseek_top_evalue` - Statistical significance
- `foldseek_top_bits` - Alignment score
- `foldseek_num_hits` - Total number of hits

## New Composite Scoring System

The composite score now weighs **all available metrics** with appropriate weights:

```python
weights = {
    # Boltzgen structure quality
    'aggregate_plddt': 0.15,
    'aggregate_ptm': 1.0,
    'aggregate_iptm': 1.0,
    
    # Interface quality
    'ipsae_score': -2.0,  # Lower is better
    
    # Binding affinity
    'predicted_binding_affinity': -0.5,  # More negative is better
    'buried_surface_area': 0.001,
    'num_interface_contacts': 0.05,
    
    # ProteinMPNN optimization
    'mpnn_score': -0.5,  # Lower is better
    'mpnn_seq_recovery': 0.5,
    
    # Protenix refolding validation
    'protenix_plddt': 0.01,
    'protenix_ptm': 0.5,
    'protenix_iptm': 0.5,
}
```

The score is normalized by the number of available metrics, so designs are fairly ranked even if some analyses weren't run.

## Output Structure

### CSV Output (`design_metrics_summary.csv`)

Columns are prioritized for easy analysis:
1. **Identification**: design_id, model_id, rank
2. **Overall Score**: composite_score, _metrics_used
3. **Boltzgen Quality**: aggregate_plddt, aggregate_ptm, aggregate_iptm, etc.
4. **ProteinMPNN**: mpnn_score, mpnn_seq_recovery, etc.
5. **Protenix**: protenix_plddt, protenix_ptm, protenix_iptm
6. **Interface**: ipsae_score
7. **Binding**: predicted_binding_affinity, predicted_kd, buried_surface_area, contacts
8. **Similarity**: foldseek_top_hit, foldseek_top_evalue, etc.
9. **Additional**: All other metrics from Boltzgen CSVs

### Markdown Report (`design_metrics_report.md`)

Enhanced report includes:

1. **Summary Statistics** - Distribution of metrics across all designs
2. **Top N Designs Table** - Key metrics at a glance
3. **Interpretation Guide** - Detailed explanation of each metric category:
   - Boltzgen quality metrics
   - ProteinMPNN optimization
   - Protenix refolding validation
   - Interface quality (IPSAE)
   - Binding affinity (PRODIGY)
   - Structural similarity (Foldseek)
4. **Recommendations** - Detailed analysis of top design:
   - Quality assessment with thresholds
   - Strengths and considerations
   - Actionable next steps

## Technical Implementation

### Hierarchical Data Collection

The script now uses a hierarchical structure to organize metrics:

```
all_metrics = {
    'design_id': {
        'boltzgen': {...},  # Base design metrics
        'model_id_1': {...},  # Metrics for specific model
        'model_id_2': {...},
        'protenix_seq1_model1': {...},  # Protenix refolded structures
    }
}
```

This is then flattened for ranking:

```
flattened_metrics = {
    'design_id_model_id_1': {
        # Boltzgen base metrics
        # + Model-specific metrics (IPSAE, PRODIGY, Foldseek)
    },
    'design_id_protenix_seq1_model1': {
        # Boltzgen base metrics
        # + ProteinMPNN metrics
        # + Protenix metrics
        # + IPSAE, PRODIGY, Foldseek (if run)
    }
}
```

### Path-Based Metric Association

Metrics are correctly associated with their source structures using path parsing:

- **Boltzgen designs**: `{design_id}/intermediate_designs_inverse_folded/{model_id}.cif`
- **IPSAE scores**: `{design_id}/ipsae_scores/{model_id}_10_10.txt`
- **PRODIGY**: `{design_id}/prodigy/{model_id}_prodigy_summary.csv`
- **Foldseek**: `{design_id}/foldseek/{model_id}_foldseek_summary.tsv`
- **ProteinMPNN**: `{design_id}_mpnn_optimized/{model_id}_scores.fa`
- **Protenix**: `{design_id}_mpnn_{seq_num}/protenix/{model_id}_confidence.json`

## Benefits

### For Users

1. **Complete Picture**: All pipeline metrics in one table
2. **Smart Ranking**: Composite score considers all available data
3. **Easy Filtering**: CSV format allows custom sorting/filtering
4. **Clear Guidance**: Markdown report explains what each metric means

### For Pipeline Development

1. **Validates All Tools**: Ensures every analysis contributes to final ranking
2. **Tracks Provenance**: Clear association between structures and metrics
3. **Extensible**: Easy to add new metrics in the future
4. **Debuggable**: Verbose output shows what was found at each step

## Example Workflow

After running the pipeline with all modules enabled:

```bash
nextflow run main.nf \
  --input samplesheet.csv \
  --run_proteinmpnn \
  --run_protenix_refold \
  --run_ipsae \
  --run_prodigy \
  --run_foldseek \
  --run_consolidation
```

You'll get:

1. **`design_metrics_summary.csv`** - Comprehensive table for custom analysis
2. **`design_metrics_report.md`** - Human-readable report with recommendations

The top-ranked designs will be those that:
- Have high Boltzgen quality (pLDDT, pTM, ipTM)
- Show good ProteinMPNN scores (optimized sequences)
- Refold well with Protenix (validates MPNN sequences)
- Have low IPSAE scores (confident interface)
- Show strong predicted binding (PRODIGY ΔG)
- Have large, well-packed interfaces (BSA, contacts)

## Files Modified

- `assets/consolidate_design_metrics.py` - Complete rewrite of metric collection and ranking logic

## Next Steps

To use the updated consolidation:

1. Run the pipeline with `--run_consolidation` enabled
2. Review `design_metrics_report.md` for quick insights
3. Open `design_metrics_summary.csv` for detailed analysis
4. Sort/filter the CSV by specific metrics of interest
5. Examine structures for top-ranked designs
6. Compare Boltzgen vs Protenix structures to validate MPNN sequences

## Notes

- The consolidation runs **after** all analyses complete (triggered by `collect()` on all outputs)
- If a metric is not available (e.g., Protenix not run), designs are still ranked fairly
- The `_metrics_used` column shows how many metrics contributed to each score
- All original Boltzgen CSV fields are preserved in the output
