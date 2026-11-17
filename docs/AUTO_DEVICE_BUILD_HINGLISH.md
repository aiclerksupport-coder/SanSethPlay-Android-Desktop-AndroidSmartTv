# SanSeth Play: bina device ID ke build + install

- Ek hi authorized Android phone connected hai: `powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_ANDROID_MOBILE.ps1` — Flutter tests, APK build, phone par install aur launch smoke check. Phone serial manually dene ki zarurat nahi.
- Full orchestrator: `powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_TEST_INSTALL_GITHUB.ps1` — device type detect karke phone aur (agar connected ho) Android TV select karega. Phone ke baad Windows build/installer bhi karega. TV missing ho to TV install skip, aur GitHub push strictly BLOCK; bina TV ke success ka false gate generate nahi hoga.
- Android TV alag: `powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_ANDROID_TV.ps1` — sirf ek TV connected ho to auto-install.
- Multiple phones ya TVs: ambiguity mein relevant `-DeviceSerial` / `-MobileSerial` / `-TvSerial` pass karein.
- USB debugging authorize karna zaroori hai. Windows aur Android TV physical testing ke bina complete production sign-off nahi.
