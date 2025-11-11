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
