#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IOS="$ROOT/ios"; OUT="$ROOT/artifacts"; mkdir -p "$OUT"
SCHEME="ATOMMonitor"
RAW="$OUT/ATOMMonitor-Demo-raw.mp4"; FINAL="$OUT/ATOMMonitor-Demo.mp4"
cd "$IOS"
command -v xcodegen >/dev/null || { echo "Install XcodeGen first: brew install xcodegen"; exit 1; }
xcodegen generate

# DEVICE may be supplied explicitly. Otherwise prefer a modern Pro iPhone and
# fall back to the first available iPhone simulator. Match the device name
# exactly so duplicate devices across installed iOS runtimes are harmless.
if [ -n "${DEVICE:-}" ]; then
  DEVICE_NAME="$DEVICE"
else
  AVAILABLE=$(xcrun simctl list devices available)
  for candidate in "iPhone 17 Pro" "iPhone 17" "iPhone 16e" "iPhone Air" "iPhone 17 Pro Max"; do
    if printf '%s\n' "$AVAILABLE" | grep -Fq "    $candidate ("; then DEVICE_NAME="$candidate"; break; fi
  done
  if [ -z "${DEVICE_NAME:-}" ]; then
    DEVICE_NAME=$(printf '%s\n' "$AVAILABLE" | sed -n 's/^    \(iPhone[^()] *\) (.*$/\1/p' | head -1 | sed 's/[[:space:]]*$//')
  fi
fi

[ -n "${DEVICE_NAME:-}" ] || { echo "No available iPhone Simulator was found."; xcrun simctl list devices available; exit 1; }
UDID=$(xcrun simctl list devices available | sed -n "s/^    ${DEVICE_NAME} (\([0-9A-F-]*\)) .*$/\1/p" | head -1)
[ -n "$UDID" ] || { echo "Simulator '$DEVICE_NAME' not found. Available iPhones:"; xcrun simctl list devices available | grep 'iPhone' || true; exit 1; }
echo "Using Simulator: $DEVICE_NAME ($UDID)"

xcrun simctl boot "$UDID" 2>/dev/null || true
open -a Simulator
xcrun simctl bootstatus "$UDID" -b
xcodebuild -project ATOMMonitor.xcodeproj -scheme "$SCHEME" -sdk iphonesimulator -destination "id=$UDID" -derivedDataPath "$OUT/DerivedData" build
APP=$(find "$OUT/DerivedData/Build/Products" -path '*iphonesimulator/ATOMMonitor.app' -print -quit)
[ -n "$APP" ] || { echo "Built ATOMMonitor.app was not found."; exit 1; }
xcrun simctl install "$UDID" "$APP"
xcrun simctl terminate "$UDID" uk.co.rhine59.ATOMMonitor 2>/dev/null || true
rm -f "$RAW" "$FINAL"
echo "Starting screen recording..."
xcrun simctl io "$UDID" recordVideo --codec=h264 "$RAW" >/dev/null 2>&1 & REC=$!
trap 'kill -INT "$REC" 2>/dev/null || true' EXIT
sleep 1
xcrun simctl launch "$UDID" uk.co.rhine59.ATOMMonitor --demo-mode
sleep 2
if [ -x "$ROOT/scripts/run-demo-ui.sh" ]; then "$ROOT/scripts/run-demo-ui.sh" "$UDID"; else echo "No UI driver available; recording 20-second deterministic demo launch."; sleep 20; fi
kill -INT "$REC" 2>/dev/null || true; wait "$REC" 2>/dev/null || true
trap - EXIT
if command -v ffmpeg >/dev/null; then
  ffmpeg -y -i "$RAW" -vf "drawbox=x=20:y=20:w=iw-40:h=74:color=black@0.55:t=fill,drawtext=text='ATOM Monitor automated demonstration':x=40:y=42:fontsize=28:fontcolor=white" -c:v libx264 -pix_fmt yuv420p -movflags +faststart "$FINAL"
  echo "Annotated MP4: $FINAL"
else
  cp "$RAW" "$FINAL"; echo "ffmpeg not installed; raw recording copied to $FINAL. Install with: brew install ffmpeg"
fi
