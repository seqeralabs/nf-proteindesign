/*
========================================================================================
    PROTEIN_DESIGN: Unified workflow for all protein design modes
========================================================================================
    This workflow consolidates all design modes into a single execution path with
    different entry points based on the mode parameter:
    
    - design: Use pre-made design YAML files
    - target: Generate design variants from target structures
    
    All modes converge on running Boltzgen and optional analysis modules.
----------------------------------------------------------------------------------------
*/
include { GENERATE_DESIGN_VARIANTS } from '../modules/local/generate_design_variants'
include { BOLTZGEN_RUN } from '../modules/local/boltzgen_run'
include { CONVERT_CIF_TO_PDB } from '../modules/local/convert_cif_to_pdb'
include { PROTEINMPNN_OPTIMIZE } from '../modules/local/proteinmpnn_optimize'
include { IPSAE_CALCULATE } from '../modules/local/ipsae_calculate'
include { PRODIGY_PREDICT } from '../modules/local/prodigy_predict'
include { FOLDSEEK_SEARCH } from '../modules/local/foldseek_search'
include { CONSOLIDATE_METRICS } from '../modules/local/consolidate_metrics'

workflow PROTEIN_DESIGN {
    
    take:
    ch_input    // channel: [meta, file] or [meta, file, files] - can be design YAML or target structure depending on mode
    ch_cache    // channel: path to cache directory or EMPTY_CACHE placeholder
    mode        // string: 'design' or 'target'

    main:
    
    // ========================================================================
    // BRANCH 1: DESIGN MODE - Use pre-made design YAML files
    // ========================================================================
    if (mode == 'design') {
        // Input is [meta, design_yaml, structure_files], ready for Boltzgen
        // Reformat to match BOLTZGEN_RUN input: [meta, yaml, structures]
        ch_designs_for_boltzgen = ch_input
    }
    
    // ========================================================================
    // BRANCH 2: TARGET MODE - Generate design variants from target structure
    // ========================================================================
    else if (mode == 'target') {
        // Step 1: Generate diversified design YAML files from target
        // Input is [meta, target_structure]
        GENERATE_DESIGN_VARIANTS(ch_input)
        
        // Step 2: Flatten to get individual design YAMLs and add structure file
        ch_designs_for_boltzgen = GENERATE_DESIGN_VARIANTS.out.design_yamls
            .join(ch_input, by: 0)  // Join with original input to get structure file
            .flatMap { meta, yaml_files, structure_file ->
                // Handle both single file and list of files
                def yaml_list = yaml_files instanceof List ? yaml_files : [yaml_files]
                
                // Create a tuple for each YAML file
                yaml_list.collect { yaml_file ->
                    def design_meta = meta.clone()
                    def design_id = yaml_file.baseName
                    design_meta.id = design_id
                    design_meta.parent_id = meta.id
                    
                    [design_meta, yaml_file, structure_file]
                }
            }
    }
    
    // ========================================================================
    // CONVERGENCE POINT: All modes run Boltzgen on design YAMLs
    // ========================================================================
    
    // Run Boltzgen for each design in parallel
    BOLTZGEN_RUN(ch_designs_for_boltzgen, ch_cache)
    
    // ========================================================================
    // ProteinMPNN: Optimize sequences for designed structures
    // ========================================================================
    if (params.run_proteinmpnn) {
        // Step 1: Convert CIF structures to PDB format (ProteinMPNN requires PDB)
        // Prepare input channel with structures from Boltzgen final_ranked_designs
        ch_structures_for_conversion = BOLTZGEN_RUN.out.results
            .map { meta, results_dir ->
                def final_designs_dir = file("${results_dir}/final_ranked_designs")
                [meta, final_designs_dir]
            }
        
        CONVERT_CIF_TO_PDB(ch_structures_for_conversion)
        
        // Step 2: Run ProteinMPNN on converted PDB structures
        PROTEINMPNN_OPTIMIZE(CONVERT_CIF_TO_PDB.out.pdb_files)
        
        // Use ProteinMPNN optimized structures for downstream analyses
        ch_final_designs_for_analysis = PROTEINMPNN_OPTIMIZE.out.optimized_designs
    } else {
        // Use Boltzgen outputs directly if ProteinMPNN is disabled
        ch_final_designs_for_analysis = BOLTZGEN_RUN.out.results
    }
    
    // ========================================================================
    // OPTIONAL: IPSAE scoring if enabled
    // ========================================================================
    if (params.run_ipsae) {
        // Prepare IPSAE script as a channel
        ch_ipsae_script = Channel.fromPath("${projectDir}/assets/ipsae.py", checkIfExists: true)
        
        // Process intermediate CIF and NPZ files
        // Strategy: Use flatMap to pair CIF and NPZ files with matching basenames
        ch_ipsae_input = BOLTZGEN_RUN.out.intermediate_cifs
            .join(BOLTZGEN_RUN.out.intermediate_npz, by: 0)
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
                        
                        [model_meta, npz_file, cif_file]
                    } else {
                        log.warn "⚠️  No matching NPZ file found for ${cif_file.name} in design ${meta.id}"
                        null
                    }
                }.findAll { it != null }  // Remove null entries where no match was found
            }
        
        // Run IPSAE calculation for each CIF/NPZ pair
        IPSAE_CALCULATE(ch_ipsae_input, ch_ipsae_script)
    }
    
    // ========================================================================
    // OPTIONAL: PRODIGY binding affinity prediction if enabled
    // ========================================================================
    if (params.run_prodigy) {
        // Prepare PRODIGY parser script as a channel
        ch_prodigy_script = Channel.fromPath("${projectDir}/assets/parse_prodigy_output.py", checkIfExists: true)
        
        // Use final CIF files directly from Boltzgen
        // Strategy: Use flatMap to create individual tasks for each CIF file
        ch_prodigy_input = BOLTZGEN_RUN.out.final_cifs
            .flatMap { meta, cif_files ->
                // Convert to list if single file
                def cif_list = cif_files instanceof List ? cif_files : [cif_files]
                
                // Create a separate entry for each CIF file
                cif_list.collect { cif_file ->
                    def base_name = cif_file.baseName
                    def design_meta = [:]
                    design_meta.id = "${meta.id}_${base_name}"
                    design_meta.parent_id = meta.id
                    
                    [design_meta, cif_file]
                }
            }
        
        // Run PRODIGY binding affinity prediction for each CIF file
        PRODIGY_PREDICT(ch_prodigy_input, ch_prodigy_script)
    }
    
    // ========================================================================
    // OPTIONAL: Foldseek structural similarity search if enabled
    // ========================================================================
    if (params.run_foldseek) {
        // Prepare database channel
        if (params.foldseek_database) {
            ch_foldseek_database = Channel.fromPath(params.foldseek_database, checkIfExists: true).first()
        } else {
            log.warn "⚠️  Foldseek is enabled but no database specified. Please set --foldseek_database parameter."
            ch_foldseek_database = Channel.value(file('NO_DATABASE'))
        }
        
        // Use final CIF files directly from Boltzgen
        // Strategy: Use flatMap to create individual tasks for each CIF file
        ch_foldseek_input = BOLTZGEN_RUN.out.final_cifs
            .flatMap { meta, cif_files ->
                // Convert to list if single file
                def cif_list = cif_files instanceof List ? cif_files : [cif_files]
                
                // Create a separate entry for each CIF file
                cif_list.collect { cif_file ->
                    def base_name = cif_file.baseName
                    def design_meta = [:]
                    design_meta.id = "${meta.id}_${base_name}"
                    design_meta.parent_id = meta.id
                    
                    [design_meta, cif_file]
                }
            }
        
        // Run Foldseek structural search for each CIF file
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
    // Common outputs for all modes
    boltzgen_results = BOLTZGEN_RUN.out.results
    final_designs = BOLTZGEN_RUN.out.final_designs
    
    // ProteinMPNN outputs (will be empty if not run)
    mpnn_optimized = params.run_proteinmpnn ? PROTEINMPNN_OPTIMIZE.out.optimized_designs : Channel.empty()
    mpnn_sequences = params.run_proteinmpnn ? PROTEINMPNN_OPTIMIZE.out.sequences : Channel.empty()
    mpnn_scores = params.run_proteinmpnn ? PROTEINMPNN_OPTIMIZE.out.scores : Channel.empty()
    
    // Mode-specific outputs (will be empty for modes that don't generate them)
    design_variants = mode == 'target' ? GENERATE_DESIGN_VARIANTS.out.design_yamls : Channel.empty()
    design_info = mode == 'target' ? GENERATE_DESIGN_VARIANTS.out.info : Channel.empty()
    
    // Optional analysis outputs (will be empty if not run)
    foldseek_results = params.run_foldseek ? FOLDSEEK_SEARCH.out.results : Channel.empty()
    foldseek_summary = params.run_foldseek ? FOLDSEEK_SEARCH.out.summary : Channel.empty()
    
    // Consolidation outputs (will be empty if not run)
    metrics_summary = params.run_consolidation ? CONSOLIDATE_METRICS.out.summary_csv : Channel.empty()
    metrics_report = params.run_consolidation ? CONSOLIDATE_METRICS.out.report_markdown : Channel.empty()
}
