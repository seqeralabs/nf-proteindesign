#!/usr/bin/env python3
"""
Extract target protein sequence from CIF or PDB file.

For minibinder design, the target is typically the larger protein (not the designed binder).
This script extracts sequences from all chains and outputs them for use in Protenix multimer prediction.
"""

import argparse
import sys
from pathlib import Path


def parse_cif_sequences(cif_file):
    """
    Parse sequences from mmCIF file.
    
    Returns:
        dict: {chain_id: sequence}
    """
    sequences = {}
    current_entity = None
    current_sequence = []
    
    try:
        with open(cif_file, 'r') as f:
            in_entity_poly = False
            in_entity_poly_seq = False
            entity_to_chain = {}
            
            for line in f:
                line = line.strip()
                
                # Parse entity to chain mapping
                if line.startswith('_struct_asym.'):
                    in_entity_poly = True
                    continue
                
                if in_entity_poly and line and not line.startswith('_') and not line.startswith('#'):
                    parts = line.split()
                    if len(parts) >= 3:
                        # Format: chain_id entity_id details
                        chain_id = parts[0]
                        entity_id = parts[1]
                        entity_to_chain[entity_id] = chain_id
                    continue
                
                # Parse sequences
                if line.startswith('_entity_poly_seq.'):
                    in_entity_poly_seq = True
                    continue
                
                if in_entity_poly_seq:
                    if line.startswith('_') or line.startswith('#') or line.startswith('loop_'):
                        in_entity_poly_seq = False
                        continue
                    
                    if line:
                        parts = line.split()
                        if len(parts) >= 3:
                            entity_id = parts[0]
                            residue = parts[2]  # 3-letter code
                            
                            # Convert 3-letter to 1-letter
                            aa_map = {
                                'ALA': 'A', 'CYS': 'C', 'ASP': 'D', 'GLU': 'E',
                                'PHE': 'F', 'GLY': 'G', 'HIS': 'H', 'ILE': 'I',
                                'LYS': 'K', 'LEU': 'L', 'MET': 'M', 'ASN': 'N',
                                'PRO': 'P', 'GLN': 'Q', 'ARG': 'R', 'SER': 'S',
                                'THR': 'T', 'VAL': 'V', 'TRP': 'W', 'TYR': 'Y',
                                'UNK': 'X'
                            }
                            
                            if entity_id not in sequences:
                                sequences[entity_id] = []
                            
                            single_letter = aa_map.get(residue, 'X')
                            sequences[entity_id].append(single_letter)
            
            # Convert to chain IDs and join sequences
            chain_sequences = {}
            for entity_id, seq_list in sequences.items():
                chain_id = entity_to_chain.get(entity_id, entity_id)
                chain_sequences[chain_id] = ''.join(seq_list)
            
            return chain_sequences
            
    except Exception as e:
        print(f"Error parsing CIF file {cif_file}: {e}", file=sys.stderr)
        return {}


def parse_pdb_sequences(pdb_file):
    """
    Parse sequences from PDB file using SEQRES records.
    
    Returns:
        dict: {chain_id: sequence}
    """
    sequences = {}
    
    aa_map = {
        'ALA': 'A', 'CYS': 'C', 'ASP': 'D', 'GLU': 'E',
        'PHE': 'F', 'GLY': 'G', 'HIS': 'H', 'ILE': 'I',
        'LYS': 'K', 'LEU': 'L', 'MET': 'M', 'ASN': 'N',
        'PRO': 'P', 'GLN': 'Q', 'ARG': 'R', 'SER': 'S',
        'THR': 'T', 'VAL': 'V', 'TRP': 'W', 'TYR': 'Y',
        'UNK': 'X'
    }
    
    try:
        with open(pdb_file, 'r') as f:
            for line in f:
                if line.startswith('SEQRES'):
                    chain_id = line[11:12].strip()
                    residues = line[19:].split()
                    
                    if chain_id not in sequences:
                        sequences[chain_id] = []
                    
                    for res in residues:
                        single_letter = aa_map.get(res, 'X')
                        sequences[chain_id].append(single_letter)
        
        # Join sequences
        for chain_id in sequences:
            sequences[chain_id] = ''.join(sequences[chain_id])
        
        return sequences
        
    except Exception as e:
        print(f"Error parsing PDB file {pdb_file}: {e}", file=sys.stderr)
        return {}


