# The Installer Wrapper Experiment

A controlled measurement of what actually changes a Windows installer's
VirusTotal verdict. It was run on **ksnip-pyqt6**, a PyQt6 application packaged
with the same recipe as Lucio IVA Calculator (Nuitka `--standalone` on
`windows-2025`, a portable ZIP, an NSIS installer built in CI), on 2026-10-31.

The question it answers is the one section 6 of `PACKAGING_STUDY.md` could only
pose: *why* does an installer built like this one come back clean while other
installers of the same application do not.

## Method

Four installers were built from **one identical Nuitka payload**: 662 files,
92 MB on disk, the same compiled `ksnip-pyqt6.exe`, the same Qt runtime, the
same translations and assets. Between rounds only the NSIS wrapper changed.

The portable ZIP produced from that payload was submitted in every round and was
clean in every round, so the payload was never a variable.

| Round | makensis | Script shape | Installer bytes | SHA-256 | VirusTotal |
|---|---|---|---|---|---|
| A | 3.13.0 | minimal: MUI2, 5 pages, 1 section, no bitmaps, solid LZMA | 34,773,313 | `843d8dc22bb4443b42e182bee22ba005eb179b17473ca5eb16a432d90f9b0da1` | **1 / 70** |
| B | 3.13.0 | same as A, `ZLIB` | 43,620,334 | `2bf446134b045befd00684ce1fd9ea27d8a32bb9c950c1a2892b33cec90887b3` | **1 / 69** |
| C | 3.10.0 | same as A, `ZLIB` | 43,620,272 | `4001c7b94b52954ed1e0dfd5cfba3dd9f0b2a2349cca9e165a6892f76aa42f11` | **1 / 69** |
| D | 3.12.0 | reference layout: MUI v1, 6 pages, 4 sections, header and welcome bitmaps, `XPStyle on`, `ZLIB` | 43,795,903 | `6a6d52fe36d3870345630adb98755341d83467808157b2b01dce440540db5ec1` | **0 / 67** |

Reports:

- A <https://www.virustotal.com/gui/file/843d8dc22bb4443b42e182bee22ba005eb179b17473ca5eb16a432d90f9b0da1>
- B <https://www.virustotal.com/gui/file/2bf446134b045befd00684ce1fd9ea27d8a32bb9c950c1a2892b33cec90887b3>
- C <https://www.virustotal.com/gui/file/4001c7b94b52954ed1e0dfd5cfba3dd9f0b2a2349cca9e165a6892f76aa42f11>
- D <https://www.virustotal.com/gui/file/6a6d52fe36d3870345630adb98755341d83467808157b2b01dce440540db5ec1>

Every detection in A, B and C came from a single engine, **Trapmine**, and every
one of them was a bare ML score with no family name:

| Round | Trapmine verdict |
|---|---|
| A | `Malicious.high.ml.score` |
| B | `Malicious.high.ml.score` |
| C | `Malicious.moderate.ml.score` |
| D | `Undetected` |

In round D the same engine reports `Undetected` and the page reads
"No security vendors flagged this file as malicious". Of the 67 engines that
answered, five could not process the file type (Avast-Mobile, BitDefenderFalx,
Cynet, Symantec Mobile Insight, Trustlook) and two reported nothing (Google,
Zillya).

Note on hashes: rounds A and C were scanned as CI produced them. Rounds B and D
were scanned as the owner's own rebuild of the same configuration. Rebuilding the
same recipe produces the same size and a different digest, because NSIS embeds
the payload file timestamps; the CI build of round D is
`d1ea33bb69ea7d9713e6a743e7c4857c8947231f420fb6cccc688db1abd8fd46`, also
43,795,903 bytes.

## Compile statistics

`makensis` prints the shape of the installer it produced. Rounds A-C are the
minimal script; round D is the port of this project's script, and it lands on the
same numbers as the reference.

