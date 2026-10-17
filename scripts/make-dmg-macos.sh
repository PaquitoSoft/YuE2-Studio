#!/bin/bash
# Builds the studio's .dmg without `hdiutil create`.
#
# Tauri's dmg bundler runs create-dmg, which makes its image with
# `hdiutil create`. Under a file sandbox that call is refused with
# "hdiutil: create failed - Operation not permitted" - even for a bare 8 MB
# image in a writable folder - while `hdiutil makehybrid` and `hdiutil convert`
# are allowed. So the payload is staged and the image is made with those two.
#
# The result mounts and installs like the released one. What it lacks is
# create-dmg's Finder decoration: no custom background, no fixed icon
# positions, no window size. That is cosmetic; the app and the /Applications
# link are there.
#
# Usage: scripts/make-dmg-macos.sh "<path to YuE2 Studio.app>" "<output .dmg>"
set -euo pipefail

app="${1:?usage: make-dmg-macos.sh <app bundle> <output .dmg>}"
dmg="${2:?usage: make-dmg-macos.sh <app bundle> <output .dmg>}"

if [ ! -d "$app" ]; then
    echo "[ERROR] no app bundle at $app" >&2
    exit 1
fi

app_name="$(basename "$app")"
volume="${app_name%.app}"
stage="$(mktemp -d "${TMPDIR:-/tmp}/yue2-dmg.XXXXXX")"
raw="${dmg%.dmg}-rw.dmg"

mkdir -p "$(dirname "$dmg")"
cleanup() { rm -rf "$stage"; rm -f "$raw"; }
trap cleanup EXIT

# ditto keeps the bundle's signature and resource forks, cp -R does not.
ditto "$app" "$stage/$app_name"
ln -s /Applications "$stage/Applications"

echo "staging $app_name ($(du -sh "$app" | cut -f1))..."
hdiutil makehybrid -default-volume-name "$volume" -hfs -o "$raw" "$stage" >/dev/null

echo "compressing..."
# -ov: rebuilding into the same path is the normal case, and convert refuses an
# existing file without it.
hdiutil convert "$raw" -format UDZO -ov -o "$dmg" >/dev/null

size="$(du -h "$dmg" | cut -f1)"
echo "built $dmg ($size)"
