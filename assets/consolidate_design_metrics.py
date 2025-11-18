#!/usr/bin/env python3
"""
Consolidate protein design metrics from multiple sources and generate a ranked report.

This script aggregates metrics from:
- Boltzgen outputs (structure quality, confidence scores)
- ProteinMPNN (sequence optimization scores)
- IPSAE (interface scores)
- PRODIGY (binding affinity predictions)
- Foldseek (structural similarity search results)

The output is a comprehensive ranked report showing which designs performed best
across multiple metrics.
"""

import argparse
import csv
import json
import glob
import os
import sys
from pathlib import Path
from collections import defaultdict
import re


def parse_ipsae_scores(ipsae_file):
    """
    Parse IPSAE score file.
    
    Format expected:
    IPSAE: <score>
    
    Returns:
        dict with 'ipsae_score'
    """
    metrics = {'ipsae_score': None}
    
    if not os.path.exists(ipsae_file):
        return metrics
    
    try:
        with open(ipsae_file, 'r') as f:
            for line in f:
                if line.startswith('IPSAE:'):
                    score = float(line.split(':')[1].strip())
                    metrics['ipsae_score'] = score
                    break
    except Exception as e:
        print(f"Warning: Could not parse IPSAE file {ipsae_file}: {e}", file=sys.stderr)
    
    return metrics


def parse_prodigy_csv(prodigy_csv):
    """
    Parse PRODIGY CSV output.
    
    Returns:
        dict with PRODIGY metrics
    """
    metrics = {
        'buried_surface_area': None,
        'num_interface_contacts': None,
        'predicted_binding_affinity': None,
        'predicted_kd': None
    }
    
    if not os.path.exists(prodigy_csv):
        return metrics
    
    try:
        with open(prodigy_csv, 'r') as f:
            reader = csv.DictReader(f)
            for row in reader:
                metrics['buried_surface_area'] = float(row['buried_surface_area_A2']) if row.get('buried_surface_area_A2') else None
                metrics['num_interface_contacts'] = int(row['num_interface_contacts']) if row.get('num_interface_contacts') else None
                metrics['predicted_binding_affinity'] = float(row['predicted_binding_affinity_kcal_mol']) if row.get('predicted_binding_affinity_kcal_mol') else None
                metrics['predicted_kd'] = float(row['predicted_kd_M']) if row.get('predicted_kd_M') else None
                break  # Only first row
    except Exception as e:
        print(f"Warning: Could not parse PRODIGY CSV {prodigy_csv}: {e}", file=sys.stderr)
    
    return metrics


def parse_foldseek_summary(foldseek_tsv):
    """
    Parse Foldseek summary TSV output.
    
    Returns:
        dict with top Foldseek hit metrics
    """
    metrics = {
        'foldseek_top_hit': None,
        'foldseek_top_evalue': None,
        'foldseek_top_bits': None,
        'foldseek_num_hits': 0
    }
    
    if not os.path.exists(foldseek_tsv):
        return metrics
    
    try:
        with open(foldseek_tsv, 'r') as f:
            # Skip header line
            next(f)
            hit_count = 0
            for line in f:
                hit_count += 1
                # First data line is the top hit
                if hit_count == 1:
                    fields = line.strip().split('\t')
                    if len(fields) >= 12:
                        metrics['foldseek_top_hit'] = fields[1]  # target name
                        metrics['foldseek_top_evalue'] = float(fields[10])  # evalue
                        metrics['foldseek_top_bits'] = float(fields[11])  # bits
            
            metrics['foldseek_num_hits'] = hit_count
    except Exception as e:
        print(f"Warning: Could not parse Foldseek TSV {foldseek_tsv}: {e}", file=sys.stderr)
    
    return metrics


