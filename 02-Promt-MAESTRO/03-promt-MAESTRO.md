# COMPARATIVE RESEARCH: PyQt6 CROSS-PLATFORM PACKAGING

You are now working in the repository:

/home/wachin/Dev3/pyqt6-packaging-research

This repository contains the results of a previous research phase in which several real-world open-source Python/Qt desktop projects were individually investigated.

Your task is NOT to repeat those individual investigations.

Your task is to perform a SECOND-LEVEL COMPARATIVE ANALYSIS of all five case studies and produce a rigorous, evidence-based MASTER GUIDE for packaging PyQt6 applications professionally on:

- Windows
- Linux
- macOS

The ultimate purpose is to derive a practical packaging architecture that can later be applied to my own open-source PyQt6 applications.

============================================================
# 1. THE FIVE CASE STUDIES
============================================================

The five projects/case studies are:

1. CARA

Result directory:

/home/wachin/Dev3/pyqt6-packaging-research/CARA-resultados/

Files:

01_resultado_de_Codex_CLI.md
PACKAGING_STUDY.md
PYQT6_PACKAGING_TUTORIAL.md


2. CustomKnight-Creator

Result directory:

/home/wachin/Dev3/pyqt6-packaging-research/CustomKnight-Creator-resultados/

Files:

01_resultados_opencode_B.AI_Api.md
PACKAGING_STUDY.md
PYQT6_PACKAGING_TUTORIAL.md


3. dikte

Result directory:

/home/wachin/Dev3/pyqt6-packaging-research/dikte-resultados/

Files:

01_Codex_CLI_reporte.md
PACKAGING_STUDY.md
PYQT6_PACKAGING_TUTORIAL.md


4. napari

There are TWO related result directories:

/home/wachin/Dev3/pyqt6-packaging-research/napari-resultados/

/home/wachin/Dev3/pyqt6-packaging-research/napari-packaging-resultados/

The first represents the main napari repository.

The second represents the dedicated napari packaging repository.

Treat them as ONE napari case study with TWO complementary evidence sources.

napari-resultados:

01_opencode_B.AI_API_resultado.md
PACKAGING_STUDY.md
PYQT6_PACKAGING_TUTORIAL.md

napari-packaging-resultados:

01_resultados_por_opencode_con_DeepSeek_V4_Flash_(B.AI).md
PACKAGING_STUDY.md
PYQT6_PACKAGING_TUTORIAL.md


5. pyzo

Result directory:

/home/wachin/Dev3/pyqt6-packaging-research/pyzo-resultados/

Files:

01_resultados_de_Codex_CLI.md
PACKAGING_STUDY.md
PYQT6_PACKAGING_TUTORIAL.md


============================================================
# 2. FIRST TASK: READ EVERYTHING
============================================================

Before writing any conclusions, read ALL of the following files.

Do not read only the PACKAGING_STUDY.md files.

The files named:

01_*.md

contain the original investigation/reasoning/report produced by the individual AI agents.

The files named:

PACKAGING_STUDY.md

contain the structured technical study.

The files named:

PYQT6_PACKAGING_TUTORIAL.md

contain the practical recommendations derived from each project.

All three types are valuable.

Read every file completely.

Do not assume that the PACKAGING_STUDY.md contains everything.

Do not assume that the PYQT6_PACKAGING_TUTORIAL.md is necessarily correct.

The purpose of this second-level analysis is precisely to compare the evidence and identify:

- agreements
- disagreements
- contradictions
- project-specific techniques
- reusable techniques
- legacy techniques
- unsupported recommendations
- missing information
- techniques that appear repeatedly
- techniques that are only used by one project
- recommendations that are theoretically attractive but not demonstrated by the case studies


============================================================
# 3. IMPORTANT: DO NOT BLINDLY TRUST THE PREVIOUS AI AGENTS
============================================================

The previous studies were produced by different AI agents and different models.

Therefore they may contain:

- incorrect assumptions
- incomplete investigations
- mistaken conclusions
- outdated information
- copied recommendations
- hallucinated commands
- overly general recommendations
- contradictions between projects

You must critically compare them.

If two studies disagree, DO NOT silently choose one.

Instead classify the disagreement.

For example:

[CONFLICT]

Project A says:
"..."

