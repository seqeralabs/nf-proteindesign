#!/usr/bin/env nextflow

/*
========================================================================================
    nf-proteindesign: Nextflow pipeline for AI-powered protein design
========================================================================================
    Supports two generative design backends:
      --protein_design_tool boltzgen   (default, original)
      --protein_design_tool complexa   (newer flow-matching approach)
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

    def valid_tools = ['boltzgen', 'complexa']
    if (!valid_tools.contains(params.protein_design_tool)) {
        error "ERROR: --protein_design_tool must be one of: ${valid_tools.join(', ')}. Got: '${params.protein_design_tool}'"
    }

    // ========================================================================
    // Print pipeline startup banner
    // ========================================================================
    def enabled_modules = []
    if (params.run_proteinmpnn) enabled_modules.add('ProteinMPNN')
    if (params.run_ipsae) enabled_modules.add('IPSAE')
    if (params.run_prodigy) enabled_modules.add('PRODIGY')
    if (params.run_foldseek) enabled_modules.add('Foldseek')
    if (params.run_consolidation) enabled_modules.add('Metrics Consolidation')
    def modules_str = enabled_modules.size() > 0 ? enabled_modules.join(', ') : 'None'

    def banner_width = 64
    def version_text = "nf-proteindesign v2.0.0"
    def tool_name = params.protein_design_tool == 'complexa' ? 'Proteina-Complexa' : 'BoltzGen'
    def mode_line = "Mode: DESIGN (${tool_name})"
    def desc_line = params.protein_design_tool == 'complexa' ? 'Using pipeline config YAML files' : 'Using design YAML files'
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
    // Parse samplesheet — schema and channel shape depend on design tool
    // ========================================================================

    if (params.protein_design_tool == 'boltzgen') {
        // ---- BoltzGen samplesheet ----
        def samplesheet = samplesheetToList(
            params.input,
            "${projectDir}/assets/schema_input_boltzgen.json"
        )

        ch_input = Channel
            .fromList(samplesheet)
            .map { tuple ->
                // Schema order: sample_id, design_yaml, structure_files, protocol,
                //   num_designs, budget, reuse, target_msa, target_sequence,
                //   target_template, boltzgen_output_dir
                def sample_id            = tuple[0]
                def design_yaml_path     = tuple[1]
                def structure_files_str  = tuple[2]
                def protocol             = tuple[3]
                def num_designs          = tuple[4]
                def budget               = tuple[5]
                def reuse                = tuple.size() > 6 ? tuple[6] : null
                def target_msa_path      = tuple.size() > 7 ? tuple[7] : null
                def target_sequence_path = tuple.size() > 8 ? tuple[8] : null
                def target_template_path = tuple.size() > 9 ? tuple[9] : null

                // Resolve design YAML
                def design_yaml = design_yaml_path.startsWith('/') || design_yaml_path.contains('://') ?
                    file(design_yaml_path, checkIfExists: true) :
                    (file(design_yaml_path).exists() ? file(design_yaml_path) : file("${project_dir}/${design_yaml_path}", checkIfExists: true))

                // Parse comma-separated structure files
                def structure_files = []
                if (structure_files_str) {
                    structure_files_str.split(',').each { p ->
                        def trimmed = p.trim()
                        def resolved = trimmed.startsWith('/') || trimmed.contains('://') ?
                            file(trimmed, checkIfExists: true) :
                            (file(trimmed).exists() ? file(trimmed) : file("${project_dir}/${trimmed}", checkIfExists: true))
                        structure_files.add(resolved)
                    }
                }

                // Resolve target sequence if provided
                def target_sequence = null
                if (target_sequence_path) {
                    target_sequence = target_sequence_path.startsWith('/') || target_sequence_path.contains('://') ?
                        file(target_sequence_path, checkIfExists: true) :
                        (file(target_sequence_path).exists() ? file(target_sequence_path) : file("${project_dir}/${target_sequence_path}", checkIfExists: true))
                }

                def meta = [:]
                meta.id              = sample_id
                meta.protocol        = protocol
                meta.num_designs     = num_designs
                meta.budget          = budget
                meta.reuse           = reuse ?: false
                meta.target_msa      = target_msa_path
                meta.target_template = target_template_path

                // BoltzGen channel shape: [meta, design_yaml, structure_files, target_sequence]
                [meta, design_yaml, structure_files, target_sequence]
            }

    } else {
        // ---- Complexa samplesheet ----
        def samplesheet = samplesheetToList(
            params.input,
            "${projectDir}/assets/schema_input_complexa.json"
        )

        ch_input = Channel
            .fromList(samplesheet)
            .map { tuple ->
                // Schema order: sample_id, target_pdb, pipeline_config,
                //   target_sequence, target_msa, target_template
                def sample_id            = tuple[0]
                def target_pdb_path      = tuple[1]
                def pipeline_config_path = tuple[2]
                def target_sequence_path = tuple[3]
                def target_msa_path      = tuple.size() > 4 ? tuple[4] : null
                def target_template_path = tuple.size() > 5 ? tuple[5] : null

                def target_pdb = target_pdb_path.startsWith('/') || target_pdb_path.contains('://') ?
                    file(target_pdb_path, checkIfExists: true) :
                    (file(target_pdb_path).exists() ? file(target_pdb_path) : file("${project_dir}/${target_pdb_path}", checkIfExists: true))

                def pipeline_config = pipeline_config_path.startsWith('/') || pipeline_config_path.contains('://') ?
                    file(pipeline_config_path, checkIfExists: true) :
                    (file(pipeline_config_path).exists() ? file(pipeline_config_path) : file("${project_dir}/${pipeline_config_path}", checkIfExists: true))

                def target_sequence = target_sequence_path.startsWith('/') || target_sequence_path.contains('://') ?
                    file(target_sequence_path, checkIfExists: true) :
                    (file(target_sequence_path).exists() ? file(target_sequence_path) : file("${project_dir}/${target_sequence_path}", checkIfExists: true))

                def meta = [:]
                meta.id              = sample_id
                meta.target_msa      = target_msa_path
                meta.target_template = target_template_path

                // Complexa channel shape: [meta, target_pdb, pipeline_config, target_sequence]
                [meta, target_pdb, pipeline_config, target_sequence]
            }
    }

    // ========================================================================
    // Prepare design-tool checkpoint / cache channel
    // ========================================================================

    if (params.protein_design_tool == 'boltzgen') {
        if (params.cache_dir) {
            ch_design_cache = Channel
                .fromPath(params.cache_dir, type: 'dir', checkIfExists: true)
                .first()
        } else {
            ch_design_cache = Channel.value(file('EMPTY_CACHE'))
        }
    } else {
        if (params.complexa_ckpt_dir) {
            ch_design_cache = Channel
                .fromPath(params.complexa_ckpt_dir, type: 'dir', checkIfExists: true)
                .first()
        } else {
            ch_design_cache = Channel.value(file('EMPTY_CKPT'))
        }
    }

    // ========================================================================
    // Prepare cache directory channel for Boltz-2 (shared across both tools)
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

    PROTEIN_DESIGN(ch_input, ch_design_cache, ch_boltz2_cache)

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
