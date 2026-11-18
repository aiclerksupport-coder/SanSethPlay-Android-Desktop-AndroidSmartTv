# Playlist privacy and recovery — v0.1.3+4 candidate

- Independent Hide / Lock flags, persisted separately from playlist URL records in OS secure storage.
- Default My Playlists hides hidden items; Manage hidden playlists requires owner authentication. Lock-only items remain listed but do not load until authenticated.
- A protected playlist is never restored automatically on startup, and applying Hide or Lock stops the active player and clears the channel UI.
- Removing both flags restores the existing URL, local cache and channel behavior; no content is deleted by privacy changes.
- Android and eligible Windows devices use OS biometric/device credential/Windows Hello via `local_auth` first. An explicit OS denial/cancel never downgrades to a self-chosen PIN.
- Android TV and devices without OS auth require a local non-trivial 6–12-digit owner PIN and one-time recovery code. The verifier (not the PIN/code) is stored in OS secure storage, with per-secret salt. Keep the recovery code offline: losing both PIN and recovery code cannot be resolved by a universal master PIN.
- PIN verification uses background-isolate SHA-256 iterations. This is a casual-access safeguard, not a hardware-bound secret proof; high-risk threat models require stronger KDF and hardware-bound authentication.
- Five failed PIN/recovery attempts trigger a two-minute in-process cooldown. OS-level attempts are controlled by the platform. A future persistent cooldown is recommended for tamper resistance.
- Unlocking a protected playlist grants access only until the app backgrounds or a different playlist is opened. Hidden management screens close on backgrounding. Hidden playlist titles do not appear in normal lists. Recording files have independent metadata and require a separate recording-library privacy design if users need existing recordings hidden too.

## Regression checklist

1. `flutter pub get && dart format lib test && flutter analyze && flutter test --reporter expanded -j 1`
2. Verify the original 4 failures: Import card at 360x640 and no RenderFlex overflow at 800x359, 800x360 and 800x361.
3. Android Mobile: set hide-only; confirm playlist name absent from normal lists, no recent/search/favorite leakage, no background playback. Use OS auth to unhide, confirm same original streams.
4. Android Mobile: lock-only visible with lock label; PIN/OS auth required before loading channels. Cancel OS auth and confirm it remains locked.
5. Android TV: owner PIN setup and offline recovery code; stop playback on lock; unlock and restore without altering data.
6. Windows: Windows Hello if supported, otherwise owner PIN and recovery code. Validate clean restore and no stale mini-player.
7. Force-stop app with protected playlist active and relaunch; no protected playback or artwork/name should be restored automatically.
8. Validate build and manual runtime playback on each target; archive-only checks cannot certify these tests.
