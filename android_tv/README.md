# Android TV delivery notes

- The Android application supports phone launchers, and `tool/prepare_platforms.ps1` adds Leanback TV launcher category to its Flutter Activity.
- `android_tv_banner_320x180.png` is a 320x180 derivative of the approved full-logo splash, not a new rendering.
- Physical remote D-pad, select, back, focus visibility, playback codecs, 720p and 4K overscan must be checked on a real Android TV / Google TV device before release.
- This APK is **not** a Tizen or LG webOS package; those operating systems require distinct integrations.