Project B says:
"..."

Evidence available:
...

Conclusion:
...

Confidence:
HIGH / MEDIUM / LOW

If the evidence is insufficient, explicitly say:

"Cannot be determined from the available studies."

Do not invent an answer.


============================================================
# 4. DISTINGUISH FOUR LEVELS OF KNOWLEDGE
============================================================

For every important recommendation distinguish between:

LEVEL 1 — OBSERVED IMPLEMENTATION

The technique is actually implemented by the project.

Example:

"dikte actually uses PyInstaller onedir."

LEVEL 2 — REPEATED IMPLEMENTATION

The technique is independently used by multiple projects.

Example:

"PyInstaller onedir is used by 3 of the 5 projects."

LEVEL 3 — RECOMMENDATION

A previous agent recommends the technique, but the case studies do not necessarily demonstrate it.

LEVEL 4 — INFERENCE

The recommendation is your own technical conclusion derived from comparing the evidence.

These levels MUST NOT be mixed.

Use labels such as:

[OBSERVED]
[REPEATED]
[RECOMMENDED]
[INFERENCE]
[NOT VERIFIED]


============================================================
# 5. CREATE A COMPARISON MATRIX
============================================================

Create a comprehensive comparison table covering at least:

- Project
- PyQt6/PySide6
- Python versions
- Windows packaging tool
- Windows build mode
- Windows installer
- Windows signing
- Windows notarization/reputation mechanisms
- UPX
- Antivirus/VirusTotal discussion
- Linux packaging tool
- AppImage
- AppImage construction method
- Linux `.deb`
- Debian packaging method
- Linux dependency strategy
- macOS packaging tool
- `.app`
- `.dmg`
- macOS code signing
- Hardened Runtime
- notarization
- GitHub Actions
- build matrix
- release automation
- dependency pinning
- reproducibility
- checksums
- artifact verification
- Qt plugins
- Qt translations
- resource handling
- external binaries
- special platform-specific handling

For each cell use:

YES
NO
PARTIAL
UNKNOWN
NOT APPLICABLE

Do not infer YES simply because a technology is mentioned.

There must be evidence.


============================================================
# 6. SECOND MATRIX: TECHNIQUE FREQUENCY
============================================================

Create a second table listing important techniques and how many projects actually use them.

Example:

| Technique | CARA | CustomKnight | dikte | napari | pyzo | Count |
|---|---|---|---|---|---|---|
| PyInstaller | YES | YES | YES | ... | ... | ... |
| Nuitka | ... | ... | ... | ... | ... | ... |
| onedir | ... | ... | ... | ... | ... | ... |
| onefile | ... | ... | ... | ... | ... | ... |
| Inno Setup | ... | ... | ... | ... | ... | ... |
| Code signing | ... | ... | ... | ... | ... | ... |
| AppImage | ... | ... | ... | ... | ... | ... |
| DEB | ... | ... | ... | ... | ... | ... |
| macOS signing | ... | ... | ... | ... | ... | ... |
| notarization | ... | ... | ... | ... | ... | ... |

This table must be based only on evidence from the studies.


============================================================
# 7. BUT FREQUENCY IS NOT ENOUGH
============================================================

DO NOT conclude:

"Technique X is best because 4/5 projects use it."

That would be an invalid conclusion.

A technique may be common because:

- it is easy
- it is old
- the projects have similar origins
- the project has not modernized its packaging
- it is suitable only for a particular application

Therefore evaluate every important technique using:

1. Frequency
2. Evidence quality
3. Technical rationale
4. Project maturity
5. Cross-platform suitability
6. Maintenance burden
7. Security implications
8. Reproducibility
9. User experience
10. Long-term maintainability


============================================================
# 8. WINDOWS: SPECIAL INVESTIGATION
============================================================

This is one of the most important parts of the entire project.

Compare:

PyInstaller
versus
Nuitka

Do NOT declare a winner prematurely.

Investigate:

- onefile
- onedir
- standalone
- compiler-generated executables
- bootloaders
- UPX
- compression
- startup behavior
- bundle structure
- build time
- runtime behavior
- Qt compatibility
- dependency handling
- installer integration
- signing
- antivirus false positives
- SmartScreen
- VirusTotal

Most importantly:

