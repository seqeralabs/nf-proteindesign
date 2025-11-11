# Pipeline Workflow Modes

The nf-proteindesign pipeline supports two distinct workflow modes, automatically detected based on your input samplesheet format.

## Quick Mode Selection

| I have... | Use Mode | Samplesheet Column |
|-----------|----------|-------------------|
| 🎯 **Target structure** (want to explore designs) | **TARGET-BASED** | `target_structure` |
| 📄 **Design YAML files** (know exactly what I want) | **DESIGN-BASED** | `design_yaml` |

---

## Mode 1: TARGET-BASED 🎯

**Use when**: You have a target structure and want to explore multiple design strategies automatically.

### Key Features
- ✅ Automatic generation of diverse design specifications
- ✅ Length variation strategies
- ✅ Multiple variants per configuration
- ✅ High-throughput exploration
- ✅ Parallel execution of all designs

### Input Format
```csv
sample_id,target_structure,target_chain_ids,min_length,max_length,length_step,n_variants_per_length,design_type,protocol,num_designs,budget
egfr_binder,data/egfr.cif,A,60,120,20,3,protein,protein-anything,100,10
```

### What Happens
1. Pipeline reads your target structure
2. Generates multiple design YAML files (e.g., 12 variants: 4 lengths × 3 variants each)
3. Runs Boltzgen on all designs in parallel
4. Collects and organizes all results

### Example Command
```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --input target_samplesheet.csv \
    --min_design_length 60 \
    --max_design_length 140 \
    --length_step 20 \
    --n_variants_per_length 5 \
    --outdir results
```

### Output Structure
```
results/
└── egfr_binder/
    ├── design_variants/                    # Generated YAMLs
    │   ├── egfr_binder_len60_v1.yaml
    │   ├── egfr_binder_len80_v1.yaml
    │   └── ...
    ├── design_info.txt                     # Summary
    ├── egfr_binder_len60_v1/               # Results per design
    ├── egfr_binder_len80_v1/
    └── ...
```

### Best For
- 🔬 Initial exploration of design space
- 📊 Screening different binder sizes
- 🚀 High-throughput design campaigns
- 🎲 When unsure of optimal parameters

---

## Mode 2: DESIGN-BASED 📄

**Use when**: You have pre-made design YAML files with specific requirements.

### Key Features
- ✅ Full control over design specifications
- ✅ Use any Boltzgen YAML format
- ✅ Custom constraints and interfaces
- ✅ Parallel execution of multiple designs
- ✅ Reusable design templates

### Input Format
```csv
sample_id,design_yaml,protocol,num_designs,budget
protein_binder,designs/my_protein_design.yaml,protein-anything,100,10
peptide_binder,designs/my_peptide_design.yaml,peptide-anything,100,10
```

### What Happens
1. Pipeline reads your design YAML files directly
2. Validates that all files exist
3. Runs Boltzgen on each design in parallel
4. Collects results per sample

### Example Command
```bash
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --input samplesheet.csv \
    --num_designs 1000 \
    --budget 20 \
    --outdir results
```

### Output Structure
```
results/
├── protein_binder/
│   ├── intermediate_designs/
│   ├── intermediate_designs_inverse_folded/
│   ├── final_ranked_designs/
│   └── predictions/
└── peptide_binder/
    ├── intermediate_designs/
    ├── ...
```

### Best For
- 🎯 Specific design requirements
- 🔧 Custom constraints and interfaces
- 📚 Reusing successful design templates
- 🎨 Complex multi-entity systems

---

## Side-by-Side Comparison

| Aspect | TARGET-BASED | DESIGN-BASED |
|--------|--------------|--------------|
| **Setup time** | ⚡ Fast (1 CSV line) | 🔧 Longer (write YAMLs) |
| **Control** | 🎲 Automated | 🎯 Full manual control |
| **Design count** | 📈 Many (automatic) | 📊 As many as you write |
| **Customization** | ⚙️ Parameters | 🎨 Full YAML spec |
| **Learning curve** | 🟢 Easy | 🟡 Moderate |
| **Best for** | Exploration | Specific goals |
| **Reproducibility** | 🔄 Generated YAMLs saved | ✅ YAMLs provided |
| **Flexibility** | 🎯 Length & type | 🌟 Everything |

