# Proteina-Complexa Integration Guide

This document is a complete technical record of the Proteina-Complexa integration into
`nf-proteindesign`, including verified setup steps obtained by inspecting the actual
repository source. It is intended as a self-contained handoff reference for Seqera AI
or any engineer reproducing this work without access to the original development session.

---

## Background

`nf-proteindesign` is a Nextflow DSL2 pipeline for AI-powered protein binder design. The
backbone design step was originally performed exclusively by **Boltzgen** (Seqera's
diffusion model). The pipeline has been extended to support **Proteina-Complexa** (NVIDIA,
ICLR 2026) as a user-selectable alternative via `--design_tool proteina_complexa`.

**Why Proteina-Complexa:**
- Apache 2.0 licence — no commercial or academic restrictions; presentable at external summits
- ICLR 2026 accepted oral; GitHub released March 2026 — newer than Boltzgen
- Flow-based generative model (160M parameters) that co-designs backbone sequence and
  structure in a single pass
- Supports protein binders, ligand binders, and enzyme/motif scaffolding (AME)
- Clean `complexa design` CLI with YAML config; Docker container provided

**What was removed:** RFdiffusion v3 (`rfdiffusion_v3`) was the previous alternative and
has been fully removed. Proteina-Complexa replaces it entirely.

---

## Step 1: Clone the Repository

> **Status: Completed** — repository cloned to `Desktop/github/Proteina-Complexa`

The Proteina-Complexa repo uses **git-lfs** for a small number of data files
(`assets/data/*.csv`, `assets/pipeline_figure.png`). If `git-lfs` is not installed,
the standard clone will fail at checkout. Use the following workaround to clone all
source code without requiring git-lfs:

```bash
# Disable the LFS filter in the repo's local config post-clone, then restore files
git clone https://github.com/NVIDIA-Digital-Bio/Proteina-Complexa ~/Desktop/github/Proteina-Complexa
cd ~/Desktop/github/Proteina-Complexa
git config filter.lfs.smudge cat
git config filter.lfs.process ""
git config filter.lfs.required false
git checkout HEAD -- .
```

This checks out all Python source, configs, Dockerfile, and scripts. The only files
missing will be the LFS-tracked CSV data files — these are benchmark datasets not needed
for building the container or running the pipeline.

**Result:** Full source tree available at `~/Desktop/github/Proteina-Complexa/`

Key directories confirmed present:
```
Proteina-Complexa/
├── env/
│   ├── docker/
│   │   └── Dockerfile              # Container build file
│   ├── build_uv_env.sh             # Python env installer (used inside Docker)
│   └── download_startup.sh         # Model weights download script
├── configs/                        # Example Hydra YAML configs
├── src/proteinfoundation/          # Main Python package
├── community_models/               # Bundled AF2, RF3, ProteinMPNN, LigandMPNN
├── pyproject.toml
└── README.md
```

---

## Step 2: Build the Docker Container

> **Status: In progress** — building via `--platform linux/amd64` cross-compilation on macOS ARM64

### Build approach: cross-compilation via QEMU

Docker Desktop on macOS ships with QEMU multi-architecture emulation. This allows
building a `linux/amd64` image on an ARM64 Mac using the `--platform` flag. The
resulting image is a valid `linux/amd64` image that runs correctly on Linux/AMD64 + GPU
machines.

```bash
cd ~/Desktop/github/Proteina-Complexa
docker build --platform linux/amd64 \
    -t proteina-complexa:latest \
    -f env/docker/Dockerfile .
```

> **Performance note:** QEMU emulation is 10–100× slower than a native build. Expect
> 60–120 minutes on macOS for this image due to the large NVIDIA PyTorch base (~10 GB)
> and Python dependency compilation. On a native Linux/AMD64 machine the same build
> typically takes 15–30 minutes.

### What the build does (inspected from `Dockerfile` + `build_uv_env.sh`)

