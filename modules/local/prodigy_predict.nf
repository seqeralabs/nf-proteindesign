process PRODIGY_PREDICT {
    tag "${meta.id}"
    label 'process_low'
    
    // Publish results
    publishDir "${params.outdir}/${meta.parent_id ?: meta.id}/prodigy", mode: params.publish_dir_mode

    container 'community.wave.seqera.io/library/gcc_linux-64_pip_prodigy-prot:2e23eabd18cdbd0a'

    input:
    tuple val(meta), path(structure)
    path parse_script

    output:
    tuple val(meta), path("${meta.id}_prodigy_results.txt"), emit: results
    tuple val(meta), path("${meta.id}_prodigy_summary.csv"), emit: summary
    path "versions.yml", emit: versions

    script:
    // Determine chain selection - use parameter, meta value, or auto-detect
    def selection_arg = ''
    if (params.prodigy_selection) {
        selection_arg = "--selection ${params.prodigy_selection}"
    } else if (meta.prodigy_selection) {
        selection_arg = "--selection ${meta.prodigy_selection}"
    }
    // If no selection specified, PRODIGY will auto-detect chains
    
    """
    # Run PRODIGY on the structure
    # If no selection specified, PRODIGY auto-detects chains (usually A,B for binary complexes)
    prodigy ${structure} ${selection_arg} > ${meta.id}_prodigy_results.txt 2>&1 || true
    
    # Make parser script executable
    chmod +x ${parse_script}
    
    # Parse PRODIGY output and create CSV summary
    python ${parse_script} \\
        --input ${meta.id}_prodigy_results.txt \\
        --output ${meta.id}_prodigy_summary.csv \\
        --structure_id ${meta.id}
    
    # Generate version information
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        prodigy: \$(prodigy --version 2>&1 | grep -oP 'version \\K[0-9.]+' || echo "2.3.0")
        python: \$(python --version 2>&1 | sed 's/Python //g')
    END_VERSIONS
    """

    stub:
    """
    touch ${meta.id}_prodigy_results.txt
    touch ${meta.id}_prodigy_summary.csv
    touch versions.yml
    """
}
