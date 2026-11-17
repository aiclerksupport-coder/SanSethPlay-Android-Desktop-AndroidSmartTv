# SanSeth Play — UI/Mini-player Acceptance Checklist

Version must stay `0.1.0+1`; original gold S and full portrait/landscape splash images must remain byte-for-byte identical. Verify 320x568, 360x640, 800x480, 1024x768, 1920x1080, Android TV D-pad, Windows keyboard/mouse and Android rotation.

1. Home with no playlist: M3U URL, direct stream and paste-text cards visible, Import sheet works and does not automatically open keyboard.
2. Import authorized GitHub M3U URL: categories/list populated; saved playlist persists across process restart; duplicate link blocked.
3. Select a live stream; after playback starts, tap mini icon beside title. Video must continue in bottom-right, with Restore/Close usable. Channel list must remain scrollable behind pane.
4. Tap a different channel while mini is open; old decoder must not race and new stream must replace it. Watch for audio leaks/duplicate player sessions.
5. Restore, minimize again, rotate portrait/landscape, switch tabs, open About and back. Confirm no resize overflow, black flash or lost playlist state.
6. Android TV D-pad must focus and activate button and list actions. Windows mouse and keyboard should not trigger virtual keyboard automatically.
7. About must show actual `0.1.0+1`, Developer `Kalpesh Patel`. Header gold S symbol larger, app theme color behind it.
8. OS-native Android 12+ splash is icon-based; verify full original portrait artwork appears immediately after OS phase and is not cropped/stretched.
9. Flutter format/analyze/tests must pass, then Android release APK build/install/launch, Windows EXE/install, Android TV remote; collect real playback logs. No GitHub push before gates.
10. Before public release review all THIRD_PARTY_NOTICES, licenses, Terms, Privacy and Security texts, signing identity, and release secrets.

One line Android Mobile: `powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_ANDROID_MOBILE.ps1`
One line Android Smart TV: `powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_ANDROID_TV.ps1`
One line Windows setup: `powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_WINDOWS_INSTALLER.ps1`