| Statistic | Lucio IVA Calculator 0.1.1 | Round A | Round D |
|---|---|---|---|
| Pages / sections | 6 pages, 4 sections (1 required) | 5 pages, 1 section | 6 pages, 4 sections (1 required) |
| Section table | 8,288 bytes | 2,072 bytes | 8,288 bytes |
| Install instructions | 549 | 1,107 | 1,092 |
| Uninstall instructions | 280 | 83 | 280 |
| EXE header (raw / compressed) | 312,320 / 39,936 | 49,152 / 38,912 | 157,696 / 39,936 |
| Install data | 81,435,057 | 94,429,613 | 94,778,274 |
| Total size (ratio) | 30,743,863 (37.5%) | 34,773,313 (36.7%) | 43,795,903 (46.0%) |

The compressed header of round D is byte-for-byte the same size as the
reference's, 39,936 bytes, and the section table and uninstall code match
exactly. That is the sense in which round D "is built like the reference": the
compiled binary has the same internal proportions, not merely the same options.

### One deviation from the reference

The reference ships a single 256x256 32-bit icon (`assets/app-icon.ico`), and so
did rounds A-C. Round D replaced it with a multi-resolution icon, 16 to 256 px.
That is a deliberate deviation and not part of the recipe: it was present in the
clean build, so it did not hurt, but it should not be read as a cause. The recipe
is the page set, the sections, the bitmaps and `XPStyle`.

## What each change did

**Compression (A to B).** `SetCompressor /SOLID lzma` became `SetCompressor
ZLIB`. The installer grew by 8.8 MB, from 36.7% to 46.0% of the payload, and the
verdict did not move: same engine, same `Malicious.high.ml.score`. Compression is
not the lever.

**Stub version (B to C).** The same script compiled with makensis 3.10.0 instead
of 3.13.0 moved Trapmine from `high` to `moderate`. The verdict stayed positive,
but the score responded to the stub alone.

**Script shape (C to D).** Two things changed at once: the stub went from 3.10.0
to 3.12.0, and the script went from the minimal MUI2 layout to the reference
layout. The verdict went from `moderate` to `Undetected`.

The experiment therefore does **not** separate the stub version from the script
shape. Both were changed together because both are part of "build it like the
reference", which is the recipe being tested. The two builds that would separate
them are cheap and have not been run:

1. round D's script compiled with makensis 3.10.0;
2. round C's script compiled with makensis 3.12.0.

Whoever runs them should scan both and record the hashes here.

## What this establishes

- **The payload is not what is being scored.** The same 92 MB sits inside all
  four installers, and the ZIP that carries it unchanged is clean every time.
- **The wrapper is.** Three wrappers of one payload produced three different
  Trapmine verdicts, and the only clean one is the one that matches a widely
  deployed installer layout.
- **The effect is not binary.** `high`, `moderate`, `undetected` is a continuous
  score responding to the binary, which is what an ML verdict looks like and
  what a signature match does not.
- **Size is not it.** Round D is the largest installer of the four and the only
  clean one.

## What this does not establish

- **n = 1 application, one engine that spoke.** 67 engines were silent on round
  D; three had something to say about A-C; only Trapmine said anything in both
  rounds. This is a strong within-engine signal and a weak across-engine one.
- **No vendor statement.** The mechanism below is inferred from the shape of the
  data. No engine has published its features.
- **Scores drift.** A clean result is a moment, not a property. Re-scan before
  relying on it.
- **It is not a technique for making a suspicious binary look clean.** The
  recipe is "build the installer the way mainstream installers are built", which
  is a design decision anyone can audit. Nothing here involves packing,
  obfuscation, stub replacement or binary mutation, and none of those should be
  added.

## Why the shape plausibly matters

An ML verdict of the form `Malicious.<severity>.ml.score` is a score on a
feature vector. Such models behave like density estimators over the population
they were trained on: common shapes score low, rare shapes score high, intent is
not an input.

- A **minimal NSIS installer** - five pages, one section, no bitmaps, a
  single-resolution icon, a 49 KB header - is rare among published desktop
  software and common among small custom NSIS droppers. Sparse region.
- A **mainstream installer** - six pages including a components page, four
  sections, header and welcome bitmaps, `XPStyle`, a full version resource - is what commercial Windows software looks like. Dense
  region.
- A **brand-new stub** has produced almost none of the installers in
  circulation; the stub that has been the Chocolatey default for years has
  produced a large share of them.

The same reading explains why the portable ZIP is never flagged: a ZIP is not an
executable, and the model is not asked the same question about it.
