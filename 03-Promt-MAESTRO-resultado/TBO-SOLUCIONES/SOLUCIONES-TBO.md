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
| `build-macos` | ✅ Verde | **Corregido** (3 fallos resueltos, incluido el de la licencia) |
| `build-windows` | ✅ Verde | **Corregido** (versión + licencia) |
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
    `COPYING` (GPL-3.0), no existía un archivo `LICENSE`.
  - **Solución:** se cambió `LICENSE` → `COPYING` en `build_macos.sh` y se creó
    también el archivo `LICENSE` en el repositorio (ver sección "Requisito
    imprescindible: el archivo de licencia").
  - **Estado:** ✅ confirmado verde (todos los builds pasan).

**Archivos modificados:** `packaging/build_macos.sh`, `packaging/generate_icon.py`

---

### 4. `build-windows` — `.exe` (Windows) — ✅ EN VERDE

**Fallos corregidos:**
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
  - **Otro fix:** `COPYING` en lugar de `LICENSE` (misma causa que macOS; ver
    sección "Requisito imprescindible: el archivo de licencia").

- **Nota:** los builds de Windows ahora pasan correctamente en GitHub Actions.

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

## ⚠️ Requisito imprescindible: el archivo de licencia

**Es imprescindible tener el archivo de licencia (`LICENSE` o `COPYING`) en el
repositorio ANTES de lanzar los builds.** No lo olvides como me pasó a mí.

### Por qué

Los scripts de empaquetado **incrustan la licencia dentro del artefacto final**:

- `packaging/build_macos.sh` copia la licencia dentro del `.app`/ZIP de macOS.
- `packaging/build_windows.ps1` copia la licencia dentro del ZIP portable de
  Windows.

Si el archivo no existe, el build **falla al final**, cuando todo lo demás ya se
construyó bien. En TBO, el build de macOS llegó hasta "Build complete!" y luego
falló con:

```
cp: /Users/runner/work/TBO/TBO/LICENSE: No such file or directory
Error: Process completed with exit code 1.
```

porque el repositorio solo tenía `COPYING` (GPL-3.0) y no `LICENSE`.

### Mi caso (para que no te pase lo mismo)

1. Olvidé crear el archivo `LICENSE` en el repositorio → el build de macOS falló
   al final.
2. Cuando lo creé, lo puse inicialmente en **la carpeta equivocada**:
   - ❌ `/home/wachin/Dev3/TBO/LICENSE` (mi clon personal)
   - ✅ `/home/wachin/Dev3/pyqt6-packaging-research/PyQt6-Apps/TBO/LICENSE`
     (el sub-módulo que es el que usa GitHub Actions)
3. Al hacer `git add .` en el sub-módulo me decía "nothing to commit" porque el
   archivo no estaba en esa carpeta.
4. Al copiarlo al sub-módulo, commitear y pushear, todos los builds pasaron.

### Consejos

- Crea el archivo de licencia **desde el primer commit**, no lo dejes para el
  final.
- Usa un nombre estándar: `LICENSE` (o `COPYING` si tu proyecto ya lo usa).
- Los scripts deben referenciar el nombre **real** del archivo. Si tu proyecto
  usa `COPYING`, ajusta los scripts o crea también `LICENSE`.
- Verifica antes de lanzar el build:
  ```bash
  git ls-files | grep -iE '^(license|copying)(\.|$)'
  ```
- En un proyecto con sub-módulos, asegúrate de poner la licencia en el
  sub-módulo correcto (el que está dentro del repositorio que usa GitHub
  Actions), no en un clon externo.

---

## Cómo probar

1. Ir a [https://github.com/wachin/TBO/actions](https://github.com/wachin/TBO/actions).
2. Click en "Build executables" → "Run workflow".
3. **Todos los jobs pasan en verde:** `build-wheel`, `build-deb`,
   `build-appimage`, `build-macos` y `build-windows`.
4. Los artifacts quedan disponibles para descarga en cada run.

---

## Notas

- El script `packaging/generate_icon.py` además corrigió un **bug latente**: el
  diccionario de tamaños del iconset tenía claves duplicadas que hacían que se
  sobrescribieran los archivos `@2x`, dejando un iconset incompleto. Ahora genera
  los 10 archivos estándar que `iconutil` espera.
- `build_appimage.sh` usa `appimagetool` desde el tag `continuous` pero **con
  SHA256 verificado**, para no romper el build si el binario cambia sin aviso.

---

## Correcciones posteriores (2026-08-26)

Tras confirmar que todos los jobs pasaban, se corrigieron dos avisos/fallos
adicionales que aparecían en el run:

### 6. El `.deb` se construía pero NO se subía como artifact

**Síntoma:** el job `build-deb` estaba en verde, pero GitHub Actions mostraba:

```
No files were found with the provided path: tbo_*.deb tbo_*.buildinfo tbo_*.changes.
No artifacts will be uploaded.
```

y en la lista de ejecutables descargables solo aparecían `tbo-linux-appimage`,
`tbo-macos` y `tbo-windows` — faltaba el `.deb`.

**Causa raíz:** `dpkg-buildpackage` escribe los archivos generados (`.deb`,
`.buildinfo`, `.changes`) en el **directorio padre** del árbol fuente
(`/home/runner/work/TBO/`), NO en el workspace
(`/home/runner/work/TBO/TBO/`) donde `upload-artifact` busca por defecto.

**Solución (`.github/workflows/build.yml`, job `build-deb`):** mover los
artefactos al workspace antes de subirlos:

```yaml
- name: Build .deb
  run: |
    dpkg-buildpackage -b -uc -us
    # dpkg-buildpackage writes to the PARENT directory; move them here.
    mv ../tbo_*.deb ../tbo_*.buildinfo ../tbo_*.changes ./
```

### 7. Avisos de Node.js 20 obsoleto en las actions

**Síntoma:** los 5 jobs mostraban avisos (warnings) como:

```
Node.js 20 is deprecated. The following actions target Node.js 20 but are
being forced to run on Node.js 24: actions/checkout@v4,
actions/setup-python@v5, actions/upload-artifact@v4.
```

**Causa raíz:** las versiones `v4`/`v5` de esas acciones usan Node.js 20, que
GitHub ya no soporta de forma nativa en sus runners (desde 2025-09).

**Solución (`.github/workflows/build.yml` y `ci.yml`):** subir las acciones a
las versiones que usan Node.js 24:

| Acción | Antes | Después |
|---|---|---|
| `actions/checkout` | `@v4` | `@v5` |
| `actions/setup-python` | `@v5` | `@v6` |
| `actions/upload-artifact` | `@v4` | `@v5` |

---

## 8. Auditoría del paquete `.deb` antes de instalarlo

Además de que el job `build-deb` pase en verde, es buena práctica **auditar el
`.deb` generado antes de instalarlo** con `gdebi` o `apt install`. Eso detecta
problemas temprano en lugar de ver los avisos de Lintian solo en el instalador
gráfico.

TBO incluye el checklist completo, listo para pasar a un agente de IA o a la
terminal:

**`DEBIAN-PACKAGE-AUDIT.md`** (en el repositorio TBO, y copiado aquí en
`03-Promt-MAESTRO-resultado/TBO-SOLUCIONES/DEBIAN-PACKAGE-AUDIT.md`).

Resumen del checklist (en orden):

1. **Lintian** (análisis estático): `lintian tbo_2.0.0.dev0-1_all.deb`
   - Avisos típicos inofensivos: `initial-upload-closes-no-bugs`,
     `no-manual-page`, `icon-size-and-directory-name-mismatch`. Todos producen
     `exit 0`.
2. **Inspeccionar metadatos**: `dpkg-deb --info tbo_2.0.0.dev0-1_all.deb`
   - Verificar `Architecture: all`, `Depends: python3-pyqt6,
     python3-pyqt6.qtsvg`, `Recommends: python3-pyqt6.qtpdf`.
3. **Inspeccionar contenido**: `dpkg-deb --contents tbo_2.0.0.dev0-1_all.deb`
   - Comprobar `/usr/bin/tbo`, los módulos Python en
     `/usr/lib/python3/dist-packages/tbo/`, los assets en
     `/usr/share/tbo/doodle/`, el `.desktop`, el metainfo, el icono SVG y PNG,
     y las traducciones `tbo/translations/tbo_en.qm` y `tbo_es.qm`.
4. **Verificar dependencias sin instalar**:
   `apt install --dry-run ./tbo_2.0.0.dev0-1_all.deb`
   - Si dice `0 newly installed`, ya está todo satisfecho.
5. **Checksums tras la instalación** (debsums):
   `sudo apt install debsums && debsums tbo`
   - Salida vacía = archivos intactos; cualquier diferencia indica corrupción.
6. **Checklist completa antes de publicar**: build → lintian → info → contents
   → dry-run → install + smoke test (`tbo --help`) → debsums.
7. **Herramientas**: `sudo apt install lintian debsums`

Si una comprobación falla, detente y corrige antes de pasar al siguiente paso.

---

## Cómo probar (tras estas correcciones)

1. Ir a [https://github.com/wachin/TBO/actions](https://github.com/wachin/TBO/actions).
2. Click en "Build executables" → "Run workflow".
3. **Todos los jobs pasan en verde** sin avisos de Node.js obsoleto.
4. Ahora sí se descargan **4 artefactos**: el AppImage, el ZIP de macOS, el ZIP
   de Windows **y el paquete `.deb`** (más el wheel/sdist si se descarga).

---

Dios les bendiga
