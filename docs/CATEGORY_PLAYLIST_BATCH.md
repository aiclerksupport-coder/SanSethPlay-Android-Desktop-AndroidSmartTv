# SanSeth Play — Category Playlists, Unlimited Sources & Duplicate Guard

## Expected behavior (Android mobile, Windows, Android TV — shared Flutter code)

1. User pastes a public/authorized GitHub M3U file URL (including GitHub `blob` format) or a direct stream link.
2. For M3U input, each `#EXTINF` `group-title` is used to build in-memory **category views under that same saved source**. News, Sports, Movies, etc. appear in the searchable category selector, with channel counts. `Uncategorized` is fallback. No new duplicate saved URL is created for each category.
3. Each URL is stored once with its original name and source type in device secure storage. Same normalized URL is rejected on subsequent additions, including equivalent `github.com/.../blob/` versus `raw.githubusercontent.com/...` forms and duplicate cross-mode addition.
4. The old arbitrary 100-source limit is removed. Saved sources picker is lazily built and searchable; actual maximum remains bounded by device secure storage space, JSON serialization cost and physical resources. This is **not a mathematical claim of infinite storage**.
5. Existing offline channel snapshots and per-source refresh behavior stay intact. No provider login required for M3U/direct links; Xtream remains optional.
6. Same responsive code for all 3 platforms; physical build/TV remote performance tests still required.

## Key production risks / next hardening

- **Scalability:** a single encrypted JSON registry is rewritten for each addition. For very large source counts, migrate to an indexed encrypted database plus secure key and transactional deduplication. Do not store bearer tokens in plaintext.
- **Duplicate semantics:** signed URLs with different query strings remain distinct, because query strings may identify different accounts or expiry tokens. Equivalent content from different URLs cannot be deduced without downloading and comparing.
- **Concurrent adds:** UI mutation guard prevents overlapping dialog submissions in one HomeScreen. Cross-process deduplication is not implemented.
- **Provider metadata:** `group-title` may be missing or malformed. Such channels go into `Uncategorized` rather than being discarded.
- **Caching:** 20k-channel snapshot cap remains per playlist; adding many sources does not guarantee offline cache for every channel on low storage devices.
- **Native/device acceptance:** Run `flutter analyze`, `flutter test`, Android/Windows release builds and actual TV remote tests on Windows Flutter toolchain.
