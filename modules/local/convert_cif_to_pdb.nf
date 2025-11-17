process CONVERT_CIF_TO_PDB {
    tag "${meta.id}"
    label 'process_low'
    
    conda "bioconda::biopython=1.83"
    container 'biocontainers/biopython:v1.83_cv1'

    input:
    tuple val(meta), path(structures)

    output:
    tuple val(meta), path("${meta.id}_pdb_structures/*.pdb"), emit: pdb_files
    path "versions.yml", emit: versions

    script:
    """
    #!/usr/bin/env python3
    import os
    import sys
    from pathlib import Path
    
    # BioPython imports
    try:
        from Bio.PDB import MMCIFParser, PDBIO, PDBParser
        from Bio.PDB import Select
    except ImportError:
        print("ERROR: BioPython not found. Please ensure biopython is installed.", file=sys.stderr)
        sys.exit(1)
    
    # Create output directory
    output_dir = Path("${meta.id}_pdb_structures")
    output_dir.mkdir(exist_ok=True)
    
    # Initialize parsers
    cif_parser = MMCIFParser(QUIET=True)
    pdb_parser = PDBParser(QUIET=True)
    pdb_writer = PDBIO()
    
    # Get all structure files
    # Handle both file and directory inputs
    structures_input = Path("${structures}")
    
    if structures_input.is_dir():
        # If input is a directory, search recursively for CIF and PDB files
        # This handles nested directories like final_1_designs, intermediate_ranked_10_designs, etc.
        structure_files = list(structures_input.rglob("*.cif")) + list(structures_input.rglob("*.pdb"))
        print("Found directory: " + str(structures_input))
        print("  Files found (recursive search): " + str(len(structure_files)))
        
        # Show which subdirectories contain files
        subdirs_with_files = set()
        for f in structure_files:
            subdir = f.parent.name
            subdirs_with_files.add(subdir)
        if subdirs_with_files:
            print("  Subdirectories with structures: " + ", ".join(sorted(subdirs_with_files)))
    elif structures_input.is_file():
        # If input is a single file
        structure_files = [structures_input]
        print("Found single file: " + str(structures_input))
    else:
        # Try to parse as space-separated list of files
        structure_files = [Path(f) for f in "${structures}".split() if Path(f).exists()]
        print("Parsed file list: " + str(len(structure_files)) + " files")
    
    converted_count = 0
    copied_count = 0
    error_count = 0
    
    if len(structure_files) == 0:
        print("ERROR: No structure files found to process!", file=sys.stderr)
        print("  Input path: ${structures}", file=sys.stderr)
        print("  Resolved to: " + str(structures_input), file=sys.stderr)
        print("  Is directory: " + str(structures_input.is_dir()), file=sys.stderr)
        print("  Is file: " + str(structures_input.is_file()), file=sys.stderr)
        print("  Exists: " + str(structures_input.exists()), file=sys.stderr)
        if structures_input.is_dir():
            all_files = list(structures_input.glob("*"))
            print("  All files in directory: " + str(len(all_files)), file=sys.stderr)
            for f in all_files[:10]:  # Show first 10 files
                print("    - " + str(f), file=sys.stderr)
    
    for structure_file in structure_files:
        try:
            file_stem = structure_file.stem
            output_file = output_dir / (file_stem + ".pdb")
            
            if structure_file.suffix.lower() == '.cif':
                # Parse CIF file
                print("Converting " + structure_file.name + " to PDB format...")
                structure = cif_parser.get_structure(file_stem, str(structure_file))
                
                # Write as PDB
                pdb_writer.set_structure(structure)
                pdb_writer.save(str(output_file))
                converted_count += 1
                
            elif structure_file.suffix.lower() == '.pdb':
                # Validate and copy PDB file
                print("Validating and copying " + structure_file.name + "...")
                structure = pdb_parser.get_structure(file_stem, str(structure_file))
                
                # Re-write to ensure proper formatting
                pdb_writer.set_structure(structure)
                pdb_writer.save(str(output_file))
                copied_count += 1
                
            else:
                print("WARNING: Skipping " + structure_file.name + " - not a CIF or PDB file", file=sys.stderr)
                continue
                
            print("  -> Output: " + str(output_file))
            
        except Exception as e:
            print("ERROR: Failed to process " + structure_file.name + ": " + str(e), file=sys.stderr)
            error_count += 1
            continue
    
    # Summary
    total_processed = converted_count + copied_count
    print("\\nConversion complete:")
    print("  CIF files converted: " + str(converted_count))
    print("  PDB files validated: " + str(copied_count))
    print("  Total processed: " + str(total_processed))
    print("  Errors: " + str(error_count))
    
    if total_processed == 0:
        print("ERROR: No structure files were successfully processed", file=sys.stderr)
        sys.exit(1)
    
    # Generate version information
    import Bio
    with open("versions.yml", "w") as f:
        f.write("\\"${task.process}\\":\\n")
        f.write("    biopython: " + Bio.__version__ + "\\n")
        f.write("    python: " + sys.version.split()[0] + "\\n")
    """

    stub:
    """
    mkdir -p ${meta.id}_pdb_structures
    touch ${meta.id}_pdb_structures/placeholder.pdb
    touch versions.yml
    """
}
