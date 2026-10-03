# ATOM Monitor — Android Setup, Build and Installation Guide

This directory contains the native Android counterpart to the SwiftUI iPhone application. It shares the existing Synology REST service and the same strict scope boundary: **ATOM ground-station operational health only; no aircraft tracking, identities, positions or movement history.**

This document is the authoritative setup/build/install guide for the Android client.

## 1. Current Android project

Technology and project settings:

- Kotlin/Compose compiler plugin 2.3.20
- Jetpack Compose / Material 3
- Android Gradle Plugin 9.4.0
- Gradle 9.6.0 wrapper
- Java 17 verified build runtime
- compile SDK 37
- target SDK 37
- minimum Android API 26 (Android 8.0)
- application ID / namespace `uk.co.rhine59.atommonitor`
- version code 1
- version name 1.0
- Android `HttpURLConnection` + `org.json` for the existing JSON REST API
- osmdroid 6.1.20 / OpenStreetMap for mapping; no Google Maps API key is required
- Android SharedPreferences for server, refresh interval, Home station and favourites
- local JSON station snapshot cache

Normal service:

```text
https://granvillehouse.synology.me:8445/
```

The Android app uses the same `/api/v1/stations` data as iOS. The manifest includes `INTERNET`. Cleartext is currently permitted only so the LAN diagnostic server can be entered during development.

## 2. What you need on the Mac

Install Android Studio from the official Android developer distribution. During first launch, allow Android Studio's Setup Wizard to install the standard Android SDK components.

For this project ensure the SDK Manager has:

- Android SDK Platform 37;
- Android SDK Build-Tools compatible with API 37;
- Android SDK Platform-Tools (`adb`);
- Android SDK Command-line Tools (latest);
- Android Emulator if you want to use a virtual phone.

The verified command-line build uses Java 17. In Android Studio check **Settings/Preferences → Build, Execution, Deployment → Build Tools → Gradle → Gradle JDK** and select an embedded JDK/JBR compatible with Java 17, or another Java 17 installation known to work with the project.

You do not need Xcode, CocoaPods or an Apple developer account to build the Android app.

## 3. Pull the source

The Android client is in the same repository as iOS and the Synology server.

```bash
cd ~/Documents/Xcode/ATOMMonitor
git pull
git status
```

The Android project root is:

```text
~/Documents/Xcode/ATOMMonitor/android
```

Do not create a separate Android project in Android Studio. Open this existing directory.

## 4. Open the project in Android Studio

Start Android Studio and choose **Open**. Select the `android` directory itself, not `app` and not the top-level `ATOMMonitor` directory:

```text
~/Documents/Xcode/ATOMMonitor/android
```

Android Studio should recognise `settings.gradle.kts` and import the Gradle project. The root project is named `ATOMMonitorAndroid` and includes the `:app` module.

Allow **Gradle project sync** to finish before attempting to create or run a device. During sync the toolbar may initially show **Add Configuration** and a disabled Run button. After a successful sync the toolbar should show the **app** run configuration and an active Run button. Do not accept suggested Gradle/plugin upgrades merely because Android Studio offers them; this repository already has a verified toolchain.

If Android Studio asks which JDK to use, select a Java 17-compatible JDK/JBR.

The Android Studio Assistant panel is not required to build or test ATOM Monitor. An **Error loading assistant panel** message can be ignored if Gradle sync and the Android project itself are otherwise healthy.

Android Studio may also offer to add IDE project settings to Git. Do not automatically add `.idea` or other local IDE state; these are not part of the application build checkpoint unless deliberately reviewed and approved.

## 5. Gradle wrapper

The Gradle wrapper has now been generated and verified locally. The project uses **Gradle 9.6.0**, and the wrapper scripts, properties and wrapper JAR are intended to be committed with the project so a fresh checkout can use the same Gradle version.

Verify the wrapper from `android/` with:

```bash
ls -l gradlew gradlew.bat gradle/wrapper/
./gradlew --version
```

