---
name: pyqt6-deb-packaging
description: Build a correct Debian package for a PyQt6 desktop application - debian/ layout, control fields, debhelper rules, the CI failures that actually happen, and how to audit the built .deb before installing it.
whenToUse: Use when creating or fixing a Debian package (.deb) for a Python/PyQt6 application, or when a dpkg-buildpackage CI job fails or produces an unusable package.
---

# Debian packaging for a PyQt6 application

Grounded in the only `.deb` evidence in this research that was actually built
and installed: TBO. The upstream case studies ship **no `.deb` at all**, so
everything here comes from a real, working package rather than from reading.

Reference files (pinned to a commit):
`03-Promt-MAESTRO-resultado/TBO-SOLUCIONES/_evidence/debian/`

## 1. Layout

```text
debian/
├── control            # metadata + Depends
├── rules              # executable; debhelper instructions
├── changelog          # the version source
├── copyright          # attribution; required for a clean lintian
└── source/format      # "3.0 (quilt)"
```

Keep application code, `pyproject.toml` and `debian/` in the same source tree.
`dpkg-buildpackage` builds from that tree; it is not a wrapper around a wheel.

## 2. `debian/control`

```text
Source: myapp
Section: utils
Priority: optional
Maintainer: Your Name <you@example.com>
Build-Depends: debhelper-compat (= 13), dh-python, python3-all, python3-setuptools, pybuild-plugin-pyproject
Standards-Version: 4.6.2
Rules-Requires-Root: no

Package: myapp
Architecture: all
Depends: ${python3:Depends}, ${misc:Depends}, python3, python3-pyqt6
Recommends: ffmpeg
Description: Short one-line summary
 Longer description here.
```

Notes that matter:

- `Architecture: all` when you ship pure Python and depend on the distro's Qt.
  It must be `any` if you bundle a compiled payload.
- Prefer the distro's `python3-pyqt6` in `Depends` (Model A). If you bundle a
  runtime instead (Model B), you cannot use `Architecture: all` and you must
  disclose the duplication.
- `Recommends:` is the right place for optional external binaries.

## 3. `debian/rules` — and the failure everybody hits

```make
#!/usr/bin/env make -f
%:
	dh $@ --with python3 --buildsystem=pybuild

# Qt GUI tests import PyQt6, which is only a *runtime* dependency, so it is
# absent from the build environment. dh_auto_test therefore fails on a package
# that is perfectly fine. Skip it here and run the tests as a separate CI job.
override_dh_auto_test:
```

This is the single most common CI failure when packaging a Qt application.
`dh_auto_test` runs your `unittest`/`pytest` suite inside the build environment,
the suite imports `PyQt6`, and the build stops. Do not add PyQt6 to
`Build-Depends` to work around it — move the tests out of the package build.

## 4. `debian/changelog`

`dpkg-buildpackage` takes the package version from here, not from
`pyproject.toml`. The top entry must be well-formed:

```text
myapp (2.0.0-1) unstable; urgency=medium

  * New upstream release.

 -- Your Name <you@example.com>  Thu, 01 Jan 2026 00:00:00 +0000
```

The part before the last `-` is the upstream version and must be a valid Debian
version. A developmental version such as `2.0.0.dev0` will cause problems
downstream — sanitize it.

## 5. CI failures that actually happened

Each of these cost real debugging time on TBO:

| Symptom | Cause | Fix |
|---|---|---|
| `No module named build` | `setup-python`'s toolcache interpreter does not have `build`; apt's `python3-build` only helps the system Python | `pip install build setuptools wheel` into the **active** interpreter before `dpkg-buildpackage` |
| Build fails running the test suite | `dh_auto_test` + GUI tests importing PyQt6 | `override_dh_auto_test:` (see §3) |
| `.deb` built but `upload-artifact` finds nothing | `dpkg-buildpackage` writes to the **parent** directory | `mv ../myapp_*.deb ./` before uploading |
| `cp: LICENSE: No such file` | packaging script expects a file the repo never had | commit the licence (or `COPYING`) from the first commit |
| `unrecognized arguments: --verbose` | removed in PyInstaller 6.x | drop it or use `--log-level=DEBUG` |

## 6. Audit the package before installing it

Never `apt install` or `gdebi` a `.deb` you have not inspected. Run this before
every install, and wire it into CI:

```bash
# 1. Static analysis. Do not ignore warnings blindly; read them.
lintian ./myapp_*.deb

# 2. Metadata actually recorded in the package.
dpkg-deb --info ./myapp_*.deb

# 3. File list: check the entry point, installed modules, assets, the .desktop
#    file, AppStream metainfo, icons and translations are all present.
dpkg-deb --contents ./myapp_*.deb

# 4. Dependency resolution without changing the system.
sudo apt-get install --dry-run ./myapp_*.deb

# 5. Install, smoke test, then verify files on disk.
sudo apt-get install -y ./myapp_*.deb
myapp --version
sudo debsums -c myapp     # lists checksum mismatches; silence is success
```

Then uninstall and confirm it leaves nothing behind:
`sudo apt-get remove --purge myapp`.

Check specifically, because these break silently:

- the launcher is executable and on `PATH` (`/usr/bin/myapp`);
- the `.desktop` file is valid and `Exec=` matches the real binary name;
- icons install under `/usr/share/icons/hicolor/<size>/apps/`;
- Qt translation files (`.qm`) are present if you ship them;
- no build artifacts, caches or `__pycache__` leaked into the package.

## 7. What is not verified here

- No upstream case study in this research ships a `.deb`, so there is no corpus
  to compare against — this is a single-project, high-confidence but narrow body
  of evidence.
- Whether Model A or Model B is "better" is a tradeoff, not a finding.
- `lintian` clean is necessary, not sufficient.

## Related

- Model choice: `pyqt6-packaging-decisions`
- AppImage alternative: `pyqt6-appimage-packaging`
- Publishing hashes: `pyqt6-release-integrity`
- Full write-up: `PyQt6-Apps/TBO/DEBIAN-PACKAGING-PYQT6.md` and
  `PyQt6-Apps/TBO/DEBIAN-PACKAGE-AUDIT.md`
