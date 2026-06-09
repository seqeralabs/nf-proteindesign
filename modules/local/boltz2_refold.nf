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
    
    // Publish results - use parent_id to group by original design
    // meta.parent_id already points to the original sample_id from the samplesheet
    publishDir "${params.outdir}/${meta.parent_id ?: meta.id}/boltz2", mode: params.publish_dir_mode

    container 'giosbiostructures/boltz2:latest'
    
    errorStrategy 'ignore'
    
    // GPU acceleration - Boltz-2 benefits from GPU for efficient prediction
    accelerator 1, type: 'nvidia-gpu'

    input:
    tuple val(meta), path(mpnn_sequences), path(target_sequence_file), path(target_msa), path(target_template)
    path cache_dir

    output:
    tuple val(meta), path("${meta.id}_boltz2_output"), emit: predictions
    tuple val(meta), path("${meta.id}_boltz2_output/*.cif"), optional: true, emit: structures
    tuple val(meta), path("${meta.id}_boltz2_output/*confidence*.json"), optional: true, emit: confidence
    tuple val(meta), path("${meta.id}_boltz2_output/*pae*.npz"), optional: true, emit: pae_npz
    tuple val(meta), path("${meta.id}_boltz2_output/*affinity*.json"), optional: true, emit: affinity
    path "versions.yml", emit: versions

    script:
    def use_msa = params.boltz2_use_msa ? '--use_msa_server' : ''
    def cache_opt = cache_dir.name != 'EMPTY_BOLTZ2_CACHE' ? "--cache ${cache_dir}" : ''
    def num_recycling = params.boltz2_num_recycling ?: 3
    def num_diffusion = params.boltz2_num_diffusion ?: 5
    def has_target_msa = target_msa.name != 'NO_MSA'
    def has_target_template = target_template.name != 'NO_TEMPLATE'
    """
    #!/bin/bash
    set -euo pipefail

    echo "Torch float32 matmul precision: ${params.boltz2_torch_precision ?: 'medium'}"

    # Fix for Numba caching error in containers
    export NUMBA_CACHE_DIR="\${PWD}/numba_cache"

    # Disable CUDA shader cache to prevent root-owned .nv directory
    # that causes AccessDeniedException when Nextflow collects outputs
    export CUDA_CACHE_DISABLE=1
    mkdir -p "\${NUMBA_CACHE_DIR}"
    
    # Fix for Boltz caching error (tries to write to /.boltz)
    export HOME="\${PWD}"
    
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
    
    # Run Python script to prepare Boltz-2 YAML inputs
    prepare_boltz2_input.py \\
        --mpnn_sequences "${mpnn_sequences}" \\
        --target_sequence "\$TARGET_SEQ" \\
        --target_msa "${target_msa}" \\
        --target_template "${target_template}" \\
        --meta_id "${meta.id}" \\
        --parent_id "${meta.parent_id}" \\
        --output_dir "yaml_inputs" \\
        --treat_as_designed \\
        ${params.boltz2_predict_affinity ? '--predict_affinity' : ''}
    
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
        
        # Run Boltz-2 via wrapper to enable Tensor Core optimization
        boltz_predict_wrapper.py --precision ${params.boltz2_torch_precision ?: 'medium'} -- "\${yaml_file}" \\
            --out_dir boltz2_results \\
            --accelerator gpu \\
            --devices 1 \\
            --num_workers 0 \\
            --recycling_steps ${num_recycling} \\
            --diffusion_samples ${num_diffusion} \\
            ${cache_opt} \\
            ${use_msa}

        
        echo "  ✓ Completed \${base_name}"
    done
    
    # Organize outputs
    echo ""
    echo "Organizing outputs..."

    # Move all results to output directory
    # Boltz2 output structure: boltz2_results/boltz_results_<name>/predictions/<name>/<files>
    if [ -d "boltz2_results" ]; then
        mkdir -p ${meta.id}_boltz2_output

        echo "  Searching for Boltz2 output files..."

        # Find all prediction directories (handles nested structure)
        find boltz2_results -type d -name "predictions" | while read pred_parent; do
            # Get the actual prediction subdirectories
            for pred_dir in "\${pred_parent}"/*/; do
                if [ -d "\${pred_dir}" ]; then
                    dir_name=\$(basename "\${pred_dir}")
                    echo "  Processing prediction: \${dir_name}"

                    # Copy CIF files (format: <name>_model_0.cif)
                    find "\${pred_dir}" -name "*.cif" -type f | while read file; do
                        filename=\$(basename "\${file}")
                        cp "\${file}" "${meta.id}_boltz2_output/\${filename}"
                        echo "    Saved CIF: \${filename}"
                    done

                    # Copy PAE NPZ files (format: pae_<name>_model_0.npz)
                    find "\${pred_dir}" -name "pae*.npz" -type f | while read file; do
                        filename=\$(basename "\${file}")
                        cp "\${file}" "${meta.id}_boltz2_output/\${filename}"
                        echo "    Saved PAE: \${filename}"
                    done

                    # Copy pLDDT NPZ files (format: plddt_<name>_model_0.npz)
                    find "\${pred_dir}" -name "plddt*.npz" -type f | while read file; do
                        filename=\$(basename "\${file}")
                        cp "\${file}" "${meta.id}_boltz2_output/\${filename}"
                        echo "    Saved pLDDT: \${filename}"
                    done

                    # Copy confidence JSON files
                    find "\${pred_dir}" -name "*confidence*.json" -type f | while read file; do
                        filename=\$(basename "\${file}")
                        cp "\${file}" "${meta.id}_boltz2_output/\${filename}"
                        echo "    Saved confidence: \${filename}"
                    done

                    # Copy affinity JSON files
                    find "\${pred_dir}" -name "*affinity*.json" -type f | while read file; do
                        filename=\$(basename "\${file}")
                        cp "\${file}" "${meta.id}_boltz2_output/\${filename}"
                        echo "    Saved affinity: \${filename}"
                    done
                fi
            done
        done
    fi
    
    # Count predictions
    CIF_COUNT=\$(find ${meta.id}_boltz2_output -name "*.cif" | wc -l)
    JSON_COUNT=\$(find ${meta.id}_boltz2_output -name "*confidence*.json" | wc -l)
    NPZ_COUNT=\$(find ${meta.id}_boltz2_output -name "*pae*.npz" | wc -l)
    PLDDT_COUNT=\$(find ${meta.id}_boltz2_output -name "plddt*.npz" | wc -l)
    AFFINITY_COUNT=\$(find ${meta.id}_boltz2_output -name "*affinity*.json" | wc -l)
    
    echo ""
    echo "============================================"
    echo "Boltz-2 Prediction Complete"
    echo "============================================"
    echo "Structures predicted: \${CIF_COUNT}"
    echo "Confidence files: \${JSON_COUNT}"
    echo "PAE NPZ files: \${NPZ_COUNT}"
    echo "pLDDT NPZ files: \${PLDDT_COUNT}"
    echo "Affinity predictions: \${AFFINITY_COUNT}"
    echo "Output directory: ${meta.id}_boltz2_output"
    echo "============================================"

    # Fail if no structures were produced (critical for downstream processes)
    if [ "\${CIF_COUNT}" -eq 0 ]; then
        echo ""
        echo "ERROR: No CIF structures were produced by Boltz-2!"
        echo "This will cause downstream processes (IPSAE, PRODIGY) to have no input."
        echo ""
        echo "Debug info - checking boltz2_results directory structure:"
        find boltz2_results -type f 2>/dev/null | head -50 || echo "No boltz2_results directory found"
        exit 1
    fi

    # Warn if no PAE files (needed for IPSAE)
    if [ "\${NPZ_COUNT}" -eq 0 ]; then
        echo ""
        echo "WARNING: No PAE NPZ files were produced. IPSAE will not be able to run."
    fi
    
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
  - Cache directory: ${cache_dir.name != 'EMPTY_BOLTZ2_CACHE' ? cache_dir.toString() : 'default (~/.boltz)'}
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
    # Create stub files with realistic names that match downstream filtering patterns
    touch ${meta.id}_boltz2_output/${meta.id}_model_0.cif
    touch ${meta.id}_boltz2_output/${meta.id}_model_0_confidence.json
    touch ${meta.id}_boltz2_output/pae_${meta.id}_model_0.npz
    touch ${meta.id}_boltz2_output/${meta.id}_model_0_affinity.json
    touch versions.yml
    """
}
