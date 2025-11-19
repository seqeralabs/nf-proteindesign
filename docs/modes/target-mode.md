# Target Mode

## :material-target: Overview

Target mode automatically generates multiple design variants from target structures, enabling systematic exploration of the design space. Perfect for high-throughput screening and parameter optimization.

!!! success "Best For"
    - Exploring different binder sizes
    - High-throughput design campaigns  
    - Parameter space screening
    - When optimal design parameters are unknown

## :material-auto-fix: Automatic Variant Generation

Target mode creates multiple design YAML files automatically based on your specifications:

- **Length variations**: Test different binder sizes
- **Multiple variants**: Generate diverse designs per configuration
- **Parallel execution**: All designs run simultaneously

### Example: Length Variation

With parameters:
- `min_length`: 60
- `max_length`: 120
- `length_step`: 20
- `n_variants_per_length`: 3

Pipeline generates **12 designs**:
- 60aa (3 variants)
- 80aa (3 variants)
- 100aa (3 variants)
- 120aa (3 variants)

## :material-file-table: Samplesheet Format

### Minimal Format

```csv title="samplesheet_minimal.csv"
sample,target_structure
target1,data/target1.pdb
target2,data/target2.cif
```

### Full Format

```csv title="samplesheet_full.csv"
sample,target_structure,target_residues,chain_type,min_length,max_length
egfr,data/egfr.pdb,"10,11,12,45,46",protein,60,120
spike,data/spike.cif,"417,484,501",nanobody,110,130
il6,data/il6.pdb,"20,21,22",peptide,15,30
```

### Column Descriptions

| Column | Required | Description | Example |
|--------|----------|-------------|---------|
| `sample` | ✅ | Unique identifier | `egfr_design` |
| `target_structure` | ✅ | Target file path | `data/egfr.pdb` |
| `target_residues` | Optional | Binding site | `"10,11,12"` |
| `chain_type` | Optional | Binder type | `protein` |
| `min_length` | Optional | Min length | `60` |
| `max_length` | Optional | Max length | `120` |

## :material-play: Running Target Mode

=== "Basic Run"
    ```bash
    nextflow run FloWuenne/nf-proteindesign-2025 \
        -profile docker \
        --mode target \
        --input samplesheet.csv \
        --outdir results
    ```

=== "Custom Parameters"
    ```bash
    nextflow run FloWuenne/nf-proteindesign-2025 \
        -profile docker \
        --mode target \
        --input samplesheet.csv \
        --outdir results \
        --min_design_length 50 \
        --max_design_length 150 \
        --length_step 20 \
        --n_variants_per_length 5
    ```

=== "With Analysis"
    ```bash
    nextflow run FloWuenne/nf-proteindesign-2025 \
        -profile docker \
        --mode target \
        --input samplesheet.csv \
        --outdir results \
        --run_prodigy \
        --run_ipsae
    ```

## :material-cog: Target Mode Parameters

### Length Parameters

| Parameter | Description | Default | Example |
|-----------|-------------|---------|---------|
| `--min_design_length` | Minimum binder length | 50 | `60` |
| `--max_design_length` | Maximum binder length | 150 | `120` |
| `--length_step` | Length increment | 20 | `10` |

### Variant Parameters

| Parameter | Description | Default | Example |
|-----------|-------------|---------|---------|
| `--n_variants_per_length` | Variants per length | 3 | `5` |
| `--n_samples` | Designs per variant | 10 | `50` |

### Design Parameters

| Parameter | Description | Default | Options |
|-----------|-------------|---------|---------|
| `--chain_type` | Binder type | protein | `protein`, `peptide`, `nanobody` |

## :material-test-tube: Example Workflows

### Example 1: Protein Binder Screening

```bash
# Create samplesheet
cat > protein_targets.csv << EOF
sample,target_structure,target_residues,chain_type
egfr,data/egfr.pdb,"10,11,12,45,46,47",protein
her2,data/her2.pdb,"25,26,27,28,90,91",protein
EOF

# Run with systematic length screening
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --mode target \
    --input protein_targets.csv \
    --min_design_length 60 \
    --max_design_length 140 \
    --length_step 20 \
    --n_variants_per_length 5 \
    --n_samples 30 \
    --outdir protein_binders
```

**Result**: 20 designs per target (4 lengths × 5 variants)

### Example 2: Peptide Library

```bash
# Create samplesheet
cat > peptide_targets.csv << EOF
sample,target_structure,target_residues,chain_type
target1,data/target1.pdb,"10,11,12",peptide
target2,data/target2.pdb,"45,46,47",peptide
EOF

# Run peptide design
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --mode target \
    --input peptide_targets.csv \
    --chain_type peptide \
    --min_design_length 10 \
    --max_design_length 30 \
    --length_step 5 \
    --n_variants_per_length 3 \
    --n_samples 50 \
    --outdir peptide_library
```

