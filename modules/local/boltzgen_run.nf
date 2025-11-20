process BOLTZGEN_RUN {
    tag "${meta.id}"
    label 'process_high_gpu'
    
    // Publish results
    publishDir "${params.outdir}/${meta.id}", mode: params.publish_dir_mode, saveAs: { filename -> filename }

    container 'cr.seqera.io/scidev/boltzgen:0.1.5'

    input:
    tuple val(meta), path(design_yaml), path(structure_files)
    path cache_dir, stageAs: 'input_cache/*'

    output:
    tuple val(meta), path("${meta.id}_output"), emit: results
    tuple val(meta), path("${meta.id}_output/final_ranked_designs"), optional: true, emit: final_designs
    tuple val(meta), path("${meta.id}_output/intermediate_designs"), optional: true, emit: intermediate_designs
    tuple val(meta), path("${meta.id}_output/intermediate_designs_inverse_folded"), optional: true, emit: inverse_folded
    
    // Final ranked designs (filtered results)
    tuple val(meta), path("${meta.id}_output/final_ranked_designs/**/*.cif"), optional: true, emit: final_cifs
    
    // Intermediate designs before filtering (unfiltered results from generation)
    tuple val(meta), path("${meta.id}_output/intermediate_designs/*.cif"), optional: true, emit: intermediate_cifs
    tuple val(meta), path("${meta.id}_output/intermediate_designs/*.npz"), optional: true, emit: intermediate_npz
    
    // Intermediate inverse folded designs (all budget designs - this is what we want for IPSAE/PRODIGY)
    tuple val(meta), path("${meta.id}_output/intermediate_designs_inverse_folded/*.cif"), optional: true, emit: budget_design_cifs
    tuple val(meta), path("${meta.id}_output/intermediate_designs_inverse_folded/*.npz"), optional: true, emit: budget_design_npz
    
    // Specific intermediate outputs: binder by itself and refolded complex
    tuple val(meta), path("${meta.id}_output/refold_design_cif"), optional: true, emit: refold_design_dir
    tuple val(meta), path("${meta.id}_output/refold_design_cif/*.cif"), optional: true, emit: refold_design_cifs
    tuple val(meta), path("${meta.id}_output/refold_cif"), optional: true, emit: refold_complex_dir
    tuple val(meta), path("${meta.id}_output/refold_cif/*.cif"), optional: true, emit: refold_complex_cifs
    
    // CSV metrics files
    tuple val(meta), path("${meta.id}_output/aggregate_metrics_analyze.csv"), optional: true, emit: aggregate_metrics
    tuple val(meta), path("${meta.id}_output/per_target_metrics_analyze.csv"), optional: true, emit: per_target_metrics
    
    path "versions.yml", emit: versions

    script:
    def reuse_flag = meta.reuse ? '--reuse' : ''
    def config_arg = params.boltzgen_config ? "--config ${params.boltzgen_config}" : ''
    def steps_arg = params.steps ? "--steps ${params.steps}" : ''
    def cache_arg = cache_dir.name != 'EMPTY_CACHE' ? "--cache input_cache" : "--cache cache"
    """
    export HF_HOME=\${PWD}/input_cache
    export NUMBA_CACHE_DIR=/tmp
    export MPLCONFIGDIR=/tmp/matplotlib
    export XET_LOG_DIR=/tmp/xet_logs
    export TRITON_CACHE_DIR=/tmp/triton  # Add this line
    export XDG_CACHE_HOME=/tmp/cache

    # Create cache directory if not using staged cache
    if [ "${cache_dir.name}" == "EMPTY_CACHE" ]; then
        mkdir -p ./cache
    fi

    # Run Boltzgen
    boltzgen run ${design_yaml} \\
        ${cache_arg} \\
        --output ${meta.id}_output \\
        --protocol ${meta.protocol} \\
        --num_designs ${meta.num_designs} \\
        --budget ${meta.budget} \\
        ${config_arg} \\
        ${steps_arg} \\
        ${reuse_flag}
    
    # Generate version information
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        boltzgen: \$(boltzgen --version 2>&1 | sed 's/^.*version //; s/ .*\$//')
        python: \$(python --version 2>&1 | sed 's/Python //g')
    END_VERSIONS
    """

    stub:
    """
    mkdir -p ${meta.id}_output/final_ranked_designs
    mkdir -p ${meta.id}_output/intermediate_designs
    mkdir -p ${meta.id}_output/intermediate_designs_inverse_folded
    touch ${meta.id}_output/final_ranked_designs/placeholder.cif
    touch versions.yml
    """
}
