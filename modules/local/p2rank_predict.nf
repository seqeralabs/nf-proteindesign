process P2RANK_PREDICT {
    tag "${meta.id}"
    label 'process_medium'
    
    publishDir "${params.outdir}/${meta.id}/p2rank_predictions", mode: params.publish_dir_mode

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://quay.io/biocontainers/p2rank:2.4.2--hdfd78af_0' :
        'quay.io/biocontainers/p2rank:2.4.2--hdfd78af_0' }"

    input:
    tuple val(meta), path(protein_structure)

    output:
    tuple val(meta), path(protein_structure), path("*.pdb_predictions.csv"), emit: predictions
    tuple val(meta), path(protein_structure), path("*.pdb_residues.csv"), emit: residues
    path("visualizations/*.pdb"), emit: visualizations, optional: true
    path "versions.yml", emit: versions

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    
    """
    # P2Rank prediction
    prank predict \\
        -f ${protein_structure} \\
        -threads ${task.cpus} \\
        ${args}
    
    # Rename output files with prefix for clarity
    if [ -f "${protein_structure}_predictions.csv" ]; then
        mv "${protein_structure}_predictions.csv" "${prefix}.pdb_predictions.csv"
    fi
    
    if [ -f "${protein_structure}_residues.csv" ]; then
        mv "${protein_structure}_residues.csv" "${prefix}.pdb_residues.csv"
    fi
    
    # Generate versions
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        p2rank: \$(prank version 2>&1 | grep -oP 'version \\K[0-9.]+' || echo "2.4.2")
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.pdb_predictions.csv
    touch ${prefix}.pdb_residues.csv
    mkdir -p visualizations
    touch visualizations/example.pdb
    touch versions.yml
    """
}