def parse_boltzgen_predictions(predictions_dir):
    """
    Parse Boltzgen predictions directory to extract confidence scores.
    
    Looks for confidence metrics in structure files or accompanying JSON/metadata files.
    
    Returns:
        dict with Boltzgen metrics
    """
    metrics = {
        'model_confidence': None,
        'plddt_avg': None,
        'ptm_score': None
    }
    
    if not os.path.exists(predictions_dir):
        return metrics
    
    # Look for JSON files with scores
    json_files = glob.glob(os.path.join(predictions_dir, '*.json'))
    for json_file in json_files:
        try:
            with open(json_file, 'r') as f:
                data = json.load(f)
                
                # Try to extract common confidence metrics
                if 'model_confidence' in data:
                    metrics['model_confidence'] = float(data['model_confidence'])
                if 'plddt' in data:
                    metrics['plddt_avg'] = float(data['plddt'])
                if 'ptm' in data:
                    metrics['ptm_score'] = float(data['ptm'])
                    
        except Exception as e:
            print(f"Warning: Could not parse JSON file {json_file}: {e}", file=sys.stderr)
    
    return metrics


def parse_proteinmpnn_scores(mpnn_scores_dir):
    """
    Parse ProteinMPNN score files (.npz format).
    
    Returns:
        dict with ProteinMPNN metrics
    """
    metrics = {
        'mpnn_score': None,
        'mpnn_avg_score': None
    }
    
    if not os.path.exists(mpnn_scores_dir):
        return metrics
    
    # ProteinMPNN scores are in NPZ format - we'd need numpy to parse
    # For now, we'll check if files exist and count them
    npz_files = glob.glob(os.path.join(mpnn_scores_dir, '*.npz'))
    if npz_files:
        metrics['mpnn_score_available'] = True
        metrics['mpnn_num_sequences'] = len(npz_files)
    
    return metrics


def extract_design_id_from_path(file_path):
    """
    Extract design ID from file path.
    
    Handles various naming patterns like:
    - design_name_model_0.cif
    - design_name.cif
    - /path/to/design_name_output/...
    """
    basename = os.path.basename(file_path)
    
    # Remove extensions
    name = basename.replace('.cif', '').replace('.pdb', '')
    
    # Remove common suffixes
    name = re.sub(r'_model_\d+$', '', name)
    name = re.sub(r'_output$', '', name)
    name = re.sub(r'_input$', '', name)
    
    return name


