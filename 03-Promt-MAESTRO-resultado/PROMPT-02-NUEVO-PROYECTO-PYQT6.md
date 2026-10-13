# PROMPT PARA AGENTE DE IA: Configurar un nuevo proyecto PyQt6 con empaquetado profesional desde el inicio

## Objetivo

Crear un **nuevo proyecto PyQt6 desde cero** cuyo pipeline de empaquetado funcione correctamente en GitHub Actions desde la primera versión, evitando los problemas típicos de empaquetado cross-platform (Windows `.exe`, macOS `.app`, Linux `.deb` y AppImage).

## Contexto

- **ROADMAP.md** está en la raíz del proyecto con las indicaciones funcionales del programa a desarrollar.
- Junto a él, en una carpeta (por ejemplo `docs/packaging/`), están los tres documentos maestros que DEFINEN el estándar de empaquetado:
  - `MASTER_PYQT6_PACKAGING_GUIDE.md`
  - `PACKAGING_EVIDENCE_MATRIX.md`
  - `PYQT6_MASTER_PACKAGING_TUTORIAL.md`

## Instrucciones generales

1. **LEE COMPLETAMENTE** los tres documentos maestros Y el `ROADMAP.md` antes de escribir código.
2. Los tres documentos maestros son la **autoridad técnica** sobre empaquetado: distingue entre lo que está `[OBSERVED]` (probado en proyectos reales), `[RECOMMENDED]` (recomendado por las guías) y `[TEMPLATE — MUST BE TESTED]` (que debes marcar como tal).
3. Implementa el proyecto de forma que las decisiones de empaquetado se tomen **desde el inicio** (arquitectura recomendada en la sección 29 del Master Guide y sección 15 del Tutorial).
4. **No modifiques los documentos maestros.** Tómalos como referencia de solo lectura.
5. Marca todo lo que no puedas probar como `[TEMPLATE — MUST BE TESTED]`.
6. **No incluyas credenciales reales ni valores secretos.** Usa placeholders (ej. `YOUR-CA-ENDPOINT`, `TEAMID`, `YOUR-GUID`).

---

## Lo que debe producir el proyecto desde el inicio

### 1. Estructura del repositorio

```text
myapp/
├── pyproject.toml              # metadata + dependencias + entry point
├── README.md
├── ROADMAP.md
├── src/myapp/
│   ├── __init__.py             # __version__ = "0.1.0"
│   ├── __main__.py             # entry point: raise SystemExit(main())
│   ├── app.py                  # QApplication + ventana principal
│   ├── resources.py            # resource resolver (dev/frozen)  [OBSERVED — CARA]
│   ├── ui/                     # widgets, dialogs
│   └── resources/              # assets (icon.svg, icon.png, icon.ico, icon.icns)
├── data/                       # datos que se distribuyen (si aplica)
├── translations/               # .ts y .qm (si aplica)
├── packaging/
│   ├── pyinstaller/
│   │   ├── myapp_windows.spec
│   │   ├── myapp_linux.spec
│   │   └── myapp_macos.spec
│   ├── windows/
│   │   ├── version_info.txt    # PE metadata [RECOMMENDED]
│   │   └── myapp.iss           # Inno Setup [OBSERVED — dikte/pyzo]
│   ├── linux/
│   │   ├── AppRun
│   │   ├── org.example.MyApp.desktop
│   │   ├── myapp.png
│   │   └── org.example.MyApp.metainfo.xml
│   ├── debian/                 # debian/control, rules, changelog, copyright, install
│   │   └── ...
│   ├── macos/
│   │   └── entitlements.plist  # mínimo posible [RECOMMENDED]
│   ├── generate_icon.py        # genera .ico/.iconset/.icns desde PNG [OBSERVED — dikte]
│   ├── requirements-windows.txt
│   ├── requirements-linux.txt
│   ├── requirements-macos.txt
│   └── scripts/
│       ├── build_windows.ps1   # PyInstaller onedir o Nuitka standalone
│       ├── build_linux.sh      # AppImage
│       ├── build_deb.sh        # .deb
│       └── build_macos.sh      # .app + DMG
├── tests/                      # unit + integration
└── .github/workflows/
    ├── ci.yml                  # tests, lint
    └── build.yml               # builds para Windows/macOS/Linux
```

### 2. Decisiones de empaquetado a aplicar (basadas en los documentos maestros)

