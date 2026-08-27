
En:

https://github.com/wachin/TBO/actions

al dar clic en "Actions" en "Build executables" ya funcionan algunos:

## en "Build .deb"

```
Esta ya pasó, está en verde
```

---

## en "build-windows" en "Build standalone executable with Nuitka":

```
Este no hay pasado, tengo que ir a Windows
```

Nota: Para Windows yo usé Nuitka porque me pasó las pruebas en VirusTotal (con PyInstaller me daba virus)

---

## En "build-macos" en "Build macOS App with PyInstaller":

```
Run bash packaging/build_macos.sh
Workspace root is /Users/runner/work/TBO/TBO
  iconset: /Users/runner/work/TBO/TBO/build/tmp/TBO.iconset
106 INFO: PyInstaller: 6.22.2, contrib hooks: 2026.7
106 INFO: Python: 3.12.10
173 INFO: Platform: macOS-15.7.9-x86_64-i386-64bit
173 INFO: Python environment: /Library/Frameworks/Python.framework/Versions/3.12
174 INFO: wrote /Users/runner/work/TBO/TBO/build/tmp/TBO.spec
206 INFO: Module search paths (PYTHONPATH):
['/Library/Frameworks/Python.framework/Versions/3.12/lib/python312.zip',
 '/Library/Frameworks/Python.framework/Versions/3.12/lib/python3.12',
 '/Library/Frameworks/Python.framework/Versions/3.12/lib/python3.12/lib-dynload',
 '/Library/Frameworks/Python.framework/Versions/3.12/lib/python3.12/site-packages',
 '/Users/runner/work/TBO/TBO/src']
664 INFO: Appending 'datas' from .spec
678 INFO: checking Analysis
678 INFO: Building Analysis because Analysis-00.toc is non existent
678 INFO: Looking for Python shared library...
689 INFO: Using Python shared library: /Library/Frameworks/Python.framework/Versions/3.12/Python
689 INFO: Running Analysis Analysis-00.toc
689 INFO: Target bytecode optimization level: 0
690 INFO: Initializing module dependency graph...
692 INFO: Initializing module graph hook caches...
714 INFO: Analyzing modules for base_library.zip ...
2619 INFO: Processing standard module hook 'hook-encodings.py' from '/Library/Frameworks/Python.framework/Versions/3.12/lib/python3.12/site-packages/PyInstaller/hooks'
3293 INFO: Processing standard module hook 'hook-math.py' from '/Library/Frameworks/Python.framework/Versions/3.12/lib/python3.12/site-packages/PyInstaller/hooks'
3869 INFO: Processing standard module hook 'hook-heapq.py' from '/Library/Frameworks/Python.framework/Versions/3.12/lib/python3.12/site-packages/PyInstaller/hooks'
6011 INFO: Processing standard module hook 'hook-pickle.py' from '/Library/Frameworks/Python.framework/Versions/3.12/lib/python3.12/site-packages/PyInstaller/hooks'
9023 INFO: Caching module dependency graph...
9125 INFO: Analyzing /Users/runner/work/TBO/TBO/src/tbo/__main__.py
10318 INFO: Processing standard module hook 'hook-PyQt6.QtCore.py' from '/Library/Frameworks/Python.framework/Versions/3.12/lib/python3.12/site-packages/PyInstaller/hooks'
10737 INFO: Processing standard module hook 'hook-PyQt6.py' from '/Library/Frameworks/Python.framework/Versions/3.12/lib/python3.12/site-packages/PyInstaller/hooks'
11848 INFO: Processing standard module hook 'hook-PyQt6.QtGui.py' from '/Library/Frameworks/Python.framework/Versions/3.12/lib/python3.12/site-packages/PyInstaller/hooks'
13666 INFO: Processing standard module hook 'hook-PyQt6.QtWidgets.py' from '/Library/Frameworks/Python.framework/Versions/3.12/lib/python3.12/site-packages/PyInstaller/hooks'
14089 INFO: Processing standard module hook 'hook-PyQt6.QtSvg.py' from '/Library/Frameworks/Python.framework/Versions/3.12/lib/python3.12/site-packages/PyInstaller/hooks'
14567 INFO: Processing standard module hook 'hook-xml.py' from '/Library/Frameworks/Python.framework/Versions/3.12/lib/python3.12/site-packages/PyInstaller/hooks'
14617 INFO: Processing standard module hook 'hook-xml.etree.cElementTree.py' from '/Library/Frameworks/Python.framework/Versions/3.12/lib/python3.12/site-packages/PyInstaller/hooks'
14789 INFO: Processing standard module hook 'hook-PyQt6.QtSvgWidgets.py' from '/Library/Frameworks/Python.framework/Versions/3.12/lib/python3.12/site-packages/PyInstaller/hooks'
15270 INFO: Analyzing hidden import 'PyQt6.QtPrintSupport'
15387 INFO: Processing standard module hook 'hook-PyQt6.QtPrintSupport.py' from '/Library/Frameworks/Python.framework/Versions/3.12/lib/python3.12/site-packages/PyInstaller/hooks'
15574 INFO: Processing module hooks (post-graph stage)...
15640 INFO: Processing standard module hook 'hook-PyQt6.QtDBus.py' from '/Library/Frameworks/Python.framework/Versions/3.12/lib/python3.12/site-packages/PyInstaller/hooks'
16789 INFO: Performing binary vs. data reclassification (310 entries)
16923 INFO: Looking for ctypes DLLs
16936 INFO: Analyzing run-time hooks ...
16938 INFO: Including run-time hook 'pyi_rth_inspect.py' from '/Library/Frameworks/Python.framework/Versions/3.12/lib/python3.12/site-packages/PyInstaller/hooks/rthooks'
16943 INFO: Including run-time hook 'pyi_rth_pyqt6.py' from '/Library/Frameworks/Python.framework/Versions/3.12/lib/python3.12/site-packages/PyInstaller/hooks/rthooks'
16947 INFO: Processing pre-find-module-path hook 'hook-_pyi_rth_utils.py' from '/Library/Frameworks/Python.framework/Versions/3.12/lib/python3.12/site-packages/PyInstaller/hooks/pre_find_module_path'
16949 INFO: Processing standard module hook 'hook-_pyi_rth_utils.py' from '/Library/Frameworks/Python.framework/Versions/3.12/lib/python3.12/site-packages/PyInstaller/hooks'
16954 INFO: Including run-time hook 'pyi_rth_pkgutil.py' from '/Library/Frameworks/Python.framework/Versions/3.12/lib/python3.12/site-packages/PyInstaller/hooks/rthooks'
16984 INFO: Creating base_library.zip...
17030 INFO: Looking for dynamic libraries
18496 INFO: Warnings written to /Users/runner/work/TBO/TBO/build/tmp/TBO/warn-TBO.txt
18529 INFO: Graph cross-reference written to /Users/runner/work/TBO/TBO/build/tmp/TBO/xref-TBO.html
19167 INFO: checking PYZ
19167 INFO: Building PYZ because PYZ-00.toc is non existent
19167 INFO: Building PYZ (ZlibArchive) /Users/runner/work/TBO/TBO/build/tmp/TBO/PYZ-00.pyz
19530 INFO: Building PYZ (ZlibArchive) /Users/runner/work/TBO/TBO/build/tmp/TBO/PYZ-00.pyz completed successfully.
19575 INFO: EXE target arch: x86_64
19575 INFO: Code signing identity: None
19584 INFO: checking PKG
19585 INFO: Building PKG because PKG-00.toc is non existent
19585 INFO: Building PKG (CArchive) TBO.pkg
19605 INFO: Building PKG (CArchive) TBO.pkg completed successfully.
19606 INFO: Bootloader /Library/Frameworks/Python.framework/Versions/3.12/lib/python3.12/site-packages/PyInstaller/bootloader/Darwin-64bit/runw
19606 INFO: checking EXE
19606 INFO: Building EXE because EXE-00.toc is non existent
19606 INFO: Building EXE from EXE-00.toc
19607 INFO: Copying bootloader EXE to /Users/runner/work/TBO/TBO/build/tmp/TBO/TBO
19608 INFO: Converting EXE to target arch (x86_64)
21569 INFO: Removing signature(s) from EXE
21614 INFO: Modifying Mach-O image UUID(s) in EXE
21620 INFO: Appending PKG archive to EXE
21621 INFO: Fixing EXE headers for code signing
21642 INFO: Rewriting the executable's macOS SDK version (26.2.0) to match the SDK version of the Python library (12.1.0) in order to avoid inconsistent behavior and potential UI issues in the frozen application.
21645 INFO: Re-signing the EXE
21697 INFO: Building EXE from EXE-00.toc completed successfully.
21708 INFO: checking COLLECT
21709 INFO: Building COLLECT because COLLECT-00.toc is non existent
21709 INFO: Building COLLECT COLLECT-00.toc
34623 INFO: Building COLLECT COLLECT-00.toc completed successfully.
34649 INFO: checking BUNDLE
34649 INFO: Building BUNDLE because BUNDLE-00.toc is non existent
34649 INFO: Building BUNDLE BUNDLE-00.toc
39964 INFO: Signing the BUNDLE...
40704 INFO: Building BUNDLE BUNDLE-00.toc completed successfully.
40719 INFO: Build complete! The results are available in: /Users/runner/work/TBO/TBO/build/dist
cp: /Users/runner/work/TBO/TBO/LICENSE: No such file or directory
Error: Process completed with exit code 1.
```

Creo que debo revisar en macOS

---


Por favor el del paquete deb ese debes hacerlo funcionar pues estoy en Linux

