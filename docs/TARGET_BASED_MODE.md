# Target Mode - Design Generation

## Overview

Target mode allows you to start with a target structure (e.g., a protein you want to bind to) and automatically generate multiple diversified design specifications. This mode is part of the unified PROTEIN_DESIGN workflow.

The pipeline will:

1. **Generate Design Variants**: Create multiple YAML design files with different parameters (length, composition, etc.)
2. **Enter Unified Workflow**: All designs proceed through the same execution path
3. **Run Boltzgen in Parallel**: Execute all designs simultaneously on available GPU resources
4. **Collect Results**: Organize outputs for easy comparison and analysis

## Workflow Diagram

```
Target Structure (PDB/CIF)
         ↓
   [Mode Selection: TARGET]
         ↓
   GENERATE_DESIGN_VARIANTS
   (Creates N design YAMLs)
         ↓
   [Unified Workflow Entry]
         ↓
   ┌─────┴─────┬─────────┬─────────┐
   ↓           ↓         ↓         ↓
Design 1   Design 2  Design 3  ... Design N
   ↓           ↓         ↓         ↓
BOLTZGEN   BOLTZGEN  BOLTZGEN  ... BOLTZGEN
(Parallel execution on available GPUs)
   ↓           ↓         ↓         ↓
   └─────┬─────┴─────────┴─────────┘
         ↓
    [IPSAE Scoring - Optional]
         ↓
    Results Collection
```

## Input Samplesheet Format

Create a CSV file with the following columns:

| Column | Required | Description | Example |
|--------|----------|-------------|---------|
| `sample_id` | ✅ | Unique identifier for this target | `my_target_protein` |
| `target_structure` | ✅ | Path to target PDB/CIF file | `data/target.cif` |
| `target_chain_ids` | ❌ | Comma-separated chain IDs to use as target | `A` or `A,B` |
| `min_length` | ❌ | Minimum length for designed binder | `50` |
| `max_length` | ❌ | Maximum length for designed binder | `150` |
| `length_step` | ❌ | Step size between length variants | `20` |
| `n_variants_per_length` | ❌ | Number of variants per length | `3` |
| `design_type` | ❌ | Type: `protein`, `peptide`, or `nanobody` | `protein` |
| `protocol` | ❌ | Boltzgen protocol | `protein-anything` |
| `num_designs` | ❌ | Number of intermediate designs | `100` |
| `budget` | ❌ | Number of final ranked designs | `10` |

### Example Samplesheet

```csv
sample_id,target_structure,target_chain_ids,min_length,max_length,length_step,n_variants_per_length,design_type,protocol,num_designs,budget
egfr_binder,data/egfr.cif,A,60,120,20,3,protein,protein-anything,100,10
il6_peptide,data/il6.pdb,A,20,40,10,2,peptide,peptide-anything,100,10
```

This example will generate:
- **EGFR binder**: 4 length variants (60, 80, 100, 120) × 3 variants each = **12 designs**
- **IL6 peptide**: 3 length variants (20, 30, 40) × 2 variants each = **6 designs**
- **Total**: 18 parallel Boltzgen runs

## Design Variant Generation Strategy

The `GENERATE_DESIGN_VARIANTS` process creates diversified designs using several strategies:

### 1. Length Variation
- Generates designs across specified length range
- Step size controls granularity
- Each length gets multiple variants

### 2. Sequence Length Ranges
- **Proteins**: Uses ranges (e.g., 60..80 residues) to give Boltzgen flexibility
- **Peptides**: Uses exact lengths for more precise control
- **Nanobodies**: Uses narrow ranges around target length

### 3. Compositional Diversity (Coming Soon)
Different variants at the same length can have:
- Different secondary structure preferences
- Different compactness requirements
- Different interface specifications

## Usage Examples

### Example 1: Protein Binder Design

Design protein binders of various sizes:

```bash
# Explicit mode specification (recommended)
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --mode target \
    --input target_samplesheet.csv \
    --outdir results

# Auto-detection (if samplesheet has target_structure column)
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --input target_samplesheet.csv \
    --min_design_length 60 \
    --max_design_length 140 \
    --length_step 20 \
    --n_variants_per_length 5 \
    --design_type protein \
    --num_designs 1000 \
    --budget 20 \
    --outdir results/protein_binders
```

This will generate designs at lengths: 60, 80, 100, 120, 140 (5 variants each = 25 total designs)

