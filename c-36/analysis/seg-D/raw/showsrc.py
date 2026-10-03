import json,sys
a=sys.argv[1].lower()
d=json.load(open('src/'+a+'.json'))
print("// name:",d.get('name'),"| verified:",d.get('is_verified'),"| proxy:",d.get('proxy_type'),"| impl:",d.get('implementations'))
print(d.get('source_code') or '')
