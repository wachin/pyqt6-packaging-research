---
name: pyqt6-macos-signing-notarization
description: Build, sign, notarize and staple a macOS .app for a PyQt6 application - inside-out codesigning, hardened runtime, entitlements, notarytool in CI, and the DMG step that is not verified.
whenToUse: Use when producing a macOS build of a Python/PyQt6 application, when codesign or notarytool fails, or when Gatekeeper blocks a released .app.
---

# macOS packaging for a PyQt6 application

Observed implementations: CARA (local script), pyzo (full CI), napari (most
auditable). Reference files, pinned to commits:

- `PYQT6-GENESIS-PACKAGING/external-PyQt6-Apps/CARA-results/_evidence/scripts/build_macos_signed.sh`
- `PYQT6-GENESIS-PACKAGING/external-PyQt6-Apps/CARA-results/_evidence/packaging/macos/entitlements.plist`
- `PYQT6-GENESIS-PACKAGING/external-PyQt6-Apps/pyzo-results/_evidence/.github/workflows/cd.yml`
- `PYQT6-GENESIS-PACKAGING/external-PyQt6-Apps/napari-packaging-results/_evidence/.github/workflows/make_bundle_conda.yml`

**Where this runs:** in GitHub Actions, as a job on `macos-15-intel` (the Intel
slice; an arm64 runner builds a different binary). Notarization in particular only
works on a runner, because it needs `notarytool` plus a certificate in a secret —
that is §5. Workflow shape: `pyqt6-packaging-decisions` §6. The real jobs:
`PYQT6-GENESIS-PACKAGING/wachin-PyQt6-Apps/TBO-results/_evidence/.github/workflows/build.yml`
(`build-macos`) and Lucio's `build_macos` / `test_macos`.

## 1. Build the `.app`

PyInstaller with a `BUNDLE` stage is the observed norm (CARA, dikte, pyzo):

```python
exe = EXE(pyz, a.scripts, [], exclude_binaries=True, name='MyApp',
          console=False, target_arch=None)
coll = COLLECT(exe, a.binaries, a.datas, name='MyApp')
app = BUNDLE(
    coll,
    name='MyApp.app',
    icon='packaging/macos/MyApp.icns',
    bundle_identifier='org.example.myapp',   # stable and reverse-DNS
    info_plist={
        'NSHighResolutionCapable': True,
        'LSMinimumSystemVersion': '11.0',
        'NSPrincipalClass': 'NSApplication',
    },
)
```

Rule: **build on the oldest macOS you intend to support**, and build separately
per architecture (arm64 and x86_64) rather than relying on a universal2 build
you have not tested. The result must run on a machine with no Python and no Qt.

### Package it as a portable `.zip`

The artifact users download is a ZIP containing the `.app`. Archive it with
`ditto`, which both owner applications do:

```bash
mkdir -p build/macos-package
cp -R dist/MyApp.app build/macos-package/
cp COPYING build/macos-package/          # optional; see below

ditto -c -k --sequesterRsrc build/macos-package build/MyApp-1.2.3-macOS-arm64.zip
```

- **`ditto`, not `zip -r`.** `zip` drops extended attributes and resource forks;
  `ditto --sequesterRsrc` is the archiver macOS expects and is what preserves a
  bundle's metadata.
- **Do not wrap the ZIP in another ZIP.** In this research one project's released
  `tbo-macos.zip` contained exactly one entry: an inner
  `TBO-2.0.0.dev0-macOS-x64.zip`. It works, and it makes every user unzip twice.
- **Keep `MyApp.app` at the archive root** — that is the macOS convention, and a
  wrapper folder is unusual here. If you also ship the licence beside it, the
  user gets two items; putting `COPYING` inside `MyApp.app/Contents/Resources/`
  gives them exactly one.
- **Match the artifact name to the architecture.** `-arm64` and `-x64` in the
  filename, because they are different binaries and a user cannot tell otherwise.

### If you are shipping it unsigned

Signing and notarizing needs a paid Apple Developer account. Without one you can
still ship, but be explicit about the consequence instead of letting users hit a
wall:

- An unsigned or unnotarized `.app` is **blocked by Gatekeeper** on first launch:
  *"MyApp is damaged and can't be opened"* or *"cannot be opened because the
  developer cannot be verified"*.
- The documented workarounds are **right-click → Open** (once), or on the command
  line `xattr -d com.apple.quarantine /Applications/MyApp.app`. Tell users this in
  the download page, not in a GitHub issue thread afterwards.
- **Ad-hoc signing (`codesign --sign -`) is not a release signature.** It does
  not remove the warning; it only satisfies the kernel's code-signature
  requirement on Apple silicon. Do not present it as signing.
- Say so in the release notes: "unsigned; right-click → Open on first launch".

The signing path in section 2 onwards is still worth following eventually:
Gatekeeper warnings cost real users, and they are the reason to buy the account
one day. They are not a reason to block a first release.

## 2. Sign **inside-out**

Sign nested code from the innermost component outwards, then the bundle last.
This is what CARA and the tutorials do, and it is more auditable than `--deep`:

