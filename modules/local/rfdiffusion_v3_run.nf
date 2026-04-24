/*
========================================================================================
    RFDIFFUSION_V3_RUN: Protein backbone design using RFdiffusion3
========================================================================================
    Runs RFdiffusion3 via the RosettaCommons Foundry framework (rfd3 CLI).
    Official container: rosettacommons/foundry

    Design YAML schema (rfdiffusion-format):
        contig:       Contig specification string, e.g. "80-120/0 A1-100"
                      Syntax: "[binder_length/0 TargetChain_start-end]"
        hotspot_res:  Optional list of hotspot residues on target, e.g. ["A42","A45"]

    The module converts the YAML spec to the JSON format required by rfd3 and
    organises outputs into the same directory structure as the other design tools
    so all downstream modules are unaffected.

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
    def model_cache = cache_dir ? "\${PWD}/input_cache" : "\${HOME}/.foundry/checkpoints"
    def num_designs = meta.num_designs ?: 10
    def budget      = meta.budget ?: 4
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
    export RESOLVED_PDB=""
    if [ \${#STRUCT_FILES[@]} -gt 0 ]; then
        export RESOLVED_PDB="\${PWD}/\${STRUCT_FILES[0]}"
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

    # ── Convert design YAML to rfd3 JSON input ──
    # NOTE: The structure PDB is passed via the rfd3 CLI (pdb=<path>), NOT inside
    # the JSON spec.  The Foundry DesignInputSpecification requires the atom array
    # to be loaded before it can parse contig chain/residue selections like "A1-100".
    # Providing the structure at the CLI level ensures it is loaded first.
    python3 - <<'PYEOF'
import yaml, json, os

with open('${design_yaml}') as f:
    spec = yaml.safe_load(f)

contig    = spec.get('contig', '100-100')
hotspots  = spec.get('hotspot_res', [])

design_entry = {
    'contig':      contig,
    'num_designs': ${num_designs},
}
if hotspots:
    design_entry['hotspot_res'] = hotspots

rfd3_input = {'${meta.id}': design_entry}

with open('rfd3_input.json', 'w') as f:
    json.dump(rfd3_input, f, indent=2)
PYEOF

    # ── Run RFdiffusion3 ──
    # pdb= is provided at CLI level so the atom array is loaded before contig parsing
    rfd3 design \\
        pdb=\${RESOLVED_PDB} \\
        out_dir=${meta.id}_output/rfd3_raw \\
        inputs=rfd3_input.json \\
        skip_existing=False \\
        prevalidate_inputs=True

    # ── Rank and collect top designs ──
    # Take the first <budget> PDB files (sorted by name) into the designs/ directory
    RANK=1
    for pdb in \$(find ${meta.id}_output/rfd3_raw -name "*.pdb" 2>/dev/null | sort -V | head -n ${budget}); do
        DESIGN_NAME=\$(basename "\${pdb}" .pdb)
        cp "\${pdb}" "${meta.id}_output/designs/rank\${RANK}_\${DESIGN_NAME}.pdb"
        RANK=\$((RANK + 1))
    done

    # ── Version information ──
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        rfdiffusion3: \$(rfd3 --version 2>&1 || echo "foundry-cli")
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
