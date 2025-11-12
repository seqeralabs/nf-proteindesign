# Consolidated Metrics Report

## Overview

The consolidated metrics report aggregates all design metrics from various analysis modules (Boltzgen, ProteinMPNN, IPSAE, PRODIGY) into a single ranked report that helps you identify the best designs.

## Enabling Consolidation

Add the following parameter to your Nextflow command:

```bash
nextflow run main.nf \
  --input samplesheet.csv \
  --run_ipsae true \
  --run_prodigy true \
  --run_proteinmpnn true \
  --run_consolidation true \
  <other parameters>
```

## Output Files

When consolidation is enabled, two files will be generated in your output directory:

### 1. `design_metrics_summary.csv`

A comprehensive CSV file containing all metrics for all designs, including:

| Column | Description | Units | Notes |
|--------|-------------|-------|-------|
| `design_id` | Unique identifier for the design | - | - |
| `rank` | Overall rank based on composite score | - | Lower is better |
| `composite_score` | Overall quality score | - | Higher is better |
| `ipsae_score` | Interface PAE score | - | Lower is better, measures interface quality |
| `predicted_binding_affinity` | Predicted ΔG | kcal/mol | More negative is stronger binding |
| `predicted_kd` | Predicted dissociation constant | M | Lower indicates tighter binding |
| `buried_surface_area` | Buried surface area at interface | Ų | Larger generally indicates more interaction |
| `num_interface_contacts` | Number of interface contacts | - | More contacts typically means stronger interaction |
| `model_confidence` | Model confidence score | - | Higher is better |
| `plddt_avg` | Average pLDDT score | - | Higher is better (> 70 is good) |
| `ptm_score` | Predicted TM-score | - | Higher is better |

**Usage:** This CSV can be imported into Excel, Python, R, or other analysis tools for further processing, visualization, and filtering.

### 2. `design_metrics_report.md`

A human-readable Markdown report containing:

- **Summary Statistics**: Overview of all designs including ranges and averages for key metrics
- **Top N Designs Table**: Ranked list of the best designs (default: top 10)
- **Interpretation Guide**: Explanation of each metric and what values to look for
- **Recommendations**: Specific suggestions for the top-ranked designs

## Interpreting the Results

### Composite Score

The composite score combines multiple metrics into a single ranking value:

- **IPSAE score** (weight: -1.0) - Lower is better
- **Binding affinity** (weight: -1.0) - More negative is better
- **Buried surface area** (weight: 0.01) - Larger is better
- **Interface contacts** (weight: 0.1) - More is better
- **Model confidence** (weight: 1.0) - Higher is better
- **pLDDT average** (weight: 0.1) - Higher is better

The weights can be customized by modifying the `calculate_composite_score` function in `assets/consolidate_design_metrics.py`.

### Key Metrics Guide

#### IPSAE Score
- **< 5.0**: Excellent interface quality ✅
- **5.0-10.0**: Moderate interface quality ⚠️
- **> 10.0**: Poor interface quality ❌

#### Binding Affinity (ΔG)
- **< -10 kcal/mol**: Strong predicted binding ✅
- **-5 to -10 kcal/mol**: Moderate predicted binding ⚠️
- **> -5 kcal/mol**: Weak predicted binding ❌

#### Dissociation Constant (Kd)
- **< 1 nM (10⁻⁹ M)**: Very tight binding ✅
- **1-100 nM**: Tight binding ✅
- **100 nM - 1 μM**: Moderate binding ⚠️
- **> 1 μM**: Weak binding ❌

#### Buried Surface Area
- **> 1000 Ų**: Large interface, good ✅
- **600-1000 Ų**: Moderate interface ⚠️
- **< 600 Ų**: Small interface ❌

#### Interface Contacts
- **> 50**: Good number of contacts ✅
- **30-50**: Moderate contacts ⚠️
- **< 30**: Few contacts ❌

## Configuration Options

### Adjust Number of Top Designs in Report

```bash
--report_top_n 20  # Show top 20 designs instead of default 10
```

### Custom Metric Patterns

If you've customized IPSAE or PRODIGY parameters, the consolidation script will automatically detect the correct files based on your `ipsae_pae_cutoff` and `ipsae_dist_cutoff` settings.

## Example Workflow

Here's a complete example running all analyses with consolidation:

```bash
nextflow run main.nf \
  --input samplesheet.csv \
  --mode target \
  --protocol protein-anything \
  --num_designs 1000 \
  --budget 20 \
  --run_proteinmpnn true \
  --mpnn_num_seq_per_target 8 \
  --run_ipsae true \
  --ipsae_pae_cutoff 10 \
  --ipsae_dist_cutoff 10 \
  --run_prodigy true \
  --run_consolidation true \
  --report_top_n 15 \
  --outdir results_with_metrics \
  -profile docker
```

This will:
1. Generate protein designs using Boltzgen
2. Optimize sequences with ProteinMPNN
3. Calculate IPSAE interface scores
4. Predict binding affinities with PRODIGY
5. Generate a consolidated ranked report of all designs

## Advanced Usage

### Filtering Designs in CSV

You can filter the CSV file to find designs meeting specific criteria. For example, using Python:

```python
import pandas as pd

# Load the summary
df = pd.read_csv('design_metrics_summary.csv')

# Filter for high-quality designs
high_quality = df[
    (df['ipsae_score'] < 5.0) &
    (df['predicted_binding_affinity'] < -10.0) &
    (df['buried_surface_area'] > 1000) &
    (df['num_interface_contacts'] > 50)
]

print(f"Found {len(high_quality)} high-quality designs:")
print(high_quality[['design_id', 'rank', 'composite_score', 'ipsae_score', 'predicted_binding_affinity']])
```

### Custom Composite Score Weights

To customize how designs are ranked, edit `assets/consolidate_design_metrics.py` and modify the `weights` dictionary in the `calculate_composite_score` function:

```python
weights = {
    'ipsae_score': -2.0,  # Double the importance of interface quality
    'predicted_binding_affinity': -1.0,
    'buried_surface_area': 0.02,  # Double the importance of BSA
    'num_interface_contacts': 0.1,
    'model_confidence': 1.0,
    'plddt_avg': 0.1,
}
```

## Troubleshooting

### "No designs found" in report

This usually means:
- The pipeline hasn't completed successfully
- Metrics weren't generated (check that `--run_ipsae` and/or `--run_prodigy` are enabled)
- The output directory path is incorrect

Check the Nextflow log for errors in individual processes.

### Missing metrics for some designs

Some designs may not have all metrics if:
- IPSAE or PRODIGY failed for specific structures
- Not all analysis modules were enabled
- File naming patterns don't match (check the glob patterns in the script)

The consolidation will still include partial metrics for these designs.

### Customizing file patterns

If you have custom directory structures, you can modify the glob patterns in the `CONSOLIDATE_METRICS` process in `modules/local/consolidate_metrics.nf`.

## Best Practices

1. **Always enable multiple metrics**: Use at least IPSAE and PRODIGY for comprehensive evaluation
2. **Review top 5-10 designs**: Don't rely solely on the #1 ranked design
3. **Check for consistency**: Good designs should score well across multiple metrics
4. **Validate experimentally**: Computational predictions should be validated in the lab
5. **Consider diversity**: Sometimes lower-ranked designs with different features are worth exploring

## Citation

If you use the consolidation feature in your research, please cite:

- **Boltzgen**: [Add Boltzgen citation]
- **ProteinMPNN**: Dauparas et al. (2022) Science
- **IPSAE**: Interface PAE scoring method
- **PRODIGY**: Vangone & Bonvin (2015) eLife

