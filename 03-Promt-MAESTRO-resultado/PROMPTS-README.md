Creé los dos prompts en:
03-Promt-MAESTRO-resultado/PROMPT-01-FIX-TBO-PACKAGING.md — prompt para reparar TBO
03-Promt-MAESTRO-resultado/PROMPT-02-NUEVO-PROYECTO-PYQT6.md — prompt para proyecto nuevo desde cero
Antes de escribirlos exploré el repositorio TBO completo y confirmé la causa raíz de cada fallo:
Resumen de lo que encontré (para que los prompts sean precisos)
Job	Causa raíz
build-deb	actions/setup-python pone un Python en PATH (/opt/hostedtoolcache/.../python3.12) distinto del del sistema; el apt python3-build solo instala build en /usr/bin/python3. Por eso python3.12 -m build falla con "No module named build".
build-windows (Nuitka)	__version__ = "2.0.0.dev0" + .0 → 2.0.0.dev0.0; Nuitka exige versión numérica de 4 partes.
build-macos	build_macos.sh espera build/tmp/TBO.iconset, pero generate_icon.py crea el iconset junto a la fuente (src/tbo/resources/icon.iconset).
build-flatpak	ghcr.io/flathub/flathub-infra:latest ya no existe / no es pública.
build-appimage	No existe ningún pipeline AppImage en TBO.
Cómo usar los prompts
Prompt 01 ya incluye los logs exactos que me pasaste y las rutas de los archivos a tocar. Se lo pegas a un agente (opencode, Codex, B.AI, etc.) con acceso al repo TBO.
Prompt 02 está pensado para que lo coloques junto a los 3 documentos maestros en el nuevo proyecto (o se los des al agente con la ruta) — define la arquitectura completa desde el primer commit para que los 4 builds pasen sin tropiezos.
Ambos prompts respetan tus reglas: los documentos maestros no se modifican, todo lo no probado se marca [TEMPLATE — MUST BE TESTED], y no hay credenciales reales.
