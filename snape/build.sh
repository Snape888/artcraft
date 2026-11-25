#!/usr/bin/env bash
# snape/build.sh (ArtCraft only): build "ArtCraft (Snape).app" into dist/snape/.
# Snape-only NEW files (this + tauri.snape.json); no upstream file is edited, so rebases can't
# conflict on them. ArtCraft is Tauri (not egui), so it can't use packaging/macos/package.sh +
# brand.sh like the other Craft apps; the rename happens at build time via a merged --config.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="$HOME/.cargo/bin:/opt/homebrew/bin:$PATH"
export SQLX_OFFLINE=true NODE_OPTIONS="--max-old-space-size=8192" NX_DAEMON=false NX_NO_CLOUD=true

echo "==> frontend (npm ci only when the lockfile changed)"
cd "$ROOT/frontend"
if [[ ! -f node_modules/.package-lock.json || package-lock.json -nt node_modules/.package-lock.json ]]; then
  npm ci --ignore-scripts --no-audit --no-fund
fi
./node_modules/.bin/nx run artcraft:build

echo "==> tauri build (ad-hoc signed, .app only)"
cd "$ROOT/crates/desktop/artcraft"
TAURI_V="$(awk '/^name = "tauri"$/{getline; gsub(/[^0-9.]/,""); print; exit}' "$ROOT/Cargo.lock")"   # e.g. 2.11.2
npx --yes "@tauri-apps/cli@^${TAURI_V%.*}" build --bundles app --config "$ROOT/snape/tauri.snape.json"

APP="$(find "${CARGO_TARGET_DIR:-$ROOT/target}/release/bundle/macos" -maxdepth 1 -name 'ArtCraft (Snape).app' | head -1)"
[[ -n "$APP" ]] || { echo "build.sh: no 'ArtCraft (Snape).app' produced" >&2; exit 1; }
OUT="$ROOT/dist/snape/ArtCraft (Snape).app"
rm -rf "$OUT"; mkdir -p "$(dirname "$OUT")"; ditto "$APP" "$OUT"
codesign --verify --strict --deep --verbose=2 "$OUT"
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' -c 'Print :CFBundleName' -c 'Print :CFBundleShortVersionString' "$OUT/Contents/Info.plist"
echo "==> $OUT"
