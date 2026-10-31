# Practical PyQt6 Packaging Tutorial

Companion to the TBO packaging study, pinned at `797011a`. This one is organised
around the three things TBO gets right that are hard to get right, and the one
thing it gets wrong that is easy to get wrong everywhere:

1. the **shape of the archive** you publish,
2. the **glibc floor** you choose for Linux,
3. the **native-dependency** Debian package,
4. and the **records** that make an antivirus claim checkable six months later.

Snippets adapted from the project are marked `[TEMPLATE — MUST BE TESTED]`.

---

## 1. The Build Contract

Before the scripts, decide and write down:

| Decision | TBO's answer | Why it matters |
|---|---|---|
| Which glibc do you support? | 2.35 (`ubuntu-22.04`) | It is set by the builder, not the code |
| Native Qt or bundled Qt for Linux packages? | native (`.deb` depends on `python3-pyqt6`) | 366 KB instead of 71 MB |
| Freezer per platform | Nuitka on Windows, PyInstaller elsewhere | measured, see section 7 |
| Is anything signed? | no | says so, with the consequence |
| Where does the version live? | `src/<pkg>/__init__.py` `__version__` | one source for four artifacts |

The version rule deserves a note because it bit this project: Nuitka needs a
**four-part numeric** version for `--file-version`. `2.0.0.dev0` makes the PE
resource invalid and the build fails. Derive the numeric form; keep the display
form:

```python
# [TEMPLATE — MUST BE TESTED]
import re
version = "2.0.0.dev0"
numeric = re.match(r"^\d+(?:\.\d+)*", version).group(0)   # "2.0.0"
windows_version = numeric + ".0"                            # "2.0.0.0"
```

---

## 2. Prepare the Application

**One resource resolver.** Every path the app reads at runtime should come from a
single function, so switching freeze layout is one edit instead of a hunt.

**A resource location that is identical when frozen and when installed from a
`.deb`.** TBO ships the doodle tree into the frozen bundle as `tbo/data/doodle`
and installs it as `share/tbo/doodle` under the prefix, and the resolver looks in
both. That is what lets the same code serve the AppImage, the portable ZIP and
the distribution package.

**A non-interactive entry point**, because you will want to run the artifact in
CI:

```python
# [TEMPLATE — MUST BE TESTED]
def main(argv=None) -> int:
    app = QApplication(argv or sys.argv)
    if "--smoke-test" in sys.argv:
        app.setWindowIcon(load_app_icon())      # proves a shipped icon loads
        load_translation(app, "en")             # proves a shipped .qm loads
        return 0
    ...
```

Place the check **after** `QApplication`: before it, the test only proves that
Python started, which is not the part that breaks in a frozen bundle.

**Translations compiled at build time.** Keep `.ts`, generate `.qm` with
`lrelease` during the build.

---

## 3. The Shape of the Archive

This is the section TBO paid for three times, and it generalises to every
platform you ship.

### Rule 1: forward slashes, always

`APPNOTE.TXT` §4.4.17.1 requires `/` as the entry separator. Windows tools
disagree:

| Tool | Separator it writes |
|---|---|
| `Compress-Archive` (Windows PowerShell 5.1) | `\` |
| `ZipFile::CreateFromDirectory` (Windows PowerShell 5.1) | `\` |
| `Compress-Archive` / .NET zip APIs on .NET Core (PowerShell 7) | `/` |
| CPython `zipfile` | `/` (normalised in `ZipInfo.__init__`) |
| `tar` on Linux/macOS | `/` |

The failure is silent on Windows and destructive everywhere else: on Linux and
macOS, `unzip` treats `\` as an ordinary character in the filename, so a tree
unpacks as flat files literally named `TBO\python312.dll`. TBO shipped exactly
that once.

**Do not try to fix it with a .NET API.** The behaviour is governed by the
`Switch.System.IO.Compression.ZipFile.UseBackslash` AppContext switch, which
defaults to the old (wrong) behaviour unless the *host* application targets .NET
Framework 4.6.1 or later. Windows PowerShell 5.1 does not. Reading
`ZipArchiveEntry.FullName` afterwards is subject to the same switch, so a
PowerShell-side check can report a conformant archive as broken.

Build the archive in a language you can test:

```python
# [TEMPLATE — MUST BE TESTED]
def arcname(path: Path, root: Path, prefix: str = "") -> str:
    parts = path.relative_to(root).parts
    if any("\\" in p for p in parts):
        raise ValueError(f"literal backslash in a path component: {parts}")
    name = "/".join(parts)
    return f"{prefix}/{name}" if prefix else name

