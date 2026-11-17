# Lifecycle & rapid channel selection hardening

- Pending channel opens are serialized: latest channel request wins, so a second selection while the decoder is opening is no longer discarded.
- Outdated opens cannot overwrite the latest loading UI; failed current opens retain bounded reconnect logic.
- On Flutter inactive/hidden/paused, playback pauses; on resume, it resumes only when the app auto-paused it. This is a conservative foreground-only media policy, **not** Android native MediaSession or true background audio support.
- Added deterministic latest-request mailbox tests.
- Caveats: pending error events from native media engine may not carry URL/generation; codec-level races require hardware stress testing. Lifecycle pause/resume should be tested for interruptions and audio focus.
- PiP, casting, multiview and native TV MediaSession remain outstanding.
- Flutter SDK absent here: analyze, unit tests and binaries cannot be verified.

## Android PiP bridge

- `tool/prepare_platforms.ps1` adds `supportsPictureInPicture` to the generated Android FlutterActivity and emits a Kotlin `MethodChannel` bridge for `isSupported` and `enter`.
- User activates from Player controls; no implicit PiP or auto-background playback. Unsupported devices return false and display an explanatory message.
- **Hardware limitation**: Android PiP lifecycle, TV launchers, remote controls in PiP and MediaSession actions are NOT verified. The Flutter lifecycle observer only tracks entry by this button; external/system PiP exits need native callbacks in later work.
