/*
========================================================================================
    BOLTZ2_REFOLD: Refold ProteinMPNN sequences using Boltz-2
========================================================================================
    This process takes ProteinMPNN-optimized sequences and refolds them as complexes
    with their target proteins using Boltz-2 structure prediction.
    
    Boltz-2 advantages over Protenix:
    - Native NPZ output with PAE/PDE/pLDDT matrices (no conversion needed)
    - Binding affinity predictions included
    - More stable and documented Docker setup
    - MIT licensed, fully open source
----------------------------------------------------------------------------------------
*/

process BOLTZ2_REFOLD {
    tag "${meta.id}"
    label 'process_high_gpu'
    
    // Publish results
    publishDir "${params.outdir}/${meta.parent_id}/boltz2", mode: params.publish_dir_mode

    // Build Boltz-2 container using Wave with conda
    conda "boltz::boltz=1.0.0"
    
    // GPU acceleration - Boltz-2 benefits from GPU for efficient prediction
    accelerator 1, type: 'nvidia-gpu'

    input:
    tuple val(meta), path(mpnn_sequences), path(target_sequence_file)

    output:
    tuple val(meta), path("${meta.id}_boltz2_output"), emit: predictions
    tuple val(meta), path("${meta.id}_boltz2_output/**/*.cif"), optional: true, emit: structures
    tuple val(meta), path("${meta.id}_boltz2_output/**/*confidence*.json"), optional: true, emit: confidence
    tuple val(meta), path("${meta.id}_boltz2_output/**/*pae*.npz"), optional: true, emit: pae_npz
    tuple val(meta), path("${meta.id}_boltz2_output/**/*affinity*.json"), optional: true, emit: affinity
    path "versions.yml", emit: versions

    script:
    def use_msa = params.boltz2_use_msa ? '--use_msa_server' : ''
    def num_recycling = params.boltz2_num_recycling ?: 3
    def num_diffusion = params.boltz2_num_diffusion ?: 200
    """
    #!/bin/bash
    set -euo pipefail
    
    echo "============================================"
    echo "Boltz-2 Multimer Structure Prediction"
    echo "============================================"
    
    # Check for GPU
    if command -v nvidia-smi &> /dev/null && nvidia-smi &> /dev/null; then
        echo "✓ GPU detected"
        nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
    else
        echo "⚠  No GPU detected - Boltz-2 may run very slowly"
    fi
    
    # Create output directory
    mkdir -p ${meta.id}_boltz2_output
    mkdir -p yaml_inputs
    mkdir -p boltz2_results
    
    # Load target sequence
    echo ""
    echo "Loading target sequence..."
    TARGET_SEQ=\$(cat ${target_sequence_file} | tr -d '\\n' | tr -d ' ')
    echo "Target sequence length: \${#TARGET_SEQ}"
    
    # Parse ProteinMPNN FASTA files and create Boltz-2 YAML inputs
    echo ""
    echo "Processing ProteinMPNN sequences..."
    
    python3 <<PARSE_FASTA
import sys
import yaml
import os

# Read input file path - handle both single file and list
fasta_input = "${mpnn_sequences}"
fasta_files = fasta_input.split() if " " in fasta_input else [fasta_input]

target_seq = "\$TARGET_SEQ"
output_base = "${meta.id}"
parent_id = "${meta.parent_id}"

# Process each FASTA file
yaml_count = 0
for fasta_file in fasta_files:
    # Parse FASTA sequences
    sequences = []
    current_seq = []
    current_header = None
    
    with open(fasta_file, 'r') as f:
        for line in f:
            line = line.strip()
            if line.startswith('>'):
                if current_header and current_seq:
                    sequences.append((current_header, ''.join(current_seq)))
                current_header = line[1:]
                current_seq = []
            else:
                current_seq.append(line)
        
        # Add last sequence
        if current_header and current_seq:
            sequences.append((current_header, ''.join(current_seq)))
    
    print(f"Found {len(sequences)} sequences in {fasta_file}")
    
    # Create Boltz-2 YAML for each sequence
    for idx, (header, binder_seq) in enumerate(sequences):
        # Create YAML input for Boltz-2
        # Format: binder (designed sequence) + target (original protein)
        boltz2_input = {
            'version': 1,
            'sequences': [
                {
                    'protein': {
                        'id': 'BINDER',
                        'sequence': binder_seq
                    }
                },
                {
                    'protein': {
                        'id': 'TARGET', 
                        'sequence': target_seq
                    }
                }
            ]
        }
        
        # Add affinity prediction property
        if ${params.boltz2_predict_affinity ? 'True' : 'False'}:
            boltz2_input['properties'] = [
                {'affinity': {'binder': 'BINDER'}}
            ]
        
        # Write YAML file
        yaml_file = f"yaml_inputs/{output_base}_seq_{yaml_count}.yaml"
        with open(yaml_file, 'w') as yf:
            yaml.dump(boltz2_input, yf, default_flow_style=False)
        
        print(f"  Created YAML input: {yaml_file}")
        print(f"    Binder length: {len(binder_seq)}")
        print(f"    Target length: {len(target_seq)}")
        
        yaml_count += 1

print(f"\\nTotal YAML files created: {yaml_count}")
PARSE_FASTA
    
    # Count YAML files created
    YAML_COUNT=\$(ls -1 yaml_inputs/*.yaml 2>/dev/null | wc -l)
    echo ""
    echo "Created \${YAML_COUNT} YAML input files"
    
    if [ \$YAML_COUNT -eq 0 ]; then
        echo "ERROR: No YAML inputs created"
        exit 1
    fi
    
    # Run Boltz-2 prediction on each YAML
    echo ""
    echo "Running Boltz-2 predictions..."
    
    for yaml_file in yaml_inputs/*.yaml; do
        base_name=\$(basename "\${yaml_file}" .yaml)
        echo ""
        echo "  Predicting \${base_name}..."
        
        # Run Boltz-2
        boltz predict "\${yaml_file}" \\
            --out_dir boltz2_results \\
            --recycling_steps ${num_recycling} \\
            --diffusion_samples ${num_diffusion} \\
            ${use_msa}
        
        echo "  ✓ Completed \${base_name}"
    done
    
    # Organize outputs
    echo ""
    echo "Organizing outputs..."
    
    # Move all results to output directory with sequence-specific naming
    if [ -d "boltz2_results" ]; then
        mkdir -p ${meta.id}_boltz2_output
        
        # Process each prediction directory
        for pred_dir in boltz2_results/predictions/*_seq_*; do
            if [ -d "\${pred_dir}" ]; then
                # Extract sequence number from directory name
                seq_num=\$(basename "\${pred_dir}" | grep -oP '_seq_\\K[0-9]+')
                
                echo "  Processing sequence \${seq_num}..."
                
                # Rename files to include sequence suffix
                find "\${pred_dir}" -type f \\( -name "*.cif" -o -name "*.json" -o -name "*.npz" \\) | while read file; do
                    filename=\$(basename "\${file}")
                    extension="\${filename##*.}"
                    basename_without_ext="\${filename%.*}"
                    
                    # Add sequence suffix before extension
                    new_filename="\${basename_without_ext}_seq\${seq_num}.\${extension}"
                    
                    # Copy to output directory
                    cp "\${file}" "${meta.id}_boltz2_output/\${new_filename}"
                    echo "    Saved: \${new_filename}"
                done
            fi
        done
    fi
    
    # Count predictions
    CIF_COUNT=\$(find ${meta.id}_boltz2_output -name "*.cif" | wc -l)
    JSON_COUNT=\$(find ${meta.id}_boltz2_output -name "*confidence*.json" | wc -l)
    NPZ_COUNT=\$(find ${meta.id}_boltz2_output -name "*pae*.npz" | wc -l)
    AFFINITY_COUNT=\$(find ${meta.id}_boltz2_output -name "*affinity*.json" | wc -l)
    
    echo ""
    echo "============================================"
    echo "Boltz-2 Prediction Complete"
    echo "============================================"
    echo "Structures predicted: \${CIF_COUNT}"
    echo "Confidence files: \${JSON_COUNT}"
    echo "PAE NPZ files: \${NPZ_COUNT}"
    echo "Affinity predictions: \${AFFINITY_COUNT}"
    echo "Output directory: ${meta.id}_boltz2_output"
    echo "============================================"
    
    # Create summary file
    cat > ${meta.id}_boltz2_output/prediction_summary.txt <<SUMMARY
Boltz-2 Multimer Prediction Summary
====================================

Parent Design: ${meta.parent_id}
Sequence ID: ${meta.id}

Input:
  - ProteinMPNN sequences: ${mpnn_sequences}
  - Target sequence file: ${target_sequence_file}
  - Target sequence length: \${#TARGET_SEQ}

Parameters:
  - Recycling steps: ${num_recycling}
  - Diffusion samples: ${num_diffusion}
  - Use MSA: ${params.boltz2_use_msa}
  - Predict affinity: ${params.boltz2_predict_affinity}

Output:
  - Total structures predicted: \${CIF_COUNT}
  - Confidence scores: \${JSON_COUNT}
  - PAE NPZ files: \${NPZ_COUNT}
  - Affinity predictions: \${AFFINITY_COUNT}

Notes:
  - NPZ files contain PAE, PDE, and pLDDT matrices
  - No conversion needed for ipSAE (native NPZ format)
  - Affinity values in log(IC50 µM) units
SUMMARY
    
    # Generate version information
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        boltz: \$(boltz --version 2>&1 | grep -oP 'version \\K[0-9.]+' || echo "1.0.0")
        python: \$(python3 --version 2>&1 | sed 's/Python //g')
    END_VERSIONS
    """

    stub:
    """
    mkdir -p ${meta.id}_boltz2_output
    touch ${meta.id}_boltz2_output/placeholder.cif
    touch ${meta.id}_boltz2_output/placeholder_confidence.json
    touch ${meta.id}_boltz2_output/placeholder_pae.npz
    touch ${meta.id}_boltz2_output/placeholder_affinity.json
    touch versions.yml
    """
}
