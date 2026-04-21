# Boltzgen Alternatives Assessment

This document records the evaluation of open-source generative AI tools considered as replacements for Boltzgen in the `nf-proteindesign` pipeline.

## Evaluation Criteria

Candidate tools were assessed against three criteria:

1. **Open source** — must be openly licensed and publicly available
2. **YAML-based configuration** — must accept a YAML design spec as input, matching how Boltzgen is invoked in the pipeline
3. **Drop-in suitability** — must perform the same role as Boltzgen: generative backbone/structure creation that feeds into downstream ProteinMPNN → Boltz-2 → analysis steps

## Tools Assessed

| Tool | Open Source | YAML Config | Drop-in Suitability | Verdict |
|------|-------------|-------------|---------------------|---------|
| **RFdiffusion** | Yes (MIT, RosettaCommons) | Yes — Hydra-based `base.yaml` with per-run overrides | Strong — diffusion model, generates backbone CIF/PDB structures, pipeline already uses ProteinMPNN downstream | **Selected** |
| ~~**BinderFlow**~~ | ~~Yes~~ | ~~No — uses JSON config (`--json input.json`)~~ | ~~Orchestration wrapper around RFdiffusion's `run_inference.py`; PyRosetta licence required for its scoring step; built around SLURM batch job submission, making it architecturally incompatible with an existing Nextflow pipeline~~ | ~~Eliminated~~ |
| ~~**EvoPro**~~ | ~~Yes (Kuhlman Lab, GitHub)~~ | ~~Yes — `evopro_basic.yaml` in run directory~~ | ~~Genetic algorithm/evolutionary optimizer, not a generative diffusion model; iterates over existing sequences rather than generating novel backbones; closer in role to ProteinMPNN than Boltzgen~~ | ~~Eliminated~~ |
| ~~**ProteinDJ**~~ | ~~Yes (PapenfussLab, GitHub)~~ | ~~Yes — YAML via BindSweeper component~~ | ~~Is itself a full Nextflow pipeline (wraps RFdiffusion + ProteinMPNN + Boltz-2 internally); embedding it as a single module replacement would nest one pipeline inside another~~ | ~~Eliminated~~ |

## Selected Candidate: RFdiffusion

**RFdiffusion** (RosettaCommons/RFdiffusion) is the recommended replacement for Boltzgen for the following reasons:

- **Same generative role:** Like Boltzgen, RFdiffusion is a diffusion model that generates novel protein backbone structures from a design specification. It directly replaces the backbone generation step.
- **YAML/Hydra configuration:** Design parameters are specified via a `base.yaml` and per-run YAML overrides, which aligns with how Boltzgen consumes a design YAML in the current pipeline.
- **Pipeline compatibility:** The `nf-proteindesign` pipeline already uses ProteinMPNN downstream of Boltzgen for sequence optimization. RFdiffusion is designed to pair with ProteinMPNN as its standard downstream step, so the rest of the pipeline remains intact.
- **Output format:** RFdiffusion outputs PDB structure files with pLDDT confidence scores natively (no PyRosetta required), compatible with the `CONVERT_CIF_TO_PDB` and subsequent modules.
- **Active, well-documented project:** Maintained by the Baker Lab (RosettaCommons) with extensive documentation and community adoption.

## Eliminated Candidates

### BinderFlow

BinderFlow was eliminated despite being genuinely generative. Investigation of the source code confirmed:

- `rfd.sh` calls RFdiffusion's own `run_inference.py` directly — BinderFlow owns none of the backbone generation logic and is purely an orchestration layer on top of RFdiffusion.
- PyRosetta is used only in the downstream `scoring.sh` step (after backbone generation and ProteinMPNN), not during diffusion. However, PyRosetta requires a commercial licence for non-academic use, adding a licensing constraint that doesn't exist in the current pipeline.
- The orchestration model is built entirely around SLURM batch job submission and polling for completion marker files. There is no clean single entrypoint suitable for wrapping in a Nextflow `process` block, and no Docker or Singularity containers are provided.

Since BinderFlow is a wrapper around RFdiffusion and adds SLURM/licensing complexity with no additional generative capability, integrating RFdiffusion directly is the better path.

### EvoPro

Eliminated because it is a genetic algorithm/evolutionary optimizer, not a generative diffusion model. It iterates over existing sequences rather than generating novel protein backbones from scratch, placing it in the same functional role as ProteinMPNN — which the pipeline already performs downstream.

### ProteinDJ

Eliminated because it is itself a full Nextflow pipeline that internally wraps RFdiffusion + ProteinMPNN + Boltz-2. Embedding it as a single module replacement for Boltzgen would nest one pipeline inside another, duplicating steps already present in `nf-proteindesign`.

## Next Steps

- Map RFdiffusion's YAML input schema to Boltzgen's design YAML schema
- Assess changes required to `modules/local/boltzgen_run.nf` to replace the `boltzgen run` CLI call with RFdiffusion's `run_inference.py`
- Verify output structure compatibility with `CONVERT_CIF_TO_PDB` and `IPSAE_CALCULATE` downstream modules
