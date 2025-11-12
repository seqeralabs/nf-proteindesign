# PRODIGY Quick Start Guide

## What is PRODIGY?

PRODIGY predicts how strongly your designed protein will bind to its target by calculating:
- **ΔG** (binding free energy): More negative = stronger binding
- **Kd** (dissociation constant): Lower = tighter binding

## Enable PRODIGY (One Command!)

Just add `--run_prodigy` to your existing pipeline command:

```bash
nextflow run main.nf \
  --input samplesheet.csv \
  --run_prodigy \
  --outdir results
```

## Where to Find Results

```
results/
└── your_sample/
    └── prodigy/
        ├── design_1_prodigy_results.txt  ← Full output
        └── design_1_prodigy_summary.csv  ← Easy-to-read metrics
```

## Understanding Your Results

### CSV Summary File

Open `*_prodigy_summary.csv` to see:

| Column | Good Values | What It Means |
|--------|-------------|---------------|
| `predicted_binding_affinity_kcal_mol` | < -10 | Stronger binding (more negative) |
| `predicted_kd_M` | < 1e-8 | Tighter binding (nanomolar range) |
| `buried_surface_area_A2` | 1000-2500 | Contact area between proteins |
| `num_interface_contacts` | 50-150 | Number of residue contacts |

### Quick Interpretation

**Strong Binder:**
```
ΔG: -12.5 kcal/mol
Kd: 3.2e-09 M (3.2 nanomolar)
→ Excellent candidate! 🎉
```

**Weak Binder:**
```
ΔG: -5.2 kcal/mol
Kd: 1.5e-04 M (150 micromolar)
→ May need optimization ⚠️
```

**Moderate Binder:**
```
ΔG: -8.7 kcal/mol
Kd: 4.2e-07 M (420 nanomolar)
→ Decent starting point ✓
```

## Advanced Options

### Specify Chains Manually

If auto-detection doesn't work:

```bash
nextflow run main.nf \
  --input samplesheet.csv \
  --run_prodigy \
  --prodigy_selection 'A,B' \
  --outdir results
```

### Combine with IPSAE

Get both structure confidence AND binding affinity:

```bash
nextflow run main.nf \
  --input samplesheet.csv \
  --run_prodigy \
  --run_ipsae \
  --outdir results
```

## Compare Multiple Designs

Quick Python script to rank designs:

```python
import pandas as pd
import glob

# Load all PRODIGY summaries
files = glob.glob('results/*/prodigy/*_summary.csv')
df = pd.concat([pd.read_csv(f) for f in files])

# Sort by binding affinity (most negative = best)
best = df.sort_values('predicted_binding_affinity_kcal_mol').head(10)

print("Top 10 Binders:")
print(best[['structure_id', 'predicted_binding_affinity_kcal_mol', 'predicted_kd_M']])
```

## Troubleshooting

### No PRODIGY results?

**Check 1:** Did you add `--run_prodigy`?
```bash
# Wrong:
nextflow run main.nf --input samplesheet.csv

# Right:
nextflow run main.nf --input samplesheet.csv --run_prodigy
```

**Check 2:** Are your structures valid protein-protein complexes?
- PRODIGY needs at least 2 protein chains
- Check your CIF files have chains A, B, etc.

### Error: "Chain not found"?

**Solution:** Manually specify chains:
```bash
--prodigy_selection 'A,B'
```

## Next Steps

📚 **Detailed Documentation:** See [PRODIGY_USAGE.md](docs/PRODIGY_USAGE.md)

📊 **Interpreting Results:** Learn about ΔG, Kd, and interface properties

🔬 **Citations:** Remember to cite PRODIGY in your publications!

---

**Need Help?** Check the [full PRODIGY documentation](docs/PRODIGY_USAGE.md) or open an issue on GitHub.
