#!/usr/bin/env bash
set -euo pipefail
flutter pub get
dart run sqflite_common_ffi_web:setup --force
flutter build web --release --base-href /spendwise-ai/ \
  --dart-define=SPENDWISE_DEMO=true --no-web-resources-cdn
test -s build/web/sqlite3.wasm
test -s build/web/sqflite_sw.js
# Precache every bundled render and database asset for offline reloads.
python3 - <<'PYCORE'
from pathlib import Path
import re
worker = Path('build/web/flutter_service_worker.js')
source, count = re.subn(r'const CORE = \[.*?\];',
    'const CORE = Object.keys(RESOURCES);', worker.read_text(), count=1, flags=re.S)
if count != 1:
    raise SystemExit('Flutter service worker template changed; review offline caching')
worker.write_text(source)
PYCORE
touch build/web/.nojekyll
