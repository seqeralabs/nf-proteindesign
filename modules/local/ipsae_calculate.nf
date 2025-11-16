process IPSAE_CALCULATE {
    tag "${meta.id}"
    label 'process_low'
    
    // Publish results
    publishDir "${params.outdir}/${meta.id}/ipsae_scores", mode: params.publish_dir_mode, saveAs: { filename -> filename }

    conda "conda-forge::python=3.11 conda-forge::numpy=1.24"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://python:3.11' :
        'python:3.11' }"

    input:
    tuple val(meta), path(pae_file), path(structure_file)
    path ipsae_script

    output:
    tuple val(meta), path("*_${params.ipsae_pae_cutoff}_${params.ipsae_dist_cutoff}.txt"), emit: scores
    tuple val(meta), path("*_${params.ipsae_pae_cutoff}_${params.ipsae_dist_cutoff}_byres.txt"), emit: byres_scores
    tuple val(meta), path("*.pml"), optional: true, emit: pymol_scripts
    path "versions.yml", emit: versions

    script:
    def pae_cutoff = params.ipsae_pae_cutoff ?: 10
    def dist_cutoff = params.ipsae_dist_cutoff ?: 10
    
    """
    # Install numpy if not available
    pip install --no-cache-dir numpy 2>&1 | grep -v "Requirement already satisfied" || true
    
    # Run IPSAE calculation
    python ${ipsae_script} \\
        ${pae_file} \\
        ${structure_file} \\
        ${pae_cutoff} \\
        ${dist_cutoff}
    
    # Generate version information
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version 2>&1 | sed 's/Python //g')
        numpy: \$(python -c "import numpy; print(numpy.__version__)")
        ipsae: 3.0
    END_VERSIONS
    """

    stub:
    def pae_cutoff = params.ipsae_pae_cutoff ?: 10
    def dist_cutoff = params.ipsae_dist_cutoff ?: 10
    """
    touch stub_output_${pae_cutoff}_${dist_cutoff}.txt
    touch stub_output_${pae_cutoff}_${dist_cutoff}_byres.txt
    touch stub_output.pml
    touch versions.yml
    """
}
