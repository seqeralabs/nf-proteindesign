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
    IMPORT FUNCTIONS / MODULES
========================================================================================
*/

include { samplesheetToList } from 'plugin/nf-schema'

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
    // Store projectDir for use in closures
    // ========================================================================
    def project_dir = projectDir
    
    // ========================================================================
    // Create input channel based on workflow mode
    // ========================================================================
    
    if (workflow_mode == 'design') {
        // DESIGN MODE: Use pre-made design YAML files
        // Validate and parse samplesheet using nf-schema
        def design_samplesheet = samplesheetToList(
            params.input, 
            "${projectDir}/assets/schema_input_design.json"
        )
        
        ch_input = Channel
            .fromList(design_samplesheet)
            .map { tuple ->
                // samplesheetToList returns list of values in schema order
                // Order: sample_id, design_yaml, structure_files, protocol, num_designs, budget, reuse
                def sample_id = tuple[0]
                def design_yaml_path = tuple[1]
                def structure_files_str = tuple[2]
                def protocol = tuple[3]
                def num_designs = tuple[4]
                def budget = tuple[5]
                def reuse = tuple.size() > 6 ? tuple[6] : null
                
                // Convert design YAML to file object and validate existence
                // Smart path resolution: try launchDir first (for local runs), then projectDir (for Platform)
                def design_yaml
                if (design_yaml_path.startsWith('/') || design_yaml_path.contains('://')) {
                    // Absolute path or remote URL - use as-is
                    design_yaml = file(design_yaml_path, checkIfExists: true)
                } else {
                    // Relative path - try launchDir first, then projectDir
                    def launchDir_path = file(design_yaml_path)
                    if (launchDir_path.exists()) {
                        design_yaml = launchDir_path
                    } else {
                        // Fall back to projectDir (for Seqera Platform)
                        design_yaml = file("${project_dir}/${design_yaml_path}", checkIfExists: true)
                    }
                }
                
                // Parse structure files (can be comma-separated list)
                def structure_files = []
                if (structure_files_str) {
                    structure_files_str.split(',').each { structure_path ->
                        def trimmed_path = structure_path.trim()
                        if (trimmed_path.startsWith('/') || trimmed_path.contains('://')) {
                            structure_files.add(file(trimmed_path, checkIfExists: true))
                        } else {
                            def launchDir_path = file(trimmed_path)
                            if (launchDir_path.exists()) {
                                structure_files.add(launchDir_path)
                            } else {
                                structure_files.add(file("${project_dir}/${trimmed_path}", checkIfExists: true))
                            }
                        }
                    }
                }
                
                def meta = [:]
                meta.id = sample_id
                meta.protocol = protocol ?: params.protocol
                meta.num_designs = num_designs ?: params.num_designs
                meta.budget = budget ?: params.budget
                meta.reuse = reuse ?: false
                
                [meta, design_yaml, structure_files]
            }
    } 
    else if (workflow_mode == 'target' || workflow_mode == 'p2rank') {
        // TARGET or P2RANK MODE: Use target structures
        // Select appropriate schema based on mode
        def schema_path = workflow_mode == 'p2rank' ? 
            "${projectDir}/assets/schema_input_p2rank.json" : 
            "${projectDir}/assets/schema_input_target.json"
        
        // Validate and parse samplesheet using nf-schema
        def target_samplesheet = samplesheetToList(params.input, schema_path)
        
        ch_input = Channel
            .fromList(target_samplesheet)
            .map { tuple ->
                // samplesheetToList returns list of values in schema order
                def sample_id = tuple[0]
                def target_structure_path = tuple[1]
                
                // Convert to file object and validate existence
                // Smart path resolution: try launchDir first (for local runs), then projectDir (for Platform)
                def target_structure
                if (target_structure_path.startsWith('/') || target_structure_path.contains('://')) {
                    // Absolute path or remote URL - use as-is
                    target_structure = file(target_structure_path, checkIfExists: true)
                } else {
                    // Relative path - try launchDir first, then projectDir
                    def launchDir_path = file(target_structure_path)
                    if (launchDir_path.exists()) {
                        target_structure = launchDir_path
                    } else {
                        // Fall back to projectDir (for Seqera Platform)
                        target_structure = file("${project_dir}/${target_structure_path}", checkIfExists: true)
                    }
                }
                
                def meta = [:]
                meta.id = sample_id
                
                if (workflow_mode == 'p2rank') {
                    // P2Rank mode field order: sample_id, target_structure, use_p2rank, top_n_pockets, 
                    // min_pocket_score, binding_region_mode, expand_region, min_length, max_length, 
                    // length_step, n_variants_per_length, design_type, protocol, num_designs, budget
                    meta.use_p2rank = tuple[2] ?: params.use_p2rank
                    meta.top_n_pockets = tuple[3] ?: params.top_n_pockets
                    meta.min_pocket_score = tuple[4] ?: params.min_pocket_score
                    meta.binding_region_mode = tuple[5] ?: params.binding_region_mode
                    meta.expand_region = tuple[6] ?: params.expand_region
                    meta.min_length = tuple[7] ?: params.min_design_length
                    meta.max_length = tuple[8] ?: params.max_design_length
                    meta.length_step = tuple[9] ?: params.length_step
                    meta.n_variants_per_length = tuple[10] ?: params.n_variants_per_length
                    meta.design_type = tuple[11] ?: params.design_type
                    meta.protocol = tuple[12] ?: params.protocol
                    meta.num_designs = tuple[13] ?: params.num_designs
                    meta.budget = tuple[14] ?: params.budget
                    meta.target_chain_ids = 'A'  // Default for p2rank mode
                } else {
                    // Target mode field order: sample_id, target_structure, target_chain_ids, min_length, 
                    // max_length, length_step, n_variants_per_length, design_type, protocol, num_designs, budget
                    meta.target_chain_ids = tuple[2] ?: 'A'
                    meta.min_length = tuple[3] ?: params.min_design_length
                    meta.max_length = tuple[4] ?: params.max_design_length
                    meta.length_step = tuple[5] ?: params.length_step
                    meta.n_variants_per_length = tuple[6] ?: params.n_variants_per_length
                    meta.design_type = tuple[7] ?: params.design_type
                    meta.protocol = tuple[8] ?: params.protocol
                    meta.num_designs = tuple[9] ?: params.num_designs
                    meta.budget = tuple[10] ?: params.budget
                    // Set p2rank defaults for target mode
                    meta.use_p2rank = params.use_p2rank
                    meta.top_n_pockets = params.top_n_pockets
                    meta.min_pocket_score = params.min_pocket_score
                    meta.binding_region_mode = params.binding_region_mode
                    meta.expand_region = params.expand_region
                }
                
                [meta, target_structure]
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
