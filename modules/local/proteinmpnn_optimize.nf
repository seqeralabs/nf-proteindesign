process PROTEINMPNN_OPTIMIZE {
    tag "${meta.id}"
    label 'process_medium'
    
    // Publish results
    publishDir "${params.outdir}/${meta.id}/proteinmpnn", mode: params.publish_dir_mode

    conda "bioconda::proteinmpnn=1.0.1"
    container 'cr.seqera.io/scidev/proteinmpnn:1.0.1'

    input:
    tuple val(meta), path(boltzgen_output)

    output:
    tuple val(meta), path("${meta.id}_mpnn_optimized"), emit: optimized_designs
    tuple val(meta), path("${meta.id}_mpnn_optimized/sequences/*.fa"), emit: sequences
    tuple val(meta), path("${meta.id}_mpnn_optimized/scores/*.npz"), emit: scores, optional: true
    path "versions.yml", emit: versions

    script:
    // ProteinMPNN parameters optimized for minibinder design
    def sampling_temp = params.mpnn_sampling_temp ?: 0.1
    def num_seq_per_target = params.mpnn_num_seq_per_target ?: 8
    def batch_size = params.mpnn_batch_size ?: 1
    def seed = params.mpnn_seed ?: 37
    def backbone_noise = params.mpnn_backbone_noise ?: 0.02
    
    // Save scores and probabilities for analysis
    def save_score = params.mpnn_save_score ? 1 : 1  // Default to saving scores
    def save_probs = params.mpnn_save_probs ? 1 : 0  // Default to not saving probs (large files)
    
    // Chain specification (design the binder chain, fix the target chain)
    // By default, we'll design all chains - but this can be customized via params
    def fixed_chains = params.mpnn_fixed_chains ?: ''
    def designed_chains = params.mpnn_designed_chains ?: ''
    
    // Chain specification flags
    def fixed_chains_flag = fixed_chains ? "--fixed_positions_jsonl fixed_chains.jsonl" : ''
    def designed_chains_flag = designed_chains ? "--chain_id_jsonl designed_chains.jsonl" : ''
    
    script:
    """
    # Create output directories
    mkdir -p ${meta.id}_mpnn_optimized/sequences
    mkdir -p ${meta.id}_mpnn_optimized/scores
    mkdir -p ${meta.id}_mpnn_optimized/structures
    
    # Find all CIF/PDB files in Boltzgen final_ranked_designs
    find ${boltzgen_output}/final_ranked_designs -name "*.cif" -o -name "*.pdb" > input_structures.txt
    
    if [ ! -s input_structures.txt ]; then
        echo "ERROR: No structure files found in ${boltzgen_output}/final_ranked_designs"
        exit 1
    fi
    
    # Process each structure individually
    while IFS= read -r structure; do
        base_name=\$(basename "\${structure}" | sed 's/\\.[^.]*\$//')
        echo "Processing \${base_name}..."
        
        # Convert CIF to PDB if needed (ProteinMPNN's parser has issues with CIF format)
        if [[ "\${structure}" == *.cif ]]; then
            echo "  Converting CIF to PDB format..."
            pdb_file="${meta.id}_mpnn_optimized/structures/\${base_name}.pdb"
            
            # Simple CIF to PDB conversion using Python (no external dependencies)
            python3 <<'EOPYTHON'
import sys

def cif_to_pdb(cif_file, pdb_file):
    """Convert mmCIF ATOM records to PDB format"""
    try:
        with open(cif_file, 'r') as f_in, open(pdb_file, 'w') as f_out:
            in_atom_site = False
            atom_serial = 1
            
            for line in f_in:
                # Check if we're in the atom_site loop
                if line.startswith('_atom_site.'):
                    in_atom_site = True
                    continue
                elif line.startswith('#') or (in_atom_site and line.startswith('_')):
                    in_atom_site = False
                    continue
                    
                # Process ATOM/HETATM records
                if in_atom_site and not line.startswith('#') and line.strip():
                    fields = line.split()
                    if len(fields) < 17:  # mmCIF atom_site has many fields
                        continue
                        
                    # Extract fields (order may vary, but typically):
                    # group_PDB, id, type_symbol, label_atom_id, label_alt_id,
                    # label_comp_id, label_asym_id, label_entity_id, label_seq_id,
                    # pdbx_PDB_ins_code, Cartn_x, Cartn_y, Cartn_z,
                    # occupancy, B_iso_or_equiv, pdbx_formal_charge,
                    # auth_seq_id, auth_comp_id, auth_asym_id, auth_atom_id
                    
                    record_type = fields[0] if fields[0] in ['ATOM', 'HETATM'] else 'ATOM'
                    atom_name = fields[3] if len(fields) > 3 else 'CA'
                    res_name = fields[5] if len(fields) > 5 else 'ALA'
                    chain_id = fields[6] if len(fields) > 6 else 'A'
                    res_seq = fields[8] if len(fields) > 8 else '1'
                    x = fields[10] if len(fields) > 10 else '0.000'
                    y = fields[11] if len(fields) > 11 else '0.000'
                    z = fields[12] if len(fields) > 12 else '0.000'
                    occupancy = fields[13] if len(fields) > 13 else '1.00'
                    temp_factor = fields[14] if len(fields) > 14 else '0.00'
                    element = fields[2] if len(fields) > 2 else atom_name[0]
                    
                    # Format PDB ATOM line
                    pdb_line = f"{record_type:<6}{atom_serial:>5}  {atom_name:<4} {res_name:>3} {chain_id:>1}{res_seq:>4}    {float(x):>8.3f}{float(y):>8.3f}{float(z):>8.3f}{float(occupancy):>6.2f}{float(temp_factor):>6.2f}          {element:>2}\n"
                    f_out.write(pdb_line)
                    atom_serial += 1
                    
            f_out.write("END\n")
            print(f"  Successfully converted to PDB: {pdb_file}")
            return True
            
    except Exception as e:
        print(f"ERROR: Failed to convert CIF to PDB: {e}", file=sys.stderr)
        return False

if __name__ == "__main__":
    success = cif_to_pdb("\${structure}", "\${pdb_file}")
    sys.exit(0 if success else 1)
EOPYTHON
            
            if [ \$? -ne 0 ]; then
                echo "ERROR: CIF to PDB conversion failed"
                exit 1
            fi
            
            # Use the converted PDB file
            structure="\${pdb_file}"
        fi
        
        # Create chain specification files if needed
        ${fixed_chains ? """
        python3 <<EOF
import json
chains_dict = {}
chains_dict["\${base_name}"] = {"${fixed_chains}"}
with open("fixed_chains.jsonl", "w") as f:
    json.dump(chains_dict, f)
EOF
        """ : ''}
        
        ${designed_chains ? """
        python3 <<EOF
import json
chains_dict = {}
chains_dict["\${base_name}"] = "${designed_chains}"
with open("designed_chains.jsonl", "w") as f:
    json.dump(chains_dict, f)
EOF
        """ : ''}
        
        # Run ProteinMPNN on this structure
        python3 /home/ProteinMPNN/protein_mpnn_run.py \\
            --pdb_path "\${structure}" \\
            --out_folder ${meta.id}_mpnn_optimized \\
            --num_seq_per_target ${num_seq_per_target} \\
            --sampling_temp "${sampling_temp}" \\
            --seed ${seed} \\
            --batch_size ${batch_size} \\
            --backbone_noise ${backbone_noise} \\
            --save_score ${save_score} \\
            --save_probs ${save_probs} \\
            ${fixed_chains_flag} \\
            ${designed_chains_flag}
        
        # Copy optimized structure to output
        cp "\${structure}" ${meta.id}_mpnn_optimized/structures/\${base_name}_input.\${structure##*.}
        
    done < input_structures.txt
    
    # Move output files to organized directories
    if [ -d "${meta.id}_mpnn_optimized/seqs" ]; then
        mv ${meta.id}_mpnn_optimized/seqs/*.fa ${meta.id}_mpnn_optimized/sequences/ 2>/dev/null || true
        rmdir ${meta.id}_mpnn_optimized/seqs 2>/dev/null || true
    fi
    
    if [ -d "${meta.id}_mpnn_optimized/score_only" ]; then
        mv ${meta.id}_mpnn_optimized/score_only/*.npz ${meta.id}_mpnn_optimized/scores/ 2>/dev/null || true
        rmdir ${meta.id}_mpnn_optimized/score_only 2>/dev/null || true
    fi
    
    # Generate summary statistics
    python3 <<'EOF'
import json
import glob
import numpy as np

sequences_dir = "${meta.id}_mpnn_optimized/sequences"
fasta_files = glob.glob(f"{sequences_dir}/*.fa")

summary = {
    "total_structures": len(fasta_files),
    "total_sequences": 0,
    "avg_sequences_per_structure": 0,
    "parameters": {
        "sampling_temp": ${sampling_temp},
        "num_seq_per_target": ${num_seq_per_target},
        "backbone_noise": ${backbone_noise},
        "seed": ${seed}
    }
}

for fasta in fasta_files:
    with open(fasta) as f:
        seq_count = sum(1 for line in f if line.startswith('>'))
        summary["total_sequences"] += seq_count

if summary["total_structures"] > 0:
    summary["avg_sequences_per_structure"] = summary["total_sequences"] / summary["total_structures"]

with open("${meta.id}_mpnn_optimized/summary.json", "w") as f:
    json.dump(summary, f, indent=2)

print(f"ProteinMPNN optimization complete:")
print(f"  Structures processed: {summary['total_structures']}")
print(f"  Total sequences generated: {summary['total_sequences']}")
print(f"  Average sequences per structure: {summary['avg_sequences_per_structure']:.1f}")
EOF
    
    # Generate version information
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        proteinmpnn: \$(protein_mpnn_run --version 2>&1 | grep -oP 'version \\K[0-9.]+' || echo "1.0.1")
        python: \$(python3 --version 2>&1 | sed 's/Python //g')
    END_VERSIONS
    """

    stub:
    """
    mkdir -p ${meta.id}_mpnn_optimized/sequences
    mkdir -p ${meta.id}_mpnn_optimized/scores
    mkdir -p ${meta.id}_mpnn_optimized/structures
    touch ${meta.id}_mpnn_optimized/sequences/placeholder.fa
    touch ${meta.id}_mpnn_optimized/summary.json
    touch versions.yml
    """
}
