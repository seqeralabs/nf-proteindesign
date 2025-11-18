process COLLECT_DESIGN_FILES {
    tag "${meta.id}"
    label 'process_single'
    
    input:
    tuple val(meta), path(results_dir)
    val file_pattern  // e.g., "*.cif" or "*.pdb"
    
    output:
    tuple val(meta), path("file_list.txt"), emit: file_list
    
    script:
    """
    # List all files matching pattern in final_ranked_designs subdirectory
    # Use -L to follow symlinks and find real files
    if [ -d "${results_dir}/final_ranked_designs" ]; then
        find -L ${results_dir}/final_ranked_designs -name "${file_pattern}" -type f > file_list.txt
    else
        touch file_list.txt
    fi
    
    # Show what we found for debugging
    echo "Searching for ${file_pattern} in ${results_dir}/final_ranked_designs"
    echo "Found files:"
    cat file_list.txt
    echo "Total files found: \$(wc -l < file_list.txt)"
    """
    
    stub:
    """
    echo "${results_dir}/final_ranked_designs/design_0.cif" > file_list.txt
    echo "${results_dir}/final_ranked_designs/design_1.cif" >> file_list.txt
    """
}


process COLLECT_IPSAE_PAIRS {
    tag "${meta.id}"
    label 'process_single'
    
    input:
    tuple val(meta), path(results_dir)
    
    output:
    tuple val(meta), path("ipsae_pairs.txt"), emit: pairs
    
    script:
    """
    # Find all CIF files and their corresponding NPZ files in intermediate_designs
    # Output format: cif_path,npz_path,design_id
    # Use -L to follow symlinks
    if [ -d "${results_dir}/intermediate_designs" ]; then
        find -L ${results_dir}/intermediate_designs -name "*.cif" -type f | while read cif_file; do
            base_name=\$(basename "\${cif_file}" .cif)
            npz_file="\$(dirname "\${cif_file}")/\${base_name}.npz"
            
            if [ -f "\${npz_file}" ]; then
                echo "\${cif_file},\${npz_file},${meta.id}_\${base_name}"
            fi
        done > ipsae_pairs.txt
    else
        touch ipsae_pairs.txt
    fi
    
    # Show what we found for debugging
    echo "Searching for IPSAE pairs in ${results_dir}/intermediate_designs"
    echo "Found pairs:"
    cat ipsae_pairs.txt
    echo "Total pairs found: \$(wc -l < ipsae_pairs.txt)"
    """
    
    stub:
    """
    echo "${results_dir}/intermediate_designs/design_0.cif,${results_dir}/intermediate_designs/design_0.npz,${meta.id}_design_0" > ipsae_pairs.txt
    """
}