The verified output should identify Gradle 9.6.0 and Java 17. Do not regenerate the wrapper simply because Android Studio has another Gradle version installed; change it only as a deliberate toolchain upgrade.

## 6. First Gradle sync problems

If Android Studio reports that SDK 37 is missing:

1. Open **Tools → SDK Manager**.
2. Under SDK Platforms select/install **API 37**.
3. Under SDK Tools ensure Platform-Tools and compatible Build-Tools are installed.
4. Apply the changes.
5. Select **File → Sync Project with Gradle Files**.

If the error concerns the Java/Gradle runtime, select a Java 17-compatible JDK in Gradle settings and sync again.

If dependency resolution fails, confirm the Mac has Internet access. The project repositories are Google Maven, Maven Central and Gradle Plugin Portal.

Do not start changing dependency versions simply because the first sync is slow. Capture the exact Gradle error first.

## 7. Build a debug APK in Android Studio

After a successful Gradle sync, select the `app` run configuration.

For a normal compile/build choose:

```text
Build → Make Project
```

To explicitly create an installable debug APK use:

```text
Build → Build App Bundles or APKs → Build APKs
```

The debug APK is normally produced under:

```text
android/app/build/outputs/apk/debug/app-debug.apk
```

A debug APK is automatically signed with the Android debug key and is suitable for development/emulator/your own physical-device testing. It is not a Play Store release package.

## 8. Command-line build and confirmed checkpoint

The preferred repeatable build is:

```bash
cd ~/Documents/Xcode/ATOMMonitor/android
./gradlew clean
./gradlew assembleDebug
```

The first confirmed Android debug APK build passed on **17 September 2026** using:

- Android SDK compile/target API 37
- Android Gradle Plugin 9.4.0
- Gradle 9.6.0
- Java 17
- Kotlin/Compose compiler plugin 2.3.20

The successful build produced:

```text
app/build/outputs/apk/debug/app-debug.apk
```

The APK was approximately 16 MB. The build emitted a non-fatal native-library stripping warning for `libandroidx.graphics.path.so`; packaging nevertheless completed with `BUILD SUCCESSFUL`.

Build evidence is retained in:

```text
artifacts/ATOMMonitor-Android-build.log
artifacts/ATOMMonitor-Android-kotlin-build.log
```

This checkpoint proves compilation and APK packaging. **Android runtime/regression testing is still pending and must not be recorded as Tested until the app has been exercised on an emulator or physical Android device.**

For more diagnostic output:

```bash
./gradlew assembleDebug --stacktrace
```

or:

```bash
./gradlew assembleDebug --info
```

Do not commit the generated `build/` directories or debug APK to Git. Commit source, wrapper/toolchain files, documentation and relevant build/test evidence instead.

## 9. Create the standard Android emulator

The standard ATOM Monitor Android regression emulator established on 17 September 2026 is a **Pixel 10a** using the **API 37.2 “CinnamonBun”, Android 17.0, Google Play, ARM64-v8a, 16 KB page-size** system image. On the Apple-silicon development Mac this is the appropriate ARM image. The Pixel 10a profile is 1080 × 2424 at 420 dpi.

Use the following procedure after the project has completed Gradle sync:

1. Look at the device selector in the Android Studio toolbar. On a new installation it may say **No Devices**. Its dropdown can show physical-device options such as **Pair Devices Using Wi-Fi** and **Troubleshoot Device Connections**; those options do not create an emulator.
2. Open **Tools → Device Manager** from the Android Studio/macOS menu bar. If the Device Manager has no entries, click **Add a new device…** near the bottom or the **+** button at the top.
3. Choose **Create Virtual Device** if Android Studio presents a choice of device types.
4. Under the **Phone** hardware profiles select **Pixel 10a**. Do not select the experimental resizable profile for the standard regression device.
5. Click **Next**.
6. In **Configure virtual device**, leave the name as `Pixel 10a` unless there is a reason to distinguish multiple test images.
7. Select the API 37 system image. The verified configuration is:

