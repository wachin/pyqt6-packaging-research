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
| `pyqt6-windows-installer-signing` | Building a Windows installer (Inno Setup or NSIS), or setting up Authenticode signing. |
| `pyqt6-release-integrity` | Setting up checksums, lockfiles, provenance and CI hardening. |

## The rule these skills follow

**A Skill must not present unverified findings as procedure.**

This matters more than it sounds. An agent follows a Skill confidently, so
encoding a guess as an instruction produces a silent, repeated failure — which
is worse than having no Skill at all. Every Skill here therefore carries a
"What is NOT verified here" section, and the two largest gaps in the research
are handled by *omission* rather than by confident advice:

- **There is still no antivirus / VirusTotal Skill.** Of the six upstream case
  studies, none measured anything about detections. Two measurements exist, both
  on the owner's own applications: TBO (2026-10, Nuitka 0/71 against PyInstaller
  3/73 in both layouts, plus a rebuilt-bootloader arm at 2/70) and Lucio IVA
  Calculator (2026-06, reported by its maintainer as 0/68 installer and 0/65
  portable ZIP). Both are Windows-only, one is self-reported, and the totals come
  from two applications written by one person. That is a lead, not a procedure —
  a Skill built on it would teach an agent to generalise from a very small
  sample. The two packaging Skills state the measurements precisely as evidence
  and say what they do not support. Earn the Skill by repeating the measurement
  on more applications, not by accumulating two results.
- **Nuitka is not presented as a solution.** No upstream case study uses it; both
  of the owner's applications use it on Windows and PyInstaller on Linux and
  macOS. The decisions Skill states that pattern with its confidence label and
  points at the experiment instead of recommending the switch outright.

Conversely, the skills lean hard on what *is* solid: the `.deb` audit procedure,
the GLIBC baseline rule, inside-out macOS signing, the Inno and NSIS installer
recipes with the signing order, and the specific CI failures that were actually
hit and fixed.

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

`SKILLS-VERIFICATION.md` is the audit of what these Skills actually cover: a
matrix of the five common release artifacts (AppImage, `.deb`, macOS `.zip`,
Windows portable `.zip`, Windows installer) against the Skill and section that
produces each, the defects that audit found and fixed, and the list of what is
still not verified. Read it before trusting a Skill for a new project, and re-run
it whenever an evidence pack is regenerated at a new commit.

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
