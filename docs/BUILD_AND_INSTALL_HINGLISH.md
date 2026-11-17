# SanSeth Play — 3 Platform Build, Test aur Install Guide

**Version:** `0.1.0+1` (unchanged). **OS:** Windows PowerShell, VS Code terminal.

## Common setup (ek baar)

1. Flutter SDK (PATH), Android SDK Platform Tools (`adb`), Android SDK command-line tools, Java/Gradle prerequisites install karein.
2. Windows EXE build ke liye Microsoft Visual Studio **Desktop development with C++** workload zaroori hai; VS Code alone enough nahi.
3. VS Code mein extracted source folder open karein. Terminal > New Terminal > PowerShell.
4. Android device USB debugging authorize karein. `adb devices -l` mein device ka status `device` hona chahiye, `unauthorized` nahi.
5. `flutter doctor -v` ka output check karein. Scripts fail on missing prerequisites.

## Android Mobile — one line

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_ANDROID_MOBILE.ps1
```

Connected aur authorized **non-TV Android** phone par release APK install karega. Multiple connected devices ho to:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_ANDROID_MOBILE.ps1 -DeviceSerial "SERIAL_FROM_ADB_DEVICES"
```

Sirf build ke liye `-SkipInstall`. Release APK: `dist\SanSeth-Play-v0.1.0+1-android-mobile.apk`.

## Windows Desktop — one line

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_WINDOWS.ps1
```

Portable Release directory: `dist\SanSeth-Play-v0.1.0+1-Windows\`. Us folder ko poora copy karna hai, sirf EXE nahi. Is batch mein MSI/MSIX installer nahi bana hai. Launch ke liye folder mein `sanseth_play.exe` (ya generated EXE filename) double-click karein.

## Android Smart TV / Google TV — install methods

**Sirf Android TV / Google TV** (Android-compatible TV box bhi) ke liye APK. Samsung Tizen aur LG webOS is Android APK ko run nahi karte.

**Method A: USB ADB**

1. TV Settings > System/Device Preferences > About > Build ko 7 baar click karke Developer options enable karein (model ke according wording badal sakti hai).
2. Developer options > USB debugging enable karein; TV ke manufacturer par USB ADB port available hona chahiye.
3. PC se connect karein, TV par RSA debugging permission Allow karein.
4. `adb devices -l` se TV serial confirm karein.
5. One-line command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_ANDROID_TV.ps1 -DeviceSerial "YOUR_TV_SERIAL"
```

**Method B: Wireless ADB (same network)**

1. TV par Developer options > Wireless debugging (supported Android versions) enable karein.
2. Pairing code ke saath pairing device/IP:port use karein:

```powershell
adb pair TV_IP:PAIR_PORT
```

3. Pairing ke baad TV ke **debugging/connect port** (pair port se alag ho sakta hai) par connect karein:

```powershell
adb connect TV_IP:DEBUG_PORT
```

4. One-line build/test/install:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_ANDROID_TV.ps1 -DeviceSerial "TV_IP:DEBUG_PORT"
```

TV par USB/wireless debugging unsupported ho to vendor-approved APK sideload method zaroori ho sakta hai. TV apps list mein **SanSeth Play** dhoondein. Agar launcher entry na dikhe to leanback manifest/device compatibility troubleshoot karein.

**Direct TV connection (paired/authorized classic ADB only):**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_ANDROID_TV.ps1 -TvHost "TV_IP:DEBUG_PORT" -DeviceSerial "TV_IP:DEBUG_PORT"
```

## All build checks — one line

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\RUN_ALL_TESTS.ps1
```

**All targets** (mobile + Windows, TV same Android APK; TV install separately):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_ALL.ps1 -SkipInstall
```

### Logs policy

Every step and `flutter build ... --verbose` output **VS Code terminal par visible** hoga. Successful steps par log files nahi bante. Any command fail to `failure-logs\FAILED_<step>-v0.1.0_1.log` create hota hai. Failed step par pipeline stop hoti hai. Note: upstream tools kabhi sensitive URL/token print kar sakte hain; failure logs public share karne se pehle redact karein.

### Important technical limitations

- `flutter doctor -v` ka non-zero result unsupported SDK setups par fail kar sakta hai; doctor ko fix karein.
- Physical devices, actual TV D-pad, PiP, codec, EPG, tiny-screen overflow, memory pressure aur long-running streaming tests local environment mein manually run karne honge.
- Android TV ke liye Android Mobile wali same signed APK use hoti hai, lekin device category ke hisaab se launcher configuration alag handle hota hai.
- Release builds development ke default signing config par ho sakte hain. Public distribution se pehle proper release signing, package ID aur installer signing ki zaroorat hai.