def identify_target_chain(sequences, designed_chain=None):
    """
    Identify the target chain (usually the longest chain, or not the designed binder).
    
    Args:
        sequences: dict of {chain_id: sequence}
        designed_chain: optional chain ID of the designed binder to exclude
    
    Returns:
        tuple: (chain_id, sequence) of the target
    """
    if not sequences:
        return None, None
    
    # If designed chain is specified, exclude it
    if designed_chain and designed_chain in sequences:
        candidates = {k: v for k, v in sequences.items() if k != designed_chain}
        if not candidates:
            print(f"Warning: Only designed chain {designed_chain} found", file=sys.stderr)
            candidates = sequences
    else:
        candidates = sequences
    
    # Return the longest sequence (typically the target)
    target_chain = max(candidates.items(), key=lambda x: len(x[1]))
    return target_chain


def main():
    parser = argparse.ArgumentParser(
        description='Extract target protein sequence from structure file'
    )
    parser.add_argument(
        'structure_file',
        help='Input CIF or PDB file'
    )
    parser.add_argument(
        '--output',
        '-o',
        help='Output FASTA file (default: stdout)'
    )
    parser.add_argument(
        '--designed-chain',
        help='Chain ID of the designed binder to exclude from target selection'
    )
    parser.add_argument(
        '--all-chains',
        action='store_true',
        help='Output all chains, not just the target'
    )
    parser.add_argument(
        '--format',
        choices=['fasta', 'plain'],
        default='fasta',
        help='Output format (default: fasta)'
    )
    
    args = parser.parse_args()
    
    # Determine file type
    structure_path = Path(args.structure_file)
    if not structure_path.exists():
        print(f"Error: File not found: {args.structure_file}", file=sys.stderr)
        sys.exit(1)
    
    suffix = structure_path.suffix.lower()
    
    # Parse sequences
    if suffix == '.cif':
        sequences = parse_cif_sequences(args.structure_file)
    elif suffix in ['.pdb', '.ent']:
        sequences = parse_pdb_sequences(args.structure_file)
    else:
        print(f"Error: Unsupported file format: {suffix}", file=sys.stderr)
        print("Supported formats: .cif, .pdb, .ent", file=sys.stderr)
        sys.exit(1)
    
    if not sequences:
        print("Error: No sequences found in structure file", file=sys.stderr)
        sys.exit(1)
    
    # Prepare output
    output_file = sys.stdout
    if args.output:
        output_file = open(args.output, 'w')
    
    try:
        if args.all_chains:
            # Output all chains
            for chain_id, sequence in sequences.items():
                if args.format == 'fasta':
                    output_file.write(f">{structure_path.stem}_chain_{chain_id}\n")
                    output_file.write(f"{sequence}\n")
                else:
                    output_file.write(f"{sequence}\n")
        else:
            # Output only target chain
            target_chain_id, target_sequence = identify_target_chain(
                sequences,
                designed_chain=args.designed_chain
            )
            
            if target_sequence:
                if args.format == 'fasta':
                    output_file.write(f">{structure_path.stem}_target_chain_{target_chain_id}\n")
                    output_file.write(f"{target_sequence}\n")
                else:
                    output_file.write(f"{target_sequence}\n")
                
                # Print summary to stderr
                print(f"Extracted target chain {target_chain_id} ({len(target_sequence)} residues)", 
                      file=sys.stderr)
                print(f"Total chains in structure: {len(sequences)}", file=sys.stderr)
            else:
                print("Error: Could not identify target chain", file=sys.stderr)
                sys.exit(1)
    
    finally:
        if args.output:
            output_file.close()


if __name__ == '__main__':
    main()
