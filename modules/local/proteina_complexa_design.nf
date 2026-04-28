process PROTEINA_COMPLEXA_DESIGN {
    tag "${meta.id}"
    label 'process_high_gpu'

    // Publish results
    publishDir "${params.outdir}/${meta.id}/proteina_complexa", mode: params.publish_dir_mode, saveAs: { filename -> filename }

    container "${params.complexa_container}"

    // GPU acceleration — Proteina-Complexa requires GPU for flow matching inference + reward scoring
    accelerator 1, type: 'nvidia-gpu'

    input:
    tuple val(meta), path(target_pdb), path(pipeline_config)
    path(ckpt_dir, stageAs: 'checkpoints', arity: '0..*')

    output:
    // Full results directory
    tuple val(meta), path("${meta.id}_output"),                                             emit: results

    // Generated PDB design files (filtered top-N from the generation+filter stages)
    // These are complex PDBs (target + binder) ready for downstream analysis
    tuple val(meta), path("${meta.id}_output/designs/*.pdb"), optional: true,               emit: design_pdbs

    // Evaluation results CSVs (from Complexa's built-in evaluate stage)
    tuple val(meta), path("${meta.id}_output/evaluation_results/*.csv"), optional: true,    emit: eval_csvs

    // Analysis summary CSVs (from Complexa's built-in analyze stage)
    tuple val(meta), path("${meta.id}_output/analysis/*_combined.csv"), optional: true,     emit: analysis_csvs

    // Success-filtered designs (designs passing i_pAE, pLDDT, scRMSD thresholds)
    tuple val(meta), path("${meta.id}_output/analysis/success_filtered/*.pdb"), optional: true, emit: success_pdbs

    path "versions.yml",                                                                    emit: versions

    script:
    def run_name       = "${meta.id}"
    def task_name      = meta.task_name ?: ''
    def pipeline_type  = meta.pipeline_type ?: 'binder'
    def nsamples       = meta.num_designs ?: 4
    def filter_limit   = meta.budget ?: 10
    def search_algo    = params.complexa_search_algorithm ?: 'best-of-n'
    def nsteps         = params.complexa_nsteps ?: 400
    def replicas       = params.complexa_replicas ?: 2
    def batch_size     = params.complexa_batch_size ?: 16
    def extra_args     = params.complexa_extra_args ?: ''
    // Only override task_name and target_path when explicitly provided
    def task_name_arg  = task_name ? "++generation.task_name=${task_name} ++generation.target_dict_cfg.${task_name}.target_path=${target_pdb}" : ''

    """
    set -euo pipefail

    # ── Environment setup ──
    export NUMBA_CACHE_DIR=/tmp/numba
    export MPLCONFIGDIR=/tmp/matplotlib
    export XDG_CACHE_HOME=/tmp/cache
    export TRITON_CACHE_DIR=/tmp/triton
    mkdir -p /tmp/numba /tmp/matplotlib /tmp/cache /tmp/triton

    # ── Initialize Proteina-Complexa environment (Docker runtime) ──
    # Set tool paths for the Docker container (normally set by 'complexa init docker && source env.sh')
    export COMPLEXA_INIT=1
    export FOLDSEEK_EXEC=/workspace/.venv/bin/foldseek
    export RF3_EXEC_PATH=/workspace/.venv/bin/rf3
    export SC_EXEC=/usr/local/bin/sc
    export MMSEQS_EXEC=/workspace/.venv/bin/mmseqs
    export DSSP_EXEC=/usr/local/bin/dssp
    export TMOL_PATH=/workspace/.venv/lib/python3.12/site-packages/tmol
    export PYTHONPATH=/workspace/protein-foundation-models/src:\${PYTHONPATH:-}
    export PATH=/workspace/.venv/bin:\$PATH

    # ── Resolve checkpoint paths ──
    export CKPT_DIR=\$(realpath checkpoints)
    export CKPT_PATH=\${CKPT_DIR}

    # ── Ensure the staged target PDB is visible as an absolute path ──
    # The YAML config's target_dict_cfg.*.target_path is resolved relative to CWD.
    # Copy the staged target PDB to the working directory root so the default
    # relative path in the YAML ("target_name.pdb") resolves correctly.
    TARGET_PDB=\$(realpath ${target_pdb})

    # ── Run Proteina-Complexa full design pipeline ──
    # The 'complexa design' command runs: generate → filter → evaluate → analyze
    complexa design ${pipeline_config} \\
        ++ckpt_path=\${CKPT_DIR} \\
        ++ckpt_name=${meta.ckpt_name ?: 'complexa.ckpt'} \\
        ++autoencoder_ckpt_path=\${CKPT_DIR}/${meta.ae_ckpt_name ?: 'complexa_ae.ckpt'} \\
        ++generation.search.algorithm=${search_algo} \\
        ++generation.args.nsteps=${nsteps} \\
        ++generation.dataloader.batch_size=${batch_size} \\
        ++generation.dataloader.dataset.nres.nsamples=${nsamples} \\
        ++generation.search.best_of_n.replicas=${replicas} \\
        ++generation.filter.filter_samples_limit=${filter_limit} \\
        ${task_name_arg} \\
        ${extra_args}

    # ── Organize outputs into standardized directory structure ──
    mkdir -p ${run_name}_output/designs
    mkdir -p ${run_name}_output/evaluation_results
    mkdir -p ${run_name}_output/analysis

    # Collect generated PDB files from inference directory
    # Proteina-Complexa outputs to: inference/{run_name}_{task_name}/job_*/*.pdb
    find inference/ -name "*.pdb" -not -path "*/filtered_out_samples/*" \\
        -exec cp {} ${run_name}_output/designs/ \\; 2>/dev/null || true

    # Collect evaluation CSVs
    find evaluation_results/ -name "*.csv" \\
        -exec cp {} ${run_name}_output/evaluation_results/ \\; 2>/dev/null || true

    # Collect analysis outputs (combined CSVs + success-filtered PDBs)
    find inference/ -path "*/analysis/*_combined.csv" \\
        -exec cp {} ${run_name}_output/analysis/ \\; 2>/dev/null || true
    if [ -d inference/*/analysis/success_filtered ]; then
        cp -r inference/*/analysis/success_filtered ${run_name}_output/analysis/ 2>/dev/null || true
    fi

    # ── Version information ──
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        proteina-complexa: \$(complexa --version 2>&1 | head -1 || echo "unknown")
        python: \$(python --version 2>&1 | sed 's/Python //g')
    END_VERSIONS
    """

    stub:
    """
    # Create realistic output directory structure for stub runs
    mkdir -p ${meta.id}_output/designs
    mkdir -p ${meta.id}_output/evaluation_results
    mkdir -p ${meta.id}_output/analysis/success_filtered

    # Create stub PDB files with realistic Proteina-Complexa naming convention
    # Format: job_{job_id}_n_{binder_length}_id_{sample_idx}_{metadata_tag}.pdb
    touch ${meta.id}_output/designs/job_0_n_80_id_0_bon_orig0_r0.pdb
    touch ${meta.id}_output/designs/job_0_n_80_id_1_bon_orig0_r1.pdb
    touch ${meta.id}_output/designs/job_0_n_100_id_2_bon_orig1_r0.pdb

    # Create stub evaluation CSVs
    echo "sample_id,self_complex_i_pAE,self_complex_pLDDT,self_binder_scRMSD" > ${meta.id}_output/evaluation_results/binder_results_0.csv
    echo "job_0_n_80_id_0_bon_orig0_r0,0.15,0.92,1.2" >> ${meta.id}_output/evaluation_results/binder_results_0.csv

    # Create stub analysis CSV
    echo "sample_id,i_pAE,pLDDT,scRMSD,pass_all" > ${meta.id}_output/analysis/binder_results_combined.csv
    echo "job_0_n_80_id_0_bon_orig0_r0,0.15,0.92,1.2,true" >> ${meta.id}_output/analysis/binder_results_combined.csv

    # Create stub success-filtered PDB
    touch ${meta.id}_output/analysis/success_filtered/job_0_n_80_id_0_bon_orig0_r0.pdb

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        proteina-complexa: stub
        python: stub
    END_VERSIONS
    """
}
