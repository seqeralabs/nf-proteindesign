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

/*
========================================================================================
    NAMED WORKFLOW FOR PIPELINE
========================================================================================
*/

include { VALIDATE_SAMPLESHEET } from './modules/local/validate_samplesheet'
include { BOLTZGEN_RUN } from './modules/local/boltzgen_run'

workflow NFPROTEINDESIGN {

    // Create channel from samplesheet
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
        // Boltzgen outputs structure: sample_output/predictions/<input>/*_model_*.cif and pae_*_model_*.npz
        ch_ipsae_input = BOLTZGEN_RUN.out.results
            .flatMap { meta, results_dir ->
                // Find all model CIF files and corresponding PAE files
                def cif_files = file("${results_dir}/predictions/**/*_model_*.cif")
                def pairs = []
                
                cif_files.each { cif ->
                    // Extract model number and input name from CIF filename
                    def cif_name = cif.getName()
                    def matcher = cif_name =~ /(.+)_model_(\d+)\.cif$/
                    
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
