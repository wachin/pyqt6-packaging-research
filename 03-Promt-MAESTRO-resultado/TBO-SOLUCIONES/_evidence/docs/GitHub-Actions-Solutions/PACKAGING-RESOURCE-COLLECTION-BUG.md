# Packaged but missing: the resource-collection bug

A real defect in this repository, found by running a released artifact rather
than by reading CI. It is written down because the same mistake is easy to repeat
on any platform and in any freezer.

## Symptom

The AppImage started and worked, but printed one error per UI icon:

```text
qt.svg: Cannot open file '.../_internal/tbo/resources/icons/document-new.svg',
        because: No such file or directory
```

No test failed. No build step failed. `build-appimage` was green, and the
artifact had been produced and downloaded for months.

## Root cause

The application resolves its own data relative to `Path(__file__).parent`:

```python
# src/tbo/resources.py
def find_icon() -> Path | None:
    resources_dir = Path(__file__).resolve().parent / "resources"

# src/tbo/application.py
TRANSLATION_DIRS = (
    _package_dir / "translations",                 # <bundle>/tbo/translations
    _package_dir.parent.parent / "translations",
    Path(QLibraryInfo.path(QLibraryInfo.LibraryPath.TranslationsPath)),
)
```

For a frozen `tbo` package, `_package_dir` is the `tbo` directory **inside** the
bundle (`_internal/tbo` for PyInstaller onedir). The build scripts collected the
loose top-level directories instead:

```bash
--add-data "translations:translations"          # -> _internal/translations   (wrong)
```

Nothing was ever placed at `_internal/tbo/`, so the icons and the application
translations could never be found.

## The fix

Collect from the package and land the files where the code looks:

```bash
--add-data "$workspace_root/src/tbo/resources:tbo/resources"
--add-data "$workspace_root/src/tbo/translations:tbo/translations"
```

## Not one bug but three different mechanisms

The same application data was collected three different ways, and only one of
them was right:

| Platform | Freezer | Mechanism | Result |
|---|---|---|---|
| Windows | Nuitka | `--include-package-data=tbo` | correct — collects `tbo/resources`, `tbo/translations`, `tbo/data` |
| macOS | PyInstaller | `--add-data` of loose directories | **missing icons and translations** |
| Linux AppImage | PyInstaller | `--add-data` of loose directories | **missing icons and translations** |

The Windows build worked by accident of choosing a different flag: Nuitka's
`--include-package-data` happens to use the layout the code expects. The two
PyInstaller builds did not, and nothing detected the difference.

This is why "it works on Windows" is not evidence that a bundle is correct.

## Why CI did not catch it

Every job was green. Green means the build command exited 0, not that the bundle
works. Nothing in the pipeline ever launched the artifact.

The general fix is a smoke test that runs the built artifact:

```yaml
- name: Smoke test the AppImage
  run: |
    chmod +x build/output/TBO-*-x86_64.AppImage
    ./build/output/TBO-*-x86_64.AppImage --appimage-extract-and-run --version
```

and, for a GUI application, a check that the expected resources are actually
inside the bundle before it is uploaded:

```bash
test -d _internal/tbo/resources/icons || { echo "icons missing"; exit 1; }
test -d _internal/tbo/translations   || { echo "translations missing"; exit 1; }
```

## The rule to carry forward

When a build command copies application data, the **destination** must match the
path the code reads at runtime — not the path that is convenient to copy from.
Verify it by inspecting the produced bundle or by running it, never by trusting
that the build succeeded.

Related: `../../../../03-Promt-MAESTRO-resultado/MASTER_PYQT6_PACKAGING_GUIDE.md`
in the packaging research repository, section 19 (Resources and Translations) and
section 32 (Common Mistakes).
