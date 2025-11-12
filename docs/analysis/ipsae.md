# ipSAE Scoring

## :material-chart-line: Overview

ipSAE (Interface Protein Structure Analysis and Evaluation) provides quantitative metrics for evaluating protein-protein interactions in designed complexes. This optional analysis complements PRODIGY predictions with detailed structural assessments.

!!! info "What is ipSAE?"
    ipSAE analyzes the geometric and chemical properties of protein interfaces to score interaction quality, helping identify the most promising designed binders.

## :material-toggle-switch: Enabling ipSAE

Add the `--run_ipsae` flag to your pipeline command:

```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --input samplesheet.csv \
    --run_ipsae \
    --outdir results
```

## :material-file-chart: Output Files

ipSAE generates detailed scoring files for each design:

```
results/
└── {sample}/
    └── ipsae/
        ├── design_1_ipsae_scores.csv
        ├── design_2_ipsae_scores.csv
        └── ...
```

### Score Metrics

Each file contains multiple interaction quality metrics:

| Metric | Description | Better Value |
|--------|-------------|--------------|
| Interface Area | Contact surface area | Larger |
| Shape Complementarity | Geometric fit | Higher (0-1) |
| Contact Density | Residues per area | Higher |
| Hydrogen Bonds | H-bond count | More |
| Salt Bridges | Ionic interactions | More |
| Hydrophobic Contacts | Apolar interactions | Balanced |

## :material-compare: Comparing ipSAE and PRODIGY

| Feature | ipSAE | PRODIGY |
|---------|-------|---------|
| **Focus** | Interface quality | Binding affinity |
| **Output** | Multiple metrics | ΔG and Kd |
| **Speed** | Fast | Fast |
| **Best For** | Structural analysis | Affinity ranking |

!!! tip "Use Both"
    Combine ipSAE and PRODIGY for comprehensive evaluation:
    ```bash
    nextflow run ... --run_ipsae --run_prodigy
    ```

## :material-chart-box: Interpreting Results

### Example Output

```csv
design_id,interface_area,shape_comp,contact_density,h_bonds,salt_bridges,hydrophobic
design_1,1543.2,0.68,0.045,12,3,28
design_2,1289.7,0.72,0.052,15,4,22
design_3,1678.9,0.61,0.038,9,2,31
```

### Quality Thresholds

!!! success "Good Interfaces"
    - Interface Area: > 1200 Ų
    - Shape Complementarity: > 0.65
    - H-bonds: > 10
    - Salt Bridges: ≥ 2

## :material-arrow-right: Next Steps

- Learn about [PRODIGY](prodigy.md) for binding affinity
- See [Output Files](../reference/outputs.md) reference
- Check [Examples](../reference/examples.md)

---

!!! note "Coming Soon"
    Detailed ipSAE analysis guide with visualization examples.