with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as z:
    for p in sorted(root.rglob("*")):
        if p.is_file():
            z.write(p, arcname(p, root, prefix))

# post-condition: read back what you actually wrote
with zipfile.ZipFile(target) as z:
    names = z.namelist()
assert not [n for n in names if "\\" in n], "non-conformant separators"
```

### Rule 2: one top-level folder, and nothing loose beside it

```text
BAD                          GOOD
TBO/                         TBO-1.2.3-Windows-x64-portable/
COPYING                        COPYING
TBO.exe                        TBO.exe
PyQt6/                         PyQt6/
```

The bad shape drops a folder **and** a stray file into whatever directory the
user extracted into. Name the folder after the archive so a user with three
versions on disk can tell them apart.

### Rule 3: check the layout, not just that the file exists

A packaging step that only asserts "the archive was created" will publish a
nested or misnamed tree happily. TBO's helper takes two extra options for this:

```powershell
python make_portable_zip.py $staging $zip `
  --prefix "TBO-$version-Windows-x64-portable" `
  --require TBO.exe --require COPYING
```

- `--prefix` names the single top-level folder;
- `--require` asserts that `<prefix>/FILE` is present in the archive as written,
  and deletes the archive and fails if it is not.

`--require` is what makes a staging mistake fatal. In TBO the staging step used
`Copy-Item $dir $dest -Recurse`, which copies the *folder* into an existing
destination, giving `staging\TBO\<files>`; the archive was nested and the licence
sat beside it. With `--require TBO.exe` that layout cannot ship: there is no
`<prefix>/TBO.exe`, so the build stops.

### The PowerShell trap, stated once

```powershell
Copy-Item $source $dest -Recurse         # copies the FOLDER into $dest
Copy-Item "$source\*" $dest -Recurse     # copies the CONTENTS
```

The second is what you almost always want when staging a payload.

---

## 4. Choose the glibc Floor on Purpose

A frozen Linux binary requires at least the glibc of the machine that built it.
Build on Ubuntu 24.04 (glibc 2.39) and the binary will not start on Debian 12
(2.36), Ubuntu 22.04 (2.35) or anything older.

```yaml
# [TEMPLATE — MUST BE TESTED]
build-appimage:
  runs-on: ubuntu-22.04        # the FLOOR you support, not the newest
```

TBO does this for the AppImage (`build.yml:75-76`) and documents the reason in
the script header. Whatever floor you pick, state it in the release notes:
"works on Linux" is not a specification.

The inverse mistake is the common one: build on `ubuntu-latest`, test on
`ubuntu-latest`, and discover the problem when a user on Debian stable reports
`GLIBC_2.38 not found`.

---

## 5. AppImage

TBO's recipe, condensed from `packaging/build_appimage.sh`:

```text
1. PyInstaller --onedir                              -> build/dist/TBO/
2. build AppDir by hand:
     AppDir/AppRun                                   (executable shell script)
     AppDir/org.app.App.desktop                       Icon=org.app.App
     AppDir/org.app.App.png                           (256x256)
     AppDir/usr/bin/<payload>
3. appimagetool (PINNED, checksum-verified) AppDir out.AppImage
```

### Pin the tool, never `continuous`

```bash
APPIMAGETOOL_VERSION="1.9.1"
APPIMAGETOOL_URL="https://github.com/AppImage/appimagetool/releases/download/${APPIMAGETOOL_VERSION}/appimagetool-x86_64.AppImage"
APPIMAGETOOL_SHA256="ed4ce84f0d9caff66f50bcca6ff6f35aae54ce8135408b3fa33abfc3cb384eb0"
curl -fsSL "$APPIMAGETOOL_URL" -o "$APPIMAGETOOL"
echo "$APPIMAGETOOL_SHA256  $APPIMAGETOOL" | sha256sum -c -
chmod +x "$APPIMAGETOOL"
```

TBO was using the `continuous` tag and the asset was republished under it, so the
checksum changed and CI failed. That is the whole argument for versioned pins:
`continuous` is a moving target that looks like a stable URL.

### `--add-data` destinations must match runtime resolution

The first working TBO AppImage shipped without its UI icons and translations and
produced a stream of `qt.svg` errors. The fix was two arguments:

```
--add-data "<repo>/src/tbo/resources:tbo/resources"
--add-data "<repo>/translations:tbo/translations"
```

The destination on the right is what the code sees at runtime; the source on the
left is where it lives in the repository. They are almost never the same string,
and a wrong destination builds green.

### Desktop integration

```ini
[Desktop Entry]
Type=Application
Name=...
Exec=...
Icon=org.tbo.TBO          ; must equal the icon filename, without extension
Categories=Graphics;
StartupWMClass=org.tbo.TBO
```

Ship an AppStream file too (`org.tbo.TBO.appdata.xml`) if you want software
centres to show the app.

---

## 6. Debian Package: the Native Dependency Model

TBO's `.deb` is 366 KB because it does not bundle Qt. The skeleton:

```text
debian/
├── control          Build-Depends, Depends, Recommends
├── rules            debhelper rules
├── changelog        drives the version
├── copyright        real attribution, GPL text
└── source/format    3.0 (quilt)
```

`debian/control`, the important lines:

```text
Package: tbo
Architecture: all
Depends: ${python3:Depends}, ${misc:Depends},
         python3-pyqt6, python3-pyqt6.qtsvg
