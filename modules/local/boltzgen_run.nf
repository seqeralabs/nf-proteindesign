process BOLTZGEN_RUN {
    tag "${meta.id}"
    label 'process_high_gpu'
    
    // Publish results
    publishDir "${params.outdir}/${meta.id}", mode: params.publish_dir_mode, saveAs: { filename -> filename }

    conda "boltzgen::boltzgen"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://boltz/boltzgen:latest' :
        'boltz/boltzgen:latest' }"

    input:
    tuple val(meta), path(design_yaml)

    output:
    tuple val(meta), path("${meta.id}_output"), emit: results
    tuple val(meta), path("${meta.id}_output/final_ranked_designs"), optional: true, emit: final_designs
    tuple val(meta), path("${meta.id}_output/intermediate_designs"), optional: true, emit: intermediate_designs
    tuple val(meta), path("${meta.id}_output/intermediate_designs_inverse_folded"), optional: true, emit: inverse_folded
    path "versions.yml", emit: versions

    script:
    def reuse_flag = meta.reuse ? '--reuse' : ''
    def cache_arg = params.cache_dir ? "--cache ${params.cache_dir}" : ''
    def config_arg = params.boltzgen_config ? "--config ${params.boltzgen_config}" : ''
    def steps_arg = params.steps ? "--steps ${params.steps}" : ''
    
    """
    # Run Boltzgen
    boltzgen run ${design_yaml} \\
        --output ${meta.id}_output \\
        --protocol ${meta.protocol} \\
        --num_designs ${meta.num_designs} \\
        --budget ${meta.budget} \\
        ${cache_arg} \\
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
