# Quick Reference: Target-Based Mode

## TL;DR

```bash
# Create a simple samplesheet
echo "sample_id,target_structure" > input.csv
echo "my_target,path/to/target.cif" >> input.csv

# Run the pipeline
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --input input.csv \
    --outdir results
```

That's it! The pipeline will automatically generate and run multiple design variants.

---

## Samplesheet Quick Create

### Minimal (uses all defaults)
```bash
cat > input.csv << EOF
sample_id,target_structure
target1,data/target1.cif
target2,data/target2.pdb
EOF
```

### With Custom Parameters
```bash
cat > input.csv << EOF
sample_id,target_structure,min_length,max_length,design_type
target1,data/target1.cif,60,120,protein
target2,data/target2.pdb,20,40,peptide
EOF
```

### Full Control
```bash
cat > input.csv << EOF
sample_id,target_structure,target_chain_ids,min_length,max_length,length_step,n_variants_per_length,design_type,protocol,num_designs,budget
egfr,data/egfr.cif,A,60,140,20,5,protein,protein-anything,1000,20
il6,data/il6.pdb,"A,B",15,35,10,3,peptide,peptide-anything,500,15
EOF
```

---

## Command Templates

### Quick Test (Fast)
```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --input input.csv \
    --min_design_length 60 \
    --max_design_length 100 \
    --length_step 20 \
    --n_variants_per_length 2 \
    --num_designs 100 \
    --budget 5 \
    --outdir results/test
```
→ Generates 6 designs (3 lengths × 2 variants)

### Standard Run (Balanced)
```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --input input.csv \
    --min_design_length 50 \
    --max_design_length 150 \
    --length_step 20 \
    --n_variants_per_length 3 \
    --num_designs 1000 \
    --budget 20 \
    --outdir results/standard
```
→ Generates 18 designs (6 lengths × 3 variants)

### Production (High Quality)
```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --input input.csv \
    --min_design_length 50 \
    --max_design_length 150 \
    --length_step 10 \
    --n_variants_per_length 5 \
    --num_designs 10000 \
    --budget 50 \
    --outdir results/production
```
→ Generates 55 designs (11 lengths × 5 variants)

### Peptide Screening
```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --input input.csv \
    --min_design_length 15 \
    --max_design_length 40 \
    --length_step 5 \
    --n_variants_per_length 3 \
    --design_type peptide \
    --protocol peptide-anything \
    --num_designs 500 \
    --budget 15 \
    --outdir results/peptides
```
→ Generates 18 designs (6 lengths × 3 variants)

---

## Parameter Cheat Sheet

| Parameter | Values | What it does |
|-----------|--------|--------------|
| `min_design_length` | 10-200 | Shortest binder to try |
| `max_design_length` | 10-200 | Longest binder to try |
| `length_step` | 5-50 | Jump between sizes |
| `n_variants_per_length` | 1-10 | How many tries per size |
| `design_type` | protein/peptide/nanobody | What to design |
| `protocol` | See below | Boltzgen protocol |
| `num_designs` | 10-60000 | Intermediate designs |
| `budget` | 5-100 | Final ranked designs |

### Protocols
- `protein-anything`: General protein binders
- `peptide-anything`: Peptide binders
- `nanobody-anything`: Nanobody designs
- `protein-small_molecule`: Protein + small molecule

---

## Design Count Calculator

**Formula**: `(max - min) / step + 1` × `n_variants_per_length`

### Examples

| min | max | step | variants | = designs |
|-----|-----|------|----------|-----------|
| 50  | 150 | 20   | 3        | 6 × 3 = **18** |
| 60  | 120 | 30   | 2        | 3 × 2 = **6** |
| 40  | 160 | 10   | 5        | 13 × 5 = **65** |
| 15  | 40  | 5    | 3        | 6 × 3 = **18** |

---

## Resource Calculator

### Time Estimates (per design)

| num_designs | GPUs | Time |
|-------------|------|------|
| 100         | 1    | ~15 min |
| 1,000       | 1    | ~1 hour |
| 10,000      | 1    | ~4 hours |
| 100         | 4    | ~4 min |
| 10,000      | 4    | ~1 hour |

### Disk Space (per design)
- **Intermediate designs**: ~1-2 GB
- **Final designs**: ~500 MB - 1 GB
- **Predictions**: ~1-3 GB
- **Total per design**: ~2-5 GB

### GPU Memory
- **Per design**: ~10-15 GB
- **Recommendation**: NVIDIA A100 (40GB) or V100 (32GB)

---

## Output Navigation

```
results/
└── {sample_id}/
    ├── design_variants/              ← Generated YAML files
    │   ├── {sample}_len{X}_v1.yaml
    │   ├── {sample}_len{X}_v2.yaml
    │   └── ...
    ├── design_info.txt               ← Summary of all designs
    ├── {sample}_len{X}_v1/           ← Boltzgen results per design
    │   ├── intermediate_designs/      ← All generated designs
    │   ├── intermediate_designs_inverse_folded/  ← With sequences
    │   ├── final_ranked_designs/      ← ⭐ Best designs (start here!)
    │   └── predictions/               ← Structure predictions
    └── {sample}_len{X}_v2/
        └── ...
```

**👉 Start here**: `results/{sample_id}/*/final_ranked_designs/`

