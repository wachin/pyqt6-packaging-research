# AGENTS.md

Instructions for AI agents working in this repository. Read this before doing
anything else.

## 0. What this repository is

**This is a research repository. It contains no application, no library and no
installable package.**

There is nothing here to build, run, test, deploy or publish. The deliverables
are **documents and evidence**: case studies of how real projects package
software, a consolidated guide, traceable evidence packs, a controlled
experiment and a set of Skills.

You are almost certainly here to **read and to write documentation**, not to
develop software. If a task seems to require building or fixing the projects in
this repository, you have misread the task — stop and ask.

---

## 1. THE LOCK: the studied projects are reference material, not dependencies

This is the most important rule in this file, and the easiest to get wrong.

This repository pins **eight projects as Git submodules**: six third-party case
studies, plus two applications belonging to the owner
(`my-PyQt6-Apps/TBO` and `my-PyQt6-Apps/lucio-iva-calculator`). All eight were
obtained **to be read**, so that their packaging, signing, installer and
release-automation infrastructure could be studied side by side. Nothing more.

A forker running

```bash
git clone --recurse-submodules https://github.com/wachin/pyqt6-packaging-research.git
# or, after a plain clone:
git submodule update --init --recursive
```

will end up with all eight full source trees on disk, the two owner applications
included. **None of them is part of this project. They are exhibits.**

### You MUST NOT

- **Import from them.** Not `import napari`, not `from dikte import ...`, not
  anything. No code in this repository consumes them.
- **Add them as dependencies.** Never add any of them to a `pyproject.toml`,
  `requirements.txt`, `setup.py`, `setup.cfg`, lockfile or any other dependency
  manifest, and never `pip install` them as part of this project.
- **Treat their APIs as available.** They are not a toolkit you can reach for.
  If you need code, write it.
- **Treat them as the project's source.** This repository's own content is
  documentation, `tools/`, `experiments/` and `.dsh/skills/`. Everything under
  the submodule directories belongs to someone else.
- **Modify, refactor, reformat, lint, "fix" or commit inside them.** Not their
  source, not their config, not their tests. Their working trees must stay
  clean. Do not run `git add` or `git commit` with a submodule path.
- **Update them on your own initiative.** `git submodule update --remote`
  changes what the research is pinned to and invalidates every study, evidence
  pack and line-number citation. Only run it if a human explicitly asks.
- **Run their build, release, packaging or CI workflows.** Do not execute their
  `*.spec`, `*.iss`, `build-*.sh`, `debian/rules` or GitHub Actions workflows.
- **Report their contents as defects in this repository.** A dependency of
  `napari` being out of date is not a bug here. An unused import in `pyzo` is
  not a bug here. Do not open, describe or "fix" such issues.
- **Suggest upgrading, pinning or vendoring them.** They are pinned to an exact
  commit **on purpose**. Their age is the point: the studies describe the code
  at that commit.

### Why this matters

The studies cite real files by path and line number, for example
`packaging/build-appimage.sh` lines 41-49. Those citations refer to the file
**at the pinned commit**. If you update a submodule, every citation silently
points somewhere else, and the research becomes unverifiable. That is why the
submodules are pinned and why the evidence packs exist.

### The correct reflex

If you need to inspect what a studied project did, **read the evidence pack**,
never the submodule tree:

```text
<project>-resultados/_evidence/        # real packaging files, pinned to a commit
```

Each pack mirrors the original repository layout, so a citation resolves
directly. Start from `EVIDENCE_INDEX.md`.

### What the studied projects are

All eight are Git submodules. Six are third-party case studies at the top level;
two are the owner's own applications under `my-PyQt6-Apps/`.

