# Quick Test Reference

## Run All Tests

```bash
# Test Design Mode (pre-made YAML configs)
nextflow run main.nf -profile test_design,docker

# Test Target Mode (auto-generate designs from structure)
nextflow run main.nf -profile test_target,docker

# Test P2Rank Mode (binding site prediction + auto-design)
nextflow run main.nf -profile test_p2rank,docker
```

## Test Data Summary

| Mode | Sample Count | Design Types | Key Features |
|------|--------------|--------------|--------------|
| Design | 3 | Protein, Peptide, Nanobody | Pre-made YAML specs |
| Target | 3 | Protein, Peptide, Nanobody | Auto-generated YAMLs with length variants |
| P2Rank | 3 | Protein, Peptide, Nanobody | Binding site prediction + auto-design |

## Target Information

- **Protein**: EGFR (PDB: 1IVO)
- **Target Chain**: A (kinase domain, ~500 residues)
- **Design Types**: All three supported (protein/peptide/nanobody)

## Quick Customization

### Change number of designs:
```bash
nextflow run main.nf -profile test_design,docker --num_designs 20 --budget 5
```

### Use different container engine:
```bash
# Singularity instead of Docker
nextflow run main.nf -profile test_design,singularity

# Conda (slower, not recommended)
nextflow run main.nf -profile test_design,conda
```

### Change output directory:
```bash
nextflow run main.nf -profile test_design,docker --outdir my_test_results
```

### Resume a failed run:
```bash
nextflow run main.nf -profile test_design,docker -resume
```

## Expected Runtime

With test settings (num_designs=10, budget=2):
- **Per sample**: ~5-15 minutes (with GPU)
- **Full profile**: ~15-45 minutes (3 samples, parallel execution)

Production settings (num_designs=10000, budget=10):
- **Per sample**: ~1-6 hours (depending on design complexity)

## Output Structure

```
results_test_*/
├── boltzgen/
│   ├── egfr_*_binder/
│   │   ├── designs/          # Generated structures
│   │   ├── filtering/        # Diversity-optimized final set
│   │   └── logs/
├── design_yamls/              # Auto-generated configs (target/p2rank modes)
├── p2rank/                    # Binding site predictions (p2rank mode only)
└── pipeline_info/             # Execution reports
```

See `TEST_PROFILES.md` for detailed documentation.