Recommends: python3-pyqt6.qtpdf
```

`Architecture: all` is correct **because** the Qt is not bundled — the package
contains only Python. If you bundle Qt, it is `amd64`/`arm64` and 20 MB larger.

### The one rule that surprises people

`dh_auto_test` runs your test suite during the build. A Qt GUI test aborts
headless, so the package build fails for a reason that has nothing to do with the
package. TBO overrides it:

```make
override_dh_auto_test:
	# Qt GUI tests abort without a display; they run in their own CI job.
```

The better long-term answer is `xvfb-run -a python3 -m pytest`, which lets the
tests run during the build. The override is the pragmatic answer.

### Audit the package after building it

```bash
dpkg-deb -I tbo_*.deb        # control fields, dependencies, size
dpkg-deb -c tbo_*.deb        # every file, with mode and owner
lintian tbo_*.deb            # packaging nits
```

Then install it into a container and run the installed entry point. The audit
TBO actually performed is
`03-Promt-MAESTRO-resultado/TBO-SOLUCIONES/DEBIAN-PACKAGE-AUDIT.md`.

Full detail lives in the `pyqt6-deb-packaging` Skill; there is no need to
improvise a `debian/` directory from first principles.

---

## 7. Measuring a Freezer Change

If antivirus results are the reason you are considering Nuitka, do the
measurement properly or do not draw the conclusion.

### Hold everything constant

TBO's four arms differed **only** in freezer and layout:

- same source, same commit, same version;
- same PE metadata (company, product, description, both versions, copyright);
- all unsigned;
- UPX disabled in both;
- same application data.

### Scan every arm, and keep the receipt

```text
arm                       result     sha256 (recorded)
Nuitka standalone         0 / 71     9f8a79c1...
PyInstaller onedir        3 / 73     e4fd5035...
PyInstaller onefile       3 / 73     94ba5787...
PyInstaller rebuilt         2 / 70   107d539b...
```

Keep, for each artifact:

1. the SHA-256,
2. the report URL,
3. a screenshot of the report page,
4. the date.

Without the hash the claim cannot be re-checked later, because VirusTotal
identifies files by digest. A "0/68" with no hash is an anecdote.

### What the numbers do and do not mean

From the recorded data:

- all major engines clean;
- the detections generic (`Malicious`, `BehavesLike.…`, a family named after
  nothing);
- related builds disagreeing with each other — the signature of an unstable
  heuristic, not of a signature matching malware;
- `onedir` flagged as well as `onefile` — so the self-extraction step is not the
  cause;
- a bootloader rebuilt from source moved 3/73 to 2/70 — so the shared stub is not
  the cause either.

What is left is the embedded CPython runtime and the archive format, which you do
not control. And still: **n = 1 application, one build each.** Report it as a
lead.

### The wrapper is a separate arm

Everything above compares freezers. If your application also ships an installer,
that is a second variable, and a clean `.exe` does not cover it.

Measured on a sibling application on 2026-10-31: one Nuitka payload, four
wrappers, same everything else.

| NSIS | Script shape | Installer | VirusTotal |
|---|---|---|---|
| 3.13.0 | minimal: MUI2, 5 pages, 1 section, no bitmaps | 34.8 MB | 1/70 |
| 3.13.0 | same, ZLIB | 43.6 MB | 1/69 |
| 3.10.0 | same, ZLIB | 43.6 MB | 1/69 |
| 3.12.0 | six pages, four sections, bitmaps, `XPStyle` | 43.8 MB | **0/67** |

The portable ZIP of the same payload was clean in every round, and changing the
compressor moved the file by 8.8 MB without moving the verdict. What moved it was
the shape of the installer.

So measure the artifact you actually ship. If you ship an installer, the freezer
arm and the installer arm are two different experiments, and a result for one
says nothing about the other.

### Do not

- rebuild to mutate the binary until an engine stops complaining;
- claim a clean score is permanent;
- treat VirusTotal as an authority rather than an aggregator.

If a detection is wrong, report it to the vendor through their published
false-positive channel.

---

## 8. Multi-Platform CI Without Wasting It

TBO's shape:

```yaml
on:
  workflow_dispatch:        # packaging is expensive; run it on purpose
