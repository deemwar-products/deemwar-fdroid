#!/usr/bin/env bash
# Build a signed release of the UPI Forwarder app and publish it to https://fdroid.deemwar.com/repo.
# Runtime state (signing keys, repo index) lives OUTSIDE any repo in ~/upipay-release-local. Never move it in here.
# Usage: scripts/publish-upipay.sh <versionCode>   (bump versionCode/versionName in upipay app/build.gradle.kts first)
set -euo pipefail
VC=${1:?versionCode}
L=~/upipay-release-local; R=$L/fdroid; S=$L/site
APP=${UPIPAY_REPO:-$HOME/muthu/gitworkspace/upipay}
export JAVA_HOME=~/.jenv/versions/openjdk64-17.0.19
cd "$APP"
# Idempotent: a version already live is skipped; a lower one is refused.
LIVE=$(curl -fsS https://fdroid.deemwar.com/repo/index-v1.json 2>/dev/null | python3 -c 'import sys,json;d=json.load(sys.stdin);print(max([v["versionCode"] for v in d["packages"].get("com.deemwar.upipay.forwarder",[])] or [0]))' 2>/dev/null || echo 0)
WANT=$(grep -oE 'versionCode = [0-9]+' app/build.gradle.kts | grep -oE '[0-9]+')
[ "$WANT" = "$VC" ] || { echo "app/build.gradle.kts has versionCode $WANT, not $VC"; exit 1; }
if [ "$VC" -lt "$LIVE" ]; then echo "refusing: live is $LIVE, asked $VC"; exit 1; fi
SKIP_APK=0; [ "$VC" = "$LIVE" ] && { echo "versionCode $VC already live: skipping the APK, refreshing the site only"; SKIP_APK=1; }
if [ $SKIP_APK = 0 ]; then
sec run UPIPAY_APP_KS_PASS -- sh -c "UPIPAY_KS_PATH=$L/app-release.jks ./gradlew --no-daemon -q testDebugUnitTest assembleRelease"
cp app/build/outputs/apk/release/app-release.apk "$R/repo/com.deemwar.upipay.forwarder_$VC.apk"
(cd "$R" && fdroid update -c && fdroid update)
fi
# Landing page: Compose Multiplatform (wasm) build from the app repo.
./gradlew --no-daemon -q :shared:wasmJsBrowserDistribution
rsync -a shared/build/dist/wasmJs/productionExecutable/ "$S/"
cp "$R/repo/com.deemwar.upipay.forwarder_$VC.apk" "$S/upi-forwarder.apk"
rsync -a --delete --exclude diff --exclude status "$R/repo" "$S/"
(cd "$S" && sec run CLOUDFLARE_ALLPURPOSE_TOKEN=CLOUDFLARE_API_TOKEN,CLOUDFLARE_ACCOUNT_ID -- \
  wrangler pages deploy . --project-name deemwar-fdroid --branch main --commit-dirty=true)
echo "published: https://fdroid.deemwar.com/repo (verify with: scripts/verify.sh $VC)"
