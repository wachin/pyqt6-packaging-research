#!/usr/bin/env bash
set -euo pipefail

this_script="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
workspace_root="$(dirname "$(dirname "$this_script")")"
dist_dir="$workspace_root/build/dist"
tmp_dir="$workspace_root/build/tmp"
output_dir="$workspace_root/build/output"
app_name="LucioIVACalculator"
icon_path="$workspace_root/assets/app-icon.ico"
desktop_file="$workspace_root/build/LucioIVACalculator.desktop"
dist_binary="$dist_dir/$app_name"
version="$(tr -d '\r\n' < "$workspace_root/VERSION")"
build_variant="${1:-}"
linux_package_suffix="${LINUX_PACKAGE_SUFFIX:-linux}"
if [[ -n "$build_variant" ]]; then
    linux_package_suffix="linux_${build_variant}"
fi
linux_archive="$output_dir/${app_name}-${version}-${linux_package_suffix}.tar.gz"

echo "Workspace root is ${workspace_root}"
echo "Linux package suffix is ${linux_package_suffix}"
mkdir -p "$dist_dir" "$tmp_dir" "$output_dir"

if command -v lrelease >/dev/null 2>&1; then
    echo "Compiling translations..."
    for ts_file in "$workspace_root"/translations/*.ts; do
        lrelease "$ts_file" -qm "${ts_file%.ts}.qm"
    done
else
    echo "lrelease not found; using existing .qm files."
fi

pyinstaller_args=(
  -w
  -F
  -y
  --name "$app_name"
  --hidden-import=PyQt6.QtCore
  --hidden-import=PyQt6.QtGui
  --hidden-import=PyQt6.QtWidgets
  --hidden-import=PyQt6.QtSvg
  --add-data "$workspace_root/assets:assets"
  --add-data "$workspace_root/translations:translations"
  --add-data "$workspace_root/docs:docs"
  --distpath "$dist_dir"
  --specpath "$tmp_dir"
  --workpath "$tmp_dir"
)

if [[ -f "$icon_path" ]]; then
    # PyInstaller accepts --icon here for build parity, but on Linux it warns
    # that the executable icon is ignored. The actual desktop icon comes from
    # the Qt runtime icon plus the installed .desktop entry and theme icon.
    pyinstaller_args+=(--icon "$icon_path")
else
    echo "Linux build icon not found at $icon_path; continuing without --icon."
fi

pyinstaller "${pyinstaller_args[@]}" "$workspace_root/main.py"

if [[ ! -f "$dist_binary" ]]; then
    echo "Expected PyInstaller output was not found: $dist_binary" >&2
    exit 1
fi

if command -v pyi-archive_viewer >/dev/null 2>&1; then
    archive_listing="$tmp_dir/${app_name}-archive.txt"
    pyi-archive_viewer -l "$dist_binary" > "$archive_listing"
    required_resources=(
      "assets/app-icon.svg"
      "assets/app-icon.ico"
      "docs/help_es.html"
      "docs/help_en.html"
      "translations/iva_calculator_en.qm"
    )
    for resource in "${required_resources[@]}"; do
        if ! grep -Fq "$resource" "$archive_listing"; then
            echo "Missing packaged resource in PyInstaller archive: $resource" >&2
            exit 1
        fi
    done
    echo "Verified PyInstaller archive resources for $app_name."
else
    echo "pyi-archive_viewer not found; skipping archive resource verification."
fi

if [[ -f "$desktop_file" ]]; then
    cp "$desktop_file" "$dist_dir/"
fi

if [[ -f "$workspace_root/assets/app-icon.svg" ]]; then
    cp "$workspace_root/assets/app-icon.svg" "$dist_dir/"
fi

rm -f "$linux_archive"
tar -C "$dist_dir" -czf "$linux_archive" \
    "$app_name" \
    "$(basename "$desktop_file")" \
    "app-icon.svg"

echo "Created Linux archive: $linux_archive"
