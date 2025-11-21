# Example Workflows

Complete examples for common protein design use cases.

## :material-dna: Example 1: Protein Binder Design

Design a protein to bind EGFR using a pre-made design specification.

### Create Design YAML

```yaml title="egfr_protein_design.yaml"
# Boltzgen design specification for protein binder
entities:
  # Designed protein entity
  - protein:
      id: C
      sequence: 80..120  # Length range for designed protein
  
  # Target structure entity  
  - file:
      path: egfr_structure.cif
      include:
        - chain:
            id: A  # Target chain to bind
```

### Create Samplesheet

```csv title="egfr_samplesheet.csv"
sample_id,design_yaml,structure_files,protocol,num_designs,budget
egfr_binder,egfr_protein_design.yaml,egfr_structure.cif,protein-anything,100,10
```

### Run Pipeline

```bash
nextflow run seqeralabs/nf-proteindesign \
    -profile docker \
    --input egfr_samplesheet.csv \
    --outdir egfr_designs \
    --run_proteinmpnn \
    --run_ipsae \
    --run_prodigy \
    --run_consolidation
```

### Analyze Results

```python
import pandas as pd

# Load consolidated metrics
results = pd.read_csv('egfr_designs/egfr_binder/consolidated_metrics.csv')

# Find top 5 candidates by binding affinity
top5 = results.nsmallest(5, 'prodigy_delta_g')
print(top5[['design_file', 'prodigy_delta_g', 'prodigy_kd', 'ipsae_score']])
```

## :material-flask: Example 2: Peptide Binder Design

Design peptide binders for a target protein.

### Create Design YAML

```yaml title="peptide_design.yaml"
# Boltzgen design specification for peptide binder
entities:
  # Designed peptide entity
  - protein:
      id: P
      sequence: 12..25  # Peptide length range
  
  # Target structure
  - file:
      path: target.cif
      include:
        - chain:
            id: A
```

### Create Samplesheet

```csv title="peptide_samplesheet.csv"
sample_id,design_yaml,structure_files,protocol,num_designs,budget
peptide_binder,peptide_design.yaml,target.cif,peptide-anything,100,10
```

### Run Pipeline

```bash
nextflow run seqeralabs/nf-proteindesign \
    -profile docker \
    --input peptide_samplesheet.csv \
    --protocol peptide-anything \
    --outdir peptide_designs
```

## :material-antibody: Example 3: Nanobody Design

Design nanobodies to bind a specific target.

### Create Design YAML

```yaml title="nanobody_design.yaml"
# Boltzgen design specification for nanobody
entities:
  # Designed nanobody entity
  - protein:
      id: N
      sequence: 110..130  # Typical nanobody length range
  
  # Target structure
  - file:
      path: antigen.cif
      include:
        - chain:
            id: A
```

### Create Samplesheet

```csv title="nanobody_samplesheet.csv"
sample_id,design_yaml,structure_files,protocol,num_designs,budget
nanobody_binder,nanobody_design.yaml,antigen.cif,nanobody-anything,100,10
```

### Run Pipeline

```bash
nextflow run seqeralabs/nf-proteindesign \
    -profile docker \
    --input nanobody_samplesheet.csv \
    --protocol nanobody-anything \
    --outdir nanobody_designs
```

## :material-test-tube: Example 4: Multiple Targets

Design binders for multiple targets in a single run.

### Create Design YAMLs

```yaml title="target1_design.yaml"
entities:
  - protein:
      id: C
      sequence: 80..120
  - file:
      path: target1.cif
      include:
        - chain:
            id: A
```

```yaml title="target2_design.yaml"
entities:
  - protein:
      id: C
      sequence: 60..100
  - file:
      path: target2.cif
      include:
        - chain:
            id: B
```

### Create Samplesheet

```csv title="multi_target_samplesheet.csv"
sample_id,design_yaml,structure_files,protocol,num_designs,budget
target1_binder,target1_design.yaml,target1.cif,protein-anything,100,10
target2_binder,target2_design.yaml,target2.cif,protein-anything,100,10
```

### Run Pipeline

```bash
nextflow run seqeralabs/nf-proteindesign \
    -profile docker \
    --input multi_target_samplesheet.csv \
    --outdir multi_designs \
    --run_consolidation
```

## :material-chart-bar: Example 5: Full Analysis Pipeline

Complete workflow with all analysis tools enabled.

### Create Samplesheet

```csv title="full_analysis_samplesheet.csv"
sample_id,design_yaml,structure_files,protocol,num_designs,budget
full_analysis,my_design.yaml,target.cif,protein-anything,200,20
```

### Run Pipeline

```bash
nextflow run seqeralabs/nf-proteindesign \
    -profile docker \
    --input full_analysis_samplesheet.csv \
    --outdir full_analysis_results \
    --num_designs 200 \
    --budget 20 \
    --run_proteinmpnn \
    --mpnn_num_seq_per_target 10 \
    --run_ipsae \
    --ipsae_pae_cutoff 8 \
    --run_prodigy \
    --run_consolidation \
    --report_top_n 20
```

