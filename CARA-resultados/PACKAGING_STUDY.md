# Packaging Study: CARA

## 1. Executive Summary

**Scope and evidence.** This is a static investigation of CARA at commit
`6c9164c` (tag `2.8.7`), plus its public GitHub release page and repository
history. No release executable was run. Paths and line numbers below refer to
this checkout unless an external URL is explicitly given.

CARA is a GPL-3.0 chess-game analysis desktop application written in Python
with **PyQt6**. Its present distribution strategy is intentionally simple:
**PyInstaller onedir** bundles for all supported desktop platforms. Windows is
a portable directory distributed as a ZIP; Linux is a portable directory
distributed as a per-architecture tar.gz; macOS is a `.app` distributed as a
ZIP. It is not an installer-based project.

The significant exception is macOS: CARA has a local release script that
Developer ID-signs its PyInstaller `.app`, enables the hardened runtime,
notarizes it, staples the ticket, and creates the final ZIP. The public site
and README claim the official macOS asset is signed and notarized. The tracked
GitHub Actions build workflow does **not** perform signing/notarization or
publish releases; it is manually triggered and uploads artifacts only.

There is no current AppImage, DEB, Windows signing, Windows installer,
Nuitka, checksum/SBOM/attestation, or automatic GitHub Release creation
configuration. Absence here means **not verified from the available
evidence**, not that a maintainer could never perform an unpublished manual
step.

## 2. Project Architecture

| Topic | Verified finding | Evidence |
|---|---|---|
| Name/purpose | CARA — Chess Analysis and Review Application; analyses and reviews chess PGN games with external UCI engines. | `README.md:1,7-11`; `cara.py:1` |
| Language/UI binding | Python; direct `PyQt6` imports, not PySide6 or QtPy. | `requirements.txt:1-5`; `cara.py:57-59` |
| Python support | README says Python 3.8+; packaging CI uses Python 3.11; tests use 3.12. | `README.md:67-69`; workflows `build-*.yml:43-46`, `tests.yml:12-22` |
| Qt requirement | PyQt6 `>=6.6.0`; Linux packaging constrains it to 6.7.1 because 22.04 ARM wheels required it; Windows/macOS workflow additionally installs 6.10.0. Thus there is no single fully locked cross-platform Qt version. | `requirements.txt:1`; `.github/ci/linux-pip-constraints.txt:1-2`; `build-appbundles.yml:46-51` |
| Supported/tested OS | Windows 11, macOS Tahoe 26.2, Linux GNOME/KDE according to README; build outputs Windows x86_64, macOS runner output advertised as Apple Silicon, Linux amd64 and arm64. | `README.md:65-74`; `index.html:1265-66,1290-92,1324-55` |
| Entry point | `cara.py`, guarded by `multiprocessing.freeze_support()` for Windows/PyInstaller worker processes. | `cara.py:122-206` |
| Structure | `app/` contains models, controllers, services, views, config, and resources; `tests/` uses `unittest`; `scripts/` has macOS release automation; three root specs drive PyInstaller. | `.github/CONTRIBUTING.md:7-31`; file tree |
| Dependency/build metadata | Flat `requirements.txt`, no `pyproject.toml`, `setup.py`, `setup.cfg`, Poetry/Pipenv lock, tox, nox, Makefile, or package build metadata found. | root-file inventory; `requirements.txt` |
| Test system | `python -m unittest discover`; Qt headless test runs set `QT_QPA_PLATFORM=offscreen`. | `.github/workflows/tests.yml:29-40` |

This is an application repository, not a Python package published as a wheel.
`pip install -r requirements.txt` and `python cara.py` are the documented
source-development commands (`README.md:121-170`).

## 3. Packaging Overview

```text
Python source + requirements.txt
             |
             +-- Windows: CARA_windows.spec -> PyInstaller onedir -> dist/CARA/
             |              -> ZIP release asset (site link; archive command is not tracked)
             |
             +-- Linux: CARA_linux.spec -> PyInstaller onedir -> dist/CARA/
             |            -> tar.gz amd64/arm64
             |
             +-- macOS: CARA_macos.spec -> PyInstaller onedir + BUNDLE -> dist/CARA.app
                         -> Developer ID/hardened-runtime sign -> notarize -> staple
                         -> ditto ZIP release asset
```

