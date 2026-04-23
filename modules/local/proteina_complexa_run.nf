/*
========================================================================================
    PROTEINA_COMPLEXA_RUN: Protein backbone design using Proteina-Complexa (NVIDIA)
========================================================================================
    Runs Proteina-Complexa via the `complexa design` CLI.
    Container: proteina-complexa:latest  (build from https://github.com/NVIDIA-Digital-Bio/Proteina-Complexa)

    Design YAML schema (proteina-complexa-format):
        task_name:      Identifier for the design task (string, e.g. "nipah_binder")
        binder_length:  [min, max] residues for the designed binder, e.g. [60, 80]
        hotspot_res:    Optional list of target hotspot residues, e.g. ["A30", "A50"]
        model:          Model variant — "protein" (default), "ligand", or "ame"

    The module constructs the full Proteina-Complexa Hydra config from this spec,
    stages the target structure, and runs all four pipeline stages (generate → filter →
    evaluate → analyze). Raw PDB outputs are collected via a glob in the output block;
    budget-limiting and ranking are handled by Nextflow channel operators in the subworkflow.

    Input structure files may be PDB or CIF; CIF files are converted automatically.
========================================================================================
*/

process PROTEINA_COMPLEXA_RUN {
    tag "${meta.id}"
    label 'process_high_gpu'

    publishDir "${params.outdir}/${meta.id}/proteina_complexa", mode: params.publish_dir_mode

    container '307946633589.dkr.ecr.eu-west-2.amazonaws.com/rashmi/proteina-complexa:latest'

    accelerator 1, type: 'nvidia-gpu'

    input:
    tuple val(meta), path(design_yaml), path(structure_files)
    path cache_dir, stageAs: 'input_cache'

    output:
    tuple val(meta), path("${meta.id}_output"),                                                                   emit: results
    tuple val(meta), path("${meta.id}_output/complexa_raw/**/generated_pdbs/*.pdb"), optional: true,              emit: raw_pdbs
    path "versions.yml",                                                                                           emit: versions

    script:
    def model_cache = cache_dir.name != 'EMPTY_CACHE' ? "\${PWD}/input_cache" : "\${HOME}/.cache/proteina_complexa"
    """
    mkdir -p ${meta.id}_output/complexa_raw

    # Resolve cache path (shell expands ${PWD}/${HOME} here; Python reads it via env var)
    export COMPLEXA_CACHE_ROOT="${model_cache}"

    # Resolve target structure — convert CIF to PDB if needed
    STRUCT_FILES=(${structure_files})
    export RESOLVED_PDB=""
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
            export RESOLVED_PDB="\${PWD}/target_structure.pdb"
        else
            export RESOLVED_PDB="\${PWD}/\${FIRST_STRUCT}"
        fi
    fi

    # Build the full Proteina-Complexa Hydra config from the design spec YAML
    python3 - <<PYEOF
import yaml, os

with open('${design_yaml}') as f:
    spec = yaml.safe_load(f)

task_name    = spec.get('task_name', '${meta.id}_task')
binder_len   = spec.get('binder_length', [60, 80])
hotspot_res  = spec.get('hotspot_res', [])
model        = spec.get('model', 'protein')
target_pdb   = os.environ.get('RESOLVED_PDB', '')
cache_root   = os.environ.get('COMPLEXA_CACHE_ROOT', os.path.join(os.path.expanduser('~'), '.cache', 'proteina_complexa'))
n_samples    = ${meta.num_designs}

ckpt_names = {
    'protein': 'complexa.ckpt',
    'ligand':  'complexa_ligand.ckpt',
    'ame':     'complexa_ame.ckpt',
}
ae_names = {
    'protein': 'complexa_ae.ckpt',
    'ligand':  'complexa_ligand_ae.ckpt',
    'ame':     'complexa_ame_ae.ckpt',
}
ckpt_name = ckpt_names.get(model, 'complexa.ckpt')
ae_name   = ae_names.get(model, 'complexa_ae.ckpt')

task_cfg = {
    'target_pdb':    target_pdb,
    'binder_length': binder_len,
}
if hotspot_res:
    task_cfg['hotspot_res'] = hotspot_res

config = {
    'ckpt_path':             cache_root,
    'ckpt_name':             ckpt_name,
    'autoencoder_ckpt_path': os.path.join(cache_root, ae_name),
    'gen_njobs':  1,
    'eval_njobs': 1,
    'output_dir': '${meta.id}_output/complexa_raw',
    'generation': {
        'n_samples': n_samples,
        'task_name': task_name,
    },
    'tasks': {task_name: task_cfg},
}

with open('complexa_config.yaml', 'w') as f:
    yaml.dump(config, f, default_flow_style=False)

with open('.task_name', 'w') as f:
    f.write(task_name)
PYEOF

    TASK_NAME=\$(cat .task_name)

    # Run Proteina-Complexa (generate → filter → evaluate → analyze)
    complexa design complexa_config.yaml \\
        ++run_name=${meta.id} \\
        ++generation.task_name=\${TASK_NAME}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        proteina_complexa: \$(complexa --version 2>&1 || echo "proteina-complexa")
        python: \$(python3 --version 2>&1 | sed 's/Python //g')
    END_VERSIONS
    """

    stub:
    """
    mkdir -p ${meta.id}_output/complexa_raw/${meta.id}_task/generated_pdbs
    touch ${meta.id}_output/complexa_raw/${meta.id}_task/generated_pdbs/design_0.pdb
    touch ${meta.id}_output/complexa_raw/${meta.id}_task/generated_pdbs/design_1.pdb
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        proteina_complexa: "proteina-complexa"
        python: \$(python3 --version 2>&1 | sed 's/Python //g')
    END_VERSIONS
    """
}
