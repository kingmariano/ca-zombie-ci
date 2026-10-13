#!/usr/bin/env python3
"""Minimal Kaiascan (Kaia explorer) API client.

The Kaiascan web frontend signs API requests with an HS256 JWT whose
secret is shipped inside the public frontend JS bundle (so it is public
information, obtainable by anyone who loads the site). The signing scheme
was reverse-engineered from the public bundle:

  1. request params + `_t` (ms timestamp) are serialized k=v&k2=v2
     (encodeURIComponent, spaces -> +)
  2. query_hash = SHA-512(serialized) hex
  3. payload = {access_key, nonce: uuid4, query_hash, query_hash_alg: "SHA-512"}
  4. Authorization: Bearer <JWT HS256(payload, secretKey)>

This script ONLY reads keys from environment variables:
  KAIASCAN_ACCESS_KEY, KAIASCAN_SECRET_KEY
No key material is stored in this repository.
"""
import base64
import hashlib
import hmac
import json
import os
import sys
import time
import urllib.parse
import urllib.request
import uuid

API = "https://mainnet-api.kaiascan.io/api/v1"


def _b64url(b: bytes) -> str:
    return base64.urlsafe_b64encode(b).rstrip(b"=").decode()


def _jwt_hs256(payload: dict, key: str) -> str:
    header = {"alg": "HS256", "typ": "JWT"}
    h = _b64url(json.dumps(header, separators=(",", ":")).encode())
    p = _b64url(json.dumps(payload, separators=(",", ":")).encode())
    sig = hmac.new(key.encode(), f"{h}.{p}".encode(), hashlib.sha256).digest()
    return f"{h}.{p}.{_b64url(sig)}"


def _serialize(params: dict) -> str:
    out = []
    for k in params:
        v = params[k]
        if v is None:
            continue
        out.append(f"{urllib.parse.quote(str(k), safe='')}={urllib.parse.quote(str(v), safe='').replace('%20', '+')}")
    return "&".join(out)


def auth_header(serialized_query: str) -> str:
    ak = os.environ["KAIASCAN_ACCESS_KEY"]
    sk = os.environ["KAIASCAN_SECRET_KEY"]
    qhash = hashlib.sha512(serialized_query.encode()).hexdigest()
    payload = {
        "access_key": ak,
        "nonce": str(uuid.uuid4()),
        "query_hash": qhash,
        "query_hash_alg": "SHA-512",
    }
    return "Bearer " + _jwt_hs256(payload, sk)


def get(path: str, params: dict | None = None, raw=False):
    params = dict(params or {})
    params["_t"] = int(time.time() * 1000)
    qs = _serialize(params)
    url = f"{API}{path}?{qs}"
    req = urllib.request.Request(url, headers={
        "Authorization": auth_header(qs),
        "User-Agent": "Mozilla/5.0 (research; read-only)",
        "Accept": "application/json",
    })
    with urllib.request.urlopen(req, timeout=30) as r:
        body = r.read()
    return body if raw else json.loads(body)


if __name__ == "__main__":
    path = sys.argv[1]
    params = json.loads(sys.argv[2]) if len(sys.argv) > 2 else None
    print(json.dumps(get(path, params), indent=2)[:20000])
