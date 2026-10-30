#!/usr/bin/env bash
set -euo pipefail

this_script="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
workspace_root="$(dirname "$(dirname "$this_script")")"
version="$(cat "$workspace_root/VERSION")"
dist_dir="$workspace_root/build/dist"
tmp_dir="$workspace_root/build/tmp"
output_dir="$workspace_root/build/output"
package_dir="$tmp_dir/macos-package"
iconset_dir="$tmp_dir/AppIcon.iconset"
icon_path="$tmp_dir/app-icon.icns"

echo "Workspace root is ${workspace_root}"
export MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-11.0}"
mkdir -p "$dist_dir" "$tmp_dir" "$output_dir"
rm -rf "$dist_dir/LucioIVACalculator" "$dist_dir/LucioIVACalculator.app" "$package_dir" "$iconset_dir" "$icon_path"

if command -v lrelease >/dev/null 2>&1; then
    echo "Compiling translations..."
    for ts_file in "$workspace_root"/translations/*.ts; do
        lrelease "$ts_file" -qm "${ts_file%.ts}.qm"
    done
else
    echo "lrelease not found; using existing .qm files."
fi

python "$workspace_root/scripts/create_macos_icon.py" "$workspace_root/assets/app-icon.svg" "$iconset_dir"
iconutil -c icns "$iconset_dir" -o "$icon_path"

pyinstaller -w -D -y \
  --name LucioIVACalculator \
  --icon "$icon_path" \
  --osx-bundle-identifier org.lucio.iva-calculator \
  --hidden-import=PyQt6.QtCore \
  --hidden-import=PyQt6.QtGui \
  --hidden-import=PyQt6.QtWidgets \
  --hidden-import=PyQt6.QtSvg \
  --add-data "$workspace_root/assets:assets" \
  --add-data "$workspace_root/translations:translations" \
  --add-data "$workspace_root/docs:docs" \
  --distpath "$dist_dir" \
  --specpath "$tmp_dir" \
  --workpath "$tmp_dir" \
  "$workspace_root/main.py"

if [ ! -d "$dist_dir/LucioIVACalculator.app" ]; then
    echo "Expected PyInstaller output was not found: $dist_dir/LucioIVACalculator.app" >&2
    exit 1
fi

mkdir -p "$package_dir"
cp -R "$dist_dir/LucioIVACalculator.app" "$package_dir/"
cp "$workspace_root/LICENSE" "$package_dir/"

rm -f "$output_dir/LucioIVACalculator-${version}-macOS-x64.zip"
ditto -c -k --sequesterRsrc "$package_dir" "$output_dir/LucioIVACalculator-${version}-macOS-x64.zip"

echo "Created $output_dir/LucioIVACalculator-${version}-macOS-x64.zip"
