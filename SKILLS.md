# Skills derived from this research

Six agent Skills that turn the research in this repository into something
executable. They live in `.dsh/skills/` so they are discovered automatically in
this workspace; each is a directory containing a `SKILL.md`.

| Skill | Use it when |
|---|---|
| `pyqt6-packaging-decisions` | Starting to package a PyQt6 app. Settles onedir vs onefile, PyInstaller vs Nuitka, and the Linux package model. |
| `pyqt6-deb-packaging` | Building or fixing a `.deb`. |
| `pyqt6-appimage-packaging` | Building or fixing an AppImage. |
| `pyqt6-macos-signing-notarization` | Building, signing, notarizing or stapling a macOS `.app`. |
| `pyqt6-windows-installer-signing` | Building a Windows installer, or setting up Authenticode signing. |
| `pyqt6-release-integrity` | Setting up checksums, lockfiles, provenance and CI hardening. |

## The rule these skills follow

**A Skill must not present unverified findings as procedure.**

This matters more than it sounds. An agent follows a Skill confidently, so
encoding a guess as an instruction produces a silent, repeated failure — which
is worse than having no Skill at all. Every Skill here therefore carries a
"What is NOT verified here" section, and the two largest gaps in the research
are handled by *omission* rather than by confident advice:

- **There is still no antivirus / VirusTotal Skill.** The case studies measured
  nothing about detections, and although a first measurement now exists (TBO,
  2026-10: both PyInstaller arms flagged, the Nuitka arm not), **it is n = 1 with
  no detection counts**. That is a lead, not a procedure — a Skill built on it
  would teach an agent to generalise from a single sample. The two packaging
  Skills state the measurement precisely as evidence and say what it does not
  support. Earn the Skill by repeating the measurement, not by having one result.
- **Nuitka is not presented as a solution.** No case study uses it, and the
  single measurement is not enough to change that. The decisions Skill says so
  explicitly and points at the experiment instead.

Conversely, the skills lean hard on what *is* solid: the `.deb` audit procedure,
the GLIBC baseline rule, inside-out macOS signing, the Inno Setup signing order,
and the specific CI failures that were actually hit and fixed.

## Using them elsewhere

Copy a skill directory into any of these, in order of precedence:

```text
<your-project>/.dsh/skills/<name>/SKILL.md     # project scope (committed)
<your-project>/.agents/skills/<name>/SKILL.md  # project scope, agents convention
~/.dsh/skills/<name>/SKILL.md                  # user scope
```

**Caveat when copying:** the Skill bodies cite evidence with paths relative to
*this* repository root, for example
`dikte-resultados/_evidence/packaging/build-appimage.sh`. Those references only
resolve here. When you copy a Skill into another project, either drop the
evidence pointers or copy the relevant `_evidence/` directory alongside it.

## Keeping them honest

These skills are only as good as the research behind them, and the research has
a known gap list (`03-Promt-MAESTRO-resultado/PACKAGING_EVIDENCE_MATRIX.md`,
section E, and the Status section of the root `README.md`).

Regenerate or extend them when:

- the antivirus measurement is repeated across several releases and captures
  detection counts and engine names — only then is there something a Skill can
  state as a rule;
- the `[TEMPLATE — MUST BE TESTED]` blocks in the tutorials have actually been
  executed;
- a Skill's procedure fails in practice — that is a bug in the Skill, and the
  fix belongs here, not in a local workaround.

The test of a Skill is not whether it reads well. It is whether an agent
following only that Skill produces an artifact that works.
