# Pruned raw downloads

To keep the public CI repo light, the following bulky raw dumps were deleted after
their tables/summaries were extracted (they are fully reproducible from the public
GoldRush/BSC endpoints with the scripts kept in this folder):

- holders/raw_goldrush/events_NAR.jsonl        (~584 MB, 444,811 Transfer events of NAR)
- holders/raw_goldrush/events_LP_WBNBBUSD.jsonl (~238 MB)
- holders/raw_goldrush/events_THUGS.jsonl     (~196 MB)
- holders/raw_goldrush/events_NLP.jsonl       (~179 MB)
- holders/raw_goldrush/events_LP_WBNBTHUGS.jsonl (~14 MB)
- holders/raw_goldrush/events_rNLP5.jsonl     (~6.3 MB)
- holders/raw_goldrush/events_rNLP6.jsonl     (~2.0 MB)
- ecosystem/lp_transfers.json / lp_transfers_ckpt.json (~54 MB, LP Transfer logs)
- ecosystem/nar_from_ckpt.json                (~20 MB, NAR Transfer logs)
- ecosystem/sourcify/ (downloaded bundles, ~7 MB) — verified sources kept in analysis/sources/

Holder tables, farm reads, reconstruction summaries and the scripts remain in
holders/ and ecosystem/.