Determine what evidence exists regarding antivirus detections.

Create a specific table:

| Technique | Evidence from projects | Evidence strength | Possible antivirus impact |
|---|---|---|---|

Do NOT claim:

"PyInstaller causes antivirus detections."

Do NOT claim:

"Nuitka does not cause antivirus detections."

Do NOT claim:

"onedir eliminates false positives."

Instead explain what can actually be supported by the evidence.


============================================================
# 9. DESIGN A CONTROLLED ANTIVIRUS EXPERIMENT
============================================================

Based on the research, design a legitimate experiment that could later be performed on the same PyQt6 application.

The experiment should compare, where practical:

A. PyInstaller onedir
B. PyInstaller onefile
C. Nuitka standalone
D. Nuitka onefile

Keep as many variables identical as possible:

- same source code
- same Python version
- same PyQt6 version
- same dependencies
- same application metadata
- same icon
- same build environment
- same release version
- same signing identity
- no UPX unless deliberately testing UPX
- same installer technology where possible

Define:

- what should be measured
- what should be recorded
- what VirusTotal can and cannot tell us
- why a VirusTotal result is not an absolute security verdict
- how to report legitimate false positives
- how code signing changes the experiment
- how reproducible builds affect interpretation

Do not provide antivirus evasion techniques.

The goal is legitimate software distribution.


============================================================
# 10. WINDOWS CODE SIGNING
============================================================

Compare what the projects actually do.

Investigate:

- Authenticode
- `signtool`
- certificate types
- executable signing
- DLL signing
- installer signing
- timestamping
- SmartScreen
- GitHub Releases

Determine:

- Which projects sign?
- Which do not?
- Which sign only the installer?
- Which sign internal binaries?
- Which use certificates?
- Which use CI secrets?

Then produce a recommended signing sequence.

Clearly distinguish:

OBSERVED IN CASE STUDIES

from:

RECOMMENDED FOR NEW PROJECTS.


============================================================
# 11. LINUX APPIMAGE
============================================================

Compare the AppImage approaches used by the projects.

Investigate:

- PyInstaller → AppDir → appimagetool
- linuxdeploy
- linuxdeploy-plugin-qt
- appimage-builder
- custom AppDir construction
- AppRun
- `.desktop`
- icons
- Qt plugins
- Python runtime
- external libraries
- GLIBC compatibility
- RPATH
- LD_LIBRARY_PATH
- host system dependencies

Determine which approaches are:

[REPEATED]
[PROJECT-SPECIFIC]
[LEGACY]
[RECOMMENDED]
[NOT VERIFIED]

Pay particular attention to the Linux distribution used for building AppImages.

Explain the relationship between:

build distribution
and
minimum supported GLIBC.


============================================================
# 12. DEBIAN PACKAGES
============================================================

Compare all `.deb` approaches found.

Investigate:

- Debian-native packaging
- `debian/`
- `dpkg-deb`
- `debhelper`
- `dh`
- `lintian`
- Python dependencies
- PyQt6 dependencies
- bundled runtimes
- system libraries
- installation paths
- `.desktop`
- icons
- AppStream metadata
- upgrades
- architecture

Then recommend an architecture for a PyQt6 `.deb`.

Do not assume that the AppImage strategy should simply be copied into a `.deb`.


============================================================
# 13. macOS
============================================================

Compare:

- `.app`
- PyInstaller
- Nuitka
- py2app
- `.dmg`

Then deeply compare:

- ad-hoc signing
- Developer ID
- hardened runtime
- entitlements
- notarization
- stapling

Determine which projects actually implement each step.

Create the ideal modern release sequence based on evidence.


============================================================
# 14. PYQT6 / QT PACKAGING
============================================================

Compare how the projects handle:

- Qt platform plugins
- image plugins
- TLS
- multimedia
- WebEngine
- SQL plugins
- QML
- translations
- fonts
- SVG
- `.qrc`
- external resources
- runtime paths

Identify common PyInstaller/Nuitka problems.

Create a section:

"Qt/PyQt6 packaging lessons that appear repeatedly."


============================================================
# 15. EXTERNAL BINARIES
============================================================

Some applications bundle or invoke external programs.

Compare how the projects handle:

