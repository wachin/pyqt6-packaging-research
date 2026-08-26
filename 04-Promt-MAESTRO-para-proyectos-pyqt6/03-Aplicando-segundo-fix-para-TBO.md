
me falla en GitHub Actios:

https://github.com/wachin/TBO/actions

al dar clic en "Actions" en "Build executables" me da falla porque los "workflow runs" no pasan, me da estos errores:

## en "Build .deb"

```
Run dpkg-buildpackage -b -uc -us
dpkg-buildpackage: info: source package tbo
dpkg-buildpackage: info: source version 2.0.0.dev0-1
dpkg-buildpackage: info: source distribution unstable
dpkg-buildpackage: info: source changed by Washington Indacochea Delgado <linuxfrontier@proton.me>
 dpkg-source --before-build .
dpkg-buildpackage: info: host architecture amd64
 fakeroot debian/rules clean
dh clean --with python3 --buildsystem=pybuild
   dh_auto_clean -O--buildsystem=pybuild
   dh_autoreconf_clean -O--buildsystem=pybuild
   debian/rules override_dh_clean
make[1]: Entering directory '/home/runner/work/TBO/TBO'
dh_clean
rm -rf ../build ../dist
make[1]: Leaving directory '/home/runner/work/TBO/TBO'
 debian/rules build
dh build --with python3 --buildsystem=pybuild
   dh_update_autotools_config -O--buildsystem=pybuild
   dh_autoreconf -O--buildsystem=pybuild
   dh_auto_configure -O--buildsystem=pybuild
   dh_auto_build -O--buildsystem=pybuild
I: pybuild plugin_pyproject:129: Building wheel for python3.12 with "build" module
I: pybuild base:311: python3.12 -m build --skip-dependency-check --no-isolation --wheel --outdir /home/runner/work/TBO/TBO/.pybuild/cpython3_3.12_tbo  
* Building wheel...
/opt/hostedtoolcache/Python/3.12.14/x64/lib/python3.12/site-packages/setuptools/config/_apply_pyprojecttoml.py:82: SetuptoolsDeprecationWarning: `project.license` as a TOML table is deprecated
!!

        ********************************************************************************
        Please use a simple string containing a SPDX expression for `project.license`. You can also use `project.license-files`. (Both options available on setuptools>=77.0.0).

        By 2027-Feb-18, you need to update your project and remove deprecated calls
        or your builds will no longer be supported.

        See https://packaging.python.org/en/latest/guides/writing-pyproject-toml/#license for details.
        ********************************************************************************

!!
  corresp(dist, value, root_dir)
running bdist_wheel
running build
running build_py
creating build/lib/tbo
copying src/tbo/__init__.py -> build/lib/tbo
copying src/tbo/__main__.py -> build/lib/tbo
copying src/tbo/resources.py -> build/lib/tbo
copying src/tbo/application.py -> build/lib/tbo
creating build/lib/tbo/document
copying src/tbo/document/__init__.py -> build/lib/tbo/document
copying src/tbo/document/model.py -> build/lib/tbo/document
creating build/lib/tbo/ui
copying src/tbo/ui/__init__.py -> build/lib/tbo/ui
copying src/tbo/ui/export_dialog.py -> build/lib/tbo/ui
copying src/tbo/ui/new_comic_dialog.py -> build/lib/tbo/ui
copying src/tbo/ui/preferences.py -> build/lib/tbo/ui
copying src/tbo/ui/main_window.py -> build/lib/tbo/ui
copying src/tbo/ui/about_dialog.py -> build/lib/tbo/ui
copying src/tbo/ui/search_dialog.py -> build/lib/tbo/ui
copying src/tbo/ui/canvas.py -> build/lib/tbo/ui
copying src/tbo/ui/theme.py -> build/lib/tbo/ui
copying src/tbo/ui/assets_dock.py -> build/lib/tbo/ui
copying src/tbo/ui/pages_dock.py -> build/lib/tbo/ui
copying src/tbo/ui/text_object_dialog.py -> build/lib/tbo/ui
copying src/tbo/ui/presentation.py -> build/lib/tbo/ui
copying src/tbo/ui/help_dialog.py -> build/lib/tbo/ui
copying src/tbo/ui/commands.py -> build/lib/tbo/ui
creating build/lib/tbo/assets
copying src/tbo/assets/__init__.py -> build/lib/tbo/assets
copying src/tbo/assets/resolver.py -> build/lib/tbo/assets
copying src/tbo/assets/catalog.py -> build/lib/tbo/assets
creating build/lib/tbo/formats
copying src/tbo/formats/__init__.py -> build/lib/tbo/formats
copying src/tbo/formats/tbo_v1.py -> build/lib/tbo/formats
creating build/lib/tbo/rendering
copying src/tbo/rendering/__init__.py -> build/lib/tbo/rendering
copying src/tbo/rendering/renderer.py -> build/lib/tbo/rendering
copying src/tbo/rendering/exporter.py -> build/lib/tbo/rendering
running egg_info
creating src/tbo.egg-info
writing src/tbo.egg-info/PKG-INFO
writing dependency_links to src/tbo.egg-info/dependency_links.txt
writing entry points to src/tbo.egg-info/entry_points.txt
writing requirements to src/tbo.egg-info/requires.txt
writing top-level names to src/tbo.egg-info/top_level.txt
writing manifest file 'src/tbo.egg-info/SOURCES.txt'
reading manifest file 'src/tbo.egg-info/SOURCES.txt'
adding license file 'COPYING'
adding license file 'AUTHORS'
writing manifest file 'src/tbo.egg-info/SOURCES.txt'
creating build/lib/tbo/resources
copying src/tbo/resources/icon.svg -> build/lib/tbo/resources
copying src/tbo/resources/icon.png -> build/lib/tbo/resources
creating build/lib/tbo/resources/icons
copying src/tbo/resources/icons/document-open.svg -> build/lib/tbo/resources/icons
copying src/tbo/resources/icons/edit-redo.svg -> build/lib/tbo/resources/icons
copying src/tbo/resources/icons/draw-text.svg -> build/lib/tbo/resources/icons
copying src/tbo/resources/icons/zoom-out.svg -> build/lib/tbo/resources/icons
copying src/tbo/resources/icons/zoom-in.svg -> build/lib/tbo/resources/icons
copying src/tbo/resources/icons/flip-horizontal.svg -> build/lib/tbo/resources/icons
copying src/tbo/resources/icons/document-new.svg -> build/lib/tbo/resources/icons
copying src/tbo/resources/icons/flip-vertical.svg -> build/lib/tbo/resources/icons
copying src/tbo/resources/icons/document-save.svg -> build/lib/tbo/resources/icons
copying src/tbo/resources/icons/edit-undo.svg -> build/lib/tbo/resources/icons
copying src/tbo/resources/icons/add-panel.svg -> build/lib/tbo/resources/icons
copying src/tbo/resources/icons/zoom-fit-page.svg -> build/lib/tbo/resources/icons
copying src/tbo/resources/icons/zoom-original.svg -> build/lib/tbo/resources/icons
installing to build/bdist.linux-x86_64/wheel
running install
running install_lib
creating build/bdist.linux-x86_64/wheel
creating build/bdist.linux-x86_64/wheel/tbo
copying build/lib/tbo/__init__.py -> build/bdist.linux-x86_64/wheel/./tbo
copying build/lib/tbo/__main__.py -> build/bdist.linux-x86_64/wheel/./tbo
creating build/bdist.linux-x86_64/wheel/tbo/document
copying build/lib/tbo/document/__init__.py -> build/bdist.linux-x86_64/wheel/./tbo/document
copying build/lib/tbo/document/model.py -> build/bdist.linux-x86_64/wheel/./tbo/document
creating build/bdist.linux-x86_64/wheel/tbo/ui
copying build/lib/tbo/ui/__init__.py -> build/bdist.linux-x86_64/wheel/./tbo/ui
copying build/lib/tbo/ui/export_dialog.py -> build/bdist.linux-x86_64/wheel/./tbo/ui
copying build/lib/tbo/ui/new_comic_dialog.py -> build/bdist.linux-x86_64/wheel/./tbo/ui
copying build/lib/tbo/ui/preferences.py -> build/bdist.linux-x86_64/wheel/./tbo/ui
copying build/lib/tbo/ui/main_window.py -> build/bdist.linux-x86_64/wheel/./tbo/ui
copying build/lib/tbo/ui/about_dialog.py -> build/bdist.linux-x86_64/wheel/./tbo/ui
copying build/lib/tbo/ui/search_dialog.py -> build/bdist.linux-x86_64/wheel/./tbo/ui
copying build/lib/tbo/ui/canvas.py -> build/bdist.linux-x86_64/wheel/./tbo/ui
copying build/lib/tbo/ui/theme.py -> build/bdist.linux-x86_64/wheel/./tbo/ui
copying build/lib/tbo/ui/assets_dock.py -> build/bdist.linux-x86_64/wheel/./tbo/ui
copying build/lib/tbo/ui/pages_dock.py -> build/bdist.linux-x86_64/wheel/./tbo/ui
copying build/lib/tbo/ui/text_object_dialog.py -> build/bdist.linux-x86_64/wheel/./tbo/ui
copying build/lib/tbo/ui/presentation.py -> build/bdist.linux-x86_64/wheel/./tbo/ui
copying build/lib/tbo/ui/help_dialog.py -> build/bdist.linux-x86_64/wheel/./tbo/ui
copying build/lib/tbo/ui/commands.py -> build/bdist.linux-x86_64/wheel/./tbo/ui
creating build/bdist.linux-x86_64/wheel/tbo/resources
creating build/bdist.linux-x86_64/wheel/tbo/resources/icons
copying build/lib/tbo/resources/icons/document-open.svg -> build/bdist.linux-x86_64/wheel/./tbo/resources/icons
copying build/lib/tbo/resources/icons/edit-redo.svg -> build/bdist.linux-x86_64/wheel/./tbo/resources/icons
copying build/lib/tbo/resources/icons/draw-text.svg -> build/bdist.linux-x86_64/wheel/./tbo/resources/icons
copying build/lib/tbo/resources/icons/zoom-out.svg -> build/bdist.linux-x86_64/wheel/./tbo/resources/icons
copying build/lib/tbo/resources/icons/zoom-in.svg -> build/bdist.linux-x86_64/wheel/./tbo/resources/icons
copying build/lib/tbo/resources/icons/flip-horizontal.svg -> build/bdist.linux-x86_64/wheel/./tbo/resources/icons
copying build/lib/tbo/resources/icons/document-new.svg -> build/bdist.linux-x86_64/wheel/./tbo/resources/icons
copying build/lib/tbo/resources/icons/flip-vertical.svg -> build/bdist.linux-x86_64/wheel/./tbo/resources/icons
copying build/lib/tbo/resources/icons/document-save.svg -> build/bdist.linux-x86_64/wheel/./tbo/resources/icons
copying build/lib/tbo/resources/icons/edit-undo.svg -> build/bdist.linux-x86_64/wheel/./tbo/resources/icons
copying build/lib/tbo/resources/icons/add-panel.svg -> build/bdist.linux-x86_64/wheel/./tbo/resources/icons
copying build/lib/tbo/resources/icons/zoom-fit-page.svg -> build/bdist.linux-x86_64/wheel/./tbo/resources/icons
copying build/lib/tbo/resources/icons/zoom-original.svg -> build/bdist.linux-x86_64/wheel/./tbo/resources/icons
copying build/lib/tbo/resources/icon.svg -> build/bdist.linux-x86_64/wheel/./tbo/resources
copying build/lib/tbo/resources/icon.png -> build/bdist.linux-x86_64/wheel/./tbo/resources
copying build/lib/tbo/resources.py -> build/bdist.linux-x86_64/wheel/./tbo
creating build/bdist.linux-x86_64/wheel/tbo/assets
copying build/lib/tbo/assets/__init__.py -> build/bdist.linux-x86_64/wheel/./tbo/assets
copying build/lib/tbo/assets/resolver.py -> build/bdist.linux-x86_64/wheel/./tbo/assets
copying build/lib/tbo/assets/catalog.py -> build/bdist.linux-x86_64/wheel/./tbo/assets
copying build/lib/tbo/application.py -> build/bdist.linux-x86_64/wheel/./tbo
creating build/bdist.linux-x86_64/wheel/tbo/formats
copying build/lib/tbo/formats/__init__.py -> build/bdist.linux-x86_64/wheel/./tbo/formats
copying build/lib/tbo/formats/tbo_v1.py -> build/bdist.linux-x86_64/wheel/./tbo/formats
creating build/bdist.linux-x86_64/wheel/tbo/rendering
copying build/lib/tbo/rendering/__init__.py -> build/bdist.linux-x86_64/wheel/./tbo/rendering
copying build/lib/tbo/rendering/renderer.py -> build/bdist.linux-x86_64/wheel/./tbo/rendering
copying build/lib/tbo/rendering/exporter.py -> build/bdist.linux-x86_64/wheel/./tbo/rendering
running install_egg_info
Copying src/tbo.egg-info to build/bdist.linux-x86_64/wheel/./tbo-2.0.0.dev0-py3.12.egg-info
running install_scripts
creating build/bdist.linux-x86_64/wheel/tbo-2.0.0.dev0.dist-info/WHEEL
creating '/home/runner/work/TBO/TBO/.pybuild/cpython3_3.12_tbo/.tmp-s16y52an/tbo-2.0.0.dev0-py3-none-any.whl' and adding 'build/bdist.linux-x86_64/wheel' to it
adding 'tbo/__init__.py'
adding 'tbo/__main__.py'
adding 'tbo/application.py'
adding 'tbo/resources.py'
adding 'tbo/assets/__init__.py'
adding 'tbo/assets/catalog.py'
adding 'tbo/assets/resolver.py'
adding 'tbo/document/__init__.py'
adding 'tbo/document/model.py'
adding 'tbo/formats/__init__.py'
adding 'tbo/formats/tbo_v1.py'
adding 'tbo/rendering/__init__.py'
adding 'tbo/rendering/exporter.py'
adding 'tbo/rendering/renderer.py'
adding 'tbo/resources/icon.png'
adding 'tbo/resources/icon.svg'
adding 'tbo/resources/icons/add-panel.svg'
adding 'tbo/resources/icons/document-new.svg'
adding 'tbo/resources/icons/document-open.svg'
adding 'tbo/resources/icons/document-save.svg'
adding 'tbo/resources/icons/draw-text.svg'
adding 'tbo/resources/icons/edit-redo.svg'
adding 'tbo/resources/icons/edit-undo.svg'
adding 'tbo/resources/icons/flip-horizontal.svg'
adding 'tbo/resources/icons/flip-vertical.svg'
adding 'tbo/resources/icons/zoom-fit-page.svg'
adding 'tbo/resources/icons/zoom-in.svg'
adding 'tbo/resources/icons/zoom-original.svg'
adding 'tbo/resources/icons/zoom-out.svg'
adding 'tbo/ui/__init__.py'
adding 'tbo/ui/about_dialog.py'
adding 'tbo/ui/assets_dock.py'
adding 'tbo/ui/canvas.py'
adding 'tbo/ui/commands.py'
adding 'tbo/ui/export_dialog.py'
adding 'tbo/ui/help_dialog.py'
adding 'tbo/ui/main_window.py'
adding 'tbo/ui/new_comic_dialog.py'
adding 'tbo/ui/pages_dock.py'
adding 'tbo/ui/preferences.py'
adding 'tbo/ui/presentation.py'
adding 'tbo/ui/search_dialog.py'
adding 'tbo/ui/text_object_dialog.py'
adding 'tbo/ui/theme.py'
adding 'tbo-2.0.0.dev0.dist-info/licenses/AUTHORS'
adding 'tbo-2.0.0.dev0.dist-info/licenses/COPYING'
adding 'tbo-2.0.0.dev0.dist-info/METADATA'
adding 'tbo-2.0.0.dev0.dist-info/WHEEL'
adding 'tbo-2.0.0.dev0.dist-info/entry_points.txt'
adding 'tbo-2.0.0.dev0.dist-info/top_level.txt'
adding 'tbo-2.0.0.dev0.dist-info/RECORD'
removing build/bdist.linux-x86_64/wheel
Successfully built tbo-2.0.0.dev0-py3-none-any.whl
I: pybuild plugin_pyproject:144: Unpacking wheel built for python3.12 with "installer" module
   dh_auto_test -O--buildsystem=pybuild
I: pybuild base:311: cd /home/runner/work/TBO/TBO/.pybuild/cpython3_3.12_tbo/build; python3.12 -m unittest discover -v 
tbo.rendering (unittest.loader._FailedTest.tbo.rendering) ... ERROR

======================================================================
ERROR: tbo.rendering (unittest.loader._FailedTest.tbo.rendering)
----------------------------------------------------------------------
ImportError: Failed to import test module: tbo.rendering
Traceback (most recent call last):
  File "/opt/hostedtoolcache/Python/3.12.14/x64/lib/python3.12/unittest/loader.py", line 429, in _find_test_path
    package = self._get_module_from_name(name)
              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/hostedtoolcache/Python/3.12.14/x64/lib/python3.12/unittest/loader.py", line 339, in _get_module_from_name
    __import__(name)
  File "/home/runner/work/TBO/TBO/.pybuild/cpython3_3.12_tbo/build/tbo/rendering/__init__.py", line 1, in <module>
    from tbo.rendering.exporter import SUPPORTED_FORMATS, ExportError, export_comic, export_page
  File "/home/runner/work/TBO/TBO/.pybuild/cpython3_3.12_tbo/build/tbo/rendering/exporter.py", line 5, in <module>
    from PyQt6.QtCore import QRect, QSize, QSizeF, Qt
ModuleNotFoundError: No module named 'PyQt6'


----------------------------------------------------------------------
Ran 1 test in 0.000s

FAILED (errors=1)
E: pybuild pybuild:389: test: plugin pyproject failed with: exit code=1: cd /home/runner/work/TBO/TBO/.pybuild/cpython3_3.12_tbo/build; python3.12 -m unittest discover -v 
dh_auto_test: error: pybuild --test -i python{version} -p 3.12 returned exit code 13
make: *** [debian/rules:6: build] Error 25
dpkg-buildpackage: error: debian/rules build subprocess returned exit status 2
Error: Process completed with exit code 2.
```

