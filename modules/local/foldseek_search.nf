process FOLDSEEK_SEARCH {
    tag "${meta.id}"
    label 'process_medium'
    
    // Publish results
    publishDir "${params.outdir}/${meta.parent_id ?: meta.id}/foldseek", mode: params.publish_dir_mode

    container 'quay.io/biocontainers/foldseek:9.427df8a--pl5321hf1761c0_0'

    input:
    tuple val(meta), path(structure)
    path database

    output:
    tuple val(meta), path("${meta.id}_foldseek_results.tsv"), emit: results
    tuple val(meta), path("${meta.id}_foldseek_summary.tsv"), emit: summary
    path "versions.yml", emit: versions

    script:
    // Determine database path - can be a path or directory
    def db_path = database.name != 'NO_DATABASE' ? database : params.foldseek_database
    
    // Set search parameters
    def evalue = params.foldseek_evalue ?: 0.001
    def max_seqs = params.foldseek_max_seqs ?: 100
    def sensitivity = params.foldseek_sensitivity ?: 9.5
    def coverage = params.foldseek_coverage ?: 0.0
    def alignment_type = params.foldseek_alignment_type ?: 2
    
    // Validate database
    if (!db_path) {
        error "ERROR: No Foldseek database specified. Please set --foldseek_database parameter."
    }
    
    """
    # Create temporary directory for Foldseek
    mkdir -p tmp_foldseek
    
    # Run Foldseek easy-search
    foldseek easy-search \\
        ${structure} \\
        ${db_path} \\
        ${meta.id}_foldseek_results.tsv \\
        tmp_foldseek \\
        -e ${evalue} \\
        --max-seqs ${max_seqs} \\
        -s ${sensitivity} \\
        -c ${coverage} \\
        --alignment-type ${alignment_type} \\
        --threads ${task.cpus}
    
    # Create summary with top hits
    # Output format: query,target,evalue,bits,qstart,qend,tstart,tend,alnlen,qlen,tlen,qaln,taln
    head -n 11 ${meta.id}_foldseek_results.tsv | \\
        awk 'BEGIN {OFS="\\t"; print "query", "target", "fident", "alnlen", "mismatch", "gapopen", "qstart", "qend", "tstart", "tend", "evalue", "bits"} 
             {print}' > ${meta.id}_foldseek_summary.tsv
    
    # Clean up
    rm -rf tmp_foldseek
    
    # Generate version information
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        foldseek: \$(foldseek version 2>&1 | grep -oP 'Version: \\K[0-9a-f]+' || echo "9.427df8a")
    END_VERSIONS
    """

    stub:
    """
    touch ${meta.id}_foldseek_results.tsv
    touch ${meta.id}_foldseek_summary.tsv
    touch versions.yml
    """
}
