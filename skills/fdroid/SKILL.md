---
name: fdroid
description: Deemwar's own F-Droid repo (fdroid.deemwar.com) for Android FOSS apps. Publish a new app version, add a new app to the repo, verify the live repo, rotate keys, or explain why F-Droid and not Play. Trigger on: publish to F-Droid, push the android app to fdroid, new apk release, add app to fdroid.deemwar.com, fdroid repo broken.
---

# fdroid: deemwar's own F-Droid repo

Live at **https://fdroid.deemwar.com** (repo URL `https://fdroid.deemwar.com/repo`). Cloudflare Pages project `deemwar-fdroid`, proxied DNS record, static files only. No approval step: we are the repo.

## Why this and not Play
Google Play rejects apps that read SMS or notifications to forward financial data. F-Droid has no such rule. Own repo = no review, ships in about a day, updates reach users automatically. Alternatives, slower: IzzyOnDroid (signed APK from GitHub Releases, short review) and official F-Droid (builds from source, weeks).

## Layout (code here, runtime outside)
| What | Where |
|---|---|
| Scripts, landing page source, app metadata | `~/muthu/deemwarworkspace/fdroid/` (this folder, git) |
| Runtime state: signing keys, repo index, built site | `~/upipay-release-local/` (**never move into a repo**) |
| `app-release.jks` | app signing key. Losing it = no more updates to installed apps |
| `fdroid/config.yml`, `fdroid/keystore.p12` | repo signing key and config (secrets) |
| `fdroid/repo/`, `fdroid/metadata/` | fdroid server working dir (APKs, index) |
| `site/` | what gets deployed: `index.html`, `_headers`, `repo/` |
| Key passwords | `sec` (`UPIPAY_APP_KS_PASS` etc.), Cloudflare via `CLOUDFLARE_ALLPURPOSE_TOKEN` |
| App source | `~/muthu/gitworkspace/upipay` (Android app, package `com.deemwar.upipay.forwarder`, Apache-2.0) |

`~/muthu/gitworkspace/upipay/release/publish.sh` just delegates to `scripts/publish-upipay.sh` here.

## Publish a new version of an existing app
1. In the app repo bump `versionCode` and `versionName` in `app/build.gradle.kts`. The versionCode must be higher than what is live.
2. Run `~/muthu/deemwarworkspace/fdroid/scripts/publish-upipay.sh <versionCode>`. It: runs unit tests + `assembleRelease` signed with the app key (via `sec`), copies the APK into the fdroid repo dir, runs `fdroid update -c` then `fdroid update` (regenerates index), rsyncs `repo/` to `site/`, and `wrangler pages deploy` to `deemwar-fdroid`.
3. Verify: `scripts/verify.sh <versionCode>` (SHA-256 of live APK equals local, index serves it).
4. On a phone: F-Droid app, add `https://fdroid.deemwar.com/repo` (or the link and fingerprint on the landing page), refresh, install or update.

Requires: `brew install fdroidserver`, Android build-tools (`apksigner`, `zipalign`), JDK 17 (`JAVA_HOME` set in the script), `sec`, `wrangler`.

## Add a different app to the repo
1. Copy `metadata/com.deemwar.upipay.forwarder.yml` to `~/upipay-release-local/fdroid/metadata/<applicationId>.yml` and edit Name, Summary, Description, Categories, License (must be FOSS: Apache-2.0, MIT, GPL...). Also keep a copy in this folder's `metadata/`.
2. Sign the app with its **own** keystore (new key in `sec`, never reuse the UPI app key). Put the APK at `fdroid/repo/<applicationId>_<versionCode>.apk`.
3. Copy `scripts/publish-upipay.sh` to `publish-<app>.sh`, change the build, ids and key names. Run it, then verify.
4. Public-repo rules for the app source still apply: `deemwar-kernel/27-skill-oss-repo.md` (owner approves per repo, 0/0/0 sweep on a fresh one-commit tree, no GitHub Actions, no internal names).

## Second app live: Deemwar Device Admin (2026-11-25)
`com.deemwar.deviceadmin` (source: `~/muthu/deemwarworkspace/fdroidadmin`, public: `deemwar-products/deemwardeviceadmin`) is our DPC + repo client. It lists every package in this repo, installs/updates with cert-pinned silent `PackageInstaller` installs (`USER_ACTION_NOT_REQUIRED` + `setRequestUpdateOwnership`), and runs a 6-hourly WorkManager sync (unmetered). Its own key: `~/upipay-release-local/deemwar-deviceadmin.jks`, password in `sec` as `DEVICEADMIN_APP_KS_PASS`. Publish with `scripts/publish-deviceadmin.sh <versionCode>` (also bumps versionCode in `app/build.gradle.kts` first; tests run as part of the build).

