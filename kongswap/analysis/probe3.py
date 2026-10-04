from ic.client import Client
from ic.identity import Identity
from ic.agent import Agent
from ic.candid import encode, decode, Types

client = Client(url="https://ic0.app")
agent = Agent(identity=Identity(), client=client)
CAN = "2ipq2-uqaaa-aaaar-qailq-cai"

def q(method, args):
    try:
        r = agent.query_raw(CAN, method, encode(args))
        print(f"== {method} OK ==")
        print(str(r)[:2500])
    except Exception as e:
        print(f"== {method} ERROR: {str(e)[:200]}")

q("user_balances", [("2ipq2-uqaaa-aaaar-qailq-cai", Types.Text)])
q("claims", [("2ipq2-uqaaa-aaaar-qailq-cai", Types.Text)])
