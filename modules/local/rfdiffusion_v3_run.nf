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

    Input structure files may be PDB or CIF; CIF files are converted automatically.
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

    # ── Convert input structure to PDB if CIF ──
    # RFdiffusion3 requires PDB input
    STRUCT_FILES=(${structure_files})
    RESOLVED_PDB=""
    if [ \${#STRUCT_FILES[@]} -gt 0 ]; then
        FIRST_STRUCT="\${STRUCT_FILES[0]}"
        if [[ "\${FIRST_STRUCT}" == *.cif ]]; then
            python3 -c "
from Bio.PDB import MMCIFParser, PDBIO
parser = MMCIFParser(QUIET=True)
structure = parser.get_structure('target', '\${FIRST_STRUCT}')
io = PDBIO()
io.set_structure(structure)
io.save('target_structure.pdb')
"
            RESOLVED_PDB="\${PWD}/target_structure.pdb"
        else
            RESOLVED_PDB="\${PWD}/\${FIRST_STRUCT}"
        fi
    fi

    # ── Convert design YAML to rfd3 JSON input ──
    python3 - <<'PYEOF'
import yaml, json, os

with open('${design_yaml}') as f:
    spec = yaml.safe_load(f)

contig    = spec.get('contig', '100-100')
hotspots  = spec.get('hotspot_res', [])
input_pdb = os.environ.get('RESOLVED_PDB', '')

design_entry = {
    'contig':      contig,
    'num_designs': ${num_designs},
}
if input_pdb:
    design_entry['input_path'] = input_pdb
if hotspots:
    design_entry['hotspot_res'] = hotspots

rfd3_input = {'${meta.id}': design_entry}

with open('rfd3_input.json', 'w') as f:
    json.dump(rfd3_input, f, indent=2)
PYEOF

    # ── Run RFdiffusion3 ──
    rfd3 design \\
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
