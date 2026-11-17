# SanSeth Play v0.1.0+1 — Live Playback + Android Launch Smoke Fix

## Reported observations
- Release APK 100.5 MB build aur USB install PASS (user ke Windows log ke mutabik)
- `adb monkey` launch smoke FAIL hua; user ne app ko phone par chalte hue dikhaya
- Kuch streams play hote hue bhi reconnect popup dikhate hain

## Targeted source changes
1. `VERIFY_ANDROID_LAUNCH.ps1`: `adb shell am start -W ... -n <package>/MainActivity`; native STDERR PowerShell 5.1 safe capture; cold-start PID check; failure par complete output log
2. `lib/player/player_view.dart`: transient `player.stream.error` ignore while `playing=true`; 3 sec delayed error confirmation; startup watchdog 18 sec; retry timers cancel when playback starts; 3-sec debounce for buffering chip; generation-cancel and cleanup

## Behavior/caveats
- Player codec/network/server ki asli buffering ko magical zero nahi karta. Bad URL, slow CDN, unsupported codec ya bandwidth issues par playback ruk sakta hai
- Auto retry only when playback has not started/has stopped after confirmation, never simply because decoder emitted a recoverable error during playback
- Android Mobile, Windows aur Android TV ke shared Dart player mein same change applies, lekin actual physical testing pending
- Native manifest, M3U parser, Xtream, favorites, DVR, branding, version aur Windows build scripts untouched
- GitHub push na kiya gaya; build/test/install gates preserve hain

## Test command
`powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_ANDROID_MOBILE.ps1`

Already-installed app ka standalone launch check:
`powershell -NoProfile -ExecutionPolicy Bypass -File .\VERIFY_ANDROID_LAUNCH.ps1`

## Acceptance checks on physical device
- Stable live stream plays >=10 minutes with no false retry overlays
- Switching among 10 channels rapidly should not reopen old channel or leak retry dialogs
- Unreachable URL shows retry only after confirmed startup failure
- Short HLS segment changes should not flash Buffering chip
- Android TV D-pad and Windows playback need separate runtime check
