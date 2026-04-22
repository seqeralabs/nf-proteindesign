/*
========================================================================================
    PREPARE_BOLTZ2_SEQUENCES: Prepare sequences for Boltz2 refolding
========================================================================================
    This process:
    1. Splits ProteinMPNN multi-sequence FASTA into individual files
    2. Processes target sequence FASTA to clean format (no header, single line)

    All sequences are included (original Complexa sequence + MPNN-designed sequences).
----------------------------------------------------------------------------------------
*/

process PREPARE_BOLTZ2_SEQUENCES {
    tag "${meta.id}"
    label 'process_low'

    container 'community.wave.seqera.io/library/pip_biopython:79c9733809036fb1'

    input:
    tuple val(meta), path(mpnn_fasta), path(target_fasta)

    output:
    tuple val(meta), path("sequences/*.fa"), emit: sequences
    tuple val(meta), path("${meta.id}_target_sequence.txt"), emit: target_sequence
    path "versions.yml", emit: versions

    script:
    """
    #!/usr/bin/env python3
    import os
    import sys
    from pathlib import Path

    mpnn_file = "${mpnn_fasta}"
    target_file = "${target_fasta}"
    design_id = "${meta.id}"
    output_dir = "sequences"

    def parse_fasta(filepath):
        \"\"\"Parse FASTA file and return list of (header, sequence) tuples.\"\"\"
        sequences = []
        current_seq = []
        current_header = None

        with open(filepath, 'r') as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                if line.startswith('>'):
                    if current_header and current_seq:
                        sequences.append((current_header, ''.join(current_seq)))
                    current_header = line
                    current_seq = []
                else:
                    current_seq.append(line)

            if current_header and current_seq:
                sequences.append((current_header, ''.join(current_seq)))

        return sequences

    # ========================================
    # Process target sequence FASTA
    # ========================================
    print("Processing target sequence FASTA...")
    target_sequences = parse_fasta(target_file)

    if not target_sequences:
        print(f"ERROR: No sequences found in target FASTA: {target_file}", file=sys.stderr)
        sys.exit(1)

    # Use the first sequence (should only be one in target FASTA)
    target_header, target_seq = target_sequences[0]
    print(f"  Header: {target_header}")
    print(f"  Length: {len(target_seq)} AA")

    # Write clean target sequence (no header, no newlines - ready for YAML)
    with open(f"{design_id}_target_sequence.txt", 'w') as f:
        f.write(target_seq)
    print(f"  Saved to: {design_id}_target_sequence.txt")

    # ========================================
    # Split ProteinMPNN sequences
    # ========================================
    print("")
    print("Splitting ProteinMPNN sequences...")
    mpnn_sequences = parse_fasta(mpnn_file)

    print(f"Found {len(mpnn_sequences)} sequences in {mpnn_file}")

    if not mpnn_sequences:
        print(f"ERROR: No sequences found in MPNN FASTA: {mpnn_file}", file=sys.stderr)
        sys.exit(1)

    # Create output directory
    os.makedirs(output_dir, exist_ok=True)

    # Write each sequence to a separate file
    # Use design_id (meta.id) + _s{idx} for naming to match Boltz2 design IDs exactly
    # e.g., meta.id="2vsm_r1" + idx=0 -> "2vsm_r1_s0.fa" (matches Boltz2 output naming)
    for idx, (header, seq) in enumerate(mpnn_sequences):
        output_file = os.path.join(output_dir, f"{design_id}_s{idx}.fa")
        with open(output_file, 'w') as out:
            out.write(f"{header}\\n{seq}\\n")
        seq_type = "original" if idx == 0 else f"MPNN design {idx}"
        print(f"  Created {output_file} ({seq_type}, {len(seq)} AA)")

    # Write versions
    with open("versions.yml", "w") as f:
        f.write('"NFPROTEINDESIGN:PROTEIN_DESIGN:PREPARE_BOLTZ2_SEQUENCES":\\n')
        f.write(f'    python: {sys.version.split()[0]}\\n')

    print("")
    print(f"Split {len(mpnn_sequences)} binder sequences successfully")
    print(f"Target sequence: {len(target_seq)} AA")
    """

    stub:
    """
    mkdir -p sequences
    echo "MOCKSEQUENCE" > ${meta.id}_target_sequence.txt
    # Create stub files with unique names matching the expected pattern
    touch sequences/${meta.id}_s0.fa
    touch versions.yml
    """
}
