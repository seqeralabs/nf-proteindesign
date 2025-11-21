process EXTRACT_TARGET_SEQUENCES {
    tag "${meta.id}"
    label 'process_low'
    
    container 'biopython/biopython:latest'

    input:
    tuple val(meta), path(original_structures)
    path extract_script

    output:
    tuple val(meta), path("${meta.id}_target_sequences.txt"), emit: target_sequences
    tuple val(meta), path("${meta.id}_target_info.json"), emit: target_info
    path "versions.yml", emit: versions

    script:
    """
    #!/usr/bin/env python3
    import os
    import sys
    import json
    from pathlib import Path
    
    # Import the extraction script
    sys.path.insert(0, '.')
    
    # Find structure files
    structures_input = Path("${original_structures}")
    
    if structures_input.is_dir():
        structure_files = list(structures_input.rglob("*.cif")) + list(structures_input.rglob("*.pdb"))
    elif structures_input.is_file():
        structure_files = [structures_input]
    else:
        structure_files = [Path(f) for f in "${original_structures}".split() if Path(f).exists()]
    
    print(f"Found {len(structure_files)} structure files")
    
    if len(structure_files) == 0:
        print("ERROR: No structure files found", file=sys.stderr)
        sys.exit(1)
    
    # Use the first structure file to extract target sequence
    # (all structures from same design should have same target)
    first_structure = structure_files[0]
    print(f"Extracting target sequence from: {first_structure}")
    
    # Run extraction script
    import subprocess
    result = subprocess.run(
        [
            'python3',
            '${extract_script}',
            str(first_structure),
            '--output', '${meta.id}_target_sequences.txt',
            '--format', 'plain'
        ],
        capture_output=True,
        text=True
    )
    
    if result.returncode != 0:
        print(f"ERROR: Failed to extract target sequence", file=sys.stderr)
        print(result.stderr, file=sys.stderr)
        sys.exit(1)
    
    # Parse extraction info from stderr
    target_length = 0
    chain_id = 'unknown'
    for line in result.stderr.split('\\n'):
        if 'Extracted target chain' in line:
            parts = line.split()
            if len(parts) >= 4:
                chain_id = parts[3]
            if '(' in line and 'residues' in line:
                try:
                    target_length = int(line.split('(')[1].split()[0])
                except:
                    pass
    
    print(f"✓ Target sequence extracted: chain {chain_id}, length {target_length}")
    
    # Create info JSON
    info = {
        "design_id": "${meta.id}",
        "source_structure": str(first_structure.name),
        "target_chain": chain_id,
        "target_length": target_length,
        "num_structures": len(structure_files)
    }
    
    with open("${meta.id}_target_info.json", 'w') as f:
        json.dump(info, f, indent=2)
    
    print(f"✓ Target info saved to ${meta.id}_target_info.json")
    
    # Generate version information
    with open("versions.yml", "w") as f:
        f.write("\\"${task.process}\\":\\n")
        f.write(f"    python: {sys.version.split()[0]}\\n")
    """

    stub:
    """
    echo "MOCK_TARGET_SEQUENCE" > ${meta.id}_target_sequences.txt
    echo '{"design_id": "${meta.id}", "target_chain": "A", "target_length": 100}' > ${meta.id}_target_info.json
    touch versions.yml
    """
}
