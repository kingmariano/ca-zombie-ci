# Tangle Explorer (Shimmer L1) — final milestones, captured 2026-10-13

Source URL: `https://explorer.shimmer.network/` (Tangle Explorer, "Explorer for viewing transactions and data on the Tangle", still online 2026-10-13, serving **frozen** L1 data).
Capture method: Firecrawl scrape (headless browser render) — two scrapes minutes apart returned **identical** latest-row text, proving the data is frozen.
Raw evidence: `new-explorer.html`, `new-explorer-env.js` (`window.env = { API_ENDPOINT: 'https://explorer-api.shimmer.network/' }`), `explorer-api-probe-*.txt`, `core-*.txt`.

## Latest milestones (as rendered)

| Index | Milestone Id | Timestamp (as rendered) |
|---|---|---|
| **24359373** | `0x327a7aa3db2a2de9ee02c34660e83fe85b02e117a7558292aab6048f617db5cd` (block id `0x4541f53be0d52c3c50a70548c8e4e11664eb9fb40be4b54f42da02d68f2df504`) | **"8.32s ago"** — broken relative string, static across scrapes (no valid absolute ts) |
| 24359372 | `0x27992851736250c8b600d93c81e2510ffbfb41965481ffa8cf959057ffe6c2f6` | **2026-09-30 03:44:04** |
| 24359371 | `0x7ab580048237bbe4886193dd8251617233ef42d99a123ec7b3b38fff6bc2c28c` | 2026-09-30 03:43:59 |
| 24359370 | `0x9271257d4263edfc1a152ff0537eba9ad65e363efe6fccaefa36165e4564cea5` | 2026-09-30 03:43:54 |
| 24359369 | `0x5dba73b5923559ed5c11050d6896f6150470d119bbf414f1c948b3e72dbc96ae` | 2026-09-30 03:43:49 |
| 24359368 | `0x70e182d201fe1d6c67b0b9c73d03db4c9c6fd556df4a60661594cbaeffdc8a6b` | 2026-09-30 03:43:44 |
| 24359367 | `0x0220d2f31b42ea5494c64489c05c4ff7f91b32b11b8b27c8f78e1feab57a0b66` | 2026-09-30 03:43:39 |
| 24359366 | `0x4ed375b4e8a083b3d45acb7042b5126b6a382aa9ee0e0eedcf509eedd62343ee` | 2026-09-30 03:43:34 |
| 24359365 | `0xa4d4bb7ec101aafadf883da1089a3ac9af37916426a30a4e1228329447b0681a` | 2026-09-30 03:43:29 |
| 24359364 | `0xbf6e26b8fe59a531fa333eb365a86ec38dbde13b35e2035f9866c490d2d4e741` | 2026-09-30 03:43:24 |

Network header stats rendered blank ("Blocks per sec --, Inclusion rate --, SMR Market Cap --, Price --").

## Milestone detail page (doubles as timezone note)

`https://explorer.shimmer.network/shimmer/block/0xc092eaf108f93e85295d621d67191980a090e4d9bd75f391e627311fd789ea93` (index 24359372, rendered 2026-10-13):

- Title: "Milestone Block 24359372" — **Confirmed**
- Index: 24359372
- Date: **Wednesday, September 30, 2026 3:44 AM – 13 days ago** (12-hour AM/PM ⇒ renderer in US locale; 3:44 AM at UTC−4 = **07:44 UTC**)
- Referenced Blocks: 20; Payload Type: Milestone; Inclusion Status: "block is referenced by a milestone but there is no value transfer"

## Interpretation

- The explorer/API froze at index **24359373**, matching the X post by @theiotafeed citing the final confirmation signal at **milestone 24,359,373** on **2026-09-30** (halt "07:44 UTC").
- The 4-hour offset between the rendered "3:44 AM" and the post's "07:44 UTC" indicates the scraped page was rendered in a US Eastern-like timezone. If the rendered times were actually UTC, the halt would be 03:44 UTC — flagged as an open question in the report.
