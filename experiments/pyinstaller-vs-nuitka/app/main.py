#!/usr/bin/env python3
"""Minimal, deterministic PyQt6 probe application for the packaging experiment.

The application is deliberately tiny and boring. The experiment compares build
*tools* (PyInstaller vs Nuitka, onedir vs onefile), so the application itself
must not be a variable.

What it still exercises, because these are the parts that actually break when
packaging:

* ``QApplication`` + ``QMainWindow`` (QtCore / QtGui / QtWidgets);
* a bundled **data file** (``resources/mark.svg``) loaded at runtime, so that
  ``--add-data`` / ``--include-data-dir`` has to be correct;
* Windows **PE version metadata**, so the arms can be compared on identity;
* an explicit **ready signal**, so an external stopwatch can measure
  process-start -> first-window-visible without guessing.

Usage
-----
    python app/main.py --ready-file out.json --exit-after-ms 1500

``--ready-file`` receives a small JSON document with the timings this process
can observe. The authoritative cold-start number is measured *outside* the
process (see ``measure/measure_startup.ps1``): interpreter start-up is not
observable from inside the process.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

APP_NAME = "PackagingProbe"
APP_VERSION = "1.0.0.0"

# Earliest point this module can timestamp. Everything before it (process
# creation, interpreter start, PyInstaller/Nuitka bootstrap) is invisible here
# and is why the authoritative measurement is taken outside the process.
_PROCESS_T0 = time.perf_counter()


def resource_dir() -> Path:
    """Locate the bundled ``resources`` directory across all four build arms.

    This verifies the candidate instead of assuming one layout, because getting
    this wrong is the single most common packaging failure. It also documents
    the difference in the arms:

    * PyInstaller onefile  -> ``__file__`` lives under a temporary ``_MEIPASS``;
    * PyInstaller onedir   -> ``__file__`` lives under ``_internal/``;
    * Nuitka standalone    -> ``__file__`` lives next to the executable;
    * Nuitka onefile       -> ``__file__`` lives in the extraction directory.

    In all four, ``Path(__file__).parent`` is correct, but the fallbacks make a
    mis-built bundle fail loudly rather than silently render an empty window.
    """
    marker = "mark.svg"
    candidates = [Path(__file__).resolve().parent]

    meipass = getattr(sys, "_MEIPASS", None)
    if meipass:
        candidates.append(Path(meipass))

    candidates.append(Path(sys.executable).resolve().parent)

    for base in candidates:
        if (base / "resources" / marker).is_file():
            return base / "resources"

    tried = "\n".join(f"  - {base / 'resources'}" for base in candidates)
    raise FileNotFoundError(
        f"bundled data file {marker!r} not found. The packaging step did not "
        f"collect the resources directory. Looked in:\n{tried}"
    )


def build_window():
    from PyQt6.QtCore import Qt
    from PyQt6.QtGui import QIcon, QPixmap
    from PyQt6.QtWidgets import QLabel, QMainWindow, QVBoxLayout, QWidget

    resources = resource_dir()
    svg_bytes = (resources / "mark.svg").read_bytes()

    # Load the bundled data through Qt itself, so a missing or corrupt resource
    # is an error rather than a cosmetic difference.
    pixmap = QPixmap()
    if not pixmap.loadFromData(svg_bytes, "SVG"):
        raise RuntimeError(f"failed to load {resources / 'mark.svg'} as SVG")

    window = QMainWindow()
    window.setWindowTitle(f"{APP_NAME} {APP_VERSION}")
    window.setWindowIcon(QIcon(pixmap))

    central = QWidget()
    layout = QVBoxLayout(central)

    badge = QLabel()
    badge.setPixmap(pixmap.scaled(64, 64, Qt.AspectRatioMode.KeepAspectRatio))
    badge.setAlignment(Qt.AlignmentFlag.AlignCenter)

    label = QLabel(f"{APP_NAME} {APP_VERSION}\nfrozen={getattr(sys, 'frozen', False)}")
    label.setAlignment(Qt.AlignmentFlag.AlignCenter)

    layout.addWidget(badge)
    layout.addWidget(label)
    window.setCentralWidget(central)
    window.resize(320, 200)
    return window


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog=APP_NAME, description=__doc__)
    parser.add_argument("--ready-file", type=Path, help="write timings JSON here once the window is visible")
    parser.add_argument("--exit-after-ms", type=int, default=0, help="close automatically after N ms (0 = stay open)")
    parser.add_argument("--version", action="store_true", help="print the version and exit")
    args = parser.parse_args(argv)

    if args.version:
        print(f"{APP_NAME} {APP_VERSION}")
        return 0

    from PyQt6.QtCore import QTimer
    from PyQt6.QtWidgets import QApplication

    t_qt_imported = time.perf_counter()
    app = QApplication(sys.argv[:1])

    window = build_window()
    window.show()

    # show() only queues the request; processEvents() makes the mapping happen
    # before we declare the window visible.
    app.processEvents()
    t_window_visible = time.perf_counter()

    if args.ready_file:
        args.ready_file.write_text(
            json.dumps(
                {
                    "app": APP_NAME,
                    "version": APP_VERSION,
                    "frozen": bool(getattr(sys, "frozen", False)),
                    "compiled": "__compiled__" in globals(),
                    "executable": sys.executable,
                    "resource_dir": str(resource_dir()),
                    "seconds_module_start_to_qt_import": round(t_qt_imported - _PROCESS_T0, 6),
                    "seconds_module_start_to_window_visible": round(t_window_visible - _PROCESS_T0, 6),
                },
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )

    if args.exit_after_ms > 0:
        QTimer.singleShot(args.exit_after_ms, app.quit)

    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
