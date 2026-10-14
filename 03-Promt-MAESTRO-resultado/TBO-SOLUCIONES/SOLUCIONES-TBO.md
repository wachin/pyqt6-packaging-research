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

## 9. Los artefactos se construían en verde y salían incompletos (2026-10)

Esta sección es distinta de las anteriores. Todo lo de arriba lo detectó CI al
fallar. Esto no: **los cinco jobs estaban en verde** y el AppImage llevaba desde
agosto publicado sin los recursos de la aplicación, sin que nada avisara.

Se encontró ejecutando el artefacto y leyendo su salida, no leyendo el workflow.

### 9.1 Síntoma

El AppImage arrancaba y funcionaba, pero imprimía un error por cada icono de la
interfaz:

```text
qt.svg: Cannot open file '.../_internal/tbo/resources/icons/document-new.svg',
        because: No such file or directory
```

14 iconos. Ningún test falló, ningún paso falló, el job estaba en verde.

### 9.2 Causa raíz: el destino de `--add-data` no coincide con lo que lee el código

La aplicación resuelve sus datos con `Path(__file__).parent`:

```python
# src/tbo/resources.py
resources_dir = Path(__file__).resolve().parent / "resources"

# src/tbo/application.py
TRANSLATION_DIRS = (
    _package_dir / "translations",              # <bundle>/tbo/translations
    _package_dir.parent.parent / "translations",
    ...
)
```

Dentro de un bundle congelado, el paquete `tbo` vive en `_internal/tbo`, así que
la aplicación busca en `_internal/tbo/resources` y `_internal/tbo/translations`.

Los scripts de PyInstaller copiaban los directorios sueltos de la raíz:

```bash
--add-data "translations:translations"     # -> _internal/translations  (mal)
```

Nunca se colocaba nada en `_internal/tbo/`, así que **los iconos y las
traducciones de la aplicación eran inalcanzables**.

### 9.3 Arreglo

```bash
--add-data "$workspace_root/src/tbo/resources:tbo/resources"
--add-data "$workspace_root/src/tbo/translations:tbo/translations"
```

Aplicado en `packaging/build_appimage.sh` y `packaging/build_macos.sh`.

### 9.4 Tres plataformas, tres mecanismos, dos mal

| Plataforma | Herramienta | Mecanismo | Resultado |
|---|---|---|---|
| Windows | Nuitka | `--include-package-data=tbo` | correcto (recoge `tbo/resources`, `tbo/translations`, `tbo/data`) |
| macOS | PyInstaller | `--add-data` de directorios sueltos | **faltaban iconos y traducciones** |
| Linux AppImage | PyInstaller | `--add-data` de directorios sueltos | **faltaban iconos y traducciones** |

Windows funcionaba por casualidad de haber elegido otra bandera: el
comportamiento de `--include-package-data` de Nuitka coincide con el layout que
el código espera. Los dos builds de PyInstaller no, y nada detectó la diferencia.

Moraleja: **"funciona en Windows" no es prueba de que un bundle esté bien.**

### 9.5 Dos roturas más, encontradas al reconstruir

Al arreglar lo anterior y reconstruir el AppImage aparecieron dos fallos que
habrían roto el próximo run de CI, y que no tienen nada que ver con los recursos:

**a) El pin de `appimagetool` era un tag móvil.**

El script fijaba el SHA256 de `releases/download/continuous/...`. El asset
`continuous` se republicó el 2026-10-04, así que el checksum dejó de coincidir y
el build falla con `La suma no coincide`. El chequeo funcionó como debía —fallar
en vez de publicar en silencio— pero el pin estaba mal elegido.

Arreglo: fijar una release **versionada** (`1.9.1`), cuyo tag no se mueve.

```bash
APPIMAGETOOL_VERSION="1.9.1"
APPIMAGETOOL_SHA256="ed4ce84f0d9caff66f50bcca6ff6f35aae54ce8135408b3fa33abfc3cb384eb0"
```

