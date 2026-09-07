#!/usr/bin/env bash
# بیلد فقط iOS IPA (نیاز به macOS + Xcode)
# اجرا:
#   bash tools/build_ios.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "[X] بیلد iOS فقط روی macOS ممکن است."
  echo "    روی ویندوز از GitHub Actions استفاده کنید: .github/workflows/ios-ipa.yml"
  exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "[X] flutter در PATH نیست."
  exit 1
fi

VERSION="$(grep '^version:' pubspec.yaml | sed 's/version: //' | tr -d ' ')"
echo "══ iOS IPA build — v${VERSION}"
echo "Root: $ROOT"
echo

echo ">> flutter pub get"
flutter pub get

if command -v dart >/dev/null 2>&1; then
  dart run flutter_launcher_icons || true
fi

echo ">> flutter build ios --release --no-codesign"
flutter build ios --release --no-codesign

bash "$ROOT/tools/package_ipa.sh"

OUT="Jahan_Bit-${VERSION}.ipa"
mkdir -p "$ROOT/dist/ios"
if [[ -f "$ROOT/$OUT" ]]; then
  cp -f "$ROOT/$OUT" "$ROOT/dist/ios/$OUT"
  echo "[OK] $ROOT/dist/ios/$OUT"
elif [[ -f "$ROOT/$OUT" ]]; then
  echo "[OK] $ROOT/$OUT"
else
  # package_ipa may leave file in root
  ls -la "$ROOT"/Jahan_Bit-*.ipa 2>/dev/null || true
fi

echo
echo "تمام شد."
