# P2Rank-Based Binding Site Prediction Mode

## Overview

The P2Rank mode uses machine learning to automatically identify potential binding sites in target protein structures, then generates Boltzgen design specifications to create binding partners for those sites.

This approach is ideal when you want to:
- Design binding partners without prior knowledge of binding sites
- Target druggable pockets identified by computational prediction
- Generate designs for multiple predicted binding sites simultaneously
- Leverage state-of-the-art binding site prediction (P2Rank)

## What is P2Rank?

[P2Rank](https://github.com/rdk/p2rank) is a fast, accurate machine learning tool for predicting ligand-binding sites from protein structures. It:

- **Fast**: <1 second per protein on typical hardware
- **Accurate**: High prediction success rates on benchmarks
- **Stand-alone**: No external databases or templates required
- **Well-validated**: Widely cited in the literature (600+ citations)

P2Rank identifies binding pockets by scoring points on the protein's solvent-accessible surface using a machine learning model trained on known protein-ligand complexes.

## Workflow

P2Rank mode is part of the unified PROTEIN_DESIGN workflow:

```
Input: Target Protein Structure (PDB/CIF)
    ↓
[Mode Selection: P2RANK]
    ↓
[P2RANK_PREDICT] - Identify binding sites
    ↓
Predicted Binding Sites (ranked, scored, with residues)
    ↓
[FORMAT_BINDING_SITES] - Convert to design YAMLs
    ↓
Boltz2 Design YAMLs (one per pocket)
    ↓
[Unified Workflow Entry Point]
    ↓
[BOLTZGEN_RUN] - Generate designs in parallel
    ↓
[IPSAE_CALCULATE] - Optional scoring
    ↓
Designed Binding Partners
```

## Usage

### 1. Enable P2Rank Mode

Specify P2Rank mode explicitly or enable via parameter:

**Option A: Explicit mode (Recommended):**
```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --mode p2rank \
    --input targets.csv \
    --top_n_pockets 3 \
    --outdir results
```

**Option B: Via --use_p2rank parameter:**
```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
  --input samplesheet.csv \
  --use_p2rank \
  --outdir results
```

**Via nextflow.config:**
```groovy
params {
    use_p2rank = true
}
```

### 2. Prepare Samplesheet

Use the **target-based** samplesheet format with P2Rank-specific columns:

```csv
sample_id,target_structure,use_p2rank,top_n_pockets,min_pocket_score,design_type,min_length,max_length
protein1,/path/to/protein1.pdb,true,3,0.5,protein,50,150
protein2,/path/to/protein2.cif,true,5,0.3,nanobody,100,130
```

**Required columns:**
- `sample_id`: Unique identifier for the target
- `target_structure`: Path to PDB/CIF file

**P2Rank-specific columns (optional):**
- `use_p2rank`: `true` to enable P2Rank for this sample (overrides global param)
- `top_n_pockets`: Number of top-scoring pockets to design for (default: 3)
- `min_pocket_score`: Minimum P2Rank score threshold (default: 0.5)
- `binding_region_mode`: `residues` or `bounding_box` (default: `residues`)
- `expand_region`: Expand binding region by N residues (default: 5)

**Design parameters (optional):**
- `design_type`: `protein`, `peptide`, or `nanobody` (default: `protein`)
- `min_length`: Minimum length of designed binder (default: 50)
- `max_length`: Maximum length of designed binder (default: 150)

**Boltzgen parameters (optional):**
- `protocol`: Boltzgen protocol (default: `protein-anything`)
- `num_designs`: Number of designs to generate (default: 100)
- `budget`: Final diversity-optimized set size (default: 10)

### 3. Run Pipeline

```bash
nextflow run main.nf \
  --input samplesheet.csv \
  --use_p2rank \
  --top_n_pockets 3 \
  --min_pocket_score 0.5 \
  --design_type protein \
  --outdir results \
  -profile docker
```

## Parameters

### P2Rank Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `use_p2rank` | `false` | Enable P2Rank-based binding site prediction |
| `top_n_pockets` | `3` | Number of top-scoring pockets to target |
| `min_pocket_score` | `0.5` | Minimum P2Rank score (0-1 scale, higher = more confident) |
| `binding_region_mode` | `'residues'` | How to specify binding regions: `'residues'` or `'bounding_box'` |
| `expand_region` | `5` | Expand binding region by N residues around predicted pocket |

### P2Rank Score Interpretation

- **Score > 0.8**: High-confidence binding pocket, very likely druggable
- **Score 0.5-0.8**: Medium-confidence pocket, good candidate
- **Score < 0.5**: Lower-confidence pocket, may be worth exploring

Typical protein structures have 5-15 predicted pockets. Using `top_n_pockets=3` with `min_pocket_score=0.5` will focus on the most promising sites.

### Binding Region Modes

**`residues` mode (recommended):**
- Specifies exact binding residues identified by P2Rank
- More precise targeting of binding interface
- Suitable for most applications

**`bounding_box` mode:**
- Defines 3D bounding box around binding residues
- More flexible spatial constraints
- Useful for large, complex binding sites

### Region Expansion

The `expand_region` parameter adds neighboring residues to the binding site definition:
- **expand_region=0**: Use only P2Rank-predicted residues
- **expand_region=5** (default): Include ±5 residues in sequence
- **expand_region=10**: More generous definition for larger interfaces

## Output Files

### Per-Sample Outputs

```
results/
├── {sample_id}/
│   ├── p2rank_predictions/
│   │   ├── {sample_id}.pdb_predictions.csv    # Ranked pocket predictions
│   │   ├── {sample_id}.pdb_residues.csv       # Per-residue pocket scores
│   │   └── visualizations/                    # Optional PyMOL/ChimeraX files
│   ├── boltz2_designs/
│   │   ├── design_variants/
│   │   │   ├── {sample_id}_pocket1_rank1.yaml # Design YAML for pocket 1
│   │   │   ├── {sample_id}_pocket2_rank2.yaml # Design YAML for pocket 2
│   │   │   └── {sample_id}_pocket3_rank3.yaml # Design YAML for pocket 3
│   │   ├── design_info.txt                    # Summary of generated designs
│   │   └── pocket_summary.txt                 # P2Rank predictions summary
│   └── {design_id}/
│       └── predictions/                       # Boltzgen outputs per design
```

### Key Files

**`{sample_id}.pdb_predictions.csv`** - P2Rank pocket predictions:
```
rank,name,score,probability,center_x,center_y,center_z,residue_ids
1,pocket1,0.856,0.921,12.3,45.6,78.9,A_123 A_124 A_125 B_67 B_68
2,pocket2,0.742,0.834,23.4,56.7,89.0,A_200 A_201 C_45
```

**`pocket_summary.txt`** - Human-readable summary:
```
# P2Rank Binding Site Predictions
# Target: protein1.pdb
# Total pockets found: 12
# Selected pockets: 3
# Score threshold: 0.5

rank    name        score   probability   center                  residue_count
1       pocket1     0.856   0.921        (12.3, 45.6, 78.9)      45
2       pocket2     0.742   0.834        (23.4, 56.7, 89.0)      32
3       pocket3     0.621   0.705        (34.5, 67.8, 90.1)      28
```

**`design_info.txt`** - Design specifications created:
```
# Generated 3 Boltz2 design specifications from P2Rank predictions
# Target: protein1.pdb
# Binding region mode: residues
# Expand region: 5 residues
# Design type: protein
# Design length range: 50-150

design_id                      yaml_file                              pocket_info    score   binding_chains
protein1_pocket1_rank1         design_variants/protein1_pocket1...    pocket:pocket1 0.856   A:45_res, B:12_res
protein1_pocket2_rank2         design_variants/protein1_pocket2...    pocket:pocket2 0.742   A:32_res
```

## Example Boltz2 YAML Output

Here's what a P2Rank-generated design YAML looks like:

```yaml
entities:
  - protein:
      id: A
      file:
        path: protein1.pdb
        chain: A
      binding_residues: [118, 119, 120, 121, 122, 123, 124, 125, 126, 127, 128]
  - protein:
      id: B
      file:
        path: protein1.pdb
        chain: B
      binding_residues: [62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72]
  - protein:
      id: BINDER
      sequence: "50..150"

constraints:
  target_binding_site:
    center: [12.3, 45.6, 78.9]
    radius: 15.0
```

This specification tells Boltz2 to:
1. Include chains A and B from the target structure
2. Mark specific residues as part of the binding interface
3. Design a protein binder (50-150 residues)
4. Target the spatial region around the predicted pocket center

## Best Practices

### 1. Choose Appropriate Thresholds

- **For drug discovery**: `min_pocket_score=0.6`, `top_n_pockets=3` (focus on best sites)
- **For exploration**: `min_pocket_score=0.3`, `top_n_pockets=5` (broader coverage)
- **For specific sites**: Manually inspect P2Rank output first, then filter

### 2. Design Type Selection

- **Protein binders**: General purpose, `design_type=protein`
- **Peptide binders**: Small interfaces, `design_type=peptide`, `min_length=10`, `max_length=30`
- **Nanobodies**: Antibody-like, `design_type=nanobody`, `min_length=110`, `max_length=130`

### 3. Computational Resources

P2Rank is fast (seconds per protein), but generates multiple designs:
- **3 pockets × 100 designs × 10 budget = 3000 final structures**
- Scale `num_designs` and `budget` based on available compute
- Use `--max_cpus` and `--max_gpus` to control parallelization

### 4. Validation

After design generation:
1. Check `pocket_summary.txt` for P2Rank predictions
2. Review `design_info.txt` for binding site definitions
3. Visualize top designs with PyMOL/ChimeraX
4. Run IPSAE scoring with `--run_ipsae` to evaluate predicted interactions

## Troubleshooting

### "No pockets found above threshold"

- Lower `min_pocket_score` (try 0.3 or 0.2)
- Check if protein structure is valid (correct format, coordinates present)
- Some proteins genuinely lack obvious binding pockets

### "P2Rank predictions look wrong"

- Ensure protein structure has correct chains/residues
- P2Rank works best with clean structures (remove ligands, water if interfering)
- Try different `binding_region_mode` or `expand_region` values

### "Designs don't converge"

- Check if binding site is too large/complex
- Reduce `max_length` for smaller, more focused binders
- Increase `num_designs` for better sampling
- Review Boltzgen logs in `{design_id}/boltzgen.log`

## Comparison: P2Rank vs. Manual Design Generation

| Feature | P2Rank Mode | Manual Mode |
|---------|-------------|-------------|
| **Binding site identification** | Automatic | User-specified |
| **Knowledge required** | Minimal | Requires domain expertise |
| **Speed** | Fast (<1s per protein) | Depends on analysis time |
| **Druggability focus** | Yes (ML-predicted) | Depends on user selection |
| **Multiple sites** | Automatic (top N) | Must specify each manually |
| **Reproducibility** | High (standardized) | Varies by user |

**Use P2Rank when:**
- You don't know where binding sites are
- You want unbiased pocket identification
- You're screening many targets

**Use manual mode when:**
- You know the exact binding site
- You want to target a specific region (e.g., allosteric site)
- You have experimental binding data

## Advanced: Custom P2Rank Configuration

For advanced users, you can customize P2Rank behavior by modifying the process in `modules/local/p2rank_predict.nf`:

```groovy
process P2RANK_PREDICT {
    // Add custom P2Rank arguments
    script:
    def args = task.ext.args ?: '-c rescore_2024'  // Use 2024 rescoring model
    
    """
    prank predict \\
        -f ${protein_structure} \\
        -threads ${task.cpus} \\
        ${args}
    """
}
```

Useful P2Rank options:
- `-c rescore_2024`: New model for AlphaFold/cryo-EM structures
- `-c alphafold`: Optimized for AlphaFold predictions
- `-threads N`: Control parallelization

## References

1. **P2Rank**: Krivák, R. & Hoksza, D. (2018). P2Rank: machine learning based tool for rapid and accurate prediction of ligand binding sites from protein structure. *Journal of Cheminformatics*, 10, 39.

2. **Binding site prediction review**: Xia, Y., Pan, X., & Shen, H.-B. (2024). A comprehensive survey on protein-ligand binding site prediction. *Current Opinion in Structural Biology*, 86, 102793.

3. **P2Rank GitHub**: https://github.com/rdk/p2rank

## See Also

- [General Usage Guide](../USAGE.md)
- [Target-Based Design Mode](../README.md#target-based-mode)
- [Boltzgen Documentation](https://boltz.mlsb.io/)
