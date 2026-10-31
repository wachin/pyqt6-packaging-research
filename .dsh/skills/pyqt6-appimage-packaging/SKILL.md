---
name: pyqt6-appimage-packaging
description: Build an AppImage for a PyQt6 application - AppDir layout, AppRun, desktop integration, Qt plugin handling, the GLIBC baseline rule, and how to fix bundled external binaries that break inside the AppImage.
whenToUse: Use when creating or fixing an AppImage for a Python/PyQt6 application, or when an AppImage fails to start, shows no icon, or breaks when it launches a bundled external program.
---

# AppImage packaging for a PyQt6 application

Reference implementation (pinned to a commit):
`PYQT6-GENESIS-PACKAGING/dikte-results/_evidence/packaging/build-appimage.sh` — the only AppImage
actually observed in this research. Read it alongside this skill.

**Where this runs:** in GitHub Actions, as a job on `ubuntu-22.04` — the glibc
floor below is the reason for that runner, not a preference. Workflow shape:
`pyqt6-packaging-decisions` §6. The real job:
`my-PyQt6-Apps/TBO-resultados/_evidence/.github/workflows/build.yml`
(`build-appimage`), or `PYQT6-GENESIS-PACKAGING/dikte-results/_evidence/packaging/build-appimage.sh`
for the script it calls.

## 1. AppDir layout

```text
MyApp.AppDir/
├── AppRun                 # executable; the entry point
├── myapp.desktop          # top-level copy, required by appimagetool
├── myapp.png              # top-level icon, required by appimagetool
└── usr/
    ├── bin/myapp          # the PyInstaller onedir executable, or a launcher
    └── share/
        ├── applications/myapp.desktop
        └── icons/hicolor/256x256/apps/myapp.png
```

## 2. AppRun — the part people get wrong

The AppImage is mounted at a **different path on every run**, so `AppRun` must
find its own directory rather than be told one:

```sh
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
exec "$HERE/usr/bin/myapp" "$@"
```

`readlink -f` is what makes this work when `AppRun` is invoked through a
symlink. Keep the AppDir build relative and mount-safe; hardcoded build-machine
paths are the classic failure.

## 3. Build it

```sh
set -eu
APPDIR=MyApp.AppDir

rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin" \
         "$APPDIR/usr/share/applications" \
         "$APPDIR/usr/share/icons/hicolor/256x256/apps"

# The frozen payload (PyInstaller onedir is the observed choice).
cp -r dist/MyApp/. "$APPDIR/usr/bin/"
install -m 0644 myapp.desktop "$APPDIR/myapp.desktop"
install -m 0644 myapp.desktop "$APPDIR/usr/share/applications/myapp.desktop"
install -m 0644 myapp.png     "$APPDIR/myapp.png"
install -m 0644 myapp.png     "$APPDIR/usr/share/icons/hicolor/256x256/apps/myapp.png"
install -m 0755 AppRun        "$APPDIR/AppRun"

ARCH=x86_64 ./appimagetool "$APPDIR" MyApp-x86_64.AppImage
```

Any standalone tree works as that payload — a Nuitka `--standalone` output drops
in exactly like the PyInstaller one; the AppDir does not care which freezer
produced it. PyInstaller is simply the one with observed precedent here.

### Pin and verify appimagetool

Some of the observed implementations download the `continuous` asset at build
time with no version pin and no checksum. Do not copy that: `continuous` is a
rolling asset, and TBO was broken by exactly that when it was republished on
2026-10-04 and the digest it had recorded stopped matching. Pin a **versioned**
release and verify the digest.

Verified working values, from TBO's `packaging/build_appimage.sh`:

```sh
APPIMAGETOOL_VERSION="1.9.1"
APPIMAGETOOL_SHA256="ed4ce84f0d9caff66f50bcca6ff6f35aae54ce8135408b3fa33abfc3cb384eb0"
curl -fsSL -o appimagetool \
  "https://github.com/AppImage/appimagetool/releases/download/${APPIMAGETOOL_VERSION}/appimagetool-x86_64.AppImage"
echo "${APPIMAGETOOL_SHA256}  appimagetool" | sha256sum -c -
chmod +x appimagetool
```

Check the digest against the release you actually download before trusting that
line — it is a fact about one release, not a constant. If it mismatches, stop and
find out why rather than updating the number to make CI green.

`linuxdeploy` with `linuxdeploy-plugin-qt` is the commonly recommended
alternative because it collects Qt plugins automatically. It is **not observed
in any case study here** — if you use it, treat it as unvalidated in this
research and pin/checksum it the same way.

## 4. GLIBC: build on the oldest base you support

This is the highest-confidence finding in the whole Linux area, repeated by
CARA, dikte and pyzo independently:

> Build on the **oldest** distribution you intend to support. A binary built
> against a newer glibc will not run on an older one.

Observed baseline: **Ubuntu 22.04** (`ubuntu-22.04`), used by all three. The
counter-example is also documented: CustomKnight-Creator builds on
`ubuntu-latest`, and that is associated with a crash report on an older system.

So in CI:

```yaml
runs-on: ubuntu-22.04     # not ubuntu-latest
```

`ubuntu-latest` moves. Your compatibility floor should not.

## 5. Bundled external binaries break inside the AppImage

If your application launches a helper binary (ffmpeg, a CLI tool, a model
runner), the AppImage's own bundled libraries can be injected into that child
process through `LD_LIBRARY_PATH` and crash it. The observed fix is to repair the
child's environment rather than fight it:

- unset or restore `LD_LIBRARY_PATH` before launching the bundled helper;
- restore the certificate store path so TLS still works.

Observed implementations: `PYQT6-GENESIS-PACKAGING/dikte-results/_evidence/dikte/integrate.py` and
`PYQT6-GENESIS-PACKAGING/CARA-results/_evidence/app/services/uci_communication_service.py`. Read both
before writing your own — the pattern is short but non-obvious.

Also: if you download a helper at build time, **pin it and verify its SHA-256**
(dikte does this for FFmpeg in `build-windows.ps1`).

## 6. Desktop integration

- `.desktop` must have `Exec=` matching the real executable name, and
  `Icon=` matching the icon name without extension.
- Set `Categories=` and a stable `StartupWMClass` if you want correct taskbar
  grouping.
- Ship an AppStream metainfo file (`<id>.appdata.xml`) if you want to appear in
  software centres. TBO has one; see
  `my-PyQt6-Apps/TBO-resultados/_evidence/packaging/org.tbo.TBO.appdata.xml`.

## 7. Verify before publishing

```bash
chmod +x MyApp-x86_64.AppImage
./MyApp-x86_64.AppImage                       # does the window appear?
./MyApp-x86_64.AppImage --appimage-extract    # inspect what is really inside
# Run on the OLDEST distro you support, in a container:
podman run --rm -v "$PWD:/w:ro" ubuntu:22.04 /w/MyApp-x86_64.AppImage --version
```

Check for: missing Qt platform plugins (`QT_DEBUG_PLUGINS=1`), missing
translation files, and an icon that does not appear in the desktop menu.

## 8. Not verified here

- Only **one** AppImage implementation was observed, so this is narrow evidence.
- `linuxdeploy`/`linuxdeploy-plugin-qt` is recommended by tutorials but not
  implemented by any project studied.
- No project publishes a checksum for its AppImage.

## Related

- Model choice: `pyqt6-packaging-decisions`
- DEB alternative: `pyqt6-deb-packaging`
- Publishing hashes: `pyqt6-release-integrity`
