# PROMPT PARA AGENTE DE IA: Reparar y completar GitHub Actions en TBO

## Objetivo

Aplicar las guías maestras de empaquetado PyQt6 para **reparar los builds fallidos** en el proyecto **TBO** (repositorio PyQt6 para edición de cómics) y **crear el build AppImage faltante**, de modo que todos los ejecutables se generen correctamente en GitHub Actions.

## Ubicación del proyecto

```
/home/wachin/Dev3/pyqt6-packaging-research/PyQt6-Apps/TBO/
```

## Instrucciones generales

1. **LEE COMPLETAMENTE** (en este orden) los tres documentos maestros:
   - `/home/wachin/Dev3/pyqt6-packaging-research/03-Promt-MAESTRO-resultado/MASTER_PYQT6_PACKAGING_GUIDE.md`
   - `/home/wachin/Dev3/pyqt6-packaging-research/03-Promt-MAESTRO-resultado/PACKAGING_EVIDENCE_MATRIX.md`
   - `/home/wachin/Dev3/pyqt6-packaging-research/03-Promt-MAESTRO-resultado/PYQT6_MASTER_PACKAGING_TUTORIAL.md`

2. Después de leerlos, **examina el proyecto TBO** a fondo (especialmente las rutas que se mencionan en los errores más abajo).

3. Identifica la causa raíz de CADA error, compárala con las guías, y haz la corrección más simple y robusta posible.

4. **No modifiques los documentos maestros.** Todos los cambios deben ser en el repositorio TBO (`.github/workflows/`, `packaging/`, `debian/`, `src/tbo/`).

5. **Marca todo lo que no puedas probar como `[TEMPLATE — MUST BE TESTED]`** (siguiendo el formato del tutorial maestro).

6. **No incluyas credenciales reales ni valores secretos.** Usa placeholders.

7. **Explica CADA cambio** con comentarios en el código o en un mensaje de commit.

---

## Errores a reparar (con los logs exactos)

### Error 1: build-deb — `python3.12: No module named build`

**Log:**
```
I: pybuild plugin_pyproject:129: Building wheel for python3.12 with "build" module
I: pybuild base:311: python3.12 -m build --skip-dependency-check --no-isolation --wheel
  --outdir /home/runner/work/TBO/TBO/.pybuild/cpython3_3.12_tbo
/opt/hostedtoolcache/Python/3.12.14/x64/bin/python3.12: No module named build
E: pybuild pybuild:389: build: plugin pyproject failed with: exit code=1
```

**Causa raíz que debes investigar:** `actions/setup-python` coloca un Python en el PATH (`/opt/hostedtoolcache/.../python3.12`) que es diferente del Python del sistema (`/usr/bin/python3`). El paquete apt `python3-build` instala el módulo `build` en el Python del sistema, pero NO en el toolcache Python. Cuando `pybuild` invoca `python3.12 -m build`, usa el toolcache Python, que no tiene `build`.

**Solución posible:** Instalar `build` en el Python activo (el de setup-python) con `pip install build` antes de `dpkg-buildpackage`. Otra opción: no usar `actions/setup-python` en el job `build-deb` y usar el Python del sistema. Evalúa cuál es más limpia y durable.

**Archivos relevantes:**
- `.github/workflows/build.yml` (job `build-deb`)
- `debian/rules`
- `debian/control` (Build-Depends)

### Error 2: build-windows — Nuitka `Invalid version number`

**Log:**
```
Nuitka-Options: ... --file-version=2.0.0.dev0.0 ...
FATAL: Invalid version number --file-version='2.0.0.dev0.0'.
```

**Causa raíz:** La versión en `src/tbo/__init__.py` es `2.0.0.dev0`. El script PowerShell hace `$windowsVersion = "$version.0"` → `2.0.0.dev0.0`. Nuitka requiere `--file-version` con formato numérico de 4 partes (`major.minor.build.revision`). `2.0.0.dev0.0` no es válido porque contiene `.dev0`.

