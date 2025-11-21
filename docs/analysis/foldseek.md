# Foldseek Structural Search

## Overview

Foldseek is a structural similarity search tool that identifies proteins with similar 3D structures. The pipeline integrates Foldseek to search for structural homologs of both Boltzgen-designed and Protenix-refolded structures against large databases like AlphaFold or Swiss-Model.

!!! info "What is Foldseek?"
    Foldseek uses a novel 3Di structural alphabet combined with traditional amino acid sequences to enable ultra-fast structural similarity searches. It's significantly faster than traditional structural alignment tools like TM-align while maintaining high sensitivity.

## When to Use Foldseek

Enable Foldseek structural search when you want to:

- **Identify homologs**: Find proteins with similar structures in large databases
- **Validate designs**: Check if designed structures resemble known proteins
- **Discover function**: Infer potential functions based on structural similarity
- **Assess novelty**: Determine if designs are truly novel or similar to existing structures

## Enabling Foldseek

```bash
nextflow run seqeralabs/nf-proteindesign \
    -profile docker \
    --input samplesheet.csv \
    --run_foldseek \
    --foldseek_database /path/to/afdb \
    --outdir results
```

## Key Parameters

### Required Parameters

| Parameter | Description |
|-----------|-------------|
| `--run_foldseek` | Enable Foldseek structural search (default: `false`) |
| `--foldseek_database` | Path to Foldseek database directory (required when Foldseek is enabled) |

### Search Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--foldseek_evalue` | `0.001` | E-value threshold for reporting matches (lower = more stringent) |
| `--foldseek_max_seqs` | `100` | Maximum number of target sequences to report |
| `--foldseek_sensitivity` | `9.5` | Search sensitivity (1.0-9.5, higher = more sensitive but slower) |
| `--foldseek_coverage` | `0.0` | Minimum fraction of aligned residues (0.0-1.0) |
| `--foldseek_alignment_type` | `2` | 0=3Di only, 1=TMalign (global), 2=3Di+AA (local, default) |

## Database Setup

### AlphaFold Database (Recommended)

Download and prepare the AlphaFold database:

```bash
# Download AlphaFold database (choose your version)
wget https://foldseek.steineggerlab.workers.dev/afdb-swissprot.tar.gz
tar xzf afdb-swissprot.tar.gz

# Use in pipeline
--foldseek_database /path/to/afdb-swissprot
```

### Swiss-Model Database

Alternatively, use Swiss-Model structures:

```bash
# Download Swiss-Model database
wget https://foldseek.steineggerlab.workers.dev/swissprot.tar.gz
tar xzf swissprot.tar.gz

--foldseek_database /path/to/swissprot
```

### Custom Database

Create a custom database from your PDB files:

```bash
# Create database from directory of PDB/CIF files
foldseek createdb /path/to/structures/ mydb

# Use in pipeline
--foldseek_database /path/to/mydb
```

## What Structures Are Searched?

The pipeline runs Foldseek on:

1. **Boltzgen budget designs** - All structures from `intermediate_designs_inverse_folded/`
2. **Protenix refolded structures** - All structures predicted by Protenix (if enabled)

Each structure is searched independently, allowing comparison of:
- Original Boltzgen designs
- ProteinMPNN-optimized sequences refolded by Protenix

## Output Files

For each design, Foldseek generates:

```
results/
└── sample_id/
    └── foldseek/
        ├── design_id_boltzgen/
        │   ├── aln.m8              # Alignment results in BLAST-like format
        │   ├── summary.tsv         # Summary of top hits
        │   └── alignment.html      # Detailed alignment visualization
        └── design_id_protenix/     # (if Protenix enabled)
            ├── aln.m8
            ├── summary.tsv
            └── alignment.html
```

### Output Format

The `summary.tsv` file contains:

| Column | Description |
|--------|-------------|
| `query` | Query structure name |
| `target` | Target structure identifier |
| `evalue` | E-value (lower = more significant) |
| `prob` | Probability score |
| `score` | Alignment score |
| `qlen` | Query length |
| `tlen` | Target length |
| `alnlen` | Alignment length |
| `qstart`, `qend` | Query alignment boundaries |
| `tstart`, `tend` | Target alignment boundaries |
| `description` | Target protein description |

## Interpreting Results

### E-value Interpretation

- **E < 1e-10**: Very strong structural similarity
- **E < 1e-5**: Strong structural similarity
- **E < 0.001**: Moderate similarity (default threshold)
- **E < 0.01**: Weak similarity
- **E > 0.1**: Likely not significant

### Example Analysis

```bash
# View top hits for a design
head results/sample1/foldseek/design1_boltzgen/summary.tsv

# Count significant hits (E < 1e-5)
awk '$3 < 1e-5' results/sample1/foldseek/design1_boltzgen/summary.tsv | wc -l

# Extract top hit details
head -n 2 results/sample1/foldseek/design1_boltzgen/summary.tsv
```

## Integration with Other Analyses

Foldseek results are automatically integrated into the consolidated metrics report when both are enabled:

```bash
nextflow run seqeralabs/nf-proteindesign \
    --input samplesheet.csv \
    --run_foldseek \
    --foldseek_database /path/to/afdb \
    --run_consolidation \
    --outdir results
```

The consolidated report includes:
- Best E-value for each design
- Top matching protein name/description
- Number of significant hits
- Comparison across Boltzgen and Protenix structures

## Performance Notes

- **GPU accelerated**: Foldseek can utilize GPUs for faster searches
- **Memory usage**: ~4-8 GB per search depending on database size
- **Search time**: ~1-5 minutes per structure with AlphaFold database
- **Database size**: AlphaFold database is ~200 GB

## Troubleshooting

### Database Not Found

```bash
ERROR: Foldseek database not found at /path/to/database
```

**Solution**: Ensure the database path is correct and accessible:
```bash
ls -l /path/to/database/
# Should show database files like database.index, database.lookup, etc.
```

### Out of Memory

```bash
ERROR: Foldseek ran out of memory
```

**Solution**: Reduce the number of results or increase memory allocation:
```bash
--foldseek_max_seqs 50  # Reduce from default 100
```

### No Significant Hits

If no hits are found:
- Check E-value threshold (try relaxing to `--foldseek_evalue 0.01`)
- Increase sensitivity (`--foldseek_sensitivity 9.5`)
- Verify database is appropriate for your designs
- Consider if designs are truly novel (no existing homologs)

## References

- **Foldseek Publication**: van Kempen M, et al. (2024) Fast and accurate protein structure search with Foldseek. *Nature Biotechnology*. [doi:10.1038/s41587-023-01773-0](https://doi.org/10.1038/s41587-023-01773-0)
- **Documentation**: [https://github.com/steineggerlab/foldseek](https://github.com/steineggerlab/foldseek)

## See Also

- [PRODIGY Binding Affinity](prodigy.md) - Predict binding affinity
- [ipSAE Scoring](ipsae.md) - Evaluate interface quality
- [Consolidated Metrics](consolidation.md) - Unified reporting
