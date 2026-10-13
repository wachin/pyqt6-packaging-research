#!/usr/bin/env bash
# Build a Linux AppImage for TBO using PyInstaller onedir + appimagetool.
#
# STATUS: built and launched. The `build-appimage` job in
# .github/workflows/build.yml is green and produced a working AppImage
# (TBO-2.0.0.dev0-x86_64.AppImage), which was extracted and run.
#
# Do not read "the job is green" as "the artifact is correct". It shipped for
# months without the application's own resources, and nothing failed. That is
# why the --add-data destinations below are spelled out.
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

# Pin appimagetool to a VERSIONED release, never to `continuous`.
#
# `continuous` is a rolling asset: it was republished on 2026-10-04, which
# invalidated the checksum this script used to carry and broke the build with
# "La suma no coincide". A versioned tag does not move, so the checksum stays
# valid and the build stays reproducible. Update APPIMAGETOOL_VERSION and the
# checksum together, deliberately, when you want a newer one.
APPIMAGETOOL_VERSION="1.9.1"
APPIMAGETOOL_URL="https://github.com/AppImage/appimagetool/releases/download/${APPIMAGETOOL_VERSION}/appimagetool-x86_64.AppImage"
APPIMAGETOOL_SHA256="ed4ce84f0d9caff66f50bcca6ff6f35aae54ce8135408b3fa33abfc3cb384eb0"
APPIMAGETOOL="$tmp_dir/appimagetool"

echo "Workspace root is ${workspace_root}"
export ARCH="${ARCH:-x86_64}"
mkdir -p "$dist_dir" "$tmp_dir" "$output_dir"
rm -rf "$dist_dir/tbo" "$appdir" "$APPIMAGETOOL"

# 1. Build the PyInstaller onedir payload (name=tbo on Linux)
#
# --add-data destinations must match how the application resolves its own data
# at runtime, otherwise the bundle builds "successfully" and ships without it.
# src/tbo/resources.py and src/tbo/application.py resolve relative to
# Path(__file__).parent, which for a frozen tbo package is <dist>/_internal/tbo:
#
#   tbo/resources     -> _internal/tbo/resources     find_icon() / UI icons
#   tbo/translations  -> _internal/tbo/translations  TRANSLATION_DIRS[0]
#   data/doodle       -> _internal/data/doodle       _candidate_roots()[0]
#
# `--collect-data tbo` would also work but depends on tbo being importable;
# the explicit --add-data form does not.
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
  --add-data "$workspace_root/src/tbo/resources:tbo/resources" \
  --add-data "$workspace_root/src/tbo/translations:tbo/translations" \
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
# The icon filename MUST match Icon= in the .desktop entry. appimagetool refuses
# to build otherwise: "org.tbo.TBO{.png,.svg,.xpm} defined in desktop file but
# not found". The desktop entry uses the reverse-DNS application ID, so the icon
# file has to use it too.
icon_name="org.tbo.TBO"
python "$workspace_root/packaging/generate_icon.py" \
    "$workspace_root/src/tbo/resources/icon.png" png "$appdir/${icon_name}.png"
install -m644 "$appdir/${icon_name}.png" \
    "$appdir/usr/share/icons/hicolor/256x256/apps/${icon_name}.png"
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
