#!/usr/bin/env python3
"""Recover deleted DefiLlama adapters from git history (last commit that had the file).
Uses authenticated `gh api`. Saves to adapters/{slug}.js."""
import json, os, subprocess, base64, sys

BASE = os.path.dirname(os.path.abspath(__file__))
CA = os.path.dirname(os.path.dirname(BASE))

def gh_json(args):
    r = subprocess.run(["gh", "api"] + args, capture_output=True, text=True)
    if r.returncode != 0:
        return None
    try:
        return json.loads(r.stdout)
    except Exception:
        return None

def main():
    mine = json.load(open(os.path.join(CA, "ci/L2-SPLIT-A.json")))
    protos = json.load(open(os.path.join(BASE, "llama-protocols.json")))
    byname = {p["slug"]: p for p in protos if p.get("slug")}
    ad_dir = os.path.join(BASE, "adapters")
    have = set(f[:-3] for f in os.listdir(ad_dir))
    todo = [r for r in mine if r["slug"].strip("`") not in have]
    print(f"{len(todo)} to recover")
    for r in todo:
        s = r["slug"].strip("`")
        mod = (byname.get(s) or {}).get("module") or ""
        if not mod:
            print(s, "NO MODULE"); continue
        fp = os.path.join(ad_dir, s + ".js")
        # 1. find commits that touched the file; walk back until the file exists
        commits = gh_json([f"repos/DefiLlama/DefiLlama-Adapters/commits?path=projects/{mod}&per_page=8"])
        if not commits:
            print(s, "no commits"); continue
        done = False
        for c in commits:
            sha = c["sha"]
            obj = gh_json([f"repos/DefiLlama/DefiLlama-Adapters/contents/projects/{mod}?ref={sha}"])
            if obj and "content" in obj:
                try:
                    data = base64.b64decode(obj["content"]).decode("utf-8", "replace")
                except Exception as e:
                    print(s, "b64 fail", e); break
                open(fp, "w").write(data)
                print(s, f"OK {len(data)}b @{sha[:10]} ({c['commit']['author']['date'][:10]})")
                done = True
                break
        if not done:
            print(s, "no content in last", len(commits), "commits")

if __name__ == "__main__":
    main()
