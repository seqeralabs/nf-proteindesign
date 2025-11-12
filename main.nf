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

// Determine workflow mode
// Priority: 1) Explicit --mode parameter, 2) Auto-detect from samplesheet headers
def workflow_mode = params.mode

if (!workflow_mode) {
    // Auto-detect mode from samplesheet headers
    def samplesheet_headers = file(params.input).readLines()[0].split(',').collect { it.trim() }
    def has_design_yaml = samplesheet_headers.contains('design_yaml')
    def has_target_structure = samplesheet_headers.contains('target_structure')
    def has_use_p2rank = samplesheet_headers.contains('use_p2rank')
    
    if (has_design_yaml) {
        workflow_mode = 'design'
    } else if (has_target_structure) {
        // Check if using P2Rank mode via parameter or samplesheet
        if (params.use_p2rank) {
            workflow_mode = 'p2rank'
        } else {
            workflow_mode = 'target'
        }
    } else {
        error """
        ERROR: Cannot determine workflow mode!
        
        Please either:
        1. Specify mode explicitly with --mode (design|target|p2rank)
        2. Use a samplesheet with proper column headers:
           - 'design_yaml' for design mode
           - 'target_structure' for target/p2rank mode
        
        Found headers: ${samplesheet_headers.join(', ')}
        """
    }
    
    log.info "Auto-detected workflow mode: ${workflow_mode}"
} else {
    // Validate explicit mode parameter
    def valid_modes = ['design', 'target', 'p2rank']
    if (!valid_modes.contains(workflow_mode)) {
        error "ERROR: Invalid --mode '${workflow_mode}'. Must be one of: ${valid_modes.join(', ')}"
    }
    log.info "Using explicit workflow mode: ${workflow_mode}"
}

/*
========================================================================================
    NAMED WORKFLOW FOR PIPELINE
========================================================================================
*/

include { PROTEIN_DESIGN } from './workflows/protein_design'

workflow NFPROTEINDESIGN {

    // ========================================================================
    // Create input channel based on workflow mode
    // ========================================================================
    
    if (workflow_mode == 'design') {
        // DESIGN MODE: Use pre-made design YAML files
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
    } 
    else if (workflow_mode == 'target' || workflow_mode == 'p2rank') {
        // TARGET or P2RANK MODE: Use target structures
        ch_input = Channel
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
    }

    // ========================================================================
    // Run unified PROTEIN_DESIGN workflow
    // ========================================================================
    
    PROTEIN_DESIGN(ch_input, workflow_mode)

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
