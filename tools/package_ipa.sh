#!/usr/bin/env bash
# Package unsigned Runner.app into an .ipa (for Scarlet / Sideloadly import).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="$(grep '^version:' pubspec.yaml | sed 's/version: //' | tr -d ' ')"
OUT="Abar_Tawseeh_ICT-${VERSION}.ipa"
APP="build/ios/iphoneos/Runner.app"

if [[ ! -d "$APP" ]]; then
  echo "Missing $APP — run: flutter build ios --release --no-codesign"
  exit 1
fi

rm -rf build/ipa
mkdir -p build/ipa/Payload
cp -R "$APP" build/ipa/Payload/
(cd build/ipa && zip -r "../${OUT}" Payload)
mv "build/${OUT}" .

echo "Created: $ROOT/${OUT}"