1. Pulls `nvcr.io/nvidia/pytorch:24.08-py3` (linux/amd64 variant)
2. Installs `rsync`, `libxrender1`, `libxext6`
3. Runs `build_uv_env.sh` which installs via `uv`:
   - PyTorch 2.7.0 + CUDA 12.6 (`cu126` pre-built wheels)
   - PyTorch Geometric CUDA 12.6 wheels
   - ColabDesign + AlphaFold-ColabFold
   - JAX + CUDA 12 / cudnn91 wheels
   - RoseTTAFold3 via `rc-foundry[all]`
   - `tmol` (compiled from source — install failure is non-fatal, guarded with `|| echo`)
4. Copies all repo files into `/workspace/protein-foundation-models/`
5. Sets ENV paths for RF3, AF2, DSSP, and SC tools

### Optional binaries (`sc`, `dssp`, `hbplus`)

These proprietary scoring binaries are **not** distributed with the repo. Place them in
`env/docker/internal/` before building if available. Without them:
- `SC_EXEC` and `DSSP_EXEC` ENV vars will point to non-existent binaries
- The filter/evaluate scoring stages will have reduced functionality
- The **generate** stage is unaffected and will still produce backbone PDB files

### Requirements for the image to run (not to build)

The image builds anywhere Docker is available. To actually **run** the container and
execute designs:
- **Linux/amd64** host
- **NVIDIA GPU** with CUDA 12.6 driver support
- **NVIDIA Container Toolkit** installed (`nvidia-docker2` or Docker Engine ≥ 19.03 with
  the `--gpus` flag)

### Pushing to a registry (for Seqera Platform)

```bash
docker tag proteina-complexa:latest <your-registry>/proteina-complexa:latest
docker push <your-registry>/proteina-complexa:latest
```

Then update the `container` directive in `modules/local/proteina_complexa_run.nf`:
```groovy
container '<your-registry>/proteina-complexa:latest'
```

The build does the following (inspected from `Dockerfile` and `build_uv_env.sh`):
1. Starts from `nvcr.io/nvidia/pytorch:24.08-py3`
2. Installs `rsync`, `libxrender1`, `libxext6`
3. Runs `build_uv_env.sh` which installs:
   - PyTorch 2.7.0 + CUDA 12.6
   - PyTorch Geometric (CUDA 12.6 wheels)
   - ColabDesign + AlphaFold-ColabFold
   - JAX + CUDA 12 (cudnn91)
   - RoseTTAFold3 via `rc-foundry[all]`
   - LigandMPNN, ProteinMPNN, openfold, colabdesign (bundled in `community_models/`)
4. Copies all repo files into `/workspace/protein-foundation-models/`
5. Sets environment variables for RF3, AF2, DSSP, SC tool paths

The build will **skip** `sc`, `dssp`, and `hbplus` binaries unless they are placed in
`env/docker/internal/` before building. These proprietary binaries are required for
full scoring functionality (hydrogen bond analysis, structure comparison). Without them,
the evaluate and filter stages may have reduced scoring capability but the generate stage
will still function.

### Pushing to a registry (for Seqera Platform)

```bash
docker tag proteina-complexa:latest <your-registry>/proteina-complexa:latest
docker push <your-registry>/proteina-complexa:latest
```

Then update the `container` directive in `modules/local/proteina_complexa_run.nf`:
```groovy
container '<your-registry>/proteina-complexa:latest'
```

---

## Step 3: Download Model Weights

> **Status: Requires container to be built first (Step 2)**

### Weight download script

The official download script is `env/download_startup.sh` (NOT `complexa download`).
Run it from inside the built container or from within an activated uv environment:

```bash
# For protein binder design only (recommended starting point):
cd ~/Desktop/github/Proteina-Complexa
bash env/download_startup.sh --complexa

# For all Complexa model variants:
bash env/download_startup.sh --complexa-all

# For all models including community models (AF2, RF3, ESM2, ProteinMPNN):
bash env/download_startup.sh --everything
```

### Weight files and storage locations

All weights are downloaded **relative to the project root** (`~/Desktop/github/Proteina-Complexa/`):

