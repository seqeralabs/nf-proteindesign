# Proteina-Complexa Migration: Technical Implementation Log

**Branch**: `feat/proteina-complexa`  
**Date Started**: 2026-04-22  
**Objective**: Replace the `BOLTZGEN_RUN` process with NVIDIA's Proteina-Complexa tool in the `nf-proteindesign` pipeline.

> **⚠️ Scope**: This is a **targeted replacement** of the BoltzGen design step only — not a
> rewrite of the pipeline. The existing `nf-proteindesign` pipeline structure, downstream
> processes (ProteinMPNN, Boltz-2 refolding, IPSAE, PRODIGY, Foldseek, metrics consolidation),
> and all surrounding infrastructure remain unchanged. Only the generative design module
> (`BOLTZGEN_RUN` → `PROTEINA_COMPLEXA_DESIGN`) and its associated config/params are modified.

---

## Step 1: Audit BoltzGen Process (the module being replaced) ✅

**Status**: Complete  
**Date**: 2026-04-22  
**⏱ Seqera AI time**: ~5 min (read all pipeline files, traced channels, mapped inputs/outputs/downstream impacts)

### What's being replaced

Only the `BOLTZGEN_RUN` process is being swapped out. Everything downstream stays the same.

```
Before:  BOLTZGEN_RUN → CONVERT_CIF_TO_PDB → PROTEINMPNN → BOLTZ2_REFOLD → scoring → metrics
After:   PROTEINA_COMPLEXA_DESIGN → (PDB, no conversion) → PROTEINMPNN → BOLTZ2_REFOLD → scoring → metrics
```

### BOLTZGEN_RUN — Current Interface

**File**: `modules/local/boltzgen_run.nf`  
**Container**: `cr.seqera.io/scidev/boltzgen:0.1.5`  
**GPU**: 1x NVIDIA GPU required | **Label**: `process_high_gpu`

#### Inputs
| Name | Type | Description |
|------|------|-------------|
| `meta` | val (map) | Sample metadata: `id`, `protocol`, `num_designs`, `budget`, `reuse` |
| `design_yaml` | path | YAML file specifying design parameters |
| `structure_files` | path | Input structure files (CIF format) |
| `cache_dir` | path | Model weight cache directory (~6GB) |

#### Key Outputs (consumed downstream)
| Emit Name | Path Pattern | Consumed By |
|-----------|-------------|-------------|
| `budget_design_cifs` | `${meta.id}_output/final_ranked_designs/final_*_designs/*.cif` | `CONVERT_CIF_TO_PDB` → ProteinMPNN |
| `aggregate_metrics` | `${meta.id}_output/aggregate_metrics_analyze.csv` | `CONSOLIDATE_METRICS` |
| `per_target_metrics` | `${meta.id}_output/per_target_metrics_analyze.csv` | `CONSOLIDATE_METRICS` |

#### Workflow Integration (in `workflows/protein_design.nf`)
1. Input channel splits into `with_precomputed` (skip) and `needs_boltzgen` (run)
2. `BOLTZGEN_RUN(ch_branched.needs_boltzgen, ch_cache)`
3. Results merge → `ch_boltzgen_results`
4. `budget_design_cifs` feeds `CONVERT_CIF_TO_PDB` → ProteinMPNN path

### Files That Need Changes

| File | Change Type | Status |
|------|-------------|--------|
| `modules/local/boltzgen_run.nf` | Replace with `PROTEINA_COMPLEXA_DESIGN` process | Pending |
| `workflows/protein_design.nf` | Update include, process call, output channels | Pending |
| `nextflow.config` | Update/add Complexa params | ✅ Done |
| `conf/base.config` | Update process label | ✅ Done |
| `nextflow_schema.json` | Update parameter schema | Pending |

### Downstream Impact

| Downstream Process | Impact |
|--------------------|--------|
| `CONVERT_CIF_TO_PDB` | **May be eliminated** — Complexa outputs PDB directly |
| `PROTEINMPNN_OPTIMIZE` | **None** — still receives PDB files |
| `BOLTZ2_REFOLD` | **None** — still receives FASTA sequences |
| `IPSAE_CALCULATE` | **Minor** — may need to source confidence data from Complexa CSVs |
| `CONSOLIDATE_METRICS` | **Minor** — CSV column names differ |

---

## Step 2: Map BoltzGen → Complexa Interface Differences ✅

**Status**: Complete  
**Date**: 2026-04-22  
**⏱ Seqera AI time**: ~8 min (cloned Complexa repo, read source configs, verified defaults, built parameter mapping)  
**Source**: https://github.com/NVIDIA-Digital-Bio/Proteina-Complexa

This step documents only what differs between BoltzGen and Complexa that affects the swap.

### Key Differences for the Swap

| Aspect | BoltzGen (current) | Proteina-Complexa (replacement) |
|--------|--------------------|---------------------------------|
| CLI | `boltzgen run <yaml> --flags` | `complexa design <yaml> [++hydra_overrides]` |
| Config system | Simple CLI flags | Hydra/OmegaConf YAML composition |
| Input structures | CIF files | PDB files |
| Output structures | CIF files | **PDB files** — eliminates `CONVERT_CIF_TO_PDB` step |
| Internal stages | Single command | 4-stage pipeline (generate → filter → evaluate → analyze) |
| Checkpoints | Single `--cache` dir | Separate `ckpt_path` + `autoencoder_ckpt_path` |

### Parameter Mapping

