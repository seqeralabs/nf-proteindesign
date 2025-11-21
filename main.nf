#!/usr/bin/env nextflow

/*
========================================================================================
    nf-proteindesign: Nextflow pipeline for Boltzgen protein design
========================================================================================
    Github : https://github.com/seqeralabs/nf-proteindesign
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

/*
========================================================================================
    NAMED WORKFLOW FOR PIPELINE
========================================================================================
*/

include { PROTEIN_DESIGN } from './workflows/protein_design'

workflow NFPROTEINDESIGN {

    // ========================================================================
    // Print pipeline startup banner
    // ========================================================================
    // Build list of enabled analysis modules
    def enabled_modules = []
    if (params.run_proteinmpnn) enabled_modules.add('ProteinMPNN')
    if (params.run_ipsae) enabled_modules.add('IPSAE')
    if (params.run_prodigy) enabled_modules.add('PRODIGY')
    if (params.run_consolidation) enabled_modules.add('Metrics Consolidation')
    def modules_str = enabled_modules.size() > 0 ? enabled_modules.join(', ') : 'None'
    
    // Format the banner with proper width (64 chars inside the box)
    def banner_width = 64
    def version_text = "nf-proteindesign v1.0.0"
    def mode_line = "Mode: DESIGN"
    def desc_line = "Using design YAML files"
    def params_header = "Design Parameters:"
    def num_designs_line = "• num_designs: ${params.num_designs}"
    def budget_line = "• budget: ${params.budget}"
    def modules_header = "Analysis Modules:"
    def output_line = "Output: ${params.outdir}"
    
    // Truncate modules string if too long
    def max_modules_len = banner_width - 2
    if (modules_str.length() > max_modules_len) {
        modules_str = modules_str.substring(0, max_modules_len - 3) + "..."
    }
    
    log.info """
    
    ╔════════════════════════════════════════════════════════════════╗
    ║${version_text.center(banner_width)}║
    ╠════════════════════════════════════════════════════════════════╣
    ║  🎯 ${mode_line.padRight(banner_width - 6)}║
    ║     ${desc_line.padRight(banner_width - 5)}║
    ╠════════════════════════════════════════════════════════════════╣
    ║  ⚙️  ${params_header.padRight(banner_width - 7)}║
    ║      ${num_designs_line.padRight(banner_width - 6)}║
    ║      ${budget_line.padRight(banner_width - 6)}║
    ╠════════════════════════════════════════════════════════════════╣
    ║  🔬 ${modules_header.padRight(banner_width - 6)}║
    ║     ${modules_str.padRight(banner_width - 5)}║
    ╠════════════════════════════════════════════════════════════════╣
    ║  📁 ${output_line.padRight(banner_width - 6)}║
    ╚════════════════════════════════════════════════════════════════╝
    
    """.stripIndent()

    // ========================================================================
    // Store projectDir for use in closures
    // ========================================================================
    def project_dir = projectDir
    
    // ========================================================================
    // Create input channel for design mode
    // ========================================================================
    
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

    // ========================================================================
    // Prepare cache directory channel for Boltzgen
    // ========================================================================
    
    // If cache_dir is specified, stage it as input; otherwise use empty placeholder
    if (params.cache_dir) {
        ch_cache = Channel
            .fromPath(params.cache_dir, type: 'dir', checkIfExists: true)
            .first()
    } else {
        // Create a placeholder file when no cache is provided
        ch_cache = Channel.value(file('EMPTY_CACHE'))
    }
    
    // ========================================================================
    // Run PROTEIN_DESIGN workflow
    // ========================================================================
    
    PROTEIN_DESIGN(ch_input, ch_cache)

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
