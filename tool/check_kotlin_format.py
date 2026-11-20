"""Run the version/hash-pinned test-only Kotlin formatter (JDK 17 required)."""
import hashlib
from pathlib import Path
import subprocess
import sys
import tempfile
import urllib.request

VERSION = "0.54"
SHA256 = "5e7eb28a0b2006d1cefbc9213bfc73a8191ec2f85d639ec4fc4ec0cd04212e82"
jar = Path(tempfile.gettempdir()) / "spendwise-ktfmt.jar"
if not jar.exists() or hashlib.sha256(jar.read_bytes()).hexdigest() != SHA256:
    url = f"https://repo.maven.apache.org/maven2/com/facebook/ktfmt/{VERSION}/ktfmt-{VERSION}-jar-with-dependencies.jar"
    with urllib.request.urlopen(url) as response:
        data = response.read()
    if hashlib.sha256(data).hexdigest() != SHA256:
        raise SystemExit("Kotlin formatter checksum mismatch")
    jar.write_bytes(data)
files = sorted(str(p) for root in ["android/app/src/main/kotlin", "android/app/src/test/kotlin"]
               for p in Path(root).rglob("*.kt"))
options = [] if "--write" in sys.argv else ["--dry-run", "--set-exit-if-changed"]
raise SystemExit(subprocess.call(["java", "-jar", str(jar), "--kotlinlang-style", *options, *files]))
