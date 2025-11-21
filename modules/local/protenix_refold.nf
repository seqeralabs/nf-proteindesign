process PROTENIX_REFOLD {
    tag "${meta.id}"
    label 'process_high_gpu'
    
    // Publish results
    publishDir "${params.outdir}/${meta.parent_id}/protenix", mode: params.publish_dir_mode

    container 'bytedance/protenix:0.7.0'
    
    // GPU acceleration - Protenix requires GPU for efficient prediction
    accelerator 1, type: 'nvidia-gpu'

    input:
    tuple val(meta), path(mpnn_sequences)
    tuple val(target_meta), path(target_sequence_file)
    path extract_target_script

    output:
    tuple val(meta), path("${meta.id}_protenix_output"), emit: predictions
    tuple val(meta), path("${meta.id}_protenix_output/**/*.cif"), optional: true, emit: structures
    tuple val(meta), path("${meta.id}_protenix_output/**/*_confidence*.json"), optional: true, emit: confidence
    path "versions.yml", emit: versions

    script:
    def seed = params.protenix_seed ?: 101
    def use_msa = params.protenix_use_msa ? 'true' : 'false'
    def model_name = params.protenix_model ?: 'protenix_base_default_v0.5.0'
    def num_samples = params.protenix_num_samples ?: 1
    """
    #!/bin/bash
    set -euo pipefail
    
    echo "============================================"
    echo "Protenix Multimer Structure Prediction"
    echo "============================================"
    
    # Check for GPU
    if command -v nvidia-smi &> /dev/null && nvidia-smi &> /dev/null; then
        echo "✓ GPU detected"
        nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
    else
        echo "⚠  No GPU detected - Protenix may run very slowly"
    fi
    
    # Create output directory
    mkdir -p ${meta.id}_protenix_output
    mkdir -p json_inputs
    mkdir -p protenix_results
    
    # Load target sequence
    echo ""
    echo "Loading target sequence..."
    TARGET_SEQ=\$(cat ${target_sequence_file} | tr -d '\\n' | tr -d ' ')
    echo "Target sequence length: \${#TARGET_SEQ}"
    
    # Parse ProteinMPNN FASTA files and create Protenix JSON inputs
    echo ""
    echo "Processing ProteinMPNN sequences..."
    
    FASTA_COUNT=0
    for fasta_file in ${mpnn_sequences}; do
        echo "  Processing \${fasta_file}..."
        
        # Parse FASTA file - ProteinMPNN outputs multiple sequences per file
        python3 <<'PARSE_FASTA'
import sys
import json
import os

fasta_file = "${mpnn_sequences}".split()[0] if " " in "${mpnn_sequences}" else "${mpnn_sequences}"
target_seq = "\${TARGET_SEQ}"
output_base = "${meta.id}"
parent_id = "${meta.parent_id}"

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

print(f"Found {len(sequences)} sequences in FASTA file")

# Create Protenix JSON for each sequence
for idx, (header, binder_seq) in enumerate(sequences):
    # Extract info from header (ProteinMPNN format: >sample, T=0.1, ...)
    sample_name = header.split(',')[0].strip() if ',' in header else header
    
    # Create JSON input for Protenix
    # Format: binder (designed sequence) + target (original protein)
    protenix_input = [{
        "name": f"{output_base}_seq_{idx}",
        "sequences": [
            {
                "proteinChain": {
                    "sequence": binder_seq,
                    "count": 1
                }
            },
            {
                "proteinChain": {
                    "sequence": target_seq,
                    "count": 1
                }
            }
        ]
    }]
    
    # Write JSON file
    json_file = f"json_inputs/{output_base}_seq_{idx}.json"
    with open(json_file, 'w') as jf:
        json.dump(protenix_input, jf, indent=2)
    
    print(f"  Created JSON input: {json_file}")
    print(f"    Binder length: {len(binder_seq)}")
    print(f"    Target length: {len(target_seq)}")

PARSE_FASTA
        
    done
    
    # Count JSON files created
    JSON_COUNT=\$(ls -1 json_inputs/*.json 2>/dev/null | wc -l)
    echo ""
    echo "Created \${JSON_COUNT} JSON input files"
    
    if [ \$JSON_COUNT -eq 0 ]; then
        echo "ERROR: No JSON inputs created"
        exit 1
    fi
    
    # Run Protenix prediction on each JSON
    echo ""
    echo "Running Protenix predictions..."
    
    for json_file in json_inputs/*.json; do
        base_name=\$(basename "\${json_file}" .json)
        echo ""
        echo "  Predicting \${base_name}..."
        
        # Run Protenix
        protenix predict \\
            --input "\${json_file}" \\
            --out_dir protenix_results \\
            --seeds ${seed} \\
            --model_name ${model_name} \\
            --use_msa ${use_msa} \\
            --sample_diffusion.N_sample ${num_samples}
        
        echo "  ✓ Completed \${base_name}"
    done
    
    # Organize outputs
    echo ""
    echo "Organizing outputs..."
    
    # Move all results to output directory
    if [ -d "protenix_results" ]; then
        mv protenix_results/* ${meta.id}_protenix_output/ 2>/dev/null || true
    fi
    
    # Count predictions
    CIF_COUNT=\$(find ${meta.id}_protenix_output -name "*.cif" | wc -l)
    JSON_COUNT=\$(find ${meta.id}_protenix_output -name "*confidence*.json" | wc -l)
    
    echo ""
    echo "============================================"
    echo "Protenix Prediction Complete"
    echo "============================================"
    echo "Structures predicted: \${CIF_COUNT}"
    echo "Confidence files: \${JSON_COUNT}"
    echo "Output directory: ${meta.id}_protenix_output"
    echo "============================================"
    
    # Create summary file
    cat > ${meta.id}_protenix_output/prediction_summary.txt <<SUMMARY
Protenix Multimer Prediction Summary
=====================================

Parent Design: ${meta.parent_id}
Sequence ID: ${meta.id}

Input:
  - ProteinMPNN sequences: ${mpnn_sequences}
  - Target sequence file: ${target_sequence_file}
  - Target sequence length: \${#TARGET_SEQ}

Parameters:
  - Model: ${model_name}
  - Seed: ${seed}
  - Use MSA: ${use_msa}
  - Samples per sequence: ${num_samples}

Output:
  - Total structures predicted: \${CIF_COUNT}
  - Confidence scores: \${JSON_COUNT}

All predictions include:
  - Binder (ProteinMPNN optimized sequence)
  - Target (original protein from Boltzgen)
SUMMARY
    
    # Generate version information
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        protenix: \$(protenix --version 2>&1 | grep -oP 'version \\K[0-9.]+' || echo "0.7.0")
        python: \$(python3 --version 2>&1 | sed 's/Python //g')
    END_VERSIONS
    """

    stub:
    """
    mkdir -p ${meta.id}_protenix_output
    touch ${meta.id}_protenix_output/placeholder.cif
    touch ${meta.id}_protenix_output/placeholder_confidence.json
    touch versions.yml
    """
}
