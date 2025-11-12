# Parameters Reference

Complete reference for all pipeline parameters.

## :material-file-table: Input/Output

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `--input` | file | Samplesheet CSV file | *Required* |
| `--outdir` | path | Output directory | *Required* |
| `--mode` | string | Pipeline mode | Auto-detect |

## :material-robot: Mode Selection

| Parameter | Type | Description | Options |
|-----------|------|-------------|---------|
| `--mode` | string | Explicit mode selection | `design`, `target`, `p2rank` |

## :material-tune: Design Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `--n_samples` | integer | Designs per specification | 10 |
| `--timesteps` | integer | Diffusion timesteps | 100 |
| `--save_traj` | boolean | Save trajectories | false |

## :material-target: Target Mode Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `--min_design_length` | integer | Minimum binder length | 50 |
| `--max_design_length` | integer | Maximum binder length | 150 |
| `--length_step` | integer | Length increment | 20 |
| `--n_variants_per_length` | integer | Variants per length | 3 |
| `--chain_type` | string | Binder type | `protein` |

### Chain Type Options

- `protein`: Full-length protein binders
- `peptide`: Short peptide binders
- `nanobody`: Single-domain antibodies

## :material-brain: P2Rank Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `--p2rank_top_n` | integer | Number of top pockets | 5 |
| `--p2rank_min_score` | float | Minimum pocket score | 0.5 |
| `--p2rank_conservation` | boolean | Use conservation analysis | false |

## :material-chart-line: Analysis Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `--run_ipsae` | boolean | Enable ipSAE scoring | false |
| `--run_prodigy` | boolean | Enable PRODIGY | false |
| `--prodigy_selection` | string | Chain selection | Auto-detect |

## :material-server: Resource Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `--max_cpus` | integer | Maximum CPUs | 16 |
| `--max_memory` | memory | Maximum memory | 128.GB |
| `--max_time` | time | Maximum time | 48.h |

### Memory Units

- `GB`: Gigabytes
- `MB`: Megabytes
- `TB`: Terabytes

### Time Units

- `h`: Hours
- `m`: Minutes
- `d`: Days

## :material-docker: Container Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `--boltzgen_container` | string | Boltzgen container | `ghcr.io/flouwuenne/boltzgen:latest` |
| `--prodigy_container` | string | PRODIGY container | `ghcr.io/flouwuenne/prodigy:latest` |
| `--p2rank_container` | string | P2Rank container | `biocontainers/p2rank:2.4.1--hdfd78af_0` |

## :material-cog: Advanced Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `--publish_dir_mode` | string | Output file mode | `copy` |
| `--validate_params` | boolean | Validate parameters | true |
| `--show_hidden_params` | boolean | Show all parameters | false |

## :material-book-open: Usage Examples

### Basic Usage

```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
    --input samplesheet.csv \
    --outdir results
```

### Custom Design Parameters

```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
    --input samplesheet.csv \
    --outdir results \
    --n_samples 50 \
    --timesteps 200 \
    --save_traj true
```

### Target Mode Configuration

```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
    --input samplesheet.csv \
    --mode target \
    --min_design_length 60 \
    --max_design_length 120 \
    --length_step 10 \
    --n_variants_per_length 5 \
    --outdir results
```

### With All Analysis Tools

```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
    --input samplesheet.csv \
    --outdir results \
    --run_ipsae \
    --run_prodigy \
    --prodigy_selection 'A,B'
```

### Resource Optimization

```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
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
    n_samples = 50
    timesteps = 200
    
    // Target mode
    min_design_length = 60
    max_design_length = 120
    length_step = 10
    
    // Analysis
    run_prodigy = true
    run_ipsae = true
}
```

Use with:

```bash
nextflow run FloWuenne/nf-proteindesign-2025 -c params.config
```

## :material-arrow-right: See Also

- [Quick Reference](../getting-started/quick-reference.md)
- [Usage Guide](../getting-started/usage.md)
- [Examples](examples.md)