## How updates reach phones (the model to keep in mind)
- One tap per app, ever: the first install (or first update of an app installed by F-Droid/adb) through Deemwar Admin shows one confirm dialog and transfers installer-of-record to it. Every later version is **silent**, including the daily job.
- Silent updates fail if: targetSdk is not current for the device's Android version, or another installer still owns the package (run one update through Deemwar Admin to take ownership).
- Deemwar Admin updates itself via the F-Droid client (it hides itself from its own list).
- Work profiles only control their own sandbox; personal-profile installs are unaffected. But profiles block `adb dpm set-device-owner` (requires exactly one user, no accounts) and can disable adb entirely.
- Device Owner (fully silent including first installs) is for **dedicated phones only**: factory reset, no accounts/no Moto Secure Vault/no third-party work profile, then QR provisioning (README of deemwardeviceadmin has the payload — SIGNATURE_CHECKSUM must be the signing **cert** hash, NOT the APK file hash) or the adb fallback after checking `pm list users`. Grant owner BEFORE adding accounts.

## Repo-wide checks after any publish
`scripts/verify.sh <versionCode>` (upipay) or the publish script's tail: index lists the new version, live APK sha256 equals local, landing page + `repo/icons/icon.png` serve 200. index-v1 `hash`+`hashType` is what clients read.

## Rules and gotchas
- Never print or paste key passwords; use `sec run NAME -- cmd`. Never commit `config.yml`, `*.jks`, `*.p12`.
- The repo key and app key cannot be swapped later without users re-adding the repo or reinstalling. Back both up (`sec`, plus the `~/upipay-release-local` dir) before any machine change.
- `sec` flagged the two repo-key entries for rotation (their values had been exposed in a session). Rotating means a new repo fingerprint, so every phone must re-add the repo. Decide deliberately, before real users exist.
- Landing page shows the repo fingerprint. After any repo-key change update `site/index.html` here and in `~/upipay-release-local/site/`.
- Do not link GitHub or the owner's personal handle on deemwar surfaces (kernel ch. 14/27).

## Sample apps (test vehicles, 2026-11-25)
`com.deemwar.sample.hello` (shows version + installer + update owner: the silent-update canary) and `com.deemwar.sample.counter` (tap counter; the count must survive updates). Source: `~/muthu/deemwarworkspace/fdroid-samples` (local git, no public remote yet: publishing the source needs owner approval per kernel ch. 27). One shared key `~/upipay-release-local/deemwar-samples.jks`, alias `deemwar-samples`, password in `sec` as `SAMPLES_APP_KS_PASS`, cert SHA-256 `6bd08994e88c568bb8c7502d7d477746d36bb4fad4f123eedc12c59bda742ab1` (pinned in Device Admin since v11). Publish both: `scripts/publish-samples.sh <versionCode> [versionName]` (writes `versions.properties`, builds, publishes, runs verify for both).

## Verify any app
`scripts/verify.sh <versionCode> [package]` checks live APK sha256 == local AND index-v1 lists that version with `hashType: sha256` and the same hash. Pipe publish output with `set -o pipefail` or a failure hides behind `| tail`.

## Adding a new app: the Device Admin checklist
A new app's signing cert MUST be added to `Policy.TRUSTED_CERT_SHA256` in fdroidadmin (`Repo.kt`) and a Device Admin version published, or the app shows in the list but every install is BLOCKED. Get the cert with `apksigner verify --print-certs <apk>` (Signer #1 certificate SHA-256).
Metadata YAML: no `: ` inside Summary (fdroid update dies with "mapping values are not allowed").

## Lessons from on-device testing (Motorola Edge 60 Fusion, Android 17 / API 37)
- Signature check must use `PackageManager.getPackageArchiveInfo(GET_SIGNING_CERTIFICATES)`. A JarFile (v1) reader rejects v2-only APKs as "not signed" (UPI Forwarder is v2-only). Fixed in v11.
- PackageInstaller results need a receiver: `STATUS_PENDING_USER_ACTION` carries the confirm Intent that the app must start, else "tap does nothing". `InstallStatusReceiver` does this (v11).
- Android 11+ package visibility: without `QUERY_ALL_PACKAGES` every repo app looks "not installed" and the background worker skips everything. Fixed in v12.
- Silent updates on Android 17 needed targetSdk 35 for BOTH Device Admin and the updated app. At targetSdk 34, "Update this app?" still showed. Keep targetSdk current.
- Proven 2026-11-25: Hello v2->v3 updated with NO dialog, installer = com.deemwar.deviceadmin. First install and uninstall show exactly one system dialog each (expected without Device Owner).
- Play Protect "App scan recommended" pops on sideloaded installs. Off on the owner's phone (adb `settings put global package_verifier_enable 0` + Play Store > Play Protect > settings > Scan apps off). Re-enable: set it to 1.
- Work profiles (Moto Secure Vault, user 12) put install restrictions only on their own user. Personal-profile installs are not blocked (checked with `dumpsys user`).

## Current state (2026-11-25)
Live: Device Admin v12 (3.1: Update/Open/Uninstall per app, Update all, auto-refresh on package changes, 6-hourly WorkManager check on unmetered network), UPI Forwarder v4, Hello v3, Counter v3. Owner's phone: Device Admin v12, Hello v3 (owned by Device Admin).
