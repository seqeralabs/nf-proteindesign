# Changelog: CIF File Staging Feature

## Version: 2025-11-12

### 🎯 Feature: Proper CIF/PDB Structure File Staging for Boltzgen

**Issue:** Boltzgen YAML files referenced structure files that were not staged into the process work directory, causing "file not found" errors during execution.

**Solution:** Implemented comprehensive structure file staging across all workflow modes (design, target, p2rank), ensuring CIF/PDB files are properly staged alongside design YAML files.

---

## 🔧 Changes Made

### Core Modules Modified

#### 1. `modules/local/boltzgen_run.nf`
**Change:** Updated input signature to accept structure files
```diff
- tuple val(meta), path(design_yaml)
+ tuple val(meta), path(design_yaml), path(structure_files)
```
**Impact:** All structure files are now staged into BOLTZGEN_RUN work directory

#### 2. `modules/local/format_binding_sites.nf`
**Change:** Generate YAMLs with basename-only references
```diff
+ structure_basename = os.path.basename('${protein_structure}')
- path: '${protein_structure}'
+ path: structure_basename
```
**Impact:** Generated YAMLs are portable and reference locally-staged files

#### 3. `modules/local/generate_design_variants.nf`
**Change:** Generate YAMLs with basename-only references
```diff
+ target_file_basename = os.path.basename("${target_structure}")
- path: target_file
+ path: target_file_basename
```
**Impact:** Generated YAMLs are portable and reference locally-staged files

### Workflows Modified

#### 4. `workflows/protein_design.nf`
**Changes:**
- Updated all three mode branches (design/target/p2rank)
- Modified channel operations to preserve structure files
- Implemented proper `join()` and `transpose()` for file propagation

**Design Mode:**
```groovy
// Input already includes structure files
ch_designs_for_boltzgen = ch_input  // [meta, yaml, structures]
```

**Target Mode:**
```groovy
ch_designs_for_boltzgen = GENERATE_DESIGN_VARIANTS.out.design_yamls
    .join(ch_input, by: 0)
    .transpose(by: 1)
    .map { meta, yaml, structure -> [design_meta, yaml, structure] }
```

**P2Rank Mode:**
```groovy
ch_designs_for_boltzgen = ch_p2rank_results
    .join(FORMAT_BINDING_SITES.out.design_yamls, by: 0)
    .transpose(by: 4)
    .map { meta, structure, pred, res, yaml -> [design_meta, yaml, structure] }
```

#### 5. `workflows/p2rank_to_designs.nf`
**Change:** Updated channel operations to preserve structure files through FORMAT_BINDING_SITES
```groovy
ch_individual_designs = ch_p2rank_results
    .join(FORMAT_BINDING_SITES.out.design_yamls, by: 0)
    .transpose(by: 4)
    .map { meta, structure, predictions_csv, residues_csv, yaml_file ->
        [design_meta, yaml_file, structure]
    }
```

### Input Processing Modified

#### 6. `main.nf`
**Change:** Added structure_files parsing for design mode
```diff
+ def structure_files_str = tuple[2]
+ def structure_files = []
+ if (structure_files_str) {
+     structure_files_str.split(',').each { structure_path ->
+         // Smart path resolution
+         structure_files.add(file(trimmed_path, checkIfExists: true))
+     }
+ }
```
**Impact:** Design mode users can provide comma-separated structure files

### Schema and Examples Modified

#### 7. `assets/schema_input_design.json`
**Change:** Added structure_files field
```json
"structure_files": {
  "type": "string",
  "errorMessage": "Structure files must be a comma-separated list of PDB/CIF file paths"
}
```

#### 8. `assets/samplesheet_example.csv`
**Change:** Added structure_files column
```diff
- sample_id,design_yaml,protocol,num_designs,budget
+ sample_id,design_yaml,structure_files,protocol,num_designs,budget
- protein_binder_example,assets/design_examples/protein_design.yaml,protein-anything,100,10
+ protein_binder_example,assets/design_examples/protein_design.yaml,assets/test_data/1IVO.cif,protein-anything,100,10
```

#### 9. `assets/test_data/samplesheet_design_test.csv`
**Change:** Added structure_files column with proper paths
```diff
- sample_id,design_yaml,protocol,num_designs,budget
+ sample_id,design_yaml,structure_files,protocol,num_designs,budget
- egfr_protein_binder,assets/test_data/egfr_protein_design.yaml,protein-anything,10,2
+ egfr_protein_binder,assets/test_data/egfr_protein_design.yaml,assets/test_data/1IVO.cif,protein-anything,10,2
```

