# CIF File Staging Architecture

## Complete Data Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          SAMPLESHEET INPUT                               │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                    ┌───────────────┼───────────────┐
                    │               │               │
            ┌───────▼─────┐  ┌──────▼──────┐  ┌────▼────────┐
            │ DESIGN MODE │  │ TARGET MODE │  │ P2RANK MODE │
            └─────────────┘  └─────────────┘  └─────────────┘
```

## Mode-Specific Flows

### 1. DESIGN MODE (User-Provided YAMLs)

```
Samplesheet:
sample_id,design_yaml,structure_files,protocol,num_designs,budget
my_design,design.yaml,1IVO.cif,protein-anything,100,10

                    ↓
        ┌──────────────────────────┐
        │  Parse Samplesheet       │
        │  [meta, yaml, [cifs]]    │
        └───────────┬──────────────┘
                    │
                    │ NO PROCESSING - Direct pass
                    │
        ┌───────────▼──────────────┐
        │   BOLTZGEN_RUN           │
        │   input:                 │
        │   - design.yaml          │
        │   - 1IVO.cif (staged)    │
        └──────────────────────────┘
```

**Key Points:**
- User provides both YAML and structure files
- YAML must reference basename: `path: 1IVO.cif`
- Structure files are staged directly into work directory

---

### 2. TARGET MODE (Generated Designs)

```
Samplesheet:
sample_id,target_structure,target_chain_ids,min_length,max_length,...
my_target,1IVO.cif,A,50,150,...

                    ↓
        ┌──────────────────────────┐
        │  Parse Samplesheet       │
        │  [meta, 1IVO.cif]        │
        └───────────┬──────────────┘
                    │
                    │ Generate designs
                    ▼
        ┌──────────────────────────┐
        │ GENERATE_DESIGN_VARIANTS │
        │                          │
        │ Creates YAMLs:           │
        │ - my_target_len50_v1     │
        │ - my_target_len50_v2     │
        │ - my_target_len70_v1     │
        │ ...                      │
        │                          │
        │ Each references:         │
        │   path: 1IVO.cif         │ ← Uses basename!
        └───────────┬──────────────┘
                    │
                    │ Join + Transpose
                    │ [meta, [yamls], structure] → [meta, yaml, structure]
                    ▼
        ┌──────────────────────────┐
        │   BOLTZGEN_RUN (x N)     │
        │   Each instance gets:    │
        │   - variant_len50_v1.yaml│
        │   - 1IVO.cif (staged)    │
        └──────────────────────────┘
```

**Key Points:**
- Single CIF generates multiple design variants
- All variants reference the same structure file
- Structure file is replicated to each BOLTZGEN_RUN task

---

### 3. P2RANK MODE (Pocket-Based Designs)

```
Samplesheet:
sample_id,target_structure,use_p2rank,top_n_pockets,min_pocket_score,...
egfr,1IVO.cif,true,3,0.5,...

                    ↓
        ┌──────────────────────────┐
        │  Parse Samplesheet       │
        │  [meta, 1IVO.cif]        │
        └───────────┬──────────────┘
                    │
                    │ Predict pockets
                    ▼
        ┌──────────────────────────┐
        │   P2RANK_PREDICT         │
        │   Identifies 3 pockets   │
        │   Returns:               │
        │   - predictions.csv      │
        │   - residues.csv         │
        └───────────┬──────────────┘
                    │
                    │ Join predictions + residues
                    │ [meta, structure, pred_csv, res_csv]
                    ▼
        ┌──────────────────────────┐
        │  FORMAT_BINDING_SITES    │
        │                          │
        │  Creates YAMLs:          │
        │  - egfr_pocket1_rank1    │
        │  - egfr_pocket2_rank2    │
        │  - egfr_pocket3_rank3    │
        │                          │
        │  Each specifies:         │
        │  - Binding residues      │
        │  - Pocket center/radius  │
        │  - Target: 1IVO.cif      │ ← Uses basename!
        └───────────┬──────────────┘
                    │
                    │ Join + Transpose
                    │ [meta, structure, ..., [yamls]] → [meta, yaml, structure]
                    ▼
        ┌──────────────────────────┐
        │   BOLTZGEN_RUN (x 3)     │
        │   Each instance gets:    │
        │   - egfr_pocket1_rank1   │
        │   - 1IVO.cif (staged)    │
        └──────────────────────────┘
