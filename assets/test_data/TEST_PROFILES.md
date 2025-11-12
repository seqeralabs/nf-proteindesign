# Test Profiles Documentation

This directory contains comprehensive test data and configurations for testing all three modes of the nf-proteindesign pipeline using EGFR (PDB: 1IVO) as the example target.

## Test Data

### EGFR Structure (1IVO)
- **File**: `1IVO.cif`
- **Description**: EGFR kinase domain crystal structure
- **Chains**: 
  - Chain A: EGFR kinase domain (~500 residues)
  - Chain B: EGFR kinase domain (second copy in asymmetric unit)
  - Chain C: Peptide ligand
  - Chain D: Peptide ligand
- **Resolution**: High-resolution crystal structure suitable for design

## Test Profiles

### 1. Design Mode Test (`test_design`)

**Purpose**: Test the design mode using pre-made Boltzgen YAML configuration files.

**Command**:
```bash
nextflow run main.nf -profile test_design,docker
```

**Input**: `samplesheet_design_test.csv`

**Test Samples**:
1. **egfr_protein_binder**: Designs an 80-120 residue protein to bind EGFR chain A
   - Config: `egfr_protein_design.yaml`
   - Protocol: protein-anything
   
2. **egfr_peptide_binder**: Designs a 12-25 residue peptide targeting specific EGFR active site residues
   - Config: `egfr_peptide_design.yaml`
   - Protocol: peptide-anything
   - Target residues: 721, 726, 730, 768, 790, 831 (key active site residues)
   
3. **egfr_nanobody_binder**: Designs a 110-130 residue nanobody against EGFR
   - Config: `egfr_nanobody_design.yaml`
   - Protocol: nanobody-anything

**Output**: `./results_test_design`

---

### 2. Target Mode Test (`test_target`)

**Purpose**: Test the target mode with automated design YAML generation from target structure.

**Command**:
```bash
nextflow run main.nf -profile test_target,docker
```

**Input**: `samplesheet_target_test.csv`

**Test Samples**:
1. **egfr_target_protein**: Auto-generates protein designs of varying lengths (80, 100, 120 residues)
   - Target: EGFR chain A
   - Lengths: 80-120 (step 20)
   - Variants per length: 2
   
2. **egfr_target_peptide**: Auto-generates peptide designs (12, 18, 25 residues)
   - Target: EGFR chain A
   - Lengths: 12-25 (step 6)
   - Variants per length: 2
   
3. **egfr_target_nanobody**: Auto-generates nanobody designs (110, 120, 130 residues)
   - Target: EGFR chain A
   - Lengths: 110-130 (step 10)
   - Variants per length: 2

**Output**: `./results_test_target`

---

### 3. P2Rank Mode Test (`test_p2rank`)

**Purpose**: Test the P2Rank mode with automated binding site prediction and design generation.

**Command**:
```bash
nextflow run main.nf -profile test_p2rank,docker
```

**Input**: `samplesheet_p2rank_test.csv`

**Test Samples**:
1. **egfr_p2rank_protein**: Uses P2Rank to identify top 3 binding pockets, designs protein binders
   - Target: EGFR structure
   - P2Rank settings: top 3 pockets, score threshold 0.5
   - Design type: protein (80-120 residues)
   
2. **egfr_p2rank_peptide**: Uses P2Rank to identify top 2 pockets, designs peptide binders
   - Target: EGFR structure
   - P2Rank settings: top 2 pockets, score threshold 0.5
   - Design type: peptide (12-25 residues)
   
3. **egfr_p2rank_nanobody**: Uses P2Rank to identify top 3 pockets, designs nanobody binders
   - Target: EGFR structure
   - P2Rank settings: top 3 pockets, score threshold 0.5
   - Design type: nanobody (110-130 residues)

**Output**: `./results_test_p2rank`

---

## Test Configuration Summary

All test profiles use minimal resource settings for fast execution:
- **num_designs**: 10 (vs 10,000-60,000 for production)
- **budget**: 2 (vs 10+ for production)
- **max_cpus**: 2
- **max_memory**: 6 GB
- **max_time**: 6 hours
- **max_gpus**: 1

## File Structure

```
assets/test_data/
├── TEST_PROFILES.md                    # This file
├── 1IVO.cif                            # EGFR structure
├── egfr_protein_design.yaml            # Protein binder design spec
├── egfr_peptide_design.yaml            # Peptide binder design spec
├── egfr_nanobody_design.yaml           # Nanobody design spec
├── samplesheet_design_test.csv         # Design mode samplesheet
├── samplesheet_target_test.csv         # Target mode samplesheet
└── samplesheet_p2rank_test.csv         # P2Rank mode samplesheet
```

## Expected Outputs

Each test profile will generate:
1. **Design YAML files**: Boltzgen configuration files (auto-generated for target/p2rank modes)
2. **Generated structures**: PDB files of designed binders
3. **Filtering results**: Diversity-optimized final design set
4. **Pipeline reports**: Execution timeline, resource usage, etc.

## Running Production Designs

To run production-quality designs, modify the test samplesheets with:
- `num_designs`: 10000-60000 (more intermediate designs)
- `budget`: 10-50 (larger final diversity set)
- Increase max_memory and max_time as needed

Example:
```bash
# Copy and modify a test samplesheet
cp assets/test_data/samplesheet_design_test.csv my_production_designs.csv
# Edit num_designs and budget values

# Run with more resources
nextflow run main.nf \
  -profile docker \
  --input my_production_designs.csv \
  --num_designs 10000 \
  --budget 10 \
  --outdir results_production
```

## Validation

These test profiles validate:
- ✅ All three pipeline modes (design, target, p2rank)
- ✅ All three design types (protein, peptide, nanobody)
- ✅ Multiple samples processed in parallel
- ✅ Automated design YAML generation
- ✅ P2Rank binding site prediction
- ✅ Length variation handling
- ✅ Real PDB structure processing

## Troubleshooting

If tests fail, check:
1. Docker/Singularity container accessibility
2. GPU availability (required for Boltzgen)
3. Internet connectivity (for downloading models on first run)
4. Cache directory permissions (~/.cache for model weights)

For more information, see the main pipeline documentation.
