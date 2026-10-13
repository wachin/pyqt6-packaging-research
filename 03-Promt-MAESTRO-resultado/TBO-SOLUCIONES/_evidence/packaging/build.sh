#!/usr/bin/env bash
# Build, verify and generate SBOM for a TBO 2 release.
# Requires: python3, pip, build. flatpak-builder only for the Flatpak step.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="$(python3 -c 'import tomllib; print(tomllib.load(open("pyproject.toml","rb"))["project"]["version"])')"
echo "=== TBO $VERSION build ==="

echo "=== Lint & unit tests ==="
if command -v ruff &>/dev/null; then
    ruff check src tests
else
    echo "  (ruff not installed, skipping lint)"
fi
QT_QPA_PLATFORM=offscreen python3 -m pytest tests/unit -q

echo "=== Build sdist and wheel ==="
if ! python3 -m build --version &>/dev/null; then
    python3 -m pip install build --quiet --break-system-packages || true
fi
python3 -m build > /dev/null
SDIST="dist/tbo-${VERSION}.tar.gz"
WHEEL="dist/tbo-${VERSION}-py3-none-any.whl"
[ -f "$SDIST" ] && [ -f "$WHEEL" ]
echo "  sdist: $SDIST"
echo "  wheel: $WHEEL"

echo "=== Generate checksums ==="
(cd dist && sha256sum "tbo-${VERSION}.tar.gz" "tbo-${VERSION}-py3-none-any.whl") > "dist/tbo-${VERSION}.sha256sums"
cat "dist/tbo-${VERSION}.sha256sums"

echo "=== SBOM (dependency list) ==="
python3 -m pip list --format=freeze > "dist/tbo-${VERSION}-requirements.txt"
echo "  written dist/tbo-${VERSION}-requirements.txt"

echo "=== Verify install from wheel into isolated prefix ==="
PREFIX="$(mktemp -d)"
trap "rm -rf $PREFIX" EXIT
python3 -m pip install "$WHEEL" --prefix="$PREFIX" --quiet --break-system-packages
SITE="$(python3 -c "import sysconfig; print(sysconfig.get_paths(scheme='posix_local')['purelib'])")"
SITE="$PREFIX$(echo "$SITE" | sed "s|$(python3 -c 'import sys; print(sys.prefix)')||")"
PYTHONPATH="$SITE" python3 -c "import tbo; print('  tbo', tbo.__version__)"

echo "=== Integration tests (requires display) ==="
echo "  xvfb-run -a python3 -m pytest tests/integration"

echo "=== Flatpak build (requires flatpak-builder) ==="
echo "  cd packaging && flatpak-builder build org.tbo.TBO.json --force-clean"

echo "=== All checks done ==="