| BoltzGen Flag | Complexa Hydra Override | Notes |
|---------------|------------------------|-------|
| `--protocol` | Pipeline config file choice | `search_binder_local_pipeline.yaml` vs `search_ligand_binder_local_pipeline.yaml` |
| `--num_designs` | `nsamples × replicas × batch_size` | Composite of multiple params |
| `--budget` | `generation.filter.filter_samples_limit` | Top-N after reward filtering |
| `--cache` | `ckpt_path` + `autoencoder_ckpt_path` | Split into separate paths |
| `--config` | `++key=value` Hydra overrides | |
| `--reuse` | N/A | No direct equivalent |

### Default Generation Parameters (verified from source)

Verified against Proteina-Complexa source code in `Proteina-Complexa/configs/`:

| Pipeline Param | Hydra Override Path | Default | Source File |
|----------------|--------------------|---------:|-------------|
| `complexa_search_algorithm` | `++generation.search.algorithm` | `best-of-n` | `pipeline/binder/binder_generate.yaml` |
| `complexa_nsteps` | `++generation.args.nsteps` | `400` | `pipeline/model_sampling.yaml` |
| `complexa_replicas` | `++generation.search.best_of_n.replicas` | `2` | `pipeline/binder/binder_generate.yaml` |
| `complexa_batch_size` | `++generation.dataloader.batch_size` | `16` | `pipeline/binder/binder_generate.yaml` (overrides base default of 10) |

### Output Structure (what the new process must emit)

Complexa outputs PDB files directly. The new process must emit outputs compatible with the existing downstream processes:

```
inference/{run_name}_{task_name}/
├── job_0_*/*.pdb              → feeds PROTEINMPNN_OPTIMIZE (replaces budget_design_cifs)
├── evaluation_results/*.csv   → feeds CONSOLIDATE_METRICS (replaces aggregate/per_target metrics)
└── analysis/*_combined.csv    → feeds CONSOLIDATE_METRICS
```

### Container Image

**Image**: `307946633589.dkr.ecr.eu-west-2.amazonaws.com/rashmi/proteina-complexa:latest`  
**Registry**: Private ECR (eu-west-2) — compute environment needs ECR pull permissions for account `307946633589`  
**Runtime**: Requires `--gpus all` (same GPU requirement as BoltzGen)

---

## Step 3: Replace BoltzGen Module with Complexa ✅

**Status**: Complete  
**Date**: 2026-04-22  
**⏱ Seqera AI time**: ~5 min (wrote module process, updated configs, matched input/output interface to downstream)

Replaced `modules/local/boltzgen_run.nf` with `modules/local/proteina_complexa_design.nf`.

### What changed
- ✅ `modules/local/proteina_complexa_design.nf` — new process definition
  - Accepts `tuple val(meta), path(target_pdb), path(pipeline_config)` + checkpoint dir
  - Runs `complexa design` with Hydra overrides mapped from pipeline params
  - Emits `design_pdbs` (PDB files), `eval_csvs`, `analysis_csvs`, `success_pdbs`, `versions`
  - Includes `stub:` block for dry-run testing
- ✅ `conf/base.config` — process resource config for `PROTEINA_COMPLEXA_DESIGN`
- ✅ `nextflow.config` — Complexa params with defaults and ECR container URI

### Key interface change: CIF → PDB
BoltzGen emitted CIF files that required `CONVERT_CIF_TO_PDB` before ProteinMPNN.  
Complexa emits PDB directly — `CONVERT_CIF_TO_PDB` is no longer needed in the pipeline path.

---

## Step 4: Update Workflow Wiring ✅

**Status**: Complete  
**Date**: 2026-04-22  
**⏱ Seqera AI time**: ~5 min (rewired workflow includes, channels, removed CIF→PDB conversion step)

Updated `workflows/protein_design.nf` to use `PROTEINA_COMPLEXA_DESIGN` instead of `BOLTZGEN_RUN`.

### What changed
- ✅ `include { PROTEINA_COMPLEXA_DESIGN }` replaces `include { BOLTZGEN_RUN }`
- ✅ Input channel maps `[meta, target_pdb, pipeline_config]` (drops `design_yaml` + CIF structure files)
- ✅ `CONVERT_CIF_TO_PDB` step bypassed — Complexa PDB outputs feed directly to ProteinMPNN
- ✅ ProteinMPNN parallelization updated to iterate over `design_pdbs` emit
- ✅ Downstream pipeline (BOLTZ2_REFOLD → IPSAE → PRODIGY → FOLDSEEK → CONSOLIDATE_METRICS) unchanged

---

## Step 5: Update Schema and Documentation ✅

**Status**: Complete  
**Date**: 2026-04-22  
**⏱ Seqera AI time**: ~5 min (schema rewrite, README samplesheet + params update)

### What changed

- ✅ `nextflow_schema.json` — replaced stale `complexa_options` block (`cache_dir`, `complexa_config`, `steps`) with actual params: `complexa_ckpt_dir`, `complexa_container`, `complexa_search_algorithm`, `complexa_nsteps`, `complexa_replicas`, `complexa_batch_size`, `complexa_extra_args`
- ✅ `nextflow_schema.json` — updated `input` help_text to list correct samplesheet columns (`sample_id`, `target_pdb`, `pipeline_config`, `target_sequence`)
- ✅ `README.md` — replaced BoltzGen samplesheet example with Complexa columns + table of required/optional fields
- ✅ `README.md` — updated Key Parameters section with `--complexa_*` flags and `--run_foldseek`
- ✅ `assets/schema_input_design.json` — already correct (updated in earlier step)

---

## Step 6: Test and Validate

**Status**: Not started

- [ ] Dry-run with `-stub` to verify process wiring
- [ ] Test with a single target on GPU compute environment
- [ ] Verify downstream processes receive expected inputs