The `EXE(..., exclude_binaries=True)` followed by `COLLECT(...)` in every
spec is the decisive onedir configuration. It produces a launcher plus a
directory of Python, Qt, and data files; there is no `--onefile` equivalent.
The generic PyInstaller-produced Qt binaries/plugins are collected via
PyInstaller's PyQt6 hooks, not by a custom hook in this repository.

Public evidence corroborates the intended releases: the site has direct links
for `CARA.2.8.7.windows.AppBundle.zip`,
`CARA.2.8.7.macOS.AppBundle.zip`, and Linux amd64/arm64 `.tar.gz`
(`index.html:1270-80,1295-1305,1329-51`). GitHub's release page lists release
2.8.7 with six assets, but the web rendering did not enumerate them, so exact
asset contents beyond the four site links are not independently verified.
([GitHub release page](https://github.com/pguntermann/CARA/releases)).

## 4. Windows

### Actual pipeline

`CARA_windows.spec` packages `cara.py` as a GUI application named `CARA`.
The `COLLECT` stage creates `dist/CARA`; the GitHub workflow uploads that
directory as a workflow artifact (`build-appbundles.yml:81-89`). The release
website links a ZIP named `CARA.<version>.windows.AppBundle.zip`, but no ZIP
creation command, installer script, or release-upload workflow is tracked.

```text
cara.py -> Analysis -> PYZ -> CARA.exe (windowed) + COLLECT directory
        -> manual/untracked ZIP/release upload inferred from public asset link
```

The Windows spec supplies `AppIcon.ico` (`CARA_windows.spec:50`) but supplies
no Windows version-resource tuple, UAC manifest, PE company/product/version
metadata, Authenticode identity, timestamp URL, or signing hook.

## 5. PyInstaller

### Spec-file walkthrough

The Windows and Linux specs have the same basic mechanism.

* `Path('app/config').glob('*.json')` at Windows lines 3-5 (Linux 6-9) gathers
  every current configuration JSON. This avoids a stale hand-maintained list
  when styles are added.
* `Analysis(['cara.py'], ...)` identifies the entry script. `datas` adds the
  whole `app/resources` tree and root documentation/configuration files;
  `hiddenimports=['_charset_normalizer']` covers a dynamically found submodule.
  `hookspath=[]`, `runtime_hooks=[]`, and `excludes=[]` show no custom hooks,
  runtime hooks, or intentional module exclusions.
* `PYZ(a.pure)` stores discovered pure Python modules in the PyInstaller Python
  archive. `noarchive=False` confirms that pure modules remain archived.
* `EXE(... exclude_binaries=True, name='CARA')` creates the GUI launcher but
  leaves dependencies for `COLLECT`. `console=False` is the spec equivalent of
  `--windowed/--noconsole`; `debug=False`, `strip=False`, and
  `disable_windowed_traceback=False` are explicit.
* `COLLECT(exe, a.binaries, a.datas, name='CARA')` creates the onedir bundle.
  Therefore neither `--onefile` nor an unpack-to-temporary-directory runtime
  is used.

The macOS spec repeats that pattern (`CARA_macos.spec:51-104`) then uses
`BUNDLE(... name='CARA.app')` (`105-116`). It loads the version from
`app/config/config.json`, assigns bundle ID `com.pguntermann.cara` unless
overridden, declares `CFBundleShortVersionString`, `CFBundleVersion`, Retina
support, principal class, and uses `AppIcon.icns`.

### Data/resources and frozen paths

All three specs explicitly copy configuration, application resources,
documentation, license information, engine defaults, and user-settings
template. `app/resources` contains SVG/PNG/ICO/ICNS icons, chess-piece assets,
HTML/CSS/manual images, JSON, an opening database, opening books, PDF assets,
and helper Python data; it is filesystem data, not a Qt `.qrc` collection.
No `.qrc`, `.ts`, or `.qm` file exists in this checkout.

`app/utils/path_resolver.py:17-39` is the important runtime counterpart:
development uses the project root; frozen macOS resolves to
`CARA.app/Contents/Resources`; frozen Windows/other onedir resolves to the
launcher's `_internal` directory. `get_app_resource_path()` simply joins that
root (`195-208`). This is a correct onedir-aware design and does **not** use
`sys._MEIPASS`, which is mainly relevant to PyInstaller onefile extraction.

User-modifiable files are handled separately. On macOS bundles the resolver
always copies/uses `~/Library/Application Support/CARA` to preserve the code
signature (`103-152`). On other platforms it uses writable bundle-root
“portable mode” when possible, otherwise `%APPDATA%/CARA` (Windows) or
`$XDG_DATA_HOME/CARA` / `~/.local/share/CARA` (Unix) (`77-192`).

### Qt components/plugins

PyInstaller's normal PyQt6 collection is relied upon. The specs list no
`--add-binary` Qt libraries, Qt plugin directory, Qt translations, hooks, or
plugin exclusions. It is therefore reasonable to infer that standard
PyInstaller PyQt6 hooks discover the imported Qt modules (Widgets, Gui, Core,
Svg and their dependencies); the final collected plugin list cannot be known
without inspecting a built `dist/` tree, which this study deliberately does
not execute or download. Verify it in a new project with PyInstaller's warn
file/TOC and a clean-machine smoke test.

## 6. Nuitka

Nuitka is not present: no command, config, plugin option, CI installation, or
output reference was found. CARA therefore provides no evidence that it chose
PyInstaller over Nuitka after a measured comparison. PyInstaller was likely
chosen because three spec files and native PyQt6 hooks make packaging direct;
that is a plausible interpretation, not a documented rationale.

For a new PyQt6 project, Nuitka is a reasonable alternative, particularly for
a Windows **standalone** directory when startup and a compiled extension-based
distribution are priorities. It compiles Python modules through C/C++ and
requires an appropriate compiler/toolchain; builds are generally slower and
diagnostics/toolchain management more involved. It has Qt support through its
Qt plugins and standalone/onefile modes, but configuration must be tested on
each target OS. Its onefile mode, like PyInstaller onefile, has extraction
behavior and is not automatically a reputation solution. See the
[Nuitka user manual](https://nuitka.net/doc/user-manual).

| Concern | PyInstaller onedir (CARA) | Nuitka standalone | Practical conclusion |
|---|---|---|---|
| Build speed/setup | Fast/easy; no C compiler normally needed | Compiler/toolchain and longer compile required | PyInstaller lowers initial friction. |
| Startup | No onefile extraction; still imports bundled Python | Often competitive, application-dependent | Measure your real app. |
| Size | Bundles interpreter/Qt; large | Also bundles runtime; size varies | Compare artifacts, not assumptions. |
| Debugging | Python-centric spec, mature hooks | Compile/cache/plugin diagnostics | PyInstaller is usually easier to iterate. |
| Antivirus reputation | Frozen bootloader patterns can be flagged | Different generated binary patterns may be flagged less often in some cases | Correlation only; neither guarantees clean detection. |

## 7. Antivirus / VirusTotal Considerations

### What CARA actually does

* Uses **onedir**, not onefile. This avoids a self-extracting executable, but
  the repository does not claim an antivirus benefit.
* Sets `upx=True` in Windows `EXE` and `COLLECT`
  (`CARA_windows.spec:34-59`). This merely requests UPX where PyInstaller finds
  it; the workflow does not install UPX on Windows, so whether a particular
  Windows CI artifact is compressed is **not verified**. It explicitly
  installs UPX only on macOS and Linux (`build-appbundles.yml:42-44`,
  `build-linux-appbundles.yml:48-58`).
* Embeds a Windows icon but no verified PE version metadata/manifest/signature.
* Does not mention VirusTotal, Defender, SmartScreen, false positives,
  Authenticode, `signtool`, certificates, timestamps, custom bootloaders, or
  reproducible build settings.

The macOS choice is specific: when signing identity is set, it disables UPX
because the author comments that compressed binaries often fail notarization
(`CARA_macos.spec:48-49`). That is evidence about Apple's signing/notary
workflow, not evidence that disabling UPX fixes Windows detections.

### Evidence-based, legitimate guidance

No repository evidence supports a magic false-positive cure or a claim of zero
VirusTotal detections. Reasonable risk-reduction practices for a new project
are: use a stable tool version; prefer onedir/standalone while investigating
onefile-specific findings; avoid optional executable packers unless measured;
give the EXE a legitimate icon and version information; sign Windows binaries
and the outer installer with a timestamped Authenticode certificate; keep a
consistent publisher identity; publish source, release notes, SHA-256 hashes,
and reproducible build instructions; test unsigned and signed candidates; and
submit a confirmed false positive through the affected vendor's official
channel. These improve transparency/reputation or remove common triggers but
cannot guarantee Defender/SmartScreen/VirusTotal outcomes. Never use
obfuscation or suspicious binary mutation as an “AV fix.”

## 8. Windows Installer

No Inno Setup (`.iss`), NSIS (`.nsi`), WiX (`.wxs`), MSI/MSIX, installer
command, or installer artifact is present. CARA distributes a portable ZIP,
not a Windows installer. Consequently there is no uninstall integration,
Start-menu shortcut, file association, elevation/UAC policy, or installer
signing pipeline verified here.

For most polished open-source desktop apps, an **Inno Setup EXE installer**
(or MSIX when its sandbox/update/channel trade-offs fit) plus an optional
portable ZIP is a pragmatic Windows route. Sign both the files installed
inside the package and the final installer. This is a recommendation for a
new project, not a technique implemented by CARA.

## 9. Windows Code Signing

Not implemented in tracked files. `CARA_windows.spec:48` has
`codesign_identity=None`, but that PyInstaller field is not a Windows
Authenticode signing procedure; no `signtool` invocation follows it. There is
also no certificate secret name in a workflow.

Thus the requested sequence is presently:

```text
CARA.exe / portable bundle -> no tracked Authenticode step -> no tracked installer
```

Whether a release ZIP was manually signed outside the repository cannot be
determined from available evidence.

## 10. Linux

The current Linux output is a PyInstaller onedir **App Bundle tarball**, not a
native package. The workflow has amd64 and arm64 matrix rows on
`ubuntu-22.04` and `ubuntu-22.04-arm`, Python 3.11, PyInstaller 6.17.0, and
creates `CARA.<version>.linux.<arch>.AppBundle.tar.gz`
(`build-linux-appbundles.yml:26-109`).

Ubuntu 22.04 is deliberate: comments say an Ubuntu 24.04 build required
`GLIBC_2.38`, which failed on Debian 12 and similar older systems; 22.04's
roughly GLIBC 2.35 baseline targets Debian 12 (~2.36), Ubuntu 22.04+, and
newer systems (`lines 4-13`). This is a good portable-bundle principle:
glibc is backward-compatible in the useful direction, so build against the
oldest supported baseline. It does not promise compatibility with older
distributions, non-glibc distributions, all graphics stacks, or all systems.

The Linux spec removes bundled `libxkbcommon`, `libxkbcommon-x11`, and
`libxkbregistry` (`CARA_linux.spec:37-51`) because they mismatched system
libxcb-xkb/libxkbcommon and caused an observed SIGSEGV on openSUSE Tumbleweed.
At launch, frozen Linux code unsets `GIO_MODULE_DIR`, sets `GIO_USE_VFS=local`,
and on GNOME Wayland defaults Qt to xcb (`cara.py:31-52`); KDE gets a
`QT_QPA_PLATFORMTHEME=gtk3` workaround unless overridden (`71-102`). When
launching a user-selected chess-engine child process, CARA strips bundled
loader/Qt/Python path variables so the external engine uses system libraries
(`app/services/uci_communication_service.py:60-81`). These are valuable
project-specific interoperability fixes, not generic defaults to copy blindly.

The only automated testing is unit tests on `ubuntu-latest` with the offscreen
Qt platform. No workflow unpacks/runs the Linux archive on a clean container,
different distribution, desktop session, or physical architecture beyond the
build runner. Cross-distribution smoke testing is therefore not verified.

## 11. AppImage

**CARA does not produce an AppImage.** No AppDir, `AppRun`, `.desktop`,
AppStream metadata, `appimagetool`, linuxdeploy/plugin-qt, or
appimage-builder configuration exists in the current checkout. Therefore it
does not implement AppImage desktop integration, AppImage RPATH handling, or
AppImage testing.

Do not mislabel CARA's `.tar.gz` as AppImage: a tarball is merely an archive
of a directory and relies on the user launching `./CARA/CARA`
(`README.md:84-93`). By contrast an AppImage is a read-only image made from an
AppDir with an `AppRun` entry point and desktop/icon metadata; see the official
[AppDir specification](https://docs.appimage.org/reference/appdir.html).

## 12. Debian Package

**CARA does not provide a DEB.** There is no `debian/`, `DEBIAN/control`,
`dpkg-deb`, debhelper, `fpm`, `lintian`, package control data, or apt
repository configuration. It therefore neither bundles a private Python/Qt
runtime in a DEB nor declares `python3-pyqt6`-style distribution dependencies.

For a native DEB, those are separate designs:

* A distribution-native package normally installs Python modules under
  `/usr/lib/python3/dist-packages` (or appropriate project location), a
  launcher in `/usr/bin`, and desktop/icon/doc files under `/usr/share`; it
  depends on distro `python3`, `python3-pyqt6`, and other packages. It receives
  distribution security updates and is small, but must match distribution
  versions and policies.
* A private-runtime package behaves more like a bundled app and avoids Python
  dependency variability but is larger and requires more security/update work.

Neither choice can be attributed to CARA.

## 13. macOS

`CARA_macos.spec` creates `dist/CARA.app` with PyInstaller's `BUNDLE` object.
The normal PyInstaller bundle has `Contents/MacOS/CARA`, resources under
`Contents/Resources`, Python/Qt frameworks and plugins as collected by
PyInstaller, and `Info.plist` properties supplied in the spec. The `.icns`
file is `app/resources/icons/AppIcon.icns` (`94,105-116`). The code’s frozen
resource resolver explicitly expects this macOS layout (`path_resolver.py:25-35`).

It creates a **ZIP**, not a DMG or PKG. The signed script uses `ditto -c -k
--norsrc --noextattr --keepParent`; it deliberately avoids AppleDouble
`._*` files because Finder materialization of them broke the signature
(`scripts/build_macos_signed.sh:83-106`). A repository commit explicitly
records that Gatekeeper fix (`e259392`). No Intel/Universal2 architecture
setting is specified (`target_arch=None`); the public page advertises Apple
Silicon. Exact supported macOS CPU coverage must be verified from a real
artifact.

## 14. macOS Code Signing

Tracked local release process:

```text
venv/bin/python + CARA_macos.spec
  -> PyInstaller sign-aware build (identity env var)
  -> codesign --force --deep --options runtime --timestamp --entitlements ...
  -> codesign --verify --deep --strict
```

`build_macos_signed.sh:33-55` requires a local virtualenv and confirms that a
Developer ID identity is in the login Keychain; `62-75` performs and verifies
the deep signing. The identity and team ID shown as defaults are public
identifiers, while the private key is intentionally kept in Keychain. The
entitlements enable unsigned executable memory and disable library validation
(`packaging/macos/entitlements.plist:5-8`); their necessity is not explained
by the source and should be minimized/revalidated for a new application.

Apple documents that Developer ID, hardened runtime, valid signatures for
executables, and secure timestamps are requirements for normal notarization.
([Apple notarization documentation](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution))

## 15. macOS Notarization

The signed script's default flow is fully tracked:

```text
signed CARA.app -> ditto notarization ZIP -> xcrun notarytool submit --wait
                -> xcrun stapler staple + validate CARA.app
                -> final ditto distribution ZIP
```

See `scripts/build_macos_signed.sh:83-112`. It uses a Keychain profile named
by `CARA_NOTARY_PROFILE` (default `CARA`); `CARA_SKIP_NOTARIZE=1` deliberately
permits a sign-only build. Required real-world authority: Apple Developer
Program membership/Developer ID Application certificate and notary-service
credentials stored in Keychain. The workflow exposes no GitHub secret for
this because the signing script is local, not CI-run.

The final ZIP itself is not separately signed; code signing and stapling occur
on the `.app` before ZIP packaging. The project does not create/sign a DMG.

## 16. GitHub Actions

There are three tracked workflows.

| Workflow | Trigger | Work performed | Publication/security boundary |
|---|---|---|---|
| `build-appbundles.yml` | Manual `workflow_dispatch` only | Matrix: `windows-latest` + `CARA_windows.spec`; `macos-latest` + `CARA_macos.spec`; Python 3.11; PyInstaller 6.17.0; upload artifacts. | No release creation, signing, notarization, installer, secret, checksum, or attestation. |
| `build-linux-appbundles.yml` | Manual only | Matrix: Ubuntu 22.04 amd64/arm64; installs system Qt/runtime libs and UPX; uses Linux PyQt6 constraint; builds tar.gz; uploads artifacts. | Same: artifacts only. |
| `tests.yml` | Push/PR to main/master/development | Ubuntu latest, Python 3.12, apt Qt dependencies, unittest under offscreen Qt. | Does not build packages. |

The release website's JavaScript queries GitHub Releases API and disables
download controls if assets are absent (`index.html:1248-52,1512-58,1648-58`).
That is release-asset availability UX, not CI release automation. The release
page confirms a 2.8.7 release and six assets, but its rendered asset list was
unavailable during this inspection. No Actions secrets are referenced, so
**none are identifiable from tracked workflows**. Local macOS environment
variables are `CARA_CODESIGN_IDENTITY`, `CARA_NOTARY_PROFILE`,
`CARA_BUNDLE_IDENTIFIER`, `CARA_ENTITLEMENTS`, and `CARA_SKIP_NOTARIZE`; only
the profile selects credentials stored outside the repo.

## 17. Resource Handling

CARA bundles filesystem resources wholesale through `('app/resources',
'app/resources')` and reads them through `get_app_resource_path`. It bundles
development-facing docs as distributable Help content too. This is simple and
portable across PyInstaller onedir and the macOS BUNDLE, but makes the final
artifact potentially larger and requires carefully excluding any user-writable
state from the signed macOS bundle.

There is no Qt Resource System (`.qrc`) or generated `*_rc.py`. Implications:
development paths and frozen paths are unified by the resolver; an AppImage or
DEB would need to preserve/translate this resource root; Nuitka would need an
equivalent `--include-data-dir=app/resources=app/resources` rule; and resource
paths should never be based blindly on current working directory.

## 18. PyQt6 / Qt Plugins

CARA imports `QtWidgets`, `QtGui`, `QtCore`, and `QtSvg` in application code;
PyInstaller must bundle relevant Qt libraries/platform plugins/image format
plugins through its own hooks. There is no explicit selection of `platforms`,
`imageformats`, `styles`, `iconengines`, TLS, or QML plugins in the repository.
That keeps configuration concise but means bundle completeness depends on the
installed PyInstaller/PyQt6 versions and must be smoke-tested.

The Linux fixes describe genuine Qt deployment pitfalls: its xcb dependencies
and plugin/library compatibility are sensitive; PyInstaller-bundled
`libxkbcommon` was deliberately removed, and GNOME/KDE workarounds exist. A
new project should first use PyInstaller's Qt hooks, then add only
evidence-driven inclusions/exclusions after a clean-environment test.

## 19. Translations

No `QTranslator`, `QLibraryInfo`, `TranslationsPath`, `qtbase_*.qm`, `.qm`,
`.ts`, locale directory, or application i18n system is present. CARA does not
explicitly bundle or load Qt translations. Standard Qt dialogs will therefore
use whatever language Qt/runtime provides; a reliable localized frozen app
would need explicitly selected Qt `*.qm` files and code such as
`QTranslator.load(...)`, then `QApplication.installTranslator(...)`. This
cannot be inferred as an implemented CARA feature.

## 20. Security and Release Integrity

Positive practices: GPL source is public; Python dependencies have minimum
versions; a security reporting policy exists; version is embedded in macOS
bundle metadata; macOS code signing/notarization is thoughtfully scripted;
Apple secrets/cert formats and generated build output are ignored in Git
(`.gitignore:9-33,99-118`).

Gaps: `requirements.txt` has no upper pins/hashes/lock file; Windows/macOS
workflow installs differing PyQt6 versions; no hash-checked requirements;
no SHA-256 release files; no SBOM; no SLSA/artifact attestation; no tag-signing
policy; no signed Windows release; no tracked automatic release pipeline; no
packaged-artifact test. Timestamp-based CI version mode is intentionally
non-reproducible (`build-appbundles.yml:53-79`; Linux equivalent `66-92`).

## 21. Techniques Worth Reusing

* **[HIGHLY RECOMMENDED]** Separate per-OS PyInstaller specs with a deliberate
  `COLLECT` onedir output; this is easy to inspect/debug and avoids onefile
  extraction.
* **[HIGHLY RECOMMENDED]** A central frozen/development resource resolver,
  plus platform-standard user-data fallback; especially never write inside a
  signed macOS app.
* **[HIGHLY RECOMMENDED]** Build Linux portable bundles on the oldest practical
  GLIBC baseline and test them across distributions.
* **[HIGHLY RECOMMENDED]** Sign, hardened-runtime verify, notarize, staple,
  then archive a macOS `.app`, while keeping private keys/credentials out of
  source control.
* **[USEFUL]** Archive Linux onedir outputs with `tar.gz` to preserve executable
  bits and symlinks, and macOS bundles with `ditto` to preserve macOS metadata.
* **[USEFUL]** Test Qt headlessly in CI and use a packaging matrix for target
  OS/architecture.
* **[USEFUL]** Record narrowly scoped Linux compatibility fixes in comments
  next to the code/spec that implements them.

## 22. Techniques Specific to This Project

* **[PROJECT-SPECIFIC]** Excluding `libxkbcommon*`, forcing xcb on selected
  GNOME Wayland sessions, and suppressing Plasma theme integration address
  CARA-observed failures; reproduce the failure before copying.
* **[PROJECT-SPECIFIC]** Sanitizing child-engine loader variables is necessary
  because CARA launches arbitrary UCI binaries; ordinary apps may not launch
  external native executables.
* **[PROJECT-SPECIFIC]** The two broad macOS runtime exception entitlements
  may be necessary for this frozen Qt stack, but Apple advises using only
  necessary exceptions. Audit them per application.
* **[PROJECT-SPECIFIC]** Bundling manual, release notes, license, chess opening
  assets, and user-settings defaults reflects CARA's in-app Help/data model.

## 23. Problems or Weaknesses Found

* **[NOT RECOMMENDED]** Treating `upx=True` as a default Windows setting while
  having no explicit Windows UPX provisioning or AV measurement. Disable it
  for candidate builds unless size results justify it.
* **[REQUIRES FURTHER RESEARCH]** The public site calls Windows a “bundle,” but
  current tracked workflow lacks the Windows ZIP command. Document/publish the
  exact release hand-off.
* **[REQUIRES FURTHER RESEARCH]** Determine final PyInstaller Qt plugin/Qt
  translation inventories from release artifact manifests and clean-machine
  testing.
* **[NOT RECOMMENDED]** Relying only on lower-bound dependencies for a release
  build. Use a reviewed lock/constraints strategy and record exact resolved
  versions.
* **[USEFUL]** Add hash manifests, SBOM/attestation, artifact smoke tests, and
  automatic tag-to-release publishing before considering the pipeline mature.
* **[LEGACY]** Flatpak once existed but was removed by `82f4e8d` (“Removed
  flatpak folder”, 2026-07-23). It must not be described as a current channel.

## 24. Recommended Approach for My PyQt6 Projects

Use onedir/standalone first, build natively per OS, make resources and user
data locations explicit, and select a packaging engine after measuring your
app. For Windows, compare PyInstaller onedir and Nuitka standalone on a clean
VM; add real version metadata, then timestamped Authenticode signing, an Inno
Setup installer, installer signing, hashes, and a GitHub release. For Linux,
offer both an AppImage (self-contained desktop UX) and a native DEB (distro
integration) if you can maintain them. For macOS, create a `.app`, sign nested
code/app with Developer ID + hardened runtime, notarize/staple, then distribute
a ZIP or notarized DMG. Full reusable commands/templates are in
`PYQT6_PACKAGING_TUTORIAL.md`.

## 25. Important Files to Study

| File | Why it matters |
|---|---|
| `CARA_windows.spec` | Windows PyInstaller onedir/data/icon/UPX request. |
| `CARA_linux.spec` | Linux onedir and `libxkbcommon` exclusion. |
| `CARA_macos.spec` | `.app`, Info.plist, identity-aware UPX/sign configuration. |
| `scripts/build_macos_signed.sh` | Actual local sign/notarize/staple/archive sequence. |
| `packaging/macos/entitlements.plist` | Hardened-runtime exceptions. |
| `.github/workflows/build-appbundles.yml` | Manual Windows/macOS artifact builds. |
| `.github/workflows/build-linux-appbundles.yml` | Linux architecture matrix and GLIBC baseline rationale. |
| `.github/workflows/tests.yml` | CI test command and Qt headless setup. |
| `app/utils/path_resolver.py` | Frozen resource and writable-data design. |
| `cara.py` | Linux frozen runtime configuration and multiprocessing support. |
| `index.html` | Public asset names and macOS signing/notarization claim. |

## 26. Commands Used by the Project

Verified tracked commands (adapt paths/environment to your own project):

```bash
# Source/development
pip install -r requirements.txt
python cara.py
python -m unittest discover -s tests -p 'test_*.py' -v

# PyInstaller builds
pyinstaller CARA_windows.spec
pyinstaller CARA_linux.spec
pyinstaller CARA_macos.spec

# Linux archive (inside CI)
(cd dist && tar -czf ../CARA.<version>.linux.<arch>.AppBundle.tar.gz CARA)

# Signed macOS release (on a credentialed Mac)
./scripts/build_macos_signed.sh
```

The signed script additionally uses `security find-identity`, `codesign`,
`ditto`, `xcrun notarytool submit --keychain-profile ... --wait`, `xcrun
stapler staple/validate`, and optional `spctl --assess`.

## 27. Final Conclusions

1. **How CARA packages Windows:** PyInstaller onedir GUI bundle with ICO; it
   is publicly distributed as a portable ZIP, not a verified installer.
2. **PyInstaller/Nuitka:** PyInstaller only; Nuitka is absent. Onedir, not
   onefile. The repository does not document why PyInstaller was chosen.
3. **UPX:** requested in Windows/Linux specs; macOS uses it only for unsigned
   builds. Actual Windows compression is not verified because the workflow
   does not provision UPX there.
4. **Windows signing/installer:** neither is implemented in tracked files.
5. **Linux:** two PyInstaller onedir tar.gz artifacts; no AppImage/DEB. Ubuntu
   22.04 build baseline and carefully targeted runtime workarounds are the
   most instructive Linux work.
6. **macOS:** PyInstaller `.app`, Developer ID signing, hardened runtime,
   notarization and stapling, then a `ditto` ZIP; no DMG.
7. **Qt resources/plugins/translations:** app data is explicitly copied as
   filesystem files; ordinary PyInstaller PyQt6 hooks collect Qt dependencies;
   no explicit Qt translation handling exists.
8. **GitHub Actions:** manual build artifact workflows plus independent unit
   test CI; no release automation/secrets/signing in Actions.
9. **Best lessons:** onedir transparency, path resolver, old Linux baseline,
   archive-format care, macOS signing/notarization. The main additions needed
   for a professional new cross-platform project are reproducibility,
   integrity artifacts, automated release publishing, Windows signing and
   installer infrastructure, and explicit AppImage/DEB plans if those outputs
   are desired.
