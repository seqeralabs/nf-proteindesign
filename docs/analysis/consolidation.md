# Metrics Consolidation

## Overview

The metrics consolidation module aggregates results from all analysis tools into a unified CSV report and markdown summary. This provides a comprehensive overview of design quality across all enabled analyses.

!!! tip "Unified Analysis"
    Consolidation automatically collects metrics from Boltzgen, ProteinMPNN, Protenix, ipSAE, PRODIGY, and Foldseek, making it easy to compare designs and identify top candidates.

## When to Use Consolidation

Enable metrics consolidation when you:

- **Compare designs**: Need to evaluate multiple designs across different metrics
- **Identify top candidates**: Want to quickly find the best designs based on multiple criteria
- **Track provenance**: Need to know which designs came from Boltzgen vs. Protenix
- **Generate reports**: Want publication-ready summary tables

## Enabling Consolidation

```bash
nextflow run seqeralabs/nf-proteindesign \
    -profile docker \
    --input samplesheet.csv \
    --run_proteinmpnn \
    --run_protenix_refold \
    --run_ipsae \
    --run_prodigy \
    --run_foldseek \
    --foldseek_database /path/to/afdb \
    --run_consolidation \
    --outdir results
```

!!! note
    Consolidation works with any combination of analysis modules. It will include whatever metrics are available from enabled analyses.

## Key Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--run_consolidation` | `false` | Enable metrics consolidation |
| `--report_top_n` | `10` | Number of top designs to highlight in report |

## Output Files

Consolidation generates a unified metrics directory:

```
results/
└── consolidated_metrics/
    ├── all_designs_metrics.csv           # Complete metrics for all designs
    ├── top_designs_summary.md            # Markdown report of top designs
    └── metrics_by_source.csv             # Metrics grouped by source (Boltzgen/Protenix)
```

## Consolidated Metrics CSV

The `all_designs_metrics.csv` file contains all available metrics in a single table:

### Core Columns

| Column | Description | Source |
|--------|-------------|--------|
| `design_id` | Unique design identifier | All |
| `parent_id` | Parent design ID (links Protenix to Boltzgen) | All |
| `source` | `boltzgen` or `protenix` | All |
| `structure_file` | Path to CIF structure | Boltzgen/Protenix |

### ProteinMPNN Metrics (if enabled)

| Column | Description |
|--------|-------------|
| `mpnn_score` | ProteinMPNN sequence score |
| `mpnn_sequence` | Optimized sequence |
| `mpnn_recovery` | Sequence recovery rate |

### Protenix Metrics (if enabled)

| Column | Description |
|--------|-------------|
| `protenix_confidence` | Overall confidence score |
| `protenix_plddt` | Mean pLDDT score |
| `protenix_ptm` | Predicted TM-score |

### ipSAE Metrics (if enabled)

| Column | Description |
|--------|-------------|
| `ipsae_score` | Interface quality score |
| `ipsae_ipae` | Interface predicted aligned error |
| `ipsae_num_contacts` | Number of interface contacts |

### PRODIGY Metrics (if enabled)

| Column | Description |
|--------|-------------|
| `prodigy_dg` | Predicted binding free energy (ΔG, kcal/mol) |
| `prodigy_kd` | Predicted dissociation constant (Kd, M) |
| `prodigy_kd_temp` | Kd at specified temperature |

### Foldseek Metrics (if enabled)

| Column | Description |
|--------|-------------|
| `foldseek_top_hit` | Best matching structure |
| `foldseek_evalue` | E-value of top hit |
| `foldseek_score` | Alignment score |
| `foldseek_num_hits` | Number of significant hits |

## Top Designs Summary

The `top_designs_summary.md` provides a markdown-formatted report highlighting the best designs:

```markdown
# Top Designs Summary

## Overview
- Total designs analyzed: 120
- Boltzgen designs: 60
- Protenix designs: 60

## Top 10 Designs by ipSAE Score

| Rank | Design ID | Source | ipSAE | PRODIGY ΔG | Foldseek E-value |
|------|-----------|--------|-------|------------|------------------|
| 1 | design1_0001 | boltzgen | 0.92 | -12.5 | 1.2e-8 |
| 2 | design1_0002 | protenix | 0.89 | -11.8 | 3.4e-7 |
...
```

## Example Analysis Workflow

### 1. View All Metrics

```bash
# Open in spreadsheet software
libreoffice results/consolidated_metrics/all_designs_metrics.csv

# Or view in terminal
column -t -s, results/consolidated_metrics/all_designs_metrics.csv | less -S
```

### 2. Filter Top Designs

