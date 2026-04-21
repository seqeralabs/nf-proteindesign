/*
========================================================================================
    DESIGN_BOLTZGEN: Backbone design using Boltzgen
========================================================================================
    Wraps BOLTZGEN_RUN and handles the pre-computed results shortcut: if
    boltzgen_output_dir is set in the samplesheet the Boltzgen step is skipped
    and the pre-computed directory is used directly.
*/

include { BOLTZGEN_RUN } from '../../modules/local/boltzgen_run'

workflow DESIGN_BOLTZGEN {

    take:
    ch_input  // [meta, design_yaml, structure_files, target_msa, target_sequence, target_template, boltzgen_output_dir]
    ch_cache  // path to cache directory or EMPTY_CACHE placeholder

    main:

    // Split into pre-computed vs needs-run branches
    ch_input
        .branch { meta, design_yaml, structure_files, target_msa, target_sequence, target_template, boltzgen_output_dir ->
            with_precomputed: boltzgen_output_dir != null
                return [meta, boltzgen_output_dir]
            needs_run: boltzgen_output_dir == null
                return [meta, design_yaml, structure_files]
        }
        .set { ch_branched }

    BOLTZGEN_RUN(ch_branched.needs_run, ch_cache)

    // Merge newly-run and pre-computed result directories
    ch_precomputed = ch_branched.with_precomputed
        .map { meta, boltzgen_dir -> [meta, boltzgen_dir] }

    ch_results = BOLTZGEN_RUN.out.results
        .mix(ch_precomputed)

    // Extract budget CIFs from both sources
    ch_budget_cifs_precomputed = ch_branched.with_precomputed
        .map { meta, boltzgen_dir ->
            def budget_cifs = file("${boltzgen_dir}/final_ranked_designs/final_*_designs/*.cif")
            [meta, budget_cifs]
        }

    ch_budget_design_cifs = BOLTZGEN_RUN.out.budget_design_cifs
        .mix(ch_budget_cifs_precomputed)

    emit:
    results            = ch_results
    budget_design_cifs = ch_budget_design_cifs
}
