#!/usr/bin/env bash
# Fast CI path for geist-finance: shallow clone + rsync + force-push + dispatch + wait.
# (The standard ci-run.sh does a full clone of the shared repo, which is very slow.)
# Usage: bash ci/push-run.sh
set -uo pipefail
REPO="kingmariano/ca-zombie-ci"
FOLDER="geist-finance"
SRC="/home/heisenberg/CA/$FOLDER"
WORK="/tmp/opencode/geist-work"

mkdir -p "$WORK"
cd "$WORK"
if [ ! -d .git ]; then
  git init -q && git remote add origin "https://github.com/$REPO.git"
fi
git remote set-url origin "https://github.com/$REPO.git"
git fetch --depth 1 --filter=blob:none origin main -q || { echo "fetch failed"; exit 1; }
git checkout -q -B "$FOLDER" FETCH_HEAD

rsync -a --delete \
  --exclude '.git/' --exclude 'out/' --exclude 'cache/' --exclude 'ci-artifacts/' \
  --exclude 'ci-log.txt' --exclude '*.pyc' --exclude '__pycache__/' \
  "$SRC/" "$FOLDER/"

git add -A "$FOLDER" >/dev/null
git -c user.name="zombie-ci" -c user.email="zombie-ci@users.noreply.github.com" \
    commit -q -m "ci: $FOLDER $(date -u +%FT%TZ)" || echo "[ci] no changes"
git push -f origin "$FOLDER" -q || { echo "push failed"; exit 1; }
echo "[ci] pushed branch $FOLDER"

gh workflow run poc.yml --repo "$REPO" --ref "$FOLDER" -f finding="$FOLDER" >/dev/null 2>&1 \
  || { echo "dispatch failed"; exit 1; }

RUN_ID=""
for i in $(seq 1 60); do
  sleep 5
  RUN_ID=$(gh run list --repo "$REPO" --workflow poc.yml --limit 40 \
             --json databaseId,headBranch \
             -q "[.[] | select(.headBranch == \"$FOLDER\") | .databaseId] | first" 2>/dev/null)
  [ -n "$RUN_ID" ] && [ "$RUN_ID" != "null" ] && break
done
[ -z "$RUN_ID" ] || [ "$RUN_ID" = "null" ] && { echo "no run found"; exit 1; }
echo "[ci] run: https://github.com/$REPO/actions/runs/$RUN_ID"
gh run watch "$RUN_ID" --repo "$REPO" --interval 20 >/dev/null 2>&1
CONCLUSION=$(gh run view "$RUN_ID" --repo "$REPO" --json conclusion -q '.conclusion' 2>/dev/null)
echo "[ci] conclusion: $CONCLUSION"
gh run view "$RUN_ID" --repo "$REPO" --log > "$SRC/ci-log.txt" 2>/dev/null || true
rm -rf "$SRC/ci-artifacts"; mkdir -p "$SRC/ci-artifacts"
gh run download "$RUN_ID" --repo "$REPO" -D "$SRC/ci-artifacts" 2>/dev/null || true
ls -la "$SRC/ci-out" "$SRC/ci-artifacts" 2>/dev/null
[ "$CONCLUSION" = "success" ] || exit 1
