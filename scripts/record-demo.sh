#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; IOS="$ROOT/ios"; OUT="$ROOT/artifacts"; mkdir -p "$OUT"
SCHEME="ATOMMonitor"; RAW="$OUT/ATOMMonitor-Demo-raw.mp4"; FINAL="$OUT/ATOMMonitor-Demo.mp4"; LOG="$OUT/ATOMMonitor-Demo-test.log"
cd "$IOS"; command -v xcodegen >/dev/null || { echo "Install XcodeGen first: brew install xcodegen"; exit 1; }; xcodegen generate
if [ -n "${DEVICE:-}" ]; then DEVICE_NAME="$DEVICE"; else AVAILABLE=$(xcrun simctl list devices available); for candidate in "iPhone 17 Pro" "iPhone 17" "iPhone 16e" "iPhone Air" "iPhone 17 Pro Max"; do if printf '%s\n' "$AVAILABLE" | grep -Fq "    $candidate ("; then DEVICE_NAME="$candidate"; break; fi; done; if [ -z "${DEVICE_NAME:-}" ]; then DEVICE_NAME=$(printf '%s\n' "$AVAILABLE" | sed -n 's/^    \(iPhone[^()] *\) (.*$/\1/p' | head -1 | sed 's/[[:space:]]*$//'); fi; fi
[ -n "${DEVICE_NAME:-}" ] || { echo "No available iPhone Simulator was found."; exit 1; }
UDID=$(xcrun simctl list devices available | sed -n "s/^    ${DEVICE_NAME} (\([0-9A-F-]*\)) .*$/\1/p" | head -1); [ -n "$UDID" ] || { echo "Simulator '$DEVICE_NAME' not found."; exit 1; }
echo "Using Simulator: $DEVICE_NAME ($UDID)"; xcrun simctl boot "$UDID" 2>/dev/null || true; open -a Simulator; xcrun simctl bootstatus "$UDID" -b
rm -f "$RAW" "$FINAL" "$LOG"
echo "Starting Simulator recording and XCUITest feature tour..."
xcrun simctl io "$UDID" recordVideo --codec=h264 "$RAW" >/dev/null 2>&1 & REC=$!; trap 'kill -INT "$REC" 2>/dev/null || true' EXIT; sleep 1
set +e
xcodebuild test -project ATOMMonitor.xcodeproj -scheme "$SCHEME" -destination "id=$UDID" -derivedDataPath "$OUT/DerivedData" -only-testing:ATOMMonitorUITests/ATOMMonitorDemoUITests/testRecordedFeatureTour 2>&1 | tee "$LOG"
TEST_STATUS=${PIPESTATUS[0]}
set -e
kill -INT "$REC" 2>/dev/null || true; wait "$REC" 2>/dev/null || true; trap - EXIT

# Homebrew FFmpeg builds can omit the optional drawtext/libfreetype filter.
# Never let presentation post-processing destroy an otherwise valid recording.
if command -v ffmpeg >/dev/null; then
  if ffmpeg -hide_banner -filters 2>/dev/null | grep -Eq '[[:space:]]drawtext[[:space:]]'; then
    echo "FFmpeg drawtext available; adding demo title overlay..."
    if ! ffmpeg -y -i "$RAW" -vf "drawbox=x=20:y=20:w=iw-40:h=74:color=black@0.55:t=fill,drawtext=text='ATOM Monitor - automated feature tour':x=40:y=42:fontsize=28:fontcolor=white" -c:v libx264 -pix_fmt yuv420p -movflags +faststart "$FINAL"; then
      echo "WARNING: annotated transcode failed; preserving usable unannotated MP4."
      cp "$RAW" "$FINAL"
    fi
  else
    echo "FFmpeg is installed without drawtext; creating web-compatible MP4 without text overlay."
    if ! ffmpeg -y -i "$RAW" -c:v libx264 -pix_fmt yuv420p -movflags +faststart "$FINAL"; then
      echo "WARNING: FFmpeg transcode failed; preserving raw recording as final MP4."
      cp "$RAW" "$FINAL"
    fi
  fi
else
  echo "FFmpeg not installed; preserving raw recording as final MP4."
  cp "$RAW" "$FINAL"
fi

echo "Raw MP4: $RAW"; echo "Demo MP4: $FINAL"; echo "UI test log: $LOG"
if [ "$TEST_STATUS" -ne 0 ]; then echo "UI test failed; recording retained for diagnosis."; exit "$TEST_STATUS"; fi
echo "PASS: automated ATOM Monitor feature tour completed."