**Complexa model weights** (downloaded to `ckpts/`):
| File | Purpose | Source |
|------|---------|--------|
| `ckpts/complexa.ckpt` | Protein binder flow matching model | NVIDIA NGC |
| `ckpts/complexa_ae.ckpt` | Protein binder autoencoder | NVIDIA NGC |
| `ckpts/complexa_ligand.ckpt` | Ligand binder flow matching model | NVIDIA NGC |
| `ckpts/complexa_ligand_ae.ckpt` | Ligand binder autoencoder | NVIDIA NGC |
| `ckpts/complexa_ame.ckpt` | Enzyme/motif scaffolding model | NVIDIA NGC |
| `ckpts/complexa_ame_ae.ckpt` | Enzyme/motif autoencoder | NVIDIA NGC |

**Community model weights** (required for internal evaluate/filter stages):
| File | Purpose | Size | Source |
|------|---------|------|--------|
| `community_models/ckpts/AF2/params_model_*.npz` | AlphaFold2 | ~5 GB | Google Storage |
| `community_models/ckpts/RF3/rf3_foundry_01_24_latest_remapped.ckpt` | RoseTTAFold3 | ~2.5 GB | UW IPD |
| `community_models/ckpts/ESM2/` | ESM2 650M | ~2.6 GB | Hugging Face |
| `community_models/ProteinMPNN/` | ProteinMPNN | ~50 MB | GitHub |
| `community_models/LigandMPNN/model_params/` | LigandMPNN | ~500 MB | GitHub |

### Passing the weights directory to the pipeline

When running `nf-proteindesign`, set `--cache_dir` to the **`ckpts/` directory** within
the cloned repo (or wherever you downloaded the Complexa weights):

```bash
nextflow run main.nf \
    -profile test_design_proteina_complexa,docker \
    --cache_dir ~/Desktop/github/Proteina-Complexa/ckpts
```

The module will automatically locate `complexa.ckpt` and `complexa_ae.ckpt` within this
directory.

> **Note:** The community model weights (AF2, RF3, ESM2) must be in the paths expected
> by the Dockerfile ENV variables, which are baked into the container image at build time.
> These paths point to `community_models/ckpts/` inside the container's working directory.
> When building the container, ensure these are present or mount them as volumes.

---

## Step 4: Validate Config Before Full Run

> **Status: Requires built container (Step 2)**

Before launching a GPU run, validate the generated Hydra config to catch errors early:

```bash
# Run a stub test first to generate the config file
nextflow run main.nf -profile test_design_proteina_complexa -stub-run

# Then validate inside the container (replace <workdir> with actual Nextflow work dir)
docker run --rm -v <workdir>:/work proteina-complexa:latest \
    complexa validate design /work/complexa_config.yaml
```

Alternatively, generate the config manually using the Python snippet from the module:
```python
import yaml, os
spec = yaml.safe_load(open('assets/test_data/proteina_complexa_design.yaml'))
# ... (see modules/local/proteina_complexa_run.nf script block for full config generator)
```

---

## Repository Layout (nf-proteindesign files)

```
nf-proteindesign/
├── main.nf                                          # Banner tool label updated
├── nextflow.config                                  # design_tool param + test profile
├── nextflow_schema.json                             # design_tool enum updated
├── conf/
│   ├── base.config                                  # PROTEINA_COMPLEXA_RUN resource block
│   └── test_design_proteina_complexa.config         # Test profile
├── workflows/
│   └── protein_design.nf                            # Routes to DESIGN_PROTEINA_COMPLEXA
├── subworkflows/local/
│   ├── design_boltzgen.nf                           # Unchanged
│   └── design_proteina_complexa.nf                  # Thin subworkflow wrapper
├── modules/local/
│   ├── boltzgen_run.nf                              # Unchanged
│   └── proteina_complexa_run.nf                     # Core process module
├── assets/test_data/
│   ├── proteina_complexa_design.yaml                # Nipah Glycoprotein design spec
│   └── samplesheet_design_proteina_complexa.csv     # Test samplesheet
└── docs/
    └── proteina_complexa_integration.md             # This file
```

---

## Parameter Reference

