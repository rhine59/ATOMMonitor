# Administrator Pairing, Rebuild and Release Process

This is the authoritative process for rebuilding, deploying and testing administrator access on the server, iOS and Android.

## Security model

- A phone never receives or stores `ATOM_ADMIN_TOKEN` or `ATOM_ADMIN_CONTROL_TOKEN`.
- `ATOM_ADMIN_TOKEN` is a server-side migration credential for existing installations.
- `ATOM_ADMIN_CONTROL_TOKEN` is an internal service-to-service credential.
- Pairing is allowed only from networks in `ATOM_ADMIN_PAIRING_NETWORKS`.
- `GET /api/v1/admin/pair` creates a five-minute, one-time code and QR payload.
- `POST /api/v1/admin/pair/exchange` exchanges that code for a random per-device credential.
- Only the credential hash is retained by the server. iOS stores the credential in Keychain; Android stores it encrypted with Android Keystore.
- `DELETE /api/v1/admin/device` revokes the calling device.
- Device registrations and unexpired pairing challenges persist in the `atommonitor-admin-devices` Docker volume. This prevents a load-balanced exchange request from losing the challenge and fixes the former HTTP 401 pairing failure.

Never paste administrator secrets into an app, screenshot, issue, log, report or source file.

## Synology clean rebuild

Before pulling, protect any local Xcode project change:

```bash
cd /volume1/docker/ATOMMonitor
git status --short
git diff -- ios/ATOMMonitor.xcodeproj/project.pbxproj
```

If the change is intentional, commit it. If it is only a local generated-project change, stash that file:

```bash
git stash push -m "local Xcode project before server update" -- ios/ATOMMonitor.xcodeproj/project.pbxproj
git pull --ff-only
```

Do not use `git reset --hard`. After pulling:

```bash
cd server
grep -E '^(ATOM_ADMIN_TOKEN|ATOM_ADMIN_CONTROL_TOKEN|ATOM_ADMIN_PAIRING_NETWORKS)=' .env
sudo docker compose config --quiet
cd ..
sh scripts/build-admin.sh
sh scripts/admin-pairing-acceptance.sh
```

The recommended pairing networks are the actual trusted LAN ranges, for example:

```dotenv
ATOM_ADMIN_PAIRING_NETWORKS=192.168.0.0/16,10.0.0.0/8,127.0.0.0/8
```

Use a narrower subnet where practical. Do not add a public Internet range.

Open the pairing page from a device on the trusted LAN:

```text
https://granvillehouse.synology.me:8445/api/v1/admin/pair
```

A direct browser visit is a GET. Posting to that URL is not the pairing exchange; the app posts the displayed code to `/api/v1/admin/pair/exchange`.

## iOS rebuild and test

Current release checkpoint: version 1.0, build 4.

```bash
cd ios
xcodegen generate
open ATOMMonitor.xcodeproj
```

In Xcode:

1. Confirm bundle identifier `uk.co.rhine59.ATOMMonitor` and automatic signing team `VNQTGCW476`.
2. Build and run on a physical iPhone; the camera scanner cannot be fully accepted using only a Simulator.
3. Open Admin, choose **Scan pairing QR code**, and scan the current Admin pairing page.
4. Confirm the summary loads after Face ID or device passcode.
5. Lock Admin, unlock again, and confirm no new pairing is required.
6. Remove/revoke the device and confirm the old credential can no longer load Admin.
7. Pair again and confirm manual short-code entry still works.
8. Test Report count links open the correctly filtered Stations list.
9. Confirm **Highlight back-level software** defaults Off and persists when changed.
10. Archive, validate and upload only after these checks pass.

For an existing install, test both upgrade and clean-install paths. Increment `CURRENT_PROJECT_VERSION` for every TestFlight upload.

## Android rebuild and test

Current source checkpoint: version code 4.

```bash
cd android
./gradlew clean assembleDebug test
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

On a Google Play-enabled emulator and then a physical Android phone:

1. Open Admin and launch **Scan pairing QR code**.
2. Scan the current pairing page, then verify authenticated summary and scaling controls.
3. Lock/relaunch and confirm the Keystore-protected device credential remains usable.
4. Remove/revoke the device and verify the old credential is rejected.
5. Verify manual short-code fallback.
6. Repeat the Report drill-down and default-Off back-level highlighting checks used on iOS.
7. Repeat cached-data, no-network and public HTTPS tests.

Compilation alone is not runtime acceptance. Record Android as Tested only after the scanner and pairing flow pass on a device.

## Server acceptance

Run:

```bash
sh scripts/admin-pairing-acceptance.sh
sh scripts/admin-scaling-acceptance.sh
sh scripts/all-phases-acceptance.sh
```

The pairing test creates and revokes its own temporary device. It does not display the code or credential.

Also verify from a non-trusted network that the pairing page is rejected while normal read-only station endpoints remain available.

## Recovery

If pairing returns HTTP 401:

1. Confirm the code is less than five minutes old and has not already been exchanged.
2. Confirm the browser and exchange request are reaching the same current deployment.
3. Confirm `atommonitor-admin-devices` is mounted at `/data` in the admin monitor.
4. Check logs: `sudo docker compose logs --tail=200 atom-admin-monitor atom-lb`.
5. Create a fresh code after any rebuild.

Deleting the admin data volume revokes every paired device and removes pending codes. Treat that as a deliberate recovery operation, not a routine rebuild step.
