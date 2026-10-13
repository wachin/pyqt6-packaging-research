# Prompts for PyQt6 packaging

Two prompts were produced at the end of the second-level analysis. Both live in
this directory.

| Prompt | Purpose |
|---|---|
| `PROMPT-01-FIX-TBO-PACKAGING.md` | Repair the failing build jobs of an existing application (TBO). |
| `PROMPT-02-NUEVO-PROYECTO-PYQT6.md` | Start a new PyQt6 project so its packaging works from the first commit. |

## Root causes confirmed before writing them

The whole TBO repository was explored first, so that the prompts could be
precise:

| Job | Root cause |
|---|---|
| `build-deb` | `actions/setup-python` puts a different Python on `PATH` (`/opt/hostedtoolcache/.../python3.12`) than the system one; apt's `python3-build` only installs `build` for `/usr/bin/python3`. That is why `python3.12 -m build` fails with "No module named build". |
| `build-windows` (Nuitka) | `__version__ = "2.0.0.dev0"` plus `.0` gives `2.0.0.dev0.0`; Nuitka requires a four-part numeric version. |
| `build-macos` | `build_macos.sh` expects `build/tmp/TBO.iconset`, but `generate_icon.py` creates the iconset next to the source (`src/tbo/resources/icon.iconset`). |
| `build-flatpak` | `ghcr.io/flathub/flathub-infra:latest` no longer exists / is not public. |
| `build-appimage` | No AppImage pipeline existed in TBO at all. |

## How to use the prompts

**Prompt 01** already includes the exact logs and the paths of the files to
touch. Paste it into an agent (opencode, Codex, B.AI, etc.) that has access to
the repository.

**Prompt 02** is meant to be placed next to the three master documents in the new
project (or given to the agent with the path). It defines the complete
architecture from the first commit so that the four builds pass without
problems.

Both prompts respect the project rules: the master documents are not modified,
everything unproven is marked `[TEMPLATE — MUST BE TESTED]`, and no real
credentials are included.
