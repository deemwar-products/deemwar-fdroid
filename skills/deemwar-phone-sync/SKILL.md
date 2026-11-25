---
name: deemwar-phone-sync
description: Install and update Deemwar F-Droid apps onto an Android phone over adb, including work-profile / Intune-managed phones where normal sideloading is blocked (installs as the ADB shell user, or via Shizuku for on-device installs). Use for "sync apps to my phone", "install deemwar apps on the phone", "set up a phone", "reload Shizuku", "silent install blocked by work policy", "install past Intune / unknown sources restriction".
---

# deemwar-phone-sync

Push Deemwar's F-Droid apps (repo: `https://fdroid.deemwar.com/repo`) onto a phone. Works on normal phones AND on work-profile / Intune-managed phones that set `no_install_unknown_sources_globally` (which blocks every F-Droid client and Deemwar Admin). Scripts live in this repo's `scripts/`.

## Why it works on a restricted phone
A work-profile `DISALLOW_INSTALL_UNKNOWN_SOURCES(_GLOBALLY)` restriction gates the **UI consent** install path, NOT the **ADB shell user (uid 2000)** path. So `adb install` / `pm install` as shell succeeds where the normal installer shows "Blocked by work policy". Shizuku hands that same shell privilege to an on-device app (Deemwar Admin), so after a one-time adb bootstrap the phone installs silently by itself. This does NOT defeat a Device-Owner `DISALLOW_INSTALL_APPS` (total block) or a phone with USB/wireless debugging disabled by policy.

## One-time setup (and post-reboot reload) — from a computer over adb
Connect the phone (USB, or wireless debugging already paired), then:
```
ADB_SERIAL=<serial> bash scripts/setup-phone.sh          # USB
bash scripts/setup-phone.sh 192.168.1.50:41234           # wireless host:port (already paired)
```
It installs Shizuku if missing, installs/updates every repo app (cert-pinned + sha256-checked), and (re)starts the Shizuku service. **Idempotent** — re-run after any reboot to restart Shizuku and re-sync. Then on the phone: Deemwar Admin > "Enable silent install (Shizuku)" > Allow > "Install / update ALL apps".

## Just sync apps (no Shizuku)
```
ADB_SERIAL=<serial> bash scripts/phone-sync.sh --list     # repo vs phone versions
ADB_SERIAL=<serial> bash scripts/phone-sync.sh            # update everything installed
ADB_SERIAL=<serial> bash scripts/phone-sync.sh com.deemwar.sample.hello   # install/update specific
```

## Start Shizuku by hand
```
adb shell "exec \$(pm path moe.shizuku.privileged.api | sed 's/package://;s/base.apk//')lib/arm64/libshizuku.so"
```
It is an ELF binary — **execute** it, do not `sh` it. Confirm with `adb shell 'ps -A | grep shizuku_server'`.

## Wireless pairing (when not on USB)
Use **"Pair device with pairing code"** (NOT the QR — the QR is for Android Studio to scan). Split-screen Termux+Settings so the pair dialog stays open, and use the phone's real Wi-Fi IP, not 127.0.0.1:
```
adb pair <ip>:<PAIRPORT>      # enter the 6-digit code
adb connect <ip>:<CONNPORT>   # the port from the main Wireless-debugging screen
```

## Reboot reality (no root)
Shizuku's service stops on reboot and cannot auto-start without root. Already-installed apps persist; only new installs/updates need Shizuku restarted (re-run `setup-phone.sh`). Truly reboot-proof, zero-touch silent install needs **Device Owner** (reset phone, no work profile) or root. See the `fdroid` skill for repo publishing and the full device-admin / provisioning detail.

## Normal (non-restricted) phone
No scripts needed — add `https://fdroid.deemwar.com/repo` in any F-Droid client; it installs and auto-updates. Deemwar Admin is optional (adds cert-pinning + the Shizuku silent-install path).
