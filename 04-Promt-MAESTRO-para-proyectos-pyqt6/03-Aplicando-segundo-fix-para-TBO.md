
me falla en GitHub Actios:

https://github.com/wachin/TBO/actions

al dar clic en "Actions" en "Build executables" me da falla porque los "workflow runs" no pasan, me da estos errores:

## en "Build .deb"

```
1s
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
/opt/hostedtoolcache/Python/3.12.14/x64/bin/python3.12: No module named build
E: pybuild pybuild:389: build: plugin pyproject failed with: exit code=1: python3.12 -m build --skip-dependency-check --no-isolation --wheel --outdir /home/runner/work/TBO/TBO/.pybuild/cpython3_3.12_tbo  
dh_auto_build: error: pybuild --build -i python{version} -p 3.12 returned exit code 13
make: *** [debian/rules:6: build] Error 25
dpkg-buildpackage: error: debian/rules build subprocess returned exit status 2
Error: Process completed with exit code 2.
```

---

## en "build-windows" en "Build standalone executable with Nuitka":

```
Run powershell -NoProfile -ExecutionPolicy Bypass -File packaging/build_windows.ps1
  ICO: D:\a\TBO\TBO\src\tbo\resources\icon.ico
Nuitka-Options: Used command line options:
Nuitka-Options:   --standalone --assume-yes-for-downloads --remove-output --verbose --msvc=latest --enable-plugin=pyqt6 --follow-import-to=tbo --windows-console-mode=disable --windows-icon-from-ico=D:\a\TBO\TBO\src\tbo\resources\icon.ico --company-name=TBO --product-name=TBO --file-description="TBO comic editor" --file-version=2.0.0.dev0.0 --product-version=2.0.0.dev0.0 --copyright="Copyright (c) 2026 Washington Indacochea Delgado" --include-package=tbo --include-package-data=tbo --include-data-dir=D:\a\TBO\TBO\data\doodle=tbo\data\doodle --include-data-dir=D:\a\TBO\TBO\translations=tbo\translations --output-filename=TBO.exe --output-dir=D:\a\TBO\TBO\build\tmp\nuitka D:\a\TBO\TBO\src\tbo\__main__.py
FATAL: Invalid version number --file-version='2.0.0.dev0.0'.
D:\a\TBO\TBO\packaging\build_windows.ps1 : Nuitka output executable was not found.
At D:\a\TBO\TBO\packaging\build_windows.ps1:59 char:5
+     Write-Error "Nuitka output executable was not found."
+     ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : NotSpecified: (:) [Write-Error], WriteErrorException
    + FullyQualifiedErrorId : Microsoft.PowerShell.Commands.WriteErrorException,build_windows.ps1
 
Error: Process completed with exit code 1.
```

Nota: Para Windows yo usé Nuitka porque me pasó las pruebas en VirusTotal (con PyInstaller me daba virus)

---

## En "build-macos" en "Build macOS App with PyInstaller":

```
Run bash packaging/build_macos.sh
Workspace root is /Users/runner/work/TBO/TBO
  iconset: /Users/runner/work/TBO/TBO/src/tbo/resources/icon.iconset
/Users/runner/work/TBO/TBO/build/tmp/TBO.iconset:Iconset not found.
Error: Process completed with exit code 1.
```

---


## En "build-flatpak" en "Initialize containers":

```
Checking docker version
  /usr/bin/docker version --format '{{.Server.APIVersion}}'
  '1.48'
  Docker daemon API version: '1.48'
  /usr/bin/docker version --format '{{.Client.APIVersion}}'
  '1.48'
  Docker client API version: '1.48'
Clean up resources from previous jobs
  /usr/bin/docker ps --all --quiet --no-trunc --filter "label=b0cd17"
  /usr/bin/docker network prune --force --filter "label=b0cd17"
Create local container network
  /usr/bin/docker network create --label b0cd17 github_network_f25e1ef9d902498f85d7698255ce5a2a
  996a854ecf29655d1b6b056c381f2886a83146bf3d9ad35c532db96533a0e699
Starting job container
  /usr/bin/docker --config /home/runner/work/_temp/.docker_f80344aa-e774-405f-be1f-e58236198f15 login ghcr.io -u wachin --password-stdin
  /usr/bin/docker --config /home/runner/work/_temp/.docker_f80344aa-e774-405f-be1f-e58236198f15 pull ghcr.io/flathub/flathub-infra:latest
  Error response from daemon: manifest unknown
  Warning: Docker pull failed with exit code 1, back off 5.028 seconds before retry.
  /usr/bin/docker --config /home/runner/work/_temp/.docker_f80344aa-e774-405f-be1f-e58236198f15 pull ghcr.io/flathub/flathub-infra:latest
  Error response from daemon: manifest unknown
  Warning: Docker pull failed with exit code 1, back off 5.488 seconds before retry.
  /usr/bin/docker --config /home/runner/work/_temp/.docker_f80344aa-e774-405f-be1f-e58236198f15 pull ghcr.io/flathub/flathub-infra:latest
  Error response from daemon: manifest unknown
  Error: Docker pull failed with exit code 1
```

Nota: Para mi no es importante flatpak, pero si se lo puede hacer funcionar bien, y si haya que desabilitarlo no me importaría, yo en realidad nunca uso flatpak.

## Y me falta el "build-appimage"

Este me falta.

---

y el promt que quiero que me hagas debe decirle al Agente de IA que lea los tres archivos los cuales los he puesto en la carpeta: 


/home/wachin/Dev3/pyqt6-packaging-research/03-Promt-MAESTRO-resultado/MASTER_PYQT6_PACKAGING_GUIDE.md
/home/wachin/Dev3/pyqt6-packaging-research/03-Promt-MAESTRO-resultado/PACKAGING_EVIDENCE_MATRIX.md
/home/wachin/Dev3/pyqt6-packaging-research/03-Promt-MAESTRO-resultado/PYQT6_MASTER_PACKAGING_TUTORIAL.md

para que en base a estos tres archivos encuentre la solución y lo haga funcionar en GitHub Actions. Y en este caso que me cree el build para AppImage.


2. La siguiente cosa que quiero es que al iniciar un proyecto en GitHub desde cero de un programa que quiero hacer en PyQt6 donde tengo colocado el ROADMAP.md con las indicaciones, allí al lado de él pondré esos tres archivos en una carpeta y necesito que me crees un promt para decirle al Agente de IA que debe guiarse en ellos para que al final cuando ya esté listo no haya problmeas con GitHub Actions al momento de crear ejecutables para Windows .exe, para macOS, para Linux paquete deb y AppImage.

---




