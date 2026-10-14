# Reporting a false positive: who to contact, and how

Companion to `LEGITIMATE-FALSE-POSITIVE-REDUCTION.md`. That document explains
what can be changed on the build side and what cannot; this one covers the one
route that actually clears a report page.

## The misconception worth clearing up first

**VirusTotal does not flag anything.** It aggregates verdicts produced by other
companies' engines, and it says so itself:

> **VirusTotal only aggregates data from a variety of vendors.** We produce no
> verdicts of our own and as such, we can't modify these results. […] If you do
> reach out to us, we will tell you to reach out to the vendors, as we will not be
> able to modify any results of scans.
> — <https://docs.virustotal.com/docs/false-positive-contacts>

That is why there is no "report a false positive" button on a file report: there
is nobody at VirusTotal to press it for. The report page is a **summary of other
people's opinions**, and the only way to change one is to change the opinion of
the engine that holds it.

VirusTotal does publish the contacts, on the page quoted above — it is simply not
linked from the file report, which is why it is easy to conclude that no route
exists:

- **Official list:** <https://docs.virustotal.com/docs/false-positive-contacts>
- **Community mirror** (plain-text emails, kept updated):
  <https://gist.github.com/skmedix/6cdce9d6d3b464c1bd719b72d1f6bce4>

Always cross-check a community-listed address against the official page before
sending; community lists go stale.

## The engines that matter for TBO

Four, from the measurements in
`experiments/pyinstaller-vs-nuitka/RESULTS-2026-10-TBO.md`:

| Engine | Detection | Where to report |
|---|---|---|
| **Bkav Pro** | `W32.Malware.7730AFD` | `fpreport@bkav.com` (also `bkav@bkav.com`) |
| **SecureAge** | `Malicious` | <https://www.secureage.com/support/report-false-positive> |
| **Zillya** | `Trojan.Script.2226` | <https://zillya.ua/ru/nakhodit-virus-v-chistom-faile-lozhnoe-srabatyvanie> |
| **Skyhigh (SWG)** | `BehavesLike.Win32.Backdoor.rc` | Skyhigh's malware-submission form |

Notes that save time:

- **Report one engine at a time.** A single message to four vendors gets
  half-answered by all four.
- **SecureAge may not be the originating verdict.** SecureAPlus runs a
  "Universal AV" that aggregates other engines, so its `Malicious` may be a
  re-report. Say so in the message and ask which engine produced it — fixing the
  underlying one could clear this one too.
- **Fixing a primary engine can cascade.** Several engines license other
  companies' technology, so one acceptance can remove several detections at once.
  If a vendor replies that the verdict comes from a partner, report it there as
  well.
- **`BehavesLike.…` is a behavioural verdict**, worth calling out explicitly in the
  message: it is not a signature match on a known family.

## A message that works

Keep it short, factual, and give the reviewer everything needed to act without
asking you a question. Replace the bracketed parts.

```text
Subject: False positive report — TBO (open-source PyQt6 application)
         [detection name]

Dear [vendor] virus lab,

I am reporting a false positive on TBO, an open-source comic editor written in
Python/PyQt6 and distributed under the GPL.

Detection details
  Detection name : [exact name as VirusTotal shows it]
  SHA-256        : [hash]
  VirusTotal     : https://www.virustotal.com/gui/file/[hash]
  Product version: 2.0.0

Why I believe this is a false positive

  * All source code is public: https://github.com/wachin/TBO
  * The binary is an unsigned PyInstaller build. It contains no obfuscation,
    no packer and no self-modifying code.
  * At the time of writing, [N] of [M] engines on VirusTotal flag it. Every
    major engine — Microsoft, Kaspersky, BitDefender, ESET, Sophos, Google,
    Fortinet, CrowdStrike, Symantec, Trend Micro — reports it as clean.
  * The detection name is generic and does not correspond to any known malware
    family for this file.

The file can be downloaded from [release URL], and the exact bytes this report
concerns are the SHA-256 above.

Please review and remove the detection if you agree.

Thank you for your time.

[Your name]
https://github.com/wachin/TBO
```

Two things make this land rather than bounce: **the exact SHA-256** (the vendor
cannot act on "my program is flagged") and **the link to public source**. Without
those it reads as a complaint from a stranger.

## Mechanics

- **Attach the sample when the vendor asks for one.** Password-protect the ZIP
  with the password `infected`, which is the convention every AV lab expects, so
  that the mail gateway does not strip or quarantine it.
- **Include the VirusTotal link in every message.** It gives the reviewer the
  context of what other engines think, which speeds up triage.
- **Upload to VirusTotal before reporting.** If the file has never been seen, the
  report link will not exist yet.
- **Expect 24–72 hours**, and longer for smaller vendors.
- **Re-scan after each confirmation** and keep the count. That is the number that
  ends an argument: `3/73` becoming `0/73` is a fact, and a screenshot of it is
  worth more than any explanation.
- **Track it in the release notes**, with dates. If someone accuses the project
  again, the record shows what was reported, when, and what the vendors answered.

## Signing: what the options actually look like

Signing is the lever the research supports, and it is reasonable not to sign
everything at once. Two realities worth knowing before planning around them:

- **SignPath Foundation is not guaranteed.** It is the standard free route for
  open-source projects (<https://signpath.org/apply>), but it is an application
  with a review, and projects with little external reputation do get declined.
  One documented case (a fork of mRemoteNG) was declined in 2026-03 and fell back
  to a paid certificate; that project's notes are a useful read before applying:
  <https://github.com/robertpopa22/mRemoteNG/blob/main/docs/AV_FALSE_POSITIVE_SUBMISSION.md>
- **The cheap fallbacks have a catch.** An OV certificate is comparatively
  inexpensive but is typically delivered on a hardware token, which cannot be
  used for unattended signing in GitHub Actions. A cloud-HSM service can, for a
  monthly fee and with identity validation. Worth pricing both before deciding.

So the practical order for a project like TBO is: report the false positives
first, because it is free and it addresses the visible symptom, and treat signing
as the slower structural improvement for whichever program matters most.

## The line that does not move

Everything here changes what a **vendor** believes about a file, by giving them
accurate information about software that is genuinely theirs to review. It is the
opposite of changing the file so a scanner cannot recognise it. Do not obfuscate,
pack, mutate or rebuild to dodge a signature — that is what makes a detection
legitimate, and it is why the approach above is the one that holds up.
