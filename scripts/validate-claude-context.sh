#!/usr/bin/env bash
# scripts/validate-claude-context.sh
# Validates CLAUDE.md files for broken references and dead commands

set -e

echo "=== Validating CLAUDE.md Context Files ==="

ERRORS=0
WARNINGS=0

# Find all CLAUDE.md files
CLAUDE_FILES=$(find . -name "CLAUDE.md" -o -name "CLAUDE.local.md" 2>/dev/null || true)

if [ -z "$CLAUDE_FILES" ]; then
    echo "❌ No CLAUDE.md files found!"
    exit 1
fi

for file in $CLAUDE_FILES; do
    echo ""
    echo "Checking: $file"

    # Skip if file doesn't exist (shouldn't happen, but defensive)
    if [ ! -f "$file" ]; then
        echo "  ⚠️  File not found (skipping)"
        continue
    fi

    # Extract @references (e.g., @docs/some-file.md, @nginx/nginx.dev.conf)
    # Matches @path/to/file.ext or @path/to/dir/
    REFS=$(grep -oE '@[a-zA-Z0-9/_.-]+' "$file" 2>/dev/null || true)

    if [ -n "$REFS" ]; then
        echo "  Found $(echo "$REFS" | wc -l) @references to validate..."

        for ref in $REFS; do
            # Remove @ prefix
            path="${ref:1}"

            # Skip if it looks like an email or special syntax
            if [[ "$path" == *"@"* ]] || [[ "$path" == "" ]]; then
                continue
            fi

            # Get directory of the CLAUDE.md file
            dir=$(dirname "$file")

            # Try different path resolutions:
            # 1. Relative to CLAUDE.md location
            # 2. Relative to repository root (current directory)
            full_path="$dir/$path"
            root_path="./$path"

            if [ -e "$full_path" ]; then
                echo "  ✅ Valid reference: $ref → $full_path"
            elif [ -e "$root_path" ]; then
                echo "  ✅ Valid reference: $ref → $root_path"
            else
                echo "  ❌ Broken reference: $ref"
                echo "     Tried: $full_path"
                echo "     Tried: $root_path"
                ERRORS=$((ERRORS + 1))
            fi
        done
    else
        echo "  ℹ️  No @references found"
    fi

    # Check for discovery commands in code blocks
    # Extract bash code blocks and check if they look runnable
    echo "  Checking discovery commands..."

    # Simple check: look for common command patterns that should exist
    if grep -q "docker compose" "$file"; then
        if ! command -v docker &> /dev/null; then
            echo "  ⚠️  Warning: References docker compose but docker command not available"
            WARNINGS=$((WARNINGS + 1))
        fi
    fi

    if grep -q "mvnw" "$file"; then
        # Check if we're in a context where mvnw should exist
        if [ ! -f "./mvnw" ] && [ ! -f "../mvnw" ]; then
            echo "  ℹ️  Note: References ./mvnw (may be in service repo context)"
        fi
    fi

    # Check file size (warn if CLAUDE.md is too large)
    lines=$(wc -l < "$file")
    if [ "$lines" -gt 200 ]; then
        echo "  ⚠️  Warning: File has $lines lines (recommend < 200 for pattern-based docs)"
        WARNINGS=$((WARNINGS + 1))
    else
        echo "  ✅ File size OK: $lines lines"
    fi

done

echo ""
echo "=== Summary ==="
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo "✅ All CLAUDE.md files valid!"
    echo "   No errors, no warnings"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo "⚠️  Validation passed with warnings"
    echo "   Errors: $ERRORS"
    echo "   Warnings: $WARNINGS"
    exit 0
else
    echo "❌ Validation failed"
    echo "   Errors: $ERRORS"
    echo "   Warnings: $WARNINGS"
    exit 1
fi
