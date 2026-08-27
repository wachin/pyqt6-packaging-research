# Debian package audit — checklist for an AI agent

This file contains the exact commands and checks to run on a built `.deb`
**before** installing it with gdebi or `apt install`. Running these checks
catches problems early instead of seeing Lintian warnings only in gdebi.

---

## 1. Lintian (statical analysis of the package)

```bash
lintian tbo_2.0.0.dev0-1_all.deb
```

`dpkg-buildpackage` already runs Lintian at the end, but running it explicitly
lets you iterate without a full rebuild. Use `--info` for the full explanation
of each tag.

### Common warnings (harmless)

| Lintian tag | Meaning | Fix |
|-------------|---------|-----|
| `initial-upload-closes-no-bugs` | The changelog does not reference a bug number. | Ignore or add a bug reference to `debian/changelog`. |
| `no-manual-page` | `/usr/bin/tbo` is a GUI application without a man page. | Ignore, or add a minimal man page and list it in `debian/tbo.manpages`. |
| `icon-size-and-directory-name-mismatch` | The PNG icon size does not match its hicolor directory name. | Resize the PNG to the correct size during the build (e.g. 48×48 into `hicolor/48x48/apps`). |

All warnings listed above produce `exit 0`; the package is valid.

---

## 2. Inspect the package metadata

```bash
dpkg-deb --info tbo_2.0.0.dev0-1_all.deb
```

This shows the package name, version, architecture, dependencies,
recommendations, and description. Verify that:

- `Architecture: all` (Python package).
- `Depends:` includes `python3-pyqt6`, `python3-pyqt6.qtsvg`.
- `Recommends:` includes `python3-pyqt6.qtpdf` (optional, for PDF export).

---

## 3. Inspect the package contents

```bash
dpkg-deb --contents tbo_2.0.0.dev0-1_all.deb | less
```

Check that the following files are present:

- `./usr/bin/tbo` (the entry point script).
- `./usr/lib/python3/dist-packages/tbo/...` (all Python modules).
- `./usr/share/tbo/doodle/...` (the asset library).
- `./usr/share/applications/org.tbo.TBO.desktop`.
- `./usr/share/metainfo/org.tbo.TBO.appdata.xml`.
- `./usr/share/icons/hicolor/scalable/apps/org.tbo.TBO.svg`.
- `./usr/share/icons/hicolor/48x48/apps/org.tbo.TBO.png`.
- `./usr/share/doc/tbo/...` (copyright, changelog).
- `tbo/translations/tbo_en.qm` and `tbo/translations/tbo_es.qm` (inside the
  Python package).

---

## 4. Verify dependencies without installing

```bash
apt install --dry-run ./tbo_2.0.0.dev0-1_all.deb
```

This resolves the dependency tree on the current system and reports what would
be pulled in, **without changing anything**. If the output says `0 upgraded,
0 newly installed, 0 to remove and 0 not upgraded.` everything is already
satisfied.

---

## 5. Checksums after installation (debsums)

Install `debsums` and run it after the package is installed to verify that the
files on disk match the embedded MD5 checksums:

```bash
sudo apt install debsums
debsums tbo
```

If all files are intact, the output is empty (exit 0). Any mismatch indicates
corruption after installation.

---

## 6. Full checklist before releasing

```bash
# 1. Build
dpkg-buildpackage -b -uc -us

# 2. Lintian (explicit)
lintian tbo_2.0.0.dev0-1_all.deb

# 3. Inspect metadata
dpkg-deb --info tbo_2.0.0.dev0-1_all.deb

# 4. Inspect contents
dpkg-deb --contents tbo_2.0.0.dev0-1_all.deb | less

# 5. Dry-run install (deps)
apt install --dry-run ./tbo_2.0.0.dev0-1_all.deb

# 6. Install and smoke test
sudo apt install ./tbo_2.0.0.dev0-1_all.deb
tbo --help    # or launch the application

# 7. Checksums
sudo apt install debsums
debsums tbo
```

---

## 7. Tools needed

```bash
sudo apt install lintian debsums
```

`lintian` is already a build dependency of `dpkg-buildpackage`; installing it
explicitly guarantees it is available at any time.

---

Follow the checklist in order. If a check fails, stop and fix the issue before
proceeding to the next step.