### Review Consolidated Report

```bash
# View consolidated metrics
cat full_analysis_results/full_analysis/consolidated_metrics.csv | column -t -s,

# Count successful designs
grep "SUCCESS" full_analysis_results/full_analysis/consolidated_metrics.csv | wc -l

# Find designs with best affinity
sort -t',' -k3,3n full_analysis_results/full_analysis/consolidated_metrics.csv | head -10
```

## :material-cog: Example 6: Using Test Profiles

The pipeline includes built-in test profiles for quick validation.

### Test Protein Design

```bash
nextflow run seqeralabs/nf-proteindesign \
    -profile test_design_protein,docker \
    --outdir test_protein_results
```

### Test Peptide Design

```bash
nextflow run seqeralabs/nf-proteindesign \
    -profile test_design_peptide,docker \
    --outdir test_peptide_results
```

### Test Nanobody Design

```bash
nextflow run seqeralabs/nf-proteindesign \
    -profile test_design_nanobody,docker \
    --outdir test_nanobody_results
```

## :material-cloud: Example 7: Seqera Platform Deployment

Run the pipeline on Seqera Platform with GPU compute.

### Via Seqera Platform UI

1. Navigate to your workspace
2. Click "Launch Pipeline"
3. Select `seqeralabs/nf-proteindesign`
4. Upload your samplesheet to a Data Link
5. Configure parameters:
   - `input`: Path to samplesheet in Data Link
   - `outdir`: Output Data Link path
   - `num_designs`: 100
   - `budget`: 10
6. Select GPU-enabled compute environment
7. Click "Launch"

### Via Seqera CLI

```bash
# Create launch configuration
tw launch seqeralabs/nf-proteindesign \
    --workspace <your-workspace> \
    --compute-env <gpu-compute-env> \
    --params-file params.json \
    --outdir s3://your-bucket/results
```

## :material-file-document: Output Files

After pipeline completion, you'll find:

```
results/
└── {sample_id}/
    ├── boltzgen/
    │   ├── final_ranked_designs/
    │   │   ├── design_1.cif          # Top ranked design
    │   │   ├── design_2.cif
    │   │   └── ...
    │   └── intermediate_designs/
    │       └── *.cif
    ├── proteinmpnn/                   # If --run_proteinmpnn enabled
    │   ├── design_1_sequences.fa
    │   └── ...
    ├── ipsae/                         # If --run_ipsae enabled
    │   ├── design_1_ipsae_scores.csv
    │   └── ...
    ├── prodigy/                       # If --run_prodigy enabled
    │   ├── design_1_prodigy_summary.csv
    │   └── ...
    └── consolidated_metrics.csv       # If --run_consolidation enabled
```

## :material-lightbulb: Tips and Best Practices

### Design YAML Tips

- **Length ranges**: Use `80..120` syntax for flexible design lengths
- **Multiple chains**: Specify multiple target chains for complex interfaces
- **Chain IDs**: Use descriptive chain IDs (A, B, C, etc.)

### Parameter Tuning

- **Quick tests**: Start with `num_designs=10, budget=5` for fast validation
- **Production runs**: Use `num_designs=100-200, budget=10-20` for quality results
- **Large campaigns**: Increase to `num_designs=200+, budget=50+` for diversity

### Resource Optimization

- **GPU memory**: Ensure 16GB+ VRAM for standard runs
- **Caching**: Use `--cache_dir` to avoid re-downloading model weights
- **Resume**: Always use `-resume` flag to recover from interruptions

### Analysis Workflow

1. Run Boltzgen to generate initial designs
2. Enable ProteinMPNN for sequence optimization
3. Use IPSAE for interface quality scoring
4. Apply PRODIGY for binding affinity prediction
5. Review consolidated metrics for top candidates
6. Select top designs for experimental validation

## :material-help: Troubleshooting

### Common Issues

**GPU not detected:**
```bash
# Verify GPU access
nvidia-smi
docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi
```

**Out of memory:**
```bash
# Reduce num_designs or use smaller length ranges in design YAML
nextflow run ... --num_designs 50
```

**Pipeline fails:**
```bash
# Resume from last successful step
nextflow run seqeralabs/nf-proteindesign -resume ...
```

## :material-arrow-right: Next Steps

- [Parameter Reference](parameters.md)
- [Quick Reference Guide](../getting-started/quick-reference.md)
- [Analysis Modules](../analysis/proteinmpnn-protenix.md)
- [Architecture Documentation](../architecture/design.md)

---

!!! info "Need Help?"
    Join the discussion on [GitHub](https://github.com/seqeralabs/nf-proteindesign/discussions) or open an [issue](https://github.com/seqeralabs/nf-proteindesign/issues).
