process FORMAT_BINDING_SITES {
    tag "${meta.id}"
    label 'process_low'
    
    publishDir "${params.outdir}/${meta.id}/boltz2_designs", mode: params.publish_dir_mode

    conda "conda-forge::python=3.11 conda-forge::pyyaml=6.0 conda-forge::biopython=1.81"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://quay.io/biocontainers/mulled-v2-3a59640f3fe1ed11819984087d31d68600200c3f:185a25ca79923df85b58f42deb48f5ac4481e91f-0' :
        'quay.io/biocontainers/mulled-v2-3a59640f3fe1ed11819984087d31d68600200c3f:185a25ca79923df85b58f42deb48f5ac4481e91f-0' }"

    input:
    tuple val(meta), path(protein_structure), path(predictions_csv), path(residues_csv)

    output:
    tuple val(meta), path("design_variants/*.yaml"), emit: design_yamls
    path "design_info.txt", emit: info
    path "pocket_summary.txt", emit: pocket_summary
    path "versions.yml", emit: versions

    script:
    def top_n_pockets = meta.top_n_pockets ?: params.top_n_pockets ?: 3
    def min_pocket_score = meta.min_pocket_score ?: params.min_pocket_score ?: 0.5
    def binding_region_mode = meta.binding_region_mode ?: params.binding_region_mode ?: 'residues'  // 'residues' or 'bounding_box'
    def expand_region = meta.expand_region ?: params.expand_region ?: 5  // Expand binding region by N residues
    def min_design_length = meta.min_length ?: params.min_design_length ?: 50
    def max_design_length = meta.max_length ?: params.max_design_length ?: 150
    def design_type = meta.design_type ?: 'protein'
    
    """
    #!/usr/bin/env python3
    import yaml
    import csv
    import os
    from pathlib import Path
    from collections import defaultdict
    from Bio.PDB import PDBParser, Select, PDBIO
    import numpy as np

    # Create output directory
    os.makedirs('design_variants', exist_ok=True)

    # Parse P2Rank predictions
    pockets = []
    with open('${predictions_csv}', 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            if row['name'].strip():  # Skip empty rows
                pockets.append({
                    'rank': int(row['rank']),
                    'name': row['name'],
                    'score': float(row['score']),
                    'probability': float(row['probability']),
                    'center_x': float(row['center_x']),
                    'center_y': float(row['center_y']),
                    'center_z': float(row['center_z']),
                    'residue_ids': row['residue_ids'].split()
                })

    # Parse residue-level predictions
    residue_pockets = defaultdict(list)
    with open('${residues_csv}', 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            if row['chain'] and row['residue_code']:
                key = f"{row['chain']}_{row['residue_code']}"
                residue_pockets[key].append({
                    'pocket_name': row['pocket_name'],
                    'score': float(row['score']) if row['score'] else 0.0
                })

    # Filter pockets by score and select top N
    filtered_pockets = [
        p for p in pockets 
        if p['score'] >= ${min_pocket_score}
    ][:${top_n_pockets}]

    print(f"Found {len(pockets)} total pockets")
    print(f"Selected {len(filtered_pockets)} pockets (score >= ${min_pocket_score}, top {${top_n_pockets}})")

    # Parse PDB structure to get chain information
    parser = PDBParser(QUIET=True)
    structure = parser.get_structure('protein', '${protein_structure}')
    model = structure[0]
    
    # Get all chains and their residues
    chain_info = {}
    for chain in model:
        chain_id = chain.get_id()
        residues = [res for res in chain if res.get_id()[0] == ' ']  # Only standard residues
        chain_info[chain_id] = {
            'residues': residues,
            'length': len(residues)
        }

    # Write pocket summary
    with open('pocket_summary.txt', 'w') as f:
        f.write("# P2Rank Binding Site Predictions\\n")
        f.write(f"# Target: ${protein_structure}\\n")
        f.write(f"# Total pockets found: {len(pockets)}\\n")
        f.write(f"# Selected pockets: {len(filtered_pockets)}\\n")
        f.write(f"# Score threshold: ${min_pocket_score}\\n\\n")
        
        f.write("rank\\tname\\tscore\\tprobability\\tcenter\\tresidue_count\\n")
        for pocket in filtered_pockets:
            center = f"({pocket['center_x']:.2f}, {pocket['center_y']:.2f}, {pocket['center_z']:.2f})"
            f.write(f"{pocket['rank']}\\t{pocket['name']}\\t{pocket['score']:.3f}\\t"
                   f"{pocket['probability']:.3f}\\t{center}\\t{len(pocket['residue_ids'])}\\n")

    # Generate design variants for each pocket
    design_count = 0
    info_lines = []

    for pocket_idx, pocket in enumerate(filtered_pockets, 1):
        design_id = f"${meta.id}_pocket{pocket_idx}_rank{pocket['rank']}"
        
        # Parse residue IDs from pocket (format: "A_123" or "A123")
        binding_residues_by_chain = defaultdict(list)
        for res_id in pocket['residue_ids']:
            # Handle both "A_123" and "A123" formats
            if '_' in res_id:
                chain_id, res_num = res_id.split('_')
            else:
                # Extract chain (first char) and residue number
                chain_id = res_id[0]
                res_num = res_id[1:]
            
            try:
                binding_residues_by_chain[chain_id].append(int(res_num))
            except ValueError:
                print(f"Warning: Could not parse residue ID: {res_id}")
                continue

        # Expand binding region if requested
        if ${expand_region} > 0:
            for chain_id, res_nums in binding_residues_by_chain.items():
                if chain_id in chain_info:
                    expanded = set()
                    for res_num in res_nums:
                        # Add residues within expand_region distance
                        for i in range(-${expand_region}, ${expand_region} + 1):
                            expanded.add(res_num + i)
                    
                    # Filter to valid residue numbers for this chain
                    chain_residues = [r.get_id()[1] for r in chain_info[chain_id]['residues']]
                    valid_expanded = sorted([r for r in expanded if r in chain_residues])
                    binding_residues_by_chain[chain_id] = valid_expanded

        # Build design specification for Boltz2
        design_spec = {
            'entities': []
        }

        # Add target protein chains with binding site constraints
        for chain_id, chain_data in chain_info.items():
            if chain_id in binding_residues_by_chain:
                # This chain contains binding residues
                binding_res = sorted(binding_residues_by_chain[chain_id])
                
                if '${binding_region_mode}' == 'residues':
                    # Specify exact binding residues as constraints
                    design_spec['entities'].append({
                        'protein': {
                            'id': chain_id,
                            'file': {
                                'path': '${protein_structure}',
                                'chain': chain_id
                            },
                            'binding_residues': binding_res
                        }
                    })
                else:  # bounding_box mode
                    # Calculate bounding box around binding residues
                    coords = []
                    for res in chain_data['residues']:
                        if res.get_id()[1] in binding_res:
                            for atom in res:
                                coords.append(atom.get_coord())
                    
                    if coords:
                        coords = np.array(coords)
                        min_coords = coords.min(axis=0)
                        max_coords = coords.max(axis=0)
                        
                        design_spec['entities'].append({
                            'protein': {
                                'id': chain_id,
                                'file': {
                                    'path': '${protein_structure}',
                                    'chain': chain_id
                                },
                                'binding_box': {
                                    'min': [float(x) for x in min_coords],
                                    'max': [float(x) for x in max_coords]
                                }
                            }
                        })
            else:
                # Non-binding chain - include as-is
                design_spec['entities'].append({
                    'file': {
                        'path': '${protein_structure}',
                        'include': [{'chain': {'id': chain_id}}]
                    }
                })

        # Add designed binding partner
        if '${design_type}' == 'peptide':
            design_spec['entities'].append({
                'peptide': {
                    'id': 'BINDER',
                    'sequence': f"${min_design_length}..${max_design_length}"
                }
            })
        elif '${design_type}' == 'nanobody':
            design_spec['entities'].append({
                'nanobody': {
                    'id': 'BINDER',
                    'sequence': f"${min_design_length}..${max_design_length}"
                }
            })
        else:  # protein (default)
            design_spec['entities'].append({
                'protein': {
                    'id': 'BINDER',
                    'sequence': f"${min_design_length}..${max_design_length}"
                }
            })

        # Add pocket center as spatial constraint
        design_spec['constraints'] = {
            'target_binding_site': {
                'center': [pocket['center_x'], pocket['center_y'], pocket['center_z']],
                'radius': 15.0  # Angstroms - typical binding site radius
            }
        }

        # Write design YAML
        yaml_file = f"design_variants/{design_id}.yaml"
        with open(yaml_file, 'w') as f:
            yaml.dump(design_spec, f, default_flow_style=False, sort_keys=False)
        
        # Record info
        binding_chain_summary = ', '.join([
            f"{chain}:{len(residues)}_res" 
            for chain, residues in binding_residues_by_chain.items()
        ])
        info_lines.append(
            f"{design_id}\\t{yaml_file}\\t"
            f"pocket:{pocket['name']}\\tscore:{pocket['score']:.3f}\\t"
            f"binding_chains:{binding_chain_summary}"
        )
        design_count += 1

    # Write design info file
    with open('design_info.txt', 'w') as f:
        f.write(f"# Generated {design_count} Boltz2 design specifications from P2Rank predictions\\n")
        f.write(f"# Target: ${protein_structure}\\n")
        f.write(f"# Binding region mode: ${binding_region_mode}\\n")
        f.write(f"# Expand region: ${expand_region} residues\\n")
        f.write(f"# Design type: ${design_type}\\n")
        f.write(f"# Design length range: ${min_design_length}-${max_design_length}\\n")
        f.write("# design_id\\tyaml_file\\tpocket_info\\tscore\\tbinding_chains\\n")
        for line in info_lines:
            f.write(line + "\\n")

    print(f"Generated {design_count} Boltz2 design YAML files from P2Rank predictions")

    # Generate versions
    with open('versions.yml', 'w') as f:
        f.write(f'"${task.process}":\\n')
        f.write(f'    python: "3.11"\\n')
        f.write(f'    pyyaml: "6.0"\\n')
        f.write(f'    biopython: "1.81"\\n')
    """

    stub:
    """
    mkdir -p design_variants
    touch design_variants/design_1.yaml
    touch design_variants/design_2.yaml
    touch design_info.txt
    touch pocket_summary.txt
    touch versions.yml
    """
}
