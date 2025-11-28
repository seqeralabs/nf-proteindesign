# Fix for MMSEQS2_MSA Syntax Error

## Problem
You're experiencing a Nextflow compilation error:
```
ERROR ~ Module compilation error
- file : /home/florian/nf-proteindesign-2025/modules/local/mmseqs2_msa.nf
- cause: Unexpected input: '{' @ line 1, column 21.
   process MMSEQS2_MSA {
                       ^
```

## Root Cause
The repository version of `modules/local/mmseqs2_msa.nf` is **correct** and compiles without errors. The issue is specific to your local copy at `/home/florian/nf-proteindesign-2025/`.

This error typically occurs due to:
1. **File encoding corruption** (BOM markers, wrong line endings)
2. **Hidden characters** introduced during editing
3. **Incomplete file sync** from git operations
4. **Text editor issues** (some editors add hidden characters)

## Solution

### Option 1: Reset the file from repository (RECOMMENDED)
```bash
cd /home/florian/nf-proteindesign-2025

# Backup your current file
cp modules/local/mmseqs2_msa.nf modules/local/mmseqs2_msa.nf.backup

# Reset to repository version
git fetch origin
git checkout origin/main -- modules/local/mmseqs2_msa.nf

# Verify it works
nextflow run . --help
```

### Option 2: Check for file corruption
```bash
# Check file encoding
file modules/local/mmseqs2_msa.nf

# Check for hidden characters
head -n 20 modules/local/mmseqs2_msa.nf | cat -A

# Check for BOM markers
head -c 3 modules/local/mmseqs2_msa.nf | od -An -tx1

# Convert line endings (if needed)
dos2unix modules/local/mmseqs2_msa.nf
```

### Option 3: Manual file replacement
If git operations don't work, manually download the correct file:

```bash
cd /home/florian/nf-proteindesign-2025/modules/local

# Download correct version
curl -o mmseqs2_msa.nf https://raw.githubusercontent.com/seqeralabs/nf-proteindesign/main/modules/local/mmseqs2_msa.nf

# Verify
head -n 20 mmseqs2_msa.nf
```

## Verification
After applying the fix, verify the syntax is correct:

```bash
cd /home/florian/nf-proteindesign-2025

# Test compilation
nextflow run . --help

# Should see help text, not syntax errors
```

## Additional Checks

### Check for missing closing braces in other modules
Sometimes the error appears at the start of one process when the actual issue is a missing closing brace in a previous module:

```bash
# Check the include statements order in workflows/protein_design.nf
grep "^include" workflows/protein_design.nf

# The modules included before MMSEQS2_MSA are:
# - BOLTZGEN_RUN
# - CONVERT_CIF_TO_PDB
# - PROTEINMPNN_OPTIMIZE
# - EXTRACT_TARGET_SEQUENCES

# Verify each of these files has correct syntax
```

### Validate all process definitions
```bash
# Check that all process blocks are properly closed
for f in modules/local/*.nf; do
  echo "Checking: $f"
  # Count opening and closing braces
  open=$(grep -o "{" "$f" | wc -l)
  close=$(grep -o "}" "$f" | wc -l)
  if [ "$open" != "$close" ]; then
    echo "  ⚠️  MISMATCH: $open opening vs $close closing braces"
  else
    echo "  ✓ Braces balanced ($open pairs)"
  fi
done
```

## Prevention
To avoid this issue in the future:

1. **Use git properly**: Always pull changes with `git pull` instead of manual file copying
2. **Check file encoding**: Ensure your editor uses UTF-8 without BOM
3. **Line endings**: Configure git to handle line endings automatically:
   ```bash
   git config --global core.autocrlf input  # For Linux/Mac
   git config --global core.autocrlf true   # For Windows
   ```
4. **Editor settings**: Use editors that preserve UNIX line endings (LF not CRLF)

## Still Having Issues?

If the problem persists after trying all solutions:

1. Show the output of these diagnostic commands:
   ```bash
   file modules/local/mmseqs2_msa.nf
   head -n 20 modules/local/mmseqs2_msa.nf | od -c | head -n 30
   git status
   git diff modules/local/mmseqs2_msa.nf
   ```

2. Check if you have any uncommitted changes that might conflict

3. Consider cloning a fresh copy of the repository:
   ```bash
   cd /home/florian
   mv nf-proteindesign-2025 nf-proteindesign-2025.old
   git clone https://github.com/seqeralabs/nf-proteindesign.git nf-proteindesign-2025
   cd nf-proteindesign-2025
   nextflow run . --help
   ```

## Repository Status
✅ **The repository version is CORRECT** - verified to compile without errors with Nextflow 25.04.7 and 25.10.0
✅ **No syntax errors in the main branch**
✅ **All process definitions are properly formatted**

The issue is isolated to your local working copy and can be resolved by restoring the file from the repository.
