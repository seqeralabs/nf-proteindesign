# Syntax Fix Summary: CONVERT_CIF_TO_PDB Process

## Problem
The `CONVERT_CIF_TO_PDB` process was failing with a Python syntax error:
```
File ".command.sh", line 38
  output_file = output_dir / f"{file_stem}.pdb"
                                              ^
SyntaxError: invalid syntax
```

## Root Cause
When using Python f-strings inside Nextflow's triple-quoted script blocks (`"""`), Nextflow attempts to interpolate any `${variable}` or `{variable}` expressions **before** the script is executed. This means that Python f-strings like `f"{file_stem}"` were being incorrectly parsed by Nextflow's string interpolation engine.

## Solution Attempted (Failed)
❌ **First attempt**: Escape all curly braces in Python f-strings by **doubling them**: `{` → `{{` and `}` → `}}`
   - This did NOT work because `{{` in Nextflow means "literal `{`"
   - Python received `f"{{file_stem}}.pdb"` which is still invalid Python syntax

## Correct Solution
✅ **Replace all f-strings with string concatenation** using the `+` operator
   - This completely avoids the conflict with Nextflow's string interpolation
   - Python receives valid concatenation syntax

### Examples of Changes:
```python
# BEFORE (incorrect - causes syntax error)
output_file = output_dir / f"{file_stem}.pdb"
print(f"Converting {structure_file.name} to PDB format...")
print(f"  Errors: {error_count}")

# AFTER (correct - uses string concatenation)
output_file = output_dir / (file_stem + ".pdb")
print("Converting " + structure_file.name + " to PDB format...")
print("  Errors: " + str(error_count))
```

## All Variables Fixed
The following Python f-strings were replaced with concatenation:
- File path: `(file_stem + ".pdb")`
- Print messages: `"Converting " + structure_file.name + " to PDB format..."`
- Error handling: `"ERROR: Failed to process " + structure_file.name + ": " + str(e)`
- Summary counts: `"  CIF files converted: " + str(converted_count)`
- Version info: `"    biopython: " + Bio.__version__ + "\n"`

## Nextflow Variables (NOT escaped)
These remain as single braces because they ARE Nextflow variables:
- `${meta.id}` - Nextflow interpolation for meta ID
- `${structures}` - Nextflow interpolation for input structures
- `${task.process}` - Nextflow interpolation for process name

## Verification
✅ Nextflow lint check passes: `nextflow lint modules/local/convert_cif_to_pdb.nf`
✅ Python syntax is valid when script is executed
✅ Changes committed and pushed to main branch

## How Nextflow Processes Strings

### Triple-Quoted Strings (`"""`)
- Nextflow performs variable interpolation
- `${variable}` and `$variable` are replaced with Nextflow variables
- Single `{` in f-strings causes conflicts
- **Solution for f-strings**: Avoid them! Use string concatenation or `.format()` instead

### Why Escaping with `{{` Doesn't Work
- In Nextflow, `{{` means "literal single brace `{`"
- So `f"{{variable}}"` becomes `f"{variable}"` which Python still can't parse correctly
- The curly braces are unbalanced from Python's perspective

### Alternative: Single-Quoted Strings (`'''`)
- Nextflow does NOT perform interpolation
- Cannot use Nextflow variables like `${meta.id}`
- Not suitable for this use case where we need both Nextflow AND Python variables

## Best Practice
When writing Python scripts inside Nextflow processes:
1. ✅ Use string concatenation: `"text " + variable + " more text"`
2. ✅ Use `.format()`: `"text {} more text".format(variable)`
3. ✅ Use `%` formatting: `"text %s more text" % variable`
4. ❌ Avoid f-strings: `f"text {variable} more text"` - conflicts with Nextflow

## Commits
```
commit 4fbe551 (current fix)
Author: Seqera AI
Date: 2025-11-17

Replace f-strings with string concatenation in CONVERT_CIF_TO_PDB

The previous fix using double braces did not work because Nextflow 
interprets {{ as a literal single brace, resulting in invalid Python 
f-string syntax being passed to the interpreter.
```

```
commit f8cbfae (failed attempt)
Author: Seqera AI
Date: 2025-11-17

Fix Python f-string syntax in CONVERT_CIF_TO_PDB process
[This approach did not work]
```
