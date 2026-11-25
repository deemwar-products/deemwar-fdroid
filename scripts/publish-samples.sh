#!/usr/bin/env bash
# Build + publish the Deemwar sample apps (hello, counter) to https://fdroid.deemwar.com/repo.
# Usage: scripts/publish-samples.sh <versionCode> [versionName]   (writes versions.properties for you)
set -euo pipefail
VC=${1:?versionCode}; VN=${2:-1.$((VC-1))}
L=~/upipay-release-local; R=$L/fdroid; S=$L/site
APP=${SAMPLES_REPO:-$HOME/muthu/deemwarworkspace/fdroid-samples}
HERE=$(cd "$(dirname "$0")" && pwd)
export JAVA_HOME=~/.jenv/versions/openjdk64-17.0.19
cd "$APP"
printf '# one versionCode for all sample apps; bump before publishing\nversionCode=%s\nversionName=%s\n' "$VC" "$VN" > versions.properties
sec run SAMPLES_APP_KS_PASS -- sh -c "KS_PASS=\$SAMPLES_APP_KS_PASS KS_PATH=$L/deemwar-samples.jks gradle --no-daemon -q assembleRelease"
for m in hello counter; do
  cp "$m/build/outputs/apk/release/$m-release.apk" "$R/repo/com.deemwar.sample.${m}_$VC.apk"
  cp "$HERE/../metadata/com.deemwar.sample.$m.yml" "$R/metadata/"
done
(cd "$R" && fdroid update -c && fdroid update)
rsync -a --delete --exclude diff --exclude status "$R/repo" "$S/"
(cd "$S" && sec run CF_PAGES_TOKEN=CLOUDFLARE_API_TOKEN -- \
  wrangler pages deploy . --project-name deemwar-fdroid --branch main --commit-dirty=true)
sleep 5
for m in hello counter; do "$HERE/verify.sh" "$VC" "com.deemwar.sample.$m"; done
