# P2Rank Mode

## :material-brain: Overview

P2Rank mode uses machine learning to automatically predict binding pockets on target structures, then designs binders for the top-ranked sites. Perfect for discovery when binding sites are unknown.

!!! success "Best For"
    - Unknown binding sites
    - Discovery-phase projects
    - Exploring multiple potential binding sites
    - Druggable pocket identification

## :material-robot: How It Works

```mermaid
flowchart LR
    A[Target Structure] --> B[P2Rank Prediction]
    B --> C[Ranked Pockets]
    C --> D[Top N Pockets]
    D --> E[Generate Design YAMLs]
    E --> F[Design Nanobinders]
    
    style B fill:#9C27B0,color:#fff
    style F fill:#8E24AA,color:#fff
```

1. **Predict**: P2Rank identifies potential binding pockets
2. **Rank**: Pockets scored by druggability and likelihood
3. **Select**: Top N pockets selected for design
4. **Generate**: Design variants created for each pocket
5. **Design**: Boltzgen designs binders for all pockets in parallel

!!! info "Design Type Selection"
    **P2Rank mode defaults to nanobody design** because P2Rank is optimized for identifying binding pockets suitable for small molecule ligands. These pockets are ideal for:
    
    - **Nanobodies** (~15 kDa, single-domain antibodies) - **Default and recommended**
    - Short peptides (can also bind in pockets, but less optimal)
    
    ❌ **Not recommended for:**
    - Full proteins (protein-protein interfaces are typically larger and flatter than the pockets P2Rank identifies)
    - Long peptides (>30 amino acids)
    
    You can override this default by specifying `design_type` in your samplesheet, but nanobodies provide the best match for P2Rank-identified binding sites.

## :material-file-table: Samplesheet Format

```csv title="samplesheet_p2rank.csv"
sample,target_structure,design_type,min_length,max_length
unknown_target1,data/target1.pdb,nanobody,110,130
unknown_target2,data/target2.cif,,110,130
drug_target,data/kinase.pdb,peptide,15,30
```

### Column Descriptions

| Column | Required | Description | Example |
|--------|----------|-------------|---------|
| `sample` | ✅ | Unique identifier | `target1` |
| `target_structure` | ✅ | Target PDB/CIF file | `data/target.pdb` |
| `design_type` | Optional | Binder type: `nanobody` (default), `peptide`, or `protein` | `nanobody` |
| `min_length` | Optional | Min length | `50` (default) |
| `max_length` | Optional | Max length | `150` (default) |

## :material-play: Running P2Rank Mode

=== "Basic Run"
    ```bash
    nextflow run FloWuenne/nf-proteindesign-2025 \
        -profile docker \
        --mode p2rank \
        --input samplesheet.csv \
        --outdir results
    ```

=== "Custom Pocket Selection"
    ```bash
    nextflow run FloWuenne/nf-proteindesign-2025 \
        -profile docker \
        --mode p2rank \
        --input samplesheet.csv \
        --outdir results \
        --p2rank_top_n 3 \
        --p2rank_min_score 0.7
    ```

=== "With Conservation"
    ```bash
    nextflow run FloWuenne/nf-proteindesign-2025 \
        -profile docker \
        --mode p2rank \
        --input samplesheet.csv \
        --outdir results \
        --p2rank_conservation \
        --p2rank_top_n 5
    ```

## :material-cog: P2Rank Parameters

| Parameter | Description | Default | Example |
|-----------|-------------|---------|---------|
| `--p2rank_top_n` | Number of top pockets | 5 | `3` |
| `--p2rank_min_score` | Minimum pocket score | 0.5 | `0.7` |
| `--p2rank_conservation` | Use conservation analysis | false | `true` |

## :material-chart-box: Understanding P2Rank Output

### Pocket Scores

P2Rank assigns scores to predicted pockets:

| Score Range | Interpretation | Recommendation |
|-------------|----------------|----------------|
| > 0.8 | High confidence | Excellent candidates |
| 0.6 - 0.8 | Good confidence | Good candidates |
| 0.5 - 0.6 | Moderate | Consider with caution |
| < 0.5 | Low confidence | Usually filtered out |