**b) El nombre del icono no coincidía con `Icon=` del `.desktop`.**

`packaging/tbo.desktop` declara `Icon=org.tbo.TBO`, pero el script instalaba el
PNG como `tbo.png`. appimagetool lo rechaza:

```text
org.tbo.TBO{.png,.svg,.xpm} defined in desktop file but not found
```

El `continuous` antiguo lo toleraba; la versión estable lo rechaza. Al fijar la
versión se destapó la inconsistencia latente.

Arreglo: nombrar el icono según el ID de aplicación, `org.tbo.TBO.png`.

### 9.6 Verificación

AppImage reconstruido y ejecutado de extremo a extremo:

| | Antes | Después |
|---|---|---|
| Errores `qt.svg: Cannot open file` | 14 | **0** |
| Iconos de UI empaquetados | 0 | 13 |
| Traducciones empaquetadas | 0 | 2 |
| Arranca y se mantiene vivo | sí | sí |

### 9.7 La lección que importa

> **CI en verde significa que el comando de build devolvió 0, no que el artefacto
> funcione.**

Nada en el pipeline lanzaba jamás lo construido. La guía maestra ya recomendaba
un *smoke test* del artefacto (solo napari y pyzo lo hacen); TBO construía pero
no ejecutaba.

La regla general, escrita también en
`PyQt6-Apps/TBO/docs/GitHub-Actions-Solutions/PACKAGING-RESOURCE-COLLECTION-BUG.md`:

> Cuando un comando de build copia datos de la aplicación, el **destino** debe
> coincidir con la ruta que el código lee en tiempo de ejecución, no con la ruta
> desde la que es cómodo copiar. Verifícalo inspeccionando el bundle o
> ejecutándolo, nunca confiando en que el build terminó bien.

### 9.8 Cambio de estado de TBO en este repositorio

TBO dejó de ser un sub-módulo y pasó a ser un clon independiente, ignorado por
`.gitignore`. Se puede editar y publicar en su propio repositorio sin que este
registre un commit distinto cada vez. Ver `AGENTS.md` §1, "The one exception:
TBO".

---

## 10. Build de Windows con PyInstaller, para poder comparar

Hasta ahora Windows se construía solo con Nuitka. El motivo original —que
PyInstaller daba falsos positivos en VirusTotal— es un dato de una aplicación
anterior y **nunca se ha medido sobre TBO**.

Para poder medirlo:

- `packaging/build_windows_nuitka.ps1` — el build que se publica (antes
  `build_windows.ps1`, renombrado para que su naturaleza quede explícita).
- `packaging/build_windows_pyinstaller.ps1` — nuevo, produce **onedir** y
  **onefile**, con los mismos metadatos PE, los mismos datos y UPX desactivado
  en ambos.
- Nuevo job `build-windows-pyinstaller` en `.github/workflows/build.yml`.

Los dos scripts mantienen constantes el código, la versión y los recursos, para
que la única diferencia sea la herramienta y el layout. Cada `.exe` se sube a
VirusTotal por separado y se registra el resultado.

Esto **no decide nada por sí solo**: es un punto de partida para medir. Un único
resultado de VirusTotal es una señal puntual de un motor concreto, no un veredicto
— ver `PACKAGING_EVIDENCE_MATRIX.md` sección B.

---

## 11. Primera medición real: PyInstaller vs Nuitka en VirusTotal (2026-10)

Esto cierra la laguna más grande de toda la investigación. Hasta ahora la matriz
de evidencia decía `NO DATA` en todas las filas de antivirus: **ningún proyecto
de los estudiados había publicado jamás una medición**.

Ya está hecha, sobre TBO, con las tres builds del mismo commit, la misma versión,
los mismos metadatos PE, sin firma y con UPX desactivado en las tres (ver §10).

### 11.1 Resultado

