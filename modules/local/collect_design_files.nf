process COLLECT_DESIGN_FILES {
    tag "${meta.id}"
    label 'process_single'
    
    input:
    tuple val(meta), path(designs_dir)
    val file_pattern  // e.g., "*.cif" or "*.pdb"
    
    output:
    tuple val(meta), path("file_list.txt"), emit: file_list
    
    script:
    """
    # List all files matching pattern in the directory
    find ${designs_dir} -name "${file_pattern}" -type f > file_list.txt
    
    # Show what we found for debugging
    echo "Found files:"
    cat file_list.txt
    """
    
    stub:
    """
    echo "${designs_dir}/design_0.cif" > file_list.txt
    echo "${designs_dir}/design_1.cif" >> file_list.txt
    """
}


process COLLECT_IPSAE_PAIRS {
    tag "${meta.id}"
    label 'process_single'
    
    input:
    tuple val(meta), path(designs_dir)
    
    output:
    tuple val(meta), path("ipsae_pairs.txt"), emit: pairs
    
    script:
    """
    # Find all CIF files and their corresponding NPZ files
    # Output format: cif_path,npz_path,design_id
    find ${designs_dir} -name "*.cif" -type f | while read cif_file; do
        base_name=\$(basename "\${cif_file}" .cif)
        npz_file="\$(dirname "\${cif_file}")/\${base_name}.npz"
        
        if [ -f "\${npz_file}" ]; then
            echo "\${cif_file},\${npz_file},${meta.id}_\${base_name}"
        fi
    done > ipsae_pairs.txt
    
    # Show what we found for debugging
    echo "Found IPSAE pairs:"
    cat ipsae_pairs.txt
    """
    
    stub:
    """
    echo "${designs_dir}/design_0.cif,${designs_dir}/design_0.npz,${meta.id}_design_0" > ipsae_pairs.txt
    """
}
