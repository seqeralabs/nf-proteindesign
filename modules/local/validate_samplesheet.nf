process VALIDATE_SAMPLESHEET {
    tag "Validating samplesheet"
    label 'process_single'

    conda "conda-forge::python=3.11"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.11' :
        'biocontainers/python:3.11' }"

    input:
    path samplesheet

    output:
    path 'validated_samplesheet.csv', emit: csv

    script:
    """
    #!/usr/bin/env python3
    
    import csv
    import sys
    from pathlib import Path
    
    # Read and validate samplesheet
    required_columns = ['sample_id', 'design_yaml']
    optional_columns = ['protocol', 'num_designs', 'budget', 'reuse']
    valid_protocols = ['protein-anything', 'peptide-anything', 'protein-small_molecule', 'nanobody-anything']
    
    with open('${samplesheet}', 'r') as f_in, open('validated_samplesheet.csv', 'w', newline='') as f_out:
        reader = csv.DictReader(f_in)
        
        # Check required columns
        for col in required_columns:
            if col not in reader.fieldnames:
                print(f"ERROR: Required column '{col}' not found in samplesheet", file=sys.stderr)
                sys.exit(1)
        
        writer = csv.DictWriter(f_out, fieldnames=reader.fieldnames)
        writer.writeheader()
        
        sample_ids = set()
        for idx, row in enumerate(reader, start=2):
            # Check for duplicate sample IDs
            if row['sample_id'] in sample_ids:
                print(f"ERROR: Duplicate sample_id '{row['sample_id']}' found in row {idx}", file=sys.stderr)
                sys.exit(1)
            sample_ids.add(row['sample_id'])
            
            # Check design YAML exists
            if not Path(row['design_yaml']).exists():
                print(f"ERROR: Design YAML file does not exist: {row['design_yaml']} (row {idx})", file=sys.stderr)
                sys.exit(1)
            
            # Validate protocol if provided
            if row.get('protocol') and row['protocol'] not in valid_protocols:
                print(f"WARNING: Unknown protocol '{row['protocol']}' for sample '{row['sample_id']}' (row {idx})", file=sys.stderr)
                print(f"Valid protocols: {', '.join(valid_protocols)}", file=sys.stderr)
            
            writer.writerow(row)
    
    print(f"Samplesheet validated successfully: {len(sample_ids)} samples")
    """

    stub:
    """
    touch validated_samplesheet.csv
    """
}
