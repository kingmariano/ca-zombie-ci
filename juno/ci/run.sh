#!/usr/bin/env bash
# C2-07 Juno governance capture - CI heavy job.
# Runs on the public ca-zombie-ci runner. Read-only RPC against public Juno endpoints.
set -uo pipefail
cd "$(dirname "$0")/.."          # finding folder (juno/)
mkdir -p ci-out

GRPCURL=/tmp/grpcurl
if [ ! -x "$GRPCURL" ]; then
  echo "[ci] fetching grpcurl..."
  curl -sL --max-time 120 -o /tmp/grpcurl.tar.gz \
    https://github.com/fullstorydev/grpcurl/releases/download/v1.9.3/grpcurl_1.9.3_linux_x86_64.tar.gz \
    && tar xzf /tmp/grpcurl.tar.gz -C /tmp grpcurl && chmod +x "$GRPCURL"
fi
"$GRPCURL" --version || echo "[ci] WARN grpcurl unavailable; gov params may be skipped"

python3 -c "import requests" 2>/dev/null || pip install --quiet --disable-pip-version-check requests
python3 ci/scan.py 2>&1 | tee ci-out/scan.log
echo "[ci] done; artifacts:"
ls -la ci-out/
