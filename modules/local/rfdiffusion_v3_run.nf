/*
========================================================================================
    RFDIFFUSION_V3_RUN: Protein backbone design using RFdiffusion3
========================================================================================
    Runs RFdiffusion3 via the RosettaCommons Foundry framework (rfd3 CLI).
    Official container: rosettacommons/foundry

    Design YAML schema (shared with rfdiffusion_v1, rfdiffusion-format):
        contig:       Contig specification string, e.g. "80-120/0 A1-100"
                      Syntax: "[binder_length/0 TargetChain_start-end]"
        hotspot_res:  Optional list of hotspot residues on target, e.g. ["A42","A45"]

    The module converts the YAML spec to the JSON format required by rfd3 and
    organises outputs into the same directory structure as BOLTZGEN_RUN and
    RFDIFFUSION_V1_RUN so all downstream modules are unaffected.

    Input structure files may be PDB or CIF; CIF files are converted automatically.
========================================================================================
*/

process RFDIFFUSION_V3_RUN {
    tag "${meta.id}"
    label 'process_high_gpu'

    publishDir "${params.outdir}/${meta.id}/rfdiffusion", mode: params.publish_dir_mode

    container 'rosettacommons/foundry:latest'

    accelerator 1, type: 'nvidia-gpu'

    input:
    tuple val(meta), path(design_yaml), path(structure_files)
    path cache_dir, stageAs: 'input_cache'

    output:
    tuple val(meta), path("${meta.id}_output"),                                                                    emit: results
    tuple val(meta), path("${meta.id}_output/final_ranked_designs/final_*_designs/*.pdb"), optional: true,         emit: budget_design_cifs
    path "versions.yml",                                                                                            emit: versions

    script:
    def model_cache = cache_dir.name != 'EMPTY_CACHE' ? "\${PWD}/input_cache" : "\${HOME}/.foundry/checkpoints"
    """
    export FOUNDRY_CHECKPOINT_DIRS="${model_cache}"
    export NUMBA_CACHE_DIR=/tmp
    export XDG_CACHE_HOME=/tmp/cache

    mkdir -p ${meta.id}_output/rfd3_raw
    mkdir -p ${meta.id}_output/final_ranked_designs/final_${meta.budget}_designs

    # Convert input structure to PDB if CIF (RFdiffusion3 requires PDB input)
    STRUCT_FILES=(${structure_files})
    RESOLVED_PDB=""
    if [ \${#STRUCT_FILES[@]} -gt 0 ]; then
        FIRST_STRUCT="\${STRUCT_FILES[0]}"
        if [[ "\${FIRST_STRUCT}" == *.cif ]]; then
            python3 -c "
from Bio.PDB import MMCIFParser, PDBIO
import sys
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

    # Convert design YAML to the JSON input format expected by rfd3
    python3 - <<PYEOF
import yaml, json, os

with open('${design_yaml}') as f:
    spec = yaml.safe_load(f)

contig    = spec.get('contig', '100-100')
hotspots  = spec.get('hotspot_res', [])
input_pdb = os.environ.get('RESOLVED_PDB', '')

design_entry = {
    'contig':      contig,
    'num_designs': ${meta.num_designs},
}
if input_pdb:
    design_entry['input_path'] = input_pdb
if hotspots:
    design_entry['hotspot_res'] = hotspots

rfd3_input = {'${meta.id}': design_entry}

with open('rfd3_input.json', 'w') as f:
    json.dump(rfd3_input, f, indent=2)
PYEOF

    # Run RFdiffusion3
    rfd3 design \\
        out_dir=${meta.id}_output/rfd3_raw \\
        inputs=rfd3_input.json

    # Rank outputs: take the first <budget> PDB files and place them in the
    # expected directory structure used by downstream modules
    RANK=1
    for pdb in \$(ls ${meta.id}_output/rfd3_raw/**/*.pdb 2>/dev/null | sort -V | head -n ${meta.budget}); do
        DESIGN_NAME=\$(basename "\${pdb}" .pdb)
        cp "\${pdb}" "${meta.id}_output/final_ranked_designs/final_${meta.budget}_designs/rank\${RANK}_\${DESIGN_NAME}.pdb"
        RANK=\$((RANK + 1))
    done

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        rfdiffusion3: \$(rfd3 --version 2>&1 || echo "foundry")
        python: \$(python3 --version 2>&1 | sed 's/Python //g')
    END_VERSIONS
    """

    stub:
    """
    mkdir -p ${meta.id}_output/rfd3_raw
    mkdir -p ${meta.id}_output/final_ranked_designs/final_${meta.budget}_designs
    touch ${meta.id}_output/rfd3_raw/design_0.pdb
    touch ${meta.id}_output/final_ranked_designs/final_${meta.budget}_designs/rank1_design_0.pdb
    touch ${meta.id}_output/final_ranked_designs/final_${meta.budget}_designs/rank2_design_1.pdb
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        rfdiffusion3: "foundry"
        python: \$(python3 --version 2>&1 | sed 's/Python //g')
    END_VERSIONS
    """
}
