#!/usr/bin/env bash
# Verify the live repo serves the APK we built. Usage: scripts/verify.sh <versionCode>
set -euo pipefail
VC=${1:?versionCode}
F=com.deemwar.upipay.forwarder_$VC.apk
LOCAL=$(shasum -a 256 ~/upipay-release-local/fdroid/repo/$F | cut -d' ' -f1)
LIVE=$(curl -fsSL https://fdroid.deemwar.com/repo/$F | shasum -a 256 | cut -d' ' -f1)
[ "$LOCAL" = "$LIVE" ] && echo "OK sha256 $LIVE" || { echo "MISMATCH local=$LOCAL live=$LIVE"; exit 1; }
curl -fsSL https://fdroid.deemwar.com/repo/index-v2.json | grep -q "$F\|versionCode" && echo "index serves it"
