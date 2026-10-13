---
name: pyqt6-release-integrity
description: Make a PyQt6 release verifiable and reproducible - dependency locking, per-artifact SHA-256 checksums, build provenance attestations, SHA-pinned CI actions, and secure secret handling.
whenToUse: Use when setting up or reviewing a release workflow for a Python/PyQt6 application, or when asked about checksums, supply-chain security, dependency pinning or release provenance.
---

# Release integrity for a PyQt6 application

This is the area with the widest gap between what mature projects do and what
small projects do. In this research, **only napari** has real dependency pinning,
SHA-pinned actions, workflow linting and build attestations. Every other project
has partial or no release-integrity practice, and **no project at all claims
reproducible builds**.

Nothing here is exotic. It is a short list, and it is the difference between an
artifact someone can trust and one they cannot.

## 1. Lock your dependencies

Without a lockfile, "the same source" produces different bytes on different
days, and no measurement you take is comparable to the next one.

- Commit a **hashed** lockfile (`requirements.txt` with `--hash=`, `uv.lock`,
  `poetry.lock`, `pylock.toml`).
- Pin the build tools too (`pyinstaller==`, `nuitka==`, `pyqt6==`). An
  unpinned build tool is an unrecorded variable.
- In CI, install from the lockfile, never with `pip install -U`.
- Record the **frozen** environment in the build output
  (`python -m pip freeze > toolchain.txt`) and attach it to the release. This is
  what makes a result traceable later; the intended pins are not evidence.

napari's approach is the model: constraints files compiled from a resolver, with
explicit upper bounds where breakage is known.

## 2. Publish a SHA-256 for every artifact

This is a universal gap: CARA, CustomKnight-Creator, dikte and pyzo publish no
checksums at all; napari generates some hashes but does not attach them.

```bash
# After all signing is complete. Order matters: hash the final bytes.
sha256sum MyApp-1.0.0-*.AppImage MyApp_1.0.0_amd64.deb > SHA256SUMS
sha256sum -c SHA256SUMS

# Windows (PowerShell)
Get-ChildItem dist -Recurse -File |
  Get-FileHash -Algorithm SHA256 |
  ForEach-Object { "{0}  {1}" -f $_.Hash.ToLower(), $_.Path } |
  Set-Content SHA256SUMS
```

Attach `SHA256SUMS` **and** the per-artifact `.sha256` files to the release.
Publish the hash in the release notes too, so it is visible without downloading.

**Hash the signed artifact.** If you sign after hashing, the published hash
describes bytes nobody has.

## 3. Attach build provenance

GitHub can attest where an artifact came from, verifiably:

```yaml
permissions:
  contents: read
  id-token: write          # required for attestation
  attestations: write

steps:
  - uses: actions/attest-build-provenance@v2
    with:
      subject-path: dist/**
```

napari does this for its wheels. It is cheap and it lets a user verify that a
download was produced by your workflow from your commit, rather than assembled
by hand.

## 4. Pin your CI actions

A floating `@v4` tag is mutable. A compromised or retagged action runs in your
release pipeline with your signing secrets.

```yaml
# Prefer a commit SHA, with the version in a comment for humans.
- uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
```

napari SHA-pins every action and runs `dependabot` to keep the pins current.
That combination is the practical answer: pin hard, automate the updates.

If you use tags for simplicity, at minimum upgrade them — `actions/checkout@v5`,
`actions/setup-python@v6`, `actions/upload-artifact@v5`,
`actions/download-artifact@v5` — because the older majors run on deprecated
Node runtimes and will stop working.

## 5. Lint the workflows themselves

napari runs **zizmor** over its workflows to catch injection, credential and
permission mistakes. Add it; a release workflow that leaks a token is worse than
no workflow.

Set least privilege at the top of every workflow:

```yaml
permissions:
  contents: read
```

Grant `id-token: write` or `attestations: write` only to the job that needs it.

## 6. Secrets

- Reference secrets by name only; never echo, never `set -x` around them.
- Never commit a certificate, private key or API token. If one leaks, rotate it
  — rewriting history is not enough.
- Import signing certificates into a **temporary** keychain or profile and
  delete the decoded material in a `finally`/post step.
- For third-party scanning services (for example VirusTotal), uploading a
  binary discloses it. Make that an explicit, opt-in choice, never a default.

## 7. Reproducible builds — be honest about this

No project in this research achieves reproducible builds. Do not claim them.
What you can realistically do:

- lock and hash dependencies;
- record exact tool versions and the frozen environment;
- record the source commit for every artifact;
- publish checksums so at least the bytes are identifiable;
- keep the build deterministic in the parts you control (no timestamps of "now"
  in embedded metadata, sorted file lists, no network fetches at build time).

That gets you **traceable** releases, which is the honest and achievable goal.
Full bit-for-bit reproducibility across PyInstaller/Nuitka, MSVC and macOS
toolchains is a research project, not a checkbox.

## 8. Test the artifact, not just the source

Only napari and pyzo launch the built artifact in CI. That is what catches a
release that imports fine from source and cannot start once frozen.

```yaml
- name: Smoke test the artifact
  run: |
    ./dist/MyApp --version
    # Linux GUI: run under a virtual display and check the log
    xvfb-run -a ./dist/MyApp --self-test --exit-after-ms 3000
```

Add a `--self-test` flag to your application that starts, verifies its bundled
resources, and exits. This is the highest-value single line of release CI.

## Checklist

- [ ] Hashed lockfile committed; build tools pinned.
- [ ] Frozen toolchain list attached to the release.
- [ ] `SHA256SUMS` published for the **signed** artifacts.
- [ ] Build provenance attested.
- [ ] Actions SHA-pinned; dependabot enabled; zizmor clean.
- [ ] `permissions: contents: read` by default.
- [ ] No secret material in the repository or in logs.
- [ ] Artifact launched in CI, not just the test suite.
- [ ] No claim of reproducible builds unless it is actually demonstrated.

## Related

- Model choice: `pyqt6-packaging-decisions`
- Platform skills: `pyqt6-deb-packaging`, `pyqt6-appimage-packaging`,
  `pyqt6-macos-signing-notarization`, `pyqt6-windows-installer-signing`
- Full reasoning: `03-Promt-MAESTRO-resultado/MASTER_PYQT6_PACKAGING_GUIDE.md`
  (§26 dependency pinning, §27 reproducible builds, §28 supply chain security)