| Parameter | Default | Options | Description |
|-----------|---------|---------|-------------|
| `--design_tool` | `boltzgen` | `boltzgen`, `proteina_complexa` | Selects backbone design tool |
| `--cache_dir` | `null` | directory path | Path to `ckpts/` directory containing Complexa weights |

All downstream parameters (`--mpnn_*`, `--boltz2_*`, `--run_ipsae`, etc.) are
tool-agnostic and unchanged.

---

## Design YAML Format

Each samplesheet row references a **design spec YAML** for Proteina-Complexa.
The module converts this to the full Hydra config internally.

```yaml
# proteina_complexa_design.yaml
task_name: "nipah_binder"      # Identifier for this design run
binder_length: [60, 80]        # [min, max] residues for the designed binder
hotspot_res: []                # Optional: e.g. ["A30", "A50"]
model: "protein"               # "protein" (binder), "ligand", or "ame" (enzyme/motif)
```

**Model checkpoint mapping** (verified from `download_startup.sh`):

| `model` | Flow matching ckpt | Autoencoder ckpt |
|---|---|---|
| `protein` | `complexa.ckpt` | `complexa_ae.ckpt` |
| `ligand` | `complexa_ligand.ckpt` | `complexa_ligand_ae.ckpt` |
| `ame` | `complexa_ame.ckpt` | `complexa_ame_ae.ckpt` |

---

## Module Behaviour: `PROTEINA_COMPLEXA_RUN`

**File:** `modules/local/proteina_complexa_run.nf`

**Input channel:** `[meta, design_yaml, structure_files]`  
`meta` must include: `id`, `num_designs`, `budget`

**What the script does:**
1. Exports the resolved cache path as `COMPLEXA_CACHE_ROOT` (shell expansion of `${PWD}` or `${HOME}` happens here, so Python can read the absolute path via `os.environ`)
2. If `structure_files` contains a CIF, converts it to PDB via BioPython
3. Exports `RESOLVED_PDB` as env var so the Python config generator can read it
4. Parses the design spec YAML and generates `complexa_config.yaml` with:
   - `ckpt_path` = `COMPLEXA_CACHE_ROOT`
   - `ckpt_name` = e.g. `complexa.ckpt`
   - `autoencoder_ckpt_path` = `<COMPLEXA_CACHE_ROOT>/complexa_ae.ckpt`
   - Task definition with target PDB, binder length, hotspots
5. Runs `complexa design complexa_config.yaml ++run_name=<meta.id> ++generation.task_name=<task_name>`
6. Uses `find . -path "*/generated_pdbs/*.pdb"` to robustly locate ranked outputs regardless of exact output directory structure
7. Copies top `meta.budget` PDBs to `<meta.id>_output/final_ranked_designs/final_<budget>_designs/rank<N>_*.pdb`

**Output channels:**
```
results            → [meta, path("<meta.id>_output")]
budget_design_cifs → [meta, path("<meta.id>_output/final_ranked_designs/final_*_designs/*.pdb")]
versions           → path("versions.yml")
```

**Container:** `proteina-complexa:latest` (must be built locally — see Step 2)

**Resource allocation (`conf/base.config`):**
```
time   = 24h × attempt
memory = 40GB × attempt
GPU    = 1 (nvidia-gpu)
containerOptions = '--gpus all'
```

---

## Samplesheet Format

Same schema as existing Boltzgen samplesheets (`assets/schema_input_design.json`).
The `protocol` column (Boltzgen-specific) is not used and can be omitted.

```csv
sample_id,design_yaml,structure_files,num_designs,budget,target_msa,target_sequence,target_template
design1_complexa,assets/test_data/proteina_complexa_design.yaml,assets/test_data/nipah_virus_Glycoprotein_competition_structure.cif,3,2,assets/test_data/nipah_glycoprotein_msa_Uniref30_2302.a3m,assets/test_data/nipah_virus_target_sequence_glycoproteinG.fasta,
```

Required columns: `sample_id`, `design_yaml`, `target_sequence`

---

## Running the Test Profile