def aggregate_metrics_from_directories(
    output_dir,
    ipsae_pattern='*/ipsae_scores/*_10_10.txt',
    prodigy_pattern='*/prodigy/*_prodigy_summary.csv',
    foldseek_pattern='*/foldseek/*_foldseek_summary.tsv',
    boltzgen_pattern='*/predictions',
    mpnn_pattern='*_mpnn_optimized'
):
    """
    Aggregate metrics from a Nextflow output directory structure.
    
    Args:
        output_dir: Path to the Nextflow output directory
        ipsae_pattern: Glob pattern to find IPSAE score files
        prodigy_pattern: Glob pattern to find PRODIGY CSV files
        foldseek_pattern: Glob pattern to find Foldseek TSV files
        boltzgen_pattern: Glob pattern to find Boltzgen predictions
        mpnn_pattern: Glob pattern to find ProteinMPNN outputs
    
    Returns:
        dict mapping design_id -> metrics
    """
    all_metrics = defaultdict(dict)
    
    # Debug: Show what we're working with
    print(f"\n{'='*60}")
    print(f"Consolidating metrics from: {output_dir}")
    print(f"Directory exists: {os.path.exists(output_dir)}")
    if os.path.exists(output_dir):
        print(f"Directory contents:")
        try:
            for item in os.listdir(output_dir):
                item_path = os.path.join(output_dir, item)
                if os.path.isdir(item_path):
                    print(f"  [DIR]  {item}")
                else:
                    print(f"  [FILE] {item}")
        except Exception as e:
            print(f"Error listing directory: {e}")
    print(f"{'='*60}\n")
    
    # Find and parse IPSAE scores
    print(f"Searching for IPSAE scores with pattern: {ipsae_pattern}")
    ipsae_search_path = os.path.join(output_dir, ipsae_pattern)
    print(f"Full search path: {ipsae_search_path}")
    ipsae_files = glob.glob(ipsae_search_path, recursive=True)
    print(f"Found {len(ipsae_files)} IPSAE files")
    if ipsae_files:
        for f in ipsae_files[:5]:  # Show first 5
            print(f"  - {f}")
    
    for ipsae_file in ipsae_files:
        design_id = extract_design_id_from_path(ipsae_file)
        # Get parent directory name as design_id
        parent_dir = Path(ipsae_file).parent.parent.name
        design_id = parent_dir
        
        metrics = parse_ipsae_scores(ipsae_file)
        all_metrics[design_id].update(metrics)
    
    # Find and parse PRODIGY results
    print(f"\nSearching for PRODIGY results with pattern: {prodigy_pattern}")
    prodigy_search_path = os.path.join(output_dir, prodigy_pattern)
    print(f"Full search path: {prodigy_search_path}")
    prodigy_files = glob.glob(prodigy_search_path, recursive=True)
    print(f"Found {len(prodigy_files)} PRODIGY files")
    if prodigy_files:
        for f in prodigy_files[:5]:  # Show first 5
            print(f"  - {f}")
    
    for prodigy_file in prodigy_files:
        # Extract design ID from CSV file name
        basename = os.path.basename(prodigy_file)
        design_id = basename.replace('_prodigy_summary.csv', '')
        
        metrics = parse_prodigy_csv(prodigy_file)
        all_metrics[design_id].update(metrics)
    
    # Find and parse Foldseek results
    print(f"\nSearching for Foldseek results with pattern: {foldseek_pattern}")
    foldseek_search_path = os.path.join(output_dir, foldseek_pattern)
    print(f"Full search path: {foldseek_search_path}")
    foldseek_files = glob.glob(foldseek_search_path, recursive=True)
    print(f"Found {len(foldseek_files)} Foldseek files")
    if foldseek_files:
        for f in foldseek_files[:5]:  # Show first 5
            print(f"  - {f}")
    
    for foldseek_file in foldseek_files:
        # Extract design ID from TSV file name
        basename = os.path.basename(foldseek_file)
        design_id = basename.replace('_foldseek_summary.tsv', '')
        
        metrics = parse_foldseek_summary(foldseek_file)
        all_metrics[design_id].update(metrics)
    
    # Find and parse Boltzgen predictions
    print(f"\nSearching for Boltzgen predictions with pattern: {boltzgen_pattern}")
    boltzgen_search_path = os.path.join(output_dir, boltzgen_pattern)
    print(f"Full search path: {boltzgen_search_path}")
    boltzgen_dirs = glob.glob(boltzgen_search_path, recursive=True)
    print(f"Found {len(boltzgen_dirs)} Boltzgen directories")
    if boltzgen_dirs:
        for d in boltzgen_dirs[:5]:  # Show first 5
            print(f"  - {d}")
    
    for boltzgen_dir in boltzgen_dirs:
        parent_dir = Path(boltzgen_dir).parent.name
        design_id = parent_dir.replace('_output', '')
        
        metrics = parse_boltzgen_predictions(boltzgen_dir)
        all_metrics[design_id].update(metrics)
    
    # Find and parse ProteinMPNN results
    print(f"\nSearching for ProteinMPNN results with pattern: {mpnn_pattern}")
    mpnn_search_path = os.path.join(output_dir, mpnn_pattern)
    print(f"Full search path: {mpnn_search_path}")
    mpnn_dirs = glob.glob(mpnn_search_path, recursive=True)
    print(f"Found {len(mpnn_dirs)} ProteinMPNN directories")
    if mpnn_dirs:
        for d in mpnn_dirs[:5]:  # Show first 5
            print(f"  - {d}")
    
    for mpnn_dir in mpnn_dirs:
        parent_dir = Path(mpnn_dir).parent.name
        design_id = parent_dir
        
        scores_dir = os.path.join(mpnn_dir, 'scores')
        metrics = parse_proteinmpnn_scores(scores_dir)
        all_metrics[design_id].update(metrics)
    
    return dict(all_metrics)


