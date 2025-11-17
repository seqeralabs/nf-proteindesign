process CONSOLIDATE_METRICS {
    label 'process_low'
    
    // Publish reports to top-level output directory
    publishDir "${params.outdir}", mode: params.publish_dir_mode

    conda "conda-forge::python=3.11"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://python:3.11' :
        'python:3.11' }"

    input:
    val output_dir  // Path to the complete output directory with all results (as string)
    path consolidate_script

    output:
    path "design_metrics_summary.csv", emit: summary_csv
    path "design_metrics_report.md", emit: report_markdown
    path "versions.yml", emit: versions

    script:
    def top_n = params.report_top_n ?: 10
    def ipsae_pattern = params.ipsae_pae_cutoff && params.ipsae_dist_cutoff ? 
        "**/ipsae_scores/*_${params.ipsae_pae_cutoff}_${params.ipsae_dist_cutoff}.txt" : 
        "**/ipsae_scores/*_10_10.txt"
    def prodigy_pattern = "**/prodigy/*_prodigy_summary.csv"
    
    // Convert to absolute path if relative
    def abs_output_dir = output_dir.startsWith('/') ? output_dir : "${workflow.launchDir}/${output_dir}"
    
    """
    # Make script executable
    chmod +x ${consolidate_script}
    
    # Debug: Show what directory we're searching
    echo "Searching in directory: ${abs_output_dir}"
    echo "Current working directory: \$(pwd)"
    ls -la ${abs_output_dir} || echo "Warning: Could not list output directory"
    
    # Run consolidation script with absolute path
    python ${consolidate_script} \\
        --output_dir "${abs_output_dir}" \\
        --output_csv design_metrics_summary.csv \\
        --output_markdown design_metrics_report.md \\
        --top_n ${top_n} \\
        --ipsae_pattern "${ipsae_pattern}" \\
        --prodigy_pattern "${prodigy_pattern}"
    
    # Generate version information
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version 2>&1 | sed 's/Python //g')
    END_VERSIONS
    """

    stub:
    """
    touch design_metrics_summary.csv
    touch design_metrics_report.md
    touch versions.yml
    """
}