| Path | Upstream | Why it is here |
|---|---|---|
| `dikte/` | yusufipk/dikte | Small PyQt6 app; the only implemented AppImage in the set. |
| `CustomKnight-Creator/` | cmot17/CustomKnight-Creator | The negative example: onefile, unsigned, no release automation. |
| `pyzo/` | pyzo/pyzo | Mature desktop app; onedir, Inno Setup, full macOS signing in CI. |
| `CARA/` | pguntermann/CARA | Real-world PyQt6 app; local macOS signing and notarization. |
| `napari/` | napari/napari | Large scientific app; rejected freezing in favour of conda. |
| `napari-packaging/` | napari/packaging | The most auditable installer pipeline in the set. |
| `my-PyQt6-Apps/TBO/` | wachin/TBO | The owner's own app; the only source of validated `.deb` and Flatpak-manifest evidence, and the only controlled freezer measurement. |
| `my-PyQt6-Apps/lucio-iva-calculator/` | wachin/lucio-iva-calculator | The owner's own app; switched its Windows freezer to Nuitka after antivirus results, and verifies its frozen archive's contents before publishing. |

None of these is a dependency of this repository. All of them are exhibits.

### The two owner applications

`my-PyQt6-Apps/TBO` and `my-PyQt6-Apps/lucio-iva-calculator` are the repository
owner's own applications rather than third-party case studies. They are pinned as
submodules **exactly like the other six**, so every rule in "You MUST NOT" above
applies to them unchanged.

Two things are still different about them:

1. **Their studies live beside them**, at `my-PyQt6-Apps/<app>-resultados/`. Those
   directories are ordinary tracked content of this repository: the submodule is a
   gitlink, the study next to it is normal files. Editing a study is editing this
   repository; editing the application is editing another one.
2. **The owner does change them**, so "do not commit inside them" has a practical
   exception that belongs to the human, not to an agent working on the research.
   If you are asked to change one of the two applications, do it in its own
   repository and push to its own remote:

   ```bash
   git -C my-PyQt6-Apps/TBO status
   git -C my-PyQt6-Apps/TBO commit -am "..."
   git -C my-PyQt6-Apps/TBO push origin master
   ```

   Because it is now a submodule, the parent repository then records that new
   commit as a changed gitlink. That is intended — it is what pins the research
   to the code the studies describe — but it means a push to the application is
   followed by a commit here, and the evidence packs must be regenerated so
   `PROVENANCE.md` names the new commit.

Note that `ignore = dirty` is set for all eight, so build output, `venv/` and
`__pycache__` inside those trees do not show up as modifications. A *changed
commit* still shows, deliberately.

---

## 2. Caveat: when this file is not loaded

The project root is detected by walking upward from the working directory to the
first directory containing `.git`. Because **every studied tree has its own
`.git`** — all eight submodules alike — an agent whose working directory is inside
one of them may not load this file at all.

Therefore:

- **Work from the repository root** when doing research work. Do not `cd` into a
  studied tree for that.
