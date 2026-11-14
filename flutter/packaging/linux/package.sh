#!/usr/bin/env bash
# Packs the Linux release bundle as a .deb and as an AppImage, into build/dist/.
# Run after `flutter build linux --release`, on the Ubuntu the bundle was built on:
# the .deb names its dependencies, and the AppImage carries its codecs, from that system.
set -euo pipefail

cd "$(dirname "$0")/../.."
VERSION="$(sed -n 's/^version: *\([0-9.]*\).*/\1/p' pubspec.yaml)"
BUNDLE=build/linux/x64/release/bundle
WORK="$PWD/build/packaging/linux"
DIST="$PWD/build/dist"
ID=com.nazzil.nazzil
ICON=macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png
# FFmpeg's audio build links these codec libraries, and a desktop Ubuntu does not ship them all.
CODECS=(libmp3lame0 libogg0 libopencore-amrnb0 libopus0 libshine3 libsoxr0 libspeex1 libtwolame0 libvo-amrwbenc0 libvorbis0a libvorbisenc2)

[[ -x "$BUNDLE/nazzil" ]] || { echo "No bundle at $BUNDLE: run flutter build linux --release first" >&2; exit 1; }
rm -rf "$WORK"
mkdir -p "$WORK" "$DIST"

# .deb: the bundle in /opt/nazzil, a command on the PATH, and the menu entry with its icon.
DEB="$WORK/deb"
mkdir -p "$DEB/DEBIAN" "$DEB/opt" "$DEB/usr/bin" "$DEB/usr/share/applications" "$DEB/usr/share/icons/hicolor/512x512/apps"
cp -a "$BUNDLE" "$DEB/opt/nazzil"
ln -s /opt/nazzil/nazzil "$DEB/usr/bin/nazzil"
cp "packaging/linux/$ID.desktop" "$DEB/usr/share/applications/"
cp "$ICON" "$DEB/usr/share/icons/hicolor/512x512/apps/$ID.png"

# dpkg-shlibdeps reads which system libraries the program and its plugins load, and names
# the packages that hold them. The libraries in the bundle's own lib/ need no package.
mkdir -p "$WORK/shlibs/debian"
touch "$WORK/shlibs/debian/control"
DEPENDS="$(cd "$WORK/shlibs" && dpkg-shlibdeps -O --ignore-missing-info -l"$DEB/opt/nazzil/lib" \
  "$DEB/opt/nazzil/nazzil" "$DEB"/opt/nazzil/lib/*.so* 2>"$WORK/shlibdeps.log" | sed -n 's/^shlibs:Depends=//p')"
[[ -n "$DEPENDS" ]] || { cat "$WORK/shlibdeps.log" >&2; echo "dpkg-shlibdeps named no dependencies" >&2; exit 1; }

cat >"$DEB/DEBIAN/control" <<EOF
Package: nazzil
Version: $VERSION
Section: video
Priority: optional
Architecture: amd64
Installed-Size: $(du -sk "$DEB" | cut -f1)
Depends: $DEPENDS
Maintainer: Nazzil <nazzil@users.noreply.github.com>
Description: Save video, photos and audio from your favourite apps
 Paste a link from YouTube, TikTok, Instagram, Facebook, Reddit, X or
 Pinterest, pick the quality, and Nazzil saves the file.
EOF
dpkg-deb --root-owner-group --build "$DEB" "$DIST/Nazzil-$VERSION-linux-amd64.deb"

# AppImage: the bundle and the codecs in one file that runs where it is put. GTK and the
# C library come from the system, as they do for any GTK app.
APPDIR="$WORK/Nazzil.AppDir"
mkdir -p "$APPDIR/usr/lib" "$APPDIR/usr/share/icons/hicolor/512x512/apps"
cp -a "$BUNDLE" "$APPDIR/usr/lib/nazzil"
mkdir -p "$APPDIR/usr/lib/codecs"
for package in "${CODECS[@]}"; do
  dpkg -L "$package" | grep -E '/lib[^/]*\.so[.0-9]*$' | xargs -r cp -a -t "$APPDIR/usr/lib/codecs/"
done
cp "packaging/linux/$ID.desktop" "$APPDIR/$ID.desktop"
cp "$ICON" "$APPDIR/$ID.png"
cp "$ICON" "$APPDIR/usr/share/icons/hicolor/512x512/apps/$ID.png"
cat >"$APPDIR/AppRun" <<'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
export LD_LIBRARY_PATH="$HERE/usr/lib/codecs${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec "$HERE/usr/lib/nazzil/nazzil" "$@"
EOF
chmod +x "$APPDIR/AppRun"

TOOL="$(command -v appimagetool || true)"
if [[ -z "$TOOL" ]]; then
  TOOL="$WORK/appimagetool"
  curl -fsSL -o "$TOOL" https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage
  chmod +x "$TOOL"
fi
# Extract-and-run needs no FUSE, which a CI machine or a container may not have.
ARCH=x86_64 APPIMAGE_EXTRACT_AND_RUN=1 "$TOOL" --no-appstream "$APPDIR" "$DIST/Nazzil-$VERSION-linux-x86_64.AppImage"

ls -l "$DIST"
