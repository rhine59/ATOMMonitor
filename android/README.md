# ATOM Monitor — Android

This directory contains the native Android counterpart to the SwiftUI iPhone application. It deliberately shares the existing Synology REST service and the same scope boundary: **ATOM ground-station operational health only; no aircraft tracking, identities, positions or movement history.**

## Technology

- Kotlin
- Jetpack Compose / Material 3
- Android API 26 minimum, API 35 target
- Android `HttpURLConnection` + `org.json` for the existing JSON REST API
- osmdroid/OpenStreetMap for the map, avoiding a Google Maps API-key requirement
- Android SharedPreferences for server, refresh interval, Home station and favourites
- local JSON station snapshot cache

## Functional parity target

The initial Android implementation provides the same main navigation model as iPhone: **Map, Stations, Favourites, Settings and Help**. It uses the same `/api/v1/stations` payload and health terminology.

Implemented:

- full-screen station map with station markers;
- station-name Find/search;
- station list and favourites;
- complete station detail sections for Health, Station, Location, System, Time and Radio;
- absolute **Record date & time** from `lastSeen` plus relative heartbeat/position/technical ages;
- configurable server URL;
- default public server `https://granvillehouse.synology.me:8445/`;
- configurable 1–10 minute foreground refresh, default 5 minutes;
- manual refresh;
- latest station snapshot cache retained across connection failures;
- Home station preference;
- local/offline Help content;
- no device-location permission requirement;
- no aircraft data UI or storage.

## Build

Open the `android` directory in Android Studio. Allow Gradle to sync, then run the `app` configuration on an Android emulator or physical phone.

The project currently declares Android Gradle Plugin 8.7.3 and Kotlin 2.1.0. A local Gradle wrapper has not been generated in Git because wrapper binaries cannot be created through the repository text connector. Android Studio can sync the project with an installed compatible Gradle/JDK toolchain; once a wrapper is generated locally, commit the normal text wrapper scripts/properties and the wrapper JAR through ordinary Git.

## Network

Normal service:

```text
https://granvillehouse.synology.me:8445/
```

The manifest includes Internet permission. Cleartext traffic is currently permitted only so the existing LAN diagnostic endpoint can still be entered in Settings during development. Production normal operation should use HTTPS.

## Map implementation note

The iPhone application uses Apple MapKit with Standard, Satellite + Labels and Satellite modes. The initial Android implementation uses OpenStreetMap/osmdroid and therefore does not yet reproduce those three Apple-specific base-map choices. Station mapping, searching and station selection are present; equivalent Android layer choices are a follow-up parity item.

## Test checklist

1. Launch and confirm stations load from the public HTTPS service.
2. Confirm Map contains only ATOM ground stations and Find filters by station name.
3. Open a station and verify Record date & time plus relative observation ages.
4. Check technical fields and `Not reported` handling.
5. Add/remove a favourite and relaunch to confirm persistence.
6. Change refresh interval and relaunch to confirm persistence.
7. Select a Home station and confirm the preference persists.
8. Disable network and refresh; previous cached stations must remain visible and `No Network` must be shown.
9. Restore network and confirm a successful refresh replaces the cache.
10. Confirm no aircraft movement, aircraft identity, aircraft position or track data appears anywhere.

## Known parity/hardening work

- Add Android-equivalent selectable map layers and a visible Home-map control.
- Add marker clustering and health-coloured marker artwork equivalent to iOS.
- Improve station-list row navigation so the whole row is tappable.
- Add explicit server Test Connection result using `/health` rather than Save & Test relying on a station refresh.
- Make automatic refresh react immediately when its interval changes and remain foreground/lifecycle-aware.
- Make cache ownership server-specific.
- Add Android unit/UI tests and a repeatable emulator regression workflow.
- Add adaptive phone/tablet layout testing while retaining phone-first behaviour.
- Add the ATOM application icon resources from the approved artwork.

The Android app should evolve alongside iOS: changes to shared behaviour, data semantics and user documentation should be reflected on both platforms.