# ATOM Monitor — Android Setup, Build and Installation Guide

This directory contains the native Android counterpart to the SwiftUI iPhone application. It shares the existing Synology REST service and the same strict scope boundary: **ATOM ground-station operational health only; no aircraft tracking, identities, positions or movement history.**

This document is the authoritative setup/build/install guide for the Android client.

## 1. Current Android project

Technology and project settings:

- Kotlin 2.1.0
- Jetpack Compose / Material 3
- Android Gradle Plugin 8.7.3
- compile SDK 35
- target SDK 35
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

- Android SDK Platform 35;
- Android SDK Build-Tools appropriate for API 35;
- Android SDK Platform-Tools (`adb`);
- Android SDK Command-line Tools (latest);
- Android Emulator if you want to use a virtual phone.

Use Android Studio's bundled JDK unless Gradle reports a specific incompatibility. AGP 8.7.x requires Java 17; Android Studio's current embedded runtime is normally the simplest choice. In Android Studio check **Settings/Preferences → Build, Execution, Deployment → Build Tools → Gradle → Gradle JDK** and select the embedded JDK/JBR compatible with Java 17 or later.

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

Start Android Studio and choose **Open**. Select:

```text
~/Documents/Xcode/ATOMMonitor/android
```

Android Studio should recognise `settings.gradle.kts` and import the Gradle project. The root project is named `ATOMMonitorAndroid` and includes the `:app` module.

Allow Gradle Sync to complete. The first sync can take several minutes because Android/Compose/osmdroid dependencies must be downloaded.

If Android Studio asks which JDK to use, select its embedded JDK/JBR rather than an unrelated system Java installation.

## 5. Gradle wrapper status

At the initial Android checkpoint, a Gradle wrapper binary was not committed because the GitHub text connector cannot create the wrapper JAR. Therefore a fresh checkout may not initially contain `gradlew`, `gradlew.bat` and `gradle/wrapper/gradle-wrapper.jar`.

Android Studio can import/sync the Gradle project using its installed Gradle/JDK tooling. Once the project has synced successfully, generate a normal Gradle wrapper locally so command-line builds are reproducible.

From Android Studio's Terminal, inside `android/`, if the `gradle` command is available:

```bash
gradle wrapper
```

If it is not available as a shell command, use Android Studio/Gradle tooling for the first build and install a compatible Gradle locally before generating the wrapper. For AGP 8.7.3 use the Gradle version recommended by Android Studio's AGP compatibility check rather than guessing an older version.

After the wrapper exists, verify:

```bash
ls -l gradlew gradlew.bat gradle/wrapper/
./gradlew --version
```

The wrapper scripts, properties and wrapper JAR are normal project files and should then be committed to Git so future builds use exactly the same Gradle version.

## 6. First Gradle sync problems

If Android Studio reports that SDK 35 is missing:

1. Open **Tools → SDK Manager**.
2. Under SDK Platforms select **Android 15 / API 35**.
3. Under SDK Tools ensure Platform-Tools and Build-Tools are installed.
4. Apply the changes.
5. Select **File → Sync Project with Gradle Files**.

If the error concerns the Java/Gradle runtime, select Android Studio's embedded JDK in Gradle settings and sync again.

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

## 8. Command-line build

Once the Gradle wrapper has been generated, the preferred repeatable build is:

```bash
cd ~/Documents/Xcode/ATOMMonitor/android
./gradlew clean
./gradlew assembleDebug
```

Expected output ends with `BUILD SUCCESSFUL`.

The APK should then be:

```text
app/build/outputs/apk/debug/app-debug.apk
```

For more diagnostic output:

```bash
./gradlew assembleDebug --stacktrace
```

or:

```bash
./gradlew assembleDebug --info
```

Before committing build evidence, do not add the `build/` directories themselves to Git.

## 9. Create an Android emulator

In Android Studio open **Tools → Device Manager** and choose **Create Virtual Device**.

A Pixel phone profile is a sensible first test target. Select an Android system image compatible with API 35, download it if required, complete the virtual-device wizard and start the emulator.

When the emulator has fully booted, select it in Android Studio's device selector and press **Run** for the `app` configuration.

Android Studio will build, install and launch ATOM Monitor automatically.

The emulator needs Internet connectivity because the normal ATOM service is the public HTTPS endpoint.

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
6. Confirm **Record date & time** shows an absolute local timestamp derived from `lastSeen`.
7. Confirm Last heartbeat, Last seen, Last position and Last technical status are relative-age displays.
8. Confirm missing optional values say **Not reported** rather than zero.
9. Open **Stations** and verify station navigation.
10. Add a station to **Favourites**, leave/relaunch the app and confirm the preference persists.
11. Set the **Home station** in Settings and confirm the preference persists.
12. Change the refresh interval; valid range is 1–10 minutes and default is 5 minutes.
13. Confirm the server is `https://granvillehouse.synology.me:8445/`.
14. Disable network access and refresh. Existing cached stations should remain visible and the app should indicate **No Network**.
15. Restore connectivity and refresh; current server data should replace the cached snapshot.
16. Open **Help** and verify the guide is local to the application.
17. Check that there is no aircraft movement, aircraft identity, aircraft position or aircraft-track functionality anywhere.

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

The iPhone application uses Apple MapKit with Standard, Satellite + Labels and Satellite modes. The current Android implementation uses OpenStreetMap/osmdroid and therefore does not yet reproduce those three Apple-specific base-map choices. Station mapping, searching and station selection are present; Android-equivalent layer choices are a follow-up parity item.

OpenStreetMap tiles require network access and must be used in accordance with the tile provider's usage requirements. For normal development/testing the current osmdroid implementation is sufficient; a production distribution review should confirm the final tile-provider arrangement.

## 19. Current known parity/hardening work

- Add Android-equivalent selectable map layers and a visible Home-map control.
- Add marker clustering and health-coloured marker artwork equivalent to iOS.
- Improve station-list row navigation so the whole row is tappable.
- Add explicit server Test Connection using `/health` rather than relying on a station refresh.
- Make automatic refresh react immediately when its interval changes and remain foreground/lifecycle-aware.
- Make cache ownership server-specific.
- Add Android unit/UI tests and a repeatable emulator regression workflow.
- Add adaptive phone/tablet layout testing while retaining phone-first behaviour.
- Add the approved ATOM application icon resources.
- Add the Gradle wrapper to Git after it has been generated locally and verified.

## 20. What to send when a build fails

Do not repeatedly alter Gradle files after a failed first build. Capture the failure so it can be fixed deterministically.

From Android Studio, copy the first meaningful Gradle/compiler error and the lines immediately around it. Once the wrapper exists, also run:

```bash
cd ~/Documents/Xcode/ATOMMonitor/android
./gradlew assembleDebug --stacktrace
```

Send the error beginning at `FAILURE: Build failed with an exception` together with the first `Caused by:` section.

For an app that builds but crashes or fails to load stations, reproduce it with:

```bash
adb logcat -c
adb logcat
```

and retain the relevant ATOM Monitor exception/network lines.

## 21. Source-control workflow

Android source is maintained alongside iOS and the Synology server in `rhine59/ATOMMonitor`.

Before work:

```bash
cd ~/Documents/Xcode/ATOMMonitor
git pull
git status
```

After a verified Android change, update Android/shared documentation and commit the implementation plus relevant build/test evidence. Do not commit generated `build/` directories, local Android Studio state, signing keys, secrets or runtime caches.

The Android app should evolve alongside iOS: shared behaviour, data semantics and user documentation should remain synchronized across platforms.
