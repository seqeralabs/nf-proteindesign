#!/usr/bin/env python3

import sys
import yaml
import os
import argparse

def parse_args():
    parser = argparse.ArgumentParser(description='Prepare Boltz-2 input YAML files')
    parser.add_argument('--mpnn_sequences', required=True, help='Path to ProteinMPNN sequences FASTA file')
    parser.add_argument('--target_sequence', required=True, help='Target sequence string')
    parser.add_argument('--target_msa', help='Path to target MSA file')
    parser.add_argument('--target_template', help='Path to target template CIF file')
    parser.add_argument('--meta_id', required=True, help='ID for the current design')
    parser.add_argument('--parent_id', required=True, help='Parent ID')
    parser.add_argument('--predict_affinity', action='store_true', help='Enable affinity prediction')
    parser.add_argument('--output_dir', default='yaml_inputs', help='Directory to save YAML files')
    parser.add_argument('--treat_as_designed', action='store_true', help='Treat the first sequence as a designed sequence (do not skip)')
    return parser.parse_args()

def main():
    args = parse_args()
    
    # Read input file path - handle both single file and list (space separated)
    fasta_input = args.mpnn_sequences
    fasta_files = fasta_input.split() if " " in fasta_input else [fasta_input]
    
    target_seq = args.target_sequence
    output_base = args.meta_id
    
    # Check if target MSA is provided and valid
    has_target_msa = False
    target_msa_path = None
    if args.target_msa and args.target_msa != 'NO_MSA' and os.path.exists(args.target_msa):
        has_target_msa = True
        target_msa_path = args.target_msa
    
    # Check if target template is provided and valid
    has_target_template = False
    target_template_path = None
    if args.target_template and args.target_template != 'NO_TEMPLATE' and os.path.exists(args.target_template):
        has_target_template = True
        target_template_path = args.target_template
    
    os.makedirs(args.output_dir, exist_ok=True)
    
    # Process each FASTA file
    yaml_count = 0
    for fasta_file in fasta_files:
        # Parse FASTA sequences
        sequences = []
        current_seq = []
        current_header = None
        
        try:
            with open(fasta_file, 'r') as f:
                for line in f:
                    line = line.strip()
                    if not line: continue
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
        except Exception as e:
            print(f"Error reading FASTA file {fasta_file}: {e}")
            continue
        
        print(f"Found {len(sequences)} sequences in {fasta_file}")
        
        # Determine which sequences to process
        if args.treat_as_designed:
            # If treating as designed, process ALL sequences (including the first one)
            sequences_to_process = sequences
            print(f"Processing all {len(sequences_to_process)} sequences (treating first as designed)")
        else:
            # Default behavior: Skip the first sequence (original from Complexa)
            sequences_to_process = sequences[1:] if len(sequences) > 1 else []
            print(f"Processing {len(sequences_to_process)} new MPNN sequences (skipping original)")
        
        if not sequences_to_process:
            print(f"⚠  Warning: No sequences to process in {fasta_file}")
            continue
        
        # Create Boltz-2 YAML for each sequence
        for idx, (header, binder_seq) in enumerate(sequences_to_process):
            # Create YAML input for Boltz-2
            # Format: binder (designed sequence) + target (original protein)
            # Note: Only target gets MSA; Boltz-2 will infer missing MSA info for binder
            # Ensure binder sequence contains only the first chain (strip any '/' separators)
            binder_seq_clean = binder_seq.split('/')[0] if '/' in binder_seq else binder_seq
            binder_entry = {
                'protein': {
                    'id': 'A',
                    'sequence': binder_seq_clean,
                    'msa': 'empty'
                }
            }

            target_entry = {
                'protein': {
                    'id': 'B',
                    'sequence': target_seq
                }
            }
            if has_target_msa and target_msa_path:
                target_entry['protein']['msa'] = os.path.abspath(target_msa_path)
                print(f"    Adding target MSA: {target_msa_path}")
            
            # Add template configuration if provided
            # Template is always applied to chain B (target) with force=true and threshold=1.0
            if has_target_template and target_template_path:
                target_entry['protein']['templates'] = [{
                    'cif': os.path.abspath(target_template_path),
                    'force': True,
                    'threshold': 1.0,
                    'chain_id': 'B'
                }]
                print(f"    Adding target template: {target_template_path} (force=true, threshold=1.0)")
            
            # Build final YAML input with exactly two entries
            boltz2_input = {
                'version': 1,
                'sequences': [binder_entry, target_entry]
            }
            # Add affinity prediction property (only for single binder case)
            if args.predict_affinity:
                boltz2_input['properties'] = [
                    {'affinity': {'binder': 'A'}}
                ]

            # Write YAML file
            # meta_id is already the full design ID (e.g., 2vsm_r1_s0)
            # Only add suffix if there are multiple sequences in the file
            if len(sequences_to_process) == 1:
                yaml_file = f"{args.output_dir}/{output_base}.yaml"
            else:
                yaml_file = f"{args.output_dir}/{output_base}_seq_{idx}.yaml"

            with open(yaml_file, 'w') as yf:
                yaml.dump(boltz2_input, yf, default_flow_style=False)

            print(f"  Created YAML input: {yaml_file}")
            print(f"    Binder length: {len(binder_seq_clean)}")
            print(f"    Target length: {len(target_seq)}")
            print(f"    Target MSA: {'Yes' if has_target_msa else 'No (will use sequence only)'}")
            print(f"    Binder MSA: Inferred automatically by Boltz-2")

            yaml_count += 1

    print(f"\nTotal YAML files created: {yaml_count}")

if __name__ == "__main__":
    main()
