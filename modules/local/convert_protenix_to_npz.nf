/*
========================================================================================
    CONVERT_PROTENIX_TO_NPZ: Extract PAE from Protenix JSON and convert to NPZ
========================================================================================
    This process converts Protenix confidence JSON files to NPZ format compatible
    with ipSAE scoring. It extracts the PAE (Predicted Aligned Error) matrix and
    saves it in the format expected by the ipSAE tool.
----------------------------------------------------------------------------------------
*/

process CONVERT_PROTENIX_TO_NPZ {
    tag "${meta.id}"
    label 'process_low'
    
    // Publish NPZ files to protenix subdirectory
    publishDir "${params.outdir}/${meta.parent_id}/protenix/npz", mode: params.publish_dir_mode

    container 'community.wave.seqera.io/library/numpy:2.3.5--f8d2712d76b3e3ce'

    input:
    tuple val(meta), path(confidence_json), path(cif_file)
    path conversion_script

    output:
    tuple val(meta), path("*.npz"), path(cif_file), emit: npz_with_cif
    tuple val(meta), path("*.npz"), emit: npz_only
    path "versions.yml", emit: versions

    script:
    def output_name = "${confidence_json.baseName}.npz"
    """
    #!/bin/bash
    set -euo pipefail
    
    echo "============================================"
    echo "Converting Protenix JSON to NPZ for ipSAE"
    echo "============================================"
    echo "Input JSON: ${confidence_json}"
    echo "Output NPZ: ${output_name}"
    echo "Associated CIF: ${cif_file}"
    echo ""
    
    # Run conversion script
    python3 ${conversion_script} \\
        ${confidence_json} \\
        ${output_name}
    
    echo ""
    echo "✓ Conversion complete"
    echo "============================================"
    
    # Generate version information
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version 2>&1 | sed 's/Python //g')
        numpy: \$(python3 -c "import numpy; print(numpy.__version__)")
    END_VERSIONS
    """

    stub:
    """
    touch ${confidence_json.baseName}.npz
    touch versions.yml
    """
}
