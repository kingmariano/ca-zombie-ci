#!/usr/bin/env python3
"""Assemble README.md from narrative + generated table + results."""
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
res = json.load(open(os.path.join(ROOT, "ci-out", "results.json")))
rows = res["rows"]
ranked = sorted(rows, key=lambda r: -(r.get("live_usd") or 0))
table = open(os.path.join(ROOT, "analysis", "table.md")).read()
narrative = open(os.path.join(ROOT, "analysis", "narrative-draft.md")).read()

funded = [r for r in rows if r["status"] == "LIVE-FUNDED"]
drained = [r for r in rows if r["status"] == "DRAINED"]
unreach = [r for r in rows if r["status"] == "UNREACHABLE"]
total = sum((r.get("live_usd") or 0) for r in rows)

short_rows = [r for r in ranked if r["status"] == "LIVE-FUNDED" and (r.get("live_usd") or 0) >= 100]
short_lines = []
for i, r in enumerate(short_rows, 1):
    reason = REASONS.get(r["slug"], "")
    short_lines.append(f"{i}. **{r['protocol']}** ({r['chain']}) — ${r.get('live_usd'):,.0f} — {reason}")
short_md = "\n".join(short_lines)

REASONS = {}  # filled below via exec of a dict
