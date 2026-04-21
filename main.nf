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
    def tool_labels = ['boltzgen': 'Boltzgen', 'rfdiffusion_v1': 'RFdiffusion v1', 'rfdiffusion_v3': 'RFdiffusion3']
    def desc_line = "Design tool: ${tool_labels.getOrDefault(params.design_tool, params.design_tool)}"
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
            // Order: sample_id, design_yaml, structure_files, protocol, num_designs, budget, reuse, target_msa, target_sequence, target_template, boltzgen_output_dir
            def sample_id = tuple[0]
            def design_yaml_path = tuple[1]
            def structure_files_str = tuple[2]
            def protocol = tuple[3]
            def num_designs = tuple[4]
            def budget = tuple[5]
            def reuse = tuple.size() > 6 ? tuple[6] : null
            def target_msa_path = tuple.size() > 7 ? tuple[7] : null
            def target_sequence_path = tuple.size() > 8 ? tuple[8] : null
            def target_template_path = tuple.size() > 9 ? tuple[9] : null
            def boltzgen_output_dir_path = tuple.size() > 10 ? tuple[10] : null
            
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
            
            // Parse target MSA file if provided
            def target_msa = null
            if (target_msa_path) {
                if (target_msa_path.startsWith('/') || target_msa_path.contains('://')) {
                    target_msa = file(target_msa_path, checkIfExists: true)
                } else {
                    def launchDir_path = file(target_msa_path)
                    if (launchDir_path.exists()) {
                        target_msa = launchDir_path
                    } else {
                        target_msa = file("${project_dir}/${target_msa_path}", checkIfExists: true)
                    }
                }
            }

            // Parse target sequence FASTA file (required for Boltz2 refolding)
            def target_sequence = null
            if (target_sequence_path) {
                if (target_sequence_path.startsWith('/') || target_sequence_path.contains('://')) {
                    target_sequence = file(target_sequence_path, checkIfExists: true)
                } else {
                    def launchDir_path = file(target_sequence_path)
                    if (launchDir_path.exists()) {
                        target_sequence = launchDir_path
                    } else {
                        target_sequence = file("${project_dir}/${target_sequence_path}", checkIfExists: true)
                    }
                }
            }

            // Parse target template CIF file (optional for Boltz2 refolding)
            def target_template = null
            if (target_template_path) {
                if (target_template_path.startsWith('/') || target_template_path.contains('://')) {
                    target_template = file(target_template_path, checkIfExists: true)
                } else {
                    def launchDir_path = file(target_template_path)
                    if (launchDir_path.exists()) {
                        target_template = launchDir_path
                    } else {
                        target_template = file("${project_dir}/${target_template_path}", checkIfExists: true)
                    }
                }
            }

            // Parse boltzgen_output_dir if provided
            def boltzgen_output_dir = null
            if (boltzgen_output_dir_path) {
                if (boltzgen_output_dir_path.startsWith('/') || boltzgen_output_dir_path.contains('://')) {
                    boltzgen_output_dir = file(boltzgen_output_dir_path, type: 'dir', checkIfExists: true)
                } else {
                    def launchDir_path = file(boltzgen_output_dir_path, type: 'dir')
                    if (launchDir_path.exists()) {
                        boltzgen_output_dir = launchDir_path
                    } else {
                        boltzgen_output_dir = file("${project_dir}/${boltzgen_output_dir_path}", type: 'dir', checkIfExists: true)
                    }
                }
            }

            def meta = [:]
            meta.id = sample_id
            meta.protocol = protocol
            meta.num_designs = num_designs
            meta.budget = budget
            meta.reuse = reuse ?: false

            [meta, design_yaml, structure_files, target_msa, target_sequence, target_template, boltzgen_output_dir]
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
    // Prepare cache directory channel for Boltz-2
    // ========================================================================

    // If boltz2_cache is specified, stage it as input; otherwise use empty placeholder
    if (params.boltz2_cache) {
        ch_boltz2_cache = Channel
            .fromPath(params.boltz2_cache, type: 'dir', checkIfExists: true)
            .first()
    } else {
        // Create a placeholder file when no cache is provided
        ch_boltz2_cache = Channel.value(file('EMPTY_BOLTZ2_CACHE'))
    }

    // ========================================================================
    // Run PROTEIN_DESIGN workflow
    // ========================================================================

    PROTEIN_DESIGN(ch_input, ch_cache, ch_boltz2_cache)

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
