/*
========================================================================================
    PROTEIN_DESIGN: Workflow for protein design using YAML specifications
========================================================================================
    Backbone design is delegated to a subworkflow selected via params.design_tool:
      'boltzgen'        -> DESIGN_BOLTZGEN  (default)
      'rfdiffusion_v3'  -> DESIGN_RFDIFFUSION -> RFDIFFUSION_V3_RUN

    All downstream steps (ProteinMPNN, Boltz-2, analysis) are tool-agnostic and
    consume the normalised budget_design_cifs channel regardless of which tool ran.
----------------------------------------------------------------------------------------
*/
include { DESIGN_BOLTZGEN    } from '../subworkflows/local/design_boltzgen'
include { DESIGN_RFDIFFUSION } from '../subworkflows/local/design_rfdiffusion'
include { CONVERT_CIF_TO_PDB } from '../modules/local/convert_cif_to_pdb'
include { PROTEINMPNN_OPTIMIZE } from '../modules/local/proteinmpnn_optimize'
include { PREPARE_BOLTZ2_SEQUENCES } from '../modules/local/prepare_boltz2_sequences'
include { BOLTZ2_REFOLD } from '../modules/local/boltz2_refold'
include { IPSAE_CALCULATE } from '../modules/local/ipsae_calculate'
include { PRODIGY_PREDICT } from '../modules/local/prodigy_predict'
include { FOLDSEEK_SEARCH } from '../modules/local/foldseek_search'
include { CONSOLIDATE_METRICS } from '../modules/local/consolidate_metrics'

