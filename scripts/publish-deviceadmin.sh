#!/usr/bin/env bash
# Build a signed release of the Deemwar Device Admin app and publish it to https://fdroid.deemwar.com/repo.
# Runtime state (signing keys, repo index) lives OUTSIDE any repo in ~/upipay-release-local. Never move it in here.
# Usage: scripts/publish-deviceadmin.sh <versionCode>   (bump versionCode/versionName in fdroidadmin app/build.gradle.kts first)
set -euo pipefail
VC=${1:?versionCode}
L=~/upipay-release-local; R=$L/fdroid; S=$L/site
APP=${DEVICEADMIN_REPO:-$HOME/muthu/deemwarworkspace/fdroidadmin}
export JAVA_HOME=~/.jenv/versions/openjdk64-17.0.19
cd "$APP"
sec run DEVICEADMIN_APP_KS_PASS -- sh -c "KS_PASS=\$DEVICEADMIN_APP_KS_PASS KS_PATH=$L/deemwar-deviceadmin.jks gradle --no-daemon -q assembleRelease"
cp app/build/outputs/apk/release/app-release.apk "$R/repo/com.deemwar.deviceadmin_$VC.apk"
(cd "$R" && fdroid update -c && fdroid update)
rsync -a --delete --exclude diff --exclude status "$R/repo" "$S/"
(cd "$S" && sec run CF_PAGES_TOKEN=CLOUDFLARE_API_TOKEN -- \
  wrangler pages deploy . --project-name deemwar-fdroid --branch main --commit-dirty=true)
echo "published: https://fdroid.deemwar.com/repo (verify with: scripts/verify.sh)"
