#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IOS="$ROOT/ios"; OUT="$ROOT/artifacts"; mkdir -p "$OUT"
DEVICE="${DEVICE:-iPhone 16 Pro}"
SCHEME="ATOMMonitor"
RAW="$OUT/ATOMMonitor-Demo-raw.mp4"; FINAL="$OUT/ATOMMonitor-Demo.mp4"
cd "$IOS"
command -v xcodegen >/dev/null || { echo "Install XcodeGen first: brew install xcodegen"; exit 1; }
xcodegen generate
UDID=$(xcrun simctl list devices available | awk -F '[()]' -v d="$DEVICE" '$0 ~ d {print $2; exit}')
[ -n "$UDID" ] || { echo "Simulator '$DEVICE' not found. Set DEVICE to an installed iPhone simulator name."; exit 1; }
xcrun simctl boot "$UDID" 2>/dev/null || true
open -a Simulator
xcodebuild -project ATOMMonitor.xcodeproj -scheme "$SCHEME" -sdk iphonesimulator -destination "id=$UDID" -derivedDataPath "$OUT/DerivedData" build
APP=$(find "$OUT/DerivedData/Build/Products" -path '*iphonesimulator/ATOMMonitor.app' -print -quit)
xcrun simctl install "$UDID" "$APP"
xcrun simctl terminate "$UDID" uk.co.rhine59.ATOMMonitor 2>/dev/null || true
rm -f "$RAW" "$FINAL"
echo "Starting screen recording..."
xcrun simctl io "$UDID" recordVideo --codec=h264 "$RAW" >/dev/null 2>&1 & REC=$!
sleep 1
xcrun simctl launch "$UDID" uk.co.rhine59.ATOMMonitor --demo-mode
sleep 2
if [ -x "$ROOT/scripts/run-demo-ui.sh" ]; then "$ROOT/scripts/run-demo-ui.sh" "$UDID"; else echo "No UI driver available; recording 20-second deterministic demo launch."; sleep 20; fi
kill -INT "$REC" 2>/dev/null || true; wait "$REC" 2>/dev/null || true
if command -v ffmpeg >/dev/null; then
  ffmpeg -y -i "$RAW" -vf "drawbox=x=20:y=20:w=iw-40:h=74:color=black@0.55:t=fill,drawtext=text='ATOM Monitor automated demonstration':x=40:y=42:fontsize=28:fontcolor=white" -c:v libx264 -pix_fmt yuv420p -movflags +faststart "$FINAL"
  echo "Annotated MP4: $FINAL"
else
  cp "$RAW" "$FINAL"; echo "ffmpeg not installed; raw recording copied to $FINAL. Install with: brew install ffmpeg"
fi
