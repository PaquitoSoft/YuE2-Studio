#!/bin/bash
# Builds YuE2 Studio.app and wraps it into a .dmg, in one command.
#
# The two steps cannot be fused into a single Tauri invocation. `--bundles dmg`
# runs create-dmg, which makes its image with `hdiutil create`, and that call is
# refused under a file sandbox ("hdiutil: create failed - Operation not
# permitted") even for a bare 8 MB image in a writable folder. `--bundles app`
# stops before that step, and make-dmg-macos.sh builds the image with
# `makehybrid` + `convert`, which are allowed.
#
# Usage: scripts/build-dmg-macos.sh [output.dmg]
#
# Output defaults to ../build/dmg-out/YuE2-Studio-<version>-macos-arm64.dmg,
# resolved beside the checkout so a development build does not write into it.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"

# A development checkout keeps the Rust and CMake this needs beside the
# repository rather than on PATH: the repo pins a Windows toolchain, and a
# system rustc can predate edition 2024. A release machine with its own
# toolchain has no such file, and is left alone. Override with YUE_ENV_FILE.
env_file="${YUE_ENV_FILE:-$root/../.toolchain/env.sh}"
if [ -f "$env_file" ]; then
    # shellcheck disable=SC1090
    . "$env_file"
fi

command -v cargo >/dev/null 2>&1 || { echo "[ERROR] cargo is not on PATH - source an env file (YUE_ENV_FILE) or install Rust" >&2; exit 1; }
command -v node >/dev/null 2>&1 || { echo "[ERROR] node is not on PATH" >&2; exit 1; }
[ -x "$root/desktop/node_modules/.bin/tauri" ] || { echo "[ERROR] the tauri CLI is missing - run 'npm --prefix desktop install'" >&2; exit 1; }

version="$(node -p "require('$root/desktop/src-tauri/tauri.conf.json').version")"
# Resolved once, so the path reported at the end has no `..` left in it.
default_out="$(cd "$root/.." && pwd)/build/dmg-out/YuE2-Studio-$version-macos-arm64.dmg"
out="${1:-$default_out}"

echo "=== building YuE2 Studio $version ==="
( cd "$root/desktop" && node_modules/.bin/tauri build \
    --config src-tauri/tauri.macos-release.conf.json --bundles app )

app="$root/desktop/src-tauri/target/release/bundle/macos/YuE2 Studio.app"
if [ ! -d "$app" ]; then
    echo "[ERROR] the build produced no app bundle at $app" >&2
    exit 1
fi

echo
echo "=== wrapping it into a dmg ==="
bash "$root/scripts/make-dmg-macos.sh" "$app" "$out"

echo
echo "done: $out"
