#!/usr/bin/env bash
# Install/update Deemwar repo apps on a USB-connected phone via adb (shell-uid install),
# which BYPASSES a work-profile 'no_install_unknown_sources_globally' restriction (proven on
# the owner's Intune-managed Motorola, 2026-11-25). Same safety checks as Deemwar Admin:
# APK sha256 == index hash, signing cert pinned, package name matches.
# Usage:
#   scripts/phone-sync.sh                 # update every repo app already on the phone
#   scripts/phone-sync.sh <package>...    # install/update these packages
#   scripts/phone-sync.sh --list          # repo vs phone versions
# Env: ADB_SERIAL=<serial> if several devices attached.
set -euo pipefail
REPO=https://fdroid.deemwar.com/repo
PINNED="d16030fd1dae9a090bb2ad4711f64d76bc8be780d624cf9f33d3e09b64c7fd28 c0d7354c6d1b535207a11b2fd81eda9fe637a9bd7905ee2306e73aea0dd5490c 6bd08994e88c568bb8c7502d7d477746d36bb4fad4f123eedc12c59bda742ab1"
BT=$(ls -d /opt/homebrew/share/android-commandlinetools/build-tools/* | tail -1)
ADB=(adb); [ -n "${ADB_SERIAL:-}" ] && ADB=(adb -s "$ADB_SERIAL")
[ "$("${ADB[@]}" get-state 2>/dev/null)" = device ] || { echo "no phone in 'device' state (adb devices; set ADB_SERIAL)"; exit 1; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
curl -fsSL "$REPO/index-v1.json?t=$(date +%s)" -o "$TMP/index.json"
python3 -I -c '
import json,sys
d=json.load(open(sys.argv[1]))
for p,vs in sorted(d["packages"].items()):
    v=max(vs,key=lambda x:x["versionCode"])
    assert v.get("hashType","sha256")=="sha256"
    print(p,v["versionCode"],v["apkName"],v.get("hash") or v["sha256"])' "$TMP/index.json" > "$TMP/latest"
installed_vc(){ "${ADB[@]}" shell dumpsys package "$1" 2>/dev/null | sed -n 's/.*versionCode=\([0-9]*\).*/\1/p' | head -1; }
if [ "${1:-}" = "--list" ]; then
  while read -r p vc _ _; do echo "$p repo=v$vc phone=$(installed_vc "$p" | sed 's/^$/-/')"; done < "$TMP/latest"; exit 0
fi
WANT=("$@"); rc=0
while read -r p vc apk hash; do
  cur=$(installed_vc "$p"); cur=${cur:-0}
  if [ ${#WANT[@]} -gt 0 ]; then printf '%s\n' "${WANT[@]}" | grep -qx "$p" || continue
  else [ "$cur" -gt 0 ] || continue; fi
  if [ "$cur" -ge "$vc" ]; then echo "= $p v$cur up to date"; continue; fi
  curl -fsSL "$REPO/$apk" -o "$TMP/$apk"
  got=$(shasum -a 256 "$TMP/$apk" | cut -d' ' -f1)
  [ "$got" = "$hash" ] || { echo "! $p sha256 mismatch, skipped"; rc=1; continue; }
  cert=$("$BT/apksigner" verify --print-certs "$TMP/$apk" 2>/dev/null | sed -n 's/^Signer #1 certificate SHA-256 digest: //p')
  name=$("$BT/aapt2" dump packagename "$TMP/$apk" 2>/dev/null || true)
  echo " $PINNED " | grep -q " $cert " || { echo "! $p cert '$cert' not pinned, skipped"; rc=1; continue; }
  [ -z "$name" ] || [ "$name" = "$p" ] || { echo "! $p APK is '$name', skipped"; rc=1; continue; }
  if out=$("${ADB[@]}" install -r "$TMP/$apk" 2>&1); then echo "+ $p v$cur -> v$vc OK"
  else echo "! $p install failed: $(echo "$out" | tail -1)"; rc=1; fi
done < "$TMP/latest"
exit $rc
