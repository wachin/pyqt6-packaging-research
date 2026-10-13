#!/usr/bin/env bash
# Build a macOS .app bundle with PyInstaller.
# Mirrors the proven configuration of lucio-iva-calculator (clean VirusTotal).
set -euo pipefail

this_script="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
workspace_root="$(dirname "$(dirname "$this_script")")"
version="$(sed -n 's/.*__version__ = "\([^"]*\)".*/\1/p' "$workspace_root/src/tbo/__init__.py")"
dist_dir="$workspace_root/build/dist"
tmp_dir="$workspace_root/build/tmp"
output_dir="$workspace_root/build/output"
package_dir="$tmp_dir/macos-package"
iconset_dir="$tmp_dir/TBO.iconset"
icon_path="$tmp_dir/TBO.icns"

echo "Workspace root is ${workspace_root}"
export MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-11.0}"
mkdir -p "$dist_dir" "$tmp_dir" "$output_dir"
rm -rf "$dist_dir/TBO" "$dist_dir/TBO.app" "$package_dir" "$iconset_dir" "$icon_path"

python "$workspace_root/packaging/generate_icon.py" \
    "$workspace_root/src/tbo/resources/icon.png" iconset "$iconset_dir"
iconutil -c icns "$iconset_dir" -o "$icon_path"

pyinstaller -w -D -y \
  --name TBO \
  --icon "$icon_path" \
  --osx-bundle-identifier org.tbo.TBO \
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

if [ ! -d "$dist_dir/TBO.app" ]; then
    echo "Expected PyInstaller output was not found: $dist_dir/TBO.app" >&2
    exit 1
fi

mkdir -p "$package_dir"
cp -R "$dist_dir/TBO.app" "$package_dir/"
cp "$workspace_root/COPYING" "$package_dir/"

rm -f "$output_dir/TBO-${version}-macOS-x64.zip"
ditto -c -k --sequesterRsrc "$package_dir" "$output_dir/TBO-${version}-macOS-x64.zip"

echo "Created $output_dir/TBO-${version}-macOS-x64.zip"
