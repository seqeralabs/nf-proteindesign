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
| **RFdiffusion + ProteinMPNN** | Yes (MIT, RosettaCommons) | Yes — Hydra-based `base.yaml` with per-run overrides | Strong — diffusion model, generates backbone CIF/PDB structures, pipeline already uses ProteinMPNN downstream | **Selected** |
| **EvoPro** | Yes (Kuhlman Lab, GitHub) | Yes — `evopro_basic.yaml` in run directory | Weak — genetic algorithm/evolutionary optimizer, not a generative diffusion model; closer in role to ProteinMPNN than Boltzgen | Eliminated |
| **BinderFlow** | Yes | No — uses JSON config (`--json input.json`) | N/A | Eliminated |
| **ProteinDJ** | Yes (PapenfussLab, GitHub) | Yes — YAML via BindSweeper component | Awkward — is itself a full Nextflow pipeline (wraps RFdiffusion + ProteinMPNN + Boltz-2 internally); embedding it as a single module replacement would nest one pipeline inside another | Eliminated |

## Selected Candidate: RFdiffusion

**RFdiffusion** (RosettaCommons/RFdiffusion) is the recommended replacement for Boltzgen for the following reasons:

- **Same generative role:** Like Boltzgen, RFdiffusion is a diffusion model that generates novel protein backbone structures from a design specification. It directly replaces the backbone generation step.
- **YAML/Hydra configuration:** Design parameters are specified via a `base.yaml` and per-run YAML overrides, which aligns with how Boltzgen consumes a design YAML in the current pipeline.
- **Pipeline compatibility:** The `nf-proteindesign` pipeline already uses ProteinMPNN downstream of Boltzgen for sequence optimization. RFdiffusion is designed to pair with ProteinMPNN as its standard downstream step, so the rest of the pipeline remains intact.
- **Output format:** RFdiffusion outputs PDB/CIF structure files, compatible with the `CONVERT_CIF_TO_PDB` and subsequent modules.
- **Active, well-documented project:** Maintained by the Baker Lab (RosettaCommons) with extensive documentation and community adoption.

## Next Steps

- Map RFdiffusion's YAML input schema to Boltzgen's design YAML schema
- Assess changes required to `modules/local/boltzgen_run.nf` to replace the `boltzgen run` CLI call with RFdiffusion's `run_inference.py`
- Verify output structure compatibility with `CONVERT_CIF_TO_PDB` and `IPSAE_CALCULATE` downstream modules
