#!/usr/bin/env bash
# Generates the Android platform folder with the pinned Flutter version,
# then applies the app's native code, manifest, icons and signing key.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GEN="$(mktemp -d)"
flutter create --org com.selema --project-name selema_gold --platforms android "$GEN/app" >/dev/null
rm -rf "$ROOT/android"
cp -r "$GEN/app/android" "$ROOT/android"
PKG="$ROOT/android/app/src/main/kotlin/com/selema/selema_gold"
mkdir -p "$PKG"
rm -f "$PKG"/*.kt
cp "$ROOT"/native/kotlin/*.kt "$PKG/"
cp "$ROOT/native/AndroidManifest.xml" "$ROOT/android/app/src/main/AndroidManifest.xml"
cp -r "$ROOT"/native/res/* "$ROOT/android/app/src/main/res/"
mkdir -p "$HOME/.android"
cp "$ROOT/native/debug.keystore" "$HOME/.android/debug.keystore"
echo "Android platform prepared"
