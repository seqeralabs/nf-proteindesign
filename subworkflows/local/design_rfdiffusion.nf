/*
========================================================================================
    DESIGN_RFDIFFUSION: Backbone design using RFdiffusion v1 or v3
========================================================================================
    Version is selected via params.design_tool:
      'rfdiffusion_v1' -> RFDIFFUSION_V1_RUN (run_inference.py, standalone repo)
      'rfdiffusion_v3' -> RFDIFFUSION_V3_RUN (rfd3 via RosettaCommons Foundry)

    Both modules emit identically-shaped output channels so downstream processes
    (ProteinMPNN, Boltz-2, analysis) are unaffected by which version is used.
*/

include { RFDIFFUSION_V1_RUN } from '../../modules/local/rfdiffusion_v1_run'
include { RFDIFFUSION_V3_RUN } from '../../modules/local/rfdiffusion_v3_run'

workflow DESIGN_RFDIFFUSION {

    take:
    ch_input  // [meta, design_yaml, structure_files]
    ch_cache  // path to cache directory or EMPTY_CACHE placeholder

    main:

    if (params.design_tool == 'rfdiffusion_v1') {
        RFDIFFUSION_V1_RUN(ch_input, ch_cache)
        ch_results            = RFDIFFUSION_V1_RUN.out.results
        ch_budget_design_cifs = RFDIFFUSION_V1_RUN.out.budget_design_cifs
    } else {
        // default: rfdiffusion_v3
        RFDIFFUSION_V3_RUN(ch_input, ch_cache)
        ch_results            = RFDIFFUSION_V3_RUN.out.results
        ch_budget_design_cifs = RFDIFFUSION_V3_RUN.out.budget_design_cifs
    }

    emit:
    results            = ch_results
    budget_design_cifs = ch_budget_design_cifs
}
