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

This repository pins six upstream projects as **Git submodules**, and keeps the
owner's own application (`PyQt6-Apps/TBO`) alongside them as an ordinary
independent clone that this repository deliberately **ignores**. All seven were
obtained **to be read**, so that their packaging, signing, installer and
release-automation infrastructure could be studied side by side. Nothing more.

A forker running

```bash
git clone --recurse-submodules https://github.com/wachin/pyqt6-packaging-research.git
# or, after a plain clone:
git submodule update --init --recursive
```

will end up with six full source trees on disk (TBO is not fetched, because it is
not a submodule). **None of them is part of this project. They are exhibits.**

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

Six of them are Git submodules. The seventh, TBO, is an independent clone kept
under `PyQt6-Apps/TBO/` and ignored by this repository.

| Path | Upstream | How it is tracked | Why it is here |
|---|---|---|---|
| `dikte/` | yusufipk/dikte | submodule | Small PyQt6 app; the only implemented AppImage in the set. |
| `CustomKnight-Creator/` | cmot17/CustomKnight-Creator | submodule | The negative example: onefile, unsigned, no release automation. |
| `pyzo/` | pyzo/pyzo | submodule | Mature desktop app; onedir, Inno Setup, full macOS signing in CI. |
| `CARA/` | pguntermann/CARA | submodule | Real-world PyQt6 app; local macOS signing and notarization. |
| `napari/` | napari/napari | submodule | Large scientific app; rejected freezing in favour of conda. |
| `napari-packaging/` | napari/packaging | submodule | The most auditable installer pipeline in the set. |
| `PyQt6-Apps/TBO/` | wachin/TBO | **independent clone, ignored here** | The owner's own app; the only source of validated `.deb`, AppImage and Windows evidence. |

None of these is a dependency of this repository. All of them are exhibits.

### The one exception: TBO

`PyQt6-Apps/TBO` is the repository owner's own application, not a third-party
case study. It is deliberately **not** a submodule: it is a separate clone with
its own `.git`, ignored by this repository through `/PyQt6-Apps/TBO/` in
`.gitignore`.

It is therefore the one tree here that **is** meant to be edited and built. When
working on it:

- commit in its own repository (`git -C PyQt6-Apps/TBO ...`), never through this
  one — this repository tracks nothing about it;
- trigger its GitHub Actions by pushing to `https://github.com/wachin/TBO`;
- everything else in section 1 still applies unchanged: no imports, no dependency
  manifests, and the six submodules remain read-only.

Because TBO is not a submodule, `git submodule update --init --recursive` will
never touch it, and a fresh clone of this repository does not contain it.

---

## 2. Caveat: when this file is not loaded

The project root is detected by walking upward from the working directory to the
first directory containing `.git`. Because **every studied tree has its own
`.git`** — the six submodules and TBO alike — an agent whose working directory is
inside one of them may not load this file at all.

Therefore:

- **Work from the repository root** when doing research work. Do not `cd` into a
  studied tree for that.
- If you are editing TBO deliberately (see "The one exception: TBO"), you will be
  inside it by necessity; carry the rules from section 1 with you.
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

One measurement now exists, so state it precisely rather than either denying or
over-claiming it. In 2026-10 the same TBO application was built three ways
(unsigned, UPX disabled, identical metadata): **both PyInstaller arms were
flagged and the Nuitka arm was not**, which also refutes the idea that `onedir`
avoids detection. It is **n = 1**, with no detection counts captured. Report it
as a lead, cite `PACKAGING_EVIDENCE_MATRIX.md` §B.1, and never generalise it into
"PyInstaller causes detections" or "Nuitka avoids them".

**No case-study project publishes any antivirus detection data.** If you are
asked about antivirus behaviour, say that the five studied projects measured
nothing, cite the single TBO measurement described above, and point at
`experiments/pyinstaller-vs-nuitka/` for the repeatable kit.

### Do not turn unverified findings into procedure

Rules and Skills must be built only from verified material. A Skill is followed
confidently by agents, so encoding a guess as an instruction causes a silent,
repeated failure — worse than having no Skill at all. See `SKILLS.md`.

If you add or extend a Skill, include a "what is NOT verified here" section.

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
| CARA, CustomKnight-Creator, dikte, TBO | **GPL** |
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
| `README.md` | What the research is, how the repository is organised, current status. |
| `SKILLS.md` | The six Skills, what they cover, and what they deliberately refuse to cover. |
| `EVIDENCE_INDEX.md` | Every evidence pack with its pinned commit and licence. |
| `<project>-resultados/` | Per-case-study `PACKAGING_STUDY.md`, `PYQT6_PACKAGING_TUTORIAL.md` and `_evidence/`. |
| `03-Promt-MAESTRO-resultado/` | Consolidated master guide, master tutorial, evidence matrix, TBO fixes. |
| `tools/extract_evidence.py` | Regenerates every evidence pack. |
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

Two traps this repository has already hit. Do not reintroduce them.

- **`.gitignore` has no effect on submodules.** A submodule is tracked as a
  gitlink (mode `160000`), and a tracked path is never ignored. What keeps
  `git status` clean is `ignore = dirty` in `.gitmodules`. Adding `dikte/`
  or `napari/` to `.gitignore` does nothing.
- **Never add unanchored directory patterns to `.gitignore`.** A bare `napari/`
  also matches `napari-resultados/_evidence/napari/`, which silently excluded
  **12 real evidence files** from git. Anchor such patterns to the root (`/x/`)
  or scope them to the directory that needs them.

Before finishing any change, verify:

```bash
git status --short
git ls-files --others --ignored --exclude-standard | grep '_evidence/'   # expect nothing
git -C <submodule> status --short                                        # expect clean
```

---

## 6. Definition of done

A change in this repository is complete when:

- [ ] No submodule working tree was modified. (TBO is not a submodule: its
      changes belong in its own repository, never in this one.)
- [ ] No evidence file was edited by hand; packs were regenerated if needed.
- [ ] `sha256sum -c SHA256SUMS` passes in every `_evidence/` directory touched.
- [ ] Any new claim is labelled with its confidence, and unverified material is
      marked as such rather than asserted.
- [ ] Any new Skill or procedure states what is not verified.
- [ ] No secret material was added.
