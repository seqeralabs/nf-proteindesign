#!/usr/bin/env python3
"""
Consolidate protein design metrics from multiple sources and generate a ranked report.

This script aggregates metrics from:
- Boltzgen outputs (structure quality, confidence scores, aggregate & per-target metrics CSVs)
  * aggregate_metrics_analyze.csv - Overall design metrics including pLDDT, pTM, ipTM, etc.
  * per_target_metrics_analyze.csv - Target-specific metrics
  * intermediate_designs_inverse_folded - All budget designs (before filtering)
  * refold_design_cif - Binder structures by themselves
  * refold_cif - Refolded complex structures
- ProteinMPNN (sequence optimization scores from _scores.fa files)
- Protenix (refolding metrics from confidence JSON files - pLDDT, pTM, ipTM)
- IPSAE (interface scores) - runs on ALL budget designs
- PRODIGY (binding affinity predictions) - runs on ALL budget designs
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
import numpy as np


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


def parse_aggregate_metrics_csv(csv_file):
    """
    Parse Boltzgen aggregate_metrics_analyze.csv file.
    
    Returns:
        dict with aggregate metrics
    """
    metrics = {}
    
    if not os.path.exists(csv_file):
        return metrics
    
    try:
        with open(csv_file, 'r') as f:
            reader = csv.DictReader(f)
            # Read first row (assuming single design or aggregate stats)
            for row in reader:
                # Extract any numeric columns
                for key, value in row.items():
                    try:
                        # Try to convert to float
                        metrics[f'aggregate_{key}'] = float(value)
                    except (ValueError, TypeError):
                        # Keep as string if not numeric
                        metrics[f'aggregate_{key}'] = value
                break  # Only first row
    except Exception as e:
        print(f"Warning: Could not parse aggregate metrics CSV {csv_file}: {e}", file=sys.stderr)
    
    return metrics


def parse_per_target_metrics_csv(csv_file):
    """
    Parse Boltzgen per_target_metrics_analyze.csv file.
    
    Returns:
        dict with per-target metrics (averages if multiple targets)
    """
    metrics = {}
    
    if not os.path.exists(csv_file):
        return metrics
    
    try:
        with open(csv_file, 'r') as f:
            reader = csv.DictReader(f)
            rows = list(reader)
            
            if not rows:
                return metrics
            
            # If multiple rows, calculate averages for numeric columns
            numeric_cols = defaultdict(list)
            
            for row in rows:
                for key, value in row.items():
                    try:
                        numeric_cols[key].append(float(value))
                    except (ValueError, TypeError):
                        pass
            
            # Calculate averages
            for key, values in numeric_cols.items():
                if values:
                    metrics[f'per_target_{key}_avg'] = sum(values) / len(values)
                    metrics[f'per_target_{key}_min'] = min(values)
                    metrics[f'per_target_{key}_max'] = max(values)
                    
    except Exception as e:
        print(f"Warning: Could not parse per-target metrics CSV {csv_file}: {e}", file=sys.stderr)
    
    return metrics


def parse_proteinmpnn_scores(mpnn_scores_fa):
    """
    Parse ProteinMPNN score files from FASTA format.
    
    FASTA header format from ProteinMPNN:
    >T=0.1, sample=1, score=2.1234, global_score=2.5678, seq_recovery=0.85
    
    Returns:
        dict with ProteinMPNN metrics (average across sequences)
    """
    metrics = {
        'mpnn_score': None,
        'mpnn_global_score': None,
        'mpnn_seq_recovery': None,
        'mpnn_num_sequences': 0
    }
    
    if not os.path.exists(mpnn_scores_fa):
        return metrics
    
    try:
        scores = []
        global_scores = []
        seq_recoveries = []
        
        with open(mpnn_scores_fa, 'r') as f:
            for line in f:
                if line.startswith('>'):
                    # Parse header
                    # Example: >T=0.1, sample=1, score=2.1234, global_score=2.5678, seq_recovery=0.85
                    parts = line[1:].strip().split(',')
                    for part in parts:
                        if 'score=' in part and 'global_score' not in part:
                            score = float(part.split('=')[1].strip())
                            scores.append(score)
                        elif 'global_score=' in part:
                            global_score = float(part.split('=')[1].strip())
                            global_scores.append(global_score)
                        elif 'seq_recovery=' in part:
                            seq_recovery = float(part.split('=')[1].strip())
                            seq_recoveries.append(seq_recovery)
        
        if scores:
            metrics['mpnn_score'] = sum(scores) / len(scores)
            metrics['mpnn_num_sequences'] = len(scores)
        
        if global_scores:
            metrics['mpnn_global_score'] = sum(global_scores) / len(global_scores)
        
        if seq_recoveries:
            metrics['mpnn_seq_recovery'] = sum(seq_recoveries) / len(seq_recoveries)
            
    except Exception as e:
        print(f"Warning: Could not parse ProteinMPNN scores from {mpnn_scores_fa}: {e}", file=sys.stderr)
    
    return metrics


def parse_protenix_confidence(confidence_json):
    """
    Parse Protenix confidence JSON output.
    
    Extracts pLDDT, pTM, and ipTM scores from the JSON file.
    
    Returns:
        dict with Protenix folding quality metrics
    """
    metrics = {
        'protenix_plddt': None,
        'protenix_ptm': None,
        'protenix_iptm': None,
        'protenix_ranking_score': None
    }
    
    if not os.path.exists(confidence_json):
        return metrics
    
    try:
        with open(confidence_json, 'r') as f:
            data = json.load(f)
        
        # Extract pLDDT (average per-residue confidence)
        if 'plddt' in data:
            plddt_values = data['plddt']
            if isinstance(plddt_values, list):
                metrics['protenix_plddt'] = sum(plddt_values) / len(plddt_values)
            else:
                metrics['protenix_plddt'] = float(plddt_values)
        
        # Extract pTM (predicted TM-score)
        if 'ptm' in data:
            metrics['protenix_ptm'] = float(data['ptm'])
        
        # Extract ipTM (interface predicted TM-score)
        if 'iptm' in data:
            metrics['protenix_iptm'] = float(data['iptm'])
        
        # Extract ranking score (if available)
        if 'ranking_score' in data:
            metrics['protenix_ranking_score'] = float(data['ranking_score'])
        elif 'score' in data:
            metrics['protenix_ranking_score'] = float(data['score'])
            
    except Exception as e:
        print(f"Warning: Could not parse Protenix confidence JSON {confidence_json}: {e}", file=sys.stderr)
    
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
    foldseek_pattern='*/foldseek/*_foldseek_summary.tsv'
):
    """
    Aggregate metrics from a Nextflow output directory structure.
    
    This function collects metrics from multiple sources for each design:
    1. Boltzgen outputs:
       - aggregate_metrics_analyze.csv: Overall quality metrics (pLDDT, pTM, etc.)
       - per_target_metrics_analyze.csv: Target-specific metrics
    2. ProteinMPNN outputs:
       - {design_id}_mpnn_optimized/{model_id}_scores.fa: Sequence optimization scores
    3. Protenix outputs (if available):
       - {design_id}_mpnn_{seq_num}/protenix/{model_id}_confidence.json: Refolding metrics
    4. IPSAE scores:
       - {design_id}/ipsae_scores/{model_id}_*_*.txt: Interface quality scores
    5. PRODIGY predictions:
       - {design_id}/prodigy/{model_id}_prodigy_summary.csv: Binding affinity
    6. Foldseek results:
       - {design_id}/foldseek/{model_id}_foldseek_summary.tsv: Structural similarity
    
    Args:
        output_dir: Path to the Nextflow output directory
        ipsae_pattern: Glob pattern to find IPSAE score files
        prodigy_pattern: Glob pattern to find PRODIGY CSV files
        foldseek_pattern: Glob pattern to find Foldseek TSV files
    
    Returns:
        dict mapping design_id -> metrics
    """
    all_metrics = defaultdict(lambda: defaultdict(dict))
    
    # Debug: Show what we're working with
    print(f"\n{'='*80}")
    print(f"CONSOLIDATING METRICS FROM: {output_dir}")
    print(f"{'='*80}")
    print(f"Directory exists: {os.path.exists(output_dir)}")
    if os.path.exists(output_dir):
        print(f"\nTop-level directory contents:")
        try:
            for item in sorted(os.listdir(output_dir)):
                item_path = os.path.join(output_dir, item)
                if os.path.isdir(item_path):
                    print(f"  [DIR]  {item}")
                else:
                    print(f"  [FILE] {item}")
        except Exception as e:
            print(f"Error listing directory: {e}")
    print(f"{'='*80}\n")
    
    # ============================================================================
    # STEP 1: Collect Boltzgen design information and base metrics
    # ============================================================================
    print(f"\n{'─'*80}")
    print("STEP 1: Collecting Boltzgen design metrics")
    print(f"{'─'*80}")
    
    # Find all Boltzgen output directories (pattern: {design_id}/ with aggregate/per_target CSVs)
    design_dirs = []
    if os.path.exists(output_dir):
        for item in os.listdir(output_dir):
            item_path = os.path.join(output_dir, item)
            if os.path.isdir(item_path) and not item.startswith('.'):
                # Check if this looks like a Boltzgen output directory
                aggregate_csv = os.path.join(item_path, 'aggregate_metrics_analyze.csv')
                if os.path.exists(aggregate_csv):
                    design_dirs.append((item, item_path))
    
    print(f"Found {len(design_dirs)} Boltzgen design directories")
    
    for design_id, design_path in design_dirs:
        print(f"\n  Processing design: {design_id}")
        
        # Parse aggregate metrics CSV (overall design quality)
        aggregate_csv = os.path.join(design_path, 'aggregate_metrics_analyze.csv')
        if os.path.exists(aggregate_csv):
            boltz_metrics = parse_aggregate_metrics_csv(aggregate_csv)
            print(f"    ✓ Aggregate metrics: {len(boltz_metrics)} fields")
            
            # Store these as base Boltzgen metrics
            for key, value in boltz_metrics.items():
                all_metrics[design_id]['boltzgen'][key] = value
        
        # Parse per-target metrics CSV (target-specific metrics)
        per_target_csv = os.path.join(design_path, 'per_target_metrics_analyze.csv')
        if os.path.exists(per_target_csv):
            target_metrics = parse_per_target_metrics_csv(per_target_csv)
            print(f"    ✓ Per-target metrics: {len(target_metrics)} fields")
            
            for key, value in target_metrics.items():
                all_metrics[design_id]['boltzgen'][key] = value
        
        # Find all intermediate design CIF files from intermediate_designs_inverse_folded
        # These are the budget designs that go through IPSAE/PRODIGY/Foldseek
        inverse_folded_dir = os.path.join(design_path, 'intermediate_designs_inverse_folded')
        if os.path.exists(inverse_folded_dir):
            cif_files = glob.glob(os.path.join(inverse_folded_dir, '*.cif'))
            print(f"    ✓ Found {len(cif_files)} budget design structures")
            
            # Store model IDs for this design
            model_ids = []
            for cif_file in cif_files:
                model_id = Path(cif_file).stem
                model_ids.append(model_id)
            
            all_metrics[design_id]['_model_ids'] = model_ids
    
    # ============================================================================
    # STEP 2: Collect ProteinMPNN sequence optimization metrics
    # ============================================================================
    print(f"\n{'─'*80}")
    print("STEP 2: Collecting ProteinMPNN sequence optimization metrics")
    print(f"{'─'*80}")
    
    # Find ProteinMPNN optimized directories (pattern: {design_id}_mpnn_optimized/)
    mpnn_dirs = glob.glob(os.path.join(output_dir, '*_mpnn_optimized'))
    print(f"Found {len(mpnn_dirs)} ProteinMPNN output directories")
    
    for mpnn_dir in mpnn_dirs:
        # Extract design ID (remove _mpnn_optimized suffix)
        mpnn_parent = Path(mpnn_dir).name.replace('_mpnn_optimized', '')
        print(f"\n  Processing MPNN outputs for: {mpnn_parent}")
        
        # Find all _scores.fa files
        scores_files = glob.glob(os.path.join(mpnn_dir, '*_scores.fa'))
        print(f"    Found {len(scores_files)} score files")
        
        for scores_fa in scores_files:
            model_id = Path(scores_fa).stem.replace('_scores', '')
            mpnn_metrics = parse_proteinmpnn_scores(scores_fa)
            
            if mpnn_metrics['mpnn_score'] is not None:
                print(f"    ✓ {model_id}: score={mpnn_metrics['mpnn_score']:.3f}")
            
            # Store under the model ID
            for key, value in mpnn_metrics.items():
                all_metrics[mpnn_parent][model_id][key] = value
    
    # ============================================================================
    # STEP 3: Collect Protenix refolding metrics
    # ============================================================================
    print(f"\n{'─'*80}")
    print("STEP 3: Collecting Protenix refolding metrics")
    print(f"{'─'*80}")
    
    # Find Protenix output directories (pattern: {design_id}_mpnn_{seq_num}/)
    protenix_dirs = glob.glob(os.path.join(output_dir, '*_mpnn_*'))
    # Filter out _mpnn_optimized directories
    protenix_dirs = [d for d in protenix_dirs if not d.endswith('_mpnn_optimized')]
    print(f"Found {len(protenix_dirs)} Protenix output directories")
    
    for protenix_dir in protenix_dirs:
        protenix_name = Path(protenix_dir).name
        # Extract parent design ID (pattern: {design_id}_mpnn_{seq_num})
        match = re.match(r'(.+)_mpnn_\d+$', protenix_name)
        if not match:
            continue
        
        parent_design = match.group(1)
        print(f"\n  Processing Protenix outputs for: {protenix_name}")
        
        # Find confidence JSON files in protenix/ subdirectory
        confidence_dir = os.path.join(protenix_dir, 'protenix')
        if os.path.exists(confidence_dir):
            json_files = glob.glob(os.path.join(confidence_dir, '*_confidence.json'))
            print(f"    Found {len(json_files)} confidence files")
            
            for json_file in json_files:
                model_id = Path(json_file).stem.replace('_confidence', '')
                protenix_metrics = parse_protenix_confidence(json_file)
                
                if protenix_metrics['protenix_plddt'] is not None:
                    print(f"    ✓ {model_id}: pLDDT={protenix_metrics['protenix_plddt']:.2f}")
                
                # Store under the Protenix sequence name
                for key, value in protenix_metrics.items():
                    all_metrics[parent_design][protenix_name + '_' + model_id][key] = value
    
    # ============================================================================
    # STEP 4: Collect IPSAE interface quality scores
    # ============================================================================
    print(f"\n{'─'*80}")
    print("STEP 4: Collecting IPSAE interface quality scores")
    print(f"{'─'*80}")
    
    ipsae_search_path = os.path.join(output_dir, ipsae_pattern)
    ipsae_files = glob.glob(ipsae_search_path, recursive=True)
    print(f"Found {len(ipsae_files)} IPSAE score files")
    
    for ipsae_file in ipsae_files:
        # Extract design ID and model ID from path
        # Pattern: {output_dir}/{design_id}/ipsae_scores/{model_id}_{pae}_{dist}.txt
        path_parts = Path(ipsae_file).parts
        if 'ipsae_scores' in path_parts:
            idx = path_parts.index('ipsae_scores')
            if idx > 0:
                design_id = path_parts[idx - 1]
                model_id = Path(ipsae_file).stem.rsplit('_', 2)[0]  # Remove _10_10 suffix
                
                ipsae_metrics = parse_ipsae_scores(ipsae_file)
                
                if ipsae_metrics['ipsae_score'] is not None:
                    print(f"  ✓ {design_id}/{model_id}: IPSAE={ipsae_metrics['ipsae_score']:.3f}")
                
                # Store under model ID
                for key, value in ipsae_metrics.items():
                    all_metrics[design_id][model_id][key] = value
    
    # ============================================================================
    # STEP 5: Collect PRODIGY binding affinity predictions
    # ============================================================================
    print(f"\n{'─'*80}")
    print("STEP 5: Collecting PRODIGY binding affinity predictions")
    print(f"{'─'*80}")
    
    prodigy_search_path = os.path.join(output_dir, prodigy_pattern)
    prodigy_files = glob.glob(prodigy_search_path, recursive=True)
    print(f"Found {len(prodigy_files)} PRODIGY summary files")
    
    for prodigy_file in prodigy_files:
        # Extract design ID and model ID from path
        # Pattern: {output_dir}/{design_id}/prodigy/{model_id}_prodigy_summary.csv
        path_parts = Path(prodigy_file).parts
        if 'prodigy' in path_parts:
            idx = path_parts.index('prodigy')
            if idx > 0:
                design_id = path_parts[idx - 1]
                model_id = Path(prodigy_file).stem.replace('_prodigy_summary', '')
                
                prodigy_metrics = parse_prodigy_csv(prodigy_file)
                
                if prodigy_metrics['predicted_binding_affinity'] is not None:
                    print(f"  ✓ {design_id}/{model_id}: ΔG={prodigy_metrics['predicted_binding_affinity']:.2f} kcal/mol")
                
                # Store under model ID
                for key, value in prodigy_metrics.items():
                    all_metrics[design_id][model_id][key] = value
    
    # ============================================================================
    # STEP 6: Collect Foldseek structural similarity results
    # ============================================================================
    print(f"\n{'─'*80}")
    print("STEP 6: Collecting Foldseek structural similarity results")
    print(f"{'─'*80}")
    
    foldseek_search_path = os.path.join(output_dir, foldseek_pattern)
    foldseek_files = glob.glob(foldseek_search_path, recursive=True)
    print(f"Found {len(foldseek_files)} Foldseek summary files")
    
    for foldseek_file in foldseek_files:
        # Extract design ID and model ID from path
        # Pattern: {output_dir}/{design_id}/foldseek/{model_id}_foldseek_summary.tsv
        path_parts = Path(foldseek_file).parts
        if 'foldseek' in path_parts:
            idx = path_parts.index('foldseek')
            if idx > 0:
                design_id = path_parts[idx - 1]
                model_id = Path(foldseek_file).stem.replace('_foldseek_summary', '')
                
                foldseek_metrics = parse_foldseek_summary(foldseek_file)
                
                if foldseek_metrics['foldseek_top_hit'] is not None:
                    print(f"  ✓ {design_id}/{model_id}: {foldseek_metrics['foldseek_num_hits']} hits (top: {foldseek_metrics['foldseek_top_hit']})")
                
                # Store under model ID
                for key, value in foldseek_metrics.items():
                    all_metrics[design_id][model_id][key] = value
    
    # ============================================================================
    # STEP 7: Flatten the nested structure for easier ranking
    # ============================================================================
    print(f"\n{'─'*80}")
    print("STEP 7: Flattening metrics for ranking")
    print(f"{'─'*80}")
    
    flattened_metrics = {}
    
    for design_id, design_data in all_metrics.items():
        # Get Boltzgen base metrics
        boltzgen_metrics = design_data.get('boltzgen', {})
        model_ids = design_data.get('_model_ids', [])
        
        print(f"\n  Design: {design_id}")
        print(f"    Boltzgen metrics: {len(boltzgen_metrics)} fields")
        
        # For each model/structure, create a flattened entry
        models_found = set()
        for key, value in design_data.items():
            if key in ['boltzgen', '_model_ids']:
                continue
            
            # This is a model ID with its metrics
            if isinstance(value, dict):
                full_id = f"{design_id}_{key}"
                flattened_metrics[full_id] = {}
                
                # Add Boltzgen base metrics
                flattened_metrics[full_id].update(boltzgen_metrics)
                
                # Add model-specific metrics
                flattened_metrics[full_id].update(value)
                
                # Add identifiers
                flattened_metrics[full_id]['design_id'] = design_id
                flattened_metrics[full_id]['model_id'] = key
                
                models_found.add(key)
        
        print(f"    Models with metrics: {len(models_found)}")
    
    print(f"\nTotal flattened entries: {len(flattened_metrics)}")
    
    return flattened_metrics


def calculate_composite_score(metrics, weights=None):
    """
    Calculate a composite score for ranking designs.
    
    This score combines multiple quality metrics with appropriate weights:
    - Structure quality: Boltzgen pLDDT, pTM, ipTM
    - Interface quality: IPSAE score (lower is better)
    - Binding affinity: PRODIGY ΔG and interface properties
    - Sequence optimization: ProteinMPNN scores
    - Refolding quality: Protenix pLDDT, pTM, ipTM
    
    Args:
        metrics: dict of metrics for a design
        weights: dict of weights for each metric (optional)
    
    Returns:
        float composite score (higher is better)
    """
    if weights is None:
        weights = {
            # Boltzgen structure quality (from aggregate_metrics)
            'aggregate_plddt': 0.15,  # Higher is better (0-100 scale)
            'aggregate_ptm': 1.0,  # Higher is better (0-1 scale)
            'aggregate_iptm': 1.0,  # Higher is better (0-1 scale) - interface quality
            
            # Interface quality
            'ipsae_score': -2.0,  # Lower is better, so negative weight (typically 0-20)
            
            # Binding affinity and interface properties
            'predicted_binding_affinity': -0.5,  # More negative is better (kcal/mol)
            'buried_surface_area': 0.001,  # Larger is generally better (Ų)
            'num_interface_contacts': 0.05,  # More contacts is better
            
            # ProteinMPNN sequence optimization
            'mpnn_score': -0.5,  # Lower is better (negative log probability)
            'mpnn_seq_recovery': 0.5,  # Higher is better (0-1 scale)
            
            # Protenix refolding quality (validates MPNN sequences)
            'protenix_plddt': 0.01,  # Higher is better (0-100 scale)
            'protenix_ptm': 0.5,  # Higher is better (0-1 scale)
            'protenix_iptm': 0.5,  # Higher is better (0-1 scale)
        }
    
    score = 0.0
    count = 0
    component_scores = {}
    
    for metric, weight in weights.items():
        if metric in metrics and metrics[metric] is not None:
            try:
                metric_value = float(metrics[metric])
                component_contribution = weight * metric_value
                score += component_contribution
                count += 1
                component_scores[metric] = component_contribution
            except (ValueError, TypeError):
                continue
    
    # Normalize by number of available metrics
    if count > 0:
        score = score / count
    
    # Store component breakdown for debugging
    metrics['_score_components'] = component_scores
    metrics['_metrics_used'] = count
    
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
    
    # Define column order - prioritize most important metrics
    priority_columns = [
        'design_id',
        'model_id',
        'rank',
        'composite_score',
        '_metrics_used',
        
        # Boltzgen original design quality
        'aggregate_plddt',
        'aggregate_ptm',
        'aggregate_iptm',
        'aggregate_pae_interaction',
        
        # ProteinMPNN sequence optimization
        'mpnn_score',
        'mpnn_global_score',
        'mpnn_seq_recovery',
        'mpnn_num_sequences',
        
        # Protenix refolding (if MPNN was run)
        'protenix_plddt',
        'protenix_ptm',
        'protenix_iptm',
        'protenix_ranking_score',
        
        # Interface quality
        'ipsae_score',
        
        # Binding affinity
        'predicted_binding_affinity',
        'predicted_kd',
        'buried_surface_area',
        'num_interface_contacts',
        
        # Structural similarity
        'foldseek_top_hit',
        'foldseek_top_evalue',
        'foldseek_top_bits',
        'foldseek_num_hits',
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
        
        # Write table header with all key metrics
        f.write("| Rank | Design | Model | Score | Boltz pLDDT | Boltz ipTM | IPSAE | ΔG | MPNN Score | Protenix pLDDT |\n")
        f.write("|------|--------|-------|-------|-------------|------------|-------|----|-----------|-----------------|\n")
        
        # Write top N designs
        for rank, (full_id, metrics, composite_score) in enumerate(ranked_designs[:top_n], 1):
            design_id = metrics.get('design_id', full_id)
            model_id = metrics.get('model_id', '-')
            
            # Format metrics with proper handling of None values
            boltz_plddt = f"{metrics.get('aggregate_plddt', 0):.1f}" if metrics.get('aggregate_plddt') else "N/A"
            boltz_iptm = f"{metrics.get('aggregate_iptm', 0):.3f}" if metrics.get('aggregate_iptm') else "N/A"
            ipsae = f"{metrics.get('ipsae_score', 0):.2f}" if metrics.get('ipsae_score') else "N/A"
            affinity = f"{metrics.get('predicted_binding_affinity', 0):.1f}" if metrics.get('predicted_binding_affinity') else "N/A"
            mpnn = f"{metrics.get('mpnn_score', 0):.2f}" if metrics.get('mpnn_score') else "N/A"
            protenix_plddt = f"{metrics.get('protenix_plddt', 0):.1f}" if metrics.get('protenix_plddt') else "N/A"
            
            # Truncate long IDs for table readability
            display_design = design_id[:20] + "..." if len(design_id) > 23 else design_id
            display_model = model_id[:15] + "..." if len(model_id) > 18 else model_id
            
            f.write(f"| {rank} | {display_design} | {display_model} | {composite_score:.3f} | "
                   f"{boltz_plddt} | {boltz_iptm} | {ipsae} | {affinity} | {mpnn} | {protenix_plddt} |\n")
        
        f.write("\n## Interpretation Guide\n\n")
        f.write("### Overall Quality\n")
        f.write("- **Composite Score**: Weighted combination of all metrics (higher is better)\n")
        f.write("- **Metrics Used**: Number of metrics available for this design (more is better)\n\n")
        
        f.write("### Boltzgen Original Design Quality\n")
        f.write("- **Boltz pLDDT**: Per-residue confidence score, 0-100 (>80 is good, >90 is excellent)\n")
        f.write("- **Boltz pTM**: Predicted TM-score, 0-1 (>0.5 is good, >0.8 is excellent)\n")
        f.write("- **Boltz ipTM**: Interface predicted TM-score, 0-1 (>0.5 is good, >0.8 is excellent)\n")
        f.write("- **Boltz PAE Interaction**: Predicted aligned error at interface (lower is better)\n\n")
        
        f.write("### ProteinMPNN Sequence Optimization\n")
        f.write("- **MPNN Score**: Negative log probability of sequence (lower is better, typically 1-5)\n")
        f.write("- **MPNN Global Score**: Overall sequence likelihood (lower is better)\n")
        f.write("- **MPNN Seq Recovery**: Fraction of original residues kept, 0-1 (indicates design novelty)\n\n")
        
        f.write("### Protenix Refolding Validation\n")
        f.write("- **Protenix pLDDT**: Confidence after refolding with MPNN sequence, 0-100\n")
        f.write("- **Protenix pTM**: Predicted TM-score after refolding, 0-1\n")
        f.write("- **Protenix ipTM**: Interface quality after refolding, 0-1\n")
        f.write("- Good Protenix scores validate that MPNN sequences fold correctly\n\n")
        
        f.write("### Interface Quality\n")
        f.write("- **IPSAE**: Interface PAE score (lower is better, <5 excellent, <10 good)\n")
        f.write("- Measures confidence in interface residue positioning\n\n")
        
        f.write("### Binding Affinity (PRODIGY)\n")
        f.write("- **ΔG**: Predicted binding free energy in kcal/mol (more negative is stronger)\n")
        f.write("- **Kd**: Predicted dissociation constant in M (lower indicates tighter binding)\n")
        f.write("- **BSA**: Buried surface area in Ų (larger generally indicates more interaction)\n")
        f.write("- **Contacts**: Number of interface residue contacts\n\n")
        
        f.write("### Structural Similarity (Foldseek)\n")
        f.write("- **Top Hit**: Most similar structure in database\n")
        f.write("- **E-value**: Statistical significance (lower is more significant)\n")
        f.write("- **Bits**: Alignment score (higher is better)\n\n")
        
        f.write("## Recommendations\n\n")
        
        if ranked_designs:
            best_design = ranked_designs[0]
            best_id = best_design[0]
            best_metrics = best_design[1]
            
            f.write(f"### Top Design: `{best_id}`\n\n")
            f.write(f"**Composite Score:** {best_design[2]:.3f} (based on {best_metrics.get('_metrics_used', 0)} metrics)\n\n")
            
            # Provide detailed analysis of the top design
            f.write("**Quality Assessment:**\n\n")
            
            recommendations = []
            warnings = []
            
            # Boltzgen structure quality
            if best_metrics.get('aggregate_plddt'):
                plddt = best_metrics['aggregate_plddt']
                if plddt > 90:
                    recommendations.append(f"✅ Excellent Boltzgen pLDDT: {plddt:.1f}")
                elif plddt > 80:
                    recommendations.append(f"✅ Good Boltzgen pLDDT: {plddt:.1f}")
                else:
                    warnings.append(f"⚠️  Moderate Boltzgen pLDDT: {plddt:.1f}")
            
            if best_metrics.get('aggregate_iptm'):
                iptm = best_metrics['aggregate_iptm']
                if iptm > 0.8:
                    recommendations.append(f"✅ Excellent Boltzgen interface quality (ipTM: {iptm:.3f})")
                elif iptm > 0.5:
                    recommendations.append(f"✅ Good Boltzgen interface quality (ipTM: {iptm:.3f})")
                else:
                    warnings.append(f"⚠️  Moderate Boltzgen interface quality (ipTM: {iptm:.3f})")
            
            # IPSAE interface quality
            if best_metrics.get('ipsae_score'):
                ipsae = best_metrics['ipsae_score']
                if ipsae < 5.0:
                    recommendations.append(f"✅ Excellent interface confidence (IPSAE: {ipsae:.2f})")
                elif ipsae < 10.0:
                    recommendations.append(f"✅ Good interface confidence (IPSAE: {ipsae:.2f})")
                else:
                    warnings.append(f"⚠️  Moderate interface confidence (IPSAE: {ipsae:.2f})")
            
            # ProteinMPNN optimization
            if best_metrics.get('mpnn_score'):
                mpnn = best_metrics['mpnn_score']
                if mpnn < 2.0:
                    recommendations.append(f"✅ Excellent MPNN sequence optimization (score: {mpnn:.2f})")
                elif mpnn < 4.0:
                    recommendations.append(f"✅ Good MPNN sequence optimization (score: {mpnn:.2f})")
                else:
                    warnings.append(f"⚠️  Moderate MPNN sequence optimization (score: {mpnn:.2f})")
            
            if best_metrics.get('mpnn_seq_recovery'):
                recovery = best_metrics['mpnn_seq_recovery']
                if recovery < 0.3:
                    recommendations.append(f"✅ Highly novel sequence (recovery: {recovery:.2f})")
                elif recovery < 0.7:
                    recommendations.append(f"✅ Moderately novel sequence (recovery: {recovery:.2f})")
                else:
                    recommendations.append(f"ℹ️  Conservative sequence design (recovery: {recovery:.2f})")
            
            # Protenix refolding validation
            if best_metrics.get('protenix_plddt'):
                protenix_plddt = best_metrics['protenix_plddt']
                if protenix_plddt > 85:
                    recommendations.append(f"✅ MPNN sequence folds well (Protenix pLDDT: {protenix_plddt:.1f})")
                elif protenix_plddt > 70:
                    recommendations.append(f"✅ MPNN sequence folds adequately (Protenix pLDDT: {protenix_plddt:.1f})")
                else:
                    warnings.append(f"⚠️  MPNN sequence may not fold well (Protenix pLDDT: {protenix_plddt:.1f})")
            
            # Binding affinity
            if best_metrics.get('predicted_binding_affinity'):
                affinity = best_metrics['predicted_binding_affinity']
                if affinity < -10.0:
                    recommendations.append(f"✅ Strong predicted binding (ΔG: {affinity:.1f} kcal/mol)")
                elif affinity < -5.0:
                    recommendations.append(f"✅ Moderate predicted binding (ΔG: {affinity:.1f} kcal/mol)")
                else:
                    warnings.append(f"⚠️  Weak predicted binding (ΔG: {affinity:.1f} kcal/mol)")
            
            if best_metrics.get('buried_surface_area'):
                bsa = best_metrics['buried_surface_area']
                if bsa > 1500:
                    recommendations.append(f"✅ Large interface (BSA: {bsa:.0f} Ų)")
                elif bsa > 800:
                    recommendations.append(f"✅ Adequate interface (BSA: {bsa:.0f} Ų)")
                else:
                    warnings.append(f"⚠️  Small interface (BSA: {bsa:.0f} Ų)")
            
            # Print recommendations and warnings
            if recommendations:
                f.write("**Strengths:**\n")
                for rec in recommendations:
                    f.write(f"- {rec}\n")
                f.write("\n")
            
            if warnings:
                f.write("**Considerations:**\n")
                for warn in warnings:
                    f.write(f"- {warn}\n")
                f.write("\n")
            
            f.write("### Next Steps\n\n")
            f.write("1. **Structural Review**: Examine PDB/CIF structures for the top 3-5 designs\n")
            f.write("2. **Sequence Analysis**: Review ProteinMPNN optimized sequences and compare to originals\n")
            f.write("3. **Validation**: Consider additional computational validation (MD simulations, docking)\n")
            f.write("4. **Experimental Testing**: Prioritize top designs for experimental characterization\n")
            f.write("5. **Detailed Comparison**: Use the full CSV for in-depth comparison of all designs\n")
    
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
