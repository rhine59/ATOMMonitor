# ATOM Monitor iOS

Native SwiftUI iPhone client for browsing PilotAware ATOM ground-station health.

## Planned technologies

- Swift / SwiftUI
- MapKit
- URLSession / Codable
- Swift Charts for later historical telemetry

## Primary navigation

The map is the home screen. It displays all known ATOM stations from the server's persistent registry. Users pan/zoom/search, select a station marker, inspect a summary, then navigate to full details.

## Health presentation

Initial states:

- Healthy
- Warning
- No recent heartbeat
- Unknown

The UI should use both colour and text/glyph cues. Missing telemetry is `Not reported`.

## Screens

1. Station map.
2. Search/results overlay.
3. Station summary card.
4. Station detail.
5. Historical health charts (later).
6. Settings/favourites (later).

## Scope

No aircraft map, aircraft tracking, traffic display or flight playback belongs in this application.

## Layout

Use adaptive SwiftUI layout, Dynamic Type and safe areas. Avoid designs tuned only to a large iPhone. Device location is optional and used only for convenience such as centring the map or finding nearby stations.