**Result**: 15 designs per target (5 lengths × 3 variants)

### Example 3: Nanobody Development

```bash
# Create samplesheet
cat > nanobody_targets.csv << EOF
sample,target_structure,target_residues
covid_spike,data/spike_rbd.pdb,"417,484,501"
influenza_ha,data/ha_head.pdb,"145,156,193"
EOF

# Run nanobody design
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --mode target \
    --input nanobody_targets.csv \
    --chain_type nanobody \
    --min_design_length 110 \
    --max_design_length 130 \
    --length_step 10 \
    --n_variants_per_length 4 \
    --n_samples 40 \
    --run_prodigy \
    --outdir nanobody_designs
```

**Result**: 12 designs per target (3 lengths × 4 variants)

## :material-folder-open: Output Structure

```
results/
└── {sample}/
    ├── design_variants/              # Generated YAML files
    │   ├── {sample}_len60_v1.yaml
    │   ├── {sample}_len60_v2.yaml
    │   ├── {sample}_len80_v1.yaml
    │   └── ...
    ├── design_info.txt              # Summary of variants
    ├── boltzgen/
    │   ├── {sample}_len60_v1/
    │   │   ├── final_ranked_designs/
    │   │   └── ...
    │   ├── {sample}_len80_v1/
    │   └── ...
    └── prodigy/
        └── {sample}_*_summary.csv
```

## :material-chart-line: Analyzing Results

### Compare Across Lengths

```python
import pandas as pd
import matplotlib.pyplot as plt

# Load all PRODIGY results
results = []
for csv in Path('results/egfr/prodigy/').glob('*_summary.csv'):
    df = pd.read_csv(csv)
    # Extract length from filename
    length = int(csv.stem.split('_len')[1].split('_')[0])
    df['length'] = length
    results.append(df)

combined = pd.concat(results)

# Plot affinity vs length
plt.figure(figsize=(10, 6))
combined.boxplot(column='delta_g', by='length')
plt.xlabel('Design Length (aa)')
plt.ylabel('ΔG (kcal/mol)')
plt.title('Binding Affinity vs Design Length')
plt.savefig('length_analysis.png', dpi=300)
```

### Find Optimal Length

```bash
# Find best design per length category
cat results/*/prodigy/*_summary.csv | \
    grep -v "sample_id" | \
    awk -F',' '{print $1,$3}' | \
    sort -k2,2n | \
    awk '{len=substr($1,match($1,/len[0-9]+/),6); print len,$2}' | \
    sort -t' ' -k1,1 -k2,2n | \
    awk '!seen[$1]++ {print}'
```

## :material-lightbulb: Best Practices

### 1. Start With Wide Range

```bash
# Initial screen: wide range, few variants
--min_design_length 50 \
--max_design_length 150 \
--length_step 30 \
--n_variants_per_length 2
```

### 2. Refine Promising Range

```bash
# Focused design: narrow range, more variants
--min_design_length 80 \
--max_design_length 110 \
--length_step 10 \
--n_variants_per_length 5
```

### 3. Production Run

```bash
# Final optimization: optimal length, many samples
--min_design_length 95 \
--max_design_length 105 \
--length_step 5 \
--n_variants_per_length 10 \
--n_samples 100
```

## :material-compare: Target vs Design Mode

| Feature | Target Mode | Design Mode |
|---------|-------------|-------------|
| Setup | Quick (CSV only) | Requires YAML files |
| Variants | Automatic | Manual |
| Control | Parameter-based | YAML-based |
| Exploration | Systematic | Targeted |
| Parallelization | High | Per-sample |

## :material-speedometer: Performance Tips

### Estimate Runtime

```python
# Calculate total designs
lengths = (max_length - min_length) // length_step + 1
total_designs = lengths * n_variants_per_length * n_samples
time_per_sample = 10  # minutes (approximate)

total_time = (total_designs * time_per_sample) / n_parallel_gpus
print(f"Estimated time: {total_time / 60:.1f} hours")
```

### Optimize Parameters

For quick tests:
- `--n_samples 5`
- `--length_step 30`
- `--n_variants_per_length 2`

For production:
- `--n_samples 50`
- `--length_step 10`
- `--n_variants_per_length 5`

## :material-arrow-right: Next Steps

- Compare with [Design Mode](design-mode.md) for precise control
- Learn about [PRODIGY analysis](../analysis/prodigy.md)

---

!!! tip "Combine Modes"
    Use Target mode for initial screening, then Design mode for optimization of promising hits.
