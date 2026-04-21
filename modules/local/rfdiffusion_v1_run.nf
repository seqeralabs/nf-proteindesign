/*
========================================================================================
    RFDIFFUSION_V1_RUN: Protein backbone design using RFdiffusion v1
========================================================================================
    Runs RFdiffusion v1 (RosettaCommons/RFdiffusion) via run_inference.py.

    Design YAML schema (rfdiffusion-format, differs from Boltzgen):
        contig:       Contig specification string, e.g. "80-120/0 A1-100"
                      Syntax: "[binder_length/0 TargetChain_start-end]"
        hotspot_res:  Optional list of hotspot residues on target, e.g. ["A42","A45"]

    Input structure files may be PDB or CIF; CIF files are converted automatically.

    Container note: update the container URI below to match your available image.
    The community image docker.io/rwgdrummer/rfdiffusion ships run_inference.py
    at /app/RFdiffusion/scripts/run_inference.py.
========================================================================================
*/

process RFDIFFUSION_V1_RUN {
    tag "${meta.id}"
    label 'process_high_gpu'

    publishDir "${params.outdir}/${meta.id}/rfdiffusion", mode: params.publish_dir_mode

    container 'docker.io/rwgdrummer/rfdiffusion:latest'

    accelerator 1, type: 'nvidia-gpu'

    input:
    tuple val(meta), path(design_yaml), path(structure_files)
    path cache_dir, stageAs: 'input_cache'

    output:
    tuple val(meta), path("${meta.id}_output"),                                                                    emit: results
    tuple val(meta), path("${meta.id}_output/final_ranked_designs/final_*_designs/*.pdb"), optional: true,         emit: budget_design_cifs
    path "versions.yml",                                                                                            emit: versions

    script:
    def model_cache = cache_dir.name != 'EMPTY_CACHE' ? "\${PWD}/input_cache" : "\${HOME}/.cache/RFdiffusion"
    """
    export DGLBACKEND=pytorch
    export HYDRA_FULL_ERROR=1

    mkdir -p ${meta.id}_output/designs
    mkdir -p ${meta.id}_output/final_ranked_designs/final_${meta.budget}_designs

    # Convert input structure to PDB if CIF (RFdiffusion v1 requires PDB input)
    INPUT_PDB_ARG=""
    STRUCT_FILES=(${structure_files})
    if [ \${#STRUCT_FILES[@]} -gt 0 ]; then
        FIRST_STRUCT="\${STRUCT_FILES[0]}"
        if [[ "\${FIRST_STRUCT}" == *.cif ]]; then
            python3 - <<'PYEOF'
from Bio.PDB import MMCIFParser, PDBIO
import sys, os
parser = MMCIFParser(QUIET=True)
structure = parser.get_structure('target', os.environ.get('FIRST_STRUCT', sys.argv[1]))
io = PDBIO()
io.set_structure(structure)
io.save('target_structure.pdb')
PYEOF
            FIRST_STRUCT="target_structure.pdb"
        fi
        INPUT_PDB_ARG="inference.input_pdb=\${FIRST_STRUCT}"
    fi

    # Parse contig and optional hotspot residues from design YAML
    CONTIG=\$(python3 -c "
import yaml
with open('${design_yaml}') as f:
    d = yaml.safe_load(f)
print(d.get('contig', '100-100'))
")

    HOTSPOT=\$(python3 -c "
import yaml
with open('${design_yaml}') as f:
    d = yaml.safe_load(f)
hrs = d.get('hotspot_res', [])
print(','.join(str(r) for r in hrs) if hrs else '')
")

    HOTSPOT_ARG=""
    if [ -n "\${HOTSPOT}" ]; then
        HOTSPOT_ARG="ppi.hotspot_res=[\${HOTSPOT}]"
    fi

    # Run RFdiffusion v1
    python /app/RFdiffusion/scripts/run_inference.py \\
        "contigmap.contigs=[\${CONTIG}]" \\
        inference.output_prefix=${meta.id}_output/designs/design \\
        inference.num_designs=${meta.num_designs} \\
        \${INPUT_PDB_ARG} \\
        \${HOTSPOT_ARG}

    # Rank outputs: take the first <budget> designs and place them in the
    # expected directory structure used by downstream modules
    RANK=1
    for pdb in \$(ls ${meta.id}_output/designs/design_*.pdb 2>/dev/null | sort -V | head -n ${meta.budget}); do
        DESIGN_NAME=\$(basename "\${pdb}" .pdb)
        cp "\${pdb}" "${meta.id}_output/final_ranked_designs/final_${meta.budget}_designs/rank\${RANK}_\${DESIGN_NAME}.pdb"
        RANK=\$((RANK + 1))
    done

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        rfdiffusion: "v1"
        python: \$(python3 --version 2>&1 | sed 's/Python //g')
    END_VERSIONS
    """

    stub:
    """
    mkdir -p ${meta.id}_output/designs
    mkdir -p ${meta.id}_output/final_ranked_designs/final_${meta.budget}_designs
    touch ${meta.id}_output/designs/design_0.pdb
    touch ${meta.id}_output/final_ranked_designs/final_${meta.budget}_designs/rank1_design_0.pdb
    touch ${meta.id}_output/final_ranked_designs/final_${meta.budget}_designs/rank2_design_1.pdb
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        rfdiffusion: "v1"
        python: \$(python3 --version 2>&1 | sed 's/Python //g')
    END_VERSIONS
    """
}