```

**Key Points:**
- P2Rank identifies N pockets → N design YAMLs
- Each YAML targets specific residues/region
- Same structure file used for all pocket-specific designs

---

## Critical Implementation Details

### Channel Transformations

```groovy
// TARGET MODE
ch_designs_for_boltzgen = GENERATE_DESIGN_VARIANTS.out.design_yamls
    .join(ch_input, by: 0)              // Add structure back
    .transpose(by: 1)                    // Flatten YAML list
    .map { meta, yaml, structure ->      
        def design_meta = meta.clone()
        design_meta.id = yaml.baseName
        [design_meta, yaml, structure]   // Output format
    }

// P2RANK MODE  
ch_designs_for_boltzgen = ch_p2rank_results
    .join(FORMAT_BINDING_SITES.out.design_yamls, by: 0)
    .transpose(by: 4)                    // Flatten YAML list (index 4)
    .map { meta, structure, pred, res, yaml ->
        def design_meta = meta.clone()
        design_meta.id = yaml.baseName
        [design_meta, yaml, structure]   // Output format
    }
```

### YAML File Content

All generated YAMLs now use **basename** instead of full path:

```yaml
# BEFORE (❌ Wrong - file not staged)
entities:
  - file:
      path: /full/path/to/assets/test_data/1IVO.cif
      include:
        - chain: {id: A}

# AFTER (✅ Correct - file is staged)
entities:
  - file:
      path: 1IVO.cif
      include:
        - chain: {id: A}
```

---

## File Staging in Nextflow

### Work Directory Structure

When BOLTZGEN_RUN executes, Nextflow stages files:

```
work/
├── 3a/
│   └── 7f9d2e... (task hash)
│       ├── design.yaml          ← Staged from input
│       ├── 1IVO.cif             ← Staged from input
│       ├── .command.sh          ← Nextflow script
│       ├── .command.log         ← Task log
│       └── egfr_design_output/  ← Boltzgen output
│           ├── predictions/
│           ├── final_ranked_designs/
│           └── ...
```

### Why Basename Works

1. **Nextflow stages** both `design.yaml` AND `1IVO.cif` into work directory
2. **YAML references** `path: 1IVO.cif` (relative)
3. **Boltzgen reads** YAML, looks for `1IVO.cif` in current directory
4. **File is found** because Nextflow staged it!

---

## Comparison: Before vs After

### BEFORE (❌ Broken)

```
BOLTZGEN_RUN input: [meta, design.yaml]
Work directory:     design.yaml only
YAML contains:      path: /full/path/1IVO.cif
Boltzgen looks for: /full/path/1IVO.cif
Result:             ❌ File not found!
```

### AFTER (✅ Fixed)

```
BOLTZGEN_RUN input: [meta, design.yaml, 1IVO.cif]
Work directory:     design.yaml + 1IVO.cif
YAML contains:      path: 1IVO.cif
Boltzgen looks for: 1IVO.cif (in current dir)
Result:             ✅ File found!
```

---

## Example Use Cases

### Use Case 1: Designing Nanobody Against EGFR

```csv
sample_id,target_structure,use_p2rank,design_type,protocol,num_designs,budget
egfr_kinase,1IVO.cif,true,nanobody,nanobody-anything,100,10
```

**Flow:**
1. P2Rank analyzes `1IVO.cif` → finds 3 binding pockets
2. FORMAT_BINDING_SITES creates 3 YAMLs, each referencing `1IVO.cif`
3. 3 parallel BOLTZGEN_RUN tasks, each with `1IVO.cif` staged
4. Each generates 100 nanobody designs targeting different pocket

### Use Case 2: Multiple Length Variants

```csv
sample_id,target_structure,min_length,max_length,length_step,protocol
my_protein,target.pdb,50,150,20,protein-anything
```

**Flow:**
1. GENERATE_DESIGN_VARIANTS creates YAMLs for lengths: 50, 70, 90, 110, 130, 150
2. Each with 3 variants → 18 total YAMLs
3. All reference `target.pdb`
4. 18 parallel BOLTZGEN_RUN tasks, each with `target.pdb` staged

### Use Case 3: Custom Complex Design

```csv
sample_id,design_yaml,structure_files,protocol,num_designs,budget
complex,my_design.yaml,proteinA.cif,proteinB.cif,protein-anything,50,5
```

**Flow:**
1. User provides custom YAML referencing both proteins
2. Both CIF files staged together
3. Single BOLTZGEN_RUN with all required files
4. Generates 50 designs of the complex

---

## Summary

This architecture ensures:

✅ **Portability:** YAMLs work anywhere (use basenames)  
✅ **Correctness:** All files staged properly  
✅ **Scalability:** Works for 1 or 1000 designs  
✅ **Flexibility:** Supports all design modes  
✅ **Efficiency:** Files staged only where needed  

The key insight: **The CIF file IS the target**, and it needs to travel with the YAML through the entire workflow pipeline!
