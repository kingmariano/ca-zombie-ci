# H-05 ViteX — CI verification run (independent vantage point)

## Run 1 — endpoint/liveness scan

- URL: https://github.com/kingmariano/ca-zombie-ci/actions/runs/37132690689
- Branch: `vitex`, workflow `poc.yml`, conclusion: **success**
- Runner: GitHub Actions Ubuntu (Azure, 4 vCPU) — 2026-10-03T15:17Z
- Job: `vitex/ci/run.sh` (read-only network scan)
- Artifacts: `vitex/ci-artifacts/result-vitex/ci-out/` (endpoint-scan.txt/json, per-host DoH JSON, vite.net bundle)

Key results (from the runner, independent of the author's host):

```
node.vite.net        CNAME=vitenode-837259984.us-east-1.elb.amazonaws.com.  http=000 (target NXDOMAIN)
vitex.vite.net       Status=3 (NXDOMAIN)                                     http=000
config.vite.net      CNAME=d-28npzmg7sk.execute-api.us-east-1.amazonaws.com. http=000 (target NXDOMAIN)
api.vite.net         CNAME=d-583y2v6j0e.execute-api.us-east-1.amazonaws.com. http=000 (target NXDOMAIN)
gateway.vite.net     NXDOMAIN                                                http=000
crosschain.vite.net  NXDOMAIN                                                http=000
biforst.vite.net     CNAME=viteconnectlb-1888616360.us-east-1.elb.amazonaws.com. http=000 (target NXDOMAIN)
buidl.vite.net       NXDOMAIN                                                http=000
vitescan.io          A=47.240.225.75                                         http=000 (timeout)
vitex.net            Status=2 (DNS refused)                                  http=000
POST https://node.vite.net/gvite       -> curl: (6) Could not resolve host
POST https://vitex.vite.net            -> curl: (6) Could not resolve host
POST https://mainnet.viteview.xyz/gvite-> POST is not a valid request method
```

check-host.net global HTTP check for `https://vitescan.io/` (run from the CI
runner, 6 nodes): au1, ch1, de1, rs1, ua1 → **Connection timed out**; in2 no
result. (Author's earlier run: de1, es2, fi1, ir4, se2, us3 → all timeouts.)

The live `https://vite.net` wallet bundle still references only dead endpoints:
`wss://node.vite.net/gvite/ws`, `wss://vitex.vite.net/websocket`,
`https://vitex.vite.net`, `https://config.vite.net`, `https://gateway.vite.net`,
`https://crosschain.vite.net`.

## Run 2 — (pending, if needed)

Reserved for any additional verification (e.g. repeated checks at a later time
to show the endpoints remain dead).
