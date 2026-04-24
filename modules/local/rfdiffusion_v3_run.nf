/*
========================================================================================
    RFDIFFUSION_V3_RUN: Protein backbone design using RFdiffusion3
========================================================================================
    Runs RFdiffusion3 via the RosettaCommons Foundry framework (rfd3 CLI).
    Official container: rosettacommons/foundry
    Docs: https://github.com/RosettaCommons/foundry/blob/production/models/rfd3/README.md

    Design YAML schema (rfd3 format):
        contig:            Contig specification string using comma-separated segments.
                           e.g. "80-120,/0,A1-100"
                           Syntax: "<binder_length>,/0,<TargetChain><start>-<end>"
        select_hotspots:   Optional dict of target residues → atom names for hotspot
                           biasing, e.g. {"A42": "CA,CB", "A45": "CG"}
        is_non_loopy:      Recommended true for PPI binder design (more structured).

    The rfd3 CLI takes two required arguments:
        rfd3 design out_dir=<path> inputs=<path/to/json_or_yaml>
    The input PDB path is specified INSIDE the JSON spec via the "input" field,
    not as a separate CLI argument.

    Number of designs is controlled via CLI args:
        n_batches (default 1) × diffusion_batch_size (default 8) = total designs

    Input structure files must be PDB format. CIF→PDB conversion should be done
    upstream (e.g. via CONVERT_CIF_TO_PDB) before calling this module.
========================================================================================
*/

