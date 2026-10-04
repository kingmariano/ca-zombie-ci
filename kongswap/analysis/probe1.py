import json
from ic.client import Client
from ic.identity import Identity
from ic.agent import Agent
from ic.candid import encode, decode, Types

client = Client(url="https://ic0.app")
agent = Agent(identity=Identity(), client=client)
CAN = "2ipq2-uqaaa-aaaar-qailq-cai"

def q(method, args_bytes):
    try:
        r = agent.query_raw(CAN, method, args_bytes)
        return r
    except Exception as e:
        return {"error": str(e)}

# get_tokens: no args
print("== get_tokens ==")
r = q("get_tokens", encode([]))
s = json.dumps(r, default=str)
print(s[:3000])