def calculate_composite_score(metrics, weights=None):
    """
    Calculate a composite score for ranking designs.
    
    Args:
        metrics: dict of metrics for a design
        weights: dict of weights for each metric (optional)
    
    Returns:
        float composite score (higher is better)
    """
    if weights is None:
        weights = {
            'ipsae_score': -1.0,  # Lower is better, so negative weight
            'predicted_binding_affinity': -1.0,  # More negative is better
            'buried_surface_area': 0.01,  # Larger is generally better
            'num_interface_contacts': 0.1,  # More contacts is better
            'model_confidence': 1.0,  # Higher is better
            'plddt_avg': 0.1,  # Higher is better
        }
    
    score = 0.0
    count = 0
    
    for metric, weight in weights.items():
        if metric in metrics and metrics[metric] is not None:
            score += weight * metrics[metric]
            count += 1
    
    # Normalize by number of available metrics
    if count > 0:
        score = score / count
    
    return score


def rank_designs(all_metrics, weights=None):
    """
    Rank designs by composite score.
    
    Args:
        all_metrics: dict mapping design_id -> metrics
        weights: optional weights for composite score
    
    Returns:
        list of tuples (design_id, metrics, composite_score) sorted by score
    """
    ranked = []
    
    for design_id, metrics in all_metrics.items():
        composite_score = calculate_composite_score(metrics, weights)
        metrics['composite_score'] = composite_score
        ranked.append((design_id, metrics, composite_score))
    
    # Sort by composite score (descending - higher is better)
    ranked.sort(key=lambda x: x[2], reverse=True)
    
    return ranked


def write_summary_report(ranked_designs, output_file):
    """
    Write a comprehensive summary report to CSV.
    
    Args:
        ranked_designs: list of (design_id, metrics, composite_score) tuples
        output_file: path to output CSV file
    """
    if not ranked_designs:
        print("Warning: No designs to report", file=sys.stderr)
        # Create empty CSV with headers
        with open(output_file, 'w', newline='') as csvfile:
            writer = csv.DictWriter(csvfile, fieldnames=['design_id', 'rank', 'composite_score'])
            writer.writeheader()
        return
    
    # Determine all available metrics
    all_metrics_keys = set()
    for _, metrics, _ in ranked_designs:
        all_metrics_keys.update(metrics.keys())
    
    # Define column order
    priority_columns = [
        'design_id',
        'rank',
        'composite_score',
        'ipsae_score',
        'predicted_binding_affinity',
        'predicted_kd',
        'buried_surface_area',
        'num_interface_contacts',
        'model_confidence',
        'plddt_avg',
        'ptm_score'
    ]
    
    # Add any remaining columns not in priority list
    other_columns = sorted(all_metrics_keys - set(priority_columns))
    fieldnames = priority_columns + other_columns
    
    with open(output_file, 'w', newline='') as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames, extrasaction='ignore')
        writer.writeheader()
        
        for rank, (design_id, metrics, composite_score) in enumerate(ranked_designs, 1):
            row = {'design_id': design_id, 'rank': rank}
            row.update(metrics)
            writer.writerow(row)
    
    print(f"Successfully wrote summary report to {output_file}")


