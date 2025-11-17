/*
========================================================================================
    PROTEIN_DESIGN: Unified workflow for all protein design modes
========================================================================================
    This workflow consolidates all design modes into a single execution path with
    different entry points based on the mode parameter:
    
    - design: Use pre-made design YAML files
    - target: Generate design variants from target structures
    - p2rank: Use P2Rank to identify binding sites, then design binders
    
    All modes converge on running Boltzgen and optional IPSAE scoring.
----------------------------------------------------------------------------------------
*/

include { P2RANK_PREDICT } from '../modules/local/p2rank_predict'
include { FORMAT_BINDING_SITES } from '../modules/local/format_binding_sites'
include { GENERATE_DESIGN_VARIANTS } from '../modules/local/generate_design_variants'
include { BOLTZGEN_RUN } from '../modules/local/boltzgen_run'
include { PROTEINMPNN_OPTIMIZE } from '../modules/local/proteinmpnn_optimize'
include { IPSAE_CALCULATE } from '../modules/local/ipsae_calculate'
include { PRODIGY_PREDICT } from '../modules/local/prodigy_predict'
include { CONSOLIDATE_METRICS } from '../modules/local/consolidate_metrics'

workflow PROTEIN_DESIGN {
    
    take:
    ch_input    // channel: [meta, file] or [meta, file, files] - can be design YAML or target structure depending on mode
    ch_cache    // channel: path to cache directory or EMPTY_CACHE placeholder
    mode        // string: 'design', 'target', or 'p2rank'

    main:
    
    // ========================================================================
    // BRANCH 1: DESIGN MODE - Use pre-made design YAML files
    // ========================================================================
    if (mode == 'design') {
        log.info """
        ========================================
        Running in DESIGN-BASED MODE
        ========================================
        Using pre-made design YAML files
        from samplesheet.
        ========================================
        """.stripIndent()
        
        // Input is [meta, design_yaml, structure_files], ready for Boltzgen
        // Reformat to match BOLTZGEN_RUN input: [meta, yaml, structures]
        ch_designs_for_boltzgen = ch_input
    }
    
    // ========================================================================
    // BRANCH 2: TARGET MODE - Generate design variants from target structure
    // ========================================================================
    else if (mode == 'target') {
        log.info """
        ========================================
        Running in TARGET-BASED MODE
        ========================================
        Input targets will be used to generate
        diversified design specifications, then
        all designs will run in parallel.
        ========================================
        """.stripIndent()
        
        // Step 1: Generate diversified design YAML files from target
        // Input is [meta, target_structure]
        GENERATE_DESIGN_VARIANTS(ch_input)
        
        // Step 2: Flatten to get individual design YAMLs and add structure file
        ch_designs_for_boltzgen = GENERATE_DESIGN_VARIANTS.out.design_yamls
            .join(ch_input, by: 0)  // Join with original input to get structure file
            .transpose(by: 1)  // Flatten list of YAML files (index 1)
            .map { meta, yaml_file, structure_file ->
                // Create new meta for each design
                def design_meta = meta.clone()
                def design_id = yaml_file.baseName
                design_meta.id = design_id
                design_meta.parent_id = meta.id
                
                [design_meta, yaml_file, structure_file]
            }
    }
    
    // ========================================================================
    // BRANCH 3: P2RANK MODE - Predict binding sites then design binders
    // ========================================================================
    else if (mode == 'p2rank') {
        log.info """
        ========================================
        Running in P2RANK MODE
        ========================================
        P2Rank will identify binding sites in
        target structures, then Boltzgen will
        design binding partners for those sites.
        ========================================
        """.stripIndent()
        
        // Step 1: Run P2Rank to identify binding sites
        // Input is [meta, target_structure]
        P2RANK_PREDICT(ch_input)
        
        // Step 2: Combine P2Rank outputs for formatting
        ch_p2rank_results = P2RANK_PREDICT.out.predictions
            .join(P2RANK_PREDICT.out.residues, by: [0, 1])
            .map { meta, structure, predictions_csv, residues_csv ->
                [meta, structure, predictions_csv, residues_csv]
            }
        
        // Step 3: Format P2Rank predictions into Boltz2 YAML files
        FORMAT_BINDING_SITES(ch_p2rank_results)
        
        // Step 4: Flatten to get individual design YAMLs and keep structure file
        ch_designs_for_boltzgen = ch_p2rank_results
            .join(FORMAT_BINDING_SITES.out.design_yamls, by: 0)
            .transpose(by: 4)  // Transpose the YAML files list (index 4)
            .map { meta, structure, predictions_csv, residues_csv, yaml_file ->
                // Create new meta for each design
                def design_meta = meta.clone()
                // Extract design_id from filename
                def design_id = yaml_file.baseName
                design_meta.id = design_id
                design_meta.parent_id = meta.id  // Keep reference to original target
                
                // Return meta, yaml file, and structure file
                [design_meta, yaml_file, structure]
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
        log.info """
        ========================================
        Running ProteinMPNN optimization
        ========================================
        Optimizing sequences for Boltzgen
        designed structures using ProteinMPNN
        with parameters optimized for minibinders.
        ========================================
        """.stripIndent()
        
        PROTEINMPNN_OPTIMIZE(BOLTZGEN_RUN.out.results)
        
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
        
        // Create channel with PAE and CIF files
        // Use Boltzgen output since PAE files are only generated by Boltzgen
        ch_ipsae_input = BOLTZGEN_RUN.out.results
            .flatMap { meta, results_dir ->
                // Find all model CIF files and corresponding PAE files
                def cif_files = file("${results_dir}/predictions/**/*_model_*.cif")
                def pairs = []
                
                cif_files.each { cif ->
                    def cif_name = cif.getName()
                    def matcher = cif_name =~ /(.+)_model_(\\d+)\\.cif$/
                    
                    if (matcher.matches()) {
                        def input_name = matcher[0][1]
                        def model_num = matcher[0][2]
                        
                        def pae_file = file("${results_dir}/predictions/${input_name}/pae_${input_name}_model_${model_num}.npz")
                        
                        if (pae_file.exists()) {
                            def model_meta = meta.clone()
                            model_meta.model_id = "${meta.id}_model_${model_num}"
                            pairs.add([model_meta, pae_file, cif])
                        }
                    }
                }
                return pairs
            }
        
        // Run IPSAE calculation
        IPSAE_CALCULATE(ch_ipsae_input, ch_ipsae_script)
    }
    
    // ========================================================================
    // OPTIONAL: PRODIGY binding affinity prediction if enabled
    // ========================================================================
    if (params.run_prodigy) {
        // Prepare PRODIGY parser script as a channel
        ch_prodigy_script = Channel.fromPath("${projectDir}/assets/parse_prodigy_output.py", checkIfExists: true)
        
        // Create channel with structures
        // If ProteinMPNN was run, use those structures; otherwise use Boltzgen final designs
        if (params.run_proteinmpnn) {
            ch_prodigy_input = PROTEINMPNN_OPTIMIZE.out.optimized_designs
                .flatMap { meta, mpnn_dir ->
                    // Find all structure files in ProteinMPNN structures directory
                    def structure_files = file("${mpnn_dir}/structures/*")
                    def structures = []
                    
                    structure_files.each { structure ->
                        if (structure.getName().endsWith('.cif') || structure.getName().endsWith('.pdb')) {
                            def structure_name = structure.getName()
                            def design_meta = meta.clone()
                            design_meta.id = structure_name.replaceAll(/\\.(cif|pdb)$/, '').replaceAll(/_input$/, '')
                            design_meta.parent_id = meta.id
                            
                            structures.add([design_meta, structure])
                        }
                    }
                    return structures
                }
        } else {
            ch_prodigy_input = BOLTZGEN_RUN.out.final_designs
                .flatMap { meta, designs_dir ->
                    // Find all CIF files in final_ranked_designs directory
                    def cif_files = file("${designs_dir}/*.cif")
                    def structures = []
                    
                    cif_files.each { cif ->
                        def cif_name = cif.getName()
                        // Extract design ID from filename
                        def design_meta = meta.clone()
                        design_meta.id = cif_name.replaceAll(/\\.cif$/, '')
                        design_meta.parent_id = meta.id
                        
                        structures.add([design_meta, cif])
                    }
                    return structures
                }
        }
        
        // Run PRODIGY binding affinity prediction
        PRODIGY_PREDICT(ch_prodigy_input, ch_prodigy_script)
    }
    
    // ========================================================================
    // CONSOLIDATION: Generate comprehensive metrics report
    // ========================================================================
    if (params.run_consolidation) {
        log.info """
        ========================================
        Generating Consolidated Metrics Report
        ========================================
        Aggregating all design metrics and
        generating ranked summary report.
        ========================================
        """.stripIndent()
        
        // Prepare consolidation script as a channel
        ch_consolidate_script = Channel.fromPath("${projectDir}/assets/consolidate_design_metrics.py", checkIfExists: true)
        
        // Collect output directory path
        // We'll pass the outdir parameter to the consolidation process
        ch_outdir = Channel.fromPath(params.outdir, type: 'dir')
        
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
    p2rank_predictions = mode == 'p2rank' ? P2RANK_PREDICT.out.predictions : Channel.empty()
    p2rank_residues = mode == 'p2rank' ? P2RANK_PREDICT.out.residues : Channel.empty()
    design_yamls = mode == 'p2rank' ? FORMAT_BINDING_SITES.out.design_yamls : Channel.empty()
    pocket_summary = mode == 'p2rank' ? FORMAT_BINDING_SITES.out.pocket_summary : Channel.empty()
    
    // Consolidation outputs (will be empty if not run)
    metrics_summary = params.run_consolidation ? CONSOLIDATE_METRICS.out.summary_csv : Channel.empty()
    metrics_report = params.run_consolidation ? CONSOLIDATE_METRICS.out.report_markdown : Channel.empty()
}