- **Windows:** PyInstaller **onedir** (no onefile) → version_info.txt + icono → **Inno Setup** per-user (`PrivilegesRequired=lowest`) → firmar inner EXE y installer (si hay certificado, con placeholder) → SHA256. `[REPEATED — CARA/dikte/pyzo]`
- **Linux AppImage:** PyInstaller onedir → AppDir manual (AppRun, .desktop, icon, metainfo) → `appimagetool` **pineado con checksum** → build en **Ubuntu 22.04** para GLIBC base. `[OBSERVED — dikte + RECOMMENDED]`
- **Linux DEB:** modelo nativo con dependencias del distro (`Depends: python3, python3-pyqt6`) usando `dh`/`pybuild` si el distro lo soporta, O bundled runtime divulgado. Documenta cuál eliges y por qué. `[RECOMMENDED — decidir modelo]`
- **macOS:** PyInstaller `.app` → firmar nested code (inside-out) → Developer ID + hardened runtime + timestamp → `notarytool` → `stapler` → `spctl` → DMG (con symlink `/Applications`). `[REPEATED — CARA/pyzo/napari]`
- **GitHub Actions:** tag-triggered release + matrix native + artifact smoke tests + SHA256SUMS. `[REPEATED — pyzo/dikte/napari]`
- **Resource handling:** resource resolver central (nunca depender de `cwd`); datos de usuario en `platformdirs`; nunca escribir dentro de un `.app` firmado. `[OBSERVED — CARA]`
- **Qt plugins:** verificar en el artifact final (nunca asumir que PyInstaller los recogió todos). `[REPEATED]`
- **Qt translations:** bundlear `qtbase_*.qm` + instalar `QTranslator`. `[RECOMMENDED]`

### 3. CI/CD desde el inicio

- `ci.yml`: lint + tests (matrix Python 3.11/3.12), ejecutables con `QT_QPA_PLATFORM=offscreen`
- `build.yml`: 
  - job `build-wheel` (Python sdist/wheel)
  - job `build-deb` (Linux)
  - job `build-appimage` (Linux, Ubuntu 22.04)
  - job `build-windows` (PyInstaller onedir)
  - job `build-macos` (PyInstaller .app + DMG)
  - job `build-flatpak` (OPCIONAL — solo si el usuario lo pide)
- **Smoke test del artifact en CI**: lanzar el binario generado y comprobar que arranca (aunque sea con `--version`). `[OBSERVED — napari/pyzo]`
- **Versionado**: usar `setuptools_scm` o `__version__` único y coherente en todos los artifacts (evita el error de Nuitka `2.0.0.dev0.0` — usar solo versiones numéricas para Windows). `[IMPORTANTE]`
- **Nunca** usar `pip install -U` para dependencias de release; usar lockfiles. `[RECOMMENDED — napari]`

### 4. Errores típicos que DEBES evitar (documentados en los archivos maestros)

- `python3.12: No module named build` en build-deb (el Python de `actions/setup-python` no tiene `build` instalado) → instalar `build` con pip en el job, o no usar setup-python.
- Nuitka `Invalid version number` (versiones como `2.0.0.dev0.0`) → sanitizar la versión a numérica.
- macOS iconset not found (discrepancia de rutas entre script y `generate_icon.py`).
- AppImage con `appimagetool` sin pin (usar `continuous`) → pin + checksum. `[OBSERVED — dikte weak point]`
- Firmar cosas que ya no se deben firmar, o escribir dentro de un `.app` firmado.
- Añadir archivos a un `.app` después de firmar.

---

## Formato de entrega esperado

Debes proporcionar:

1. **Resumen ejecutivo** de las decisiones de empaquetado tomadas (con clasificación `[OBSERVED]`/`[RECOMMENDED]`/`[TEMPLATE — MUST BE TESTED]`)
2. **Contenido completo de cada archivo creado** (no fragments): pyproject.toml, src/myapp/*, packaging/*, debian/*, .github/workflows/*
3. **Instrucciones para el usuario**: cómo lanzar el build, cómo añadir certificados/signo cuando los tenga, cómo probar localmente
4. **Checklist de release** basada en el tutorial maestro
5. **Limitaciones conocidas** (qué no se pudo probar, qué requiere entorno real)

---

## Restricciones importantes

- No modificar los documentos maestros.
- No incluir credenciales reales ni secretos.
- Marcar todo lo no probado como `[TEMPLATE — MUST BE TESTED]`.
- Respetar el estilo de código y estructura que el usuario defina en el ROADMAP.md.
- El proyecto debe poder empaquetarse desde el primer commit: al hacer push y lanzar `Build executables`, todos los jobs deben pasar o fallar con errores claros y solucionables.
