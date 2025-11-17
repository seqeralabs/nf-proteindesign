/*
========================================================================================
    P2RANK_TO_DESIGNS: Workflow for P2Rank-based binding site prediction and design
========================================================================================
    This workflow uses P2Rank to identify binding sites in target structures,
    then generates Boltz2 design specifications targeting those sites.
----------------------------------------------------------------------------------------
*/

include { P2RANK_PREDICT } from '../modules/local/p2rank_predict'
include { FORMAT_BINDING_SITES } from '../modules/local/format_binding_sites'
include { BOLTZGEN_RUN } from '../modules/local/boltzgen_run'
include { IPSAE_CALCULATE } from '../modules/local/ipsae_calculate'

workflow P2RANK_TO_DESIGNS {
    
    take:
    ch_targets  // channel: [meta, target_structure_file]
    ch_cache    // channel: path to cache directory or EMPTY_CACHE placeholder

    main:
    // Step 1: Run P2Rank to identify binding sites
    P2RANK_PREDICT(ch_targets)

    // Step 2: Combine P2Rank outputs for formatting
    ch_p2rank_results = P2RANK_PREDICT.out.predictions
        .join(P2RANK_PREDICT.out.residues, by: [0, 1])  // Join by meta and structure file
        .map { meta, structure, predictions_csv, residues_csv ->
            [meta, structure, predictions_csv, residues_csv]
        }

    // Step 3: Format P2Rank predictions into Boltz2 YAML files
    FORMAT_BINDING_SITES(ch_p2rank_results)

    // Step 4: Flatten the channel to get individual design YAMLs
    // Keep structure file with the YAML files
    ch_individual_designs = ch_p2rank_results
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

    // Step 5: Run Boltzgen for each design in parallel
    BOLTZGEN_RUN(ch_individual_designs, ch_cache)

    // Step 6: Optionally run IPSAE scoring if enabled
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
    p2rank_predictions = P2RANK_PREDICT.out.predictions
    p2rank_residues = P2RANK_PREDICT.out.residues
    design_yamls = FORMAT_BINDING_SITES.out.design_yamls
    design_info = FORMAT_BINDING_SITES.out.info
    pocket_summary = FORMAT_BINDING_SITES.out.pocket_summary
    boltzgen_results = BOLTZGEN_RUN.out.results
    final_designs = BOLTZGEN_RUN.out.final_designs
}
