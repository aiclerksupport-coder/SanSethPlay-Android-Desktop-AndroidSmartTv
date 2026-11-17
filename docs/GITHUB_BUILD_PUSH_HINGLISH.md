# SanSeth Play — GitHub Build / Install / Push (Hinglish)

Repository: https://github.com/aiclerksupport-coder/SanSethPlay-Android-Desktop-AndroidSmartTv
Branch: `main` (existing repository README/history preserved; no force-push)
Version: `0.1.0+1` unchanged.

## Ek line — full pipeline

1. Windows 10/11 mein Flutter SDK + Dart, Android SDK platform-tools (adb), Visual Studio Desktop C++ workload, Inno Setup 6, Git for Windows install karo.
2. VS Code PowerShell terminal mein `flutter doctor -v`, `adb devices -l`, `git --version` check karo.
3. Android phone par Developer Options + USB Debugging on karke USB authorize karo.
4. Android TV/Google TV par Settings > About > Build par Developer Options activate karke USB/Wireless Debugging on karo. TV ke pairing port aur connect port alag ho sakte hain; `adb pair IP:PAIR_PORT` (supported devices), phir `adb connect IP:DEBUG_PORT`; `adb devices -l`.
5. GitHub auth setup ke liye `gh auth login` (agar GitHub CLI installed ho), warna Git Credential Manager ki browser authentication use karo. Password/PAT scripts mein mat rakho.
6. Project root mein actual phone aur TV serial ke saath:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_TEST_INSTALL_GITHUB.ps1 -MobileSerial 'PHONE_SERIAL' -TvSerial 'TV_IP:DEBUG_PORT'
```

Ye ordered pipeline: Flutter format-check/analyze/tests; phone release APK build + ADB install + launch smoke; Android TV release APK build + ADB install + Leanback launch smoke; Windows release build + Inno Setup installer; installer ka silent per-user install + launch smoke; secrets/artifact guard; existing GitHub `main` history par commit + push.

**No push dry run:** upar same command ke end mein `-NoPush` lagao.

## Alag one-liners

```powershell
.\RUN_ALL_TESTS.ps1
.\BUILD_ANDROID_MOBILE.ps1 -DeviceSerial 'PHONE_SERIAL'
.\BUILD_ANDROID_TV.ps1 -DeviceSerial 'TV_IP:DEBUG_PORT'
.\BUILD_WINDOWS.ps1
.\BUILD_WINDOWS_INSTALLER.ps1
.\VERIFY_WINDOWS_INSTALLER.ps1
```

### TV sideload detail
- Android TV/Google TV ko ADB se connect karo. Samsung Tizen/LG webOS par Android APK seedhi install nahi hoti.
- Build script TV ka `android.software.leanback` feature check karke hi APK install karta hai.
- Leanback launcher icon ke andar approved golden S symbol preserved rahega.
- Agar TV Wi-Fi debugging unsupported hai to USB ADB-capable Android TV box use karo; vendor permissions differ.

### Failure logs + release policy
- VS Code terminal mein commands aur output visible rehte hain; failure par `failure-logs/FAILED_*.log` generate hote hain.
- `dist/`, `.env`, signing keys, token files, secrets, user playlists aur database GitHub mein kabhi push nahi honge.
- GitHub push only after all automatic gates pass; force push prohibited.
- GitHub Actions CI additional verification hai, physical TV/Chromecast/video and performance tests ka substitute nahi.
- Ye scripts is environment mein run nahi huye; PC par actual outputs ke bina success claim mat karo.
- Video compatibility, low-RAM jank, native splash, Cast receiver, remote D-pad aur seek/live edge manual testing abhi mandatory hai.