workflow PROTEIN_DESIGN {

    take:
    ch_input         // channel: [meta, design_yaml, structure_files, target_msa, target_sequence, target_template, boltzgen_output_dir]
    ch_cache         // channel: path to cache directory or EMPTY_CACHE placeholder
    ch_boltz2_cache  // channel: path to Boltz-2 cache directory or EMPTY_BOLTZ2_CACHE placeholder

    main:

    // ========================================================================
    // Backbone design: Boltzgen or RFdiffusion3
    // ========================================================================

    if (params.design_tool == 'boltzgen') {
        // Full input tuple passed — DESIGN_BOLTZGEN handles the pre-computed
        // shortcut (boltzgen_output_dir) internally
        DESIGN_BOLTZGEN(ch_input, ch_cache)
        ch_design_results     = DESIGN_BOLTZGEN.out.results
        ch_budget_design_cifs = DESIGN_BOLTZGEN.out.budget_design_cifs
    } else {
        // RFdiffusion3: strip fields not consumed by the subworkflow
        ch_rfd_input = ch_input
            .map { meta, design_yaml, structure_files, target_msa, target_sequence, target_template, boltzgen_output_dir ->
                [meta, design_yaml, structure_files]
            }
        DESIGN_RFDIFFUSION(ch_rfd_input, ch_cache)
        ch_design_results     = DESIGN_RFDIFFUSION.out.results
        ch_budget_design_cifs = DESIGN_RFDIFFUSION.out.budget_design_cifs
    }
    
    // ========================================================================
    // ProteinMPNN: Optimize sequences for designed structures
    // ========================================================================
    if (params.run_proteinmpnn) {
        // Step 1: Convert CIF structures to PDB format (ProteinMPNN requires PDB)
        // Use budget_design_cifs which contains ONLY the budget designs (e.g., 2 structures if budget=2)
        // NOT all designs from results directory
        // Use the combined channel that includes both newly computed and pre-computed Boltzgen results
        CONVERT_CIF_TO_PDB(ch_budget_design_cifs)
        
        // Step 2: Parallelize ProteinMPNN - run separately for each budget design
        // Use flatMap to create individual tasks per PDB file (one per budget iteration)
        ch_pdb_per_design = CONVERT_CIF_TO_PDB.out.pdb_files_all
            .flatMap { meta, pdb_files ->
                // Convert to list if single file and create defensive copy
                def pdb_list = pdb_files instanceof List ? new ArrayList(pdb_files) : [pdb_files]

                // Create a separate channel entry for each PDB file
                pdb_list.collect { pdb_file ->
                    // Extract rank number from filename (e.g., "rank1_2VSM_protein_design_1" -> "1")
                    def rank_num = pdb_file.baseName.replaceAll(/^rank(\d+)_.*/, '$1')

                    // Simplified naming: {sample}_r{rank}
                    def design_meta = [
                        id: "${meta.id}_r${rank_num}",
                        parent_id: meta.id,
                        rank_num: rank_num,
                        design_name: pdb_file.baseName  // Keep original for reference
                    ]

                    [design_meta, pdb_file]
                }
            }
        
        // Run ProteinMPNN on each design individually (parallel execution per budget design)
        PROTEINMPNN_OPTIMIZE(ch_pdb_per_design)
        
        // Use ProteinMPNN optimized structures for downstream analyses
        ch_final_designs_for_analysis = PROTEINMPNN_OPTIMIZE.out.optimized_designs
        
        // ====================================================================
        // Step 3: Prepare sequences for Boltz-2 refolding
        // ====================================================================
        // 1. Split ProteinMPNN FASTA into individual sequence files
        // 2. Process target sequence FASTA (from samplesheet) to clean format
        // ====================================================================
        if (params.run_boltz2_refold) {
            // Get target sequence FASTA from samplesheet
            ch_target_fasta = ch_input
                .map { meta, design_yaml, structure_files, target_msa, target_sequence, target_template, boltzgen_output_dir ->
                    [meta.id, target_sequence]
                }

            // Combine MPNN FASTA files with target sequence FASTA
            ch_prepare_input = PROTEINMPNN_OPTIMIZE.out.sequences
                .flatMap { meta, fasta_files ->
                    def fasta_list = fasta_files instanceof List ? new ArrayList(fasta_files) : [fasta_files]
                    fasta_list.collect { fasta_file ->
                        [meta, fasta_file]
                    }
                }
                .map { meta, fasta ->
                    [meta.parent_id, meta, fasta]
                }
                .combine(ch_target_fasta, by: 0)
                .map { parent_id, meta, fasta, target_fasta ->
                    [meta, fasta, target_fasta]
                }

            // Run sequence preparation (splits MPNN sequences + processes target FASTA)
            PREPARE_BOLTZ2_SEQUENCES(ch_prepare_input)

            // ================================================================
            // Prepare Target MSA from Samplesheet
            // ================================================================
            // Use actual placeholder files in assets/ for k8s compatibility (avoids staging non-existent files)
            ch_target_msa = ch_input
                .map { meta, design_yaml, structure_files, target_msa, target_sequence, target_template, boltzgen_output_dir ->
                    def msa_file = target_msa ?: file("${projectDir}/assets/NO_MSA", checkIfExists: true)
                    [meta.id, msa_file]
                }

            // ================================================================
            // Prepare Target Template from Samplesheet
            // ================================================================
            ch_target_template = ch_input
                .map { meta, design_yaml, structure_files, target_msa, target_sequence, target_template, boltzgen_output_dir ->
                    def template_file = target_template ?: file("${projectDir}/assets/NO_TEMPLATE", checkIfExists: true)
                    [meta.id, template_file]
                }

            // ================================================================
            // Create channel for Boltz-2 refolding
            // ================================================================
            // Sequence files are now named {meta.id}_s{idx}.fa (e.g., 2vsm_r1_s0.fa)
            // The baseName IS the design ID, so we use it directly
            ch_boltz2_input = PREPARE_BOLTZ2_SEQUENCES.out.sequences
                .flatMap { meta, fasta_files ->
                    def fasta_list = fasta_files instanceof List ? new ArrayList(fasta_files) : [fasta_files]
                    fasta_list.collect { fasta_file ->
                        // Extract seq_num from filename (e.g., 2vsm_r1_s0 -> 0)
                        def seq_num = fasta_file.baseName.replaceAll(/.*_s(\d+)$/, '$1')

                        // The baseName is already the design ID (e.g., 2vsm_r1_s0)
                        def seq_meta = [
                            id: fasta_file.baseName,
                            parent_id: meta.parent_id,
                            rank_num: meta.rank_num,
                            seq_num: seq_num,
                            mpnn_parent_id: meta.id,
                            sequence_name: fasta_file.baseName
                        ]
                        [seq_meta, fasta_file]
                    }
                }
                .map { meta, fasta ->
                    [meta.mpnn_parent_id, meta, fasta]
                }
                .combine(
                    PREPARE_BOLTZ2_SEQUENCES.out.target_sequence.map { meta, seq ->
                        [meta.id, seq]
                    },
                    by: 0
                )
                .map { mpnn_parent_id, meta, fasta, target_seq ->
                    [meta.parent_id, meta, fasta, target_seq]
                }
                .combine(ch_target_msa, by: 0)
                .map { parent_id, meta, fasta, target_seq, target_msa ->
                    [meta.parent_id, meta, fasta, target_seq, target_msa]
                }
                .combine(ch_target_template, by: 0)
                .map { parent_id, meta, fasta, target_seq, target_msa, target_template ->
                    [meta, fasta, target_seq, target_msa, target_template]
                }

            // Run Boltz-2 structure prediction with target MSA
            // NOTE: Boltz-2 will automatically add missing MSA info to binder
            // NOTE: Boltz-2 outputs NPZ files natively - no conversion needed!
            BOLTZ2_REFOLD(ch_boltz2_input, ch_boltz2_cache)
        }
    } else {
        // Use design tool outputs directly if ProteinMPNN is disabled
        ch_final_designs_for_analysis = ch_design_results
    }
    
    // ========================================================================
    // OPTIONAL: IPSAE scoring if enabled
    // ========================================================================
    // NOTE: IPSAE requires NPZ confidence files. We now support both:
    //   1. Boltzgen budget designs (native NPZ output)
    //   2. Boltz-2 refolded structures (native NPZ output - no conversion needed!)
    if (params.run_ipsae) {
        // Prepare IPSAE script as a value channel (reusable across all tasks)
        ch_ipsae_script = Channel.fromPath("${projectDir}/assets/ipsae.py", checkIfExists: true).first()
        
        // ====================================================================
        // Process Boltz-2 refolded structures
        // ====================================================================
        if (params.run_proteinmpnn && params.run_boltz2_refold) {
            // Get CIF and NPZ pairs from Boltz-2 for IPSAE
            // Use combine instead of join for more robust matching in k8s/cloud
            ch_ipsae_input = BOLTZ2_REFOLD.out.structures
                .combine(BOLTZ2_REFOLD.out.pae_npz, by: 0)
                .flatMap { meta, cif_files, npz_files ->
                    // Convert to lists if single files
                    def cif_list = cif_files instanceof List ? cif_files : [cif_files]
                    def npz_list = npz_files instanceof List ? npz_files : [npz_files]

                    // Filter to only model_0 (best model) - use flexible matching
                    def model0_cifs = cif_list.findAll { it.name.contains('model_0') && it.name.endsWith('.cif') }
                    def model0_npzs = npz_list.findAll { it.name.contains('model_0') }

                    // If no model_0 files found, use all files (fallback for different naming)
                    if (model0_cifs.isEmpty()) {
                        model0_cifs = cif_list.findAll { it.name.endsWith('.cif') }
                    }
                    if (model0_npzs.isEmpty()) {
                        model0_npzs = npz_list
                    }

                    // Create a map of NPZ files by normalized base name
                    def npz_map = [:]
                    model0_npzs.each { npz_file ->
                        // Normalize: remove pae_ prefix and _model_X suffix for matching
                        def base_name = npz_file.baseName
                            .replaceAll(/^pae_/, '')
                            .replaceAll(/_model_\d+$/, '')
                        npz_map[base_name] = npz_file
                    }

                    // Match CIF files with their NPZ files
                    model0_cifs.collect { cif_file ->
                        // Normalize CIF name for matching
                        def base_name = cif_file.baseName.replaceAll(/_model_\d+$/, '')
                        def npz_file = npz_map[base_name]

                        // If exact match fails, try first NPZ file as fallback
                        if (!npz_file && model0_npzs.size() == 1 && model0_cifs.size() == 1) {
                            npz_file = model0_npzs[0]
                        }

                        if (npz_file) {
                            def ipsae_meta = [
                                id: meta.id,
                                parent_id: meta.parent_id,
                                rank_num: meta.rank_num,
                                seq_num: meta.seq_num,
                                source: "boltz2"
                            ]
                            [ipsae_meta, npz_file, cif_file]
                        } else {
                            log.warn "⚠️  No matching NPZ file found for ${cif_file.name} (available: ${model0_npzs*.name})"
                            null
                        }
                    }.findAll { it != null }
                }

            // Run IPSAE calculation
            IPSAE_CALCULATE(ch_ipsae_input, ch_ipsae_script)
        } else {
            log.warn "⚠️  IPSAE requested but ProteinMPNN/Boltz2 not enabled. Skipping IPSAE."
        }
    }
    
    // ========================================================================
    // OPTIONAL: PRODIGY binding affinity prediction if enabled
    // ========================================================================
    if (params.run_prodigy) {
        // Prepare PRODIGY parser script as a value channel (reusable across all tasks)
        ch_prodigy_script = Channel.fromPath("${projectDir}/assets/parse_prodigy_output.py", checkIfExists: true).first()
        
        if (params.run_proteinmpnn && params.run_boltz2_refold) {
            // Get CIF structures from Boltz-2 for PRODIGY
            ch_prodigy_input = BOLTZ2_REFOLD.out.structures
                .flatMap { meta, cif_files ->
                    // Convert to list if single file
                    def cif_list = cif_files instanceof List ? new ArrayList(cif_files) : [cif_files]

                    // Filter to only model_0 (best model) - use flexible matching
                    def model0_cifs = cif_list.findAll { it.name.contains('model_0') && it.name.endsWith('.cif') }

                    // If no model_0 files found, use all CIF files (fallback for different naming)
                    if (model0_cifs.isEmpty()) {
                        model0_cifs = cif_list.findAll { it.name.endsWith('.cif') }
                    }

                    // Create a separate entry for each CIF file
                    model0_cifs.collect { cif_file ->
                        def design_meta = [
                            id: meta.id,
                            parent_id: meta.parent_id,
                            rank_num: meta.rank_num,
                            seq_num: meta.seq_num,
                            source: "boltz2"
                        ]
                        [design_meta, cif_file]
                    }
                }

            // Run PRODIGY binding affinity prediction
            PRODIGY_PREDICT(ch_prodigy_input, ch_prodigy_script)
        } else {
            log.warn "⚠️  Prodigy requested but ProteinMPNN/Boltz2 not enabled. Skipping Prodigy."
        }
    }
    
    // ========================================================================
    // OPTIONAL: Foldseek structural similarity search if enabled
    // ========================================================================
    // Search for structural homologs of both Boltzgen and Protenix structures
    // in the AlphaFold database (or other specified database)
    if (params.run_foldseek) {
        // Validate and prepare database channel
        if (!params.foldseek_database) {
            error "ERROR: Foldseek is enabled but no database specified. Please set --foldseek_database parameter."
        }
        
        // Create channel from database directory path
        ch_foldseek_database = Channel.fromPath(params.foldseek_database, type: 'dir', checkIfExists: true).first()

        
        // ====================================================================
        // Process Boltz-2 refolded structures
        // ====================================================================
        if (params.run_proteinmpnn && params.run_boltz2_refold) {
            // Get CIF structures from Boltz-2 for Foldseek
            ch_foldseek_input = BOLTZ2_REFOLD.out.structures
                .flatMap { meta, cif_files ->
                    // Convert to list if single file
                    def cif_list = cif_files instanceof List ? new ArrayList(cif_files) : [cif_files]

                    // Filter to only model_0 (best model) - use flexible matching
                    def model0_cifs = cif_list.findAll { it.name.contains('model_0') && it.name.endsWith('.cif') }

                    // If no model_0 files found, use all CIF files (fallback for different naming)
                    if (model0_cifs.isEmpty()) {
                        model0_cifs = cif_list.findAll { it.name.endsWith('.cif') }
                    }
                    cif_list = model0_cifs

                    // Create a separate entry for each CIF file
                    cif_list.collect { cif_file ->
                        // Use simplified naming from Boltz2 meta directly
                        def design_meta = [
                            id: meta.id,
                            parent_id: meta.parent_id,
                            rank_num: meta.rank_num,
                            seq_num: meta.seq_num,
                            source: "boltz2"
                        ]

                        [design_meta, cif_file]
                    }
                }

            // Run Foldseek structural search
            FOLDSEEK_SEARCH(ch_foldseek_input, ch_foldseek_database)
        } else {
            log.warn "⚠️  Foldseek requested but ProteinMPNN/Boltz2 not enabled. Skipping Foldseek."
        }
    }
    
    // ========================================================================
    // CONSOLIDATION: Generate comprehensive metrics report
    // ========================================================================
    if (params.run_consolidation) {
        // Prepare consolidation script as a value channel (reusable)
        ch_consolidate_script = Channel.fromPath("${projectDir}/assets/consolidate_design_metrics.py", checkIfExists: true).first()

        // Collect output files from each analysis process
        // These will be staged into the consolidation task's work directory
        // Use empty lists [] instead of non-existent placeholder files for k8s compatibility

        // ipSAE scores (the .txt files, not byres)
        ch_ipsae_files = (params.run_ipsae && params.run_proteinmpnn && params.run_boltz2_refold)
            ? IPSAE_CALCULATE.out.scores
                .map { meta, file -> file }
                .collect()
                .ifEmpty { [] }
            : Channel.value([])

        // Prodigy results (.txt files)
        ch_prodigy_files = (params.run_prodigy && params.run_proteinmpnn && params.run_boltz2_refold)
            ? PRODIGY_PREDICT.out.results
                .map { meta, file -> file }
                .collect()
                .ifEmpty { [] }
            : Channel.value([])

        // Foldseek summaries (.tsv files)
        ch_foldseek_files = (params.run_foldseek && params.run_proteinmpnn && params.run_boltz2_refold)
            ? FOLDSEEK_SEARCH.out.summary
                .map { meta, file -> file }
                .collect()
                .ifEmpty { [] }
            : Channel.value([])

        // ====================================================================
        // Collect binder sequences from ProteinMPNN for the report
        // ====================================================================
        // Use sequences from PREPARE_BOLTZ2_SEQUENCES (the actual designed sequences)
        // rather than extracting from structures
        if (params.run_proteinmpnn && params.run_boltz2_refold) {
            ch_sequence_files = PREPARE_BOLTZ2_SEQUENCES.out.sequences
                .flatMap { meta, fasta_files ->
                    def fasta_list = fasta_files instanceof List ? fasta_files : [fasta_files]
                    fasta_list.collect { fasta_file -> fasta_file }
                }
                .collect()
                .ifEmpty { [] }
        } else {
            ch_sequence_files = Channel.value([])
        }

        // Run consolidation with staged files
        CONSOLIDATE_METRICS(
            ch_ipsae_files,
            ch_prodigy_files,
            ch_foldseek_files,
            ch_sequence_files,
            ch_consolidate_script
        )
    }

    emit:
    // Design tool outputs (Boltzgen or RFdiffusion3)
    design_results = ch_design_results
    final_designs  = ch_budget_design_cifs
    
    // ProteinMPNN outputs (will be empty if not run)
    mpnn_optimized = params.run_proteinmpnn ? PROTEINMPNN_OPTIMIZE.out.optimized_designs : Channel.empty()
    mpnn_sequences = params.run_proteinmpnn ? PROTEINMPNN_OPTIMIZE.out.sequences : Channel.empty()
    mpnn_scores = params.run_proteinmpnn ? PROTEINMPNN_OPTIMIZE.out.scores : Channel.empty()
    
    // Boltz-2 refolding outputs (will be empty if not run)
    boltz2_structures = (params.run_proteinmpnn && params.run_boltz2_refold) ? BOLTZ2_REFOLD.out.structures : Channel.empty()
    boltz2_confidence = (params.run_proteinmpnn && params.run_boltz2_refold) ? BOLTZ2_REFOLD.out.confidence : Channel.empty()
    boltz2_pae_npz = (params.run_proteinmpnn && params.run_boltz2_refold) ? BOLTZ2_REFOLD.out.pae_npz : Channel.empty()
    boltz2_affinity = (params.run_proteinmpnn && params.run_boltz2_refold) ? BOLTZ2_REFOLD.out.affinity : Channel.empty()
    
    // Optional analysis outputs (will be empty if not run)
    foldseek_results = (params.run_foldseek && params.run_proteinmpnn && params.run_boltz2_refold) ? FOLDSEEK_SEARCH.out.results : Channel.empty()
    foldseek_summary = (params.run_foldseek && params.run_proteinmpnn && params.run_boltz2_refold) ? FOLDSEEK_SEARCH.out.summary : Channel.empty()

    // Consolidation outputs (will be empty if not run)
    metrics_summary = params.run_consolidation ? CONSOLIDATE_METRICS.out.summary_csv : Channel.empty()
    metrics_report = params.run_consolidation ? CONSOLIDATE_METRICS.out.report_html : Channel.empty()
}
