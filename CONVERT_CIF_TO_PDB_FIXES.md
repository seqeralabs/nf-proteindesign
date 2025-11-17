# CONVERT_CIF_TO_PDB Process - Complete Fix Summary

## Issues Encountered and Fixed

### Issue 1: Python f-string Syntax Error ❌→✅
**Error Message:**
```
File ".command.sh", line 38
  output_file = output_dir / f"{file_stem}.pdb"
                                              ^
SyntaxError: invalid syntax
```

**Root Cause:**
- Python f-strings use curly braces `{}`
- Nextflow's triple-quoted strings also use `${variable}` for interpolation
- Conflict between Python and Nextflow syntax

**Failed Solution:**
- Tried escaping with double braces `{{variable}}`
- This didn't work because `{{` in Nextflow = literal `{`
- Python received `f"{{variable}}"` which is still invalid

**Working Solution:**
- Replaced ALL f-strings with string concatenation
- Used `"text " + variable + " more text"` syntax
- Completely avoids Nextflow/Python conflict

### Issue 2: No Files Found ❌→✅
**Error Message:**
```
Conversion complete:
  CIF files converted: 0
  PDB files validated: 0
  Total processed: 0
  Errors: 0
ERROR: No structure files were successfully processed
```

**Root Cause:**
- Input `path(structures)` from Nextflow stages a directory
- Original code: `structure_files = [Path(f) for f in "${structures}".split()]`
- This created `[Path("final_ranked_designs")]` - just the name, not the contents
- Never looked inside the directory for actual .cif files

**Solution:**
- Check if input is a directory using `Path().is_dir()`
- If directory: glob for `*.cif` and `*.pdb` files inside
- If single file: use it directly
- Added comprehensive debugging output

## Final Working Code Structure

### Input Handling
```python
structures_input = Path("${structures}")

if structures_input.is_dir():
    # Get all CIF and PDB files from directory
    structure_files = list(structures_input.glob("*.cif")) + \
                      list(structures_input.glob("*.pdb"))
    print("Found directory: " + str(structures_input))
    print("  Files found: " + str(len(structure_files)))
elif structures_input.is_file():
    # Single file input
    structure_files = [structures_input]
else:
    # Space-separated list fallback
    structure_files = [Path(f) for f in "${structures}".split() 
                       if Path(f).exists()]
```

### String Formatting (All Concatenation)
```python
# File paths
output_file = output_dir / (file_stem + ".pdb")

# Print statements
print("Converting " + structure_file.name + " to PDB format...")
print("  -> Output: " + str(output_file))

# Error handling
print("ERROR: Failed to process " + structure_file.name + ": " + str(e))

# Numeric output
print("  CIF files converted: " + str(converted_count))
```

### Debugging Output
When no files are found, the script now outputs:
- Input path (raw Nextflow variable)
- Resolved Path object
- Is it a directory?
- Is it a file?
- Does it exist?
- If directory: list all files inside (first 10)

## Testing Checklist

✅ **Syntax Validation:**
- Nextflow lint: `nextflow lint modules/local/convert_cif_to_pdb.nf` → PASS
- Python syntax check: `python3 -m py_compile` → PASS

✅ **Input Handling:**
- Directory input: Globs for .cif and .pdb files
- Single file input: Processes directly
- Empty directory: Provides helpful error message

✅ **String Operations:**
- No f-strings used anywhere
- All concatenation using `+` operator
- Numeric values converted with `str()`

## Commits History

1. **f8cbfae** - First attempt (failed): Tried escaping with `{{`
2. **4fbe551** - Fixed syntax: Replaced f-strings with concatenation
3. **1d66b12** - Updated documentation
4. **66b9572** - Fixed file discovery: Proper directory handling

## Usage

The process now correctly:
1. ✅ Accepts a directory of structure files from Boltzgen
2. ✅ Finds all .cif and .pdb files in that directory
3. ✅ Converts CIF to PDB format using BioPython
4. ✅ Outputs all converted files to `{meta.id}_pdb_structures/`
5. ✅ Provides clear error messages if something goes wrong

## Run with Resume

After pulling these fixes:
```bash
nextflow run main.nf -profile <your_profile> -resume
```

The `-resume` flag will pick up from where it failed and use the updated code.

## Best Practices Learned

### When Writing Python in Nextflow Processes:

**DO:**
- ✅ Use string concatenation: `"text " + var`
- ✅ Use `.format()`: `"text {}".format(var)`
- ✅ Use `%` formatting: `"text %s" % var`
- ✅ Test with `Path().is_dir()` for directory inputs
- ✅ Use `.glob()` to find files in directories
- ✅ Add debugging output for troubleshooting

**DON'T:**
- ❌ Use f-strings: `f"text {var}"` (conflicts with Nextflow)
- ❌ Assume inputs are always files (can be directories)
- ❌ Use `.split()` on paths without checking type first
- ❌ Skip error handling and debugging output

## Container Used
```
container 'biocontainers/biopython:v1.83_cv1'
```

This provides:
- BioPython 1.83
- Python 3.x
- MMCIFParser (for CIF files)
- PDBParser and PDBIO (for PDB files)
