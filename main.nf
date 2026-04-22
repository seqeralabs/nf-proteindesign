#!/usr/bin/env nextflow

/*
========================================================================================
    nf-proteindesign: Nextflow pipeline for Proteina-Complexa protein design
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
    NAMED WORKFLOW FOR PIPELINE
========================================================================================
*/

include { PROTEIN_DESIGN } from './workflows/protein_design'

workflow NFPROTEINDESIGN {

    // ========================================================================
    // Validate inputs
    // ========================================================================
    if (!params.input) {
        error "ERROR: Please provide a samplesheet with --input"
    }

    // ========================================================================
    // Print pipeline startup banner
    // ========================================================================
    def enabled_modules = []
    if (params.run_proteinmpnn) enabled_modules.add('ProteinMPNN')
    if (params.run_ipsae) enabled_modules.add('IPSAE')
    if (params.run_prodigy) enabled_modules.add('PRODIGY')
    if (params.run_consolidation) enabled_modules.add('Metrics Consolidation')
    def modules_str = enabled_modules.size() > 0 ? enabled_modules.join(', ') : 'None'
    
    def banner_width = 64
    def version_text = "nf-proteindesign v2.0.0"
    def mode_line = "Mode: DESIGN (Proteina-Complexa)"
    def desc_line = "Using pipeline config YAML files"
    def modules_header = "Analysis Modules:"
    def output_line = "Output: ${params.outdir}"
    
    if (modules_str.length() > banner_width - 2) {
        modules_str = modules_str.substring(0, banner_width - 5) + "..."
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
            // samplesheetToList returns values in schema property order:
            // sample_id, target_pdb, pipeline_config, target_sequence, target_msa, target_template
            def sample_id            = tuple[0]
            def target_pdb_path      = tuple[1]
            def pipeline_config_path = tuple[2]
            def target_sequence_path = tuple[3]
            def target_msa_path      = tuple.size() > 4 ? tuple[4] : null
            def target_template_path = tuple.size() > 5 ? tuple[5] : null

            // Resolve file paths (try launchDir first, then projectDir for Platform)
            def target_pdb = target_pdb_path.startsWith('/') || target_pdb_path.contains('://') ?
                file(target_pdb_path, checkIfExists: true) :
                (file(target_pdb_path).exists() ? file(target_pdb_path) : file("${project_dir}/${target_pdb_path}", checkIfExists: true))

            def pipeline_config = pipeline_config_path.startsWith('/') || pipeline_config_path.contains('://') ?
                file(pipeline_config_path, checkIfExists: true) :
                (file(pipeline_config_path).exists() ? file(pipeline_config_path) : file("${project_dir}/${pipeline_config_path}", checkIfExists: true))

            def target_sequence = target_sequence_path.startsWith('/') || target_sequence_path.contains('://') ?
                file(target_sequence_path, checkIfExists: true) :
                (file(target_sequence_path).exists() ? file(target_sequence_path) : file("${project_dir}/${target_sequence_path}", checkIfExists: true))

            // Build metadata map
            def meta = [:]
            meta.id              = sample_id
            meta.target_msa      = target_msa_path      // stored as string; resolved in workflow if needed
            meta.target_template = target_template_path  // stored as string; resolved in workflow if needed

            [meta, target_pdb, pipeline_config, target_sequence]
        }

    // ========================================================================
    // Prepare Complexa checkpoint directory channel
    // ========================================================================

    if (params.complexa_ckpt_dir) {
        ch_ckpt_dir = Channel
            .fromPath(params.complexa_ckpt_dir, type: 'dir', checkIfExists: true)
            .first()
    } else {
        ch_ckpt_dir = Channel.value(file('EMPTY_CKPT'))
    }

    // ========================================================================
    // Prepare cache directory channel for Boltz-2
    // ========================================================================

    if (params.boltz2_cache) {
        ch_boltz2_cache = Channel
            .fromPath(params.boltz2_cache, type: 'dir', checkIfExists: true)
            .first()
    } else {
        ch_boltz2_cache = Channel.value(file('EMPTY_BOLTZ2_CACHE'))
    }

    // ========================================================================
    // Run PROTEIN_DESIGN workflow
    // ========================================================================

    PROTEIN_DESIGN(ch_input, ch_ckpt_dir, ch_boltz2_cache)

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