### Example 2: Peptide Binder Screening

Design peptide binders with shorter lengths:

```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --input peptide_targets.csv \
    --min_design_length 15 \
    --max_design_length 40 \
    --length_step 5 \
    --n_variants_per_length 3 \
    --design_type peptide \
    --protocol peptide-anything \
    --num_designs 500 \
    --budget 15 \
    --outdir results/peptide_screen
```

### Example 3: Nanobody Design

Design nanobodies (typically ~110-130 residues):

```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --input nanobody_targets.csv \
    --min_design_length 110 \
    --max_design_length 130 \
    --length_step 10 \
    --n_variants_per_length 3 \
    --design_type nanobody \
    --protocol nanobody-anything \
    --num_designs 1000 \
    --budget 10 \
    --outdir results/nanobodies
```

## Output Structure

```
results/
└── my_target_protein/
    ├── design_variants/              # Generated YAML files
    │   ├── my_target_protein_len60_v1.yaml
    │   ├── my_target_protein_len60_v2.yaml
    │   ├── my_target_protein_len80_v1.yaml
    │   └── ...
    ├── design_info.txt               # Summary of generated designs
    ├── my_target_protein_len60_v1/   # Boltzgen output for each design
    │   ├── intermediate_designs/
    │   ├── intermediate_designs_inverse_folded/
    │   ├── final_ranked_designs/
    │   └── predictions/
    ├── my_target_protein_len60_v2/
    └── ...
```

## Parameter Tuning Guide

### For Initial Exploration
```bash
--min_design_length 50
--max_design_length 150
--length_step 25
--n_variants_per_length 2
--num_designs 100
--budget 10
```
Generates: ~10 designs, fast runtime

### For Comprehensive Screening
```bash
--min_design_length 40
--max_design_length 160
--length_step 20
--n_variants_per_length 5
--num_designs 10000
--budget 50
```
Generates: ~30 designs, production quality

### For Production/Publication
```bash
--min_design_length 50
--max_design_length 150
--length_step 10
--n_variants_per_length 10
--num_designs 60000
--budget 100
```
Generates: ~100 designs, high quality, long runtime

## GPU Resource Considerations

Each design runs independently, so:
- **1 GPU**: Designs run sequentially (slower but reliable)
- **4 GPUs**: Up to 4 designs run in parallel (4× faster)
- **8 GPUs**: Up to 8 designs run in parallel (8× faster)

Configure in your compute environment or profile:
```groovy
process {
    withLabel: 'process_high_gpu' {
        maxForks = 4  // Limit to 4 parallel GPU jobs
    }
}
```

## Comparing to Original Mode

| Feature | Original Mode | Target-Based Mode |
|---------|---------------|-------------------|
| Input | Pre-made YAML files | Target structure only |
| Design generation | Manual | Automatic |
| Number of designs | Fixed | Configurable (length × variants) |
| Diversification | Manual editing | Automatic |
| Use case | Specific designs | Exploration/screening |
| Setup time | Longer | Faster |

## Best Practices

1. **Start Small**: Begin with 2-3 variants per length to test
2. **Check GPU Memory**: Each design needs ~10-15GB GPU RAM
3. **Use Test Data First**: Validate with small `num_designs` (100) before production runs
4. **Monitor Disk Space**: Each design can generate several GB of output
5. **Review Generated YAMLs**: Check `design_variants/` folder to understand what's being generated

## Troubleshooting

### Too Many Designs Generated
Reduce `n_variants_per_length` or increase `length_step`:
```bash
--length_step 30 --n_variants_per_length 2
```

### Designs Too Similar
Increase variant diversity (future feature) or manually edit generated YAMLs before running

### GPU Out of Memory
Reduce number of parallel jobs or use smaller `num_designs`:
```bash
--num_designs 100
```

## Advanced: Custom Design Templates

You can extend `GENERATE_DESIGN_VARIANTS` to include:
- Custom constraints per variant
- Interface-specific requirements
- Composition preferences
- Symmetry specifications

See `modules/local/generate_design_variants.nf` for implementation details.

## Next Steps

After running target-based mode:
1. Review `design_info.txt` for overview of generated designs
2. Examine results in `final_ranked_designs/` for each variant
3. Use IPSAE scoring (if enabled) to evaluate binding interfaces
4. Select best candidates for experimental validation
5. Refine parameters and re-run with higher `num_designs` and `budget`
