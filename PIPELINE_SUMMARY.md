# Pipeline Summary: nf-proteindesign

## Overview
Production-ready Nextflow DSL2 pipeline for Boltzgen protein design with parallel sample processing.

## Key Features
✅ Samplesheet-based input for parallel processing
✅ GPU-optimized configuration (Docker & Singularity)
✅ Multiple Boltzgen protocols supported
✅ Per-sample parameterization
✅ Automatic result organization
✅ Comprehensive documentation

## Pipeline Structure

### Main Components
- **main.nf**: Workflow orchestration with DSL2 syntax
- **modules/local/boltzgen_run.nf**: Core Boltzgen execution process
- **modules/local/validate_samplesheet.nf**: Input validation
- **nextflow.config**: Main configuration with GPU settings
- **conf/base.config**: Process resource definitions
- **conf/test.config**: Minimal test configuration

### Documentation
- **README.md**: Complete pipeline overview and reference
- **USAGE.md**: Detailed step-by-step usage guide (508 lines)
- **QUICKSTART.md**: 5-minute getting started guide
- **LICENSE**: MIT License

### Examples
- **assets/samplesheet_example.csv**: Example input file
- **assets/design_examples/protein_design.yaml**: Protein binder design
- **assets/design_examples/peptide_design.yaml**: Peptide design with binding site
- **assets/design_examples/nanobody_design.yaml**: Nanobody design

## Technical Details

### GPU Configuration
- **Docker**: `--gpus all` flag for GPU access
- **Singularity**: `--nv` flag for NVIDIA GPU support
- **Process label**: `process_high_gpu` with accelerator=1
- **Default resources**: 8 CPUs, 64GB RAM, 48h time, 1 GPU

### Supported Protocols
1. **protein-anything**: Standard protein binder design
2. **peptide-anything**: Peptide/cyclic peptide design
3. **protein-small_molecule**: Small molecule binding
4. **nanobody-anything**: Nanobody design

### Parameters
**Required:**
- `--input`: Samplesheet CSV path

**Configuration:**
- `--protocol`: Default protocol (default: protein-anything)
- `--num_designs`: Intermediate designs count (default: 100)
- `--budget`: Final design count (default: 10)
- `--cache_dir`: Model cache directory (~6GB)
- `--boltzgen_config`: Custom config override
- `--steps`: Pipeline steps to run

**Resources:**
- `--max_memory`: 128.GB default
- `--max_cpus`: 16 default
- `--max_time`: 240.h default
- `--max_gpus`: 1 default

### Samplesheet Format
```csv
sample_id,design_yaml,protocol,num_designs,budget,reuse
exp1,design1.yaml,protein-anything,10000,20,false
exp2,design2.yaml,peptide-anything,5000,10,false
```

**Columns:**
- `sample_id` (required): Unique identifier
- `design_yaml` (required): Path to Boltzgen design YAML
- `protocol` (optional): Override default protocol
- `num_designs` (optional): Override default num_designs
- `budget` (optional): Override default budget
- `reuse` (optional): Reuse previous results (true/false)

### Output Structure
```
results/
├── pipeline_info/              # Execution reports
└── {sample_id}/
    └── {sample_id}_output/
        ├── config/             # Run configuration
        ├── intermediate_designs/
        ├── intermediate_designs_inverse_folded/
        │   ├── refold_cif/    # Main structures
        │   └── metrics files
        └── final_ranked_designs/
            ├── final_{budget}_designs/  # ⭐ Main results
            ├── metrics files
            └── results_overview.pdf
```

## Example Usage

### Test Run
```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --input samplesheet.csv \
    --outdir results \
    --num_designs 10 \
    --budget 2
```

### Production Run
```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --input samplesheet.csv \
    --outdir results \
    --num_designs 20000 \
    --budget 50 \
    --cache_dir /shared/cache
```

### HPC with Singularity
```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile singularity \
    --input samplesheet.csv \
    --outdir results \
    --max_memory 256.GB \
    --max_time 168.h
```

## Important Notes

### GPU Requirement
⚠️ **Boltzgen REQUIRES GPU (CUDA)**
- Cannot run on CPU-only systems
- Tested on NVIDIA A100
- Requires CUDA-compatible drivers
- Container engine must support GPU passthrough

### Performance
- **Per design timing** (A100 GPU): ~10-20 seconds
- **Recommended num_designs**: 10,000-60,000 for production
- **Test runs**: Use 10-50 designs first
- **Filtering**: ~15 seconds, can be rerun quickly

### Design Workflow
1. Create design YAML specifications
2. Validate with `boltzgen check design.yaml`
3. Create samplesheet with all experiments
4. Run pipeline with test parameters
5. Scale up to production parameters
6. Rerun filtering with different settings if needed

## File Inventory

### Core Pipeline Files
- main.nf (75 lines)
- nextflow.config (163 lines)
- conf/base.config (71 lines)
- conf/test.config (27 lines)
- modules/local/boltzgen_run.nf (58 lines)
- modules/local/validate_samplesheet.nf (69 lines)

### Documentation Files
- README.md (305 lines)
- USAGE.md (508 lines)
- QUICKSTART.md (190 lines)
- LICENSE (22 lines)
- .gitignore (35 lines)

### Example Files
- assets/samplesheet_example.csv
- assets/design_examples/protein_design.yaml (19 lines)
- assets/design_examples/peptide_design.yaml (29 lines)
- assets/design_examples/nanobody_design.yaml (28 lines)

**Total:** 12 pipeline files + 6 documentation files + 4 example files

## Testing Checklist

- [ ] GPU access configured (docker/singularity)
- [ ] Nextflow >= 23.04.0 installed
- [ ] Test run with small num_designs
- [ ] Design YAML validated with boltzgen check
- [ ] Samplesheet format correct
- [ ] Output directory has write permissions
- [ ] Sufficient disk space for results

## Credits
- **Pipeline**: Florian Wuennemann
- **Boltzgen**: MIT Jameel Clinic and collaborators
- **License**: MIT

## Next Steps
1. Review QUICKSTART.md for immediate use
2. Read USAGE.md for detailed instructions
3. Check example designs in assets/
4. Join Boltzgen Slack for support
