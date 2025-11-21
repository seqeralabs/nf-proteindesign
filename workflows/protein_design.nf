/*
========================================================================================
    PROTEIN_DESIGN: Workflow for protein design using YAML specifications
========================================================================================
    This workflow uses pre-made design YAML files for protein design with Boltzgen
    and optional analysis modules.
----------------------------------------------------------------------------------------
*/
include { BOLTZGEN_RUN } from '../modules/local/boltzgen_run'
include { CONVERT_CIF_TO_PDB } from '../modules/local/convert_cif_to_pdb'
include { PROTEINMPNN_OPTIMIZE } from '../modules/local/proteinmpnn_optimize'
include { EXTRACT_TARGET_SEQUENCES } from '../modules/local/extract_target_sequences'
include { PROTENIX_REFOLD } from '../modules/local/protenix_refold'
include { CONVERT_PROTENIX_TO_NPZ } from '../modules/local/convert_protenix_to_npz'
include { IPSAE_CALCULATE } from '../modules/local/ipsae_calculate'
include { PRODIGY_PREDICT } from '../modules/local/prodigy_predict'
include { FOLDSEEK_SEARCH } from '../modules/local/foldseek_search'
include { CONSOLIDATE_METRICS } from '../modules/local/consolidate_metrics'

workflow PROTEIN_DESIGN {
    
    take:
    ch_input    // channel: [meta, design_yaml, structure_files]
    ch_cache    // channel: path to cache directory or EMPTY_CACHE placeholder

    main:
    
    // ========================================================================
    // Run Boltzgen on design YAMLs
    // ========================================================================
    
    // Run Boltzgen for each design in parallel
    BOLTZGEN_RUN(ch_input, ch_cache)
    
    // ========================================================================
    // ProteinMPNN: Optimize sequences for designed structures
    // ========================================================================
    if (params.run_proteinmpnn) {
        // Step 1: Convert CIF structures to PDB format (ProteinMPNN requires PDB)
        // Prepare input channel with structures from Boltzgen budget designs (intermediate_designs_inverse_folded)
        // These are the same structures that IPSAE and PRODIGY analyze
        ch_structures_for_conversion = BOLTZGEN_RUN.out.results
            .map { meta, results_dir ->
                def budget_designs_dir = file("${results_dir}/intermediate_designs_inverse_folded")
                [meta, budget_designs_dir]
            }
        
        CONVERT_CIF_TO_PDB(ch_structures_for_conversion)
        
        // Step 2: Run ProteinMPNN on converted PDB structures
        PROTEINMPNN_OPTIMIZE(CONVERT_CIF_TO_PDB.out.pdb_files)
        
        // Use ProteinMPNN optimized structures for downstream analyses
        ch_final_designs_for_analysis = PROTEINMPNN_OPTIMIZE.out.optimized_designs
        
        // ====================================================================
        // Step 3: Protenix refolding if enabled
        // ====================================================================
        if (params.run_protenix_refold) {
            // Extract target sequences from Boltzgen structures
            ch_boltzgen_structures = BOLTZGEN_RUN.out.final_cifs
            EXTRACT_TARGET_SEQUENCES(ch_boltzgen_structures)
            
            // Combine ProteinMPNN FASTA outputs with target sequence
            // Join based on parent_id (meta.parent_id from MPNN matches meta.id from Boltzgen)
            ch_protenix_input = PROTEINMPNN_OPTIMIZE.out.sequences
                .map { meta, fasta -> 
                    [meta.parent_id, meta, fasta]
                }
                .join(
                    EXTRACT_TARGET_SEQUENCES.out.target_sequences.map { meta, seq -> 
                        [meta.id, seq]
                    }
                )
                .map { parent_id, meta, fasta, target_seq ->
                    [meta, fasta, target_seq]
                }
            
            // Run Protenix structure prediction on combined sequences
            PROTENIX_REFOLD(ch_protenix_input)
            
            // ================================================================
            // Step 4: Convert Protenix confidence JSON to NPZ for ipSAE
            // ================================================================
            // Prepare conversion script as a channel
            ch_conversion_script = Channel.fromPath("${projectDir}/assets/convert_protenix_to_npz.py", checkIfExists: true)
            
            // Pair confidence JSON files with their corresponding CIF structures
            // This runs in parallel with PRODIGY and feeds into IPSAE
            ch_protenix_for_conversion = PROTENIX_REFOLD.out.structures
                .join(PROTENIX_REFOLD.out.confidence, by: 0)
                .flatMap { meta, cif_files, json_files ->
                    // Convert to lists if single files
                    def cif_list = cif_files instanceof List ? cif_files : [cif_files]
                    def json_list = json_files instanceof List ? json_files : [json_files]
                    
                    // Create a map of basenames for matching
                    def json_map = [:]
                    json_list.each { json_file ->
                        // Extract base name (without _confidence suffix if present)
                        def base_name = json_file.baseName.replaceAll(/_confidence.*$/, '')
                        json_map[base_name] = json_file
                    }
                    
                    // Match CIF files with their JSON confidence files
                    cif_list.collect { cif_file ->
                        def base_name = cif_file.baseName
                        def json_file = json_map[base_name]
                        
                        if (json_file) {
                            def conversion_meta = [:]
                            conversion_meta.id = "${meta.id}_${base_name}"
                            conversion_meta.parent_id = meta.parent_id
                            conversion_meta.mpnn_parent_id = meta.id
                            conversion_meta.model_id = base_name
                            
                            [conversion_meta, json_file, cif_file]
                        } else {
                            log.warn "⚠️  No matching confidence JSON found for ${cif_file.name}"
                            null
                        }
                    }.findAll { it != null }
                }
            
            // Run conversion to NPZ format
            CONVERT_PROTENIX_TO_NPZ(ch_protenix_for_conversion, ch_conversion_script)
        }
    } else {
        // Use Boltzgen outputs directly if ProteinMPNN is disabled
        ch_final_designs_for_analysis = BOLTZGEN_RUN.out.results
    }
    
    // ========================================================================
    // OPTIONAL: IPSAE scoring if enabled
    // ========================================================================
    // NOTE: IPSAE requires NPZ confidence files. We now support both:
    //   1. Boltzgen budget designs (native NPZ output)
    //   2. Protenix refolded structures (converted from JSON to NPZ)
    if (params.run_ipsae) {
        // Prepare IPSAE script as a channel
        ch_ipsae_script = Channel.fromPath("${projectDir}/assets/ipsae.py", checkIfExists: true)
        
        // ====================================================================
        // Part 1: Process Boltzgen budget design CIF and NPZ files
        // ====================================================================
        // Process ALL budget design CIF and NPZ files from intermediate_designs_inverse_folded
        // This ensures we run IPSAE on ALL designs before filtering (e.g., if budget=10, run 10 times)
        ch_ipsae_boltzgen = BOLTZGEN_RUN.out.budget_design_cifs
            .join(BOLTZGEN_RUN.out.budget_design_npz, by: 0)
            .flatMap { meta, cif_files, npz_files ->
                // Convert to list if single file
                def cif_list = cif_files instanceof List ? cif_files : [cif_files]
                def npz_list = npz_files instanceof List ? npz_files : [npz_files]
                
                // Create a map of basenames to files for quick lookup
                def npz_map = [:]
                npz_list.each { npz_file ->
                    npz_map[npz_file.baseName] = npz_file
                }
                
                // Match CIF files with corresponding NPZ files
                cif_list.collect { cif_file ->
                    def base_name = cif_file.baseName
                    def npz_file = npz_map[base_name]
                    
                    if (npz_file) {
                        def model_meta = [:]
                        model_meta.id = "${meta.id}_${base_name}"
                        model_meta.parent_id = meta.id
                        model_meta.model_id = "${meta.id}_${base_name}"
                        model_meta.source = "boltzgen"
                        
                        [model_meta, npz_file, cif_file]
                    } else {
                        log.warn "⚠️  No matching NPZ file found for ${cif_file.name} in design ${meta.id}"
                        null
                    }
                }.findAll { it != null }  // Remove null entries where no match was found
            }
        
        // ====================================================================
        // Part 2: Process Protenix refolded structures (if enabled)
        // ====================================================================
        // Add Protenix NPZ files if Protenix refolding is enabled
        if (params.run_proteinmpnn && params.run_protenix_refold) {
            // Get NPZ and CIF pairs from the conversion step
            ch_ipsae_protenix = CONVERT_PROTENIX_TO_NPZ.out.npz_with_cif
                .map { meta, npz_file, cif_file ->
                    // Add source tracking
                    def ipsae_meta = meta.clone()
                    ipsae_meta.source = "protenix"
                    [ipsae_meta, npz_file, cif_file]
                }
            
            // Combine both Boltzgen and Protenix inputs
            ch_ipsae_input = ch_ipsae_boltzgen.mix(ch_ipsae_protenix)
        } else {
            // Only Boltzgen inputs
            ch_ipsae_input = ch_ipsae_boltzgen
        }
        
        // Run IPSAE calculation for all CIF/NPZ pairs (Boltzgen + Protenix)
        IPSAE_CALCULATE(ch_ipsae_input, ch_ipsae_script)
    }
    
    // ========================================================================
    // OPTIONAL: PRODIGY binding affinity prediction if enabled
    // ========================================================================
    if (params.run_prodigy) {
        // Prepare PRODIGY parser script as a channel
        ch_prodigy_script = Channel.fromPath("${projectDir}/assets/parse_prodigy_output.py", checkIfExists: true)
        
        // Use ALL budget design CIF files from intermediate_designs_inverse_folded
        // This ensures we run PRODIGY on ALL designs before filtering (e.g., if budget=10, run 10 times)
        // Strategy: Use flatMap to create individual tasks for each CIF file
        ch_prodigy_input = BOLTZGEN_RUN.out.budget_design_cifs
            .flatMap { meta, cif_files ->
                // Convert to list if single file
                def cif_list = cif_files instanceof List ? cif_files : [cif_files]
                
                // Create a separate entry for each CIF file
                cif_list.collect { cif_file ->
                    def base_name = cif_file.baseName
                    def design_meta = [:]
                    design_meta.id = "${meta.id}_${base_name}"
                    design_meta.parent_id = meta.id
                    design_meta.source = "boltzgen"
                    
                    [design_meta, cif_file]
                }
            }
        
        // Add Protenix-refolded structures if available
        if (params.run_proteinmpnn && params.run_protenix_refold) {
            ch_prodigy_protenix = PROTENIX_REFOLD.out.structures
                .flatMap { meta, cif_files ->
                    // Convert to list if single file
                    def cif_list = cif_files instanceof List ? cif_files : [cif_files]
                    
                    // Create a separate entry for each CIF file
                    cif_list.collect { cif_file ->
                        def base_name = cif_file.baseName
                        def design_meta = [:]
                        design_meta.id = "${meta.id}_${base_name}_protenix"
                        design_meta.parent_id = meta.parent_id  // Maintain link to original Boltzgen design
                        design_meta.mpnn_parent_id = meta.id     // Track which ProteinMPNN design this came from
                        design_meta.source = "protenix"
                        
                        [design_meta, cif_file]
                    }
                }
            
            // Combine both sources
            ch_prodigy_input = ch_prodigy_input.mix(ch_prodigy_protenix)
        }
        
        // Run PRODIGY binding affinity prediction for all CIF files (Boltzgen + Protenix)
        PRODIGY_PREDICT(ch_prodigy_input, ch_prodigy_script)
    }
    
    // ========================================================================
    // OPTIONAL: Foldseek structural similarity search if enabled
    // ========================================================================
    // Search for structural homologs of both Boltzgen and Protenix structures
    // in the AlphaFold database (or other specified database)
    if (params.run_foldseek) {
        // Prepare database channel
        if (params.foldseek_database) {
            ch_foldseek_database = Channel.fromPath(params.foldseek_database, checkIfExists: true).first()
        } else {
            log.warn "⚠️  Foldseek is enabled but no database specified. Please set --foldseek_database parameter."
            ch_foldseek_database = Channel.value(file('NO_DATABASE'))
        }
        
        // ====================================================================
        // Part 1: Process Boltzgen budget design CIF files
        // ====================================================================
        // Use ALL budget design CIF files from intermediate_designs_inverse_folded
        // This searches for homologs of the original Boltzgen-designed structures
        ch_foldseek_boltzgen = BOLTZGEN_RUN.out.budget_design_cifs
            .flatMap { meta, cif_files ->
                // Convert to list if single file
                def cif_list = cif_files instanceof List ? cif_files : [cif_files]
                
                // Create a separate entry for each CIF file
                cif_list.collect { cif_file ->
                    def base_name = cif_file.baseName
                    def design_meta = [:]
                    design_meta.id = "${meta.id}_${base_name}"
                    design_meta.parent_id = meta.id
                    design_meta.source = "boltzgen"
                    
                    [design_meta, cif_file]
                }
            }
        
        // ====================================================================
        // Part 2: Add Protenix refolded structures (if enabled)
        // ====================================================================
        // Search for homologs of the Protenix refolded structures with MPNN sequences
        if (params.run_proteinmpnn && params.run_protenix_refold) {
            ch_foldseek_protenix = PROTENIX_REFOLD.out.structures
                .flatMap { meta, cif_files ->
                    // Convert to list if single file
                    def cif_list = cif_files instanceof List ? cif_files : [cif_files]
                    
                    // Create a separate entry for each CIF file
                    cif_list.collect { cif_file ->
                        def base_name = cif_file.baseName
                        def design_meta = [:]
                        design_meta.id = "${meta.id}_${base_name}_protenix"
                        design_meta.parent_id = meta.parent_id  // Link to original Boltzgen design
                        design_meta.mpnn_parent_id = meta.id     // Track which ProteinMPNN design this came from
                        design_meta.source = "protenix"
                        
                        [design_meta, cif_file]
                    }
                }
            
            // Combine both Boltzgen and Protenix structures
            ch_foldseek_input = ch_foldseek_boltzgen.mix(ch_foldseek_protenix)
        } else {
            // Only Boltzgen structures
            ch_foldseek_input = ch_foldseek_boltzgen
        }
        
        // Run Foldseek structural search for all CIF files (Boltzgen + Protenix)
        // This runs in parallel with IPSAE and PRODIGY analyses
        FOLDSEEK_SEARCH(ch_foldseek_input, ch_foldseek_database)
    }
    
    // ========================================================================
    // CONSOLIDATION: Generate comprehensive metrics report
    // ========================================================================
    if (params.run_consolidation) {
        // Prepare consolidation script as a channel
        ch_consolidate_script = Channel.fromPath("${projectDir}/assets/consolidate_design_metrics.py", checkIfExists: true)
        
        // Create a trigger channel that waits for all analyses to complete
        // Start with Boltzgen results (always runs)
        ch_trigger = BOLTZGEN_RUN.out.results.collect()
        
        // Mix in other outputs based on what's enabled
        if (params.run_proteinmpnn) {
            ch_trigger = ch_trigger
                .concat(PROTEINMPNN_OPTIMIZE.out.optimized_designs.collect())
        }
        
        if (params.run_ipsae) {
            ch_trigger = ch_trigger
                .concat(IPSAE_CALCULATE.out.scores.collect())
        }
        
        if (params.run_prodigy) {
            ch_trigger = ch_trigger
                .concat(PRODIGY_PREDICT.out.summary.collect())
        }
        
        if (params.run_foldseek) {
            ch_trigger = ch_trigger
                .concat(FOLDSEEK_SEARCH.out.summary.collect())
        }
        
        // After all outputs are collected, create a single trigger
        // and map it to the output directory path
        ch_outdir = ch_trigger
            .collect()
            .map { params.outdir }
        
        // Run consolidation after all analyses are complete
        CONSOLIDATE_METRICS(ch_outdir, ch_consolidate_script)
    }

    emit:
    // Boltzgen outputs
    boltzgen_results = BOLTZGEN_RUN.out.results
    final_designs = BOLTZGEN_RUN.out.final_designs
    
    // ProteinMPNN outputs (will be empty if not run)
    mpnn_optimized = params.run_proteinmpnn ? PROTEINMPNN_OPTIMIZE.out.optimized_designs : Channel.empty()
    mpnn_sequences = params.run_proteinmpnn ? PROTEINMPNN_OPTIMIZE.out.sequences : Channel.empty()
    mpnn_scores = params.run_proteinmpnn ? PROTEINMPNN_OPTIMIZE.out.scores : Channel.empty()
    
    // Protenix refolding outputs (will be empty if not run)
    protenix_structures = (params.run_proteinmpnn && params.run_protenix_refold) ? PROTENIX_REFOLD.out.structures : Channel.empty()
    protenix_confidence = (params.run_proteinmpnn && params.run_protenix_refold) ? PROTENIX_REFOLD.out.confidence : Channel.empty()
    
    // Optional analysis outputs (will be empty if not run)
    foldseek_results = params.run_foldseek ? FOLDSEEK_SEARCH.out.results : Channel.empty()
    foldseek_summary = params.run_foldseek ? FOLDSEEK_SEARCH.out.summary : Channel.empty()
    
    // Consolidation outputs (will be empty if not run)
    metrics_summary = params.run_consolidation ? CONSOLIDATE_METRICS.out.summary_csv : Channel.empty()
    metrics_report = params.run_consolidation ? CONSOLIDATE_METRICS.out.report_markdown : Channel.empty()
}
