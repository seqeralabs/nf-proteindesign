#!/usr/bin/env nextflow

/*
========================================================================================
    nf-proteindesign: Nextflow pipeline for Boltzgen protein design
========================================================================================
    Github : https://github.com/FloWuenne/nf-proteindesign-2025
----------------------------------------------------------------------------------------
*/

nextflow.enable.dsl = 2

/*
========================================================================================
    VALIDATE INPUTS
========================================================================================
*/

// Validate required parameters
if (!params.input) {
    error "ERROR: Please provide a samplesheet with --input"
}

// Detect workflow mode based on samplesheet headers
def samplesheet_headers = file(params.input).readLines()[0].split(',').collect { it.trim() }
def is_target_mode = samplesheet_headers.contains('target_structure')
def is_design_mode = samplesheet_headers.contains('design_yaml')

if (!is_target_mode && !is_design_mode) {
    error """
    ERROR: Invalid samplesheet format!
    
    Samplesheet must contain either:
    - 'design_yaml' column for pre-made design mode
    - 'target_structure' column for target-based design generation mode
    
    Found headers: ${samplesheet_headers.join(', ')}
    """
}

/*
========================================================================================
    NAMED WORKFLOW FOR PIPELINE
========================================================================================
*/

include { VALIDATE_SAMPLESHEET } from './modules/local/validate_samplesheet'
include { BOLTZGEN_RUN } from './modules/local/boltzgen_run'
include { IPSAE_CALCULATE } from './modules/local/ipsae_calculate'
include { TARGET_TO_DESIGNS } from './workflows/target_to_designs'
include { P2RANK_TO_DESIGNS } from './workflows/p2rank_to_designs'

workflow NFPROTEINDESIGN {

    if (is_target_mode) {
        /*
         * TARGET-BASED MODE: Generate design variants from target structures
         */
        
        // Create channel from target samplesheet
        ch_targets = Channel
            .fromPath(params.input, checkIfExists: true)
            .splitCsv(header: true, sep: ',')
            .map { row ->
                def meta = [:]
                meta.id = row.sample_id
                
                // Target-specific parameters
                meta.target_chain_ids = row.target_chain_ids ?: 'A'
                meta.min_length = row.min_length ? row.min_length.toInteger() : params.min_design_length
                meta.max_length = row.max_length ? row.max_length.toInteger() : params.max_design_length
                meta.length_step = row.length_step ? row.length_step.toInteger() : params.length_step
                meta.n_variants_per_length = row.n_variants_per_length ? row.n_variants_per_length.toInteger() : params.n_variants_per_length
                meta.design_type = row.design_type ?: params.design_type
                
                // P2Rank-specific parameters
                meta.use_p2rank = row.use_p2rank ? row.use_p2rank.toBoolean() : params.use_p2rank
                meta.top_n_pockets = row.top_n_pockets ? row.top_n_pockets.toInteger() : params.top_n_pockets
                meta.min_pocket_score = row.min_pocket_score ? row.min_pocket_score.toFloat() : params.min_pocket_score
                meta.binding_region_mode = row.binding_region_mode ?: params.binding_region_mode
                meta.expand_region = row.expand_region ? row.expand_region.toInteger() : params.expand_region
                
                // Boltzgen parameters
                meta.protocol = row.protocol ?: params.protocol
                meta.num_designs = row.num_designs ? row.num_designs.toInteger() : params.num_designs
                meta.budget = row.budget ? row.budget.toInteger() : params.budget
                
                // Validate target structure exists
                if (!file(row.target_structure).exists()) {
                    error "ERROR: Target structure file does not exist: ${row.target_structure}"
                }
                
                [meta, file(row.target_structure)]
            }

        // Determine which workflow to use
        if (params.use_p2rank) {
            log.info """
            ========================================
            Running in P2RANK-BASED MODE
            ========================================
            P2Rank will identify binding sites in
            target structures, then Boltzgen will
            design binding partners for those sites.
            ========================================
            """.stripIndent()
            
            P2RANK_TO_DESIGNS(ch_targets)
        } else {
            log.info """
            ========================================
            Running in TARGET-BASED MODE
            ========================================
            Input targets will be used to generate
            diversified design specifications, then
            all designs will run in parallel.
            ========================================
            """.stripIndent()
            
            TARGET_TO_DESIGNS(ch_targets)
        }

    } else {
        /*
         * DESIGN-BASED MODE: Use pre-made design YAML files
         */
        log.info """
        ========================================
        Running in DESIGN-BASED MODE
        ========================================
        Using pre-made design YAML files
        from samplesheet.
        ========================================
        """.stripIndent()

        // Create channel from design samplesheet (original behavior)
        ch_input = Channel
            .fromPath(params.input, checkIfExists: true)
            .splitCsv(header: true, sep: ',')
            .map { row ->
                def meta = [:]
                meta.id = row.sample_id
                meta.protocol = row.protocol ?: params.protocol
                meta.num_designs = row.num_designs ? row.num_designs.toInteger() : params.num_designs
                meta.budget = row.budget ? row.budget.toInteger() : params.budget
                meta.reuse = row.reuse ? row.reuse.toBoolean() : false
                
                // Validate design YAML exists
                if (!file(row.design_yaml).exists()) {
                    error "ERROR: Design YAML file does not exist: ${row.design_yaml}"
                }
                
                [meta, file(row.design_yaml)]
            }

        // Run Boltzgen for each sample
        BOLTZGEN_RUN(ch_input)

        // Run IPSAE scoring if enabled
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
    }

}

/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/

workflow {
    NFPROTEINDESIGN()
}

/*
========================================================================================
    THE END
========================================================================================
*/