---

## Common Scenarios

### "I want to explore different binder sizes"
```bash
--min_design_length 50 \
--max_design_length 150 \
--length_step 25 \
--n_variants_per_length 3
```
→ Tests 5 sizes with 3 tries each

### "I want many designs fast"
```bash
--length_step 30 \          # Fewer sizes
--n_variants_per_length 1 \  # One try per size
--num_designs 100 \          # Quick generation
--budget 5                   # Few final designs
```
→ Fast exploration

### "I want high-quality results"
```bash
--length_step 10 \           # More sizes
--n_variants_per_length 5 \  # Multiple tries
--num_designs 10000 \        # Many intermediates
--budget 50                  # Many final designs
```
→ Production quality

### "I'm designing peptides"
```bash
--min_design_length 15 \
--max_design_length 35 \
--length_step 5 \
--design_type peptide \
--protocol peptide-anything
```

### "I'm designing nanobodies"
```bash
--min_design_length 110 \
--max_design_length 130 \
--length_step 10 \
--design_type nanobody \
--protocol nanobody-anything
```

---

## Profiles

### Docker (Recommended)
```bash
-profile docker
```
Requires: Docker with GPU support

### Singularity
```bash
-profile singularity
```
Requires: Singularity/Apptainer with GPU support

### Test
```bash
-profile test,docker
```
Runs with minimal test data

---

## Troubleshooting Quick Fixes

### "Too many designs!"
```bash
# Reduce:
--length_step 30           # Bigger steps = fewer sizes
--n_variants_per_length 1  # Fewer variants
```

### "GPU out of memory"
```bash
# Add to config:
process.maxForks = 1       # One design at a time
# OR reduce:
--num_designs 100          # Smaller runs
```

### "Taking too long"
```bash
# Speed up:
--num_designs 100          # Faster generation
--budget 5                 # Fewer final designs
--length_step 30           # Fewer sizes
```

### "Disk space running out"
```bash
# Clean intermediate files:
nextflow clean -f
# OR reduce:
--n_variants_per_length 2  # Fewer designs
```

---

## One-Liners

### Resume failed run
```bash
nextflow run FloWuenne/nf-proteindesign-2025 -profile docker --input input.csv -resume
```

### Check what will run (dry-run)
```bash
nextflow run FloWuenne/nf-proteindesign-2025 -profile docker --input input.csv -stub-run
```

### Generate report
```bash
# After run completes, check:
results/pipeline_info/execution_report_*.html
```

### Clean work directory
```bash
nextflow clean -f
```

---

## File Locations

| File | Path |
|------|------|
| Input samplesheet | `input.csv` (you create) |
| Example samplesheet | `assets/target_samplesheet_example.csv` |
| Example designs | `assets/design_examples/*.yaml` |
| Results | `results/` (or `--outdir`) |
| Pipeline info | `results/pipeline_info/` |
| Generated YAMLs | `results/{sample}/design_variants/` |
| Best designs | `results/{sample}/*/final_ranked_designs/` |

---

## Getting Help

### Check pipeline version
```bash
nextflow run FloWuenne/nf-proteindesign-2025 --version
```

### View help message
```bash
nextflow run FloWuenne/nf-proteindesign-2025 --help
```

### Documentation
- **Pipeline docs**: `docs/` directory
- **Detailed guide**: `docs/TARGET_BASED_MODE.md`
- **Mode comparison**: `docs/WORKFLOW_MODES.md`
- **Boltzgen docs**: https://github.com/HannesStark/boltzgen

---

## Example Workflow

```bash
# 1. Create samplesheet
echo "sample_id,target_structure" > input.csv
echo "my_protein,data/target.cif" >> input.csv

# 2. Test run (fast)
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --input input.csv \
    --num_designs 100 \
    --budget 5 \
    --outdir results/test

# 3. Check results
ls results/my_protein/*/final_ranked_designs/

# 4. Looks good? Run production
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --input input.csv \
    --num_designs 10000 \
    --budget 50 \
    --outdir results/production

# 5. Analyze results
# Check: results/production/my_protein/*/final_ranked_designs/
```

---

## Pro Tips

💡 **Start small**: Use `num_designs=100` and `budget=5` for initial testing

💡 **Use resume**: Add `-resume` to continue from last successful step

💡 **Check generated YAMLs**: Look in `design_variants/` to see what's being designed

💡 **Multiple targets**: Add rows to samplesheet - they run in parallel

💡 **GPU limits**: Set `process.maxForks` to match your GPU count

💡 **Disk space**: Each design needs ~3-5 GB, plan accordingly

💡 **Time estimate**: ~1 hour per design for `num_designs=1000`

---

## Quick Comparison: Target vs Design Mode

| Aspect | Target Mode | Design Mode |
|--------|-------------|-------------|
| Input | PDB/CIF file | YAML files |
| Setup | 1 CSV line | Write YAMLs |
| Control | Parameters | Full spec |
| Designs | Auto-generated | Pre-defined |
| Use case | Exploration | Specific goals |

**How to choose**: 
- Don't know what you need → **Target mode**
- Know exactly what you need → **Design mode**

---

This quick reference covers 90% of common use cases. For detailed information, see the full documentation in the `docs/` directory.