def write_markdown_report(ranked_designs, output_file, top_n=10):
    """
    Write a human-readable Markdown report.
    
    Args:
        ranked_designs: list of (design_id, metrics, composite_score) tuples
        output_file: path to output Markdown file
        top_n: number of top designs to highlight
    """
    with open(output_file, 'w') as f:
        f.write("# Protein Design Consolidation Report\n\n")
        f.write(f"**Total Designs Analyzed:** {len(ranked_designs)}\n\n")
        
        if not ranked_designs:
            f.write("No designs found.\n")
            return
        
        f.write("## Summary Statistics\n\n")
        
        # Calculate summary statistics
        all_ipsae = [m.get('ipsae_score') for _, m, _ in ranked_designs if m.get('ipsae_score') is not None]
        all_affinity = [m.get('predicted_binding_affinity') for _, m, _ in ranked_designs if m.get('predicted_binding_affinity') is not None]
        all_bsa = [m.get('buried_surface_area') for _, m, _ in ranked_designs if m.get('buried_surface_area') is not None]
        
        if all_ipsae:
            f.write(f"- **IPSAE Scores:** {len(all_ipsae)} designs\n")
            f.write(f"  - Min: {min(all_ipsae):.3f}, Max: {max(all_ipsae):.3f}, Mean: {sum(all_ipsae)/len(all_ipsae):.3f}\n")
        
        if all_affinity:
            f.write(f"- **Binding Affinity (ΔG):** {len(all_affinity)} designs\n")
            f.write(f"  - Min: {min(all_affinity):.3f} kcal/mol, Max: {max(all_affinity):.3f} kcal/mol, Mean: {sum(all_affinity)/len(all_affinity):.3f} kcal/mol\n")
        
        if all_bsa:
            f.write(f"- **Buried Surface Area:** {len(all_bsa)} designs\n")
            f.write(f"  - Min: {min(all_bsa):.1f} Ų, Max: {max(all_bsa):.1f} Ų, Mean: {sum(all_bsa)/len(all_bsa):.1f} Ų\n")
        
        f.write(f"\n## Top {top_n} Designs (by Composite Score)\n\n")
        
        # Write table header
        f.write("| Rank | Design ID | Composite Score | IPSAE | ΔG (kcal/mol) | Kd (M) | BSA (Ų) | Contacts |\n")
        f.write("|------|-----------|-----------------|-------|---------------|--------|----------|----------|\n")
        
        # Write top N designs
        for rank, (design_id, metrics, composite_score) in enumerate(ranked_designs[:top_n], 1):
            ipsae = f"{metrics.get('ipsae_score', 'N/A'):.3f}" if metrics.get('ipsae_score') else "N/A"
            affinity = f"{metrics.get('predicted_binding_affinity', 'N/A'):.2f}" if metrics.get('predicted_binding_affinity') else "N/A"
            kd = f"{metrics.get('predicted_kd', 'N/A'):.2e}" if metrics.get('predicted_kd') else "N/A"
            bsa = f"{metrics.get('buried_surface_area', 'N/A'):.1f}" if metrics.get('buried_surface_area') else "N/A"
            contacts = f"{metrics.get('num_interface_contacts', 'N/A')}" if metrics.get('num_interface_contacts') else "N/A"
            
            f.write(f"| {rank} | {design_id} | {composite_score:.3f} | {ipsae} | {affinity} | {kd} | {bsa} | {contacts} |\n")
        
        f.write("\n## Interpretation Guide\n\n")
        f.write("- **Composite Score**: Overall ranking combining all metrics (higher is better)\n")
        f.write("- **IPSAE Score**: Interface PAE score - measures interface quality (lower is better)\n")
        f.write("- **ΔG**: Predicted binding affinity in kcal/mol (more negative is stronger binding)\n")
        f.write("- **Kd**: Predicted dissociation constant in M (lower indicates tighter binding)\n")
        f.write("- **BSA**: Buried surface area in Ų (larger generally indicates more interaction)\n")
        f.write("- **Contacts**: Number of interface contacts (more contacts typically means stronger interaction)\n\n")
        
        f.write("## Recommendations\n\n")
        
        if ranked_designs:
            best_design = ranked_designs[0]
            f.write(f"The **top-ranked design is `{best_design[0]}`** based on composite scoring.\n\n")
            
            # Provide specific recommendations
            best_metrics = best_design[1]
            
            recommendations = []
            
            if best_metrics.get('ipsae_score') and best_metrics['ipsae_score'] < 5.0:
                recommendations.append("✅ Excellent interface quality (IPSAE < 5.0)")
            elif best_metrics.get('ipsae_score') and best_metrics['ipsae_score'] < 10.0:
                recommendations.append("⚠️  Moderate interface quality (IPSAE < 10.0)")
            
            if best_metrics.get('predicted_binding_affinity') and best_metrics['predicted_binding_affinity'] < -10.0:
                recommendations.append("✅ Strong predicted binding affinity (ΔG < -10 kcal/mol)")
            elif best_metrics.get('predicted_binding_affinity') and best_metrics['predicted_binding_affinity'] < -5.0:
                recommendations.append("⚠️  Moderate predicted binding affinity")
            
            if best_metrics.get('buried_surface_area') and best_metrics['buried_surface_area'] > 1000:
                recommendations.append("✅ Large buried surface area (> 1000 Ų)")
            
            if best_metrics.get('num_interface_contacts') and best_metrics['num_interface_contacts'] > 50:
                recommendations.append("✅ Good number of interface contacts (> 50)")
            
            if recommendations:
                f.write("Key features of the top design:\n\n")
                for rec in recommendations:
                    f.write(f"- {rec}\n")
            
            f.write("\n**Next Steps:**\n")
            f.write("1. Review the structure files for the top-ranked designs\n")
            f.write("2. Perform additional validation (MD simulations, experimental testing)\n")
            f.write("3. Consider the top 3-5 designs for experimental characterization\n")
    
    print(f"Successfully wrote Markdown report to {output_file}")