- If you are editing one of the two owner applications deliberately (see "The two
  owner applications"), you will be inside it by necessity; carry the rules from
  section 1 with you.
- If you find yourself operating inside `dikte/`, `pyzo/`, `CARA/`, `napari/`,
  `napari-packaging/` or `CustomKnight-Creator/`, stop: you are in the wrong
  place, and the rules in section 1 may not be in your context.

---

## 3. How to work in this repository

### Evidence packs are read-only snapshots

- **Never edit anything under `_evidence/`.** Those files are evidence. Changing
  them destroys the point of having them.
- If a citation in a study is wrong, fix **the study**, not the evidence.
- To refresh a pack (for example after a human deliberately updates a
  submodule), regenerate it — do not hand-edit:

  ```bash
  python3 tools/extract_evidence.py            # write
  python3 tools/extract_evidence.py --dry-run  # preview
  ```

- The script fails loudly if a whitelisted file is missing. Treat that as a real
  problem to report, not as something to work around by deleting the entry.

### Never present an unverified claim as a fact

This repository's value rests on separating what was observed from what was
assumed. Every claim carries a confidence label — `HIGH`, `MEDIUM`, `LOW` or
`NOT VERIFIED`. Read
`03-Promt-MAESTRO-resultado/PACKAGING_EVIDENCE_MATRIX.md`, particularly
section E, which lists what could **not** be verified.

In particular, these are **not established** and must never be stated as fact:

- that UPX increases detections;
- that code signing guarantees a clean VirusTotal result;
- the exact Qt plugin or translation inventory inside any frozen artifact;
- any *rate* — how many engines flag what, for any project.

Two measurements now exist, so state them precisely rather than either denying or
over-claiming them.

**TBO, 2026-10, built by this project.** The same application, version and PE
metadata, unsigned, UPX disabled, built four ways: **Nuitka 0/71; PyInstaller
3/73 in both onedir and onefile**; a fourth arm with the PyInstaller bootloader
compiled from source scored **2/70**. The flagging engines have generic verdicts
(`Malicious`, `BehavesLike.…`) or name no real family, while every major engine
reports clean. That shape reads as heuristic false positives, and it refutes the
idea that `onedir` avoids detection. It is **n = 1**. Cite
`PACKAGING_EVIDENCE_MATRIX.md` §B.1, where the hashes and per-engine lists are.

**Lucio IVA Calculator, 2026-06, reported by its own maintainer.** `0/68` for the
NSIS installer and `0/65` for the portable ZIP, recorded after the project moved
its Windows build from PyInstaller to Nuitka for that reason. No scan artifact was
preserved, but the two files are still in its `v0.1.1` release, so
`my-PyQt6-Apps/lucio-iva-calculator-resultados/PACKAGING_STUDY.md` §6 records their
SHA-256 and the claim can be re-queried. Confidence: **MEDIUM**, self-reported.

Never generalise either into "PyInstaller causes detections" or "Nuitka avoids
them". Never propose obfuscation or a rebuild to silence a scanner — the response
to a suspected false positive is a report to the vendor.

**Of the six upstream case studies, none publishes any antivirus detection data.**
The only figures that exist come from the owner's own two applications. If you are
asked about antivirus behaviour, say that, cite the two records above with their
confidence labels, and point at `experiments/pyinstaller-vs-nuitka/` for the
repeatable kit.

### Do not turn unverified findings into procedure

Rules and Skills must be built only from verified material. A Skill is followed
confidently by agents, so encoding a guess as an instruction causes a silent,
repeated failure — worse than having no Skill at all. See `SKILLS.md`.

If you add or extend a Skill, include a "what is NOT verified here" section.

The Skills are also published as an installable bundle
(`tools/build_skills_bundle.py`, released by `.github/workflows/release-skills.yml`
on a `skills-v*` tag). Two consequences for anyone editing `.dsh/skills/`:

- the directory name must equal the `name:` in the Skill's frontmatter, because
  the bundle refuses to build otherwise;
- the bundle carries `LICENSE`, `SKILLS.md` and `SKILLS-VERIFICATION.md` under
  `_meta/`, so a rename or a deletion of any of those breaks the release job, not
  just the docs.

After changing a Skill, run `python3 tools/build_skills_bundle.py --version
1.0.0` and confirm it still reports "reproducible".

### This is not antivirus evasion research

Treat false positives as a software distribution and reputation problem.
**Never** propose obfuscation, packing, binary mutation, encoder loops or any
other technique whose purpose is to defeat a scanner. Legitimate responses are:
code signing, consistent metadata, checksums, published source, and submitting a
false-positive report through the vendor's official portal.

### Do not copy GPL code into non-GPL projects

Licences differ sharply across the submodules:

| Project | Licence |
|---|---|
| CARA, CustomKnight-Creator, dikte, TBO, lucio-iva-calculator | **GPL** |
| napari, pyzo | BSD |
| napari/packaging | **no licence file** |

The evidence packs are for **study and citation**, not for reuse. If you adapt
anything from a GPL project into another application, say so explicitly and
flag the licensing consequence. Do not adapt anything from `napari/packaging`
at all.

### Never handle secret material

- Never commit certificates, private keys, `.pfx`/`.p12` files, API tokens or
  passwords.
- In workflow files, reference secrets **by name only**. Do not add a step that
  echoes one.
- The VirusTotal step in the experiment workflow is opt-in by design: uploading
  a binary discloses it to a third party. Never enable it silently.

---

## 4. Where things are

| Path | Contents |
|---|---|
| `README.md` | What the research is, how to use it two ways (point an agent at `PYQT6-GENESIS-PACKAGING/`, or install the Skills in DeepSeek Harness or opencode), and the current limits. |
| `SKILLS.md` | The six Skills, what they cover, and what they deliberately refuse to cover. |
| `SKILLS-VERIFICATION.md` | The audit of those Skills against the five common release artifacts, what it fixed, and what is still not verified. |
| `EVIDENCE_INDEX.md` | Every evidence pack with its pinned commit and licence. |
| `PYQT6-GENESIS-PACKAGING/` | The studies in one folder with English directory names, written to be pointed at by a person or an agent. For the six case-study packs it is the **only** copy: edit it here, and note that no source pack exists to regenerate it from. |
| `my-PyQt6-Apps/<app>-resultados/` | The two owner applications' packs, maintained as a source plus a mirror under `PYQT6-GENESIS-PACKAGING/wachin-PyQt6-Apps/`. Edit the source, then regenerate its copy. `tools/check_genesis_pack.py` enforces parity between the two, including the two permitted path rewrites. |
| `03-Promt-MAESTRO-resultado/` | Consolidated master guide, master tutorial, evidence matrix, TBO fixes. |
| `tools/extract_evidence.py` | Regenerates every evidence pack. |
| `tools/build_skills_bundle.py` | Builds the installable Skills tarball; deterministic, and it refuses a bundle a harness could not load. |
| `LICENSE` | GPL-3.0-or-later for this repository's own content: the full GPL text, then a scope notice saying what that does **not** cover (submodules, evidence packs, `napari/packaging`). The notice is at the *end* because GitHub classifies a licence from the start of the file, and any prose above the text makes it report "Other". |
| `experiments/pyinstaller-vs-nuitka/` | The repeatable build-tool experiment kit. Its own CI workflow has not been run; the equivalent comparison was measured on TBO instead. |
| `.dsh/skills/` | Agent Skills derived from the verified findings. |

### If you are asked to package a PyQt6 application

1. Load the relevant Skill from `.dsh/skills/` — start with
   `pyqt6-packaging-decisions`.
2. Follow it. Do not improvise a build system from the case studies directly.
3. Treat any `[TEMPLATE — MUST BE TESTED]` marker in the master tutorial as
   exactly that: untested. Do not present an untested template as a working
   recipe.

---

## 5. Submodule and ignore hygiene (for maintainers)

Three traps this repository has already hit. Do not reintroduce them.

- **`.gitignore` has no effect on submodules.** A submodule is tracked as a
  gitlink (mode `160000`), and a tracked path is never ignored. What keeps
  `git status` clean is `ignore = dirty` in `.gitmodules`. Adding `dikte/`
  or `napari/` to `.gitignore` does nothing.
- **Never add unanchored directory patterns to `.gitignore`.** A bare `napari/`
  also matches `PYQT6-GENESIS-PACKAGING/napari-results/_evidence/napari/`, which silently excluded
  **12 real evidence files** from git. Anchor such patterns to the root (`/x/`)
  or scope them to the directory that needs them.
- **The same trap, hit again — and then dissolved.** A bare `PyQt6-Apps/` was
  once added here while those two trees were independent clones, and it swallowed
  everything under the directory, including the `<app>-resultados/` folders that
  must be tracked. Caught before it was committed, by running `git check-ignore`
  on the paths that were about to be created. The pattern is gone now: the two
  applications are submodules, so nothing in this file can or should affect them.
  The habit is what survives — whenever you add or change an ignore rule, check
  the paths you *want* tracked as well as the ones you want ignored.

Before finishing any change, verify:

```bash
git status --short
git ls-files --others --ignored --exclude-standard | grep '_evidence/'   # expect nothing
git -C <submodule> status --short                                        # expect clean
```

---

## 6. Definition of done

A change in this repository is complete when:

- [ ] No submodule working tree was modified. (If the change is deliberately in
      one of the two owner applications, it was committed in *its* repository and
      this one only recorded the new gitlink, with the evidence packs
      regenerated.)
- [ ] No evidence file was edited by hand; packs were regenerated if needed.
- [ ] `sha256sum -c SHA256SUMS` passes in every `_evidence/` directory touched.
- [ ] `python3 tools/check_genesis_pack.py` passes, so the reader-facing copy still
      matches the canonical packs.
- [ ] Any new claim is labelled with its confidence, and unverified material is
      marked as such rather than asserted.
- [ ] Any new Skill or procedure states what is not verified.
- [ ] No secret material was added.
