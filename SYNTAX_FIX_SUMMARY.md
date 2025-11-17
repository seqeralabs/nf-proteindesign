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

## Solution
Escape all curly braces in Python f-strings by **doubling them**: `{` → `{{` and `}` → `}}`

### Examples of Changes:
```python
# BEFORE (incorrect - causes syntax error)
output_file = output_dir / f"{file_stem}.pdb"
print(f"Converting {structure_file.name} to PDB format...")
print(f"  Errors: {error_count}")

# AFTER (correct - escapes braces)
output_file = output_dir / f"{{file_stem}}.pdb"
print(f"Converting {{structure_file.name}} to PDB format...")
print(f"  Errors: {{error_count}}")
```

## All Variables Fixed
The following Python f-string variables were escaped:
- `{{file_stem}}`
- `{{structure_file.name}}`
- `{{output_file}}`
- `{{e}}` (exception variable)
- `{{converted_count}}`
- `{{copied_count}}`
- `{{total_processed}}`
- `{{error_count}}`
- `{{Bio.__version__}}`
- `{{sys.version.split()[0]}}`

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
- Single `{` can cause issues with Python f-strings
- **Solution**: Escape with `{{` and `}}`

### Alternative: Single-Quoted Strings (`'''`)
- Nextflow does NOT perform interpolation
- Cannot use Nextflow variables like `${meta.id}`
- Not suitable for this use case where we need both Nextflow AND Python variables

## Commit
```
commit f8cbfae
Author: Seqera AI
Date: 2025-11-17

Fix Python f-string syntax in CONVERT_CIF_TO_PDB process

Escape all curly braces in Python f-strings by doubling them to 
prevent Nextflow from attempting to interpolate them as Nextflow 
variables. This fixes the SyntaxError: invalid syntax error.
```