```text
API: API 37.2 "CinnamonBun", Android 17.0
Services: Google Play Store
System image: 16 KB Page Size Google Play ARM 64 v8a System Image
ABI: arm64-v8a
```

8. If the image is not already installed, Android Studio will download it. At the initial setup this download was approximately 2.2 GB.
9. Click **Finish** and allow Android Studio to complete the image download and virtual-device creation.
10. When creation completes, `Pixel 10a` should appear both in Device Manager and in the toolbar device selector.

### Boot the emulator before installing ATOM Monitor

For the first runtime test, boot Android separately before asking Android Studio to install the app. This distinguishes emulator/platform startup problems from ATOM Monitor application problems.

1. Do **not** initially press the main green Run triangle beside the `app` configuration.
2. Open **Tools → Device Manager**.
3. Locate **Pixel 10a**.
4. Click its launch/play control.
5. Wait for the emulator to reach the normal Android lock/home screen. The first boot may take a minute or two.
6. Once Android itself is fully booted, return to Android Studio, ensure **Pixel 10a** is selected as the target device and **app** is selected as the run configuration.
7. Press the main green **Run** triangle to build/install/launch ATOM Monitor.

The emulator needs Internet connectivity because the normal ATOM service is the public HTTPS endpoint.

If the toolbar continues to show **No Devices** after the AVD has been created, return to Device Manager and confirm the Pixel 10a exists and can boot independently before troubleshooting the application.

## 10. Install on a physical Android phone from Android Studio

On the Android phone:

1. Open **Settings → About phone**.
2. Find **Build number** and tap it seven times until Developer options are enabled. The exact Settings path varies slightly by manufacturer.
3. Return to Settings and open **Developer options**.
4. Enable **USB debugging**.
5. Connect the phone to the Mac with a data-capable USB cable.
6. Unlock the phone.
7. Accept the phone's **Allow USB debugging?** RSA fingerprint prompt.

On the Mac, confirm Android Debug Bridge sees it:

```bash
adb devices
```

You want a line ending in `device`, not `unauthorized`.

Example shape:

```text
List of devices attached
XXXXXXXXXXXX    device
```

If `adb` is not found in Terminal, either use Android Studio's Terminal/environment or add the Android SDK `platform-tools` directory to your shell PATH. The SDK location is shown in Android Studio under **Settings/Preferences → Languages & Frameworks → Android SDK**.

With the phone visible, select it in Android Studio's device selector and press **Run**. Android Studio will install the debug build and launch it.

No device-location permission should be requested by ATOM Monitor because Home means an ATOM ground station, not the phone's GPS location.

## 11. Install an APK manually with adb

After `assembleDebug`:

