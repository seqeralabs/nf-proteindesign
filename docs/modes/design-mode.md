# Design Mode

## :material-file-code: Overview

Design mode provides **full control** over protein design specifications through pre-made YAML files. This mode is ideal when you know exactly what you want to design and have prepared detailed specifications.

!!! success "Best For"
    - Precise, well-defined design requirements
    - Iterating on specific designs
    - Reproducible workflows
    - Fine-grained parameter control

## :material-file-document: YAML Specification Format

Design YAML files follow the Boltzgen design specification format:

```yaml
name: my_protein_design
target:
  structure: path/to/target.pdb
  residues: [10, 11, 12, 45, 46, 47, 89, 90]
designed:
  chain_type: protein  # protein, peptide, or nanobody
  length: [50, 100]    # [min_length, max_length]
global:
  n_samples: 20
  timesteps: 100
  save_traj: false
  seed: 42
```

### Required Fields

| Field | Description | Example |
|-------|-------------|---------|
| `name` | Design identifier | `"antibody_egfr_design"` |
| `target.structure` | Target structure file | `"data/egfr.pdb"` |
| `target.residues` | Binding site residues | `[10, 11, 12, 45]` |
| `designed.chain_type` | Type of binder | `protein`, `peptide`, `nanobody` |
| `designed.length` | Length range | `[50, 100]` |

### Optional Fields

| Field | Description | Default |
|-------|-------------|---------|
| `global.n_samples` | Number of designs | 10 |
| `global.timesteps` | Diffusion steps | 100 |
| `global.save_traj` | Save trajectories | false |
| `global.seed` | Random seed | null (random) |

## :material-play: Running Design Mode

### Create Samplesheet

```csv title="samplesheet_design.csv"
sample,design_yaml
antibody1,designs/antibody_design1.yaml
antibody2,designs/antibody_design2.yaml
peptide1,designs/peptide_binder.yaml
```

### Execute Pipeline

=== "Explicit Mode"
    ```bash
    nextflow run FloWuenne/nf-proteindesign-2025 \
        -profile docker \
        --mode design \
        --input samplesheet_design.csv \
        --outdir results
    ```

=== "Auto-Detection"
    ```bash
    # Mode automatically detected from 'design_yaml' column
    nextflow run FloWuenne/nf-proteindesign-2025 \
        -profile docker \
        --input samplesheet_design.csv \
        --outdir results
    ```

## :material-test-tube: Example: Antibody Design

### 1. Create Design YAML

```yaml title="antibody_egfr.yaml"
name: anti_egfr_antibody
target:
  structure: data/egfr_extracellular.pdb
  residues: [10, 11, 12, 13, 45, 46, 47, 89, 90, 91]  # EGFR epitope
designed:
  chain_type: protein
  length: [100, 130]  # Typical antibody VH domain size
global:
  n_samples: 50       # Generate 50 designs
  timesteps: 100
  save_traj: false
  seed: 12345         # Reproducible results
```

### 2. Create Samplesheet

```csv title="antibody_designs.csv"
sample,design_yaml
egfr_vh1,designs/antibody_egfr.yaml
```

### 3. Run Pipeline

```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --input antibody_designs.csv \
    --outdir egfr_antibodies \
    --run_prodigy  # Enable affinity prediction
```

### 4. Check Results

```bash
# View final designs
ls egfr_antibodies/egfr_vh1/boltzgen/final_ranked_designs/

# Check binding predictions
cat egfr_antibodies/egfr_vh1/prodigy/design_*_summary.csv | \
    sort -t',' -k3,3n | head -5
```

## :material-puzzle: Design Tips

### Choosing Binding Site Residues

!!! tip "Identifying Binding Sites"
    Use structural analysis tools to identify key residues:
    
    - **Known complexes**: Extract interface residues
    - **Functional sites**: Target catalytic or regulatory sites
    - **Hotspots**: Focus on energetically important residues
    - **Conservation**: Target conserved regions for specificity

