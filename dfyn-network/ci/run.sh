#!/usr/bin/env bash
# CI custom job: full Dfyn pair integrity scan across Polygon/Fantom/OKC.
set -uo pipefail
cd "$(dirname "$0")/.."
echo "=== dfyn-network CI job start $(date -u +%FT%TZ) ==="
python3 --version
python3 ci/scan_pairs.py
echo "=== job done $(date -u +%FT%TZ) ==="
ls -la ci-out/
