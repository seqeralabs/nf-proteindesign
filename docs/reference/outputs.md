# Output Files Reference

Complete guide to understanding pipeline outputs.

## :material-folder-open: Directory Structure

```
results/
├── {sample_id}/
│   ├── boltzgen/
│   ├── prodigy/
│   └── ipsae/
└── pipeline_info/
```

## :material-dna: Boltzgen Outputs

### Final Ranked Designs

```
results/{sample}/boltzgen/final_ranked_designs/
├── design_1.cif
├── design_2.cif
└── ...
```

**Description**: Top-ranked protein designs in CIF format.

**Contents**: Complete atomic coordinates for designed complexes.

### Intermediate Designs

```
results/{sample}/boltzgen/intermediate_designs/
├── generation_*.cif
├── inverse_fold_*.cif
└── refold_*.cif
```

**Description**: Intermediate structures from design pipeline.

### Log Files

```
results/{sample}/boltzgen/boltzgen.log
```

**Description**: Complete execution log with design metrics.

## :material-chart-box: PRODIGY Outputs

### Summary CSV

```
results/{sample}/prodigy/design_1_prodigy_summary.csv
```

**Format**:
```csv
sample_id,design_file,delta_g,kd,temperature,bsa,ics,charged_residues,charged_percentage,apolar_residues,apolar_percentage
sample1,design_1.cif,-11.2,5.4e-09,25.0,1543.21,89,15,16.85,48,53.93
```

### Full Results

```
results/{sample}/prodigy/design_1_prodigy_results.txt
```

**Description**: Complete PRODIGY output with all metrics.

## :material-chart-line: ipSAE Outputs

```
results/{sample}/ipsae/design_1_ipsae_scores.csv
```

**Format**:
```csv
design_id,interface_area,shape_comp,contact_density,h_bonds,salt_bridges,hydrophobic
design_1,1543.2,0.68,0.045,12,3,28
```

## :material-brain: P2Rank Outputs (P2Rank Mode)

### Pocket Predictions

```
results/{sample}/p2rank/
├── pockets/
│   ├── {sample}_pocket1.pdb
│   ├── {sample}_pocket2.pdb
│   └── ...
├── visualizations/
│   └── {sample}_pockets.pml
└── {sample}_predictions.csv
```

### Predictions CSV

**Format**:
```csv
rank,score,size,center_x,center_y,center_z,residues
1,0.85,42,12.3,45.6,78.9,"10,11,12,45,46,47"
2,0.72,38,23.4,56.7,89.0,"20,21,22,65,66,67"
```

## :material-file-multiple: Target Mode Outputs

### Generated Designs

```
results/{sample}/design_variants/
├── {sample}_len60_v1.yaml
├── {sample}_len60_v2.yaml
├── {sample}_len80_v1.yaml
└── ...
```

### Design Info

```
results/{sample}/design_info.txt
```

**Contents**: Summary of generated design variants.

## :material-information: Pipeline Info

### Execution Report

```
results/pipeline_info/execution_report.html
```

**Description**: Interactive HTML report with:
- Pipeline execution summary
- Resource usage statistics
- Process completion status
- Error reports

### Execution Timeline

```
results/pipeline_info/execution_timeline.html
```

**Description**: Visual timeline of process execution.

### Execution Trace

```
results/pipeline_info/execution_trace.txt
```

**Format**: TSV file with detailed process information:
```
task_id  hash      native_id  name         status    exit  submit               duration  realtime  %cpu      rss       vmem
1        ab/cd12   12345      BOLTZGEN_RUN COMPLETED 0     2024-01-15 10:00:00  1h 23m    1h 21m    95.2%     16.2 GB   24.1 GB
```

## :material-file-download: File Formats

### CIF Files

**Description**: Crystallographic Information File format

**Usage**:
```bash
# View with PyMOL
pymol design_1.cif

# Convert to PDB
obabel design_1.cif -O design_1.pdb
```

### YAML Files

**Description**: Design specifications

**Example**:
```yaml
name: design1
target:
  structure: target.pdb
  residues: [10, 11, 12]
designed:
  chain_type: protein
  length: [60, 100]
```

### CSV Files

**Description**: Comma-separated analysis results

**Usage**:
```python
import pandas as pd
df = pd.read_csv('design_1_prodigy_summary.csv')
```

## :material-database: Result Organization

### By Sample

All outputs for each sample grouped together:

```
results/
├── sample1/
│   ├── boltzgen/
│   ├── prodigy/
│   └── ipsae/
└── sample2/
    └── ...
```

### By Analysis Type

Within each sample, organized by analysis:

```
{sample}/
├── boltzgen/          # Primary designs
├── prodigy/           # Binding affinity
└── ipsae/             # Interface scoring
```

## :material-download: Accessing Results

### Command Line

```bash
# List all final designs
find results/ -name "*.cif" -path "*/final_ranked_designs/*"

# Get best PRODIGY scores
cat results/*/prodigy/*_summary.csv | \
    grep -v "sample_id" | \
    sort -t',' -k3,3n | \
    head -5

# Count successful designs
find results/ -name "design_*.cif" | wc -l
```

### Python

```python
from pathlib import Path
import pandas as pd

# Load all PRODIGY results
results = []
for csv in Path('results').rglob('*_prodigy_summary.csv'):
    df = pd.read_csv(csv)
    results.append(df)

combined = pd.concat(results)
print(combined.nsmallest(10, 'delta_g'))
```

### R

```r
library(tidyverse)

# Load PRODIGY results
results <- list.files(
    "results", 
    pattern = "*_summary.csv",
    recursive = TRUE,
    full.names = TRUE
) %>%
    map_df(read_csv)

# Analyze
results %>%
    arrange(delta_g) %>%
    head(10)
```

## :material-file-check: Quality Control

### Check Completion

```bash
# Verify all samples completed
grep "COMPLETED" results/pipeline_info/execution_trace.txt | \
    wc -l

# Check for failures
grep "FAILED" results/pipeline_info/execution_trace.txt
```

### Validate Outputs

```bash
# Ensure all expected files exist
for sample in sample1 sample2; do
    if [ ! -d "results/${sample}/boltzgen/final_ranked_designs" ]; then
        echo "Missing designs for ${sample}"
    fi
done
```

## :material-package: Export Results

### Archive for Publication

```bash
# Create archive of final results
tar -czf protein_designs.tar.gz \
    results/*/boltzgen/final_ranked_designs/ \
    results/*/prodigy/*_summary.csv \
    results/pipeline_info/execution_report.html
```

### Upload to Repository

```bash
# Example: Upload to Zenodo, FigShare, etc.
# See repository-specific instructions
```

## :material-arrow-right: Next Steps

- [Quick Reference](../getting-started/quick-reference.md)
- [Analysis Examples](examples.md)
- [Parameter Reference](parameters.md)

---

!!! tip "Reproducibility"
    Always save the execution report and trace files for reproducibility and troubleshooting.