| Artefacto | Herramienta | Layout | SHA-256 | Tamaño | VirusTotal |
|---|---|---|---|---|---|
| `TBO.exe` | Nuitka | standalone | `9f8a79c1c6cf55cf6700334f585a2e9a61f04ce15eb723bacc0a1c7c20a1818b` | 7.117.824 B | **no marcado** |
| `tbo-pyinstaller-onedir.exe` | PyInstaller | onedir | `e4fd50350ca15e6f456dd746f04332849db31714375174122275e970e96d840a` | 2.019.109 B | **marcado** |
| `tbo-pyinstaller-onefile.exe` | PyInstaller | onefile | `94ba578707ebc5c90591520c8f6c3ce392aa3d1c76bc2100b53413f887acd5f1` | 38.802.576 B | **marcado** |

Los tres SHA-256 se recalcularon sobre los artefactos en disco y **coinciden con
los enlaces de VirusTotal**, así que los ficheros de los que hablamos son
exactamente los que produjo el CI de este repositorio.

### 11.2 Qué cambia y qué no

**Cambia el supuesto más repetido del área.** La idea de que `onedir` evita las
heurísticas de autoextracción que hacen sospechoso a `onefile` **no se sostiene**
en esta medición: los dos layouts de PyInstaller salieron marcados. Si el
resultado se mantiene, el factor diferencial es el **bootloader de PyInstaller**,
no el layout del bundle.

**No cambia nada más allá de esta aplicación.** Las condiciones a tener presentes:

- **n = 1.** Una aplicación, una build de cada rama, un momento concreto. La
  regla de esta misma matriz aplica: una muestra es ruido.
- **Faltan los recuentos.** "Marcado" abarca desde un único motor heurístico
  hasta una mayoría; el número cambia por completo la interpretación. **No se
  capturaron ni el número de detecciones ni los nombres de los motores.**
- **Sin firma, y versión `2.0.0.dev0`.** Tanto la ausencia de firma como una
  versión de desarrollo son señales débiles por sí mismas.
- **Historial de envío no controlado.** Un hash que VirusTotal nunca ha visto se
  trata distinto de uno con historial.
- TBO es software GPL, con pocos usuarios y sin historial de descargas.

### 11.3 Un artefacto que confunde: el `.exe` suelto

En el listado de los artefactos descargados, el mismo `TBO.exe` aparece dos
veces: una anotada **"No funciona"** y otra **"Este funciona"**. No es un defecto
de compilación.

El job de CI sube **el zip completo y además el `.exe` suelto**:

- el `.exe` extraído del artifact por separado no tiene su carpeta hermana
  (`_internal` en PyInstaller, los DLL en Nuitka) → **no arranca**;
- el `.exe` que vive dentro del zip portable, con sus hermanos, → **funciona**.

Lo mismo pasa con `tbo-pyinstaller-onedir.exe`.

El `.exe` suelto se sube a propósito, porque es lo que se manda a VirusTotal. Pero
**no debe presentarse como una aplicación ejecutable**. Si el artifact se
distribuye a personas, conviene etiquetarlo como "solo para escaneo" o dejar
únicamente el zip.

Verificado en disco: `dist/TBO/` contiene 1 entrada (`TBO.exe`) y
`dist/tbo-pyinstaller-onedir/` contiene 1 entrada (el `.exe`).

### 11.4 Qué haría falta para que esto sea concluyente

1. **Capturar el detalle**: número de detecciones, motores, y categoría
   (malware / PUA / heurístico) de cada artefacto.
2. **Repetir en varias releases.** Un único par de builds no distingue una
   propiedad de la herramienta de una casualidad de ese build.
3. **Repetir con firma Authenticode**, que cambia las heurísticas y no está
   probado aquí.
4. **Probar la hipótesis del bootloader**: un tercer build con `--noupx` ya está,
   pero faltaría una rama con un bootloader reconstruido o un `onedir` de
   PyInstaller sin bootloader self-extracting, para separar "bootloader" de
   "PyInstaller" como causa.

Mientras eso no exista, el resultado es **una pista sólida, no una regla**.

---

Dios les bendiga