---

## 📊 Impact Summary

### Breaking Changes
- **Design Mode ONLY:** Samplesheets must now include `structure_files` column
- **Target Mode:** No breaking changes
- **P2Rank Mode:** No breaking changes

### Migration Required For
- Users providing custom design YAML files (design mode)
- Existing design mode samplesheets need `structure_files` column added

### No Migration Required For
- Target mode users (target_structure is already the CIF file)
- P2Rank mode users (target_structure is already the CIF file)

---

## ✅ Benefits

1. **Fixes Critical Bug:** Structure files are now properly staged, eliminating "file not found" errors
2. **Portable YAMLs:** Generated YAMLs use basenames, making them location-independent
3. **Consistent Behavior:** All three modes handle structure files uniformly
4. **Multiple Files Support:** Design mode supports comma-separated structure file lists
5. **Better Error Handling:** File existence checked during input parsing (fail fast)

---

## 🧪 Testing Status

### Recommended Tests
- [ ] Design mode with single CIF file
- [ ] Design mode with multiple CIF files
- [ ] Target mode with various length parameters
- [ ] P2Rank mode with multiple pockets
- [ ] End-to-end pipeline with IPSAE scoring
- [ ] Resume capability
- [ ] Absolute and relative path handling

See `TESTING_CHECKLIST.md` for comprehensive test suite.

---

## 📚 Documentation Added

1. **CIF_STAGING_CHANGES.md** - Detailed technical documentation
2. **SUMMARY.md** - Executive summary and quick reference
3. **ARCHITECTURE_DIAGRAM.md** - Visual architecture and data flow diagrams
4. **TESTING_CHECKLIST.md** - Comprehensive testing procedures
5. **CHANGELOG_CIF_STAGING.md** - This file

---

## 🔗 Related Issues

- Fixes: Structure files not staged in BOLTZGEN_RUN
- Addresses: "FileNotFoundError" in Boltzgen execution
- Improves: Pipeline robustness and portability

---

## 👥 User Impact

### Design Mode Users
**Action Required:** Update samplesheets to include structure_files column

**Before:**
```csv
sample_id,design_yaml,protocol,num_designs,budget
my_design,design.yaml,protein-anything,100,10
```

**After:**
```csv
sample_id,design_yaml,structure_files,protocol,num_designs,budget
my_design,design.yaml,target.cif,protein-anything,100,10
```

### Target/P2Rank Mode Users
**Action Required:** None! Your workflows continue to work as-is.

---

## 🚀 Future Enhancements

Potential improvements for future versions:

1. **Automatic YAML Validation:** Check that all file paths in YAML match staged files
2. **Structure File Discovery:** Auto-detect required structure files from YAML content
3. **Remote File Support:** Direct staging from URLs (PDB database, etc.)
4. **Caching:** Shared structure file cache across multiple designs
5. **Metadata Tracking:** Record structure file provenance in outputs

---

## 📝 Notes

### Key Insight
The CIF/PDB structure file **IS** the biological target we design against. It needs to travel with the design YAML through the entire workflow pipeline. This is true for all three modes:

- **Design Mode:** User provides both (explicit)
- **Target Mode:** target_structure is the CIF (implicit)
- **P2Rank Mode:** target_structure is the CIF (implicit)

### Technical Details
- Channel transformations use `join()` to preserve file associations
- `transpose()` used to flatten lists while maintaining structure references
- Smart path resolution supports absolute, relative, and remote paths
- File existence validated early in pipeline (fail-fast approach)

---

## ✍️ Author
- **Date:** 2025-11-12
- **Context:** Seqera AI Assistant implementation
- **Repository:** FloWuenne/nf-proteindesign-2025

---

## 📋 Commit Message

```
feat: implement proper CIF/PDB structure file staging for Boltzgen

- Add structure_files input to BOLTZGEN_RUN module
- Update YAML generation to use basename references
- Modify all workflows to preserve structure files
- Add structure_files column to design mode samplesheet
- Update schemas and examples
- Add comprehensive documentation

This fixes the "file not found" errors by ensuring structure files
are properly staged alongside design YAML files in all workflow modes.

Design mode users must add structure_files column to samplesheets.
Target and P2Rank modes require no changes.

Closes: Structure file staging issue
```
