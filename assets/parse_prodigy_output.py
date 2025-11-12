#!/usr/bin/env python3
"""
Parse PRODIGY output and create a CSV summary file.

PRODIGY output format example:
[+] Reading structure file: structure.pdb
[+] Parsed structure file 1ABC (1 model(s))
[+] Setting selection: A,B
[+] Found 2 chains in structure: A, B
[+] Calculating buried surface area...
[+] Buried Surface Area: 1234.56 A^2
[+] Number of interface contacts (ICs): 123
[+] Number of non-interacting surface residues: 45
[+] Number of charged residues in ICs: 12
[+] Percentage of charged residues in ICs: 9.76%
[+] Number of apolar residues in ICs: 67
[+] Percentage of apolar residues in ICs: 54.47%
[+] Predicted binding affinity (ΔG): -12.34 kcal/mol
[+] Predicted dissociation constant (Kd): 1.23e-09 M at 25.0˚C
"""

import argparse
import re
import csv
import sys


def parse_prodigy_output(input_file):
    """Parse PRODIGY output file and extract key metrics."""
    
    metrics = {
        'buried_surface_area': None,
        'num_interface_contacts': None,
        'num_noninteracting_surface': None,
        'num_charged_residues': None,
        'percent_charged_residues': None,
        'num_apolar_residues': None,
        'percent_apolar_residues': None,
        'predicted_binding_affinity': None,
        'predicted_kd': None,
        'kd_temperature': None
    }
    
    with open(input_file, 'r') as f:
        content = f.read()
    
    # Extract buried surface area
    bsa_match = re.search(r'Buried Surface Area:\s+([\d.]+)\s+A', content)
    if bsa_match:
        metrics['buried_surface_area'] = float(bsa_match.group(1))
    
    # Extract number of interface contacts
    ic_match = re.search(r'Number of interface contacts \(ICs\):\s+(\d+)', content)
    if ic_match:
        metrics['num_interface_contacts'] = int(ic_match.group(1))
    
    # Extract non-interacting surface residues
    nis_match = re.search(r'Number of non-interacting surface residues:\s+(\d+)', content)
    if nis_match:
        metrics['num_noninteracting_surface'] = int(nis_match.group(1))
    
    # Extract charged residues
    charged_match = re.search(r'Number of charged residues in ICs:\s+(\d+)', content)
    if charged_match:
        metrics['num_charged_residues'] = int(charged_match.group(1))
    
    charged_pct_match = re.search(r'Percentage of charged residues in ICs:\s+([\d.]+)%', content)
    if charged_pct_match:
        metrics['percent_charged_residues'] = float(charged_pct_match.group(1))
    
    # Extract apolar residues
    apolar_match = re.search(r'Number of apolar residues in ICs:\s+(\d+)', content)
    if apolar_match:
        metrics['num_apolar_residues'] = int(apolar_match.group(1))
    
    apolar_pct_match = re.search(r'Percentage of apolar residues in ICs:\s+([\d.]+)%', content)
    if apolar_pct_match:
        metrics['percent_apolar_residues'] = float(apolar_pct_match.group(1))
    
    # Extract predicted binding affinity (ΔG)
    dg_match = re.search(r'Predicted binding affinity \(ΔG\):\s+([-\d.]+)\s+kcal/mol', content)
    if dg_match:
        metrics['predicted_binding_affinity'] = float(dg_match.group(1))
    
    # Extract predicted Kd
    kd_match = re.search(r'Predicted dissociation constant \(Kd\):\s+([\d.e+-]+)\s+M\s+at\s+([\d.]+)', content)
    if kd_match:
        metrics['predicted_kd'] = float(kd_match.group(1))
        metrics['kd_temperature'] = float(kd_match.group(2))
    
    return metrics


def write_csv_summary(metrics, structure_id, output_file):
    """Write metrics to CSV file."""
    
    fieldnames = [
        'structure_id',
        'buried_surface_area_A2',
        'num_interface_contacts',
        'num_noninteracting_surface',
        'num_charged_residues',
        'percent_charged_residues',
        'num_apolar_residues',
        'percent_apolar_residues',
        'predicted_binding_affinity_kcal_mol',
        'predicted_kd_M',
        'kd_temperature_C'
    ]
    
    with open(output_file, 'w', newline='') as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()
        
        row = {
            'structure_id': structure_id,
            'buried_surface_area_A2': metrics['buried_surface_area'],
            'num_interface_contacts': metrics['num_interface_contacts'],
            'num_noninteracting_surface': metrics['num_noninteracting_surface'],
            'num_charged_residues': metrics['num_charged_residues'],
            'percent_charged_residues': metrics['percent_charged_residues'],
            'num_apolar_residues': metrics['num_apolar_residues'],
            'percent_apolar_residues': metrics['percent_apolar_residues'],
            'predicted_binding_affinity_kcal_mol': metrics['predicted_binding_affinity'],
            'predicted_kd_M': metrics['predicted_kd'],
            'kd_temperature_C': metrics['kd_temperature']
        }
        
        writer.writerow(row)


def main():
    parser = argparse.ArgumentParser(
        description='Parse PRODIGY output and create CSV summary'
    )
    parser.add_argument(
        '--input',
        required=True,
        help='Input PRODIGY output file'
    )
    parser.add_argument(
        '--output',
        required=True,
        help='Output CSV summary file'
    )
    parser.add_argument(
        '--structure_id',
        required=True,
        help='Structure identifier'
    )
    
    args = parser.parse_args()
    
    # Parse PRODIGY output
    metrics = parse_prodigy_output(args.input)
    
    # Write CSV summary
    write_csv_summary(metrics, args.structure_id, args.output)
    
    print(f"Successfully parsed PRODIGY output and wrote summary to {args.output}")


if __name__ == '__main__':
    main()
