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
include { IPSAE_CALCULATE } from '../modules/local/ipsae_calculate'

workflow PROTEIN_DESIGN {
    
    take:
    ch_input    // channel: [meta, file] - can be design YAML or target structure depending on mode
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
        
        // Input is already [meta, design_yaml], ready for Boltzgen
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
        GENERATE_DESIGN_VARIANTS(ch_input)
        
        // Step 2: Flatten to get individual design YAMLs
        ch_designs_for_boltzgen = GENERATE_DESIGN_VARIANTS.out.design_yamls
            .transpose()  // Flatten list of YAML files
            .map { meta, yaml_file ->
                // Create new meta for each design
                def design_meta = meta.clone()
                def design_id = yaml_file.baseName
                design_meta.id = design_id
                design_meta.parent_id = meta.id
                
                [design_meta, yaml_file]
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
        P2RANK_PREDICT(ch_input)
        
        // Step 2: Combine P2Rank outputs for formatting
        ch_p2rank_results = P2RANK_PREDICT.out.predictions
            .join(P2RANK_PREDICT.out.residues, by: [0, 1])
            .map { meta, structure, predictions_csv, residues_csv ->
                [meta, structure, predictions_csv, residues_csv]
            }
        
        // Step 3: Format P2Rank predictions into Boltz2 YAML files
        FORMAT_BINDING_SITES(ch_p2rank_results)
        
        // Step 4: Flatten to get individual design YAMLs
        ch_designs_for_boltzgen = FORMAT_BINDING_SITES.out.design_yamls
            .transpose()
            .map { meta, yaml_file ->
                def design_meta = meta.clone()
                def design_id = yaml_file.baseName
                design_meta.id = design_id
                design_meta.parent_id = meta.id
                
                [design_meta, yaml_file]
            }
    }
    
    // ========================================================================
    // CONVERGENCE POINT: All modes run Boltzgen on design YAMLs
    // ========================================================================
    
    // Run Boltzgen for each design in parallel
    BOLTZGEN_RUN(ch_designs_for_boltzgen)
    
    // ========================================================================
    // OPTIONAL: IPSAE scoring if enabled
    // ========================================================================
    if (params.run_ipsae) {
        // Prepare IPSAE script as a channel
        ch_ipsae_script = Channel.fromPath("${projectDir}/assets/ipsae.py", checkIfExists: true)
        
        // Create channel with PAE and CIF files from Boltzgen output
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

    emit:
    // Common outputs for all modes
    boltzgen_results = BOLTZGEN_RUN.out.results
    final_designs = BOLTZGEN_RUN.out.final_designs
    
    // Mode-specific outputs (will be empty for modes that don't generate them)
    design_variants = mode == 'target' ? GENERATE_DESIGN_VARIANTS.out.design_yamls : Channel.empty()
    design_info = mode == 'target' ? GENERATE_DESIGN_VARIANTS.out.info : Channel.empty()
    p2rank_predictions = mode == 'p2rank' ? P2RANK_PREDICT.out.predictions : Channel.empty()
    p2rank_residues = mode == 'p2rank' ? P2RANK_PREDICT.out.residues : Channel.empty()
    design_yamls = mode == 'p2rank' ? FORMAT_BINDING_SITES.out.design_yamls : Channel.empty()
    pocket_summary = mode == 'p2rank' ? FORMAT_BINDING_SITES.out.pocket_summary : Channel.empty()
}
