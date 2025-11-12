# CIF/PDB Structure File Staging - Quick Start Guide

## 🎯 What Changed?

We've implemented proper staging of CIF/PDB structure files for Boltzgen tasks. This fixes "file not found" errors and ensures all required structure files are available during design generation.

## 🚨 Do I Need to Update My Workflow?

### ✅ No Changes Needed If You Use:
- **Target Mode** (`--mode target`)
- **P2Rank Mode** (`--mode p2rank`)

Your existing samplesheets and workflows continue to work without modification!

### ⚠️ Update Required If You Use:
- **Design Mode** (`--mode design`)

You must add a `structure_files` column to your samplesheet.

---

## 📝 Quick Fix for Design Mode

### Old Samplesheet (Won't Work)
```csv
sample_id,design_yaml,protocol,num_designs,budget
my_design,design.yaml,protein-anything,100,10
```

### New Samplesheet (Required Format)
```csv
sample_id,design_yaml,structure_files,protocol,num_designs,budget
my_design,design.yaml,target.cif,protein-anything,100,10
```

### Multiple Structure Files
```csv
sample_id,design_yaml,structure_files,protocol,num_designs,budget
complex,design.yaml,protein1.cif,protein2.pdb,protein-anything,100,10
```

---

## 🔍 Why This Change?

### The Problem
```
Boltzgen YAML:     path: /full/path/to/target.cif
Work directory:    Only contains design.yaml
Boltzgen looks for: /full/path/to/target.cif
Result:            ❌ FileNotFoundError
```

### The Solution
```
Boltzgen YAML:     path: target.cif
Work directory:    Contains design.yaml AND target.cif
Boltzgen looks for: target.cif (in current directory)
Result:            ✅ File found!
```

---

## 📖 Usage Examples

### Example 1: Design Mode - Single Target
```bash
# Create samplesheet
cat > samplesheet.csv << EOF
sample_id,design_yaml,structure_files,protocol,num_designs,budget
egfr_binder,my_design.yaml,1IVO.cif,protein-anything,100,10
EOF

# Run pipeline
nextflow run FloWuenne/nf-proteindesign-2025 \
  --input samplesheet.csv \
  --mode design \
  -profile docker
```

**Your YAML should reference basename only:**
```yaml
entities:
  - protein:
      id: BINDER
      sequence: 80..120
  - file:
      path: 1IVO.cif  # ✅ Just the filename
      include:
        - chain: {id: A}
```

### Example 2: Target Mode (No Changes Needed)
```bash
# Samplesheet (unchanged)
cat > samplesheet.csv << EOF
sample_id,target_structure,target_chain_ids,min_length,max_length,protocol,num_designs,budget
my_target,target.pdb,A,50,150,protein-anything,100,10
EOF

# Run pipeline (same as before)
nextflow run FloWuenne/nf-proteindesign-2025 \
  --input samplesheet.csv \
  --mode target \
  -profile docker
```

### Example 3: P2Rank Mode (No Changes Needed)
```bash
# Samplesheet (unchanged)
cat > samplesheet.csv << EOF
sample_id,target_structure,use_p2rank,top_n_pockets,min_pocket_score,design_type,protocol,num_designs,budget
egfr,1IVO.cif,true,3,0.5,protein,protein-anything,100,10
EOF

# Run pipeline (same as before)
nextflow run FloWuenne/nf-proteindesign-2025 \
  --input samplesheet.csv \
  --mode p2rank \
  -profile docker
```

---

## 🛠️ Troubleshooting

### Error: "File not found" for structure file

**Symptom:**
```
FileNotFoundError: [Errno 2] No such file or directory: 'target.cif'
```

**Solution:**
1. Check that `structure_files` column exists in your samplesheet (design mode)
2. Verify file paths are correct
3. Ensure YAML references use basename only (e.g., `target.cif` not `/path/to/target.cif`)

### Error: Schema validation failed

**Symptom:**
```
ERROR: Samplesheet validation failed
* structure_files: required property
```

**Solution:**
Add the `structure_files` column to your design mode samplesheet.

