#!/usr/bin/env bash
set -euo pipefail
# Versions are constrained in pubspec.yaml and resolved in pubspec.lock.
flutter pub get
dart run sqflite_common_ffi_web:setup --force
flutter build web --release --base-href /spendwise-ai/ \
  --dart-define=SPENDWISE_DEMO=true --no-web-resources-cdn
# Verify the two database assets are shipped at the same base as the app.
test -s build/web/sqlite3.wasm
test -s build/web/sqflite_sw.js
touch build/web/.nojekyll
