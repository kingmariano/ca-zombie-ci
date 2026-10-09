#!/usr/bin/env python3
"""Read-only ABCI query for gov params across the C2-26 chains.
Decodes protobuf generically (wire types) and prints candidate strings.
No secrets, public endpoints only."""
import base64, json, sys, urllib.request

def get(url, timeout=25):
    req = urllib.request.Request(url, headers={'User-Agent': 'zombie-research/1.0'})
    return urllib.request.urlopen(req, timeout=timeout).read()

def varint(b, i):
    r = 0; s = 0
    while True:
        x = b[i]; i += 1
        r |= (x & 0x7f) << s
        if not (x & 0x80): break
        s += 7
    return r, i

def parse(b, depth=0, out=None):
    """Generic protobuf field walker. Returns list of (field_no, wire, value)."""
    if out is None: out = []
    i = 0
    while i < len(b):
        try:
            key, i = varint(b, i)
        except Exception:
            break
        fn, wt = key >> 3, key & 7
        if wt == 0:
            v, i = varint(b, i); out.append((fn, wt, v))
        elif wt == 1:
            v = b[i:i+8]; i += 8; out.append((fn, wt, v))
        elif wt == 2:
            ln, i = varint(b, i); v = b[i:i+ln]; i += ln; out.append((fn, wt, v))
        elif wt == 5:
            v = b[i:i+4]; i += 4; out.append((fn, wt, v))
        else:
            break
    return out

def decode(b):
    """Return {field: [values]} with strings decoded when printable."""
    fields = {}
    for fn, wt, v in parse(b):
        fields.setdefault(fn, []).append((wt, v))
    return fields

def _try_str(v):
    try:
        s = v.decode('utf-8')
        if s and all(32 <= ord(ch) < 127 for ch in s):
            return repr(s)
    except Exception:
        pass
    return None

def show(label, raw, limit=90, depth=0, maxdepth=3):
    fields = decode(raw)
    for fn in sorted(fields):
        for wt, v in fields[fn]:
            disp = None
            if wt == 2:
                s = _try_str(v)
                if s is not None:
                    disp = s
                elif depth < maxdepth:
                    sub = decode(v)
                    # nested message heuristic: has fields and no huge blob
                    if sub and sum(len(x[1]) for x in sub.get(1, []) if x[0] == 2) < 500:
                        print(f"{'  '*depth}field {fn} (submessage):")
                        show(label, v, limit, depth + 1, maxdepth)
                        continue
                    disp = f"<bytes {len(v)}> " + v[:48].hex()
                else:
                    disp = f"<bytes {len(v)}> " + v[:48].hex()
            elif wt == 0:
                disp = str(v)
            else:
                disp = v.hex()[:40]
            print(f"{'  '*depth}field {fn} wire {wt}: {disp}")

def abci(rpc, path, data_hex="", label="", raw_out=None):
    if data_hex:
        url = f"{rpc}/abci_query?path=\"{path}\"&data=0x{data_hex}&prove=false"
    else:
        url = f"{rpc}/abci_query?path=\"{path}\"&prove=false"
    j = json.loads(get(url))
    r = j.get('result', {}).get('response', {})
    code = r.get('code')
    import base64 as b64
    val = b64.b64decode(r.get('value', '')) if r.get('value') else b''
    print(f"=== {label or path} @ {rpc} -> code={code} {r.get('log','')[:60]}")
    if code == 0 and val:
        show(label or path, val)
        if raw_out:
            open(raw_out, 'wb').write(val)
    return val

if __name__ == '__main__':
    CH = {
        'pundix':    ('https://px-json.pundix.com', '/cosmos.gov.v1beta1.Query/Params'),
        'nyx':       ('https://rpc.nymtech.net', '/cosmos.gov.v1.Query/Params'),
        'sommelier': ('https://sommelier-rpc.polkachu.com', '/cosmos.gov.v1.Query/Params'),
        'shido':     ('https://rpc-shido.onenov.xyz', '/cosmos.gov.v1.Query/Params'),
    }
    only = sys.argv[1] if len(sys.argv) > 1 else None
    for c, (rpc, path) in CH.items():
        if only and only != c:
            continue
        try:
            abci(rpc, path, label=f"{c} gov params", raw_out=f"/home/heisenberg/CA/unpatched-chains/analysis/gov_params_{c}.pb")
        except Exception as e:
            print(f"=== {c} ERR {e}")