### Error: Multiple structure files not recognized

**Symptom:**
Structure files treated as single string instead of list.

**Solution:**
Use comma-separated format:
```csv
structure_files
file1.cif,file2.pdb,file3.cif
```

---

## 📂 File Locations

### Test Data
```
assets/test_data/
├── 1IVO.cif                           # EGFR kinase domain structure
├── egfr_protein_design.yaml           # Example protein design
├── egfr_peptide_design.yaml           # Example peptide design
├── egfr_nanobody_design.yaml          # Example nanobody design
└── samplesheet_design_test.csv        # Updated test samplesheet
```

### Documentation
```
.
├── CIF_STAGING_README.md              # This file (quick start)
├── SUMMARY.md                          # Executive summary
├── CIF_STAGING_CHANGES.md             # Technical details
├── ARCHITECTURE_DIAGRAM.md            # Architecture diagrams
├── TESTING_CHECKLIST.md               # Testing procedures
└── CHANGELOG_CIF_STAGING.md           # Complete changelog
```

---

## ✅ Validation Checklist

Before running your pipeline, verify:

- [ ] **Design Mode:** Samplesheet has `structure_files` column
- [ ] **Design Mode:** YAML files reference basenames only
- [ ] **All Modes:** Structure files exist at specified paths
- [ ] **All Modes:** File extensions are `.cif`, `.pdb`, `.CIF`, or `.PDB`
- [ ] **Design Mode:** Structure files match references in YAML

---

## 🆘 Getting Help

### Quick Reference
- Design mode users: See "Quick Fix for Design Mode" above
- Target/P2Rank users: No action needed
- Detailed docs: See `CIF_STAGING_CHANGES.md`
- Full testing: See `TESTING_CHECKLIST.md`

### Common Questions

**Q: I use P2Rank mode. Do I need to change anything?**
A: No! The `target_structure` column already contains your CIF file.

**Q: I use Target mode. Do I need to change anything?**
A: No! The `target_structure` column already contains your CIF file.

**Q: What if my YAML references multiple CIF files?**
A: List them comma-separated in `structure_files`: `file1.cif,file2.cif`

**Q: Can I use absolute paths?**
A: Yes, but relative paths are recommended for portability.

**Q: Do I need to change my existing YAML files?**
A: Only if they use full paths. Update to use basenames (e.g., `1IVO.cif` instead of `/path/to/1IVO.cif`).

---

## 📊 Summary Table

| Mode | Samplesheet Changes | YAML Changes | Structure File Source |
|------|-------------------|--------------|---------------------|
| Design | ✅ Add `structure_files` | ✅ Use basenames | User provides |
| Target | ❌ None | ❌ Auto-generated | `target_structure` |
| P2Rank | ❌ None | ❌ Auto-generated | `target_structure` |

---

## 🎓 Understanding the Architecture

### The Key Insight
**The CIF/PDB file IS your biological target!**

- In **Design Mode**: You say "here's my target (CIF) and design (YAML)"
- In **Target Mode**: You say "here's my target (CIF), generate designs for me"
- In **P2Rank Mode**: You say "here's my target (CIF), find pockets and design for them"

In all cases, the CIF file represents the protein you want to design a binder against (e.g., EGFR kinase domain). This file must travel with your design through the pipeline!

### What Happens Now

```
Your CIF file → Staged with YAML → Boltzgen reads both → Designs generated ✅
```

Instead of:

```
Your CIF file → Not staged → Boltzgen can't find it → Error ❌
```

---

## 🚀 Next Steps

1. **Update your samplesheets** (if using design mode)
2. **Update your YAML files** to use basenames
3. **Run the pipeline** and verify it works
4. **Report issues** if you encounter problems

---

## 📅 Version Info

- **Feature Date:** 2025-11-12
- **Pipeline Version:** Compatible with nf-proteindesign-2025
- **Status:** ✅ Complete and tested
- **Breaking Changes:** Design mode samplesheet format only

---

For detailed technical documentation, see `CIF_STAGING_CHANGES.md`.
For complete testing procedures, see `TESTING_CHECKLIST.md`.
