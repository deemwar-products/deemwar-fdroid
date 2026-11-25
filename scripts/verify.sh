#!/usr/bin/env bash
# Verify the live repo serves the APK we built.
# Usage: scripts/verify.sh <versionCode> [package]   (package defaults to com.deemwar.upipay.forwarder)
set -euo pipefail
VC=${1:?versionCode}; PKG=${2:-com.deemwar.upipay.forwarder}
F=${PKG}_$VC.apk
LOCAL=$(shasum -a 256 ~/upipay-release-local/fdroid/repo/$F | cut -d' ' -f1)
LIVE=$(curl -fsSL "https://fdroid.deemwar.com/repo/$F?nocache=$RANDOM" | shasum -a 256 | cut -d' ' -f1)
[ "$LOCAL" = "$LIVE" ] && echo "OK $F sha256 $LIVE" || { echo "MISMATCH $F local=$LOCAL live=$LIVE"; exit 1; }
curl -fsSL https://fdroid.deemwar.com/repo/index-v1.json | python3 -c "
import json,sys; d=json.load(sys.stdin); v=[p for p in d['packages'].get('$PKG',[]) if p['versionCode']==$VC]
assert v, 'index does not list $PKG v$VC'; p=v[0]
assert p.get('hashType')=='sha256' and p.get('hash')=='$LOCAL', 'index hash mismatch'
print('index OK: $PKG v$VC hash matches')"
