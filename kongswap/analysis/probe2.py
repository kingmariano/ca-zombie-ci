from ic.client import Client
from ic.identity import Identity
from ic.agent import Agent
from ic.candid import encode

client = Client(url="https://ic0.app")
agent = Agent(identity=Identity(), client=client)
CAN = "2ipq2-uqaaa-aaaar-qailq-cai"
for m in ["__get_candid_interface_tmp_hack", "get_candid_interface"]:
    try:
        r = agent.query_raw(CAN, m, encode([]))
        print(f"== {m} ==")
        print(r)
    except Exception as e:
        print(f"== {m} == ERROR: {str(e)[:300]}")
