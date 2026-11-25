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

## Rules and gotchas
- Never print or paste key passwords; use `sec run NAME -- cmd`. Never commit `config.yml`, `*.jks`, `*.p12`.
- The repo key and app key cannot be swapped later without users re-adding the repo or reinstalling. Back both up (`sec`, plus the `~/upipay-release-local` dir) before any machine change.
- `sec` flagged the two repo-key entries for rotation (their values had been exposed in a session). Rotating means a new repo fingerprint, so every phone must re-add the repo. Decide deliberately, before real users exist.
- Landing page shows the repo fingerprint. After any repo-key change update `site/index.html` here and in `~/upipay-release-local/site/`.
- Do not link GitHub or the owner's personal handle on deemwar surfaces (kernel ch. 14/27).

## Current state (2026-11-22)
Version 1 live, signed `CN=UPI Forwarder`. Not yet installed on a real device. Still to build: the Go gateway that receives signed events and serves the signed config manifest (`docs/MANIFEST.md` in the upipay repo); needs one real credit SMS or notification sample to write the parser.
