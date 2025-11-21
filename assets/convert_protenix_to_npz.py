#!/usr/bin/env python3
"""
Convert Protenix confidence JSON to NPZ format compatible with ipSAE

This script extracts the PAE (Predicted Aligned Error) matrix from Protenix
confidence JSON files and converts it to NPZ format that can be used by ipSAE.

Usage:
    python convert_protenix_to_npz.py <input.json> <output.npz>

Input:
    - Protenix confidence JSON file (e.g., *_confidence*.json)

Output:
    - NPZ file with 'predicted_aligned_error' key containing the PAE matrix
"""

import json
import numpy as np
import argparse
import sys
from pathlib import Path


def find_pae_matrix(data, verbose=True):
    """
    Search for PAE matrix in Protenix JSON structure.
    
    Protenix and AlphaFold3 can store PAE data under various keys.
    This function searches common locations.
    
    Args:
        data: Parsed JSON dictionary
        verbose: Print search progress
        
    Returns:
        numpy array of PAE matrix or None if not found
    """
    # Common top-level keys for PAE data
    keys_to_check = [
        'pae',
        'predicted_aligned_error', 
        'token_pair_predicted_aligned_error',
        'contact_probs',
        'contact_probabilities'
    ]
    
    # Check top-level keys first
    for key in keys_to_check:
        if key in data:
            pae_matrix = np.array(data[key])
            if verbose:
                print(f"✓ Found PAE matrix under key: '{key}'")
            return pae_matrix
    
    # Check nested structures (common in AlphaFold3/Protenix)
    nested_paths = [
        ('confidence', 'pae'),
        ('confidence', 'predicted_aligned_error'),
        ('scores', 'pae'),
        ('scores', 'predicted_aligned_error'),
    ]
    
    for path in nested_paths:
        temp_data = data
        found = True
        for key in path:
            if isinstance(temp_data, dict) and key in temp_data:
                temp_data = temp_data[key]
            else:
                found = False
                break
        
        if found:
            pae_matrix = np.array(temp_data)
            if verbose:
                print(f"✓ Found PAE matrix at nested path: {' -> '.join(path)}")
            return pae_matrix
    
    return None


def validate_pae_matrix(pae_matrix):
    """
    Validate PAE matrix format and values.
    
    Args:
        pae_matrix: numpy array to validate
        
    Returns:
        bool: True if valid, False otherwise
    """
    # Must be 2D
    if pae_matrix.ndim != 2:
        print(f"ERROR: PAE matrix must be 2D, got {pae_matrix.ndim}D")
        return False
    
    # Must be square
    if pae_matrix.shape[0] != pae_matrix.shape[1]:
        print(f"ERROR: PAE matrix must be square, got shape {pae_matrix.shape}")
        return False
    
    # Check value range (PAE typically 0-30 Angstroms)
    if np.any(pae_matrix < 0):
        print(f"WARNING: PAE contains negative values (min: {pae_matrix.min()})")
    
    if np.any(pae_matrix > 100):
        print(f"WARNING: PAE contains unusually large values (max: {pae_matrix.max()})")
    
    return True


def convert_protenix_to_ipsae(json_path, output_path, verbose=True):
    """
    Main conversion function.
    
    Args:
        json_path: Path to input Protenix JSON file
        output_path: Path to output NPZ file
        verbose: Print progress messages
    """
    if verbose:
        print("=" * 60)
        print("Protenix to ipSAE NPZ Converter")
        print("=" * 60)
        print(f"Input:  {json_path}")
        print(f"Output: {output_path}")
        print()
    
    # Load JSON file
    try:
        with open(json_path, 'r') as f:
            data = json.load(f)
        if verbose:
            print(f"✓ Successfully loaded JSON file")
    except FileNotFoundError:
        print(f"ERROR: File not found: {json_path}")
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"ERROR: Invalid JSON format: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"ERROR: Failed to read file: {e}")
        sys.exit(1)
    
    # Find PAE matrix
    if verbose:
        print(f"\nSearching for PAE matrix...")
    
    pae_matrix = find_pae_matrix(data, verbose=verbose)
    
    if pae_matrix is None:
        print()
        print("ERROR: Could not find PAE matrix in JSON file")
        print(f"Available top-level keys: {list(data.keys())}")
        
        # Try to provide helpful diagnostics
        if 'confidence' in data:
            print(f"Keys in 'confidence': {list(data['confidence'].keys())}")
        if 'scores' in data:
            print(f"Keys in 'scores': {list(data['scores'].keys())}")
        
        sys.exit(1)
    
    # Validate matrix
    if verbose:
        print(f"\nValidating PAE matrix...")
        print(f"  Shape: {pae_matrix.shape}")
        print(f"  Data type: {pae_matrix.dtype}")
        print(f"  Value range: [{pae_matrix.min():.2f}, {pae_matrix.max():.2f}]")
        print(f"  Mean PAE: {pae_matrix.mean():.2f}")
    
    if not validate_pae_matrix(pae_matrix):
        print("\nERROR: PAE matrix validation failed")
        sys.exit(1)
    
    # Convert to float32 for consistency with AlphaFold outputs
    if pae_matrix.dtype != np.float32:
        if verbose:
            print(f"\nConverting from {pae_matrix.dtype} to float32...")
        pae_matrix = pae_matrix.astype(np.float32)
    
    # Save as NPZ
    try:
        # Create output directory if it doesn't exist
        output_path = Path(output_path)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        
        # Save with the key that ipSAE expects
        np.savez_compressed(
            output_path, 
            predicted_aligned_error=pae_matrix
        )
        
        if verbose:
            print(f"\n✓ Successfully saved NPZ file")
            print(f"  Location: {output_path}")
            print(f"  Size: {output_path.stat().st_size / 1024:.1f} KB")
            print()
            print("=" * 60)
            print("Conversion complete!")
            print("=" * 60)
        
    except Exception as e:
        print(f"\nERROR: Failed to write NPZ file: {e}")
        sys.exit(1)


def main():
    """Command-line interface"""
    parser = argparse.ArgumentParser(
        description='Convert Protenix confidence JSON to ipSAE-compatible NPZ format',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Convert a single file
  python convert_protenix_to_npz.py confidence.json output.npz
  
  # Quiet mode
  python convert_protenix_to_npz.py confidence.json output.npz --quiet

Notes:
  - Input must be a valid JSON file from Protenix prediction
  - Output NPZ will contain 'predicted_aligned_error' key
  - The PAE matrix must be square (N_residues x N_residues)
        """
    )
    
    parser.add_argument(
        'input_json',
        type=str,
        help='Input Protenix confidence JSON file'
    )
    
    parser.add_argument(
        'output_npz',
        type=str,
        help='Output NPZ file path'
    )
    
    parser.add_argument(
        '-q', '--quiet',
        action='store_true',
        help='Suppress progress messages'
    )
    
    parser.add_argument(
        '-v', '--version',
        action='version',
        version='%(prog)s 1.0.0'
    )
    
    args = parser.parse_args()
    
    # Run conversion
    convert_protenix_to_ipsae(
        args.input_json, 
        args.output_npz,
        verbose=not args.quiet
    )


if __name__ == "__main__":
    main()