```bash
cd ~/Documents/Xcode/ATOMMonitor/android
adb devices
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

`-r` replaces an existing development installation while retaining its app data where Android permits.

For a completely clean installation:

```bash
adb uninstall uk.co.rhine59.atommonitor
adb install app/build/outputs/apk/debug/app-debug.apk
```

A clean uninstall removes the app's local preferences/cache/favourites, so use it only when that is intended.

The application package is:

```text
uk.co.rhine59.atommonitor
```

Launch it from the phone's normal app launcher after installation.

## 12. Wireless debugging

Modern Android versions can also use wireless debugging. Enable **Wireless debugging** under Developer options and pair the phone with Android Studio's **Pair Devices Using Wi-Fi** function. USB is preferable for the first build because it removes Wi-Fi pairing as another possible source of failure.

## 13. Server configuration

The intended normal Android server is:

```text
https://granvillehouse.synology.me:8445/
```

The Synology Docker API remains internally available on port 8088. The LAN diagnostic address currently used during development is:

```text
http://192.168.1.99:8088/
```

Do not Internet-forward port 8088. The public path is HTTPS 8445 through DSM Reverse Proxy.

The Android manifest currently permits cleartext HTTP solely so the LAN diagnostic URL can be entered during development. Normal remote use should remain HTTPS.

## 14. First-run functional test

After installation, perform this sequence:

1. Launch ATOM Monitor and allow the initial station fetch to complete.
2. Confirm stations load from the public service.
3. Open **Map** and confirm only ATOM ground stations appear.
4. Use **Find** to search for part of a station name.
5. Select a station and inspect the full detail.
6. Confirm the Station Detail status icon represents the effective station health and that its explanation is understandable.
7. Confirm back-level status is presented correctly where applicable.
8. Confirm **Record date & time** shows an absolute local timestamp derived from `lastSeen`.
9. Confirm Last heartbeat, Last seen, Last position and Last technical status are relative-age displays.
10. Confirm missing optional values say **Not reported** rather than zero and that intentionally omitted/unused telemetry fields do not reappear.
11. From Station Detail, verify the Google Maps action opens the exact station latitude/longitude using satellite imagery and a location pin.
12. Open **Stations** and verify station navigation and shared filtering behaviour.
13. Add a station to **Favourites**, leave/relaunch the app and confirm the preference persists.
14. Set the **Home station** in Settings and confirm the preference persists.
15. Change the refresh interval; valid range is 1–10 minutes and default is 5 minutes.
16. Confirm the server is `https://granvillehouse.synology.me:8445/`.
17. Disable network access and refresh. Existing cached stations should remain visible and the app should indicate **No Network**.
18. Restore connectivity and refresh; current server data should replace the cached snapshot.
19. Generate a station report and verify its content, bar graphs and native Android sharing path.
20. Open **Help** and verify the guide is local to the application and consistent with current behaviour.
21. Check that there is no aircraft movement, aircraft identity, aircraft position or aircraft-track functionality anywhere.

## 15. Test the real public path

An emulator on the Mac proves general Internet access but does not provide the same test as a phone away from the home LAN.

For the physical Android test, disconnect the phone from Wi-Fi and use mobile data. Launch/refresh ATOM Monitor using:

```text
https://granvillehouse.synology.me:8445/
```

That tests the complete path:

```text
Android phone
  -> mobile Internet
  -> public DNS
  -> TLS :8445
  -> router
  -> DSM Reverse Proxy
  -> localhost:8088
  -> ATOM Monitor Docker API
  -> persistent station registry
```

## 16. Useful adb diagnostics

List devices:

```bash
adb devices -l
```

View Android logs while reproducing a fault:

```bash
adb logcat
```

Filter approximately for the application/package:

```bash
adb logcat | grep -i atommonitor
```

Clear old logcat before reproducing a fault:

```bash
adb logcat -c
adb logcat
```

Check the package is installed:

```bash
adb shell pm list packages | grep uk.co.rhine59.atommonitor
```

Remove the debug app completely:

```bash
adb uninstall uk.co.rhine59.atommonitor
```

If Android Studio says the device is unauthorized, unlock the phone, revoke/re-enable USB debugging authorization if necessary and accept the RSA prompt again.

## 17. APK versus release/AAB

For development use `app-debug.apk`.

For eventual public distribution through Google Play, the project will need a release signing configuration and an Android App Bundle (`.aab`). Do not commit a release keystore or its passwords to Git. Release signing should be configured separately when the application reaches distribution readiness.

A release build is therefore intentionally **not** part of the present first-install procedure.

## 18. Map implementation note

The iPhone application uses Apple MapKit with Standard, Satellite + Labels and Satellite modes. The current Android implementation uses OpenStreetMap/osmdroid and therefore does not yet reproduce those three Apple-specific base-map choices. Station mapping, searching and station selection are present; Android-equivalent layer choices remain a follow-up parity item.

OpenStreetMap tiles require network access and must be used in accordance with the tile provider's usage requirements. For normal development/testing the current osmdroid implementation is sufficient; a production distribution review should confirm the final tile-provider arrangement.

## 19. Current known parity/hardening work

The successful APK build does not close the remaining Android parity work. Current known items are:

