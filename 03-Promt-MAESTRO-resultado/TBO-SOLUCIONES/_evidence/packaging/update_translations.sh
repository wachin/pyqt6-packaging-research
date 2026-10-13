#!/usr/bin/env bash
# Extract translatable strings to .ts and compile to .qm.
# Works with pylupdate6 (PyQt6-tools), lupdate (Qt SDK), or creates a placeholder.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p translations

EXTRACTOR=""
if command -v pylupdate6 &>/dev/null; then
    EXTRACTOR="pylupdate6"
elif command -v lupdate &>/dev/null; then
    EXTRACTOR="lupdate"
    echo "INFO: using lupdate (may not scan Python files; pylupdate6 is preferred)"
fi

if [ -n "$EXTRACTOR" ]; then
    echo "=== Extracting strings ($EXTRACTOR) ==="
    if [ "$EXTRACTOR" = "lupdate" ]; then
        lupdate src/tbo -ts translations/tbo_en.ts -source-language en \
            -tr-function-alias tr=tr -extensions py,ui
    else
        pylupdate6 src/tbo -ts translations/tbo_en.ts
    fi
else
    echo "WARNING: no translation tool found (install pylupdate6 or pyqt6-tools)."
    echo "Creating a placeholder .ts instead."
    cat > translations/tbo_en.ts << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE TS>
<TS version="2.1" language="en">
<context>
    <name>Application</name>
    <message>
        <source>Untitled</source>
        <translation type="unfinished"></translation>
    </message>
</context>
</TS>
EOF
    echo "  placeholder translations/tbo_en.ts created"
fi

echo "=== Compiling .qm files (lrelease) ==="
for ts in translations/*.ts; do
    qm="${ts%.ts}.qm"
    if [ -f "$qm" ] && [ "$qm" -nt "$ts" ]; then
        continue
    fi
    lrelease "$ts" -qm "$qm" 2>/dev/null || echo "  (lrelease not available, skipping $ts -> $qm)"
done

echo "=== Copying .qm into the package (src/tbo/translations/) ==="
mkdir -p src/tbo/translations
cp -f translations/*.qm src/tbo/translations/

echo "=== Done ==="
echo "  To add a new language:"
echo "    pylupdate6 src/tbo -ts translations/tbo_<locale>.ts"