**Stub test (no GPU, no container required — validates pipeline logic):**
```bash
nextflow run main.nf -profile test_design_proteina_complexa -stub-run
```

**Full test run (requires Linux/amd64, NVIDIA GPU, Docker, weights downloaded):**
```bash
nextflow run main.nf \
    -profile test_design_proteina_complexa,docker \
    --cache_dir ~/Desktop/github/Proteina-Complexa/ckpts
```

**Expected runtime on A100:** ~1–1.5 hours
- Proteina-Complexa design (3 binders, internal AF2/RF3 evaluate stage): ~30–60 min
- ProteinMPNN (2 designs × 2 sequences): ~5 min
- Boltz-2 refolding (recycling=1, diffusion=1): ~20–30 min
- Analysis (IPSAE, PRODIGY, consolidation): ~5 min

---

## Files Changed in nf-proteindesign

### Created
| File | Purpose |
|------|---------|
| `modules/local/proteina_complexa_run.nf` | Core Nextflow process module |
| `subworkflows/local/design_proteina_complexa.nf` | Subworkflow wrapper |
| `assets/test_data/proteina_complexa_design.yaml` | Nipah Glycoprotein design spec |
| `assets/test_data/samplesheet_design_proteina_complexa.csv` | Test samplesheet |
| `conf/test_design_proteina_complexa.config` | Test profile config |

### Modified
| File | Change |
|------|--------|
| `workflows/protein_design.nf` | Replaced RFdiffusion import/branch with Proteina-Complexa |
| `nextflow.config` | Updated `design_tool` comment; registered test profile |
| `nextflow_schema.json` | Updated `design_tool` enum and help text |
| `conf/base.config` | Replaced `RFDIFFUSION_V3_RUN` block with `PROTEINA_COMPLEXA_RUN` |
| `main.nf` | Updated banner tool label map |
| `docs/index.md` | Updated overview and mermaid diagram |
| `docs/quick-start.md` | Added Proteina-Complexa YAML format and usage example |

### Deleted (replaced by Proteina-Complexa)
| File | Reason |
|------|--------|
| `modules/local/rfdiffusion_v3_run.nf` | Replaced |
| `subworkflows/local/design_rfdiffusion.nf` | Replaced |
| `conf/test_design_rfdiffusion_v3.config` | Replaced |
| `assets/test_data/nipah_rfdiffusion_design.yaml` | Replaced |
| `assets/test_data/samplesheet_design_rfdiffusion.csv` | Replaced |

---

## Known Issues and Verification Checklist

On first real run, verify:

- [ ] **`COMPLEXA_CACHE_ROOT` resolves correctly** — the shell should expand `${PWD}` or `${HOME}` before Python reads the path via `os.environ.get('COMPLEXA_CACHE_ROOT')`
- [ ] **Checkpoint directory structure** — `--cache_dir` must point to the directory containing `complexa.ckpt` directly (i.e., the `ckpts/` subdirectory of the cloned repo, not the repo root)
- [ ] **Community model paths inside container** — AF2 and RF3 are expected at hardcoded paths baked into the container (`/workspace/.../community_models/ckpts/`). If running without these, the evaluate/filter stages will fail but generate will succeed
- [ ] **Output PDB location** — the module uses `find . -path "*/generated_pdbs/*.pdb"` to collect outputs; verify this glob matches Proteina-Complexa's actual output structure on first run
- [ ] **`sc`/`dssp`/`hbplus` binaries** — absent from the public build; their absence limits scoring in the evaluate stage but does not block generation

---

## Seqera Platform Notes

- `--cache_dir` should point to an S3 or NFS path containing the `ckpts/` weight files
- Community model weights (AF2, RF3, etc.) must be mounted or baked into the container at the paths set by the Dockerfile ENV variables
- Push the built container to a registry accessible from your compute environment (AWS ECR, GitHub Container Registry, or Seqera's internal registry)
- GPU compute environment required: `containerOptions = '--gpus all'` is already set in `conf/base.config`
- The `test_design_proteina_complexa` profile is the recommended starting point; scale `num_designs` and `budget` in the samplesheet for production runs
