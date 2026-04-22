# Pipeline Parameters

!!! tip "Auto-Generated Documentation"
    This page is automatically generated from `nextflow_schema.json`. 
    Parameter defaults and descriptions reflect the current pipeline version.

## Overview

**Pipeline**: nf-proteindesign pipeline parameters

Nextflow pipeline for computational protein design using BoltzGen (default) or Proteina-Complexa as the design backend, with a full analysis suite including ProteinMPNN, Boltz-2, ipSAE, PRODIGY, Foldseek, and consolidated reporting.

## Input/output options

Define where the pipeline should find input data and save output data.

### `--input`

**Required.** Path to comma-separated samplesheet file.

- **Type**: `string`
- **Default**: `"null"`
- **Pattern**: `^\S+\.csv$`

### `--outdir`

**Required.** The output directory where the results will be saved.

- **Type**: `string`
- **Default**: `"./results"`

## Design tool selection

### `--protein_design_tool`

Which design backend to use: `boltzgen` (default) or `complexa`.

- **Type**: `string`
- **Default**: `"boltzgen"`
- **Allowed values**: `boltzgen`, `complexa`

## BoltzGen parameters

Parameters specific to the BoltzGen design backend.

### `--cache_dir`

Cache directory for BoltzGen model weights.

- **Type**: `string`
- **Default**: `"null"`

## Complexa parameters

Parameters specific to the Proteina-Complexa design backend.

### `--complexa_ckpt_dir`

Directory containing Complexa model checkpoints (required when using Complexa).

- **Type**: `string`
- **Default**: `"null"`

### `--complexa_search_algorithm`

Search algorithm for Complexa design sampling.

- **Type**: `string`
- **Default**: `"best-of-n"`

### `--complexa_nsteps`

Number of diffusion sampling steps for Complexa.

- **Type**: `integer`
- **Default**: `400`

### `--complexa_replicas`

Number of replicas for best-of-n search.

- **Type**: `integer`
- **Default**: `2`

### `--complexa_batch_size`

Batch size for Complexa inference.

- **Type**: `integer`
- **Default**: `16`

## ProteinMPNN sequence optimization

Options for ProteinMPNN sequence optimization of designed structures.

### `--run_proteinmpnn`

Enable ProteinMPNN sequence optimization of Complexa designs.

- **Type**: `boolean`
- **Default**: `false`

### `--mpnn_sampling_temp`

Sampling temperature (lower = more conservative).

- **Type**: `number`
- **Default**: `0.1`

### `--mpnn_num_seq_per_target`

Number of sequence variants to generate per structure.

- **Type**: `integer`
- **Default**: `8`

### `--mpnn_batch_size`

Batch size for ProteinMPNN inference.

- **Type**: `integer`
- **Default**: `1`

### `--mpnn_seed`

Random seed for reproducibility.

- **Type**: `integer`
- **Default**: `37`

### `--mpnn_backbone_noise`

Backbone noise level (lower = more faithful to input).

- **Type**: `number`
- **Default**: `0.02`

### `--mpnn_save_score`

Save per-residue scores.

- **Type**: `boolean`
- **Default**: `true`

### `--mpnn_save_probs`

Save per-residue probabilities (large files, use for detailed analysis).

- **Type**: `boolean`
- **Default**: `false`

### `--mpnn_fixed_chains`

Chains to keep fixed (e.g., 'A,B' - typically the target chains).

- **Type**: `string`
- **Default**: `"null"`

### `--mpnn_designed_chains`

Chains to design (e.g., 'C' - typically the binder chain).

- **Type**: `string`
- **Default**: `"null"`

## Boltz-2 structure prediction

Options for Boltz-2 multimer structure prediction of ProteinMPNN sequences.

### `--run_boltz2_refold`

Enable Boltz-2 structure prediction for ProteinMPNN sequences.

- **Type**: `boolean`
- **Default**: `false`

### `--boltz2_num_diffusion`

Number of diffusion samples per sequence (higher = more diversity).

- **Type**: `integer`
- **Default**: `200`

### `--boltz2_num_recycling`

Number of recycling iterations for structure refinement.

- **Type**: `integer`
- **Default**: `3`

### `--boltz2_use_msa`

Use multiple sequence alignments (MSAs) for prediction.

