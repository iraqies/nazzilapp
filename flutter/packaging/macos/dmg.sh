#!/usr/bin/env bash
# Packs the macOS release build as a disk image in build/dist/, the app beside a link to Applications.
# Run after `flutter build macos --release`.
set -euo pipefail

cd "$(dirname "$0")/../.."
VERSION="$(sed -n 's/^version: *\([0-9.]*\).*/\1/p' pubspec.yaml)"
APP=build/macos/Build/Products/Release/Nazzil.app
STAGE=build/packaging/macos
OUT="build/dist/Nazzil-$VERSION-macos.dmg"

[[ -d "$APP" ]] || { echo "No app at $APP: run flutter build macos --release first" >&2; exit 1; }
rm -rf "$STAGE"
mkdir -p "$STAGE" build/dist
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

# On a CI machine hdiutil now and then finds the volume busy; a later try goes through.
for attempt in 1 2 3 4 5; do
  if hdiutil create -volname Nazzil -srcfolder "$STAGE" -ov -format UDZO "$OUT"; then
    ls -l "$OUT"
    exit 0
  fi
  sleep $((attempt * 5))
done
exit 1