### Pocket Properties

Each predicted pocket includes:

- **Score**: Confidence/druggability score
- **Rank**: Relative ranking
- **Size**: Number of residues
- **Center**: Geometric center coordinates
- **Residues**: Constituent amino acids

## :material-test-tube: Example Workflows

### Example 1: Novel Target Discovery

```bash
# Create samplesheet for unknown targets
cat > discovery.csv << EOF
sample,target_structure,chain_type
novel_protein1,data/novel1.pdb,protein
novel_protein2,data/novel2.pdb,protein
EOF

# Run P2Rank prediction
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --mode p2rank \
    --input discovery.csv \
    --p2rank_top_n 3 \
    --p2rank_min_score 0.6 \
    --n_samples 20 \
    --outdir discovery_results
```

### Example 2: Druggable Pocket Screening

```bash
# Screen for druggable pockets
cat > drugscreen.csv << EOF
sample,target_structure,chain_type,min_length,max_length
kinase_target,data/kinase.pdb,peptide,10,25
gpcr_target,data/gpcr.pdb,peptide,15,30
EOF

# Run with conservation
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --mode p2rank \
    --input drugscreen.csv \
    --p2rank_conservation \
    --p2rank_min_score 0.7 \
    --run_prodigy \
    --outdir drug_pockets
```

### Example 3: Nanobody Discovery

```bash
# Find pockets for nanobody design
cat > nanobody_discovery.csv << EOF
sample,target_structure
immune_target1,data/target1.pdb
immune_target2,data/target2.pdb
EOF

# Design nanobodies
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --mode p2rank \
    --input nanobody_discovery.csv \
    --chain_type nanobody \
    --min_design_length 110 \
    --max_design_length 130 \
    --p2rank_top_n 5 \
    --n_samples 30 \
    --outdir nanobody_discovery
```

## :material-folder-open: Output Structure

```
results/
└── {sample}/
    ├── p2rank/
    │   ├── pockets/
    │   │   ├── {sample}_pocket1.pdb
    │   │   ├── {sample}_pocket2.pdb
    │   │   └── ...
    │   ├── visualizations/
    │   │   └── {sample}_pockets.pml
    │   └── {sample}_predictions.csv
    ├── design_variants/
    │   ├── {sample}_pocket1_len50_v1.yaml
    │   ├── {sample}_pocket1_len70_v1.yaml
    │   └── ...
    └── boltzgen/
        ├── {sample}_pocket1_len50_v1/
        │   ├── final_ranked_designs/
        │   └── ...
        └── ...
```

## :material-eye: Visualizing Predicted Pockets

### PyMOL Visualization

```python
# Load in PyMOL
pymol results/{sample}/p2rank/visualizations/{sample}_pockets.pml

# Or manually
load results/{sample}/target_structure.pdb
load results/{sample}/p2rank/pockets/{sample}_pocket1.pdb
show surface, pocket1
color marine, pocket1
```

### Python Analysis

```python
import pandas as pd
import matplotlib.pyplot as plt

# Load predictions
predictions = pd.read_csv('results/sample1/p2rank/sample1_predictions.csv')

# Plot pocket scores
plt.figure(figsize=(10, 6))
plt.bar(range(len(predictions)), predictions['score'])
plt.xlabel('Pocket Rank')
plt.ylabel('P2Rank Score')
plt.title('Predicted Pocket Scores')
plt.axhline(y=0.6, color='r', linestyle='--', label='Threshold')
plt.legend()
plt.savefig('pocket_scores.png', dpi=300)

# Show top pockets
print("Top 5 Pockets:")
print(predictions.nlargest(5, 'score')[['rank', 'score', 'size', 'center_x', 'center_y', 'center_z']])
```

## :material-lightbulb: Best Practices

### 1. Start Conservative

```bash
# Use high threshold for initial screening
--p2rank_min_score 0.7 \
--p2rank_top_n 3
```

### 2. Expand if Needed

