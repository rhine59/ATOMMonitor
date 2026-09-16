# Map UI Specification

## Home screen

ATOM Monitor opens directly to the station map. The map is the application canvas and must fill the complete native iPhone display. Markers represent ground stations only.

## Full-screen and adaptive layout policy

The Map tab is not embedded in a NavigationStack. It owns its compact title/search overlay and MapKit extends edge-to-edge behind the status area and bottom tab bar. Other tabs retain NavigationStack where conventional navigation is appropriate.

Physical-device testing exposed a second, more fundamental cause of large black bands above and below the application: native modern-iPhone launch geometry must be declared. The XcodeGen project therefore generates the iOS launch screen (`INFOPLIST_KEY_UILaunchScreen_Generation: YES`) and declares the iPhone app full-screen. Without appropriate launch-screen metadata iOS can run an application using compatibility geometry, which cannot be corrected merely by applying SwiftUI `ignoresSafeArea` modifiers inside that smaller application viewport.

The map itself uses GeometryReader and explicitly takes the available width and height, then ignores all container safe-area edges. Overlay controls use the actual `geometry.safeAreaInsets` so the background map can fill the screen while title/search controls remain clear of the status area/Dynamic Island. Horizontal padding is adaptive rather than tied to a particular model.

No fixed iPhone pixel dimensions are used. The layout derives from the runtime geometry and is intended to support small, standard, Pro and Max-sized iPhones without letterboxing or unused black space.

## Map chrome

The map does not devote a separate panel to its title. `ATOM Stations` and the compact `Find` search field float over the map. The map continues underneath them and underneath system chrome. Standard MapKit controls remain available.

## Annotation state

- green — Healthy;
- amber — Warning;
- red — No recent heartbeat;
- grey — Unknown.

Markers must remain legible in light/dark appearance and not rely solely on colour.

## Selection flow

A single tap on an individual station opens the full station detail view directly in a draggable sheet. There is no intermediate summary card. Tapping a cluster zooms into that cluster.

## Search

Search supports full and partial station names through the compact `Find` overlay and does not consume a permanent map region.

## Clustering

Dense annotations cluster when zoomed out and separate as the user zooms in. Cluster circles currently show station count.

## Station detail layout

The direct detail sheet includes health and observation times, station identity/software versions, location/altitude, CPU/RAM/temperature, uptime/voltage, NTP and RF information. Missing source fields display `Not reported`.

## Physical-device verification

Full-screen behaviour must be verified on a physical iPhone as well as Simulator. Acceptance criteria are:

- no black/unused band above the map;
- no black/unused band below the map;
- MapKit background reaches every display edge;
- status bar/Dynamic Island appears over map content;
- bottom tab bar appears over map content;
- title and `Find` stay within usable safe-area geometry;
- changing iPhone screen size does not require source-code dimensions.

After changing launch-screen/full-screen Info.plist generation, regenerate the Xcode project and perform a clean reinstall on the physical iPhone so the new application metadata is definitely installed.

## Device location

Location is optional. Core map browsing works without location permission.
