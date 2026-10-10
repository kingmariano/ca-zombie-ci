#!/usr/bin/env bash
# H2-05 (eos-misc) CI heavy/verification job — public endpoints only, no secrets.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p ci-out
python3 ci/verify_eos.py
export PATH="$PATH:$HOME/.foundry/bin"
bash ci/verify_plasma_fluent.sh
echo "eos-misc verification done" | tee -a ci-out/run-note.txt
