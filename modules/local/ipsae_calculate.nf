process IPSAE_CALCULATE {
    tag "${meta.id}"
    label 'process_low'
    
    // Publish results - use parent_id to group by original design
    publishDir "${params.outdir}/${meta.parent_id ?: meta.id}/ipsae", mode: params.publish_dir_mode, saveAs: { filename -> filename }

    container 'community.wave.seqera.io/library/numpy:2.3.5--f8d2712d76b3e3ce'

    input:
    tuple val(meta), path(pae_file), path(structure_file), path(confidence_json), path(plddt_npz)
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

    # Stage confidence and pLDDT files alongside the PAE file so ipsae.py
    # auto-discovers them by filename convention:
    #   pae_<name>_model_0.npz  ->  confidence_<name>_model_0.json
    #   pae_<name>_model_0.npz  ->  plddt_<name>_model_0.npz
    echo "Staged confidence JSON: ${confidence_json}"
    echo "Staged pLDDT NPZ: ${plddt_npz}"
    
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
    # Create stub files with unique names using meta.id
    touch ${meta.id}_${pae_cutoff}_${dist_cutoff}.txt
    touch ${meta.id}_${pae_cutoff}_${dist_cutoff}_byres.txt
    touch ${meta.id}.pml
    touch versions.yml
    """
}
