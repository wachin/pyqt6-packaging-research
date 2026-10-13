#!/usr/bin/env bash
# Build a Linux AppImage for TBO using PyInstaller onedir + appimagetool.
# [TEMPLATE — MUST BE TESTED] Run the job in GitHub Actions once before
# treating the produced AppImage as a release artifact.
#
# Approach (from PYQT6_MASTER_PACKAGING_TUTORIAL.md §9 AppImage and §10 GLIBC):
#   - PyInstaller onedir as the payload base (same flags as the macOS build)
#   - Manual AppDir assembly: AppRun, .desktop, icon, metainfo
#   - appimagetool with a pinned, checksum-verified binary
#   - Build on Ubuntu 22.04 (see .github/workflows/build.yml) for a
#     conservative GLIBC baseline (2.35)
set -euo pipefail

this_script="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
workspace_root="$(dirname "$(dirname "$this_script")")"
version="$(sed -n 's/.*__version__ = "\([^"]*\)".*/\1/p' "$workspace_root/src/tbo/__init__.py")"
dist_dir="$workspace_root/build/dist"
tmp_dir="$workspace_root/build/tmp"
output_dir="$workspace_root/build/output"
appdir="$tmp_dir/TBO.AppDir"

# [TEMPLATE — MUST BE TESTED] Pin appimagetool to a fixed asset and update
# APPIMAGETOOL_SHA256 whenever you want a newer build. The `continuous` tag is
# a moving target; the SHA256 below is verified before execution so an
# unexpected change fails the build instead of shipping silently.
APPIMAGETOOL_URL="https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage"
APPIMAGETOOL_SHA256="a6d71e2b6cd66f8e8d16c37ad164658985e0cf5fcaa950c90a482890cb9d13e0"
APPIMAGETOOL="$tmp_dir/appimagetool"

echo "Workspace root is ${workspace_root}"
export ARCH="${ARCH:-x86_64}"
mkdir -p "$dist_dir" "$tmp_dir" "$output_dir"
rm -rf "$dist_dir/tbo" "$appdir" "$APPIMAGETOOL"

# 1. Build the PyInstaller onedir payload (name=tbo on Linux)
pyinstaller -D -y \
  --name tbo \
  --hidden-import=PyQt6 \
  --hidden-import=PyQt6.QtCore \
  --hidden-import=PyQt6.QtGui \
  --hidden-import=PyQt6.QtWidgets \
  --hidden-import=PyQt6.QtSvg \
  --hidden-import=PyQt6.QtSvgWidgets \
  --hidden-import=PyQt6.QtPrintSupport \
  --add-data "$workspace_root/data/doodle:data/doodle" \
  --add-data "$workspace_root/translations:translations" \
  --distpath "$dist_dir" \
  --specpath "$tmp_dir" \
  --workpath "$tmp_dir" \
  "$workspace_root/src/tbo/__main__.py"

if [ ! -x "$dist_dir/tbo/tbo" ]; then
    echo "Expected PyInstaller output not found: $dist_dir/tbo/tbo" >&2
    exit 1
fi

# 2. Assemble the AppDir (manual, dikte pattern)
install -d "$appdir/usr/bin" \
    "$appdir/usr/share/applications" \
    "$appdir/usr/share/icons/hicolor/256x256/apps" \
    "$appdir/usr/share/metainfo"
cp -a "$dist_dir/tbo/." "$appdir/usr/bin/"

# AppRun (mount-safe; resolves the AppDir from wherever it is mounted)
cat > "$appdir/AppRun" <<'EOF'
#!/bin/sh
set -eu
HERE="$(dirname "$(readlink -f "$0")")"
export APPDIR="$HERE"
exec "$HERE/usr/bin/tbo" "$@"
EOF
chmod +x "$appdir/AppRun"

# Desktop entry + icon + metainfo
python "$workspace_root/packaging/generate_icon.py" \
    "$workspace_root/src/tbo/resources/icon.png" png "$appdir/tbo.png"
install -m644 "$appdir/tbo.png" "$appdir/usr/share/icons/hicolor/256x256/apps/tbo.png"
install -m644 "$workspace_root/packaging/tbo.desktop" "$appdir/tbo.desktop"
install -m644 "$workspace_root/packaging/tbo.desktop" "$appdir/usr/share/applications/tbo.desktop"
install -m644 "$workspace_root/packaging/org.tbo.TBO.appdata.xml" \
    "$appdir/usr/share/metainfo/org.tbo.TBO.metainfo.xml"

# 3. Download and verify a pinned appimagetool
wget -q -O "$APPIMAGETOOL" "$APPIMAGETOOL_URL"
echo "$APPIMAGETOOL_SHA256  $APPIMAGETOOL" | sha256sum -c -
chmod +x "$APPIMAGETOOL"

# 4. Build the AppImage (--appimage-extract-and-run because CI has no FUSE)
"$APPIMAGETOOL" --appimage-extract-and-run "$appdir" \
    "$output_dir/TBO-${version}-x86_64.AppImage"

echo "Created $output_dir/TBO-${version}-x86_64.AppImage"