```bash
# Lower threshold if few pockets found
--p2rank_min_score 0.5 \
--p2rank_top_n 5
```

### 3. Use Conservation

```bash
# For protein families with known structures
--p2rank_conservation
```

This helps identify functionally important pockets.

### 4. Validate Predictions

!!! warning "Always Validate"
    P2Rank predictions should be validated:
    
    - Check biological relevance
    - Compare with known binding sites (if available)
    - Verify accessibility and surface exposure
    - Consider structural context

## :material-compare: When to Use Each Mode

| Scenario | Recommended Mode | Reason |
|----------|-----------------|--------|
| Known binding site | Design or Target | Direct control |
| Unknown binding site | **P2Rank** | Discover sites |
| Known epitope | Target | Systematic exploration |
| Structure-only info | **P2Rank** | No prior knowledge needed |
| Druggability screen | **P2Rank** | Pocket prediction |

## :material-chart-line: Analyzing P2Rank Results

### Compare Pockets Across Targets

```bash
# Extract all pocket predictions
for dir in results/*/p2rank/; do
    sample=$(basename $(dirname $dir))
    cat ${dir}/${sample}_predictions.csv | \
        tail -n +2 | \
        awk -v s=$sample -F',' '{print s","$0}'
done > all_pockets.csv

# Find highest scoring pockets
sort -t',' -k3,3nr all_pockets.csv | head -10
```

### Success Rate by Pocket

```python
import pandas as pd

# Load all PRODIGY results
results = []
for csv in Path('results/').rglob('*_prodigy_summary.csv'):
    df = pd.read_csv(csv)
    # Extract pocket ID from filename
    pocket = csv.parent.parent.name.split('_pocket')[1].split('_')[0]
    df['pocket'] = pocket
    results.append(df)

combined = pd.concat(results)

# Group by pocket and find best designs
best_by_pocket = combined.groupby('pocket')['delta_g'].agg(['min', 'mean', 'count'])
print(best_by_pocket.sort_values('min'))
```

## :material-speedometer: Performance Considerations

### Runtime Estimates

For each target:

```
P2Rank prediction:     5-10 minutes
Designs per pocket:    3-10 variants
Total designs:         15-50 per target
Runtime:               2-8 hours (GPU)
```

### Scaling

```python
# Calculate resources needed
n_targets = 5
pockets_per_target = 3
designs_per_pocket = 6
total_designs = n_targets * pockets_per_target * designs_per_pocket

print(f"Total designs: {total_designs}")
print(f"With 1 GPU (~10 min/design): {total_designs * 10 / 60:.1f} hours")
print(f"With 4 GPUs: {total_designs * 10 / 60 / 4:.1f} hours")
```

## :material-alert-circle: Limitations

!!! warning "Important Considerations"
    - P2Rank predictions are computational estimates
    - Not all predicted pockets are functionally relevant
    - High scores don't guarantee biological activity
    - Always validate with experimental data
    - Consider structural dynamics and flexibility

### Best Results When:

✅ High-quality crystal structures  
✅ Protein surface accessible  
✅ Clear pocket geometry  
✅ Similar proteins in training set

### Use Caution With:

⚠️ Low-resolution structures  
⚠️ Highly flexible regions  
⚠️ Membrane proteins  
⚠️ Large solvent channels

## :material-book-open: References

!!! quote "P2Rank Citation"
    **P2Rank: machine learning based tool for rapid and accurate prediction of ligand binding sites from protein structure**  
    Krivák R, Hoksza D. Journal of Cheminformatics (2018)  
    [doi:10.1186/s13321-018-0285-8](https://doi.org/10.1186/s13321-018-0285-8)

## :material-arrow-right: Next Steps

- Compare with [Design Mode](design-mode.md) for known sites
- See [Target Mode](target-mode.md) for systematic exploration
- Learn about [PRODIGY](../analysis/prodigy.md) for validation

---

!!! tip "Workflow Combination"
    Use P2Rank mode for discovery, then refine promising pockets with Design mode for optimized binders.