- **Type**: `boolean`
- **Default**: `false`

### `--boltz2_predict_affinity`

Predict binding affinity for protein complexes.

- **Type**: `boolean`
- **Default**: `true`

## Analysis and scoring options

Options for scoring and evaluating designed structures.

### `--run_ipsae`

Enable IPSAE scoring of Complexa predictions.

- **Type**: `boolean`
- **Default**: `false`

### `--ipsae_pae_cutoff`

PAE cutoff for IPSAE calculation (Angstroms).

- **Type**: `number`
- **Default**: `10`

### `--ipsae_dist_cutoff`

Distance cutoff for CA-CA contacts (Angstroms).

- **Type**: `number`
- **Default**: `10`

### `--run_prodigy`

Enable PRODIGY binding affinity prediction on final designs.

- **Type**: `boolean`
- **Default**: `false`

### `--prodigy_selection`

Chain selection for PRODIGY (e.g., 'A,B'). If null, auto-detects from structure.

- **Type**: `string`
- **Default**: `"null"`

### `--run_foldseek`

Enable Foldseek structural similarity search for budget designs and Boltz-2 structures.

- **Type**: `boolean`
- **Default**: `false`

### `--foldseek_database`

Path to Foldseek database directory (required if run_foldseek is true).

- **Type**: `string`
- **Default**: `"null"`

### `--foldseek_database_name`

Name of the Foldseek database within the directory.

- **Type**: `string`
- **Default**: `"afdb"`

### `--foldseek_evalue`

E-value threshold for reporting matches (lower = more stringent).

- **Type**: `number`
- **Default**: `0.001`

### `--foldseek_max_seqs`

Maximum number of target sequences to report per query.

- **Type**: `integer`
- **Default**: `100`

### `--foldseek_sensitivity`

Search sensitivity (1.0-9.5, higher = more sensitive but slower).

- **Type**: `number`
- **Default**: `9.5`

### `--foldseek_coverage`

Minimum fraction of aligned residues (0.0-1.0, higher = more global alignment).

- **Type**: `number`
- **Default**: `0.0`

### `--foldseek_alignment_type`

Alignment type: 0=3Di only, 1=TMalign (global), 2=3Di+AA (local, default).

- **Type**: `integer`
- **Default**: `2`
- **Allowed values**: `0`, `1`, `2`

### `--run_consolidation`

Enable consolidated metrics report generation.

- **Type**: `boolean`
- **Default**: `false`

### `--report_top_n`

Number of top designs to highlight in consolidated report.

- **Type**: `integer`
- **Default**: `10`

## Resource allocation

Maximum resource limits for pipeline execution.

### `--max_cpus`

Maximum number of CPUs per process.

- **Type**: `integer`
- **Default**: `16`

### `--max_memory`

Maximum memory per process.

- **Type**: `string`
- **Default**: `"128.GB"`
- **Pattern**: `^\d+(\.\d+)?\.?\s*(K|M|G|T)?B$`

### `--max_time`

Maximum time per process.

- **Type**: `string`
- **Default**: `"240.h"`
- **Pattern**: `^\d+(\.\d+)?\.?\s*(m|h|d|s)?$`

### `--max_gpus`

Maximum number of GPUs per process.

- **Type**: `integer`
- **Default**: `1`

## Generic options

Less common options for the pipeline, typically set in a config file.

### `--publish_dir_mode`

Method for publishing outputs.

- **Type**: `string`
- **Default**: `"copy"`
- **Allowed values**: `copy`, `symlink`, `move`

### `--tracedir`

Directory to store pipeline execution traces.

- **Type**: `string`
- **Default**: `"${params.outdir}/pipeline_info"`

### `--validate_params`

Validate parameters against the schema at runtime.

- **Type**: `boolean`
- **Default**: `true`

### `--show_hidden_params`

Show hidden parameters in help message.

- **Type**: `boolean`
- **Default**: `false`

### `--help`

Display help text.

- **Type**: `boolean`
- **Default**: `"null"`

### `--version`

Display version and exit.

- **Type**: `boolean`
- **Default**: `"null"`

---

