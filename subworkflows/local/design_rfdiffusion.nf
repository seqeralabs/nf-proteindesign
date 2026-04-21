/*
========================================================================================
    DESIGN_RFDIFFUSION: Backbone design using RFdiffusion3
========================================================================================
    Runs RFdiffusion3 (rfd3 via RosettaCommons Foundry) for backbone design.
    Downstream steps (ProteinMPNN, Boltz-2, analysis) consume the normalised
    budget_design_cifs channel regardless of which design tool was used.
*/

include { RFDIFFUSION_V3_RUN } from '../../modules/local/rfdiffusion_v3_run'

workflow DESIGN_RFDIFFUSION {

    take:
    ch_input  // [meta, design_yaml, structure_files]
    ch_cache  // path to cache directory or EMPTY_CACHE placeholder

    main:

    RFDIFFUSION_V3_RUN(ch_input, ch_cache)

    emit:
    results            = RFDIFFUSION_V3_RUN.out.results
    budget_design_cifs = RFDIFFUSION_V3_RUN.out.budget_design_cifs
}
