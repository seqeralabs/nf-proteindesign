process GENERATE_DESIGN_VARIANTS {
    tag "${meta.id}"
    label 'process_low'
    
    publishDir "${params.outdir}/${meta.id}/design_variants", mode: params.publish_dir_mode

    conda "conda-forge::python=3.11 conda-forge::pyyaml=6.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://python:3.11' :
        'python:3.11' }"

    input:
    tuple val(meta), path(target_structure)

    output:
    tuple val(meta), path("design_variants/*.yaml"), emit: design_yamls
    path "design_info.txt", emit: info
    path "versions.yml", emit: versions

    script:
    def chain_ids = meta.target_chain_ids ?: 'A'
    def min_length = meta.min_length ?: 50
    def max_length = meta.max_length ?: 150
    def length_step = meta.length_step ?: 20
    def n_variants_per_length = meta.n_variants_per_length ?: 3
    def design_type = meta.design_type ?: 'protein'  // protein, peptide, nanobody
    
    """
    #!/usr/bin/env python3
    import yaml
    import os
    from pathlib import Path

    # Create output directory
    os.makedirs('design_variants', exist_ok=True)

    # Parse parameters
    target_file = "${target_structure}"
    target_file_basename = os.path.basename("${target_structure}")
    target_chains = "${chain_ids}".split(',')
    min_len = int(${min_length})
    max_len = int(${max_length})
    step = int(${length_step})
    n_per_length = int(${n_variants_per_length})
    design_type = "${design_type}"

    # Generate length ranges
    lengths = list(range(min_len, max_len + 1, step))
    if max_len not in lengths:
        lengths.append(max_len)

    # Store generated design info
    design_count = 0
    info_lines = []

    # Generate variants for each length range
    for length in lengths:
        for variant_idx in range(n_per_length):
            design_count += 1
            design_id = f"${meta.id}_len{length}_v{variant_idx + 1}"
            
            # Define the base entity for designed molecule
            if design_type == 'peptide':
                designed_entity = {
                    'peptide': {
                        'id': 'C',
                        'sequence': f"{length}"
                    }
                }
                # For single-length peptides, use exact length
                designed_entity['peptide']['sequence'] = f"{length}"
            elif design_type == 'nanobody':
                designed_entity = {
                    'nanobody': {
                        'id': 'C',
                        'sequence': f"{length-5}..{length+5}"  # Narrower range for nanobodies
                    }
                }
            else:  # protein (default)
                # Create a range around the target length
                range_start = max(length - 10, min_len)
                range_end = min(length + 10, max_len)
                designed_entity = {
                    'protein': {
                        'id': 'C',
                        'sequence': f"{range_start}..{range_end}"
                    }
                }

            # Build the design specification
            design_spec = {
                'entities': [
                    designed_entity,
                    {
                        'file': {
                            'path': target_file_basename,
                            'include': []
                        }
                    }
                ]
            }

            # Add target chains
            for chain in target_chains:
                design_spec['entities'][1]['file']['include'].append({
                    'chain': {'id': chain.strip()}
                })

            # Add optional constraints/specifications based on variant
            # This adds diversity between variants of same length
            if variant_idx == 1:
                # Variant 2: Add composition constraint
                if design_type == 'protein':
                    designed_entity['protein']['composition'] = {
                        'min_helix': 0.3,
                        'min_sheet': 0.2
                    }
            elif variant_idx == 2:
                # Variant 3: Different strategy (e.g., more compact)
                if design_type == 'protein':
                    designed_entity['protein']['compactness'] = 'high'

            # Write design YAML
            yaml_file = f"design_variants/{design_id}.yaml"
            with open(yaml_file, 'w') as f:
                yaml.dump(design_spec, f, default_flow_style=False, sort_keys=False)
            
            info_lines.append(f"{design_id}\\t{yaml_file}\\tlength_range:{designed_entity[design_type].get('sequence', length)}\\tvariant:{variant_idx + 1}")

    # Write design info file
    with open('design_info.txt', 'w') as f:
        f.write(f"# Generated {design_count} design variants for target: {target_file}\\n")
        f.write(f"# Design type: {design_type}\\n")
        f.write(f"# Length range: {min_len}-{max_len}\\n")
        f.write(f"# Variants per length: {n_per_length}\\n")
        f.write("# design_id\\tyaml_file\\tparameters\\tvariant\\n")
        for line in info_lines:
            f.write(line + "\\n")

    print(f"Generated {design_count} design variant YAML files")

    # Generate versions
    with open('versions.yml', 'w') as f:
        f.write(f'"${task.process}":\\n')
        f.write(f'    python: "3.11"\\n')
        f.write(f'    pyyaml: "6.0"\\n')
    """

    stub:
    """
    mkdir -p design_variants
    touch design_variants/design_1.yaml
    touch design_variants/design_2.yaml
    touch design_info.txt
    touch versions.yml
    """
}
