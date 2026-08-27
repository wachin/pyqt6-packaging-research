# TBO — SOLUCIONES APLICADAS A GITHUB ACTIONS (Build executables)

**Proyecto:** [https://github.com/wachin/TBO](https://github.com/wachin/TBO) (editor de cómics en Python/PyQt6)
**Repositorio de investigación:** [https://github.com/wachin/pyqt6-packaging-research](https://github.com/wachin/pyqt6-packaging-research)
**Fecha de esta revisión:** 2026-08-26

Este documento registra las correcciones aplicadas al workflow "Build executables" del repositorio **TBO**, junto con el estado de cada job en GitHub Actions.

---

## Estado general de los jobs

| Job | Estado | Comentario |
|---|---|---|
| `build-wheel` | ✅ Verde | Siempre funcionó |
| `build-deb` | ✅ Verde | **Corregido** (2 fallos resueltos) |
| `build-appimage` | ✅ Verde | **Creado desde cero** (no existía) |
| `build-macos` | ⚠️ Se corrige | Último fallo resuelto (LICENSE→COPYING); falta un nuevo run |
| `build-windows` | ⏳ Pendiente | Fix de versión aplicado; requiere prueba en Windows |
| `build-flatpak` | ⛔ Deshabilitado | Imagen Docker no disponible; no es importante para el proyecto |

---

## Correcciones por job

### 1. `build-deb` — paquete `.deb` (Linux) — ✅ EN VERDE

**Fallos corregidos:**

- **Fallo A: `python3.12: No module named build`**
  - **Causa raíz:** `actions/setup-python` coloca su propio Python en el PATH
    (`/opt/hostedtoolcache/.../python3.12`). El paquete apt `python3-build` instala
    `build` en el Python del sistema (`/usr/bin/python3`), NO en el del toolcache.
    Cuando `pybuild` invoca `python3.12 -m build`, usa el Python del toolcache que
    no tiene el módulo `build`.
  - **Solución (`.github/workflows/build.yml`, job `build-deb`):** añadir un paso
    que instale `build setuptools wheel` en el intérprete activo:
    ```yaml
    - name: Install Python build tooling into the active interpreter
      run: python3 -m pip install build setuptools wheel
    ```
    También se restauraron `python3-build` y `python3-installer` en el apt install.

- **Fallo B: `dh_auto_test` fallaba con `ModuleNotFoundError: No module named 'PyQt6'`**
  - **Causa raíz:** durante el empaquetado, `dh_auto_test` ejecuta
    `python3.12 -m unittest discover -v`, pero los tests importan PyQt6, que es
    dependencia de **runtime** (`python3-pyqt6`), no de **build**. Por eso el
    import falla.
  - **Solución (`debian/rules`):** saltar los tests durante el build del paquete
    (los tests ya corren por separado en `ci.yml`):
    ```makefile
    override_dh_auto_test:
        @echo "Skipping dh_auto_test (Qt GUI tests require a display and PyQt6 at build time)"
    ```

- **Mejora (`debian/control`):** se añadieron `python3-build` y `python3-wheel` a
  `Build-Depends` para que el paquete declare correctamente sus dependencias de
  build en builds Debian locales.

**Archivos modificados:** `.github/workflows/build.yml`, `debian/rules`, `debian/control`

---

### 2. `build-appimage` — AppImage (Linux) — ✅ EN VERDE (nuevo)

No existía ningún pipeline de AppImage en TBO. Se creó siguiendo la guía maestra
(`PYQT6_MASTER_PACKAGING_TUTORIAL.md` §9 AppImage y §10 GLIBC):

**Archivos nuevos:**
- `packaging/build_appimage.sh` — script que:
  1. Construye el payload con PyInstaller **onedir** (`--name tbo`, mismos
     `--hidden-import` y `--add-data` que el build de macOS).
  2. Ensambla el **AppDir** manualmente: `AppRun` (mount-safe), desktop entry,
     icono PNG 256×256 (generado con `generate_icon.py png`), metainfo.
  3. Descarga `appimagetool` con **SHA256 verificado** (pinned) y ejecuta
     `--appimage-extract-and-run` (CI no tiene FUSE).
- `packaging/requirements-linux.txt` — `PyQt6`, `pyinstaller`, `Pillow`.

**Cambios en `.github/workflows/build.yml`:**
- Nuevo job `build-appimage` que corre en **`ubuntu-22.04`** (línea base GLIBC
  conservadora ~2.35) e instala dependencias de sistema para Qt.

---

### 3. `build-macos` — app `.app` (macOS) — ⚠️ Último fallo corregido

**Fallos corregidos (en orden de aparición):**

- **Fallo A: `Iconset not found`**
  - **Causa raíz:** `build_macos.sh` definía `iconset_dir="$tmp_dir/TBO.iconset"`
    pero `generate_icon.py` siempre creaba el iconset junto al archivo fuente
    (`src/tbo/resources/icon.iconset`), porque usaba `source.with_suffix(".iconset")`.
  - **Solución:** `generate_icon.py` ahora acepta un tercer argumento `<output>` y
    `build_macos.sh` le pasa `$iconset_dir` explícitamente.

- **Fallo B: `pyinstaller: error: unrecognized arguments: --verbose`**
  - **Causa raíz:** PyInstaller **6.x eliminó la bandera `--verbose`**.
  - **Solución:** se quitó `--verbose` del comando `pyinstaller` en `build_macos.sh`.

- **Fallo C (último, recién corregido): `cp: .../LICENSE: No such file or directory`**
  - **Causa raíz:** el script copiaba `$workspace_root/LICENSE`, pero TBO usa
    `COPYING` (GPL-3.0), no existe un archivo `LICENSE`.
  - **Solución:** se cambió `LICENSE` → `COPYING` en `build_macos.sh`.
  - **Estado:** requiere ejecutar de nuevo el workflow para confirmar verde.

**Archivos modificados:** `packaging/build_macos.sh`, `packaging/generate_icon.py`

---

### 4. `build-windows` — `.exe` (Windows) — ⏳ PENDIENTE

**Fix aplicado (no confirmado):**
- **Fallo: `FATAL: Invalid version number --file-version='2.0.0.dev0.0'`**
  - **Causa raíz:** la versión en `src/tbo/__init__.py` es `2.0.0.dev0`. El script
    PowerShell hacía `$windowsVersion = "$version.0"` → `2.0.0.dev0.0`, que Nuitka
    rechaza porque `--file-version` exige formato numérico de 4 partes
    (`major.minor.build.revision`).
  - **Solución (`packaging/build_windows.ps1`):** sanitizar la versión extrayendo
    solo la parte numérica y añadiendo `.0`:
    ```powershell
    $numericVersion = if ($version -match '^(\d+(?:\.\d+)*)') { $Matches[1] } else { $version }
    $windowsVersion = "$numericVersion.0"   # 2.0.0.dev0 -> 2.0.0.0
    ```
  - **Otro fix:** `COPYING` en lugar de `LICENSE` (misma causa que macOS).

- **Nota:** el usuario indicó que debe probar el build en Windows localmente
  (`Nota: Para Windows yo usé Nuitka porque me pasó las pruebas en VirusTotal; con
  PyInstaller me daba virus`). Falta confirmar que Nuitka genera el `.exe` con la
  nueva versión.

**Archivos modificados:** `packaging/build_windows.ps1`

---

### 5. `build-flatpak` — Flatpak (Linux) — ⛔ DESHABILITADO

- **Causa:** la imagen Docker `ghcr.io/flathub/flathub-infra:latest` ya no es
  accesible públicamente (`Error response from daemon: manifest unknown`).
- **Decisión:** no es importante para el proyecto, se deshabilitó el job
  (comentado en `.github/workflows/build.yml`) con una nota explicativa.
  Re-enable solo si se identifica una imagen funcional.

---

## Resumen de archivos tocados en TBO

| Archivo | Acción | Job relacionado |
|---|---|---|
| `.github/workflows/build.yml` | Modificado | todos |
| `debian/rules` | Modificado | build-deb |
| `debian/control` | Modificado | build-deb |
| `packaging/build_appimage.sh` | **Nuevo** | build-appimage |
| `packaging/requirements-linux.txt` | **Nuevo** | build-appimage |
| `packaging/build_macos.sh` | Modificado | build-macos |
| `packaging/generate_icon.py` | Modificado | build-macos / appimage / windows |
| `packaging/build_windows.ps1` | Modificado | build-windows |

---

## Cómo probar

1. Ir a [https://github.com/wachin/TBO/actions](https://github.com/wachin/TBO/actions).
2. Click en "Build executables" → "Run workflow".
3. Los jobs `build-wheel`, `build-deb` y `build-appimage` ya pasan (verde).
4. `build-macos` debería pasar tras el fix de `COPYING`.
5. `build-windows` depende de la prueba local en Windows.
6. Los artifacts quedan disponibles para descarga en cada run.

---

## Notas

- El script `packaging/generate_icon.py` además corrigió un **bug latente**: el
  diccionario de tamaños del iconset tenía claves duplicadas que hacían que se
  sobrescribieran los archivos `@2x`, dejando un iconset incompleto. Ahora genera
  los 10 archivos estándar que `iconutil` espera.
- `build_appimage.sh` usa `appimagetool` desde el tag `continuous` pero **con
  SHA256 verificado**, para no romper el build si el binario cambia sin aviso.

---

Dios les bendiga
