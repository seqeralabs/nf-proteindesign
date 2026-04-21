# Boltzgen Alternatives Assessment

This document records the evaluation of open-source generative AI tools considered as replacements for Boltzgen in the `nf-proteindesign` pipeline.

## Evaluation Criteria

Candidate tools were assessed against three criteria:

1. **Open source** — must be openly licensed and publicly available
2. **YAML-based configuration** — must accept a YAML design spec as input, matching how Boltzgen is invoked in the pipeline
3. **Drop-in suitability** — must perform the same role as Boltzgen: generative backbone/structure creation that feeds into downstream ProteinMPNN → Boltz-2 → analysis steps

## Tools Assessed

| Tool | Licence | YAML Config | Drop-in Suitability | Verdict |
|------|---------|-------------|---------------------|---------|
| **RFdiffusion v1** | BSD-3-Clause (RosettaCommons) | Yes — Hydra-based `base.yaml` with per-run overrides | Strong — diffusion model, generates backbone PDB structures, pipeline already uses ProteinMPNN downstream | **Selected** |
| **RFdiffusion3** | BSD-3-Clause (RosettaCommons) | Yes — Hydra-based via RosettaCommons Foundry framework, compatible with v1 contig syntax | Strong — all-atom successor to v1; expanded capabilities (protein binders, small molecules, DNA, enzymes); substantially faster; same PDB output paradigm | **Selected** |
| **Genie 2** | Apache 2.0 | No — CLI arguments via argparse (`--name`, `--epoch`, `--scale`, `--outdir`) | Strong — SE(3) diffusion model generating novel backbones; multi-motif scaffolding; PDB output compatible with ProteinMPNN; more diverse and novel designs than RFdiffusion v1 | **Candidate** |
| **salad** | MIT | No — CLI arguments; `--config` takes a preset name, not a file path | Strong for large proteins — sparse SE(3) denoising model; up to 100x faster than RFdiffusion v1 for proteins >500 residues; PDB output | **Candidate** |
| ~~**FrameFlow**~~ | ~~MIT~~ | ~~Yes — Hydra-based YAML configs with per-run CLI overrides (`-cn inference_scaffolding.yaml`), same framework as RFdiffusion~~ | ~~SE(3) flow-matching backbone generator; PDB output; does not clearly surpass RFdiffusion v1 on designability or quality metrics; limited wet-lab validation; no meaningful capability gain over v1~~ | ~~Eliminated~~ |
| ~~**BinderFlow**~~ | ~~Yes~~ | ~~No — uses JSON config (`--json input.json`)~~ | ~~Orchestration wrapper around RFdiffusion's `run_inference.py`; PyRosetta licence required for its scoring step; built around SLURM batch job submission, making it architecturally incompatible with an existing Nextflow pipeline~~ | ~~Eliminated~~ |
| ~~**EvoPro**~~ | ~~Yes (Kuhlman Lab, GitHub)~~ | ~~Yes — `evopro_basic.yaml` in run directory~~ | ~~Genetic algorithm/evolutionary optimizer, not a generative diffusion model; iterates over existing sequences rather than generating novel backbones; closer in role to ProteinMPNN than Boltzgen~~ | ~~Eliminated~~ |
| ~~**ProteinDJ**~~ | ~~Yes (PapenfussLab, GitHub)~~ | ~~Yes — YAML via BindSweeper component~~ | ~~Is itself a full Nextflow pipeline (wraps RFdiffusion + ProteinMPNN + Boltz-2 internally); embedding it as a single module replacement would nest one pipeline inside another~~ | ~~Eliminated~~ |

## Selected Candidates: RFdiffusion v1 and v3

