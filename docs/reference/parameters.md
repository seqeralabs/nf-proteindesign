# Parameters Reference

Complete reference for all pipeline parameters.

## :material-file-table: Input/Output

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `--input` | file | Samplesheet CSV file | *Required* |
| `--outdir` | path | Output directory | `./results` |
| `--mode` | string | Pipeline mode (only `design` supported) | `design` |
| `--publish_dir_mode` | string | How to publish output files | `copy` |

## :material-robot: Mode Selection

The pipeline runs in **design mode**, using pre-made Boltzgen design YAML files specified in the samplesheet's `design_yaml` column.
## :material-dna: Boltzgen Design Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `--protocol` | string | Boltzgen protocol | `protein-anything` |
| `--num_designs` | integer | Number of intermediate designs | 100 |
| `--budget` | integer | Final diversity-optimized designs | 10 |
| `--cache_dir` | path | Cache directory for model weights (~6GB) | `null` (uses ~/.cache) |
| `--boltzgen_config` | file | Custom Boltzgen config YAML | `null` |
| `--steps` | string | Comma-separated steps to run | `null` (all steps) |

### Protocol Options

- `protein-anything`: Design proteins to bind any biomolecule
- `peptide-anything`: Design peptides to bind any biomolecule
- `protein-small_molecule`: Design proteins to bind small molecules
- `nanobody-anything`: Design nanobodies to bind any biomolecule

## :material-chart-line: Analysis Modules

### ProteinMPNN Sequence Optimization

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `--run_proteinmpnn` | boolean | Enable ProteinMPNN optimization | `false` |
| `--mpnn_sampling_temp` | float | Sampling temperature (0.1-0.3) | 0.1 |
| `--mpnn_num_seq_per_target` | integer | Sequences per structure | 8 |
| `--mpnn_batch_size` | integer | Batch size for inference | 1 |
| `--mpnn_seed` | integer | Random seed for reproducibility | 37 |
| `--mpnn_backbone_noise` | float | Backbone noise level (0.02-0.20) | 0.02 |
| `--mpnn_save_score` | boolean | Save per-residue scores | `true` |
| `--mpnn_save_probs` | boolean | Save per-residue probabilities | `false` |
| `--mpnn_fixed_chains` | string | Chains to keep fixed (e.g., 'A,B') | `null` |
| `--mpnn_designed_chains` | string | Chains to design (e.g., 'C') | `null` |

### IPSAE Interface Scoring

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `--run_ipsae` | boolean | Enable IPSAE scoring | `false` |
| `--ipsae_pae_cutoff` | float | PAE cutoff in Angstroms | 10 |
| `--ipsae_dist_cutoff` | float | CA-CA distance cutoff | 10 |

### PRODIGY Binding Affinity

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `--run_prodigy` | boolean | Enable PRODIGY prediction | `false` |
| `--prodigy_selection` | string | Chain selection (e.g., 'A,B') | `null` (auto-detect) |

### Metrics Consolidation

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `--run_consolidation` | boolean | Enable consolidated report | `false` |
| `--report_top_n` | integer | Number of top designs to highlight | 10 |

## :material-server: Resource Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `--max_cpus` | integer | Maximum CPUs per process | 16 |
| `--max_memory` | memory | Maximum memory per process | 128.GB |
| `--max_time` | time | Maximum time per process | 240.h |
| `--max_gpus` | integer | Maximum GPUs per process | 1 |

### Memory Units

- `GB`: Gigabytes
- `MB`: Megabytes
- `TB`: Terabytes

### Time Units

- `h`: Hours
- `m`: Minutes
- `d`: Days

## :material-cog: Advanced Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `--publish_dir_mode` | string | Output file mode | `copy` |
| `--validate_params` | boolean | Validate parameters | true |
| `--show_hidden_params` | boolean | Show all parameters | false |

## :material-book-open: Usage Examples

### Basic Usage

```bash
nextflow run seqeralabs/nf-proteindesign \
    --input samplesheet.csv \
    --outdir results
```

### Custom Design Parameters

```bash
nextflow run seqeralabs/nf-proteindesign \
    --input samplesheet.csv \
    --outdir results \
    --n_samples 50 \
    --timesteps 200 \
    --save_traj true
```

### With All Analysis Tools

```bash
nextflow run seqeralabs/nf-proteindesign \
    --input samplesheet.csv \
    --outdir results \
    --run_ipsae \
    --run_prodigy \
    --prodigy_selection 'A,B'
```

### Resource Optimization

```bash
nextflow run seqeralabs/nf-proteindesign \
    --input samplesheet.csv \
    --outdir results \
    --max_cpus 32 \
    --max_memory 256.GB \
    --max_time 72.h
```

## :material-file-code: Configuration File

Create `params.config` for reusable settings:

```groovy
params {
    // Input/Output
    input = 'samplesheet.csv'
    outdir = 'results'
    
    // Design parameters
    num_designs = 100
    budget = 10
    
    // Analysis
    run_prodigy = true
    run_ipsae = true
}
```

Use with:

```bash
nextflow run seqeralabs/nf-proteindesign -c params.config
```

## :material-arrow-right: See Also

- [Quick Reference](../getting-started/quick-reference.md)
- [Usage Guide](../getting-started/usage.md)
- [Examples](examples.md)
