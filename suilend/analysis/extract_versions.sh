#!/usr/bin/env bash
# Extract per-version source snapshots from the public suilend repo using deploy timestamps.
set -e
REPO=/tmp/opencode/suilend-repo
OUT=/home/heisenberg/CA/suilend/analysis
declare -A DEPLOY=(
 [10]="2025-01-13T15:43:22Z" [11]="2025-02-06T18:27:41Z" [12]="2025-02-26T07:00:34Z"
 [13]="2025-03-14T17:09:46Z" [14]="2025-06-03T09:22:12Z" [15]="2025-08-19T03:28:49Z"
 [16]="2025-11-10T05:58:49Z" [17]="2026-01-06T02:38:40Z" [18]="2026-01-31T01:47:52Z"
 [19]="2026-02-24T10:32:05Z" [20]="2026-03-05T06:53:56Z"
)
cd "$REPO"
for v in "${!DEPLOY[@]}"; do
  t="${DEPLOY[$v]}"
  # prefer mainnet branch, fall back to devel
  c=$(git rev-list -1 --before="$t" mainnet 2>/dev/null || true)
  [ -z "$c" ] && c=$(git rev-list -1 --before="$t" devel)
  mkdir -p "$OUT/src-v$v"
  for f in $(git ls-tree -r --name-only "$c" -- contracts/suilend/sources | grep '\.move$'); do
    git show "$c:$f" > "$OUT/src-v$v/$(basename "$f")" 2>/dev/null || true
  done
  echo "v$v -> $c ($(git show -s --format='%cI' $c))"
done
