process CREATE_DESIGN_SAMPLESHEET {
    tag "${meta.id}"
    label 'process_low'
    
    publishDir "${params.outdir}/${meta.id}", mode: params.publish_dir_mode

    conda "conda-forge::python=3.11"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://python:3.11' :
        'python:3.11' }"

    input:
    tuple val(meta), path(design_yamls)

    output:
    tuple val(meta), path("generated_samplesheet.csv"), emit: samplesheet
    path "versions.yml", emit: versions

    script:
    def protocol = meta.protocol ?: params.protocol
    def num_designs = meta.num_designs ?: params.num_designs
    def budget = meta.budget ?: params.budget
    
    """
    #!/usr/bin/env python3
    import os
    import csv
    from pathlib import Path

    # Get all YAML files
    yaml_files = sorted([f for f in os.listdir('.') if f.endswith('.yaml')])
    
    # Create samplesheet
    with open('generated_samplesheet.csv', 'w', newline='') as csvfile:
        writer = csv.writer(csvfile)
        # Write header
        writer.writerow(['sample_id', 'design_yaml', 'protocol', 'num_designs', 'budget'])
        
        # Write each design as a row
        for yaml_file in yaml_files:
            # Extract sample_id from filename (remove .yaml extension)
            sample_id = Path(yaml_file).stem
            
            # Get absolute path
            yaml_path = os.path.abspath(yaml_file)
            
            # Write row
            writer.writerow([
                sample_id,
                yaml_path,
                '${protocol}',
                ${num_designs},
                ${budget}
            ])
    
    print(f"Generated samplesheet with {len(yaml_files)} design entries")

    # Generate versions
    with open('versions.yml', 'w') as f:
        f.write(f'"${task.process}":\\n')
        f.write(f'    python: "3.11"\\n')
    """

    stub:
    """
    touch generated_samplesheet.csv
    touch versions.yml
    """
}
