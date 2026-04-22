# Proteina-Complexa Integration Guide

This document is a complete technical record of the Proteina-Complexa integration into
`nf-proteindesign`. It is intended as a self-contained handoff reference — enough context
to reproduce, extend, or debug the integration without access to the original development
conversation.

---

## Background

`nf-proteindesign` is a Nextflow DSL2 pipeline for AI-powered protein binder design. The
backbone design step was originally performed exclusively by **Boltzgen** (Seqera's
diffusion model). The pipeline has been extended to support **Proteina-Complexa** (NVIDIA,
ICLR 2026) as a user-selectable alternative, invoked via the `--design_tool` parameter.

**Why Proteina-Complexa:**
- Apache 2.0 licence — no commercial or academic restrictions
- Published ICLR 2026 (accepted oral); released March 2026 — newer than Boltzgen
- Flow-based generative model (160M parameters) that co-designs sequence and backbone
  structure in a single pass, eliminating the need for a separate inverse-folding step
- Clean `complexa design` CLI with YAML config and Docker container
- Supports protein binders, ligand binders, and enzyme/motif scaffolding

**What was removed:**
- RFdiffusion v3 (`rfdiffusion_v3`) was the previous alternative to Boltzgen and has been
  fully removed. Proteina-Complexa replaces it.

---

## Repository Layout (relevant files)

```
nf-proteindesign/
├── main.nf                                          # Entry point; banner tool label updated
├── nextflow.config                                  # design_tool param + test profile registered
├── nextflow_schema.json                             # design_tool enum updated
├── conf/
│   ├── base.config                                  # PROTEINA_COMPLEXA_RUN resource block
│   └── test_design_proteina_complexa.config         # NEW: test profile
├── workflows/
│   └── protein_design.nf                            # Routes to DESIGN_PROTEINA_COMPLEXA
├── subworkflows/local/
│   ├── design_boltzgen.nf                           # Unchanged
│   └── design_proteina_complexa.nf                  # NEW: thin subworkflow wrapper
├── modules/local/
│   ├── boltzgen_run.nf                              # Unchanged
│   └── proteina_complexa_run.nf                     # NEW: core process module
└── assets/test_data/
    ├── proteina_complexa_design.yaml                # NEW: Nipah Glycoprotein design spec
    └── samplesheet_design_proteina_complexa.csv     # NEW: test samplesheet
```

---

## Parameter Reference

| Parameter | Default | Options | Description |
|-----------|---------|---------|-------------|
| `--design_tool` | `boltzgen` | `boltzgen`, `proteina_complexa` | Selects backbone design tool |
| `--cache_dir` | `null` | directory path | Model weights cache; falls back to `~/.cache/proteina_complexa` |

All downstream parameters (`--mpnn_*`, `--boltz2_*`, `--run_ipsae`, etc.) are
tool-agnostic and unchanged.

---

## Design YAML Format

Each samplesheet row references a **design spec YAML** specific to Proteina-Complexa.
This is a simplified spec — the module converts it to the full Hydra config internally.

```yaml
# proteina_complexa_design.yaml
task_name: "nipah_binder"      # Identifier for this design run
binder_length: [60, 80]        # [min, max] residues for the designed binder
hotspot_res: []                # Optional: target residues to bias towards, e.g. ["A30","A50"]
model: "protein"               # "protein" (binder), "ligand", or "ame" (enzyme/motif)
```

**Model checkpoint mapping:**

| `model` value | Checkpoint used |
|---|---|
| `protein` | `complexa.ckpt` |
| `ligand` | `complexa_ligand.ckpt` |
| `ame` | `complexa_ame.ckpt` |

---

## Samplesheet Format

Same schema as the existing Boltzgen samplesheet (`assets/schema_input_design.json`).
The `protocol` column (Boltzgen-specific) is not used and can be omitted.

```csv
sample_id,design_yaml,structure_files,num_designs,budget,target_msa,target_sequence,target_template
design1_complexa,assets/test_data/proteina_complexa_design.yaml,assets/test_data/nipah_virus_Glycoprotein_competition_structure.cif,3,2,assets/test_data/nipah_glycoprotein_msa_Uniref30_2302.a3m,assets/test_data/nipah_virus_target_sequence_glycoproteinG.fasta,
```