## Quick Reference Table

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `--input` | `string` | `"null"` | **Required |
| `--outdir` | `string` | `"./results"` | **Required |
| `--cache_dir` | `string` | `"null"` | Cache directory for model weights (~6GB) |
| `--complexa_config` | `string` | `"null"` | Optional path to custom Complexa config YAML to... |
| `--steps` | `string` | `"null"` | Optional comma-separated list of steps to run (e |
| `--run_proteinmpnn` | `boolean` | `false` | Enable ProteinMPNN sequence optimization of Bol... |
| `--mpnn_sampling_temp` | `number` | `0.1` | Sampling temperature (lower = more conservative) |
| `--mpnn_num_seq_per_target` | `integer` | `8` | Number of sequence variants to generate per str... |
| `--mpnn_batch_size` | `integer` | `1` | Batch size for ProteinMPNN inference |
| `--mpnn_seed` | `integer` | `37` | Random seed for reproducibility |
| `--mpnn_backbone_noise` | `number` | `0.02` | Backbone noise level (lower = more faithful to ... |
| `--mpnn_save_score` | `boolean` | `true` | Save per-residue scores |
| `--mpnn_save_probs` | `boolean` | `false` | Save per-residue probabilities (large files, us... |
| `--mpnn_fixed_chains` | `string` | `"null"` | Chains to keep fixed (e |
| `--mpnn_designed_chains` | `string` | `"null"` | Chains to design (e |
| `--run_boltz2_refold` | `boolean` | `false` | Enable Boltz-2 structure prediction for Protein... |
| `--boltz2_num_diffusion` | `integer` | `200` | Number of diffusion samples per sequence (highe... |
| `--boltz2_num_recycling` | `integer` | `3` | Number of recycling iterations for structure re... |
| `--boltz2_use_msa` | `boolean` | `false` | Use multiple sequence alignments (MSAs) for pre... |
| `--boltz2_predict_affinity` | `boolean` | `true` | Predict binding affinity for protein complexes |
| `--run_ipsae` | `boolean` | `false` | Enable IPSAE scoring of Complexa predictions |
| `--ipsae_pae_cutoff` | `number` | `10` | PAE cutoff for IPSAE calculation (Angstroms) |
| `--ipsae_dist_cutoff` | `number` | `10` | Distance cutoff for CA-CA contacts (Angstroms) |
| `--run_prodigy` | `boolean` | `false` | Enable PRODIGY binding affinity prediction on f... |
| `--prodigy_selection` | `string` | `"null"` | Chain selection for PRODIGY (e |
| `--run_foldseek` | `boolean` | `false` | Enable Foldseek structural similarity search fo... |
| `--foldseek_database` | `string` | `"null"` | Path to Foldseek database directory (required i... |
| `--foldseek_database_name` | `string` | `"afdb"` | Name of the Foldseek database within the directory |
| `--foldseek_evalue` | `number` | `0.001` | E-value threshold for reporting matches (lower ... |
| `--foldseek_max_seqs` | `integer` | `100` | Maximum number of target sequences to report pe... |
| `--foldseek_sensitivity` | `number` | `9.5` | Search sensitivity (1 |
| `--foldseek_coverage` | `number` | `0.0` | Minimum fraction of aligned residues (0 |
| `--foldseek_alignment_type` | `integer` | `2` | Alignment type: 0=3Di only, 1=TMalign (global),... |
| `--run_consolidation` | `boolean` | `false` | Enable consolidated metrics report generation |
| `--report_top_n` | `integer` | `10` | Number of top designs to highlight in consolida... |
| `--max_cpus` | `integer` | `16` | Maximum number of CPUs per process |
| `--max_memory` | `string` | `"128.GB"` | Maximum memory per process |
| `--max_time` | `string` | `"240.h"` | Maximum time per process |
| `--max_gpus` | `integer` | `1` | Maximum number of GPUs per process |
| `--publish_dir_mode` | `string` | `"copy"` | Method for publishing outputs |
| `--tracedir` | `string` | `"${params.outdir}/pipeline_info"` | Directory to store pipeline execution traces |
| `--validate_params` | `boolean` | `true` | Validate parameters against the schema at runtime |
| `--show_hidden_params` | `boolean` | `false` | Show hidden parameters in help message |
| `--help` | `boolean` | `"null"` | Display help text |
| `--version` | `boolean` | `"null"` | Display version and exit |
