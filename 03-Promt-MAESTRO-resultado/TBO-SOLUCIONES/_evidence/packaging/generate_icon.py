#!/usr/bin/env python3
"""Generate .ico (Windows), .iconset/.icns (macOS) and 256px .png (AppImage)
icons from the application icon.

Usage:
    generate_icon.py <source-image> ico [<output>]
    generate_icon.py <source-image> iconset [<output-dir>]
    generate_icon.py <source-image> png [<output>]

The iconset and png modes accept an explicit output path so build scripts can
control exactly where the generated files land (previously the iconset was
always written next to the source image, which made the macOS build fail).
"""

import sys
from pathlib import Path

from PIL import Image


def build_ico(source: Path, target: Path) -> None:
    img = Image.open(source)
    sizes = [16, 24, 32, 48, 64, 128, 256]
    images = []
    for size in sizes:
        resized = img.resize((size, size), Image.Resampling.LANCZOS)
        images.append(resized)
    images[0].save(target, format="ICO", sizes=[(i.width, i.height) for i in images])
    print(f"  ICO: {target}")


def build_iconset(source: Path, iconset_dir: Path) -> None:
    iconset_dir.mkdir(parents=True, exist_ok=True)
    # The standard 10-file iconset that `iconutil -c icns` expects.
    names = {
        "icon_16x16.png": 16,
        "icon_16x16@2x.png": 32,
        "icon_32x32.png": 32,
        "icon_32x32@2x.png": 64,
        "icon_128x128.png": 128,
        "icon_128x128@2x.png": 256,
        "icon_256x256.png": 256,
        "icon_256x256@2x.png": 512,
        "icon_512x512.png": 512,
        "icon_512x512@2x.png": 1024,
    }
    img = Image.open(source)
    for filename, size in names.items():
        resized = img.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(iconset_dir / filename)
    print(f"  iconset: {iconset_dir}")


def build_png(source: Path, target: Path, size: int = 256) -> None:
    img = Image.open(source)
    img.resize((size, size), Image.Resampling.LANCZOS).save(target)
    print(f"  PNG: {target}")


def main() -> None:
    if len(sys.argv) < 3:
        sys.exit(f"usage: {sys.argv[0]} <source-image> <ico|iconset|png> [<output>]")
    source = Path(sys.argv[1])
    if not source.is_file():
        sys.exit(f"Source file not found: {source}")
    mode = sys.argv[2]
    output = Path(sys.argv[3]) if len(sys.argv) > 3 else None

    if mode == "ico":
        build_ico(source, output or source.with_suffix(".ico"))
    elif mode == "iconset":
        build_iconset(source, output or source.with_suffix(".iconset"))
    elif mode == "png":
        build_png(source, output or source.with_suffix("-256.png"))
    else:
        sys.exit(f"Unknown mode: {mode}")


if __name__ == "__main__":
    main()