Required columns: `sample_id`, `design_yaml`, `target_sequence`
Used by module: `structure_files`, `num_designs`, `budget`

---

## Module Behaviour: `PROTEINA_COMPLEXA_RUN`

**File:** `modules/local/proteina_complexa_run.nf`

**Input channel shape:** `[meta, design_yaml, structure_files]`
- `meta` must include: `id`, `num_designs`, `budget`

**What the script does:**
1. If `structure_files` contains a CIF, converts it to PDB via BioPython
2. Parses the design spec YAML with Python and generates a full Hydra-compatible
   `complexa_config.yaml` with absolute paths for checkpoints and target structure
3. Runs `complexa design complexa_config.yaml ++run_name=<meta.id> ++generation.task_name=<task_name>`
4. Collects all PDB files matching `*/generated_pdbs/*.pdb`, sorts by filename, and copies
   the top `meta.budget` files into the standard ranked output directory used by all
   downstream modules

**Output channel shape:**
```
results            → [meta, path("${meta.id}_output")]
budget_design_cifs → [meta, path("${meta.id}_output/final_ranked_designs/final_*_designs/*.pdb")]
versions           → path("versions.yml")
```

**Generated config structure:**
```yaml
ckpt_path:             <cache_dir>/checkpoints
ckpt_name:             complexa.ckpt            # varies by model type
autoencoder_ckpt_path: <cache_dir>/checkpoints/autoencoder.ckpt
gen_njobs:  1
eval_njobs: 1
output_dir: <meta.id>_output/complexa_raw
generation:
  n_samples: <meta.num_designs>
  task_name: <task_name>
tasks:
  <task_name>:
    target_pdb:    /abs/path/to/target.pdb
    binder_length: [60, 80]
    hotspot_res:   []          # omitted if empty
```

**Container:** `proteina-complexa:latest`
Must be built locally — see Docker section below. No pre-built image is published.

**Resource allocation (conf/base.config):**
```
time   = 24h × attempt
memory = 40GB × attempt
GPU    = 1 (nvidia-gpu)
containerOptions = '--gpus all'
```

---

## Docker Container Build

No official pre-built image exists. Build from the GitHub repository on a
**Linux/amd64** machine with Docker installed (Apple Silicon is not supported):

```bash
git clone https://github.com/NVIDIA-Digital-Bio/Proteina-Complexa
cd Proteina-Complexa
docker build -t proteina-complexa:latest -f env/docker/Dockerfile .
```

The built image includes:
- `complexa` CLI
- AlphaFold2, RoseTTAFold3, DSSP, FoldSeek (pre-configured paths)
- All Python dependencies

**Pushing to a registry (for use on Seqera Platform):**
```bash
docker tag proteina-complexa:latest <your-registry>/proteina-complexa:latest
docker push <your-registry>/proteina-complexa:latest
```
Then update the `container` directive in `modules/local/proteina_complexa_run.nf` to
the full registry path.

---

## Model Weights Setup

Weights are distributed via NVIDIA NGC and Hugging Face. Inside the container:

```bash
complexa init          # Creates .env file; set checkpoint/tool paths interactively
complexa download --all   # Downloads all model variants (~several GB)
```

**Available model weight variants on Hugging Face:**
- `nvidia/NV-Proteina-Complexa-Protein-Target-160M-v1` — protein binder design
- `nvidia/NV-Proteina-Complexa-Ligand-160M-v1` — small molecule binder design
- `nvidia/NV-Proteina-Complexa-AME-160M-v1` — enzyme / motif scaffolding

**Expected weights directory structure (cache_dir):**
```
<cache_dir>/
└── checkpoints/
    ├── complexa.ckpt
    ├── complexa_ligand.ckpt
    ├── complexa_ame.ckpt
    └── autoencoder.ckpt
```

> **Note:** The autoencoder checkpoint filename (`autoencoder.ckpt`) is assumed based on
> available documentation. Verify the actual filename after running `complexa download --all`
> and update `proteina_complexa_run.nf` if it differs.

Pass the weights directory to the pipeline:
```bash
nextflow run main.nf -profile test_design_proteina_complexa,docker \
    --cache_dir /path/to/cache_dir
```

