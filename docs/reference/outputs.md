# Output Files Reference

Complete guide to understanding pipeline outputs.

## :material-folder-open: Directory Structure

```
results/
├── {sample_id}/
│   ├── boltzgen/ or complexa/    # Design outputs (depends on tool)
│   ├── proteinmpnn/              # Sequence optimization
│   ├── boltz2/                   # Structure prediction (refolding)
│   ├── ipsae/                    # Interface scoring
│   ├── prodigy/                  # Affinity prediction
│   ├── foldseek/                 # Structural search
│   └── consolidated/            # Combined metrics report
└── pipeline_info/
```

## :material-dna: Design Tool Outputs

### BoltzGen Outputs (default)

```
results/{sample}/boltzgen/
├── design_1.pdb
├── design_2.pdb
└── ...
```

**Description**: Generated protein designs in PDB format from BoltzGen.

### Complexa Outputs

```
results/{sample}/complexa/
├── design_1.pdb
├── design_2.pdb
└── ...
```

**Description**: Generated protein designs from Proteina-Complexa.

## :material-protein: ProteinMPNN Outputs

```
results/{sample}/proteinmpnn/
├── sequences/                   # Optimized FASTA sequences
│   ├── design_1.fa
│   └── ...
└── scores/                      # ProteinMPNN scores
    ├── design_1_scores.txt
    └── ...
```

**Description**: Sequence optimization results — optimized amino acid sequences for each generated structure.

## :material-molecule: Boltz-2 Outputs

```
results/{sample}/boltz2/
├── structures/                  # Predicted CIF structures
│   ├── design_1.cif
│   └── ...
├── confidence/                  # Confidence scores (JSON)
│   ├── design_1_confidence.json
│   └── ...
└── npz/                         # PAE NPZ files
    ├── design_1.npz
    └── ...
```

**Description**: Structure prediction (refolding) results from Boltz-2, validating whether optimized sequences fold into the intended structure.

## :material-chart-box: PRODIGY Outputs

```
results/{sample}/prodigy/
├── design_1_prodigy_results.txt
└── ...
```

**Description**: Complete PRODIGY output with binding affinity predictions including ΔG and Kd values.

## :material-chart-line: ipSAE Outputs

```
results/{sample}/ipsae/
├── design_1_ipsae_scores.txt
└── ...
```

**Description**: Interface scoring results measuring quality of the protein-protein interface.

## :material-magnify: Foldseek Outputs

```
results/{sample}/foldseek/
├── design_1_foldseek_summary.tsv
└── ...
```

**Description**: Structural similarity search results against known protein structures.

## :material-table: Consolidated Outputs

```
results/{sample}/consolidated/
├── consolidated_metrics.csv     # Combined metrics for all designs
└── consolidated_report.html     # Interactive HTML report
```

**Description**: Combined report merging all analysis module scores into a single ranked table for easy comparison.

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
1        ab/cd12   12345      COMPLEXA_RUN COMPLETED 0     2024-01-15 10:00:00  1h 23m    1h 21m    95.2%     16.2 GB   24.1 GB
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
│   ├── complexa/
│   ├── prodigy/
│   └── ipsae/
└── sample2/
    └── ...
```

### By Analysis Type

Within each sample, organized by analysis:

```
{sample}/
├── complexa/          # Primary designs
├── prodigy/           # Binding affinity
└── ipsae/             # Interface scoring
```

## :material-download: Accessing Results

### Command Line

```bash
# List all design structures
find results/ -name "*.pdb" -path "*/boltzgen/*"
# or for Complexa:
find results/ -name "*.pdb" -path "*/complexa/*"

# View consolidated metrics
cat results/*/consolidated/consolidated_metrics.csv | column -t -s,

# Count successful designs
find results/ -name "design_*.pdb" | wc -l
```

### Python

```python
from pathlib import Path
import pandas as pd

# Load consolidated metrics
results = []
for csv in Path('results').rglob('consolidated_metrics.csv'):
    df = pd.read_csv(csv)
    results.append(df)

combined = pd.concat(results)
print(combined.nsmallest(10, 'prodigy_delta_g'))
```

### R

```r
library(tidyverse)

# Load consolidated metrics
results <- list.files(
    "results", 
    pattern = "consolidated_metrics.csv",
    recursive = TRUE,
    full.names = TRUE
) %>%
    map_df(read_csv)

# Analyze — find top designs by binding affinity
results %>%
    arrange(prodigy_delta_g) %>%
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
# Ensure all expected output directories exist
for sample in sample1 sample2; do
    if [ ! -d "results/${sample}/consolidated" ]; then
        echo "Missing consolidated results for ${sample}"
    fi
done
```

## :material-package: Export Results

### Archive for Publication

```bash
# Create archive of final results
tar -czf protein_designs.tar.gz \
    results/*/complexa/final_ranked_designs/ \
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