- ffmpeg
- helper executables
- subprocesses
- PATH
- LD_LIBRARY_PATH
- RPATH
- executable discovery

Identify cases where PyInstaller/Nuitka environment changes can interfere with external programs.

Explain reusable solutions only when supported by evidence.


============================================================
# 16. GITHUB ACTIONS
============================================================

Compare all CI/CD systems.

Determine:

- runner OS
- build matrix
- Python versions
- architecture
- dependency installation
- cache strategy
- artifact generation
- signing
- notarization
- release creation
- checksums
- versioning
- tags
- secrets

Then design a recommended GitHub Actions architecture for a new PyQt6 project.

Do not blindly copy any one project's workflow.


============================================================
# 17. DEPENDENCY PINNING
============================================================

Compare how projects control:

- Python versions
- PyQt6 versions
- PyInstaller versions
- Nuitka versions
- appimagetool
- linuxdeploy
- installer tools

Determine whether versions are:

- pinned exactly
- range constrained
- floating
- obtained from latest releases

Analyze the effect on reproducibility.

Produce a recommendation for release builds.


============================================================
# 18. REPRODUCIBLE BUILDS
============================================================

Compare:

- pinned dependencies
- lock files
- hashes
- build images
- fixed OS versions
- deterministic builds
- artifact checksums
- SBOM
- attestations

Determine which practices are actually used.

Then recommend a realistic reproducibility strategy for a small open-source PyQt6 project.


============================================================
# 19. SECURITY AND SOFTWARE SUPPLY CHAIN
============================================================

Compare:

- source transparency
- signed releases
- checksums
- code signing
- certificates
- GitHub Actions secrets
- dependency pinning
- SBOM
- attestations
- release provenance

Do not recommend unnecessarily complicated enterprise systems if they are inappropriate for a small open-source project.

Design a realistic progression:

BASIC
BETTER
PROFESSIONAL


============================================================
# 20. IDENTIFY TECHNIQUES THAT APPEAR IN MULTIPLE PROJECTS
============================================================

Create a section:

"Techniques Repeated Across Multiple Projects"

For each technique state:

- projects using it
- evidence
- why it may be useful
- limitations
- whether it should enter the master tutorial

Then create:

"Techniques Found in Only One Project"

These should NOT automatically be rejected.

Explain whether they appear to be:

- genuinely specialized
- innovative
- unnecessary
- legacy
- application-specific
- potentially worth testing


============================================================
# 21. IDENTIFY CONTRADICTIONS
============================================================

Create:

"Contradictions and Disagreements Between Case Studies"

Examples:

Project A:
PyInstaller onefile

Project B:
PyInstaller onedir

Project C:
Nuitka standalone

Do not simply choose one.

Explain:

- why each project might have chosen it
- technical tradeoffs
- evidence
- which situation each approach may fit

Do the same for:

- AppImage
- DEB
- macOS
- signing
- installers
- dependency handling


============================================================
# 22. CREATE A DECISION TREE
============================================================

Create a decision tree for a developer starting a NEW PyQt6 application.

For example:

START
 |
 +-- Windows?
 |     |
 |     +-- Need portable?
 |     |
 |     +-- Need installer?
 |     |
 |     +-- PyInstaller or Nuitka?
 |
 +-- Linux?
 |     |
 |     +-- AppImage?
 |     |
 |     +-- DEB?
 |
 +-- macOS?
       |
       +-- .app
       |
       +-- DMG
       |
       +-- signing
       |
       +-- notarization

Make the actual decision tree much more detailed.


============================================================
# 23. CREATE A RECOMMENDED ARCHITECTURE
============================================================

Design a modern packaging architecture for a NEW open-source PyQt6 application.

It should cover:

Windows
Linux AppImage
Linux DEB
macOS

The architecture should include:

- source repository
- dependency management
- build environment
- packaging
- testing
- signing
- checksums
- GitHub Actions
- release artifacts

Do not copy any single project.

Construct the architecture from the strongest evidence found across all five.


============================================================
# 24. CLASSIFY EVERY MAJOR RECOMMENDATION
============================================================

Every major recommendation in the final guide must have one of these classifications:

[REPEATED + STRONG EVIDENCE]

[REPEATED + MODERATE EVIDENCE]

[OBSERVED BUT PROJECT-SPECIFIC]