```bash
APP="dist/MyApp.app"
IDENTITY="Developer ID Application: Your Name (TEAMID)"

# 1. Every nested Mach-O: helpers, .dylib, .so, frameworks.
find "$APP" -type f \( -name '*.dylib' -o -name '*.so' -o -perm -u+x \) -print0 |
while IFS= read -r -d '' f; do
  file "$f" | grep -q 'Mach-O' || continue
  codesign --force --options runtime --timestamp \
           --entitlements packaging/macos/entitlements.plist \
           --sign "$IDENTITY" "$f"
done

# 2. Frameworks.
find "$APP/Contents/Frameworks" -maxdepth 1 -name '*.framework' -print0 2>/dev/null |
while IFS= read -r -d '' fw; do
  codesign --force --options runtime --timestamp --sign "$IDENTITY" "$fw"
done

# 3. The bundle itself, last.
codesign --force --options runtime --timestamp \
         --entitlements packaging/macos/entitlements.plist \
         --sign "$IDENTITY" "$APP"

codesign --verify --deep --strict --verbose=2 "$APP"
```

Notes:

- `--options runtime` enables the **Hardened Runtime**. It is part of the
  professional baseline, not optional.
- `--timestamp` attaches a secure timestamp. Without it the signature expires
  with the certificate and your notarization does not survive.
- `--deep` (used by pyzo and dikte) is a shortcut. It is widely discouraged for
  signing because it does not always sign nested code in the right order. Prefer
  inside-out.
- **Ad-hoc signing (`codesign --sign -`) is not a release signature.** dikte
  does this in its DMG script and says so explicitly. Do not ship it as a
  production artifact.

## 3. Entitlements

Start from nothing and add only what you need. A PyQt6 app generally needs very
little; the common additions are:

```xml
<key>com.apple.security.cs.allow-unsigned-executable-memory</key>
<true/>
```

only if a dependency genuinely requires JIT or similar. Each entitlement you add
weakens the hardened runtime, so justify it in a comment — CARA's
`entitlements.plist` is a good model of a small, deliberate file.

## 4. Notarize and staple

Two observed authentication methods. Both work; pick one.

**API key (napari)** — best for CI, no keychain profile to provision:

```bash
xcrun notarytool submit dist/MyApp.zip \
  --apple-id "$APPLE_ID" \
  --team-id "$APPLE_TEAM_ID" \
  --password "$APPLE_APP_PASSWORD" \
  --wait
```

**Keychain profile (pyzo)** — store credentials once, reference by name:

```bash
xcrun notarytool store-credentials "myapp-notary" \
  --apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APPLE_APP_PASSWORD"

xcrun notarytool submit dist/MyApp.zip --keychain-profile "myapp-notary" --wait
```

Then staple and verify — **stapling is a separate step and is often forgotten**:

```bash
xcrun stapler staple dist/MyApp.app      # or the .dmg
xcrun stapler validate dist/MyApp.app
spctl --assess --type execute --verbose=4 dist/MyApp.app
```

Notarize the form you actually ship. If you ship a DMG, notarize the DMG, not
just the `.app` inside it.

## 5. CI: certificate handling

The workflow needs the Developer ID certificate as a base64 `.p12` in a secret:

```bash
KEYCHAIN="$RUNNER_TEMP/app-signing.keychain-db"
echo "$MACOS_CERT_P12_BASE64" | base64 --decode > "$RUNNER_TEMP/cert.p12"
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security import "$RUNNER_TEMP/cert.p12" -k "$KEYCHAIN" -P "$MACOS_CERT_PASSWORD" \
  -T /usr/bin/codesign
security set-key-partition-list -S apple-tool:,apple: -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security list-keychains -d user -s "$KEYCHAIN"
rm -f "$RUNNER_TEMP/cert.p12"
```

Rules: import into a **temporary** keychain, never echo a secret, always delete
the decoded certificate, and reference secrets by name only in tracked files.

## 6. DMG

pyzo and dikte create DMGs with `hdiutil`:

```bash
hdiutil create -volname "MyApp" -srcfolder dist/MyApp.app \
  -ov -format UDZO dist/MyApp.dmg
```

**Not verified in this research:** no project demonstrates a fully signed,
notarized **and stapled DMG**. pyzo's DMG is not separately notarized. If you
ship a DMG, you are beyond the evidence — test the download → open → Gatekeeper
path yourself on a clean machine.

## 7. Checklist

- [ ] Builds and runs on a clean machine with no Python/Qt.
- [ ] Bundle identifier is stable and reverse-DNS; changing it resets
      permissions and reputation.
- [ ] Every nested Mach-O signed, then the bundle, with `--options runtime` and
      `--timestamp`.
- [ ] `codesign --verify --deep --strict` passes.
- [ ] `spctl --assess` passes **after** stapling.
- [ ] Version metadata consistent with the Windows and Linux artifacts.
- [ ] Published SHA-256 for the shipped file (see `pyqt6-release-integrity`).

## Related

- Model choice: `pyqt6-packaging-decisions`
- Publish hashes and provenance: `pyqt6-release-integrity`
