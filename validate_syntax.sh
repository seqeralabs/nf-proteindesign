#!/bin/bash
# Validate Nextflow syntax for all module files

set -eo pipefail

echo "=================================================="
echo "  Nextflow Module Syntax Validation"
echo "=================================================="
echo ""

# Check Nextflow is available
if ! command -v nextflow &> /dev/null; then
    echo "❌ Error: Nextflow not found in PATH"
    exit 1
fi

NF_VERSION=$(nextflow -version 2>&1 | grep version | head -n1)
echo "✓ Nextflow found: $NF_VERSION"
echo ""

# Check main pipeline syntax
echo "Checking main pipeline syntax..."
output=$(nextflow run . --help 2>&1 || true)
if echo "$output" | grep -q "Module compilation error\|Unexpected input\|parse error"; then
    echo "❌ Main pipeline has syntax errors"
    echo "$output" | grep -A 10 "ERROR"
    exit 1
else
    echo "✓ Main pipeline compiles successfully"
fi
echo ""

# Validate individual module files
echo "Validating individual module files..."
echo ""

MODULE_DIR="modules/local"
ERRORS=0

for module_file in "$MODULE_DIR"/*.nf; do
    module_name=$(basename "$module_file" .nf)
    
    # Check file encoding (if file command is available)
    if command -v file &> /dev/null; then
        encoding=$(file -b --mime-encoding "$module_file")
        if [ "$encoding" != "us-ascii" ] && [ "$encoding" != "utf-8" ]; then
            echo "⚠️  $module_name: Unexpected encoding: $encoding (expected utf-8)"
            ERRORS=$((ERRORS + 1))
        fi
    else
        encoding="unknown"
    fi
    
    # Check for BOM
    if head -c 3 "$module_file" 2>/dev/null | grep -q $'\xef\xbb\xbf'; then
        echo "❌ $module_name: File contains UTF-8 BOM marker (should be removed)"
        ERRORS=$((ERRORS + 1))
    fi
    
    # Check for CRLF line endings
    if grep -q $'\r' "$module_file" 2>/dev/null; then
        echo "⚠️  $module_name: File contains Windows line endings (CRLF)"
        ERRORS=$((ERRORS + 1))
    fi
    
    # Check brace balance
    open_braces=$(grep -o "{" "$module_file" | wc -l)
    close_braces=$(grep -o "}" "$module_file" | wc -l)
    
    if [ "$open_braces" -ne "$close_braces" ]; then
        echo "❌ $module_name: Brace mismatch ($open_braces opening, $close_braces closing)"
        ERRORS=$((ERRORS + 1))
    else
        if [ "$encoding" != "unknown" ]; then
            echo "✓ $module_name: Syntax OK (encoding: $encoding, braces: $open_braces pairs)"
        else
            echo "✓ $module_name: Syntax OK (braces: $open_braces pairs)"
        fi
    fi
done

echo ""
echo "=================================================="

if [ $ERRORS -eq 0 ]; then
    echo "✅ All module files validated successfully!"
    echo "=================================================="
    exit 0
else
    echo "❌ Found $ERRORS issue(s) in module files"
    echo "=================================================="
    exit 1
fi
