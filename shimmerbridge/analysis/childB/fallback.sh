#!/bin/bash
# fallback.sh "CHAIN|BLOCK|LABEL|TO|SIG|ARGS" rpc1 rpc2 rpc3 ...
# Tries each RPC in order until OK. Emits one line per attempt:
#   CHAIN|LABEL|OK|VALUE|RPC   or   CHAIN|LABEL|ERR|MESSAGE|RPC
export PATH="$HOME/.foundry/bin:$PATH"
IFS='|' read -r chain block label to sig args <<< "$1"
shift
for rpc in "$@"; do
  # shellcheck disable=SC2086
  if out=$(timeout 45 cast call "$to" "$sig" $args --block "$block" --rpc-url "$rpc" 2>&1); then
    v="${out//$'\n'/ }"
    printf '%s|%s|OK|%s|%s\n' "$chain" "$label" "${v%% \[*}" "$rpc"
    exit 0
  else
    v="${out//$'\n'/ }"
    printf '%s|%s|ERR|%s|%s\n' "$chain" "$label" "${v:0:200}" "$rpc"
  fi
  sleep 2
done
exit 1