```python
# Example: Extract interface residues with Biopython
from Bio.PDB import *

parser = PDBParser()
structure = parser.get_structure('complex', 'complex.pdb')

# Get all residues within 5Å of target chain
target_chain = structure[0]['A']
designed_chain = structure[0]['B']

interface_residues = []
for target_res in target_chain:
    for designed_res in designed_chain:
        if target_res['CA'] - designed_res['CA'] < 5.0:
            interface_residues.append(target_res.id[1])

print(f"Interface residues: {sorted(set(interface_residues))}")
```

### Chain Type Selection

=== "Protein"
    **Best for**: Full-length binders, structural proteins
    
    ```yaml
    designed:
      chain_type: protein
      length: [80, 150]  # Typical range
    ```

=== "Peptide"
    **Best for**: Short binders, epitope mimics, drug-like molecules
    
    ```yaml
    designed:
      chain_type: peptide
      length: [8, 30]    # Short sequences
    ```

=== "Nanobody"
    **Best for**: Therapeutic antibodies, single-domain binders
    
    ```yaml
    designed:
      chain_type: nanobody
      length: [110, 130]  # Standard VHH size
    ```

### Length Range Guidelines

| Design Type | Typical Length | Considerations |
|-------------|---------------|----------------|
| **Small peptide** | 8-15 | Limited diversity, high specificity |
| **Peptide** | 15-30 | Good balance, flexible |
| **Small protein** | 40-80 | Structured, specific binding |
| **Protein** | 80-150 | Full structural repertoire |
| **Nanobody** | 110-130 | Antibody-like properties |

## :material-file-multiple: Multiple Designs

Run multiple designs in parallel by adding rows to your samplesheet:

```csv title="multiple_designs.csv"
sample,design_yaml
design_v1,designs/egfr_v1.yaml
design_v2,designs/egfr_v2.yaml
design_v3,designs/egfr_v3.yaml
il6_design,designs/il6_binder.yaml
spike_design,designs/spike_binder.yaml
```

!!! tip "Parallel Processing"
    All designs run in parallel, making this mode highly efficient for multiple targets or design variants.

## :material-cog: Advanced Options

### Diffusion Parameters

Adjust diffusion settings for quality vs. speed:

```yaml
global:
  timesteps: 200      # More steps = higher quality (slower)
  save_traj: true     # Save intermediate structures
  seed: 42            # Reproducible results
```

### Multiple Binding Sites

Design binders for multiple sites by creating separate YAML files:

```yaml title="site1.yaml"
name: target_site1
target:
  structure: data/target.pdb
  residues: [10, 11, 12, 13]  # Site 1
designed:
  chain_type: peptide
  length: [15, 25]
```

```yaml title="site2.yaml"
name: target_site2
target:
  structure: data/target.pdb
  residues: [45, 46, 47, 48]  # Site 2
designed:
  chain_type: peptide
  length: [15, 25]
```

## :material-folder-open: Output Structure

```
results/
└── {sample}/
    ├── boltzgen/
    │   ├── final_ranked_designs/
    │   │   ├── design_1.cif
    │   │   ├── design_2.cif
    │   │   └── ...
    │   ├── intermediate_designs/
    │   └── boltzgen.log
    ├── prodigy/
    │   └── design_*_summary.csv
    └── ipsae/
        └── design_*_scores.csv
```

## :material-compare: Comparison with Other Modes

| Feature | Design Mode | Target Mode | P2Rank Mode |
|---------|-------------|-------------|-------------|
| Control | Maximum | High | Automated |
| Setup time | Medium | Low | Low |
| Flexibility | High | Medium | Low |
| Designs per sample | 1 | Multiple | Multiple |
| Best for | Precise designs | Exploration | Discovery |

## :material-arrow-right: Next Steps

- Learn about [Target Mode](target-mode.md) for systematic exploration
- See [P2Rank Mode](p2rank-mode.md) for binding site discovery
- Check [PRODIGY](../analysis/prodigy.md) for affinity prediction

---

!!! example "Complete Workflow"
    See [Examples](../reference/examples.md) for complete design workflows with analysis.
