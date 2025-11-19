# Production Test Profile - Quick Summary

## What Was Added

A new test profile `test_production` that simulates a realistic production-scale protein binder design run.

## Files Created

1. **`conf/test_production.config`** - Profile configuration
2. **`assets/test_data/samplesheet_production_test.csv`** - Production samplesheet
3. **`assets/test_data/egfr_protein_production.yaml`** - Realistic design specification
4. **`TEST_PRODUCTION_PROFILE.md`** - Comprehensive documentation

## Files Modified

1. **`nextflow.config`** - Added test_production profile
2. **`README.md`** - Updated test profiles section

## Key Parameters

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| **num_designs** | 10,000 | Production-scale intermediate designs |
| **budget** | 10 | Final diversity-optimized candidates |
| **protocol** | protein-anything | Therapeutic protein binder development |
| **binder_length** | 90-130 aa | Realistic binding domain sizes |
| **target** | EGFR kinase (1IVO) | Well-characterized therapeutic target |

## Resources

- **CPU**: 8 cores (vs 2 in test profiles)
- **Memory**: 32 GB (vs 6 GB in test profiles)
- **GPU**: 1 NVIDIA GPU
- **Runtime**: ~6-8 hours (vs ~20 min for test_design)

## Quick Start

```bash
# Run the production test
nextflow run seqeralabs/nf-proteindesign -profile test_production,docker

# With custom output
nextflow run seqeralabs/nf-proteindesign \
    -profile test_production,docker \
    --outdir my_production_test

# Resume from checkpoint
nextflow run seqeralabs/nf-proteindesign \
    -profile test_production,docker \
    -resume
```

## What It Tests

✅ **Full production workflow** with 10,000 designs  
✅ **All metrics modules** (ProteinMPNN, ipSAE, PRODIGY)  
✅ **Realistic resource utilization** (8 CPU, 32GB RAM, 1 GPU)  
✅ **Complete output generation** and file organization  
✅ **Consolidated reporting** functionality  
✅ **Production parameter validation**  

## Expected Output

```
results_test_production/
└── egfr_protein_production/
    ├── boltzgen/
    │   ├── intermediate_designs/     # 10,000 designs
    │   ├── filtered_designs/         # Quality filtered
    │   └── final_ranked_designs/     # Top 10
    ├── proteinmpnn/                  # 80 sequences (10 × 8)
    ├── ipsae/                        # Interface scores
    ├── prodigy/                      # Affinity predictions
    └── consolidated_metrics/         # Summary CSV
```

## Comparison with Other Tests

| Profile | Designs | Budget | Runtime | Purpose |
|---------|---------|--------|---------|---------|
| test_design | 10 | 2 | 20 min | Quick validation |
| test_target | 10 | 2 | 45 min | Auto-generation |
| **test_production** | **10,000** | **10** | **6-8 hrs** | **Production validation** |

## Why This Matters

1. **Realistic testing**: Validates pipeline at production scale
2. **Resource planning**: Determines actual resource needs
3. **Performance profiling**: Identifies bottlenecks before production
4. **Quality validation**: Tests all metrics at scale
5. **Pre-deployment check**: Final validation before real production runs

## Next Steps

1. Run the test: `nextflow run main.nf -profile test_production,docker`
2. Monitor execution: `watch nvidia-smi` 
3. Review results in `results_test_production/`
4. Check execution reports in `pipeline_info/`
5. Use learnings to configure your production runs

---

**Questions?** See detailed documentation in `TEST_PRODUCTION_PROFILE.md`
