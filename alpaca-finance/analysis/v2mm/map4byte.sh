#!/bin/bash
out=selector_map.txt
: > $out
for s in $(python3 -c "
import json
f=json.load(open('facets_live.json'))
for a,sels in f.items():
    for s in sels: print(s)
"); do
  name=$(timeout 20 cast 4byte $s 2>/dev/null | head -1)
  echo "$s $name" >> $out
done
echo DONE >> $out