```bash
# Find designs with strong binding (PRODIGY ΔG < -10)
awk -F',' '$8 < -10' results/consolidated_metrics/all_designs_metrics.csv

# Find designs with high ipSAE score (> 0.8)
awk -F',' '$6 > 0.8' results/consolidated_metrics/all_designs_metrics.csv

# Find designs with significant Foldseek hits (E-value < 1e-5)
awk -F',' '$11 < 1e-5' results/consolidated_metrics/all_designs_metrics.csv
```

### 3. Compare Boltzgen vs. Protenix

```bash
# View metrics by source
cat results/consolidated_metrics/metrics_by_source.csv

# Count designs per source
awk -F',' 'NR>1 {print $3}' results/consolidated_metrics/all_designs_metrics.csv | sort | uniq -c
```

### 4. Identify Best Overall Designs

```python
import pandas as pd

# Load metrics
df = pd.read_csv('results/consolidated_metrics/all_designs_metrics.csv')

# Define scoring criteria (adjust weights as needed)
df['combined_score'] = (
    df['ipsae_score'] * 0.3 +           # Interface quality
    (df['prodigy_dg'] / -15) * 0.3 +    # Binding strength (normalized)
    (1 - df['foldseek_evalue']) * 0.2 + # Structural novelty
    df['protenix_confidence'] * 0.2     # Confidence (if available)
)

# Get top 10
top_designs = df.nlargest(10, 'combined_score')
print(top_designs[['design_id', 'source', 'combined_score', 'ipsae_score', 'prodigy_dg']])
```

## Integration with Analysis Modules

### Partial Analysis Support

Consolidation works with any subset of analysis modules:

```bash
# Only ipSAE and PRODIGY
--run_ipsae --run_prodigy --run_consolidation

# Only Foldseek
--run_foldseek --foldseek_database /path/to/afdb --run_consolidation

# All modules
--run_proteinmpnn --run_protenix_refold --run_ipsae --run_prodigy --run_foldseek --run_consolidation
```

Missing metrics will be indicated as `NA` in the CSV.

### Provenance Tracking

The report tracks design provenance:

- **Boltzgen designs**: Original structures from Boltzgen design
- **Protenix designs**: Structures from ProteinMPNN sequences refolded by Protenix

Parent-child relationships are maintained via `parent_id` column.

## Customizing the Report

### Change Number of Top Designs

```bash
--report_top_n 20  # Show top 20 instead of default 10
```

### Sort by Different Metrics

The consolidation script can be customized to prioritize different metrics. Edit `assets/consolidate_design_metrics.py` to change sorting criteria.

## Use Cases

### 1. Therapeutic Development

Identify designs with:
- Strong binding affinity (PRODIGY ΔG < -10 kcal/mol)
- High interface quality (ipSAE > 0.8)
- Novel structures (Foldseek E-value > 0.01)

### 2. Protein Engineering

Compare:
- Boltzgen designs (original scaffold)
- Protenix designs (sequence-optimized)
- Identify improvements from ProteinMPNN optimization

### 3. High-Throughput Screening

Process large design sets:
- Rank by combined score
- Filter by specific thresholds
- Identify patterns in successful designs

## Performance Notes

- **Execution time**: < 1 minute for typical datasets
- **Resource usage**: Minimal (CPU-only, < 1 GB memory)
- **Scales linearly**: Works with 10s to 1000s of designs

## Troubleshooting

### Missing Metrics

```bash
ERROR: No ipSAE results found
```

**Cause**: Analysis module was not run or failed

**Solution**: 
- Check that the module was enabled (`--run_ipsae`)
- Verify module completed successfully in pipeline logs
- Consolidation will still run with available metrics

### Empty CSV

If `all_designs_metrics.csv` is empty:

1. Check that at least one analysis module completed
2. Verify output directory structure
3. Check pipeline logs for errors in analysis modules

### Inconsistent Design Counts

If Protenix design count doesn't match ProteinMPNN:

- This is expected behavior (some sequences may fail refolding)
- Check Protenix logs for failed predictions
- Consolidation will include all successfully generated structures

## Best Practices

1. **Always enable consolidation**: Provides overview even with single analysis
2. **Use with multiple analyses**: Maximum value when combining multiple metrics
3. **Document criteria**: Note which metrics matter for your application
4. **Archive reports**: Save consolidated reports for reproducibility
5. **Visualize**: Import CSV into plotting tools for visual analysis

## See Also

- [ipSAE Scoring](ipsae.md) - Interface quality evaluation
- [PRODIGY Binding Affinity](prodigy.md) - Binding strength prediction
- [Foldseek Structural Search](foldseek.md) - Structural similarity analysis
- [Output Files Reference](../reference/outputs.md) - Complete output documentation
