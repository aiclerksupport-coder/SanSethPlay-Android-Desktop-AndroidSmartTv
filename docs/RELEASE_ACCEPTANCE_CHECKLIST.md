# Release Acceptance (required before calling production-ready)

- [ ] Flutter doctor / format / analyze / all Flutter tests pass
- [ ] Android phone installed; cold start, saved M3U, HLS, subtitles, PiP tested
- [ ] Android TV installed; D-pad navigation, focus, back, volume, media buttons physically tested
- [ ] Windows EXE portable folder tested on clean Windows machine
- [ ] Minimum 320px mobile width, tablet, 720p/1080p TV, 100-200% Windows DPI overflow tests
- [ ] Long-play 4h+ memory / battery / decoder/reconnect soak tests
- [ ] M3U URL privacy + HTTP redirects + encrypted key failure recovery
- [ ] Security QA: Android signing and package ID, network host/header handling, secret leakage
- [ ] Native splash / MediaSession / Windows installer / casting / multi-view complete or explicitly deferred

Do not mark these as passed based on source code only.
