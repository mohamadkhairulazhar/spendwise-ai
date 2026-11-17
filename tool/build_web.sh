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
# Precache the database worker/WASM and render assets as well as the app shell.
# This is needed for offline reloads even if a worker's fetch is not intercepted.
python3 - <<'PYCORE'
from pathlib import Path
import re
worker = Path('build/web/flutter_service_worker.js')
source = worker.read_text()
source, count = re.subn(r'const CORE = \[.*?\];',
    'const CORE = Object.keys(RESOURCES);', source, count=1, flags=re.S)
if count != 1:
    raise SystemExit('Flutter service worker template changed; review offline caching')
worker.write_text(source)
PYCORE
touch build/web/.nojekyll
