#!/usr/bin/env bash
# Deemwar one-time phone setup over adb (USB or already-paired wireless).
# Installs Shizuku + every Deemwar repo app as the ADB shell user — which
# BYPASSES a work-profile no_install_unknown_sources_globally restriction —
# then starts Shizuku so Deemwar Admin can keep installing silently on-device.
# Re-run after a reboot (Shizuku stops on reboot without root).
#
# Usage:
#   scripts/setup-phone.sh                      # USB (set ADB_SERIAL if several)
#   scripts/setup-phone.sh 192.168.1.50:41234   # wireless: already-paired host:port
set -euo pipefail
REPO=https://fdroid.deemwar.com/repo
BT=$(ls -d /opt/homebrew/share/android-commandlinetools/build-tools/* 2>/dev/null | tail -1)
PINNED="d16030fd1dae9a090bb2ad4711f64d76bc8be780d624cf9f33d3e09b64c7fd28 c0d7354c6d1b535207a11b2fd81eda9fe637a9bd7905ee2306e73aea0dd5490c 6bd08994e88c568bb8c7502d7d477746d36bb4fad4f123eedc12c59bda742ab1"
TARGET="${1:-}"
if [ -n "$TARGET" ]; then adb connect "$TARGET" >/dev/null; ADB=(adb -s "$TARGET");
elif [ -n "${ADB_SERIAL:-}" ]; then ADB=(adb -s "$ADB_SERIAL"); else ADB=(adb); fi
[ "$("${ADB[@]}" get-state 2>/dev/null)" = device ] || { echo "no phone in 'device' state (adb devices)"; exit 1; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

if "${ADB[@]}" shell pm path moe.shizuku.privileged.api >/dev/null 2>&1; then
  echo "==> Shizuku already installed"
else
  echo "==> installing Shizuku (latest from GitHub)"
  SHIZ=$(curl -fsSL https://api.github.com/repos/RikkaApps/Shizuku/releases/latest | python3 -c "import json,sys;print([a['browser_download_url'] for a in json.load(sys.stdin)['assets'] if a['name'].endswith('.apk')][0])")
  curl -fsSL -o "$TMP/shizuku.apk" "$SHIZ"
  "${ADB[@]}" install -r "$TMP/shizuku.apk" >/dev/null && echo "   installed Shizuku"
fi

echo "==> Deemwar apps from the repo (cert-pinned + sha256-checked)"
curl -fsSL "$REPO/index-v1.json?t=$(date +%s)" -o "$TMP/index.json"
python3 -I -c 'import json,sys
d=json.load(open(sys.argv[1]))
for p,vs in sorted(d["packages"].items()):
    v=max(vs,key=lambda x:x["versionCode"])
    print(p, v["versionCode"], v["apkName"], (v.get("hash") or v.get("sha256")))' "$TMP/index.json" > "$TMP/apps"
while read -r pkg vc apk hash; do
  curl -fsSL "$REPO/$apk" -o "$TMP/$apk"
  got=$(shasum -a 256 "$TMP/$apk" | cut -d' ' -f1)
  [ "$got" = "$hash" ] || { echo "   ! $pkg sha256 mismatch, skipped"; continue; }
  if [ -n "$BT" ]; then
    cert=$("$BT/apksigner" verify --print-certs "$TMP/$apk" 2>/dev/null | sed -n 's/^Signer #1 certificate SHA-256 digest: //p')
    echo " $PINNED " | grep -q " $cert " || { echo "   ! $pkg cert not pinned, skipped"; continue; }
  fi
  if "${ADB[@]}" install -r "$TMP/$apk" >/dev/null 2>&1; then echo "   installed $pkg v$vc"
  else echo "   ! $pkg install failed"; fi
done < "$TMP/apps"

echo "==> starting Shizuku service"
"${ADB[@]}" shell "exec \$(pm path moe.shizuku.privileged.api | sed 's/package://;s/base.apk//')lib/arm64/libshizuku.so" || true
sleep 2
if "${ADB[@]}" shell 'ps -A' | grep -q shizuku_server; then echo "   Shizuku running"; else echo "   ! Shizuku did not start"; fi

cat <<'EOF'

DONE. On the phone:
  1. Open Deemwar Admin -> "Enable silent install (Shizuku)" -> Allow.
  2. "Install / update ALL apps" (or install per app) now runs silently.
After a REBOOT, Shizuku stops (Android limit without root) — re-run this script
(or just re-run the Shizuku start) to re-enable silent installs. Already-installed
apps keep working across reboots.
EOF
