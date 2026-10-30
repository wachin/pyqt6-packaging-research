from __future__ import annotations

import sys
from pathlib import Path

from PyQt6.QtCore import QRectF, Qt
from PyQt6.QtGui import QGuiApplication, QImage, QPainter
from PyQt6.QtSvg import QSvgRenderer


def render_icon(svg_path: Path, iconset_dir: Path) -> None:
    app = QGuiApplication.instance() or QGuiApplication(sys.argv)
    renderer = QSvgRenderer(str(svg_path))
    iconset_dir.mkdir(parents=True, exist_ok=True)

    sizes = [
        (16, "16x16"),
        (32, "16x16@2x"),
        (32, "32x32"),
        (64, "32x32@2x"),
        (128, "128x128"),
        (256, "128x128@2x"),
        (256, "256x256"),
        (512, "256x256@2x"),
        (512, "512x512"),
        (1024, "512x512@2x"),
    ]

    for pixels, name in sizes:
        image = QImage(pixels, pixels, QImage.Format.Format_ARGB32)
        image.fill(Qt.GlobalColor.transparent)
        painter = QPainter(image)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing, True)
        renderer.render(painter, QRectF(0, 0, pixels, pixels))
        painter.end()
        image.save(str(iconset_dir / f"icon_{name}.png"), "PNG")

    app.quit()


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("Usage: create_macos_icon.py app-icon.svg AppIcon.iconset")
    render_icon(Path(sys.argv[1]), Path(sys.argv[2]))
