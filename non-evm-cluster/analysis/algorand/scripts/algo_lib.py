"""Read-only Algorand helpers (keyless public endpoints only).

Endpoints:
  algod    https://mainnet-api.algonode.cloud/v2
  indexer  https://mainnet-idx.algonode.cloud/v2
"""
import base64
import hashlib
import json
import time
import urllib.request
import urllib.error

ALGOD = "https://mainnet-api.algonode.cloud/v2"
INDEXER = "https://mainnet-idx.algonode.cloud/v2"
UA = {"User-Agent": "zombie-research/1.0 (read-only)"}


def _req(url, data=None, headers=None, method=None):
    h = dict(UA)
    if headers:
        h.update(headers)
    req = urllib.request.Request(url, data=data, headers=h, method=method)
    last = None
    for attempt in range(6):
        try:
            with urllib.request.urlopen(req, timeout=45) as r:
                body = r.read()
                try:
                    return json.loads(body)
                except Exception:
                    return body
        except urllib.error.HTTPError as e:
            last = e
            if e.code in (429, 500, 502, 503, 504):
                time.sleep(2 ** attempt * 0.5)
                continue
            raise
        except Exception as e:  # noqa: BLE001
            last = e
            time.sleep(1.5 * (attempt + 1))
    raise RuntimeError(f"request failed: {url}: {last}")


def algod_get(path):
    return _req(ALGOD + path)


def indexer_get(path):
    return _req(INDEXER + path)


def disassemble(program_b64):
    """Disassemble a TEAL program (base64) via algod /v2/teal/disassemble."""
    raw = base64.b64decode(program_b64)
    out = _req(
        ALGOD + "/teal/disassemble",
        data=raw,
        headers={"Content-Type": "application/octet-stream"},
        method="POST",
    )
    if isinstance(out, dict) and "result" in out:
        return out["result"]
    return out


def app_address(app_id: int) -> str:
    h = hashlib.new("sha512_256", b"appID" + app_id.to_bytes(8, "big")).digest()
    chk = hashlib.new("sha512_256", h).digest()[-4:]
    return base64.b32encode(h + chk).decode().rstrip("=")


def b64key(k: str) -> str:
    return base64.b64decode(k).decode("utf-8", "replace")


def decode_global_state(gs):
    """Decode algod global-state list -> {key: value} where value is int or base64 str."""
    out = {}
    for e in gs or []:
        k = b64key(e["key"])
        v = e["value"]
        if v["type"] == 2:
            out[k] = v["uint"]
        else:
            out[k] = v.get("bytes", "")
    return out


def get_app(app_id: int):
    return algod_get(f"/applications/{app_id}")


def get_account(addr: str):
    return algod_get(f"/accounts/{addr}")


def get_asset(asset_id: int):
    return indexer_get(f"/assets/{asset_id}")


def get_indexer_app(app_id: int):
    return indexer_get(f"/applications/{app_id}")


def apps_by_creator(creator: str, limit=100, page_size=100):
    """Paginate indexer /applications?creator=..."""
    out = []
    params = f"?creator={creator}&limit={page_size}"
    while True:
        d = indexer_get("/applications" + params)
        apps = d.get("applications", [])
        out.extend(apps)
        nxt = d.get("next-token")
        if not nxt or len(out) >= limit:
            break
        params = f"?creator={creator}&limit={page_size}&next={urllib.request.quote(nxt)}"
    return out


def microalgos_to_algo(x):
    return x / 1e6


def addr_from_pk(pk32: bytes) -> str:
    chk = hashlib.new("sha512_256", pk32).digest()[-4:]
    return base64.b32encode(pk32 + chk).decode().rstrip("=")