def main():
    parser = argparse.ArgumentParser(
        description='Consolidate protein design metrics and generate ranked report'
    )
    parser.add_argument(
        '--output_dir',
        required=True,
        help='Path to Nextflow output directory containing all results'
    )
    parser.add_argument(
        '--output_csv',
        default='design_metrics_summary.csv',
        help='Output CSV file path'
    )
    parser.add_argument(
        '--output_markdown',
        default='design_metrics_report.md',
        help='Output Markdown report file path'
    )
    parser.add_argument(
        '--top_n',
        type=int,
        default=10,
        help='Number of top designs to highlight in report'
    )
    parser.add_argument(
        '--ipsae_pattern',
        default='*/ipsae_scores/*_10_10.txt',
        help='Glob pattern to find IPSAE score files'
    )
    parser.add_argument(
        '--prodigy_pattern',
        default='*/prodigy/*_prodigy_summary.csv',
        help='Glob pattern to find PRODIGY CSV files'
    )
    
    args = parser.parse_args()
    
    print(f"Consolidating metrics from: {args.output_dir}")
    
    # Aggregate all metrics
    all_metrics = aggregate_metrics_from_directories(
        args.output_dir,
        ipsae_pattern=args.ipsae_pattern,
        prodigy_pattern=args.prodigy_pattern
    )
    
    print(f"Found metrics for {len(all_metrics)} designs")
    
    # Rank designs
    ranked_designs = rank_designs(all_metrics)
    
    # Write reports
    write_summary_report(ranked_designs, args.output_csv)
    write_markdown_report(ranked_designs, args.output_markdown, top_n=args.top_n)
    
    print("\n" + "="*60)
    print("CONSOLIDATION COMPLETE")
    print("="*60)
    print(f"Total designs analyzed: {len(ranked_designs)}")
    if ranked_designs:
        print(f"Top ranked design: {ranked_designs[0][0]} (score: {ranked_designs[0][2]:.3f})")
    print(f"Summary CSV: {args.output_csv}")
    print(f"Markdown report: {args.output_markdown}")


if __name__ == '__main__':
    main()