---

## Running the Test Profile

**Stub test (no GPU, no container required):**
```bash
nextflow run main.nf -profile test_design_proteina_complexa -stub-run
```

**Validate config before a full run (inside the container):**
```bash
complexa validate design complexa_config.yaml
```
Run this manually with the generated config to catch path/schema errors before
committing GPU time.

**Full test run (requires Linux/amd64, NVIDIA GPU, Docker):**
```bash
nextflow run main.nf -profile test_design_proteina_complexa,docker \
    --cache_dir /path/to/weights
```

**Expected runtime on A100:** ~1–1.5 hours
- Proteina-Complexa design (3 binders, internal AF2/RF3 evaluation): ~30–60 min
- ProteinMPNN (2 designs × 2 sequences, reduced settings): ~5 min
- Boltz-2 refolding (recycling=1, diffusion=1): ~20–30 min
- Analysis (IPSAE, PRODIGY, consolidation): ~5 min

---

## Files Changed

### Created
| File | Purpose |
|------|---------|
| `modules/local/proteina_complexa_run.nf` | Core Nextflow process module |
| `subworkflows/local/design_proteina_complexa.nf` | Subworkflow wrapping the module |
| `assets/test_data/proteina_complexa_design.yaml` | Nipah Glycoprotein design spec (test data) |
| `assets/test_data/samplesheet_design_proteina_complexa.csv` | Test samplesheet |
| `conf/test_design_proteina_complexa.config` | Test profile config |

### Modified
| File | Change |
|------|--------|
| `workflows/protein_design.nf` | Replaced `DESIGN_RFDIFFUSION` import and branch with `DESIGN_PROTEINA_COMPLEXA` |
| `nextflow.config` | Updated `design_tool` comment; registered `test_design_proteina_complexa` profile |
| `nextflow_schema.json` | Updated `design_tool` enum and help text |
| `conf/base.config` | Replaced `RFDIFFUSION_V3_RUN` block with `PROTEINA_COMPLEXA_RUN` |
| `main.nf` | Updated banner tool label map |

### Deleted
| File | Reason |
|------|--------|
| `modules/local/rfdiffusion_v3_run.nf` | Replaced by Proteina-Complexa |
| `subworkflows/local/design_rfdiffusion.nf` | Replaced by Proteina-Complexa |
| `conf/test_design_rfdiffusion_v3.config` | Replaced by Proteina-Complexa test profile |
| `assets/test_data/nipah_rfdiffusion_design.yaml` | Replaced by Proteina-Complexa design YAML |
| `assets/test_data/samplesheet_design_rfdiffusion.csv` | Replaced by Proteina-Complexa samplesheet |

---

## Known Assumptions to Verify on First Real Run

1. **Autoencoder checkpoint filename** — assumed to be `autoencoder.ckpt`. If the actual
   filename differs, update the `autoencoder_ckpt_path` line in the Python config
   generator inside `proteina_complexa_run.nf`.

2. **Output PDB location** — the module uses `find . -path "*/generated_pdbs/*.pdb"` to
   collect ranked outputs robustly. If Proteina-Complexa changes its output directory
   structure in future versions, this glob may need updating.

3. **`output_dir` config key** — assumed to redirect Proteina-Complexa's output root.
   If this key is not honoured and outputs always go to `./outputs/`, the `find` command
   will still collect them correctly since it searches from the work directory root.

4. **Internal AF2/RF3 evaluation** — Proteina-Complexa runs structure prediction
   internally during the evaluate stage. The container must have valid AF2/RF3 weights
   configured (set up during `complexa init`). Ensure these paths are reachable from
   inside the Nextflow work directory or passed via `containerOptions` volume mounts.

---

## Seqera Platform Notes

- Set `--cache_dir` to an S3 or NFS path accessible from compute nodes for model weights
- The container must be pushed to a registry accessible by the compute environment
  (e.g., AWS ECR, GitHub Container Registry, or Seqera's internal registry)
- GPU compute environment required: NVIDIA GPU with CUDA, `containerOptions = '--gpus all'`
  is already set in `conf/base.config`
- The `test_design_proteina_complexa` profile is the recommended starting point;
  scale `num_designs` and `budget` in the samplesheet for production runs