---

## en "build-windows" en "Build standalone executable with Nuitka":

```
Aquí da un error muy grande, creo que debo revisar en Windows si todo se construye bien (no lo he hecho)
```

Nota: Para Windows yo usé Nuitka porque me pasó las pruebas en VirusTotal (con PyInstaller me daba virus)

---

## En "build-macos" en "Build macOS App with PyInstaller":

```
Run bash packaging/build_macos.sh
Workspace root is /Users/runner/work/TBO/TBO
  iconset: /Users/runner/work/TBO/TBO/build/tmp/TBO.iconset
usage: pyinstaller [-h] [-v] [-D] [-F] [--specpath DIR] [-n NAME]
                   [--contents-directory CONTENTS_DIRECTORY]
                   [--add-data SOURCE:DEST] [--add-binary SOURCE:DEST]
                   [-p DIR] [--hidden-import MODULENAME]
                   [--collect-submodules MODULENAME]
                   [--collect-data MODULENAME] [--collect-binaries MODULENAME]
                   [--collect-all MODULENAME] [--copy-metadata PACKAGENAME]
                   [--recursive-copy-metadata PACKAGENAME]
                   [--additional-hooks-dir HOOKSPATH]
                   [--runtime-hook RUNTIME_HOOKS] [--exclude-module EXCLUDES]
                   [--splash IMAGE_FILE]
                   [--splash-center {primary,active,default,virtual}]
                   [-d {all,imports,bootloader,noarchive}] [--optimize LEVEL]
                   [--python-option PYTHON_OPTION] [-s] [--noupx]
                   [--upx-exclude FILE] [-c] [-w]
                   [--hide-console {hide-early,hide-late,minimize-late,minimize-early}]
                   [-i <FILE.ico or FILE.exe,ID or FILE.icns or Image or "NONE">]
                   [--disable-windowed-traceback] [--version-file FILE]
                   [--manifest <FILE or XML>] [-m <FILE or XML>] [-r RESOURCE]
                   [--uac-admin] [--uac-uiaccess] [--argv-emulation]
                   [--osx-bundle-identifier BUNDLE_IDENTIFIER]
                   [--target-architecture ARCH] [--codesign-identity IDENTITY]
                   [--osx-entitlements-file FILENAME] [--runtime-tmpdir PATH]
                   [--bootloader-ignore-signals] [--distpath DIR]
                   [--workpath WORKPATH] [-y] [--upx-dir UPX_DIR] [--clean]
                   [--log-level LEVEL]
                   scriptname [scriptname ...]
pyinstaller: error: unrecognized arguments: --verbose
Error: Process completed with exit code 2.
```

Creo que debo revisar en macOS

---


Por favor el del paquete deb ese debes hacerlo funcionar pues estoy en Linux