[RECOMMENDED FROM TECHNICAL REASONING]

[EXPERIMENTAL]

[NOT VERIFIED]

[NOT RECOMMENDED]

This is important because I do not want the final tutorial to disguise inference as fact.


============================================================
# 25. CREATE THE MASTER DOCUMENT
============================================================

Create:

MASTER_PYQT6_PACKAGING_GUIDE.md

at:

/home/wachin/Dev3/pyqt6-packaging-research/

The document should contain:

# MASTER GUIDE: Professional PyQt6 Packaging

## 1. Executive Summary

## 2. The Five Case Studies

## 3. Comparative Matrix

## 4. Technique Frequency Matrix

## 5. What Multiple Projects Have in Common

## 6. Important Differences

## 7. Contradictions and Tradeoffs

## 8. Windows Packaging

## 9. PyInstaller

## 10. Nuitka

## 11. PyInstaller vs Nuitka

## 12. Windows Antivirus / VirusTotal

## 13. Windows Code Signing

## 14. Windows Installers

## 15. Linux AppImage

## 16. Linux GLIBC Compatibility

## 17. Linux DEB

## 18. PyQt6 and Qt Plugins

## 19. Resources and Translations

## 20. External Binaries

## 21. macOS `.app`

## 22. macOS Signing

## 23. macOS Notarization

## 24. DMG

## 25. GitHub Actions

## 26. Dependency Pinning

## 27. Reproducible Builds

## 28. Supply Chain Security

## 29. Recommended Architecture

## 30. Decision Tree

## 31. Controlled PyInstaller/Nuitka Experiment

## 32. Common Mistakes to Avoid

## 33. What NOT to Copy From the Case Studies

## 34. Recommended Release Checklist

## 35. Final Conclusions


============================================================
# 26. CREATE A PRACTICAL STEP-BY-STEP TUTORIAL
============================================================

Also create:

PYQT6_MASTER_PACKAGING_TUTORIAL.md

This document should be practical enough that I can eventually use it to package my own PyQt6 applications.

It must include:

- directory structures
- configuration examples
- commands
- PyInstaller examples
- Nuitka examples
- AppImage examples
- DEB examples
- macOS examples
- GitHub Actions examples
- signing examples
- verification commands
- testing procedures
- release checklist

BUT:

Do not present untested examples as guaranteed working commands.

Clearly label templates:

[TEMPLATE — MUST BE TESTED]

Use placeholders instead of real credentials.

Never include private keys or secret values.


============================================================
# 27. CREATE A THIRD DOCUMENT: EVIDENCE TABLE
============================================================

Create:

PACKAGING_EVIDENCE_MATRIX.md

This should be a compact evidence-oriented reference.

For every major conclusion record:

- technique
- project
- evidence file
- evidence location
- observed behavior
- conclusion
- confidence

Example:

| Technique | Project | Evidence | Observation | Confidence |
|---|---|---|---|---|
| PyInstaller onedir | dikte | ... | ... | HIGH |
| AppImage | dikte | ... | ... | HIGH |
| Authenticode | ... | ... | ... | ... |

This document is important because the final tutorial must remain traceable to the original research.


============================================================
# 28. DO NOT MODIFY THE ORIGINAL STUDIES
============================================================

Do NOT modify:

CARA-resultados/
CustomKnight-Creator-resultados/
dikte-resultados/
napari-resultados/
napari-packaging-resultados/
pyzo-resultados/

Do not overwrite their:

PACKAGING_STUDY.md
PYQT6_PACKAGING_TUTORIAL.md
01_*.md

The second-level analysis must produce NEW files.


============================================================
# 29. IF INFORMATION IS MISSING
============================================================

Never fill missing information with assumptions.

Use:

"UNKNOWN"

or:

"NOT ESTABLISHED BY THE CASE STUDIES"

or:

"REQUIRES DIRECT EXPERIMENT"

This is especially important for:

- VirusTotal
- antivirus behavior
- SmartScreen
- performance
- startup speed
- executable size
- compatibility
- notarization
- signing
- reproducibility


============================================================
# 30. EXTERNAL WEB RESEARCH
============================================================

If Internet access is available, you MAY perform additional research.

However, clearly distinguish:

CASE-STUDY EVIDENCE

