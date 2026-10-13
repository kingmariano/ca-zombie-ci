#!/bin/bash
# ChildB worker: execute one cast call and emit a labeled raw line.
# Usage: worker.sh "CHAIN|RPC|BLOCK|LABEL|TO|SIG|ARGS"
# Emits: CHAIN|LABEL|OK|VALUE   or   CHAIN|LABEL|ERR|MESSAGE
export PATH="$HOME/.foundry/bin:$PATH"
IFS='|' read -r chain rpc block label to sig args <<< "$1"
# shellcheck disable=SC2086
if out=$(timeout 45 cast call "$to" "$sig" $args --block "$block" --rpc-url "$rpc" 2>&1); then
  printf '%s|%s|OK|%s\n' "$chain" "$label" "${out//$'\n'/ }"
else
  printf '%s|%s|ERR|%s\n' "$chain" "$label" "${out//$'\n'/ }"
fi
