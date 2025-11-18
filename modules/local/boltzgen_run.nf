process BOLTZGEN_RUN {
    tag "${meta.id}"
    label 'process_high_gpu'
    
    // Publish results
    publishDir "${params.outdir}/${meta.id}", mode: params.publish_dir_mode, saveAs: { filename -> filename }

    conda "boltzgen::boltzgen"
    container 'wuennemannflorian/boltzgen:latest'

    input:
    tuple val(meta), path(design_yaml), path(structure_files)
    path cache_dir, stageAs: 'input_cache/*'

    output:
    tuple val(meta), path("${meta.id}_output"), emit: results
    tuple val(meta), path("${meta.id}_output/final_ranked_designs"), optional: true, emit: final_designs
    tuple val(meta), path("${meta.id}_output/intermediate_designs"), optional: true, emit: intermediate_designs
    tuple val(meta), path("${meta.id}_output/intermediate_designs_inverse_folded"), optional: true, emit: inverse_folded
    tuple val(meta), path("${meta.id}_output/final_ranked_designs/*.cif"), optional: true, emit: final_cifs
    tuple val(meta), path("${meta.id}_output/intermediate_designs/*.cif"), optional: true, emit: intermediate_cifs
    tuple val(meta), path("${meta.id}_output/intermediate_designs/*.npz"), optional: true, emit: intermediate_npz
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
