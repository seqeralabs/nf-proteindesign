/*
========================================================================================
    DESIGN_PROTEINA_COMPLEXA: Backbone design using Proteina-Complexa (NVIDIA)
========================================================================================
    Runs Proteina-Complexa for de novo protein binder backbone design.
    Downstream steps (ProteinMPNN, Boltz-2, analysis) consume the normalised
    budget_design_cifs channel regardless of which design tool was used.
*/

include { PROTEINA_COMPLEXA_RUN } from '../../modules/local/proteina_complexa_run'

workflow DESIGN_PROTEINA_COMPLEXA {

    take:
    ch_input  // [meta, design_yaml, structure_files]
    ch_cache  // path to cache directory (model weights) or EMPTY_CACHE placeholder

    main:

    PROTEINA_COMPLEXA_RUN(ch_input, ch_cache)

    // Sort by filename (natural design order) and take only the budget number of designs
    ch_budget_pdbs = PROTEINA_COMPLEXA_RUN.out.raw_pdbs
        .map { meta, pdbs ->
            def sorted = (pdbs instanceof List ? pdbs : [pdbs]).sort { it.name }
            [meta, sorted.take(meta.budget as Integer)]
        }

    emit:
    results            = PROTEINA_COMPLEXA_RUN.out.results
    budget_design_cifs = ch_budget_pdbs
}