Both RFdiffusion v1 and RFdiffusion3 are selected for implementation, with the pipeline offering a user-selectable parameter to invoke either version. See [Pipeline Integration Approach](#pipeline-integration-approach) below.

### v1 vs v3 Comparison

#### Architecture

| Aspect | RFdiffusion v1 | RFdiffusion3 |
|--------|----------------|--------------|
| Diffusion unit | Residue-level frames | Individual atoms |
| Atoms modelled per residue | 4 (backbone only: N, Cα, C, O) | 14 (backbone + all sidechain heavy atoms) |
| Sidechain representation | None | Explicit |
| Codebase | Fine-tuned RoseTTAFold | Complete rewrite — no shared code with v1 |
| Model parameters | Not disclosed | 168M |

The fundamental difference: v1 uses a simplified backbone geometry that ignores precise hydrogen bond geometry, electrostatics, and sidechain packing. v3 models all atomic chemistry explicitly, enabling it to reason about catalytic geometries and ligand interactions that v1 cannot.

#### Design Tasks

| Task | v1 | v3 |
|------|----|----|
| Protein binders | Yes | Yes |
| Motif scaffolding | Yes (single motif) | Yes (single and multi-motif) |
| Symmetric assemblies | Yes | Yes |
| Nanobody/antibody | Binders only | Full antibody design (RFantibody, cryo-EM validated) |
| Peptide binders | Yes | Yes |
| Small molecule co-design | No (rigid ligands only) | Yes (~10–42% success by ligand type) |
| DNA-binding protein design | No | Yes (co-diffusion, ~7–9% AF3-predicted) |
| Enzyme active site design | Very limited (inverse rotamer) | Yes, atom-level (18% multi-turnover hit rate) |

#### Performance

| Benchmark | RFdiffusion v1 | RFdiffusion3 |
|-----------|----------------|--------------|
| Enzyme design (AME benchmark) | 16/41 cases | 41/41 cases |
| Binder diversity (PD-L1, Tie2) | 1.4 successful clusters | 8.2 successful clusters |
| DNA binder (experimental) | Not possible | EC₅₀ = 5.89 ± 2.15 μM |
| Enzyme kcat/Km (best design) | Not possible | 3,557 M⁻¹s⁻¹ (matches natural enzymes) |

#### Speed

v3 is substantially faster than v1 (exact multiplier vs v1 not independently benchmarked; v3 is confirmed 10x faster than its predecessor RFdiffusion2, which was itself faster than v1). In practice, v3 can run thousands of designs in the wall-clock time v1 requires for tens.

#### Input Format

Both use Hydra and the same contig string syntax for specifying design regions (e.g., `[100-100/0 B1-150]`). The invocation differs:

- **v1** — Hydra CLI string parameters, prone to shell escaping issues:
  ```bash
  python scripts/run_inference.py \
    'contigmap.contigs=[100-100/0 B1-150]' \
    inference.input_pdb=target.pdb \
    inference.num_designs=10
  ```

- **v3** — structured JSON input file fed to a clean CLI, more Nextflow-friendly:
  ```bash
  rfd3 design out_dir=rfd3_out inputs=design.json
  ```
  where `design.json` encapsulates all design parameters including contig spec, number of designs, and optional atomic conditioning.

#### Output Format

| Output | RFdiffusion v1 | RFdiffusion3 |
|--------|----------------|--------------|
| Structure files | PDB (backbone only, no sidechains) | PDB (full atom: backbone + sidechains) |
| Metadata | `.trb` files (pLDDT per denoising step, residue mapping) | Optional trajectory dumps |
| Confidence scores | pLDDT (native) | pLDDT (native) |
| Ranking | No built-in ranking; requires post-hoc AF2 reprediction | No built-in ranking; AF3 metrics used downstream |

v3's full-atom PDB output is richer input for ProteinMPNN and Boltz-2, as downstream tools can use sidechain context.

#### Dependencies and Containers

| Aspect | RFdiffusion v1 | RFdiffusion3 |
|--------|----------------|--------------|
| Installation | Complex — custom SE(3)-Transformer, CUDA 11.1 conda env | Simple — `pip install "rc-foundry[rfd3]"` |
| Official Docker image | No | Yes — `rosettacommons/foundry` (DockerHub) |
| TensorRT-optimised containers | No | Yes — A100, A10g, L40, H100 |
| NVIDIA NIM support | No | Yes |

#### Maturity and Validation

| Aspect | RFdiffusion v1 | RFdiffusion3 |
|--------|----------------|--------------|
| Publication | *Nature* 2023 | bioRxiv December 2025 |
| Age | ~2.5 years | ~4 months |
| Wet-lab validations | Hundreds of designs; crystal structures, cryo-EM, ITC | Enzymes (35/190), DNA binders, antibodies — strong but lower N |
| Community adoption | Extensive — used in many labs worldwide | Rapidly growing |
| Edge cases documented | Yes — extensive GitHub issue history | Limited so far |

#### Known Limitations

**RFdiffusion v1:**
- Backbone-only output; sidechains require separate prediction
- Cannot design around unspecified ligand conformations or DNA sequences
- No official Docker container; fragile conda environment setup
- Slower inference; Hydra CLI string escaping is fragile in pipeline scripts
- Requires tens of thousands of samples for some design challenges

**RFdiffusion3:**
- Very new (~4 months old); fewer long-term robustness guarantees
- Ligand design success rates vary widely by ligand type (10–42%)
- DNA binding design has modest success rates (~7–9% AF3-predicted)
- HBPLUS required for advanced hydrogen bond conditioning (additional dependency)
- Fewer community-reported edge cases and workarounds available

---

## Pipeline Integration Approach

Both v1 and v3 will be supported in nf-proteindesign via a user-selectable parameter (`rfdiffusion_version`), defaulting to v3. The implementation will use two separate Nextflow process modules — one per version — with a workflow-level conditional in `workflows/protein_design.nf`. This follows the existing pattern of optional modules in the pipeline (e.g., `run_proteinmpnn`, `run_boltz2`).

**Why two separate modules rather than one module with internal branching:**
- Each version has a different container, entrypoint, and input format — keeping them in separate files makes each independently maintainable and testable
- Follows the existing DSL2 convention in the pipeline (one process per tool)
- Allows containers and resource labels to be specified independently

**Input handling:**
- Both versions use the same contig syntax, so the YAML design spec can be shared
- v3 requires a JSON input file; the module will generate this from the pipeline's existing YAML spec
- v1 passes parameters directly via Hydra CLI

**Output compatibility:**
- Both produce PDB files, so all downstream modules (`CONVERT_CIF_TO_PDB`, ProteinMPNN, Boltz-2, IPSAE, PRODIGY, Foldseek) are unaffected regardless of which version is used

---

## Additional Candidates

Two further candidates remain under consideration (Genie 2 and salad) but require YAML config adapters since they use CLI argument-based invocation. They are not part of the current implementation scope.

### Genie 2

- **GitHub:** [aqlaboratory/genie2](https://github.com/aqlaboratory/genie2)
- **Published:** arXiv May 2024; ICLR 2025
- **What it does:** SE(3) diffusion model trained on the full structural universe (PDB + computed structures), generating novel protein backbones unconditionally or conditioned on one or more functional motifs. Key capability: **multi-motif scaffolding** — can simultaneously scaffold multiple binding interfaces or functional sites in a single design, a task RFdiffusion v1 cannot do.
- **Improvement over RFdiffusion v1:** More diverse and novel backbones (63% more unique solutions on the single-motif scaffolding benchmark); solves 4/6 multi-motif benchmark tasks vs 0/6 for v1. Fully permissive Apache 2.0 licence.
- **Output:** PDB backbone files — compatible with ProteinMPNN downstream.
- **Limitation:** 20x slower sampling than RFdiffusion v1 (1,000 denoising steps vs 50). Requires A100/H100-class GPU for practical throughput. CLI-only invocation requires a config adapter layer.

### salad

- **GitHub:** [mjendrusch/salad](https://github.com/mjendrusch/salad)
- **Published:** *Nature Machine Intelligence* 2025
- **What it does:** Sparse all-atom denoising model using O(N·K) sparse attention instead of O(N²). Generates protein backbones and supports motif scaffolding and multi-state design.
- **Improvement over RFdiffusion v1:** Up to 100x faster for large proteins (>500 residues); matches or exceeds state-of-the-art designability and diversity metrics.
- **Output:** PDB backbone files — compatible with ProteinMPNN downstream.
- **Limitation:** CLI-only invocation requires a config adapter layer. Newer and less experimentally validated than RFdiffusion v1.

---

## Eliminated Candidates

### FrameFlow

Eliminated because it does not meaningfully improve on RFdiffusion v1 — competitive designability on standard benchmarks but no clear quality advantage, limited wet-lab validation, and no capability gains that would justify the integration cost over the already-selected RFdiffusion options.

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

---

## Next Steps

- Implement `modules/local/rfdiffusion_v1_run.nf` — wraps `run_inference.py` with Hydra CLI, maps YAML design spec to contig params, outputs PDB + `.trb` files
- Implement `modules/local/rfdiffusion_v3_run.nf` — wraps `rfd3 design` via `rosettacommons/foundry` Docker image, converts YAML design spec to JSON input, outputs full-atom PDB files
- Add `rfdiffusion_version` parameter to `nextflow.config` (default: `v3`)
- Wire workflow-level conditional in `workflows/protein_design.nf` to invoke the appropriate module
- Verify output PDB compatibility with `CONVERT_CIF_TO_PDB` and `IPSAE_CALCULATE` for both versions
- Map Boltzgen's design YAML schema to the shared RFdiffusion contig input format
