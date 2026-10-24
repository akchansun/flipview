#!/usr/bin/env bash
# Build a universal Release Flip.app zip (Intel + Apple Silicon).
# Run on macOS with Xcode. Usage: scripts/package_macos.sh [version]
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This script must run on macOS (xcodebuild)." >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' SimpleImageViewer/Info.plist)"
fi

DD="${DERIVED_DATA_PATH:-$ROOT/.build/derived}"
xcodebuild -project SimpleImageViewer.xcodeproj -scheme SimpleImageViewer \
  -configuration Release -destination 'generic/platform=macOS' \
  ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
  -derivedDataPath "$DD"

APP="$DD/Build/Products/Release/Flip.app"
if [[ ! -d "$APP" ]]; then
  echo "Flip.app not found at $APP" >&2
  exit 1
fi

OUT="${OUTPUT_ZIP:-$ROOT/Flip-${VERSION}-macos-universal.zip}"
rm -f "$OUT"
ditto -c -k --keepParent "$APP" "$OUT"
echo "$OUT"
