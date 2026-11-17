# SanSeth Play v0.1.0+1 — Keyboard focus patch

## Reproduction / cause
`home_screen.dart` applied `autofocus: true` to the Add Playlist URL input and generic searchable picker input. Opening these dialogs automatically focused an editable field, causing the OS software keyboard to appear without a tap or click.

## Source fix
- Add Playlist URL input: `autofocus: false`.
- Category / Saved Playlists picker search: `autofocus: false`.
- Channel selection: if channel search is focused, transfer focus to the existing non-editable shortcut root before switching streams; this also applies when selecting the already-active channel.
- Keep existing `Focus(autofocus: true)` on root shortcut/remote handlers. They are *not editable text fields* and preserve TV D-pad / desktop shortcuts.
- Keep Ctrl+F as deliberate user-triggered search focus.

## Scope
Shared Flutter layout applies to Android Mobile, Android Smart TV and Windows Desktop. No playlist, video retry, Cast, DVR or native launcher changes. Existing version and assets unchanged.

## Validation
Added `test/keyboard_focus_test.dart` for startup and Add dialog keyboard visibility. Requires Flutter SDK to execute. Re-run `flutter analyze` and `flutter test` before building; actual device IME behavior needs runtime confirmation.
