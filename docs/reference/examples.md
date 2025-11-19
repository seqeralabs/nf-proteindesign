# Example Workflows

Complete examples for common use cases.

## :material-test-tube: Example 1: Antibody Design

Design an antibody VH domain to bind EGFR.

### Setup

```bash
# Create design YAML
cat > antibody_egfr.yaml << EOF
name: anti_egfr_vh
target:
  structure: data/egfr_ectodomain.pdb
  residues: [10, 11, 12, 13, 45, 46, 47, 89, 90, 91]
designed:
  chain_type: protein
  length: [100, 130]
global:
  n_samples: 50
  timesteps: 100
EOF

# Create samplesheet
cat > antibody_samples.csv << EOF
sample,design_yaml
egfr_vh,antibody_egfr.yaml
EOF
```

### Run

```bash
nextflow run seqeralabs/nf-proteindesign \
    -profile docker \
    --input antibody_samples.csv \
    --outdir egfr_antibodies \
    --run_prodigy
```

### Analyze

```python
import pandas as pd

# Load results
results = pd.read_csv('egfr_antibodies/egfr_vh/prodigy/design_*_summary.csv')

# Find top 5 candidates
top5 = results.nsmallest(5, 'delta_g')
print(top5[['design_file', 'delta_g', 'kd', 'bsa']])
```

## :material-flask: Example 2: Peptide Binder Library

Screen peptide lengths for IL-6 binding.

### Setup

```bash
cat > peptide_targets.csv << EOF
sample,target_structure,target_residues,chain_type
il6,data/il6.pdb,"20,21,22,65,66,67",peptide
EOF
```

### Run

```bash
nextflow run seqeralabs/nf-proteindesign \
    -profile docker \
    --mode target \
    --input peptide_targets.csv \
    --chain_type peptide \
    --min_design_length 10 \
    --max_design_length 30 \
    --length_step 5 \
    --n_variants_per_length 5 \
    --n_samples 30 \
    --run_prodigy \
    --outdir peptide_library
```

### Analyze

```bash
# Find optimal peptide length
cat peptide_library/il6/prodigy/*_summary.csv | \
    grep -v "sample_id" | \
    awk -F',' '{
        len = substr($2, match($2, /len[0-9]+/), 5)
        print len, $3
    }' | \
    sort -k1,1n -k2,2n
```

## :material-brain: Example 3: Binding Site Discovery

### Setup

```bash
cat > discovery.csv << EOF
sample,target_structure,chain_type
novel_target,data/novel_protein.pdb,protein
EOF
```

### Run

```bash
nextflow run seqeralabs/nf-proteindesign \
    -profile docker \
    --input discovery.csv \
    --n_samples 20 \
    --run_prodigy \
    --outdir discovery_results
```

### Visualize

```bash
# Load in PyMOL
```

## :material-robot: Example 4: High-Throughput Campaign

Design binders for multiple targets in parallel.

### Setup

```bash
cat > hts_campaign.csv << EOF
sample,target_structure,target_residues,chain_type,min_length,max_length
target1,data/target1.pdb,"10,11,12",protein,60,120
target2,data/target2.pdb,"25,26,27",nanobody,110,130
target3,data/target3.pdb,"5,6,7,8",peptide,15,25
target4,data/target4.pdb,"40,41,42",protein,80,140
EOF
```

### Run

```bash
nextflow run seqeralabs/nf-proteindesign \
    -profile docker \
    --mode target \
    --input hts_campaign.csv \
    --length_step 20 \
    --n_variants_per_length 3 \
    --n_samples 50 \
    --run_prodigy \
    --run_ipsae \
    --max_cpus 32 \
    --outdir hts_results
```

### Report

```python
import pandas as pd
from pathlib import Path

# Collect all results
all_results = []
for sample_dir in Path('hts_results').iterdir():
    if sample_dir.is_dir():
        prodigy_files = sample_dir.glob('prodigy/*_summary.csv')
        for f in prodigy_files:
            df = pd.read_csv(f)
            df['sample'] = sample_dir.name
            all_results.append(df)

combined = pd.concat(all_results)

# Summary statistics
summary = combined.groupby('sample')['delta_g'].agg([
    'count', 'min', 'mean', 'std'
]).round(2)

print(summary)
combined.to_csv('hts_summary.csv', index=False)
```

## :material-chart-line: Example 5: Optimization Workflow

Iterative refinement of designs.

### Round 1: Initial Screen

```bash
# Wide screen
nextflow run seqeralabs/nf-proteindesign \
    -profile docker \
    --mode target \
    --input targets.csv \
    --min_design_length 50 \
    --max_design_length 150 \
    --length_step 30 \
    --n_variants_per_length 2 \
    --n_samples 20 \
    --outdir round1
```

### Round 2: Focused Design

```bash
# Analyze round 1, identify optimal range (e.g., 80-110)

nextflow run seqeralabs/nf-proteindesign \
    -profile docker \
    --mode target \
    --input targets.csv \
    --min_design_length 80 \
    --max_design_length 110 \
    --length_step 10 \
    --n_variants_per_length 5 \
    --n_samples 50 \
    --outdir round2
```

### Round 3: Final Optimization

```bash
# Create custom YAML from best hits
# Use design mode for final optimization

nextflow run seqeralabs/nf-proteindesign \
    -profile docker \
    --mode design \
    --input optimized_designs.csv \
    --n_samples 100 \
    --timesteps 200 \
    --run_prodigy \
    --run_ipsae \
    --outdir final_designs
```

## :material-cloud: Example 6: HPC Cluster

Running on SLURM cluster with Docker.

### Configuration

```groovy
// hpc.config
process {
    executor = 'slurm'
    queue = 'gpu'
    
    withLabel: gpu {
        clusterOptions = '--gres=gpu:1 --mem=32GB'
        time = '48h'
    }
}

docker {
    enabled = true
    runOptions = '--gpus all'
}
```

### Run

```bash
nextflow run seqeralabs/nf-proteindesign \
    -profile docker \
    -c hpc.config \
    --input samplesheet.csv \
    --outdir results
```

## :material-format-list-checks: Best Practices Examples

### Reproducible Run

```bash
# Use explicit versions and seeds
nextflow run seqeralabs/nf-proteindesign \
    -r v1.0.0 \
    -profile docker \
    --input samplesheet.csv \
    --outdir results_v1.0.0 \
    --n_samples 50 \
    2>&1 | tee pipeline.log
```

### Resume After Failure

```bash
# Add -resume flag
nextflow run seqeralabs/nf-proteindesign \
    -profile docker \
    --input samplesheet.csv \
    --outdir results \
    -resume
```

### Resource Monitoring

```bash
# Generate detailed reports
nextflow run seqeralabs/nf-proteindesign \
    -profile docker \
    --input samplesheet.csv \
    --outdir results \
    -with-report results/report.html \
    -with-timeline results/timeline.html \
    -with-trace results/trace.txt \
    -with-dag results/dag.png
```

## :material-arrow-right: More Resources

- [Quick Reference](../getting-started/quick-reference.md)
- [Parameters Guide](parameters.md)
- [Output Files](outputs.md)

---

!!! example "Share Your Examples"
    Have a great use case? Consider contributing to the documentation!
