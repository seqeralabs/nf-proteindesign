# Production-Scale Test Profile

## Overview

The `test_production` profile validates the complete production workflow with realistic parameters, testing a full-scale protein binder design run against EGFR (PDB: 1IVO).

## Key Features

### Production Parameters
- **Intermediate Designs**: 10,000 (representative of production scale)
- **Final Budget**: 10 diversity-optimized designs
- **Protocol**: `protein-anything` for therapeutic protein binder development
- **Target**: EGFR kinase domain (established therapeutic target)

### Realistic Design Specification
The production YAML (`egfr_protein_production.yaml`) includes:
- **Binder Length**: 90-130 amino acids
  - Covers small binding proteins (90-100 aa)
  - Medium domains (100-120 aa)
  - Larger single-domain binders (120-130 aa)
- **Target Region**: Complete EGFR kinase domain (chain A)
- **Design Constraints**: Geometry and stability optimization

### Comprehensive Metrics Pipeline
All analysis modules enabled to validate production workflow:
- ✅ **ProteinMPNN**: 8 sequence variants per structure (full default)
- ✅ **ipSAE**: Protein-protein interface quality scoring
- ✅ **PRODIGY**: Binding affinity prediction (ΔG and Kd)
- ✅ **Consolidated Metrics**: Unified quality report

### Resource Configuration
Realistic production-level resources:
- **CPU**: 8 cores
- **Memory**: 32 GB
- **GPU**: 1 NVIDIA GPU with CUDA
- **Time**: 24 hours maximum

## Usage

### Basic Run
```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile test_production,docker
```

### With Custom Output Directory
```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile test_production,docker \
    --outdir my_production_test
```

### Resume from Checkpoint
```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile test_production,docker \
    -resume
```

## Expected Runtime

| Stage | Approximate Duration |
|-------|---------------------|
| Boltzgen Design | 4-6 hours |
| ProteinMPNN | 30-60 minutes |
| ipSAE Scoring | 15-30 minutes |
| PRODIGY Prediction | 10-20 minutes |
| Consolidation | 5-10 minutes |
| **Total** | **~6-8 hours** |

*Runtime varies based on GPU model and system specifications*

## Files Created

### New Configuration Files
1. **`conf/test_production.config`**
   - Profile configuration with production parameters
   - Resource settings and metrics modules

2. **`assets/test_data/samplesheet_production_test.csv`**
   - Samplesheet with production parameters
   - Links to production YAML and structure files

3. **`assets/test_data/egfr_protein_production.yaml`**
   - Realistic production design specification
   - EGFR kinase domain targeting
   - 90-130 aa binder length range

### Modified Files
1. **`nextflow.config`**
   - Added `test_production` profile entry

2. **`README.md`**
   - Added production test profile documentation
   - Comparison table of all test profiles

## Output Structure

```
results_test_production/
├── egfr_protein_production/
│   ├── boltzgen/
│   │   ├── intermediate_designs/     # All 10,000 designs
│   │   ├── filtered_designs/         # Filtered by quality
│   │   └── final_ranked_designs/     # Top 10 budget designs
│   ├── proteinmpnn/
│   │   └── sequences/                # 80 sequences (10 designs × 8 variants)
│   ├── ipsae/
│   │   └── scores/                   # Interface quality metrics
│   ├── prodigy/
│   │   └── predictions/              # Binding affinity predictions
│   └── consolidated_metrics/
│       └── egfr_protein_production_metrics_summary.csv
└── pipeline_info/
    ├── execution_timeline.html
    ├── execution_report.html
    └── execution_trace.txt
```

## Validation Checklist

Use this test to validate:
- ✅ GPU acceleration works correctly
- ✅ Large-scale design generation (10k designs)
- ✅ Memory management for production volumes
- ✅ Complete metrics pipeline integration
- ✅ Output file organization and naming
- ✅ Resource utilization and efficiency
- ✅ Consolidated reporting functionality

## Comparison with Other Test Profiles

| Aspect | test_design | test_target | test_production |
|--------|-------------|-------------|-----------------|
| **Purpose** | Quick validation | Auto-generation test | Production validation |
| **Designs** | 10 | 10 | 10,000 |
| **Budget** | 2 | 2 | 10 |
| **Runtime** | ~20 min | ~45 min | ~6-8 hours |
| **CPU** | 2 | 2 | 8 |
| **Memory** | 6 GB | 6 GB | 32 GB |
| **ProteinMPNN** | 2 seq/target | 2 seq/target | 8 seq/target |
| **Use Case** | CI/CD testing | Feature testing | Pre-deployment validation |

## Production Deployment Notes

After successful `test_production` run:
1. **Verify outputs**: Check all metrics files are generated
2. **Review metrics**: Examine consolidated report for quality indicators
3. **Resource profiling**: Use execution reports to optimize production resources
4. **Scale up**: Apply learned parameters to full production datasets
5. **Monitor**: Set up appropriate monitoring for production runs

## Troubleshooting

### GPU Not Available
```bash
# Check GPU status
nvidia-smi

# Verify Docker GPU access
docker run --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi
```

### Out of Memory
If OOM errors occur:
- Increase `max_memory` in config
- Reduce `mpnn_batch_size` if ProteinMPNN fails
- Check GPU memory with `nvidia-smi`

### Long Runtime
Expected for production scale, but to optimize:
- Ensure GPU is properly utilized (check `nvidia-smi` during run)
- Use `-resume` to restart from checkpoints
- Consider parallel execution for multiple samples

## Design Rationale

This test profile was designed to:
1. **Simulate real production**: 10,000 designs is typical for production binder discovery
2. **Test scalability**: Validates pipeline handles large design volumes
3. **Verify metrics**: Ensures all analysis modules work at scale
4. **Realistic resources**: Production-level CPU/GPU/memory settings
5. **Single sample**: Tests complete workflow without parallelization complexity

The parameters chosen (10,000 designs, budget of 10) represent a realistic production scenario for therapeutic protein binder development, where:
- Large design space exploration is needed (10k designs)
- Final selection focuses on top diverse candidates (budget: 10)
- Complete quality assessment is critical (all metrics enabled)
- Computational resources match typical HPC/cloud configurations

## Next Steps

1. **Run the test**:
   ```bash
   nextflow run main.nf -profile test_production,docker
   ```

2. **Monitor execution**:
   - Watch GPU utilization: `nvidia-smi -l 1`
   - Check progress in work directory

3. **Analyze results**:
   - Review consolidated metrics CSV
   - Examine execution reports in `pipeline_info/`
   - Validate output structures and sequences

4. **Adapt for production**:
   - Adjust parameters based on test results
   - Scale resources for multiple parallel samples
   - Configure appropriate storage for large outputs