jobs:
  build-wheel:              # sdist + wheel
  build-deb:                # dpkg-buildpackage
  build-appimage:           # ubuntu-22.04, pinned tool
  build-windows:            # Nuitka + make_portable_zip.py
  build-macos:              # PyInstaller .app
```

Two improvements worth making on top of it:

**Add an artifact smoke test per platform.** Nothing in TBO's pipeline downloads
what it just built and runs it, so a bundle missing its Qt plugins gets a green
tick. The shape that works is `build_* -> test_*`, where the test job has none of
the build environment.

```yaml
# [TEMPLATE — MUST BE TESTED]
  test-appimage:
    needs: build-appimage
    runs-on: ubuntu-22.04
    steps:
      - uses: actions/download-artifact@v5
        with: {name: appimage}
      - run: |
          chmod +x ./*.AppImage
          ./*.AppImage --appimage-extract-and-run --smoke-test
```

**Pin third-party actions by commit SHA**, not by `@v5`. A retagged action
changes what runs in your repository without any commit of yours. This is what
the `pyqt6-release-integrity` Skill covers.

**Leave tombstones for disabled jobs:**

```yaml
# build-flatpak is DISABLED: ghcr.io/flathub/flathub-infra:latest is no longer
# publicly accessible. Re-enable when a working image is identified.
```

A job deleted silently looks like a project that never tried.

---

## 9. Release Integrity

What a user should be able to do with your release:

```bash
sha256sum -c SHA256SUMS      # is this the file you built?
```

So publish, next to the artifacts:

```text
SHA256SUMS                   one line per artifact
docs/…/screenshot.png        the scan evidence, if you cite a scan
```

and name the exact artifacts in the release notes. TBO's `docs/virustotal/`
directory is the model: four links, four digests, four screenshots, plus a note
that some engines cannot process an AppImage or a `.deb` at all and therefore
never judged those files.

**The mistake to avoid:** publishing assets that your CI does not produce. TBO's
published Windows ZIP and macOS ZIP were assembled by hand, so they do not match
what the workflow emits for the same commit. That is a reproducibility claim you
cannot make afterwards, even though the recipe is public.

---

## 10. Artifact-Level Checklist

```text
[ ] Every ZIP has forward-slash separators (assert it, do not hope).
[ ] Every archive extracts to ONE top-level folder, named after the artifact,
    with no loose files beside it — including the licence.
[ ] The folder contains the licence, README and the executable.
[ ] The glibc floor matches the oldest distribution you claim to support.
[ ] The .deb depends on the distribution's Qt, or bundles it and says so.
[ ] The .deb installs and the installed entry point runs.
[ ] The AppImage runs with --appimage-extract-and-run on a machine without FUSE.
[ ] The AppImage finds its icons: no qt.svg warnings on start.
[ ] The macOS .app is signed and notarized, or the notes say it is not.
[ ] SHA256SUMS is generated from the final files and published beside them.
[ ] If antivirus results are quoted, the SHA-256 of each scanned file is quoted
    with them.
[ ] The published assets are the ones CI produced.
```

---

## 11. What Is NOT Verified Here

- **That Nuitka reduces detections generally.** Measured on one application. The
  shape of the data supports the reading; it does not establish a rule.
- **That the AppImage tooling still works with the pinned 1.9.1 digest.** The pin
  was correct when it was made; a future republish under a *versioned* tag would
  be unusual but is not impossible.
- **That the `--prefix` / `--require` helper covers every archive mistake.** It
  covers separators, one-top-level-folder and required files. It does not check
  permissions, timestamps or compression.
- **That the `debian/rules` override is right for your project.** It skips GUI
  tests during the package build; whether that is acceptable depends on whether
  you run them elsewhere.
- **That any `[TEMPLATE — MUST BE TESTED]` snippet here compiles as written.**
  They are adaptations, not copies.
