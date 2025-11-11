# P2Rank Mode Quick Start Guide

Get started with automatic binding site prediction and design in 5 minutes!

## Prerequisites

- Nextflow (≥23.04.0)
- Docker or Singularity
- GPU with CUDA support
- Target protein structure (PDB or CIF format)

## Step 1: Prepare Your Target Structure

Have your protein structure ready in PDB or CIF format:

```bash
/data/
└── my_protein.pdb
```

**Tips:**
- Clean structure (remove ligands/water if needed)
- Correct chain IDs
- Standard amino acids

## Step 2: Create Samplesheet

Create `samplesheet.csv`:

```csv
sample_id,target_structure,use_p2rank,top_n_pockets,min_pocket_score,design_type
my_target,/data/my_protein.pdb,true,3,0.5,protein
```

**Columns explained:**
- `sample_id`: Your target name
- `target_structure`: Full path to PDB/CIF file
- `use_p2rank`: Set to `true` to enable P2Rank
- `top_n_pockets`: How many pockets to target (e.g., 3)
- `min_pocket_score`: Minimum confidence threshold (0.5 recommended)
- `design_type`: `protein`, `peptide`, or `nanobody`

## Step 3: Run Pipeline

```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --input samplesheet.csv \
    --use_p2rank \
    --outdir results
```

That's it! The pipeline will:
1. ✅ Run P2Rank to identify binding sites (~1 second)
2. ✅ Generate Boltz2 design specifications (one per pocket)
3. ✅ Design binding partners for each pocket
4. ✅ Rank and output final designs

## Step 4: Check Results

```bash
results/
├── my_target/
│   ├── p2rank_predictions/          # P2Rank identified pockets
│   │   ├── my_target.pdb_predictions.csv   # Ranked pockets with scores
│   │   └── my_target.pdb_residues.csv      # Per-residue pocket info
│   ├── boltz2_designs/
│   │   ├── pocket_summary.txt              # Human-readable summary
│   │   └── design_variants/                # Generated YAML specs
│   └── my_target_pocket1_rank1/            # Boltzgen results for pocket 1
│       └── predictions/
│           └── final_ranked_designs/       # Your designed binders!
```

## Quick Review Workflow

### 1. Check P2Rank Predictions

```bash
cat results/my_target/boltz2_designs/pocket_summary.txt
```

Look for:
- **Score > 0.7**: High-confidence pockets
- **Score 0.5-0.7**: Good pockets
- **Score < 0.5**: Lower confidence

### 2. Visualize Top Designs

Open in PyMOL:
```bash
pymol results/my_target/my_target_pocket1_rank1/predictions/final_ranked_designs/*.cif
```

### 3. Check Design Metrics

Review Boltzgen output:
```bash
cat results/my_target/my_target_pocket1_rank1/predictions/final_ranked_designs/ranking.txt
```

## Common Use Cases

### Drug Discovery: Find Druggable Pockets

```csv
sample_id,target_structure,use_p2rank,top_n_pockets,min_pocket_score,design_type
kinase,/data/kinase.pdb,true,3,0.7,protein
```

High threshold (0.7) focuses on most confident sites.

### Peptide Binders: Small Molecule Alternative

```csv
sample_id,target_structure,use_p2rank,top_n_pockets,min_pocket_score,design_type,min_length,max_length
target,/data/protein.pdb,true,5,0.5,peptide,10,30
```

Peptides (10-30 residues) for more sites (top 5).

### Nanobody Design: Therapeutic Antibodies

```csv
sample_id,target_structure,use_p2rank,top_n_pockets,min_pocket_score,design_type,min_length,max_length
antigen,/data/antigen.pdb,true,2,0.6,nanobody,110,130
```

Nanobody-specific design (110-130 residues typical).

### High-Throughput Screening: Many Targets

```csv
sample_id,target_structure,use_p2rank,top_n_pockets,min_pocket_score,design_type
target_1,/data/target1.pdb,true,3,0.5,protein
target_2,/data/target2.pdb,true,3,0.5,protein
target_3,/data/target3.pdb,true,3,0.5,protein
target_4,/data/target4.pdb,true,3,0.5,protein
target_5,/data/target5.pdb,true,3,0.5,protein
```

Process multiple targets in parallel automatically.

## Adjusting Parameters

### More Pockets per Target

```bash
--top_n_pockets 5
```

Explores more binding sites (computational cost increases).

### Lower Confidence Threshold

```bash
--min_pocket_score 0.3
```

Includes lower-confidence pockets (more exploratory).

### Larger/Smaller Designs

```bash
--min_design_length 30 --max_design_length 80
```

Adjust binder size range as needed.

### Production-Scale Designs

```bash
--num_designs 20000 --budget 50
```

More designs = better quality (but slower):
- `num_designs`: 10,000-60,000 for production
- `budget`: 10-50 final designs

## Troubleshooting

### "No pockets found"

**Solution:** Lower the threshold
```bash
--min_pocket_score 0.3
```

### "Designs look poor"

**Solution:** Increase sampling
```bash
--num_designs 20000 --budget 50
```

### "P2Rank failed"

**Check:**
- Is structure file valid PDB/CIF?
- Does it have coordinates?
- Are chains properly labeled?

### "Out of memory"

**Solution:** Reduce parallelization
```bash
--max_cpus 8 --max_gpus 1
```

## Next Steps

1. **Evaluate designs**: Enable IPSAE scoring
   ```bash
   --run_ipsae
   ```

2. **Optimize best hits**: Focus on top pockets
   ```bash
   --top_n_pockets 1 --num_designs 50000
   ```

3. **Experimental validation**: Test top designs in lab

4. **Iterate**: Adjust parameters based on results

## Full Documentation

- [Complete P2Rank Mode Guide](P2RANK_MODE.md)
- [Parameter Reference](../USAGE.md)
- [Design Specification Format](../README.md#design-specification-format)
- [Boltzgen Documentation](https://boltz.mlsb.io/)

## Example Command with All Options

```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --input samplesheet.csv \
    --use_p2rank \
    --top_n_pockets 3 \
    --min_pocket_score 0.5 \
    --design_type protein \
    --min_design_length 50 \
    --max_design_length 150 \
    --num_designs 20000 \
    --budget 30 \
    --run_ipsae \
    --outdir results \
    --max_cpus 16 \
    --max_gpus 1
```

## Questions?

Check the [full documentation](P2RANK_MODE.md) or open an issue on GitHub!
