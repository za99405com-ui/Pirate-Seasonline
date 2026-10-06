#!/usr/bin/env bash
set -euo pipefail

MODEL_URL="https://storage.to3d.app/generated-3d/models/2026-10-06/task_6d8016fe-7f2b-482c-b9d3-1c8d76415392_model.glb"
TARGET="assets/models/pirate_ship.glb"
TMP="${TARGET}.download"

mkdir -p "$(dirname "$TARGET")"
echo "Downloading Level 1 pirate ship model..."
curl -L --fail --silent --show-error --retry 3 --retry-delay 2 --connect-timeout 20 --max-time 180 -o "$TMP" "$MODEL_URL"

python3 - "$TMP" <<'PY'
import os
import struct
import sys

path = sys.argv[1]
size = os.path.getsize(path)
if size < 100_000:
    raise SystemExit(f"Downloaded GLB is unexpectedly small: {size} bytes")

with open(path, "rb") as f:
    magic = f.read(4)
    version = struct.unpack("<I", f.read(4))[0]

if magic != b"glTF" or version != 2:
    raise SystemExit("Downloaded file is not a valid GLB 2.0 model")

print(f"Validated Level 1 ship GLB: {size / 1024 / 1024:.2f} MiB")
PY

mv "$TMP" "$TARGET"
echo "Level 1 ship model installed at $TARGET"
