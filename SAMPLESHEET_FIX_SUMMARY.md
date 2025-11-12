# Samplesheet Validation Fix

## Problem
The test profiles were failing with the error:
```
Samplesheet file /home/florian/assets/test_data/samplesheet_p2rank_test.csv does not exist
```

## Root Cause
The issue was caused by the `"exists": true` validation in the nf-schema JSON schemas. When nf-schema validates samplesheet files with this option enabled, it checks if file paths exist **relative to the directory where Nextflow is launched from** (launchDir), not relative to the project directory (projectDir).

In the samplesheets, paths were specified as relative paths like:
- `assets/test_data/1IVO.cif`
- `assets/test_data/egfr_protein_design.yaml`

When a user launches the pipeline from a different directory (e.g., `/home/florian/`), nf-schema would try to find `/home/florian/assets/test_data/1IVO.cif`, which doesn't exist.

## Solution
We made two key changes:

### 1. Removed `"exists": true` from Schema Files
Removed the file existence validation from three schema files:
- `assets/schema_input_design.json` - for design_yaml field
- `assets/schema_input_p2rank.json` - for target_structure field
- `assets/schema_input_target.json` - for target_structure field

This allows paths to be validated for format and pattern, but not for existence at the schema validation stage.

### 2. Added Runtime File Validation in main.nf
Added explicit file existence checking when creating file objects in the workflow:

**Design Mode:**
```groovy
// Convert to file object and validate existence
def design_yaml = file(design_yaml_path, checkIfExists: true)
```

**Target/P2Rank Mode:**
```groovy
// Convert to file object and validate existence
def target_structure = file(target_structure_path, checkIfExists: true)
```

## Benefits of This Approach

1. **Portability**: Relative paths now work correctly from any launch directory
2. **Better Error Messages**: Nextflow's `file()` function with `checkIfExists: true` provides clear error messages about which specific file is missing
3. **Proper Resolution**: Nextflow automatically resolves paths relative to projectDir when using the `file()` function
4. **Right Timing**: File existence is validated at the right stage - when Nextflow actually processes the files, not during schema parsing

## Testing
After this fix, the test profiles should work when launched from any directory:

```bash
# From project root
nextflow run main.nf -profile test_p2rank,docker

# From a different directory
cd /home/florian
nextflow run /path/to/nf-proteindesign-2025/main.nf -profile test_p2rank,docker
```

## Technical Details
- nf-schema's `samplesheetToList()` function still validates:
  - Field types (string, integer, boolean)
  - Patterns (regex for file extensions)
  - Format (file-path format type)
  - Required fields
- Nextflow's `file()` function with `checkIfExists: true`:
  - Resolves paths relative to projectDir automatically
  - Works with absolute paths, relative paths, and glob patterns
  - Provides clear error messages if files don't exist
  - Supports S3, Azure, and other remote paths

## References
- nf-schema documentation: https://nextflow-io.github.io/nf-schema/
- Nextflow file() function: https://www.nextflow.io/docs/latest/script.html#file
