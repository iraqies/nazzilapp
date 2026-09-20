#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP=""
for candidate in \
  build/ios/iphoneos/Runner.app \
  build/ios/sideload-derived/Build/Products/Release-iphoneos/Runner.app \
  build/ios/Release-iphoneos/Runner.app
do
  if [[ -d "$candidate" ]]; then
    APP="$candidate"
    break
  fi
done

if [[ -z "$APP" ]]; then
  APP="$(find build -type d -name Runner.app 2>/dev/null | grep -i iphoneos | head -n 1 || true)"
fi

if [[ -z "$APP" || ! -d "$APP" ]]; then
  echo "Runner.app not found under $ROOT/build" >&2
  find build -name 'Runner.app' -type d 2>/dev/null || true
  exit 1
fi

STAGING="$ROOT/build/ios/sideload"
rm -rf "$STAGING"
mkdir -p "$STAGING/Payload"
cp -R "$APP" "$STAGING/Payload/"
(
  cd "$STAGING"
  zip -qry Nazzil.ipa Payload
)
ls -lh "$STAGING/Nazzil.ipa"
echo "$STAGING/Nazzil.ipa"