**Solución:** Sanitizar la versión para Windows: extraer solo la parte numérica (`2.0.0`) y añadir `.0` → `2.0.0.0`. Ejemplo: `$windowsVersion = ($version -replace '[^0-9.].*$', '') + '.0'`.

**Archivos relevantes:**
- `packaging/build_windows.ps1`
- `src/tbo/__init__.py` (versión)

### Error 3: build-macos — Iconset not found

**Log:**
```
  iconset: /Users/runner/work/TBO/TBO/src/tbo/resources/icon.iconset
/Users/runner/work/TBO/TBO/build/tmp/TBO.iconset:Iconset not found.
```

**Causa raíz:** El script `build_macos.sh` define `iconset_dir="$tmp_dir/TBO.iconset"` (ruta: `build/tmp/TBO.iconset`). Pero `generate_icon.py` con el argumento `iconset` crea el iconset junto al archivo de origen: `src/tbo/resources/icon.iconset` (porque `source.with_suffix(".iconset")`). Luego `iconutil -c icns "$iconset_dir" -o "$icon_path"` falla porque `$iconset_dir` apunta a `build/tmp/TBO.iconset` que no existe.

**Solución:** Alinear las rutas. La opción más limpia: modificar `generate_icon.py` para que acepte un directorio de salida, o modificar `build_macos.sh` para que use la ubicación real donde `generate_icon.py` crea los archivos.

**Archivos relevantes:**
- `packaging/build_macos.sh`
- `packaging/generate_icon.py`

### Error 4: build-flatpak — Docker image no encontrada

**Log:**
```
Error response from daemon: manifest unknown
/usr/bin/docker pull ghcr.io/flathub/flathub-infra:latest
Warning: Docker pull failed with exit code 1, back off 9.1 seconds before retry.
...
Error: Docker pull failed with exit code 1
```

**Causa raíz:** La imagen `ghcr.io/flathub/flathub-infra:latest` no existe o no es accesible públicamente.

**Nota del usuario:** "Para mi no es importante flatpak, pero si se lo puede hacer funcionar bien, y si haya que desabilitarlo no me importaría, yo en realidad nunca uso flatpak."

**Solución:** Deshabilitar el job `build-flatpak` (comentarlo o eliminarlo del workflow), o intentar repararlo con una imagen diferente. Si lo reparas, documenta la imagen correcta. La recomendación es deshabilitarlo para que los otros builds no dependan de él.

### Error 5 (falta): build-appimage — No existe

No hay ningún pipeline de AppImage en el proyecto TBO. **Debes crearlo** siguiendo la guía maestra (§9 del tutorial, §15 del master guide).

**Requisitos:**
- Usar PyInstaller onedir como payload base (el proyecto ya usa PyInstaller en macOS)
- Construir en Ubuntu 22.04 para línea base GLIBC conservadora
- Ensamblar AppDir manualmente (AppRun, .desktop, icono, metainfo)
- Usar `appimagetool` con pin y checksum (NO usar `continuous` sin verificar, como advierte el estudio de dikte)
- Incluir `build-appimage` como un nuevo job en `.github/workflows/build.yml`
- Probar que el AppImage se genera correctamente (subir como artifact)

---

## Formato de entrega esperado

Debes proporcionar:

1. **Lista de cambios** con cada archivo modificado, qué cambió y por qué
2. **Contenido de cada archivo modificado o creado** (completo, no fragments)
3. **Explicación de la causa raíz** de cada error y por qué tu solución funciona
4. **Instrucciones de verificación** (cómo probar que los builds pasan)
5. **Cualquier limitación conocida** o cosa que no se haya podido probar

---

## Restricciones importantes

- No modificar los archivos en `03-Promt-MAESTRO-resultado/` ni en `MASTER_PYQT6_PACKAGING_GUIDE.md`, `PYQT6_MASTER_PACKAGING_TUTORIAL.md`, `PACKAGING_EVIDENCE_MATRIX.md`
- No agregar secretos ni credenciales reales
- Usar placeholders para todo lo que requiera configuración del usuario (certificados, URLs de timestamp, etc.)
- Mantener compatibilidad con Python 3.11, 3.12, 3.12
- Seguir el estilo de código existente del proyecto