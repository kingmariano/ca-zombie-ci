from ic.client import Client
from ic.identity import Identity
from ic.agent import Agent
from ic.candid import encode, Types

client = Client(url="https://ic0.app")
agent = Agent(identity=Identity(), client=client)
CAN = "2ipq2-uqaaa-aaaar-qailq-cai"

def q(method, params):
    try:
        r = agent.query_raw(CAN, method, encode(params))
        print(f"== {method} OK ==")
        print(str(r)[:3000])
    except Exception as e:
        print(f"== {method} ERROR: {str(e)[:250]}")

q("user_balances", [{'type': Types.Text, 'value': "2ipq2-uqaaa-aaaar-qailq-cai"}])
q("claims", [{'type': Types.Text, 'value': "2ipq2-uqaaa-aaaar-qailq-cai"}])