process RFDIFFUSION_V3_RUN {
    tag "${meta.id}"
    label 'process_high_gpu'

    publishDir "${params.outdir}/${meta.id}/rfdiffusion_v3", mode: params.publish_dir_mode

    container "${params.rfdiffusion_v3_container}"

    accelerator 1, type: 'nvidia-gpu'

    input:
    tuple val(meta), path(design_yaml), path(structure_files)
    path(cache_dir, stageAs: 'input_cache', arity: '0..*')

    output:
    // Full results directory
    tuple val(meta), path("${meta.id}_output"),                                                  emit: results

    // Generated PDB design files — ranked top-N (budget) for downstream analysis
    tuple val(meta), path("${meta.id}_output/designs/*.pdb"), optional: true,                    emit: design_pdbs

    path "versions.yml",                                                                          emit: versions

    script:
    def model_cache  = cache_dir ? "\${PWD}/input_cache" : "\${HOME}/.foundry/checkpoints"
    def num_designs  = meta.num_designs ?: 10
    def budget       = meta.budget ?: 4
    // rfd3 controls total designs via n_batches × diffusion_batch_size (default 8).
    // We set diffusion_batch_size = num_designs and n_batches = 1.
    def batch_size   = num_designs
    """
    set -euo pipefail

    # ── Environment setup ──
    export FOUNDRY_CHECKPOINT_DIRS="${model_cache}"
    export NUMBA_CACHE_DIR=/tmp/numba
    export XDG_CACHE_HOME=/tmp/cache
    mkdir -p /tmp/numba /tmp/cache

    mkdir -p ${meta.id}_output/rfd3_raw
    mkdir -p ${meta.id}_output/designs

    # ── Resolve input PDB structure ──
    # CIF→PDB conversion is handled upstream by CONVERT_CIF_TO_PDB
    STRUCT_FILES=(${structure_files})
    RESOLVED_PDB=""
    if [ \${#STRUCT_FILES[@]} -gt 0 ]; then
        RESOLVED_PDB="\${PWD}/\${STRUCT_FILES[0]}"
    fi

    if [ -z "\${RESOLVED_PDB}" ]; then
        echo "ERROR: No input PDB structure found. RFdiffusion3 requires a target structure." >&2
        echo "  structure_files input: ${structure_files}" >&2
        exit 1
    fi
    if [ ! -f "\${RESOLVED_PDB}" ]; then
        echo "ERROR: Input PDB not found at: \${RESOLVED_PDB}" >&2
        ls -la \${PWD}/ >&2
        exit 1
    fi
    echo "Using input structure: \${RESOLVED_PDB}"

    # ── Convert design YAML to rfd3 JSON InputSpecification ──
    # The PDB path goes inside the JSON spec as the "input" field.
    # Ref: https://github.com/RosettaCommons/foundry/blob/production/models/rfd3/docs/input.md
    python3 - <<'PYEOF'
import yaml, json, pathlib

with open('${design_yaml}') as f:
    spec = yaml.safe_load(f)

# Contig — rfd3 expects a single contig **string**.
# rfd3 uses "/" as chain break (NOT "/0" like RFdiffusion v1).
# v1 syntax: "80-120/0 A1-100"  →  rfd3 syntax: "80-120/A1-100"
#
# Normalisation steps:
#   1. Strip commas (our YAML may use "80-120,/0,A1-100")
#   2. Convert v1 "/0" chain breaks to rfd3 "/" chain breaks
#   3. Remove extraneous spaces around slashes
raw_contig = spec.get('contig', '100-100')

# If YAML provides a list, join back to a string
if isinstance(raw_contig, list):
    raw_contig = ' '.join(str(s) for s in raw_contig)

# Normalise: remove commas → collapse spaces → convert /0 to /
contig = raw_contig.replace(',', ' ')       # commas to spaces
contig = ' '.join(contig.split())           # collapse whitespace
# v1 chain break "/0" → rfd3 chain break "/"
import re
contig = re.sub(r'/0(?=\s|$)', '/', contig)
# Remove spaces around slashes: "80-120 / A1-100" → "80-120/A1-100"
contig = re.sub(r'\s*/\s*', '/', contig)

# Build the rfd3 InputSpecification entry
design_entry = {
    'dialect':              2,
    'input':                '${meta.id}_target.pdb',   # resolved PDB path (symlinked below)
    'contig':               contig,
    'is_non_loopy':         spec.get('is_non_loopy', True),
}

# Hotspots: rfd3 uses "select_hotspots" dict with atom selections.
# Accept both the rfd3-native dict form and a simple residue list.
hotspots = spec.get('select_hotspots', spec.get('hotspot_res', None))
if hotspots:
    if isinstance(hotspots, dict):
        # Already in rfd3 native format: {"A42": "CA,CB", ...}
        design_entry['select_hotspots'] = hotspots
        design_entry['infer_ori_strategy'] = 'hotspots'
    elif isinstance(hotspots, list) and len(hotspots) > 0:
        # Convert simple list ["A42", "A45"] → dict with empty atom selection
        design_entry['select_hotspots'] = {r: '' for r in hotspots}
        design_entry['infer_ori_strategy'] = 'hotspots'

# Pass through any additional rfd3-native fields from the YAML
for key in ('select_fixed_atoms', 'select_unfixed_sequence', 'ligand',
            'length', 'unindex', 'partial_t', 'infer_ori_strategy',
            'cif_parser_args'):
    if key in spec and key not in design_entry:
        design_entry[key] = spec[key]

rfd3_input = {'${meta.id}': design_entry}

with open('rfd3_input.json', 'w') as f:
    json.dump(rfd3_input, f, indent=2)

print("Generated rfd3_input.json:")
print(json.dumps(rfd3_input, indent=2))
PYEOF

    # ── Symlink PDB so the path in the JSON spec resolves ──
    ln -sf "\${RESOLVED_PDB}" "${meta.id}_target.pdb"

    # ── Run RFdiffusion3 ──
    # CLI reference: https://github.com/RosettaCommons/foundry/blob/production/models/rfd3/docs/input.md
    # Required: out_dir, inputs
    # Recommended PPI overrides: step_scale=3, gamma_0=0.2
    rfd3 design \\
        out_dir=${meta.id}_output/rfd3_raw \\
        inputs=rfd3_input.json \\
        n_batches=1 \\
        diffusion_batch_size=${batch_size} \\
        inference_sampler.step_scale=3 \\
        inference_sampler.gamma_0=0.2 \\
        skip_existing=False \\
        prevalidate_inputs=True

    # ── Rank and collect top designs ──
    # rfd3 outputs PDB files into the out_dir. Collect the first <budget>.
    RANK=1
    for pdb in \$(find ${meta.id}_output/rfd3_raw -name "*.pdb" 2>/dev/null | sort -V | head -n ${budget}); do
        DESIGN_NAME=\$(basename "\${pdb}" .pdb)
        cp "\${pdb}" "${meta.id}_output/designs/rank\${RANK}_\${DESIGN_NAME}.pdb"
        RANK=\$((RANK + 1))
    done

    # ── Version information ──
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        rfdiffusion3: \$(pip show rc-foundry 2>/dev/null | grep Version | cut -d' ' -f2 || echo "unknown")
        python: \$(python3 --version 2>&1 | sed 's/Python //g')
    END_VERSIONS
    """

    stub:
    """
    mkdir -p ${meta.id}_output/rfd3_raw
    mkdir -p ${meta.id}_output/designs

    # Create stub PDB files
    touch ${meta.id}_output/rfd3_raw/design_0.pdb
    touch ${meta.id}_output/rfd3_raw/design_1.pdb
    touch ${meta.id}_output/designs/rank1_design_0.pdb
    touch ${meta.id}_output/designs/rank2_design_1.pdb

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        rfdiffusion3: "stub"
        python: \$(python3 --version 2>&1 | sed 's/Python //g')
    END_VERSIONS
    """
}