- map clustering and mixed-colour cluster presentation;
- configurable map-icon colours;
- Home-relative filtered-map focus;
- Android-equivalent selectable map layers/Home-map presentation where needed for iPhone-equivalent behaviour;
- broader station-list/navigation polish;
- explicit server Test Connection using `/health` rather than relying on a station refresh;
- automatic-refresh lifecycle/interval hardening;
- server-specific cache ownership;
- Android unit/UI tests and a repeatable emulator regression workflow;
- adaptive phone/tablet layout testing while retaining phone-first behaviour;
- approved ATOM application icon resources.

These items must remain synchronized with `docs/FEATURE-STATUS.md`. A successful build is not evidence that an untested runtime feature is complete.

## 20. What to send when a build or runtime test fails

For a build failure, capture the exact failure before changing dependency or Gradle versions. Run:

```bash
cd ~/Documents/Xcode/ATOMMonitor/android
./gradlew assembleDebug --stacktrace
```

Retain the error beginning at `FAILURE: Build failed with an exception` together with the first relevant `Caused by:` section.

For an app that builds but crashes or fails to load stations, reproduce it with:

```bash
adb logcat -c
adb logcat
```

and retain the relevant ATOM Monitor exception/network lines.

## 21. Source-control and parity workflow

Android source is maintained alongside iOS and the Synology server in `rhine59/ATOMMonitor`.

Before work:

```bash
cd ~/Documents/Xcode/ATOMMonitor
git pull
git status
```

For every user-facing implementation change, update the corresponding entry in `docs/FEATURE-STATUS.md` in the same development cycle. iPhone and Android functional behaviour should remain synchronized unless a platform-specific difference is explicitly documented.

After a verified Android change, commit the implementation, affected documentation and relevant build/test evidence. Do not commit generated `build/` directories, local Android Studio state, signing keys, secrets, runtime caches or the generated debug APK.

Build and runtime status are independent: record **Build passed — runtime test pending** after a successful compile/package checkpoint, and only advance to **Tested** after the relevant emulator/physical-device regression checks have actually passed.


## 22. Feedback, About and distribution checkpoint — 18 September 2026

Android source now places **Feedback** and **About** at the same main-navigation level as Settings and Help. About displays Version, Build and Android platform information separately, credits Richard Hine, links to the official PilotAware ATOM page, carries the ATOM Monitor copyright/trademark/non-affiliation notice, and exposes distribution/open-source notices including AndroidX/Jetpack Compose, osmdroid and OpenStreetMap attribution.

Feedback accepts a 1–5 rating and comments and posts them to the server-side relay so the destination email address is not shown in the application. Server SMTP delivery is intentionally deferred and therefore must not be marked Tested.

These latest Android changes are **build/runtime test pending**. The earlier Pixel 10a responsive-map checkpoint remains valid, including successful Home map centring; the searchable Home-station picker still has a scrolling defect and is the first Android parity defect to resume. Release signing/AAB work also remains outstanding.

## Restricted Admin checkpoint — 20 September 2026

The responsive app includes a locked Admin tab using a LAN-only one-time code and an Android Keystore-protected per-device credential. It displays the shared admin summary/container contract and supports explicitly confirmed 1–4 `atom-api` scaling only. Android build/runtime verification remains pending.


## Administrator QR pairing checkpoint — 3 October 2026

Android Admin uses the Google Play services code scanner and exchanges the same five-minute one-time code as iOS. The per-device credential is protected with Android Keystore; the shared server Admin tokens must never be entered into the app.

Source parity is implemented, but the current scanner/pairing build and device-runtime checkpoint remains pending. Run `./gradlew clean assembleDebug test`, install on a Google Play-enabled emulator and a physical phone, then verify QR scan, manual-code fallback, relaunch persistence, revocation, report drill-down and default-Off back-level highlighting. See `../docs/ADMIN-PAIRING-AND-RELEASE.md`.


## More and station icon legend

The primary Android bottom navigation is now Map, Stations, Favourites, Report and More. More contains Admin, Settings, Legend, Help, Feedback and About. Legend displays the effective station icon colours; Back-level software appears only while its Settings toggle is enabled. Build/runtime verification remains pending.