---

## Automatic Mode Detection

The pipeline automatically detects which mode to use:

```groovy
// Checks samplesheet headers
target_structure column found → TARGET-BASED MODE
design_yaml column found → DESIGN-BASED MODE
Neither found → ERROR
```

You'll see a clear message at pipeline start:
```
========================================
Running in TARGET-BASED MODE
========================================
Input targets will be used to generate
diversified design specifications, then
all designs will run in parallel.
========================================
```

---

## Switching Between Modes

### From Design-Based to Target-Based
If you have existing YAMLs but want to explore more:
1. Extract target structure path from your YAML
2. Create target samplesheet
3. Run with new parameters

### From Target-Based to Design-Based
If you found good parameters and want more control:
1. Find generated YAMLs in `design_variants/`
2. Edit/refine them as needed
3. Create design samplesheet pointing to edited YAMLs
4. Run in design-based mode

---

## Combining Both Modes

You can run both modes in separate pipeline runs and compare results:

```bash
# 1. Exploration phase (Target-based)
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --input targets.csv \
    --outdir results/exploration

# 2. Review generated designs in results/exploration/*/design_variants/

# 3. Refinement phase (Design-based)
# Edit best designs, create new samplesheet
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --input refined_designs.csv \
    --num_designs 10000 \
    --budget 50 \
    --outdir results/refined
```

---

## Common Workflows

### Workflow A: Complete Exploration
```
Target Structure
       ↓
  TARGET-BASED MODE (exploration)
       ↓
  Review Results
       ↓
  Select Best Parameters
       ↓
  TARGET-BASED MODE (production)
```

### Workflow B: Targeted Refinement
```
Target Structure
       ↓
  TARGET-BASED MODE (quick screen)
       ↓
  Find Promising Length/Type
       ↓
  Edit Generated YAMLs
       ↓
  DESIGN-BASED MODE (high quality)
```

### Workflow C: Template Development
```
Manual YAML Design
       ↓
  DESIGN-BASED MODE (test)
       ↓
  Optimize Template
       ↓
  Apply to Multiple Targets
       ↓
  DESIGN-BASED MODE (batch)
```

---

## Quick Decision Tree

```
Do you have pre-written design YAML files?
│
├─ YES → Use DESIGN-BASED mode
│         (samplesheet with 'design_yaml' column)
│
└─ NO → Do you want to explore multiple designs?
        │
        ├─ YES → Use TARGET-BASED mode
        │         (samplesheet with 'target_structure' column)
        │
        └─ NO → Write a YAML first, then use DESIGN-BASED mode
```

---

## Performance Considerations

### TARGET-BASED Mode
- **Generates**: N designs = (length variations) × (variants per length)
- **Parallelization**: All N designs run in parallel (GPU-limited)
- **Disk usage**: N × ~2-5GB per design
- **Time**: Depends on GPU count and `num_designs` parameter

### DESIGN-BASED Mode
- **Processes**: Exactly the YAMLs you provide
- **Parallelization**: All designs run in parallel (GPU-limited)
- **Disk usage**: Depends on your design count
- **Time**: More predictable (you control design count)

---

## Getting Started

### For Beginners
Start with **TARGET-BASED** mode:
```bash
# Create simple samplesheet
echo "sample_id,target_structure,design_type" > test.csv
echo "test1,my_target.cif,protein" >> test.csv

# Run with defaults
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --input test.csv
```

### For Advanced Users
Use **DESIGN-BASED** mode with custom YAMLs:
```bash
# Use your carefully crafted designs
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --input my_designs.csv \
    --num_designs 60000 \
    --budget 100
```

---

## Additional Resources

- **Target-Based Mode Details**: See [`TARGET_BASED_MODE.md`](TARGET_BASED_MODE.md)
- **Design YAML Format**: See [Boltzgen documentation](https://github.com/HannesStark/boltzgen)
- **Examples**: Check `assets/design_examples/` and `assets/samplesheet_example.csv`
- **Parameters**: Full list in `nextflow.config`
