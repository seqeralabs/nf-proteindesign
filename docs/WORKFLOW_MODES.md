# Pipeline Workflow Modes

The nf-proteindesign pipeline features a **unified workflow architecture** with three distinct modes that all converge into a single execution path. Modes can be specified explicitly with `--mode` or auto-detected from your samplesheet format.

## Quick Mode Selection

| I have... | Mode | Parameter | Samplesheet Column |
|-----------|------|-----------|-------------------|
| 🎯 **Target structure** (explore designs) | **TARGET** | `--mode target` | `target_structure` |
| 📄 **Design YAML files** (know what I want) | **DESIGN** | `--mode design` | `design_yaml` |
| 🔬 **Target + binding site prediction** | **P2RANK** | `--mode p2rank` | `target_structure` + `--use_p2rank` |

---

## Unified Workflow Architecture

All three modes share the same core workflow (`PROTEIN_DESIGN`) but with different entry points:

```
Design Mode    ──┐
                 ├──> Unified Workflow ──> Boltzgen ──> IPSAE (optional) ──> Results
Target Mode    ──┤
                 │
P2Rank Mode    ──┘
```

**Benefits:**
- ✅ Consistent execution across all modes
- ✅ Simplified maintenance and testing
- ✅ Easy to switch between modes
- ✅ All modes benefit from improvements
- ✅ Unified output structure

---

## Mode 1: TARGET 🎯

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
# Explicit mode specification
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --mode target \
    --input target_samplesheet.csv \
    --min_design_length 60 \
    --max_design_length 140 \
    --length_step 20 \
    --n_variants_per_length 5 \
    --outdir results

# Auto-detection (if samplesheet has target_structure column)
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --input target_samplesheet.csv \
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

## Mode 2: DESIGN 📄

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
# Explicit mode specification
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --mode design \
    --input samplesheet.csv \
    --num_designs 1000 \
    --budget 20 \
    --outdir results

# Auto-detection (if samplesheet has design_yaml column)
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --input samplesheet.csv \
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

## Mode 3: P2RANK 🔬

**Use when**: You want to automatically identify binding sites and design binders without prior knowledge.

### Key Features
- ✅ Machine learning binding site prediction
- ✅ Automatic pocket identification
- ✅ No manual site specification needed
- ✅ Multiple pockets targeted simultaneously
- ✅ Fast and accurate

### Input Format
Same as target mode - uses `target_structure` column:
```csv
sample_id,target_structure,top_n_pockets,min_pocket_score,protocol,num_designs,budget
protein1,data/protein1.cif,3,0.5,protein-anything,100,10
```

### What Happens
1. P2Rank identifies top binding sites in target
2. Creates design YAMLs for each predicted pocket
3. All designs enter unified workflow
4. Boltzgen generates binders for each site
5. Results organized by target and pocket

### Example Command
```bash
# Explicit mode specification
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --mode p2rank \
    --input targets.csv \
    --top_n_pockets 3 \
    --outdir results

# Via --use_p2rank parameter (auto-detects)
nextflow run FloWuenne/nf-proteindesign-2025 \
    -profile docker \
    --input targets.csv \
    --use_p2rank \
    --top_n_pockets 3 \
    --outdir results
```

### Output Structure
```
results/
└── protein1/
    ├── p2rank_predictions/              # P2Rank output
    ├── binding_sites/                   # Generated YAMLs
    │   ├── protein1_pocket1.yaml
    │   ├── protein1_pocket2.yaml
    │   └── protein1_pocket3.yaml
    ├── pocket_summary.csv               # Pocket details
    ├── protein1_pocket1/                # Designs per pocket
    ├── protein1_pocket2/
    └── protein1_pocket3/
```

### Best For
- 🔬 Drug discovery campaigns
- 🎯 Unknown binding sites
- 📊 High-throughput screening
- 🚀 Automated workflows

---

## Side-by-Side Comparison

| Aspect | DESIGN | TARGET | P2RANK |
|--------|--------|--------|--------|
| **Setup time** | 🔧 Longer (write YAMLs) | ⚡ Fast (1 CSV line) | ⚡ Fast (1 CSV line) |
| **Control** | 🎯 Full manual control | 🎲 Automated | 🤖 ML-automated |
| **Design count** | 📊 As many as you write | 📈 Many (automatic) | 📈 Per pocket (auto) |
| **Customization** | 🎨 Full YAML spec | ⚙️ Parameters | ⚙️ Parameters + ML |
| **Learning curve** | 🟡 Moderate | 🟢 Easy | 🟢 Easy |
| **Best for** | Specific goals | Exploration | Drug discovery |
| **Binding sites** | ✍️ Manual specify | ✍️ Manual specify | 🤖 Auto-predicted |
| **Reproducibility** | ✅ YAMLs provided | 🔄 Generated YAMLs | 🔄 Generated YAMLs |
| **Flexibility** | 🌟 Everything | 🎯 Length & type | 🎯 Pockets + type |

---

## Mode Selection

### Option 1: Explicit Mode (Recommended)
Specify mode explicitly with `--mode` parameter:
```bash
--mode design   # Use pre-made design YAMLs
--mode target   # Generate design variants
--mode p2rank   # Auto-identify binding sites
```

### Option 2: Auto-Detection
The pipeline can auto-detect mode from your samplesheet:

```
Samplesheet Headers → Mode Detection Logic
==========================================
design_yaml column               → DESIGN mode
target_structure column          → TARGET mode
target_structure + --use_p2rank  → P2RANK mode
```

### Mode Confirmation
You'll see a clear message at pipeline start:
```
========================================
Running in TARGET MODE
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