from:

OFFICIAL DOCUMENTATION

from:

EXTERNAL TECHNICAL RESEARCH

Prioritize:

1. Actual repository evidence
2. Official documentation
3. Official tool documentation
4. Official issue trackers
5. High-quality technical sources

Do not allow external information to overwrite what the case studies actually show.

If an external source contradicts a case study, document the contradiction.


============================================================
# 31. SOURCE TRACEABILITY
============================================================

Every major claim should be traceable.

When referring to a project, include:

- project name
- original study filename
- relevant section
- file path from the original repository when the study provides it

Do not invent line numbers.

If the study does not provide enough evidence for exact source location, say so.


============================================================
# 32. FINAL RECOMMENDATION MUST BE PRAGMATIC
============================================================

The final recommendation should be designed for an open-source developer, not a large corporation.

Consider:

- cost
- complexity
- maintenance
- free/open-source tooling
- GitHub Actions
- code signing costs
- Apple Developer requirements
- build infrastructure
- developer time
- user experience

Do not recommend an expensive or complicated system merely because it is theoretically more secure.


============================================================
# 33. FINAL RELEASE CHECKLIST
============================================================

Create a practical checklist similar to:

WINDOWS

[ ] Version updated
[ ] Dependencies controlled
[ ] Build environment controlled
[ ] Application built
[ ] Qt plugins verified
[ ] Resources verified
[ ] Antivirus scan performed
[ ] Code signing performed
[ ] Signature verified
[ ] Installer created
[ ] Installer signed
[ ] Installer signature verified
[ ] SHA256 generated
[ ] Tested on clean Windows system

LINUX APPIMAGE

[ ] Build distribution selected
[ ] GLIBC compatibility considered
[ ] AppDir verified
[ ] Qt plugins verified
[ ] `.desktop` verified
[ ] Icon verified
[ ] AppImage created
[ ] AppImage tested on target distributions
[ ] SHA256 generated

LINUX DEB

[ ] Debian metadata verified
[ ] Dependencies verified
[ ] Architecture verified
[ ] Desktop integration verified
[ ] lintian checked
[ ] Installation tested
[ ] Upgrade tested
[ ] Removal tested

MACOS

[ ] `.app` created
[ ] Resources verified
[ ] Qt frameworks verified
[ ] Signing performed
[ ] Hardened Runtime configured
[ ] Notarization performed
[ ] Stapling performed
[ ] DMG created
[ ] DMG tested
[ ] SHA256 generated

RELEASE

[ ] Version consistent
[ ] Changelog updated
[ ] Artifacts tested
[ ] Checksums published
[ ] Source code available
[ ] Git tag created
[ ] GitHub Release created


============================================================
# 34. FINAL SUMMARY
============================================================

At the end of the process provide a concise summary containing:

1. The strongest packaging technique found across the studies.
2. The strongest Windows strategy.
3. PyInstaller vs Nuitka conclusion.
4. What we actually know about antivirus false positives.
5. The strongest AppImage strategy.
6. The strongest DEB strategy.
7. The strongest macOS strategy.
8. The strongest signing strategy.
9. The strongest GitHub Actions architecture.
10. The five most reusable techniques.
11. The five most important things NOT to copy.
12. The biggest unresolved questions.
13. The experiments that should be performed before finalizing the packaging architecture.

Do not simply declare one tool "the winner".

The goal is to derive a robust packaging strategy from multiple real-world implementations.

============================================================
# 35. MOST IMPORTANT PRINCIPLE
============================================================

The purpose of this analysis is NOT:

"Which project has the best packaging?"

The purpose is:

"What can we learn by comparing five real-world implementations, and which techniques have enough evidence to become part of a reusable professional PyQt6 packaging methodology?"

Think like a software build/release engineer performing a comparative technical study.

Be skeptical.

Be precise.

Do not hallucinate.

Do not hide uncertainty.

Do not confuse frequency with quality.

Do not confuse an AI recommendation with evidence.

Produce the three new documents:

MASTER_PYQT6_PACKAGING_GUIDE.md
PYQT6_MASTER_PACKAGING_TUTORIAL.md
PACKAGING_EVIDENCE_MATRIX.md

in:

/home/wachin/Dev3/pyqt6-packaging-research/
