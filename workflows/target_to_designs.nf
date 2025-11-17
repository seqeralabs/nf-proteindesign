/*
========================================================================================
    TARGET_TO_DESIGNS: Workflow for generating multiple design variants from target structure
========================================================================================
    This workflow takes target structures as input and generates diversified design
    specifications, then runs Boltzgen on all variants in parallel.
----------------------------------------------------------------------------------------
*/

include { GENERATE_DESIGN_VARIANTS } from '../modules/local/generate_design_variants'
include { CREATE_DESIGN_SAMPLESHEET } from '../modules/local/create_design_samplesheet'
include { BOLTZGEN_RUN } from '../modules/local/boltzgen_run'
include { IPSAE_CALCULATE } from '../modules/local/ipsae_calculate'

workflow TARGET_TO_DESIGNS {
    
    take:
    ch_targets  // channel: [meta, target_structure_file]
    ch_cache    // channel: path to cache directory or EMPTY_CACHE placeholder

    main:
    // Step 1: Generate diversified design YAML files from target
    GENERATE_DESIGN_VARIANTS(ch_targets)

    // Step 2: Flatten the channel to get individual design YAMLs
    // Each design YAML becomes a separate item in the channel
    ch_individual_designs = GENERATE_DESIGN_VARIANTS.out.design_yamls
        .transpose()  // Flatten the list of YAML files
        .map { meta, yaml_file ->
            // Create new meta for each design
            def design_meta = meta.clone()
            // Extract design_id from filename
            def design_id = yaml_file.baseName
            design_meta.id = design_id
            design_meta.parent_id = meta.id  // Keep reference to original target
            
            [design_meta, yaml_file]
        }

    // Step 3: Run Boltzgen for each design in parallel
    BOLTZGEN_RUN(ch_individual_designs, ch_cache)

    // Step 4: Optionally run IPSAE scoring if enabled
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
                    // Extract model number and input name from CIF filename
                    def cif_name = cif.getName()
                    def matcher = cif_name =~ /(.+)_model_(\\d+)\\.cif$/
                    
                    if (matcher.matches()) {
                        def input_name = matcher[0][1]
                        def model_num = matcher[0][2]
                        
                        // Find corresponding PAE file
                        def pae_file = file("${results_dir}/predictions/${input_name}/pae_${input_name}_model_${model_num}.npz")
                        
                        if (pae_file.exists()) {
                            // Create unique meta for each model
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
    design_variants = GENERATE_DESIGN_VARIANTS.out.design_yamls
    design_info = GENERATE_DESIGN_VARIANTS.out.info
    boltzgen_results = BOLTZGEN_RUN.out.results
    final_designs = BOLTZGEN_RUN.out.final_designs
}
